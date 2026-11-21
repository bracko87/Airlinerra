-- Single route creation: either commit all slots, signed approvals and inventory,
-- or roll back all changes. No player-visible intermediate route is created.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_single_route_first_departure_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_day date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE target record;position jsonb;clock_proof jsonb;now_utc timestamptz;
 airport text;ready_at timestamptz;occ record;maintenance jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_ROUTE_CREATION_ONLY';END IF;
 SELECT s.* INTO target FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id AND a.owner_player_id=p_player
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF NOT FOUND THEN RETURN jsonb_build_object('valid',false,'reason','ROUTE_NOT_OWNED');END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' OR clock_proof->>'gameDate' IS DISTINCT FROM p_day::text
 THEN RETURN jsonb_build_object('valid',false,'reason','GAME_CLOCK_NOT_READY');END IF;
 now_utc:=(clock_proof->>'gameHourUtc')::timestamptz;
 position:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,target.aircraft_inventory_id,p_day);
 IF position->>'verified' IS DISTINCT FROM 'true' OR position->>'atGroundAirport' IS DISTINCT FROM 'true' OR position->>'airportKey' IS NULL
 THEN RETURN jsonb_build_object('valid',false,'reason','AIRCRAFT_POSITION_NOT_VERIFIED');END IF;
 airport:=position->>'airportKey';ready_at:=now_utc;
 -- Only the candidate and already active schedules can move this aircraft.
 -- A future leg that cannot run never teleports the aircraft. Stop at the
 -- first candidate departure: later recurring location gaps are warnings.
 FOR occ IN
  WITH schedules AS (
   SELECT s.*,a.timezone_iana FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
   JOIN airlinerra_game.airport_reference_profiles a ON a.world_id=s.world_id AND a.airport_key=s.origin_airport_key
   JOIN pg_catalog.pg_timezone_names z ON z.name=a.timezone_iana
   WHERE s.world_id=1 AND s.airline_id=p_airline AND s.aircraft_inventory_id=target.aircraft_inventory_id
   AND (s.id=p_schedule OR (s.status='active' AND s.operationally_verified))
  ), departures AS (
   SELECT s.id,s.origin_airport_key,s.destination_airport_key,
    (d::date+(w->>'time')::time) AT TIME ZONE s.timezone_iana AS dep,
    s.reference_arrival_utc-s.reference_departure_utc AS duration,
    s.reference_departure_utc AS reference_dep
   FROM schedules s CROSS JOIN generate_series(p_day-1,p_day+8,interval '1 day') d
    CROSS JOIN LATERAL jsonb_array_elements(s.weekly_schedule) w
   WHERE (w->>'day')::int=extract(isodow from d)::int-1
  )
  SELECT *,dep+duration AS arr FROM departures
  WHERE dep>now_utc AND dep>=reference_dep
  ORDER BY dep,id
 LOOP
  IF occ.id=p_schedule THEN
   IF airport IS DISTINCT FROM occ.origin_airport_key THEN
    RETURN jsonb_build_object('valid',false,'reason','AIRCRAFT_CANNOT_REACH_FIRST_DEPARTURE','expectedAirport',airport,'requiredAirport',occ.origin_airport_key,'departureUtc',occ.dep);
   END IF;
   IF ready_at>occ.dep THEN RETURN jsonb_build_object('valid',false,'reason','FIRST_DEPARTURE_TURNAROUND_CONFLICT');END IF;
   maintenance:=airlinerra_game.section9_owned_game_maintenance_flight_window_v1(p_player,p_airline,target.aircraft_inventory_id,occ.dep,occ.arr);
   IF maintenance->>'flightWindowClear' IS DISTINCT FROM 'true' THEN
    RETURN jsonb_build_object('valid',false,'reason','MAINTENANCE_FLIGHT_WINDOW_BLOCKED','blockers',maintenance->'blockers');END IF;
   RETURN jsonb_build_object('valid',true,'departureUtc',occ.dep,'arrivalUtc',occ.arr);
  END IF;
  IF airport=occ.origin_airport_key AND ready_at<=occ.dep THEN
   airport:=occ.destination_airport_key;ready_at:=occ.arr+interval '45 minutes';
  END IF;
 END LOOP;
 RETURN jsonb_build_object('valid',false,'reason','NO_UPCOMING_DEPARTURE');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_single_route_first_departure_v1(uuid,uuid,uuid,date) FROM PUBLIC,anon,authenticated,service_role;

-- Keep the existing strict pair certification behavior. Only the trusted
-- atomic single-route transaction may use its first-departure proof in place
-- of requiring every subsequent recurring position gap to be resolved.
DO $patch$
DECLARE def text; old_clause text; new_clause text;
BEGIN
 SELECT pg_get_functiondef('airlinerra_game.section9_owned_commercial_activation_preflight_v1(uuid,uuid,uuid,date,integer)'::regprocedure) INTO def;
 old_clause:='AND coalesce((rotation->>''wrongAirportDepartures'')::integer,-1)=0';
 new_clause:='AND (coalesce((rotation->>''wrongAirportDepartures'')::integer,-1)=0 OR (current_user=''postgres'' AND current_setting(''airlinerra.single_route_create'',true)=p_schedule::text AND airlinerra_game.section9_single_route_first_departure_v1(p_player,p_airline,p_schedule,p_date)->>''valid''=''true''))';
 IF strpos(def,new_clause)=0 THEN
  IF strpos(def,old_clause)=0 THEN RAISE EXCEPTION 'Unexpected activation preflight definition';END IF;
  EXECUTE replace(def,old_clause,new_clause);
 END IF;
END $patch$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_create_active_single_route_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_flight text,p_origin text,p_destination text,
 p_dep timestamptz,p_arr timestamptz,p_weekly jsonb,p_depart_stand text,p_arrive_stand text,
 p_turnaround integer,p_fare numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
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
  FOREACH kind IN ARRAY ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance'] LOOP
   cert:=airlinerra_game.section9_issue_queued_game_clearance_v1(p_airline,schedule_id,ver,day,kind);
   IF coalesce(cert->>'status','') NOT IN ('certification_event_recorded','certification_event_replayed')
   THEN failure:=jsonb_build_object('status','blocked_operational_requirement','clearanceType',kind,'details',cert);RAISE SQLSTATE 'P9001';END IF;
  END LOOP;
  PERFORM set_config('airlinerra.single_route_create',schedule_id::text,true);
  activation:=airlinerra_game.section9_commit_certified_schedule_activation_v1(p_player,p_airline,schedule_id,ver,day,28);
  IF activation->>'status' IS DISTINCT FROM 'certified_schedule_activated' OR activation->>'scheduleActivated' IS DISTINCT FROM 'true' OR activation->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN failure:=jsonb_build_object('status','blocked_activation','details',activation);RAISE SQLSTATE 'P9001';END IF;
  capacity:=airlinerra_game.section9_register_verified_schedule_capacity_v1(schedule_id,p_airline,seats,0,'GAME_SIMULTANEOUS_PASSENGER_PAYLOAD_CERTIFIED_V1');
  IF capacity->>'verified' IS DISTINCT FROM 'true' OR (capacity->>'passengerSeats')::int IS DISTINCT FROM seats
  THEN failure:=jsonb_build_object('status','blocked_capacity');RAISE SQLSTATE 'P9001';END IF;
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
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_create_active_single_route_v1(uuid,uuid,uuid,text,text,text,timestamptz,timestamptz,jsonb,text,text,integer,numeric) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
