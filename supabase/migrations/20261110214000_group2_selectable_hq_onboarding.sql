CREATE OR REPLACE FUNCTION airlinerra_game.create_airline_once(p_player_id uuid, p_world_id smallint, p_name text, p_home_airport_key text)
 RETURNS TABLE(airline_id uuid, newly_created boolean, starting_balance_usd numeric, trial_ends_at timestamp with time zone)
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_existing_airline uuid;
  v_existing_name text;
  v_existing_airport text;
  v_airline_name text;
  v_entitlement_state text;
  v_trial_end timestamptz;
  v_trial_start timestamptz;
  v_credit_applied boolean;
  v_membership_state text;
  v_is_owner_private_pilot boolean := false;
begin
  -- One verified owner-approved email, and only after explicit private pilot
  -- acknowledgement. This does NOT open public registration or publish draft Terms.
  select exists(
    select 1 from auth.users u
    join airlinerra_game.owner_premium_email_reservations r
      on r.email=lower(btrim(u.email))
    join airlinerra_game.owner_private_pilot_consents p on p.player_id=u.id
    where u.id=p_player_id
      and u.email_confirmed_at is not null
      and coalesce(u.is_anonymous,false)=false
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until<=now())
  ) into v_is_owner_private_pilot;
  -- Server-side release switch always fail closed.
  -- For SHARE prevents operator disabling the gate midway through a call.
  perform 1 from airlinerra_game.platform_release_gate g
    where g.id = true and g.enabled = true for share;
  if not found and not v_is_owner_private_pilot then
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
  if not found and not v_is_owner_private_pilot then
    raise exception 'Published terms and verified player consent required'
      using errcode = 'check_violation';
  end if;

  -- World status is governed by the operator, not caller input.
  -- Holding this lock makes activation + a simultaneous world close serial.
  perform 1 from public.airlinerra_game_worlds w
    where w.id = p_world_id
      and (w.state in ('registration_open','active')
        or (v_is_owner_private_pilot and p_world_id=1 and w.state='planned'))
    for share;
  if not found then
    raise exception 'Selected Airlinerra world is closed'
      using errcode = 'check_violation';
  end if;

  -- HQ selection is independent from commercial flight approval. Group 2
  -- locations can host an airline; all scheduling and movement gates remain separate.
  perform 1 from airlinerra_game.airport_location_eligibility_v1 a
    where a.world_id = p_world_id
      and a.airport_key = p_home_airport_key
      and a.hq_selectable = true
    for share;
  if not found then
    raise exception 'Home airport not eligible for this world'
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
  select a.id,a.name,a.home_airport_key
    into v_existing_airline,v_existing_name,v_existing_airport
    from airlinerra_game.airlines a
   where a.owner_player_id = p_player_id and a.world_id = p_world_id;

  if found then
    if v_existing_name <> v_airline_name
       or v_existing_airport <> p_home_airport_key then
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
    (world_id,owner_player_id,name,home_airport_key)
  values (p_world_id,p_player_id,v_airline_name,p_home_airport_key)
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
$function$;
