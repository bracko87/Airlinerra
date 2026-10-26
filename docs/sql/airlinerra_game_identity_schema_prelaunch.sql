-- Airlinerra game/account foundation — REVIEW ONLY, NOT APPLIED.
-- Revised 2026-10-26, for a future OWNER-AUTHORIZED Supabase migration.
-- IMPORTANT: do NOT execute this against production until the launch schema
-- approval, privacy/legal terms, backfill plan and current schema checks.
-- Does NOT touch private airport research schema: airlinerra.*.
-- Does NOT activate gameplay, grant research access, or create actual airlines.
begin;

create schema if not exists airlinerra_game;
revoke all on schema airlinerra_game from public, anon, authenticated;

-- Public directory contains ONLY non-sensitive metadata.
-- No real world is open. Values become mutable only by a trusted operator.
create table if not exists public.airlinerra_game_worlds (
  id smallint primary key check (id between 1 and 3),
  name text not null,
  state text not null default 'planned'
    check (state in ('planned','registration_open','active','locked','retired')),
  registered_at timestamptz not null default now(),
  opens_at timestamptz,
  constraint game_world_name_length check (char_length(name) between 2 and 80)
);
alter table public.airlinerra_game_worlds enable row level security;
revoke all on public.airlinerra_game_worlds from public, anon, authenticated;
grant select on public.airlinerra_game_worlds to anon, authenticated;
create policy "World directory is publicly readable"
  on public.airlinerra_game_worlds for select to anon, authenticated
  using (true);

insert into public.airlinerra_game_worlds (id, name, state) values
  (1,'Founding World','planned'),
  (2,'Expansion World','planned'),
  (3,'Future World','planned')
on conflict (id) do nothing;

-- Profiles are optional until a verified, authenticated user creates one.
-- Do not trust editable profile fields for operator roles or entitlement.
create table if not exists public.airlinerra_player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null
    check (char_length(trim(display_name)) between 2 and 40),
  locale text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.airlinerra_player_profiles enable row level security;
revoke all on public.airlinerra_player_profiles from public, anon, authenticated;
grant select on public.airlinerra_player_profiles to authenticated;
-- Only the owner-provided, non-authoritative profile fields are writeable.
-- The user_id must match auth.uid(); timestamps are database-controlled.
grant insert (user_id, display_name, locale)
  on public.airlinerra_player_profiles to authenticated;
grant update (display_name, locale)
  on public.airlinerra_player_profiles to authenticated;
create policy "Profile owner can read"
  on public.airlinerra_player_profiles for select to authenticated
  using ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false');
create policy "Profile owner can insert"
  on public.airlinerra_player_profiles for insert to authenticated
  with check ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false');
create policy "Profile owner can update"
  on public.airlinerra_player_profiles for update to authenticated
  using ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false')
  with check ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false');

-- Profile timestamps come from the database, never from client input.
create or replace function airlinerra_game.touch_profile_updated_at()
returns trigger language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
begin
  new.updated_at := now();
  return new;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.touch_profile_updated_at()
  from public, anon, authenticated;
create trigger airlinerra_profile_update_clock
  before update on public.airlinerra_player_profiles
  for each row execute function airlinerra_game.touch_profile_updated_at();

-- Private tables: neither exposed via the Data API nor granted to client roles.
-- Policies are intentionally absent; all state mutations require a vetted
-- server-side transaction subject to fresh identity and entitlement checks.
create table if not exists airlinerra_game.account_entitlements (
  player_id uuid primary key references auth.users(id) on delete cascade,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  membership_state text not null default 'none'
    check (membership_state in ('none','trial','active','past_due','expired','suspended')),
  created_at timestamptz not null default now(),
  constraint trial_interval_exact check (
    (trial_started_at is null and trial_ends_at is null)
    or (trial_started_at is not null
        and trial_ends_at = trial_started_at + interval '168 hours')
  ),
  constraint entitlement_state_clock_consistent check (
    (membership_state = 'none'
       and trial_started_at is null and trial_ends_at is null)
    or (membership_state = 'trial'
       and trial_started_at is not null and trial_ends_at is not null)
    or membership_state in ('active','past_due','expired','suspended')
  )
);
alter table airlinerra_game.account_entitlements enable row level security;

create table if not exists airlinerra_game.world_memberships (
  world_id smallint not null references public.airlinerra_game_worlds(id),
  player_id uuid not null references auth.users(id) on delete cascade,
  state text not null default 'reserved'
    check (state in ('reserved','active','suspended','left')),
  joined_at timestamptz not null default now(),
  primary key (world_id,player_id)
);
alter table airlinerra_game.world_memberships enable row level security;

-- Game approval is a separate operator-owned step. Exact stable airport_key
-- matches the existing research registry, including fictional LYAL.
-- Empty by default: no runway-only/research airport is automatically playable.
-- An operator must separately approve actual airports, per individual world.
create table if not exists airlinerra_game.approved_game_airports (
  world_id smallint not null references public.airlinerra_game_worlds(id),
  airport_key text not null check (airport_key ~ '^(OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})
  approval_reference text not null,
  approved_at timestamptz not null default now(),
  primary key (world_id, airport_key)
);
alter table airlinerra_game.approved_game_airports enable row level security;

create table if not exists airlinerra_game.airlines (
  id uuid primary key default gen_random_uuid(),
  world_id smallint not null,
  owner_player_id uuid not null,
  name text not null
    check (char_length(trim(name)) between 3 and 80),
  home_airport_key text not null,
  -- FK prevents ANY airline until separately approved game airports exist.
  cash_usd numeric(18,2) not null default 0 check (cash_usd >= 0),
  created_at timestamptz not null default now(),
  unique (world_id,owner_player_id),
  foreign key (world_id,owner_player_id)
    references airlinerra_game.world_memberships(world_id,player_id),
  foreign key (world_id,home_airport_key)
    references airlinerra_game.approved_game_airports(world_id,airport_key)
);
create unique index if not exists airlinerra_airline_name_per_world
  on airlinerra_game.airlines(world_id,lower(name));
alter table airlinerra_game.airlines enable row level security;

-- Protect against accidental server-side airline creation in a closed world.
create or replace function airlinerra_game.require_open_world_for_airline()
returns trigger language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
begin
  if not exists (
    select 1 from public.airlinerra_game_worlds w
    where w.id = new.world_id
      and w.state in ('registration_open','active')
  ) then
    raise exception 'Airlinerra world is not open for airline registration'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.require_open_world_for_airline()
  from public, anon, authenticated;
create trigger airlinerra_airline_world_gate
  before insert or update of world_id on airlinerra_game.airlines
  for each row execute function airlinerra_game.require_open_world_for_airline();

create table if not exists airlinerra_game.airline_ledger (
  id bigint generated always as identity primary key,
  airline_id uuid not null references airlinerra_game.airlines(id),
  entry_kind text not null,
  amount_usd numeric(18,2) not null check (amount_usd <> 0),
  recorded_at timestamptz not null default now(),
  constraint valid_entry_kind check (
    entry_kind in ('STARTING_CAPITAL','AIRCRAFT_PURCHASE','AIRCRAFT_LEASE','REVENUE','EXPENSE','ADJUSTMENT')
  ),
  constraint valid_starting_amount check (
    entry_kind <> 'STARTING_CAPITAL' or amount_usd = 5000000.00
  )
);
-- Exactly one startup grant ($5 million) per airline; future secure
-- activation transaction must create its ledger entry and balance atomically.
create unique index if not exists airlinerra_one_startup_credit_per_airline
  on airlinerra_game.airline_ledger (airline_id)
  where entry_kind = 'STARTING_CAPITAL';
alter table airlinerra_game.airline_ledger enable row level security;

-- This operation is exactly-once under concurrency: the partial unique
-- ledger index decides which concurrent transaction may apply the balance
-- credit. Ledger insert and balance update happen in ONE database statement.
-- Call from the SAME trusted DB transaction as airline creation and trial.
create or replace function airlinerra_game.credit_starting_cash_once(
  p_airline_id uuid
)
returns boolean
language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
declare
  was_credited boolean;
begin
  with inserted as (
    insert into airlinerra_game.airline_ledger
      (airline_id,entry_kind,amount_usd)
    values (p_airline_id,'STARTING_CAPITAL',5000000.00)
    on conflict do nothing
    returning airline_id
  ),
  credited as (
    update airlinerra_game.airlines a
       set cash_usd = a.cash_usd + 5000000.00
     where a.id in (select inserted.airline_id from inserted)
    returning a.id
  )
  select exists (select 1 from credited) into was_credited;
  return was_credited;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.credit_starting_cash_once(uuid)
  from public, anon, authenticated;

-- Call ONLY as part of a future trusted airline-creation transaction.
-- This function is security INVOKER, private-schema only, and has no public
-- EXECUTE privilege. Repeated calls can NEVER restart an existing trial.
-- The airline row must already exist (within the trusted transaction).
create or replace function airlinerra_game.start_account_trial_once(p_player_id uuid)
returns table (
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  membership_state text
)
language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
begin
  if p_player_id is null or not exists (
    select 1 from airlinerra_game.airlines a
    where a.owner_player_id = p_player_id
  ) then
    raise exception 'Verified airline activation is required to begin a trial'
      using errcode = 'check_violation';
  end if;

  insert into airlinerra_game.account_entitlements as e
    (player_id, trial_started_at, trial_ends_at, membership_state)
  values (p_player_id, now(), now() + interval '168 hours', 'trial')
  on conflict (player_id) do update
    set trial_started_at = excluded.trial_started_at,
        trial_ends_at = excluded.trial_ends_at,
        membership_state = 'trial'
    where e.trial_started_at is null and e.membership_state = 'none';

  return query select e.trial_started_at, e.trial_ends_at, e.membership_state
    from airlinerra_game.account_entitlements e
    where e.player_id = p_player_id;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.start_account_trial_once(uuid)
  from public, anon, authenticated;

-- Defensive grants. No anon or authenticated privileges on private schema.
revoke all on all tables in schema airlinerra_game from public, anon, authenticated;
revoke all on all sequences in schema airlinerra_game from public, anon, authenticated;
commit;
),
  approval_reference text not null,
  approved_at timestamptz not null default now(),
  primary key (world_id, source_airport_id)
);
alter table airlinerra_game.approved_game_airports enable row level security;

create table if not exists airlinerra_game.airlines (
  id uuid primary key default gen_random_uuid(),
  world_id smallint not null,
  owner_player_id uuid not null,
  name text not null
    check (char_length(trim(name)) between 3 and 80),
  home_airport_source_id bigint not null,
  -- FK prevents ANY airline until separately approved game airports exist.
  cash_usd numeric(18,2) not null default 0 check (cash_usd >= 0),
  created_at timestamptz not null default now(),
  unique (world_id,owner_player_id),
  foreign key (world_id,owner_player_id)
    references airlinerra_game.world_memberships(world_id,player_id),
  foreign key (world_id,home_airport_source_id)
    references airlinerra_game.approved_game_airports(world_id,source_airport_id)
);
create unique index if not exists airlinerra_airline_name_per_world
  on airlinerra_game.airlines(world_id,lower(name));
alter table airlinerra_game.airlines enable row level security;

-- Protect against accidental server-side airline creation in a closed world.
create or replace function airlinerra_game.require_open_world_for_airline()
returns trigger language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
begin
  if not exists (
    select 1 from public.airlinerra_game_worlds w
    where w.id = new.world_id
      and w.state in ('registration_open','active')
  ) then
    raise exception 'Airlinerra world is not open for airline registration'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.require_open_world_for_airline()
  from public, anon, authenticated;
create trigger airlinerra_airline_world_gate
  before insert or update of world_id on airlinerra_game.airlines
  for each row execute function airlinerra_game.require_open_world_for_airline();

create table if not exists airlinerra_game.airline_ledger (
  id bigint generated always as identity primary key,
  airline_id uuid not null references airlinerra_game.airlines(id),
  entry_kind text not null,
  amount_usd numeric(18,2) not null check (amount_usd <> 0),
  recorded_at timestamptz not null default now(),
  constraint valid_entry_kind check (
    entry_kind in ('STARTING_CAPITAL','AIRCRAFT_PURCHASE','AIRCRAFT_LEASE','REVENUE','EXPENSE','ADJUSTMENT')
  ),
  constraint valid_starting_amount check (
    entry_kind <> 'STARTING_CAPITAL' or amount_usd = 5000000.00
  )
);
-- Exactly one startup grant ($5 million) per airline; future secure
-- activation transaction must create its ledger entry and balance atomically.
create unique index if not exists airlinerra_one_startup_credit_per_airline
  on airlinerra_game.airline_ledger (airline_id)
  where entry_kind = 'STARTING_CAPITAL';
alter table airlinerra_game.airline_ledger enable row level security;

-- This operation is exactly-once under concurrency: the partial unique
-- ledger index decides which concurrent transaction may apply the balance
-- credit. Ledger insert and balance update happen in ONE database statement.
-- Call from the SAME trusted DB transaction as airline creation and trial.
create or replace function airlinerra_game.credit_starting_cash_once(
  p_airline_id uuid
)
returns boolean
language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
declare
  was_credited boolean;
begin
  with inserted as (
    insert into airlinerra_game.airline_ledger
      (airline_id,entry_kind,amount_usd)
    values (p_airline_id,'STARTING_CAPITAL',5000000.00)
    on conflict do nothing
    returning airline_id
  ),
  credited as (
    update airlinerra_game.airlines a
       set cash_usd = a.cash_usd + 5000000.00
     where a.id in (select inserted.airline_id from inserted)
    returning a.id
  )
  select exists (select 1 from credited) into was_credited;
  return was_credited;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.credit_starting_cash_once(uuid)
  from public, anon, authenticated;

-- Call ONLY as part of a future trusted airline-creation transaction.
-- This function is security INVOKER, private-schema only, and has no public
-- EXECUTE privilege. Repeated calls can NEVER restart an existing trial.
-- The airline row must already exist (within the trusted transaction).
create or replace function airlinerra_game.start_account_trial_once(p_player_id uuid)
returns table (
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  membership_state text
)
language plpgsql security invoker set search_path = ''
as $airlinerra_fn$
begin
  if p_player_id is null or not exists (
    select 1 from airlinerra_game.airlines a
    where a.owner_player_id = p_player_id
  ) then
    raise exception 'Verified airline activation is required to begin a trial'
      using errcode = 'check_violation';
  end if;

  insert into airlinerra_game.account_entitlements as e
    (player_id, trial_started_at, trial_ends_at, membership_state)
  values (p_player_id, now(), now() + interval '168 hours', 'trial')
  on conflict (player_id) do update
    set trial_started_at = excluded.trial_started_at,
        trial_ends_at = excluded.trial_ends_at,
        membership_state = 'trial'
    where e.trial_started_at is null and e.membership_state = 'none';

  return query select e.trial_started_at, e.trial_ends_at, e.membership_state
    from airlinerra_game.account_entitlements e
    where e.player_id = p_player_id;
end;
$airlinerra_fn$;
revoke all on function airlinerra_game.start_account_trial_once(uuid)
  from public, anon, authenticated;

-- Defensive grants. No anon or authenticated privileges on private schema.
revoke all on all tables in schema airlinerra_game from public, anon, authenticated;
revoke all on all sequences in schema airlinerra_game from public, anon, authenticated;
commit;
