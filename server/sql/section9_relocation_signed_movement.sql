BEGIN;
ALTER TABLE airlinerra_game.section9_relocation_release_v1 ADD COLUMN IF NOT EXISTS execution_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE airlinerra_game.section9_maintenance_relocation_trips_v1 ADD COLUMN IF NOT EXISTS maintenance_job_id uuid REFERENCES airlinerra_game.section9_game_maintenance_jobs_v1(job_id);
-- A physical flight must have exactly one parent: commercial schedule or a dated relocation.
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1 ADD COLUMN IF NOT EXISTS relocation_trip_id uuid REFERENCES airlinerra_game.section9_maintenance_relocation_trips_v1(id);
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1 ALTER COLUMN schedule_id DROP NOT NULL;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1 DROP CONSTRAINT section9_operated_flight_movements_v1_check2;
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1 ADD CONSTRAINT section9_movement_exact_parent_v2 CHECK(
 (schedule_id IS NOT NULL AND relocation_trip_id IS NULL OR schedule_id IS NULL AND relocation_trip_id IS NOT NULL AND schedule_version=1 AND weekly_entry IN (1,2))
 AND flight_occurrence_id=coalesce(schedule_id,relocation_trip_id)::text||':'||flight_local_date::text||':'||weekly_entry::text);
CREATE INDEX IF NOT EXISTS section9_movements_relocation_trip_idx ON airlinerra_game.section9_operated_flight_movements_v1(relocation_trip_id) WHERE relocation_trip_id IS NOT NULL;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_relocation_leg_evidence_v1(p_physical text)
RETURNS TABLE(trip_id uuid,airline_id uuid,aircraft_inventory_id uuid,owner_player_id uuid,configuration_id bigint,origin_airport_key text,destination_airport_key text,departure_utc timestamptz,arrival_utc timestamptz,flight_local_date date,leg_number integer,leg text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
 SELECT t.id,t.airline_id,t.aircraft_inventory_id,t.owner_player_id,f.configuration_id,
 CASE WHEN l.n=1 THEN t.origin_airport_key ELSE t.provider_airport_key END,
 CASE WHEN l.n=1 THEN t.provider_airport_key ELSE t.origin_airport_key END,
 (t.quote->l.name->>'departureUtc')::timestamptz,(t.quote->l.name->>'arrivalUtc')::timestamptz,
 ((t.quote->l.name->>'departureUtc')::timestamptz AT TIME ZONE 'UTC')::date,l.n,l.name
 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t
 JOIN airlinerra_game.airline_aircraft_inventory f ON f.id=t.aircraft_inventory_id AND f.airline_id=t.airline_id AND f.fleet_status='in_service' AND f.ownership_type IN ('owned','leased')
 JOIN airlinerra_game.airlines a ON a.id=t.airline_id AND a.owner_player_id=t.owner_player_id AND a.world_id=1
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=t.owner_player_id AND w.state='active'
 CROSS JOIN (VALUES(1,'outbound'),(2,'return')) l(n,name)
 WHERE current_user='postgres' AND t.world_id=1 AND t.status='reserved' AND t.quote->>'passengers'='0' AND t.quote->>'ticketRevenueUsd'='0'
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled)
 AND p_physical=t.id::text||':'||((t.quote->l.name->>'departureUtc')::timestamptz AT TIME ZONE 'UTC')::date::text||':'||l.n::text
 AND EXISTS(SELECT 1 FROM airlinerra_game.section6_dated_relocation_slots_v1 s WHERE s.trip_id=t.id AND s.leg=l.name AND s.direction='departure' AND s.airport_key=CASE WHEN l.n=1 THEN t.origin_airport_key ELSE t.provider_airport_key END AND s.movement_utc=(t.quote->l.name->>'departureUtc')::timestamptz)
 AND EXISTS(SELECT 1 FROM airlinerra_game.section6_dated_relocation_slots_v1 s WHERE s.trip_id=t.id AND s.leg=l.name AND s.direction='arrival' AND s.airport_key=CASE WHEN l.n=1 THEN t.provider_airport_key ELSE t.origin_airport_key END AND s.movement_utc=(t.quote->l.name->>'arrivalUtc')::timestamptz)
 AND (l.n=1 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 r JOIN airlinerra_game.section9_game_maintenance_jobs_v1 j ON j.job_id=r.job_id AND j.status='completed' JOIN airlinerra_game.airline_ledger b ON b.id=r.paid_ledger_entry_id AND b.airline_id=t.airline_id AND b.amount_usd=-r.settled_cost_usd AND b.entry_kind='EXPENSE'
 WHERE j.job_id=t.maintenance_job_id AND r.airline_id=t.airline_id AND r.aircraft_inventory_id=t.aircraft_inventory_id AND j.airport_key=t.provider_airport_key AND r.check_code=t.check_code AND r.game_completed_at_utc<=(t.quote->l.name->>'departureUtc')::timestamptz))
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_relocation_leg_evidence_v1(text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 proof jsonb;hour_proof jsonb;
 flight record;state record;model record;
 pos jsonb;auto_source text;
 event_id text;expected_qty numeric(14,3);
 prior_qty numeric(14,3):=0;
 add_qty numeric(14,3);
 supplied int;updated int;current_game_date date;
 v_enabled boolean; relocation record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_GAME_ONLY_AUTOFUEL_TRUSTED_ENGINE_ONLY';END IF;
 IF p_physical_flight_id IS NULL
  OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_AUTO_FUEL_INVALID_PHYSICAL_FLIGHT_ID';END IF;
 -- Cannot allocate game fuel while World 1 operations are paused.
 SELECT (a.release_state='enabled' AND a.enabled_at IS NOT NULL
  AND a.crew_mode='deferred_phase1'
  AND e.release_state='enabled' AND e.enabled_at IS NOT NULL) INTO v_enabled
 FROM airlinerra_game.section9_activation_release_policy_v1 a
 JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e
 ON e.world_id=a.world_id WHERE a.world_id=1;
 IF v_enabled IS DISTINCT FROM true THEN
 RETURN jsonb_build_object('status','blocked_game_fuel_auto_supply_unreleased',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT o.airline_id,o.aircraft_inventory_id,o.origin_airport_key,
  o.departure_utc,o.flight_local_date,o.booking_status,o.source_kind,
  s.configuration_id,s.operationally_verified,s.status AS schedule_status,
  a.owner_player_id
 INTO flight
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
 ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.airlines a ON a.id=o.airline_id AND a.world_id=1
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::integer
  AND o.world_id=1;
 IF NOT FOUND THEN
  SELECT * INTO relocation FROM airlinerra_game.section9_relocation_leg_evidence_v1(p_physical_flight_id);
  IF NOT FOUND OR relocation.departure_utc>(hour_proof->>'gameHourUtc')::timestamptz+interval '7 days' OR relocation.departure_utc<=(hour_proof->>'gameHourUtc')::timestamptz-interval '10 minutes' THEN RETURN jsonb_build_object('status','blocked_nonoperating_or_out_of_window_flight','gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
  SELECT relocation.airline_id AS airline_id,relocation.aircraft_inventory_id AS aircraft_inventory_id,relocation.origin_airport_key AS origin_airport_key,relocation.configuration_id AS configuration_id,relocation.owner_player_id AS owner_player_id INTO flight;
 ELSE
 IF flight.operationally_verified IS DISTINCT FROM true
 OR flight.schedule_status IS DISTINCT FROM 'active'
 OR flight.booking_status IS DISTINCT FROM 'open'
 OR flight.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
 OR flight.departure_utc>(hour_proof->>'gameHourUtc')::timestamptz+interval '7 days'
 OR flight.departure_utc<=(hour_proof->>'gameHourUtc')::timestamptz-interval '10 minutes'
 THEN RETURN jsonb_build_object('status','blocked_nonoperating_or_out_of_window_flight',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 END IF;

 IF NOT pg_catalog.pg_try_advisory_xact_lock(
     583731,pg_catalog.hashtext(flight.aircraft_inventory_id::text))
 THEN RETURN jsonb_build_object('status','game_auto_fuel_aircraft_busy',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id);
 IF proof->>'status'='verified_game_fuel_onboard_available_for_planned_trip'
 AND proof->>'fuelVerifiedForGame'='true'
 THEN RETURN jsonb_build_object('status','game_fuel_already_sufficient',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF proof->>'status' NOT IN (
  'blocked_missing_verified_aircraft_fuel_onboard',
  'blocked_insufficient_aircraft_fuel_including_reserve'
 ) THEN RETURN jsonb_build_object('status','blocked_game_fuel_preflight_evidence',
  'preflightStatus',proof->>'status',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF proof->>'airportFuelServiceListed' IS DISTINCT FROM 'true' THEN
 RETURN jsonb_build_object('status','blocked_no_game_airport_fuel_service',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT * INTO model FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=flight.configuration_id;
 IF NOT FOUND OR model.game_calculation_ready IS DISTINCT FROM true
 OR model.fuel_game_family IS NULL OR model.tank_capacity_kg<=0
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_fuel_model',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 expected_qty:=(proof->>'minimumPlannedFuelOnBoardKg')::numeric(14,3);
 IF expected_qty IS NULL OR expected_qty<=0
 OR expected_qty>model.tank_capacity_kg
 THEN RETURN jsonb_build_object('status','blocked_game_fuel_minimum_exceeds_tank',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 -- Starting custody may ONLY be created at the authoritative game
 -- starter airport. Once signed arrivals exist, all future refuelling
 -- must use the fuel custody location, not the player's home airport.
 SELECT * INTO state FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1
 WHERE aircraft_inventory_id=flight.aircraft_inventory_id
 AND airline_id=flight.airline_id FOR UPDATE;
 IF NOT FOUND THEN
   current_game_date:=((hour_proof->>'gameHourUtc')::timestamptz
    AT TIME ZONE 'Europe/Berlin')::date;
   pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
     flight.owner_player_id,flight.airline_id,
     flight.aircraft_inventory_id,current_game_date);
   IF pos->>'verified' IS DISTINCT FROM 'true'
    OR pos->>'atGroundAirport' IS DISTINCT FROM 'true'
    OR pos->>'airportKey' IS DISTINCT FROM flight.origin_airport_key
    OR pos->>'status' IS DISTINCT FROM 'verified_original_game_starter_position'
   THEN RETURN jsonb_build_object('status','blocked_unverified_aircraft_fuel_starter_location',
     'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 ELSE
   prior_qty:=state.onboard_kg;
   IF state.at_airport_key IS DISTINCT FROM flight.origin_airport_key
    OR state.fuel_game_family IS DISTINCT FROM model.fuel_game_family
    OR state.configuration_id IS DISTINCT FROM flight.configuration_id
   THEN RETURN jsonb_build_object('status','blocked_fuel_custody_not_at_departure',
    'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 END IF;
 add_qty:=expected_qty-prior_qty;
 IF add_qty<=0 THEN
 RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_AUTOFUEL_NONPOSITIVE_TOPUP_WITH_UNVERIFIED_CUSTODY';END IF;

 -- A game-only airport supplier receipt. This is NOT proof that the
 -- actual aircraft's installed engines or real fuel grade were certified.
 auto_source:='GAME_ONLY_AUTO_FUEL_SERVICE_V1_'||flight.origin_airport_key;
 event_id:='game-auto-fuel-v1-'||md5(p_physical_flight_id);
 INSERT INTO airlinerra_game.section9_game_approved_fuel_load_receipts_v1(
  source_event_id,airline_id,aircraft_inventory_id,at_airport_key,
  fuel_family,load_added_kg,fuel_after_load_kg,
  game_hour_utc,game_supplier_reference,source_status
 ) VALUES(event_id,flight.airline_id,flight.aircraft_inventory_id,
  flight.origin_airport_key,model.fuel_game_family,add_qty,expected_qty,
  (hour_proof->>'gameHourUtc')::timestamptz,
  auto_source,'game_authority_approved');
 GET DIAGNOSTICS supplied=ROW_COUNT;
 IF supplied<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_DUPLICATE_GAME_FUEL_AUTO_SUPPLY_EVENT';END IF;
 IF state.aircraft_inventory_id IS NULL THEN
  INSERT INTO airlinerra_game.section9_aircraft_game_fuel_custody_v1(
   aircraft_inventory_id,airline_id,configuration_id,at_airport_key,
   fuel_game_family,onboard_kg,source_event_id,source_event_kind,
   evidence_reference,game_hour_utc,revision
  ) VALUES(flight.aircraft_inventory_id,flight.airline_id,
   flight.configuration_id,flight.origin_airport_key,
   model.fuel_game_family,expected_qty,event_id,'approved_game_fuel_load',
   auto_source,(hour_proof->>'gameHourUtc')::timestamptz,1);
 ELSE
  UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1
  SET onboard_kg=expected_qty,
   source_event_id=event_id,source_event_kind='approved_game_fuel_load',
   evidence_reference=auto_source,
   game_hour_utc=(hour_proof->>'gameHourUtc')::timestamptz,
   revision=revision+1,recorded_at=clock_timestamp()
  WHERE aircraft_inventory_id=flight.aircraft_inventory_id
  AND airline_id=flight.airline_id AND revision=state.revision;
  GET DIAGNOSTICS updated=ROW_COUNT;
  IF updated<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_GAME_FUEL_TOPUP_CONCURRENT_CONFLICT';END IF;
 END IF;
 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id);
 IF proof->>'status' IS DISTINCT FROM
   'verified_game_fuel_onboard_available_for_planned_trip'
 OR proof->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_GAME_AUTO_FUEL_NOT_VERIFIED_ROLLBACK';END IF;
 RETURN jsonb_build_object(
   'status','game_only_auto_fuel_supply_recorded',
   'physicalFlightId',p_physical_flight_id,
   'fuelTopUpKg',add_qty,'fuelOnBoardKg',expected_qty,
   'gameFuelFamily',model.fuel_game_family,
   'gameSupplySource',auto_source,
   'fuelVerifiedForGame',true,
   'realWorldFuelGradeCertified',false,
   'chargedNow',false,'ledgerPosted',false,
   'gameFuelSupplierEventCreated',true);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 phase_profile jsonb;
 r record;custody record; fuel_model record;
 clock_proof jsonb;fuel jsonb;
 hours_old numeric;total_minutes integer;
 taxi_out_min integer;taxi_in_min integer;climb_min integer;descent_min integer;cruise_min integer;
 qty_trip numeric(14,3);qty_min numeric(14,3);
 source_valid boolean:=false;
 origin_can_supply boolean:=false;
 relocation record; is_relocation boolean:=false;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUEL_PREFLIGHT_TRUSTED_GAME_WORKER_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR
  p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_GAME_FUEL_FLIGHT_ID';END IF;

 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 SELECT o.id AS occurrence_id,o.airline_id,o.schedule_id,o.aircraft_inventory_id,
   o.schedule_version,o.weekly_entry,o.flight_local_date,
   o.departure_utc,o.arrival_utc,o.origin_airport_key,o.destination_airport_key,
   o.verified_passenger_seats,o.booked_seats,o.booking_status,o.source_kind,
   s.version AS active_schedule_version,s.status AS active_schedule_status,
   s.operationally_verified,s.configuration_id,
   fleet.fleet_status,fleet.configuration_id AS fleet_configuration_id,
   cap.passenger_capacity,cap.passengers_held,cap.cargo_held_tonnes,
   cap.schedule_version AS cap_version,cap.departure_utc AS cap_departure,
   cap.arrival_utc AS cap_arrival
 INTO r
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=o.aircraft_inventory_id AND fleet.airline_id=o.airline_id
 LEFT JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  ON cap.physical_flight_id=p_physical_flight_id AND cap.airline_id=o.airline_id
 WHERE o.world_id=1
  AND o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::integer;
 IF NOT FOUND THEN
  SELECT * INTO relocation FROM airlinerra_game.section9_relocation_leg_evidence_v1(p_physical_flight_id);
  IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked_unverified_operating_flight','readOnly',true,'ledgerPosted',false,'fuelVerifiedForGame',false);END IF;
  SELECT relocation.airline_id AS airline_id,relocation.aircraft_inventory_id AS aircraft_inventory_id,relocation.origin_airport_key AS origin_airport_key,relocation.destination_airport_key AS destination_airport_key,relocation.configuration_id AS configuration_id,relocation.departure_utc AS departure_utc,relocation.arrival_utc AS arrival_utc,0 AS booked_seats,0 AS verified_passenger_seats INTO r;
  is_relocation:=true;
 ELSE
 IF r.active_schedule_status IS DISTINCT FROM 'active'
  OR r.operationally_verified IS DISTINCT FROM true
  OR r.active_schedule_version IS DISTINCT FROM r.schedule_version
  OR r.fleet_status IS DISTINCT FROM 'in_service'
  OR r.fleet_configuration_id IS DISTINCT FROM r.configuration_id
  OR r.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
  OR r.booking_status NOT IN ('open','closed')
  OR r.verified_passenger_seats IS NULL OR r.verified_passenger_seats<=0
  OR r.booked_seats>r.verified_passenger_seats
  OR r.passenger_capacity IS DISTINCT FROM r.verified_passenger_seats
  OR r.passengers_held<r.booked_seats
  OR r.passengers_held>r.passenger_capacity
  OR r.cargo_held_tonnes IS DISTINCT FROM 0
  OR r.cap_version IS DISTINCT FROM r.schedule_version
  OR r.cap_departure IS DISTINCT FROM r.departure_utc
  OR r.cap_arrival IS DISTINCT FROM r.arrival_utc
  OR r.arrival_utc<=r.departure_utc
 THEN RETURN jsonb_build_object('status','blocked_unverified_operating_flight',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);
 END IF;

 END IF;

 SELECT * INTO fuel_model
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=r.configuration_id;
 IF NOT FOUND OR fuel_model.game_calculation_ready IS DISTINCT FROM true
 OR fuel_model.tank_capacity_kg IS NULL
 OR fuel_model.fuel_game_family IS NULL
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_aircraft_fuel_model',
  'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;
 total_minutes:=ceil(extract(epoch from(r.arrival_utc-r.departure_utc))/60)::integer;
 phase_profile:=airlinerra_game.section9_game_route_phase_profile_v1(r.configuration_id,r.origin_airport_key,r.destination_airport_key,total_minutes);
 IF phase_profile IS NULL THEN RETURN jsonb_build_object('status','blocked_invalid_game_fuel_flight_duration','readOnly',true,'ledgerPosted',false);END IF;
 taxi_out_min:=(phase_profile->>'taxiOutMinutes')::int;
 climb_min:=(phase_profile->>'climbMinutes')::int;
 cruise_min:=(phase_profile->>'cruiseMinutes')::int;
 descent_min:=(phase_profile->>'descentMinutes')::int;
 taxi_in_min:=(phase_profile->>'taxiInMinutes')::int;
 IF cruise_min<1 THEN RETURN jsonb_build_object(
   'status','blocked_game_fuel_flight_too_short_for_phase_model',
   'gameOnly',true,'fuelVerifiedForGame',false,'readOnly',true,'ledgerPosted',false);END IF;

 fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(
   r.configuration_id,
   CASE WHEN is_relocation THEN 0 ELSE round(r.booked_seats::numeric/r.verified_passenger_seats*100,2) END,
   taxi_out_min,climb_min,cruise_min,descent_min,taxi_in_min);
 IF fuel->>'status' IS DISTINCT FROM 'game_reserve_aware_fuel_estimate_only'
  OR fuel->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'
  OR fuel->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'
  OR fuel->>'accountingApproved' IS DISTINCT FROM 'false'
  OR fuel->>'dispatchApproved' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object('status','blocked_fuel_tank_or_game_model',
  'gameOnly',true,'fuelVerifiedForGame',false,
  'quoteStatus',fuel->>'status',
  'withinGameTankIncludingReserve',fuel->>'withinGameTankIncludingReserve',
  'readOnly',true,'ledgerPosted',false);END IF;
 qty_trip:=(fuel->>'tripBurnKg')::numeric(14,3);
 qty_min:=(fuel->>'minimumPlannedFuelOnBoardKg')::numeric(14,3);
 IF qty_trip<=0 OR qty_min<=qty_trip THEN
 RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_INVALID_FUEL_TRIP_AND_RESERVE_PROOF';END IF;

 -- The airport's generic fuel_available only indicates that *some* fuel
 -- service exists. It is not proof of this aircraft's fuel grade or balance.
 SELECT coalesce(fac.fuel_available,false) INTO origin_can_supply
 FROM airlinerra_game.airport_facilities fac
 WHERE fac.world_id=1 AND fac.airport_key=r.origin_airport_key;
 origin_can_supply:=coalesce(origin_can_supply,false);

 -- Lock the physical fuel balance until the dispatcher either records
 -- the signed departure and its fuel receipt or rolls back.
 SELECT * INTO custody
 FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 c
 WHERE c.aircraft_inventory_id=r.aircraft_inventory_id
 AND c.airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object(
   'status','blocked_missing_verified_aircraft_fuel_onboard',
   'physicalFlightId',p_physical_flight_id,
   'minimumPlannedFuelOnBoardKg',qty_min,
   'plannedTripBurnKg',qty_trip,
   'airportFuelServiceListed',origin_can_supply,
   'fuelOnBoardKnown',false,'fuelVerifiedForGame',false,
   'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF custody.configuration_id IS DISTINCT FROM r.configuration_id
 OR custody.world_id<>1
 OR custody.at_airport_key IS DISTINCT FROM r.origin_airport_key
 OR custody.fuel_game_family IS DISTINCT FROM fuel_model.fuel_game_family
 OR custody.onboard_kg>fuel_model.tank_capacity_kg
 OR custody.game_hour_utc>(clock_proof->>'gameHourUtc')::timestamptz
 THEN RETURN jsonb_build_object(
  'status','blocked_fuel_custody_location_configuration_or_clock_mismatch',
  'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;

 IF custody.source_event_kind='approved_game_fuel_load' THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_approved_fuel_load_receipts_v1 t
   WHERE t.source_event_id=custody.source_event_id
   AND t.source_status='game_authority_approved'
   AND t.airline_id=custody.airline_id
   AND t.aircraft_inventory_id=custody.aircraft_inventory_id
   AND t.at_airport_key=custody.at_airport_key
   AND t.fuel_family=custody.fuel_game_family
   AND t.fuel_after_load_kg=custody.onboard_kg
   AND t.game_hour_utc=custody.game_hour_utc
   AND t.game_supplier_reference=custody.evidence_reference
  ) INTO source_valid;
 ELSIF custody.source_event_kind='signed_arrival_burn' THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 a
   WHERE a.arrival_engine_event_id=custody.source_event_id
   AND a.airline_id=custody.airline_id
   AND a.aircraft_inventory_id=custody.aircraft_inventory_id
   AND a.location_airport_key=custody.at_airport_key
   AND a.onboard_after_arrival_kg=custody.onboard_kg
  ) INTO source_valid;
 END IF;
 IF source_valid IS DISTINCT FROM true THEN RETURN jsonb_build_object(
   'status','blocked_missing_authorized_fuel_custody_source',
   'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF custody.onboard_kg<qty_min THEN RETURN jsonb_build_object(
   'status','blocked_insufficient_aircraft_fuel_including_reserve',
   'physicalFlightId',p_physical_flight_id,
   'fuelOnBoardKg',custody.onboard_kg,
   'minimumPlannedFuelOnBoardKg',qty_min,
   'plannedTripBurnKg',qty_trip,
   'airportFuelServiceListed',origin_can_supply,
   'fuelVerifiedForGame',false,
   'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 d
  WHERE d.physical_flight_id=p_physical_flight_id
 ) THEN RETURN jsonb_build_object(
  'status','blocked_departure_fuel_proof_already_recorded',
  'fuelVerifiedForGame',false,'gameOnly',true,'readOnly',true,'ledgerPosted',false);END IF;
 RETURN jsonb_build_object(
 'status','verified_game_fuel_onboard_available_for_planned_trip',
 'physicalFlightId',p_physical_flight_id,
 'airlineId',r.airline_id,'aircraftInventoryId',r.aircraft_inventory_id,
 'originAirport',r.origin_airport_key,'destinationAirport',r.destination_airport_key,
 'configurationId',r.configuration_id,
 'fuelGameFamily',custody.fuel_game_family,
 'fuelCustodyRevision',custody.revision,
 'fuelSourceEventId',custody.source_event_id,
 'fuelOnBoardKg',custody.onboard_kg,
 'plannedTripBurnKg',qty_trip,
 'plannedContingencyKg',(fuel->>'contingencyKg')::numeric,
 'plannedHoldingReserveKg',(fuel->>'holdingReserveKg')::numeric,
 'minimumPlannedFuelOnBoardKg',qty_min,
 'tankCapacityKg',fuel_model.tank_capacity_kg,
 'fuelQuoteModelVersion',fuel->>'modelVersion',
 'airportFuelServiceListed',origin_can_supply,
 'fuelVerifiedForGame',true,'fuelGradeCertifiedForRealAircraft',false,
 'gameOnly',true,'readOnly',true,'ledgerPosted',false,
 'dispatchApprovedByThisCheck',false);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_execute_relocation_leg_event_v1(p_trip uuid,p_leg integer,p_phase text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; l record; pos record; has_position boolean; anchor jsonb; resolution jsonb; q jsonb; clock_proof jsonb; v_now timestamptz; event_time timestamptz; physical text; event_id text; signature text; signer text; usage jsonb; fuel jsonb; movement jsonb; maint jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_EXECUTION_ONLY';END IF;
 IF p_leg NOT IN (1,2) OR p_phase NOT IN ('departed','arrived') OR p_phase IS NULL THEN RAISE EXCEPTION 'INVALID_RELOCATION_EVENT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled) THEN RETURN jsonb_build_object('status','relocation_execution_not_released','movementRecorded',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 a JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e ON e.world_id=a.world_id JOIN airlinerra_game.section9_flight_engine_readiness_audit_v1 g ON g.world_id=a.world_id WHERE a.world_id=1 AND a.release_state='enabled' AND e.release_state='enabled' AND g.trusted_flight_execution_release='ACTIVATED' AND g.fuel_transaction_release='ACTIVATED' AND g.automatic_flight_and_fuel_settlement_enabled) THEN RETURN jsonb_build_object('status','flight_engine_unreleased','movementRecorded',false);END IF;
 SELECT * INTO t FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE id=p_trip FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unknown_relocation_trip','movementRecorded',false);END IF;
 physical:=t.id::text||':'||((t.quote->(CASE WHEN p_leg=1 THEN 'outbound' ELSE 'return' END)->>'departureUtc')::timestamptz AT TIME ZONE 'UTC')::date::text||':'||p_leg::text;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND flight_occurrence_id=physical AND phase=p_phase) THEN RETURN jsonb_build_object('status','relocation_movement_replayed','movementRecorded',false,'replayed',true);END IF;
 SELECT * INTO l FROM airlinerra_game.section9_relocation_leg_evidence_v1(physical);
 IF NOT FOUND THEN RETURN jsonb_build_object('status','relocation_leg_not_ready','movementRecorded',false);END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','game_clock_unverified','movementRecorded',false);END IF;
 v_now:=(clock_proof->>'gameHourUtc')::timestamptz;
 event_time:=CASE WHEN p_phase='departed' THEN l.departure_utc ELSE l.arrival_utc END;
 IF event_time>v_now OR event_time>clock_timestamp() OR event_time<>date_trunc('second',event_time) OR (p_phase='departed' AND event_time<=v_now-interval '10 minutes') THEN RETURN jsonb_build_object('status','relocation_event_outside_window','movementRecorded',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=l.aircraft_inventory_id AND airline_id=l.airline_id AND fleet_status='in_service' AND configuration_id=l.configuration_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','movementRecorded',false);END IF;
 SELECT * INTO pos FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=l.aircraft_inventory_id AND airline_id=l.airline_id FOR UPDATE;
 has_position:=FOUND;
 anchor:=airlinerra_game.section9_owned_aircraft_operational_position_v1(l.owner_player_id,l.airline_id,l.aircraft_inventory_id,(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date);
 IF anchor->>'verified' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_position_unverified','movementRecorded',false);END IF;
 IF p_phase='departed' THEN
  IF anchor->>'atGroundAirport' IS DISTINCT FROM 'true' OR anchor->>'airportKey' IS DISTINCT FROM l.origin_airport_key THEN RETURN jsonb_build_object('status','relocation_at_wrong_airport','movementRecorded',false);END IF;
  IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(l.airline_id,airlinerra_game.section9_verified_permission_game_day_v1(),0) OR airlinerra_game.section9_game_route_licence_scope_v1(l.airline_id,l.origin_airport_key,l.destination_airport_key,airlinerra_game.section9_verified_permission_game_day_v1(),0)->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_licence_blocked','movementRecorded',false);END IF;
  q:=airlinerra_game.section5_universal_route_restriction_gate_v1(1::smallint,l.origin_airport_key,l.destination_airport_key,l.configuration_id,l.departure_utc,l.arrival_utc,NULL,NULL);
  IF NOT airlinerra_game.section9_game_route_restrictions_valid_v1(l.origin_airport_key,l.destination_airport_key,jsonb_build_object('weeklyTimetableChecked',true,'gameHardBlocked',(q->>'gameHardBlocked')::boolean,'occurrences',jsonb_build_array(q))) THEN RETURN jsonb_build_object('status','relocation_airport_restrictions_blocked','movementRecorded',false);END IF;
  maint:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(l.owner_player_id,l.airline_id,l.aircraft_inventory_id,l.departure_utc,l.arrival_utc);
  IF maint->>'gameMaintenanceClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_maintenance_blocked','movementRecorded',false,'blockers',maint->'blockers');END IF;
 ELSE
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND flight_occurrence_id=physical AND phase='departed') THEN RETURN jsonb_build_object('status','relocation_arrival_without_departure','movementRecorded',false);END IF;
 END IF;
 resolution:=airlinerra_game.section9_aircraft_movement_decision_v1(p_phase,CASE WHEN has_position THEN pos.location_status ELSE 'grounded' END,CASE WHEN has_position THEN pos.airport_key ELSE anchor->>'airportKey' END,CASE WHEN has_position THEN pos.current_flight_occurrence_id ELSE NULL END,CASE WHEN has_position THEN pos.last_event_utc ELSE NULL END,CASE WHEN has_position THEN pos.last_departure_utc ELSE NULL END,l.origin_airport_key,l.destination_airport_key,physical,event_time);
 IF resolution->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_movement_blocked','movementRecorded',false,'reason',resolution->>'reason');END IF;
 event_id:='relocation-v1:'||physical||':'||p_phase;
 SELECT decrypted_secret INTO signer FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF signer IS NULL OR length(signer)<64 THEN RETURN jsonb_build_object('status','private_signer_unavailable','movementRecorded',false);END IF;
 signature:=encode(extensions.hmac(convert_to(concat_ws(E'\n','airlinerra-relocation-event-v1',l.airline_id::text,l.aircraft_inventory_id::text,physical,p_phase,l.origin_airport_key,l.destination_airport_key,to_char(event_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),event_id),'UTF8'),convert_to(signer,'UTF8'),'sha256'),'hex');
 IF p_phase='departed' THEN
  fuel:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(physical);
  IF fuel->>'status' NOT IN ('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient') THEN RAISE EXCEPTION 'RELOCATION_FUEL_SUPPLY_BLOCKED';END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,relocation_trip_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,event_id,signature,l.airline_id,l.aircraft_inventory_id,NULL,p_trip,1,p_leg,l.flight_local_date,physical,p_phase,l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,event_time);
 INSERT INTO airlinerra_game.section9_aircraft_current_position_v1(aircraft_inventory_id,world_id,airline_id,location_status,airport_key,current_flight_occurrence_id,last_event_utc,last_departure_utc,last_arrival_utc,last_engine_event_id)
 VALUES(l.aircraft_inventory_id,1,l.airline_id,resolution->>'newState',resolution->>'newAirport',CASE WHEN p_phase='departed' THEN physical ELSE NULL END,event_time,CASE WHEN p_phase='departed' THEN event_time ELSE pos.last_departure_utc END,CASE WHEN p_phase='arrived' THEN event_time ELSE pos.last_arrival_utc END,event_id)
 ON CONFLICT(aircraft_inventory_id) DO UPDATE SET location_status=excluded.location_status,airport_key=excluded.airport_key,current_flight_occurrence_id=excluded.current_flight_occurrence_id,last_event_utc=excluded.last_event_utc,last_departure_utc=excluded.last_departure_utc,last_arrival_utc=excluded.last_arrival_utc,last_engine_event_id=excluded.last_engine_event_id,updated_at=clock_timestamp()
 WHERE airlinerra_game.section9_aircraft_current_position_v1.airline_id=excluded.airline_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'RELOCATION_POSITION_UPDATE_FAILED';END IF;
 IF p_phase='departed' THEN
  fuel:=airlinerra_game.section9_capture_verified_departure_fuel_v1(physical,event_id);
  IF fuel->>'fuelReceiptCreated' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_DEPARTURE_FUEL_NOT_RECORDED';END IF;
 ELSE
  usage:=airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(physical);
  IF usage->>'usageApplied' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_USAGE_NOT_RECORDED';END IF;
  fuel:=airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(physical,event_id);
  IF fuel->>'fuelBurnRecorded' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'RELOCATION_ARRIVAL_FUEL_NOT_RECORDED';END IF;
 END IF;
 RETURN jsonb_build_object('status','relocation_movement_recorded','movementRecorded',true,'replayed',false,'flightOccurrenceId',physical,'phase',p_phase,'airportKey',resolution->>'newAirport','usage',usage,'fuel',fuel,'passengers',0,'ticketRevenueUsd',0,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_execute_relocation_leg_event_v1(uuid,integer,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
