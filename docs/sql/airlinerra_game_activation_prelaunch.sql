-- Airlinerra ACCOUNT ACTIVATION (review only, NOT APPLIED).
-- Requires docs/sql/airlinerra_game_identity_schema_prelaunch.sql.
-- Uses a trusted, privileged database connection. NEVER add public RPC grants.
-- Does not approve airports, open worlds, accept terms, or create real accounts.
begin;

-- Operator-owned platform gate: begins DISABLED and cannot be modified
-- by anonymous or authenticated browsers.
create table if not exists airlinerra_game.platform_release_gate (
  id boolean primary key default true check (id = true),
  enabled boolean not null default false,
  changed_at timestamptz not null default now()
);
alter table airlinerra_game.platform_release_gate enable row level security;
insert into airlinerra_game.platform_release_gate (id, enabled)
values (true,false) on conflict (id) do nothing;

-- The official policy versions must be separately approved and published.
-- Empty at install: even deliberately opening a world is insufficient.
create table if not exists airlinerra_game.legal_release_policy (
  id boolean primary key default true check (id = true),
  terms_version text not null check (length(terms_version) between 1 and 50),
  privacy_version text not null check (length(privacy_version) between 1 and 50),
  is_published boolean not null default false,
  approved_at timestamptz
);
alter table airlinerra_game.legal_release_policy enable row level security;

-- Only a trusted legal-acceptance endpoint may add consent, after
-- verifying the actual version/text displayed to the signed-in player.
-- No user_metadata or client-supplied consent boolean is authoritative.
create table if not exists airlinerra_game.account_consents (
  player_id uuid not null references auth.users(id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  accepted_at timestamptz not null default now(),
  primary key (player_id,terms_version,privacy_version)
);
alter table airlinerra_game.account_consents enable row level security;

create or replace function airlinerra_game.create_airline_once(
  p_player_id uuid,
  p_world_id smallint,
  p_name text,
  p_home_airport_source_id bigint
)
returns table (
  airline_id uuid,
  newly_created boolean,
  starting_balance_usd numeric,
  trial_ends_at timestamptz
)
language plpgsql security invoker
set search_path = ''
as $airlinerra_activation$
declare
  v_existing_airline uuid;
  v_existing_name text;
  v_existing_airport bigint;
  v_airline_name text;
  v_entitlement_state text;
  v_trial_end timestamptz;
  v_trial_start timestamptz;
  v_credit_applied boolean;
  v_membership_state text;
begin
  -- Server-side release switch always fail closed.
  -- For SHARE prevents operator disabling the gate midway through a call.
  perform 1 from airlinerra_game.platform_release_gate g
    where g.id = true and g.enabled = true for share;
  if not found then
    raise exception 'Airlinerra airline activation is not enabled'
      using errcode = 'check_violation';
  end if;

  -- Row lock serializes activation for the SAME player, across every world.
  -- Read only trusted Auth data, not user-controlled JWT metadata.
  perform 1 from auth.users u
    where u.id = p_player_id
      and u.email_confirmed_at is not null
      and coalesce(u.is_anonymous,false) = false
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until <= now())
    for update;
  if not found then
    raise exception 'Verified, active player account required'
      using errcode = 'check_violation';
  end if;

  -- Verified, published terms must have actually been accepted.
  -- Empty legal policy => no airline can ever be created.
  perform 1 from airlinerra_game.legal_release_policy l
    join airlinerra_game.account_consents c
      on c.player_id = p_player_id
     and c.terms_version = l.terms_version
     and c.privacy_version = l.privacy_version
    where l.id = true and l.is_published = true
      and l.approved_at is not null
    for share of l;
  if not found then
    raise exception 'Published terms and verified player consent required'
      using errcode = 'check_violation';
  end if;

  -- World status is governed by the operator, not caller input.
  -- Holding this lock makes activation + a simultaneous world close serial.
  perform 1 from public.airlinerra_game_worlds w
    where w.id = p_world_id
      and w.state in ('registration_open','active')
    for share;
  if not found then
    raise exception 'Selected Airlinerra world is closed'
      using errcode = 'check_violation';
  end if;

  -- Source IDs alone do NOT approve an airport.
  -- Approved game airports are intentionally empty by default.
  perform 1 from airlinerra_game.approved_game_airports a
    where a.world_id = p_world_id
      and a.source_airport_id = p_home_airport_source_id
    for share;
  if not found then
    raise exception 'Home airport not approved for this world'
      using errcode = 'check_violation';
  end if;

  v_airline_name := regexp_replace(btrim(p_name), '[[:space:]]+', ' ', 'g');
  if v_airline_name is null
     or length(v_airline_name) not between 3 and 80
     or v_airline_name ~ '[[:cntrl:]<>]' then
    raise exception 'Invalid airline name'
      using errcode = 'check_violation';
  end if;

  -- Repeated identical activation is allowed, different airline is not.
  select a.id,a.name,a.home_airport_source_id
    into v_existing_airline,v_existing_name,v_existing_airport
    from airlinerra_game.airlines a
   where a.owner_player_id = p_player_id and a.world_id = p_world_id;

  if found then
    if v_existing_name <> v_airline_name
       or v_existing_airport <> p_home_airport_source_id then
      raise exception 'Player already operates a different airline in this world'
        using errcode = 'unique_violation';
    end if;
    select e.trial_ends_at into v_trial_end
      from airlinerra_game.account_entitlements e
      where e.player_id = p_player_id;
    return query
      select v_existing_airline,false,
             a.cash_usd,v_trial_end
        from airlinerra_game.airlines a where a.id = v_existing_airline;
    return;
  end if;

  -- Do not allow a NEW airline after the one-time trial has ended, unless
  -- paid and valid. Trial clocks come from the database, never the browser.
  select e.membership_state,e.trial_ends_at
    into v_entitlement_state,v_trial_end
    from airlinerra_game.account_entitlements e
   where e.player_id = p_player_id
   for update;
  if found and (
    v_entitlement_state in ('past_due','expired','suspended')
    or (v_entitlement_state = 'trial'
        and (v_trial_end is null or v_trial_end <= now()))
  ) then
    raise exception 'Active membership is required for another world'
      using errcode = 'check_violation';
  end if;
  if found and v_entitlement_state not in ('none','trial','active') then
    raise exception 'Invalid account entitlement state'
      using errcode = 'check_violation';
  end if;

  -- World membership + airline + $5m ledger + first trial are part of one
  -- statement/transaction. Any error rolls the entire call back.
  insert into airlinerra_game.world_memberships
    (world_id,player_id,state)
  values (p_world_id,p_player_id,'active')
  on conflict (world_id,player_id) do update
      set state='active'
      where world_memberships.state in ('reserved','active','left')
  returning state into v_membership_state;
  if not found or v_membership_state <> 'active' then
    raise exception 'World membership is suspended'
      using errcode = 'check_violation';
  end if;

  insert into airlinerra_game.airlines
    (world_id,owner_player_id,name,home_airport_source_id)
  values (p_world_id,p_player_id,v_airline_name,p_home_airport_source_id)
  returning id into v_existing_airline;

  select airlinerra_game.credit_starting_cash_once(v_existing_airline)
    into v_credit_applied;
  if not v_credit_applied then
    raise exception 'Starting capital ledger was not created'
      using errcode = 'check_violation';
  end if;

  select e.trial_started_at,e.trial_ends_at,e.membership_state
    into v_trial_start,v_trial_end,v_entitlement_state
    from airlinerra_game.start_account_trial_once(p_player_id) e;
  -- A previously paid account may legitimately have no free-trial clock.
  -- A trial/none account, however, must have acquired a full trial.
  if not found or
     (v_entitlement_state <> 'active'
       and (v_entitlement_state <> 'trial'
         or v_trial_start is null
         or v_trial_end is null
         or v_trial_end <> v_trial_start + interval '168 hours'
         or v_trial_end <= now())) then
    raise exception 'Account entitlement initialization failed'
      using errcode = 'check_violation';
  end if;

  return query
    select v_existing_airline,true,a.cash_usd,v_trial_end
    from airlinerra_game.airlines a
    where a.id = v_existing_airline;
end;
$airlinerra_activation$;

-- Deny all direct client calls. A dedicated privileged backend must
-- establish an authenticated user identity and call through a trusted
-- database connection. NOT via browser RPC or client service-role key.
revoke all on function airlinerra_game.create_airline_once(uuid,smallint,text,bigint)
  from public,anon,authenticated;
revoke all on all tables in schema airlinerra_game
  from public,anon,authenticated;
revoke all on all sequences in schema airlinerra_game
  from public,anon,authenticated;
commit;
