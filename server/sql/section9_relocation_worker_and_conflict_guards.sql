BEGIN;
ALTER TABLE airlinerra_game.section9_maintenance_relocation_trips_v1 ADD COLUMN IF NOT EXISTS last_attempt_at timestamptz, ADD COLUMN IF NOT EXISTS last_result text, ADD COLUMN IF NOT EXISTS completed_at timestamptz;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_advance_maintenance_relocations_v1(p_limit int DEFAULT 25)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; v_now timestamptz; r jsonb; p_leg int; p_phase text; attempted int:=0; moved int:=0; completed int:=0; blocked int:=0; decision text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_RELOCATION_WORKER_ONLY';END IF;
 IF p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_RELOCATION_WORKER_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled) THEN RETURN jsonb_build_object('status','relocation_execution_not_released','checked',0,'movements',0,'completed',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583734,45) THEN RETURN jsonb_build_object('status','relocation_worker_already_running');END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 FOR t IN SELECT * FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE status='reserved' AND departure_utc<=v_now ORDER BY last_attempt_at NULLS FIRST,departure_utc LIMIT p_limit FOR UPDATE SKIP LOCKED
 LOOP
  attempted:=attempted+1;
  BEGIN
   p_leg:=NULL;p_phase:=NULL;
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=1 AND phase='departed') THEN p_leg:=1;p_phase:='departed';
   ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=1 AND phase='arrived') THEN IF (t.quote#>>'{outbound,arrivalUtc}')::timestamptz<=v_now THEN p_leg:=1;p_phase:='arrived';END IF;
   ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=2 AND phase='departed') THEN IF (t.quote#>>'{return,departureUtc}')::timestamptz<=v_now THEN p_leg:=2;p_phase:='departed';END IF;
   ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=2 AND phase='arrived') THEN IF (t.quote#>>'{return,arrivalUtc}')::timestamptz<=v_now THEN p_leg:=2;p_phase:='arrived';END IF;
   ELSIF t.available_utc<=v_now AND (SELECT count(*) FROM airlinerra_game.section9_relocation_leg_expense_receipts_v1 WHERE trip_id=t.id)=2 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j JOIN airlinerra_game.section9_game_maintenance_service_receipts_v1 m ON m.job_id=j.job_id WHERE j.job_id=t.maintenance_job_id AND j.status='completed' AND m.paid_ledger_entry_id IS NOT NULL) THEN
    UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET status='completed',completed_at=v_now,last_attempt_at=v_now,last_result='completed' WHERE id=t.id;
    completed:=completed+1;CONTINUE;
   END IF;
   decision:='awaiting_next_event_or_service';
   IF p_leg IS NOT NULL THEN
    r:=airlinerra_game.section9_execute_relocation_leg_event_v1(t.id,p_leg,p_phase);
    decision:=coalesce(r->>'status','event_not_verified');
    IF r->>'movementRecorded'='true' THEN moved:=moved+1;ELSE blocked:=blocked+1;END IF;
   END IF;
   UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET last_attempt_at=v_now,last_result=decision WHERE id=t.id;
  EXCEPTION WHEN OTHERS THEN
   blocked:=blocked+1;
   UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET last_attempt_at=v_now,last_result='relocation_event_failed' WHERE id=t.id;
  END;
 END LOOP;
 RETURN jsonb_build_object('status','relocation_worker_processed','checked',attempted,'movements',moved,'completed',completed,'blocked',blocked);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_advance_maintenance_relocations_v1(int) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_book_ai_maintenance_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_check text, p_airport text, p_provider text, p_start timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE f record; q jsonb; offer jsonb; pos jsonb; proof jsonb; v_now timestamptz; starts timestamptz; ends timestamptz; mins int; cost numeric; cap int; balance numeric; reserved numeric; state record; j uuid; check_day date;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_MAINTENANCE_BOOKING_ONLY';END IF;
 SELECT i.id,i.configuration_id INTO f FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.world_id=1 AND a.owner_player_id=p_player JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.fleet_status='in_service' AND i.ownership_type IN ('owned','leased') FOR UPDATE OF i;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='MAINTENANCE_AIRCRAFT_NOT_OWNED';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved') THEN RETURN jsonb_build_object('status','aircraft_relocation_already_reserved','created',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 starts:=coalesce(p_start,date_trunc('minute',v_now)+interval '2 minutes');
 IF starts<v_now+interval '1 minute' OR starts>v_now+interval '7 days' THEN RETURN jsonb_build_object('status','invalid_maintenance_start','created',false);END IF;
 q:=airlinerra_game.section9_owned_ai_maintenance_quotes_v1(p_player,p_airline,p_aircraft,p_check,p_airport);
 SELECT value INTO offer FROM jsonb_array_elements(q->'quotes') WHERE value->>'providerKey'=p_provider AND value->>'airportKey'=p_airport;
 IF offer IS NULL THEN RETURN jsonb_build_object('status','invalid_provider_offer','created',false);END IF;
 mins:=(offer->>'durationMinutes')::int;cost:=(offer->>'priceUsd')::numeric;cap:=(offer->>'designCapacity')::int;ends:=starts+make_interval(mins=>mins);
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE aircraft_inventory_id=p_aircraft AND status IN ('scheduled','in_progress','payment_required')) THEN RETURN jsonb_build_object('status','aircraft_already_booked_for_maintenance','created',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS DISTINCT FROM p_airport THEN RETURN jsonb_build_object('status','maintenance_relocation_required','created',false,'airportKey',pos->>'airportKey','providerAirportKey',p_airport);END IF;
 -- Until future route chaining is released, require a continuously proven ground window.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.status='active' AND s.version=o.schedule_version WHERE o.aircraft_inventory_id=p_aircraft AND o.airline_id=p_airline AND o.departure_utc>=v_now AND o.departure_utc<starts) THEN RETURN jsonb_build_object('status','future_aircraft_position_not_confirmed','created',false);END IF;
 proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(p_player,p_airline,p_aircraft,starts,ends);
 IF proof->>'slotClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','maintenance_flight_conflict','created',false,'slotEvidence',proof);END IF;
 PERFORM pg_advisory_xact_lock(583734,hashtext(p_provider));
 -- A provider slot is occupied for the entire reserved service interval.
 IF (SELECT count(*) FROM airlinerra_game.section9_game_maintenance_jobs_v1 j WHERE j.provider_key=p_provider AND j.status IN ('scheduled','in_progress','payment_required') AND j.game_start_utc<ends AND (j.game_end_utc>starts OR j.status='payment_required'))+(SELECT count(*) FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t WHERE t.provider_key=p_provider AND t.status='reserved' AND t.maintenance_job_id IS NULL AND (t.quote#>>'{maintenance,startUtc}')::timestamptz<ends AND (t.quote#>>'{maintenance,endUtc}')::timestamptz>starts)>=cap THEN RETURN jsonb_build_object('status','provider_capacity_unavailable','created',false);END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline FOR UPDATE;
 SELECT coalesce(sum(amount_usd),0) INTO balance FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 SELECT coalesce(sum(quoted_cost_usd),0) INTO reserved FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND status IN ('scheduled','in_progress','payment_required');
 IF balance-reserved<cost THEN RETURN jsonb_build_object('status','game_maintenance_insufficient_funds','created',false,'requiredUsd',cost);END IF;
 SELECT m.tracked_flight_hours INTO state FROM airlinerra_game.aircraft_maintenance_state_v1 m WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline;
 IF NOT FOUND OR state.tracked_flight_hours IS NULL OR airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,v_now) IS NULL THEN RETURN jsonb_build_object('status','missing_game_airframe_baseline','created',false);END IF;
 INSERT INTO airlinerra_game.section9_game_maintenance_jobs_v1(owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,game_start_utc,game_end_utc,duration_hours,duration_minutes,condition_before_game_pct,flight_hours_at_book,quoted_cost_usd,provider_key,provider_name,provider_quality)
 VALUES(p_player,p_airline,p_aircraft,p_check,p_airport,starts,ends,ceil(mins/60.0)::int,mins,(airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,v_now)->>'conditionPct')::numeric,state.tracked_flight_hours,cost,p_provider,offer->>'providerName',(offer->>'qualityRating')::int) RETURNING job_id INTO j;
 RETURN jsonb_build_object('status','scheduled','created',true,'jobId',j,'providerName',offer->>'providerName','providerKey',p_provider,'checkCode',p_check,'airportKey',p_airport,'startUtc',starts,'endUtc',ends,'durationMinutes',mins,'quotedCostUsd',cost,'chargedNow',false,'chargedAtServiceCompletion',true,'flightActivated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_commit_certified_schedule_activation_v1(p_player uuid, p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_date date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE target record; approval jsonb; proof record; changed integer; aoc_gate jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
    OR p_expected_version IS NULL OR p_expected_version<1
    OR p_game_date IS NULL
    OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
    OR p_days IS NULL OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_SCHEDULE_ACTIVATION_REQUEST'; END IF;
 SELECT s.id,s.world_id,s.version,s.status,s.operationally_verified,
        s.airline_id,s.aircraft_inventory_id
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a
   ON a.id=s.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR UPDATE OF s;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_SCHEDULE_ACTIVATION_NOT_OWNED';
 END IF;
 aoc_gate:=airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline,p_game_date);
 IF aoc_gate->>'authorized' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_activation_not_fully_certified',
   'scheduleId',p_schedule,'blockers',coalesce(aoc_gate->'issues','[]'::jsonb),
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 IF target.version IS DISTINCT FROM p_expected_version
 THEN RETURN jsonb_build_object(
   'status','blocked_stale_schedule_version','scheduleId',p_schedule,
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=target.aircraft_inventory_id AND status='reserved') THEN RETURN jsonb_build_object('status','blocked_aircraft_relocation_reserved','scheduleActivated',false,'ledgerPosted',false);END IF;
 IF target.status IS DISTINCT FROM 'draft'
    OR target.operationally_verified IS DISTINCT FROM false
 THEN RETURN jsonb_build_object(
   'status','blocked_schedule_not_draft','scheduleId',p_schedule,
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 -- Re-check full real-world and game certification, current clock, slots,
 -- crew, aircraft, route rights and source evidence inside the same lock.
 approval:=airlinerra_game.section9_prepare_certified_schedule_activation_v1(
   p_player,p_airline,p_schedule,p_expected_version,p_game_date,p_days);
 IF approval->>'status' IS DISTINCT FROM 'prepared_for_future_activation_commit'
    OR approval->>'prepared' IS DISTINCT FROM 'true'
    OR approval->>'flightActivated' IS DISTINCT FROM 'false'
    OR approval->>'movementRecorded' IS DISTINCT FROM 'false'
    OR approval->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
    'status','blocked_activation_not_fully_certified',
    'scheduleId',p_schedule,
    'blockers',coalesce(approval->'blockers','[]'::jsonb),
    'scheduleActivated',false,'flightActivated',false,
    'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT * INTO proof
 FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=p_schedule AND schedule_version=p_expected_version
 AND airline_id=p_airline AND aircraft_inventory_id=target.aircraft_inventory_id
 FOR SHARE;
 IF NOT FOUND
  OR proof.verified_game_date IS DISTINCT FROM p_game_date
  OR proof.certified_horizon_days IS DISTINCT FROM p_days
  OR proof.fingerprint_md5 IS DISTINCT FROM approval->>'fingerprint'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVATION_PREPARATION_CHANGED';END IF;

 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET status='active',operationally_verified=true,updated_at=clock_timestamp()
 WHERE id=p_schedule AND version=p_expected_version AND world_id=1
   AND airline_id=p_airline AND status='draft' AND operationally_verified=false;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ACTIVATION_ATOMIC_UPDATE_NOT_CONFIRMED';END IF;
 RETURN jsonb_build_object(
  'status','certified_schedule_activated','worldId',1,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'certifiedThroughGameDate',p_game_date+p_days,
  'scheduleActivated',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_create_active_single_route_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_flight text, p_origin text, p_destination text, p_dep timestamp with time zone, p_arr timestamp with time zone, p_weekly jsonb, p_depart_stand text, p_arrive_stand text, p_turnaround integer, p_fare numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE clk jsonb;day date;owner_row record;fleet_row record;cfg record;payload record;
 saved jsonb;plan jsonb;first_leg jsonb;cert jsonb;activation jsonb;capacity jsonb;ticket jsonb;
 schedule_id uuid;ver int;seats int;kind text;item record;win jsonb;opened int:=0;
 failure jsonb;rotation jsonb;prior_scope text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_ROUTE_CREATION_ONLY';END IF;
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL OR p_flight IS NULL OR p_flight!~'^[A-Z0-9]{2}[0-9]{1,4}$'
 OR p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
 OR p_dep IS NULL OR p_arr IS NULL OR p_arr<=p_dep OR p_arr>p_dep+interval '72 hours'
 OR p_turnaround IS NULL OR p_turnaround NOT BETWEEN 45 AND 360
 OR p_fare IS NULL OR p_fare NOT BETWEEN 1 AND 100000
 THEN RETURN jsonb_build_object('status','blocked_invalid_route_inputs','routeCreated',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1 AND release_state='enabled' AND crew_mode='deferred_phase1' FOR SHARE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked_commercial_engine_not_released','routeCreated',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1 AND release_state='enabled')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_fuel_and_settlement_release_policy_v1 WHERE world_id=1 AND release_state='enabled')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1 AND release_state='approved')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1 AND trusted_flight_execution_release='ACTIVATED' AND fuel_transaction_release='ACTIVATED' AND automatic_flight_and_fuel_settlement_enabled)
 THEN RETURN jsonb_build_object('status','blocked_commercial_engine_not_released','routeCreated',false);END IF;
 clk:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clk->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','blocked_game_clock','routeCreated',false);END IF;
 day:=(clk->>'gameDate')::date;
 SELECT a.id,a.iata_code INTO owner_row FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player FOR UPDATE OF a;
 IF NOT FOUND OR left(p_flight,2) IS DISTINCT FROM owner_row.iata_code THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='ROUTE_AIRLINE_NOT_OWNED';END IF;
 SELECT * INTO fleet_row FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND airline_id=p_airline FOR UPDATE;
 IF NOT FOUND OR fleet_row.fleet_status IS DISTINCT FROM 'in_service' OR fleet_row.ownership_type NOT IN ('owned','leased')
 THEN RETURN jsonb_build_object('status','blocked_aircraft_not_in_service','routeCreated',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved') THEN RETURN jsonb_build_object('status','blocked_aircraft_relocation_reserved','routeCreated',false);END IF;
 SELECT * INTO cfg FROM airlinerra.aircraft_configurations WHERE id=fleet_row.configuration_id;
 SELECT * INTO payload FROM airlinerra.aircraft_service_payload_game_v1 WHERE configuration_id=fleet_row.configuration_id;
 IF cfg.use_type IS DISTINCT FROM 'passenger' OR coalesce(payload.simultaneous_passenger_seats,0)<=0 OR coalesce(cfg.maximum_passenger_seats,0)<=0
 THEN RETURN jsonb_build_object('status','blocked_passenger_capacity_unverified','routeCreated',false);END IF;
 seats:=least(1000,payload.simultaneous_passenger_seats,cfg.maximum_passenger_seats);
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE airline_id=p_airline AND flight_number=p_flight)
 THEN RETURN jsonb_build_object('status','blocked_flight_number_exists','routeCreated',false);END IF;
 prior_scope:=current_setting('airlinerra.single_route_create',true);
 -- Subtransaction: every failure, including a returned negative receipt,
 -- rolls back ALL draft rows, slots, fare records, certificates and tickets.
 BEGIN
  failure:=jsonb_build_object('status','blocked_schedule_or_slots');
  saved:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(p_player,p_airline,p_aircraft,p_flight,p_origin,p_destination,p_dep,p_arr,p_weekly,NULL::uuid,p_depart_stand,p_arrive_stand);
  IF saved->>'status' IS DISTINCT FROM 'draft' OR saved->>'slotsReserved' IS DISTINCT FROM 'true' THEN failure:=failure||jsonb_build_object('details',saved);RAISE SQLSTATE 'P9001';END IF;
  schedule_id:=(saved->>'scheduleId')::uuid;ver:=(saved->>'version')::int;
  first_leg:=airlinerra_game.section9_single_route_first_departure_v1(p_player,p_airline,schedule_id,day);
  IF first_leg->>'valid' IS DISTINCT FROM 'true' THEN failure:=jsonb_build_object('status','blocked_first_departure','details',first_leg);RAISE SQLSTATE 'P9001';END IF;
  plan:=airlinerra_game.section9_save_owned_commercial_plan_v1(p_player,p_airline,schedule_id,p_fare,0,0);
  IF (plan->>'economyFareUsd')::numeric IS DISTINCT FROM p_fare OR plan->>'bookingsEnabled' IS DISTINCT FROM 'false'
  THEN failure:=jsonb_build_object('status','blocked_fare_save');RAISE SQLSTATE 'P9001';END IF;
  -- The slot authority verifies the same version-bound payload row.
  -- Reserve capacity before signing; it is invisible until this transaction commits.
  INSERT INTO airlinerra_game.section9_verified_schedule_capacity_v1
   (schedule_id,airline_id,schedule_version,passenger_seats,cargo_capacity_tonnes,verification_source)
  VALUES(schedule_id,p_airline,ver,seats,0,'GAME_SIMULTANEOUS_PASSENGER_PAYLOAD_CERTIFIED_V1');
  FOREACH kind IN ARRAY ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance'] LOOP
   cert:=airlinerra_game.section9_issue_queued_game_clearance_v1(p_airline,schedule_id,ver,day,kind);
   IF coalesce(cert->>'status','') NOT IN ('certification_event_recorded','certification_event_replayed')
   THEN failure:=jsonb_build_object('status','blocked_operational_requirement','clearanceType',kind,'details',cert);RAISE SQLSTATE 'P9001';END IF;
  END LOOP;
  PERFORM set_config('airlinerra.single_route_create',schedule_id::text,true);
  activation:=airlinerra_game.section9_commit_certified_schedule_activation_v1(p_player,p_airline,schedule_id,ver,day,28);
  IF activation->>'status' IS DISTINCT FROM 'certified_schedule_activated' OR activation->>'scheduleActivated' IS DISTINCT FROM 'true' OR activation->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN failure:=jsonb_build_object('status','blocked_activation','details',activation);RAISE SQLSTATE 'P9001';END IF;
  -- Capacity remains identical to the signed slot proof; do not update it here.
  FOR item IN SELECT d::date AS date,w.ordinality::int AS entry
   FROM generate_series(day,day+7,interval '1 day') d
   CROSS JOIN LATERAL jsonb_array_elements(p_weekly) WITH ORDINALITY w(value,ordinality)
   WHERE (w.value->>'day')::int=extract(isodow from d)::int-1
  LOOP
   win:=airlinerra_game.section9_verified_saleable_departure_window_v1(schedule_id,item.date,item.entry,(clk->>'gameHourUtc')::timestamptz);
   IF win->>'withinWindow' IS DISTINCT FROM 'true' THEN CONTINUE;END IF;
   ticket:=airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(schedule_id,item.date,item.entry);
   IF ticket->>'status' IS DISTINCT FROM 'verified_ticket_sales_open' OR ticket->>'sevenDayWindowVerified' IS DISTINCT FROM 'true' OR (ticket->>'passengerSeats')::int IS DISTINCT FROM seats OR ticket->>'ledgerPosted' IS DISTINCT FROM 'false'
   THEN failure:=jsonb_build_object('status','blocked_ticket_inventory','details',ticket);RAISE SQLSTATE 'P9001';END IF;
   opened:=opened+1;
  END LOOP;
  IF opened=0 THEN failure:=jsonb_build_object('status','blocked_no_bookable_departure');RAISE SQLSTATE 'P9001';END IF;
  rotation:=airlinerra_game.section9_owned_aircraft_rotation_preview_v1(p_player,p_airline,schedule_id,day,28);
  PERFORM set_config('airlinerra.single_route_create',coalesce(prior_scope,''),true);
  RETURN jsonb_build_object('status','active','routeCreated',true,'activated',true,'slotsReserved',true,'bookingEnabled',true,'scheduleId',schedule_id,'scheduleVersion',ver,'saleableDepartures',opened,'futurePositionWarnings',rotation->'wrongAirportDepartures','ledgerPosted',false);
 EXCEPTION WHEN SQLSTATE 'P9001' THEN
  RETURN coalesce(failure,jsonb_build_object('status','blocked_route_creation'))||jsonb_build_object('routeCreated',false,'activated',false,'slotsReserved',false,'bookingEnabled',false,'ledgerPosted',false);
 END;
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_job_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_action text, p_check_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_now timestamptz; f record; pos jsonb; policy record; slot_proof jsonb;
 active_job record; next_start timestamptz;
 j_id uuid; jobs jsonb; completed integer; setup record;
 quote_usd numeric; available_usd numeric; quotes jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
    OR p_action NOT IN ('status','book','cancel') OR p_action IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_MAINTENANCE_JOB_ACTION';END IF;
 SELECT fleet.id,fleet.airline_id,fleet.registration,fleet.configuration_id,
        fleet.fleet_status,airline.home_airport_key
 INTO f FROM airlinerra_game.airline_aircraft_inventory fleet
 JOIN airlinerra_game.airlines airline ON airline.id=fleet.airline_id
   AND airline.world_id=1 AND airline.owner_player_id=p_player
 JOIN airlinerra_game.world_memberships w
 ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE fleet.id=p_aircraft AND fleet.airline_id=p_airline
 AND fleet.ownership_type IN ('owned','leased')
 FOR UPDATE OF fleet;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_MAINTENANCE_JOB_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF f.fleet_status<>'in_service' THEN RAISE EXCEPTION USING ERRCODE='55000',
 MESSAGE='SECTION9_AIRCRAFT_NOT_IN_SERVICE';END IF;
 SELECT jsonb_agg(jsonb_build_object(
  'jobId',j.job_id,'checkCode',j.check_code,'airportKey',j.airport_key,
  'gameStartUtc',j.game_start_utc,'gameEndUtc',j.game_end_utc,
  'status',j.status,'quotedCostUsd',j.quoted_cost_usd,'providerKey',j.provider_key,'providerName',j.provider_name,'durationMinutes',coalesce(j.duration_minutes,j.duration_hours*60),
  'costPosted',j.paid_ledger_entry_id IS NOT NULL,'isGameService',true)
  ORDER BY j.created_at DESC)
 INTO jobs FROM (
  SELECT * FROM airlinerra_game.section9_game_maintenance_jobs_v1
  WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
  ORDER BY created_at DESC LIMIT 15
 ) j;
 SELECT jsonb_object_agg(check_code,base_estimate_usd) INTO quotes
 FROM airlinerra_game.aircraft_maintenance_check_overview_v1
 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
 AND cost_evidence='provisional_game_tariff_not_vendor_quote' AND base_estimate_usd>0;
 IF p_action='status' THEN
  RETURN jsonb_build_object('status','game_maintenance_jobs',
   'jobs',coalesce(jobs,'[]'::jsonb),
   'quotedGameServicePricesUsd',coalesce(quotes,'{}'::jsonb),
   'tariffSource','provisional_game_tariff_not_vendor_quote',
   'gameNowUtc',v_now,'aircraftGroundedForJob',
   EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1
    WHERE aircraft_inventory_id=p_aircraft AND status IN ('in_progress','payment_required')),
   'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_action IN ('book','cancel') AND EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved') THEN RETURN jsonb_build_object('status','aircraft_relocation_already_reserved','created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF p_action='cancel' THEN
  UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
  SET status='cancelled'
  WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
   AND status='scheduled' AND game_start_utc>v_now
  RETURNING job_id INTO j_id;
  IF j_id IS NULL THEN RETURN jsonb_build_object('status','no_cancelable_service',
    'changed',false,'flightActivated',false,'ledgerPosted',false);END IF;
  RETURN jsonb_build_object('status','cancelled','jobId',j_id,
   'changed',true,'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_check_code IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_MAINTENANCE_CHECK_REQUIRED';END IF;
 SELECT * INTO policy FROM airlinerra_game.maintenance_check_policy_v1
 WHERE check_code=p_check_code;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_UNKNOWN_MAINTENANCE_CHECK';END IF;
 -- Booking now must use only the fully trusted current instant; a future
 -- start can be added once reliable aircraft-time rotation reservations exist.
 next_start:=date_trunc('minute',v_now)+interval '2 minutes';
 SELECT * INTO setup
 FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b
 JOIN airlinerra_game.aircraft_maintenance_state_v1 m
 ON m.aircraft_inventory_id=b.aircraft_inventory_id
 AND m.airline_id=b.airline_id
 WHERE b.aircraft_inventory_id=p_aircraft AND b.airline_id=p_airline
 AND b.owner_player_id=p_player;
 IF NOT FOUND OR setup.tracked_flight_hours IS NULL OR
    setup.game_baseline_date> (v_now AT TIME ZONE 'Europe/Berlin')::date
 THEN RETURN jsonb_build_object('status','missing_game_airframe_baseline',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
  p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified'<>'true' OR pos->>'atGroundAirport'<>'true'
   OR pos->>'airportKey' IS NULL
 THEN RETURN jsonb_build_object('status','aircraft_location_unverified',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.approved_game_airports a
  WHERE a.world_id=1 AND a.airport_key=pos->>'airportKey'
 ) THEN RETURN jsonb_build_object('status','airport_not_in_game',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF policy.airport_scope='type_approved_mro' AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.maintenance_airport_capabilities_v1 a
 WHERE a.world_id=1 AND a.airport_key=pos->>'airportKey'
 AND a.configuration_id=f.configuration_id
 AND a.check_code=policy.check_code
 AND a.approval_status='game_approved')
 THEN RETURN jsonb_build_object('status','airport_not_approved_for_heavy_check',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
  WHERE j.aircraft_inventory_id=p_aircraft
  AND j.status IN ('scheduled','in_progress','payment_required'))
 THEN RETURN jsonb_build_object('status','aircraft_already_booked_for_maintenance',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 slot_proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(
    p_player,p_airline,p_aircraft,next_start,
    next_start+make_interval(hours=>policy.downtime_hours));
 IF slot_proof->>'status' IS DISTINCT FROM 'hourly_maintenance_slot_clear'
 OR slot_proof->>'slotClear' IS DISTINCT FROM 'true'
 OR slot_proof->>'readOnly' IS DISTINCT FROM 'true'
 OR slot_proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
   'status','aircraft_flight_or_slot_conflict_not_clear',
   'hourAccurateConflictCheck',true,
   'slotStatus',slot_proof->>'status',
   'slotEvidence',slot_proof,
   'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT base_estimate_usd INTO quote_usd
 FROM airlinerra_game.aircraft_maintenance_check_overview_v1
 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
 AND check_code=policy.check_code
 AND cost_evidence='provisional_game_tariff_not_vendor_quote';
 IF NOT FOUND OR quote_usd IS NULL OR quote_usd<=0 THEN
  RETURN jsonb_build_object('status','game_maintenance_cost_unverified',
   'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO available_usd
 FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF available_usd<quote_usd THEN
  RETURN jsonb_build_object('status','game_maintenance_insufficient_funds',
   'created',false,'requiredUsd',quote_usd,'balanceUsd',available_usd,
   'flightActivated',false,'ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_game_maintenance_jobs_v1
  (owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,
   game_start_utc,game_end_utc,duration_hours,condition_before_game_pct,
   flight_hours_at_book,quoted_cost_usd)
 VALUES(p_player,p_airline,p_aircraft,policy.check_code,pos->>'airportKey',
  next_start,next_start+make_interval(hours=>policy.downtime_hours),
  policy.downtime_hours,(airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,v_now)->>'conditionPct')::numeric,setup.tracked_flight_hours,quote_usd)
 RETURNING job_id INTO j_id;
 RETURN jsonb_build_object('status','scheduled','created',true,
  'jobId',j_id,'checkCode',policy.check_code,'airportKey',pos->>'airportKey',
  'startUtc',next_start,
  'endUtc',next_start+make_interval(hours=>policy.downtime_hours),
  'gameJobOnly',true,'groundDuringService',true,
  'quotedCostUsd',quote_usd,'chargedNow',false,
  'chargedAtServiceCompletion',true,
  'tariffSource','provisional_game_tariff_not_vendor_quote',
  'physicalInspectionVerified',false,'flightActivated',false,'ledgerPosted',false);
END $function$;
COMMIT;
