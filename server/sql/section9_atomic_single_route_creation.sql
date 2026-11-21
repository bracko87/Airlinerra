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

-- Server-owned timetable derived from actual game time, airport local time and
-- the same short-sector / aircraft-size model used by the browser forecast.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_route_timing_pick_v1(p_seed text,p_low int,p_high int)
RETURNS int LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path TO 'pg_catalog' AS $fn$
DECLARE h bigint:=2166136261;i int;
BEGIN
 FOR i IN 1..length(p_seed) LOOP
  h:=((h # ascii(substr(p_seed,i,1))::bigint)*16777619)%4294967296;
 END LOOP;
 RETURN p_low+(h%(p_high-p_low+1))::int;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_route_timing_pick_v1(text,int,int) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_create_active_route_from_weekly_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_flight text,p_origin text,p_destination text,
 p_weekly jsonb,p_depart_stand text,p_arrive_stand text,p_turnaround int,p_fare numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog' AS $fn$
DECLARE origin record;destination record;aircraft record;clock_proof jsonb;now_utc timestamptz;
 first_dep timestamptz;first_arr timestamptz;seed text;km numeric;speed numeric;
 taxi_factor numeric;climb_factor numeric;climb_base numeric;descent_base numeric;
 taxi_out numeric;taxi_in numeric;climb numeric;descent numeric;cruise numeric;scale numeric;minutes int;
 out_low int;out_high int;in_low int;in_high int;result jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_ROUTE_CREATION_ONLY';END IF;
 IF p_weekly IS NULL OR jsonb_typeof(p_weekly)<>'array' OR jsonb_array_length(p_weekly) NOT BETWEEN 1 AND 7
 THEN RETURN jsonb_build_object('status','blocked_invalid_weekly_schedule','routeCreated',false);END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_weekly) w WHERE coalesce(w->>'day','')!~'^[0-6] OR coalesce(w->>'time','')!~'^([01][0-9]|2[0-3]):[0-5][0-9])
 OR (SELECT count(DISTINCT w->>'day') FROM jsonb_array_elements(p_weekly) w)<>jsonb_array_length(p_weekly)
 THEN RETURN jsonb_build_object('status','blocked_invalid_weekly_schedule','routeCreated',false);END IF;
 SELECT a.*,u.game_category INTO origin FROM airlinerra_game.airport_reference_profiles a
 JOIN airlinerra_game.airport_unified_operations_v1 u ON u.world_id=a.world_id AND u.airport_key=a.airport_key
 JOIN pg_catalog.pg_timezone_names z ON z.name=a.timezone_iana
 WHERE a.world_id=1 AND a.airport_key=p_origin;
 SELECT a.*,u.game_category INTO destination FROM airlinerra_game.airport_reference_profiles a
 JOIN airlinerra_game.airport_unified_operations_v1 u ON u.world_id=a.world_id AND u.airport_key=a.airport_key
 JOIN pg_catalog.pg_timezone_names z ON z.name=a.timezone_iana
 WHERE a.world_id=1 AND a.airport_key=p_destination;
 IF origin.airport_key IS NULL OR destination.airport_key IS NULL OR origin.latitude_deg IS NULL OR origin.longitude_deg IS NULL OR destination.latitude_deg IS NULL OR destination.longitude_deg IS NULL
 THEN RETURN jsonb_build_object('status','blocked_airport_reference_unavailable','routeCreated',false);END IF;
 SELECT f.configuration_id,m.cruise_speed_kmh,c.mtow_kg INTO aircraft
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.section9_game_fuel_model_snapshot_v1 m ON m.configuration_id=f.configuration_id
 LEFT JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=f.configuration_id
 WHERE f.id=p_aircraft AND f.airline_id=p_airline AND f.fleet_status='in_service';
 IF NOT FOUND OR coalesce(aircraft.cruise_speed_kmh,0)<=0 THEN RETURN jsonb_build_object('status','blocked_aircraft_performance_unavailable','routeCreated',false);END IF;
 speed:=aircraft.cruise_speed_kmh;
 km:=round((6371.0088*acos(least(1.0,greatest(-1.0,sin(radians(origin.latitude_deg::float8))*sin(radians(destination.latitude_deg::float8))+cos(radians(origin.latitude_deg::float8))*cos(radians(destination.latitude_deg::float8))*cos(radians((destination.longitude_deg-origin.longitude_deg)::float8))))))::numeric);
 IF km<=0 THEN RETURN jsonb_build_object('status','blocked_invalid_route_distance','routeCreated',false);END IF;
 seed:=p_origin||'|'||p_destination;
 SELECT lo,hi INTO out_low,out_high FROM (VALUES ('Local',3,9),('Regional',5,11),('Medium',7,14),('Large',9,17),('Major Hub',12,21),('Mega Hub',15,28)) t(category,lo,hi) WHERE category=origin.game_category;
 SELECT lo,hi INTO in_low,in_high FROM (VALUES ('Local',3,6),('Regional',4,8),('Medium',5,10),('Large',7,12),('Major Hub',9,15),('Mega Hub',11,19)) t(category,lo,hi) WHERE category=destination.game_category;
 taxi_factor:=CASE WHEN aircraft.mtow_kg IS NULL OR aircraft.mtow_kg<=0 THEN 1 WHEN aircraft.mtow_kg<20000 THEN .8 WHEN aircraft.mtow_kg<50000 THEN .9 WHEN aircraft.mtow_kg<100000 THEN 1 WHEN aircraft.mtow_kg<200000 THEN 1.15 ELSE 1.3 END;
 taxi_out:=greatest(1,round(airlinerra_game.section9_route_timing_pick_v1(seed||'|taxi-out',coalesce(out_low,7),coalesce(out_high,14))*taxi_factor));
 taxi_in:=greatest(1,round(airlinerra_game.section9_route_timing_pick_v1(seed||'|taxi-in',coalesce(in_low,5),coalesce(in_high,10))*taxi_factor));
 climb_factor:=least(1,greatest(.35,(km/speed*60+10)/45));
 climb_base:=airlinerra_game.section9_route_timing_pick_v1(seed||'|climb',CASE WHEN km<300 THEN 10 ELSE 12 END,CASE WHEN km<300 THEN 14 ELSE 20 END);
 descent_base:=airlinerra_game.section9_route_timing_pick_v1(seed||'|descent',CASE WHEN km<300 THEN 10 ELSE 12 END,CASE WHEN km<300 THEN 14 ELSE 20 END);
 climb:=greatest(3,round(climb_base*climb_factor));descent:=greatest(3,round(descent_base*climb_factor));
 scale:=least(1,km/((climb+descent)*speed*.65/60));
 cruise:=greatest(0,km-(climb+descent)*speed*.65/60*scale)/speed*60;
 minutes:=greatest(1,round(taxi_out+taxi_in+(climb+descent)*scale+cruise)::int);
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','blocked_game_clock','routeCreated',false);END IF;
 now_utc:=(clock_proof->>'gameHourUtc')::timestamptz;
 SELECT min((d::date+(w->>'time')::time) AT TIME ZONE origin.timezone_iana) INTO first_dep
 FROM generate_series((now_utc AT TIME ZONE origin.timezone_iana)::date,(now_utc AT TIME ZONE origin.timezone_iana)::date+7,interval '1 day') d
 CROSS JOIN LATERAL jsonb_array_elements(p_weekly) w
 WHERE (w->>'day')::integer=extract(isodow from d)::int-1
 AND ((d::date+(w->>'time')::time) AT TIME ZONE origin.timezone_iana)>now_utc;
 IF first_dep IS NULL THEN RETURN jsonb_build_object('status','blocked_no_upcoming_departure','routeCreated',false);END IF;
 first_arr:=first_dep+make_interval(mins=>minutes);
 result:=airlinerra_game.section9_create_active_single_route_v1(p_player,p_airline,p_aircraft,p_flight,p_origin,p_destination,first_dep,first_arr,p_weekly,p_depart_stand,p_arrive_stand,p_turnaround,p_fare);
 IF result->>'routeCreated'='true' THEN
  -- Persist the existing My Routes editor metadata INSIDE the same successful
  -- transaction. This is not an intermediate route and cannot survive failure.
  INSERT INTO airlinerra_game.airline_route_planning_drafts_v1 AS meta
   (world_id,airline_id,aircraft_inventory_id,flight_number,origin_airport_key,destination_airport_key,weekly_schedule,
    departure_stand_type,arrival_stand_type,turnaround_minutes,planning_options,reference_departure_utc,reference_arrival_utc,created_by_player_id)
  VALUES (1,p_airline,p_aircraft,p_flight,p_origin,p_destination,p_weekly,p_depart_stand,p_arrive_stand,p_turnaround,
   jsonb_build_object('fares',jsonb_build_object('economy',p_fare,'premium',NULL,'business',NULL,'first',NULL),
    'service',jsonb_build_object('onboard','basic','baggage','standard','cargo','none','cabinPackageId','basic'),'launchDelayDays',0),
   first_dep,first_arr,p_player)
  ON CONFLICT(airline_id,flight_number) DO UPDATE SET aircraft_inventory_id=excluded.aircraft_inventory_id,
   origin_airport_key=excluded.origin_airport_key,destination_airport_key=excluded.destination_airport_key,
   weekly_schedule=excluded.weekly_schedule,departure_stand_type=excluded.departure_stand_type,
   arrival_stand_type=excluded.arrival_stand_type,turnaround_minutes=excluded.turnaround_minutes,
   planning_options=excluded.planning_options,reference_departure_utc=excluded.reference_departure_utc,
   reference_arrival_utc=excluded.reference_arrival_utc,updated_at=now(),version=meta.version+1;
  result:=result||jsonb_build_object('referenceDepartureUtc',first_dep,'referenceArrivalUtc',first_arr,'estimatedDurationMinutes',minutes);
 END IF;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_create_active_route_from_weekly_v1(uuid,uuid,uuid,text,text,text,jsonb,text,text,int,numeric) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
