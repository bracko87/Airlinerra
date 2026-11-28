-- Read-only source capture; no production records or secret values.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 departure record;arrival record;state_row record;existing record;
 hours_to_add numeric(10,3);
 affected integer:=0;
 hour_proof jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_AIRFRAME_USAGE_ENGINE_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR length(p_physical_flight_id)<40
  OR length(p_physical_flight_id)>140
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_FLIGHT_USAGE_ID';END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_airframe_game_hour',
  'usageApplied',false,'ledgerPosted',false);END IF;

 SELECT * INTO arrival FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='arrived';
 SELECT * INTO departure FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='departed';
 IF arrival.engine_event_id IS NULL OR departure.engine_event_id IS NULL
 OR arrival.world_id<>1 OR departure.world_id<>1
 OR arrival.source_kind<>'signed_operated_game_flight_v1'
 OR departure.source_kind<>'signed_operated_game_flight_v1'
 OR arrival.airline_id IS DISTINCT FROM departure.airline_id
 OR arrival.aircraft_inventory_id IS DISTINCT FROM departure.aircraft_inventory_id
 OR arrival.schedule_id IS DISTINCT FROM departure.schedule_id
 OR arrival.schedule_version IS DISTINCT FROM departure.schedule_version
 OR arrival.actual_event_utc<=departure.actual_event_utc
 OR arrival.actual_event_utc>(hour_proof->>'gameHourUtc')::timestamptz
 OR arrival.actual_event_utc>departure.actual_event_utc+interval '72 hours'
 THEN RETURN jsonb_build_object('status','blocked_unverified_arrival_and_departure',
  'usageApplied',false,'ledgerPosted',false);END IF;
 hours_to_add:=round(
  extract(epoch FROM(arrival.actual_event_utc-departure.actual_event_utc))/3600,3);
 IF hours_to_add<=0 OR hours_to_add>72 THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_INVALID_AIRFRAME_TIME';END IF;

 SELECT * INTO state_row
 FROM airlinerra_game.aircraft_maintenance_state_v1
 WHERE aircraft_inventory_id=arrival.aircraft_inventory_id
  AND airline_id=arrival.airline_id FOR UPDATE;
 IF NOT FOUND OR state_row.verified_tracking_started_utc IS NULL
 OR state_row.tracked_flight_hours IS NULL
 OR state_row.tracked_flight_cycles IS NULL
 OR state_row.tracked_flight_hours<0
 OR state_row.tracked_flight_cycles<0
 THEN RETURN jsonb_build_object('status','blocked_missing_initial_airframe_tracking',
  'usageApplied',false,'ledgerPosted',false);END IF;
 SELECT * INTO existing
 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF existing.airline_id IS DISTINCT FROM arrival.airline_id
   OR existing.aircraft_inventory_id IS DISTINCT FROM arrival.aircraft_inventory_id
   OR existing.arrived_engine_event_id IS DISTINCT FROM arrival.engine_event_id
   OR existing.departed_engine_event_id IS DISTINCT FROM departure.engine_event_id
   OR existing.elapsed_flight_hours IS DISTINCT FROM hours_to_add
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_REPLAYED_AIRFRAME_USAGE_INCONSISTENT';END IF;
  RETURN jsonb_build_object('status','airframe_usage_already_applied',
    'flightOccurrenceId',p_physical_flight_id,
    'usageApplied',false,'replayed',true,
    'flightHoursAddedNow',0,'flightCyclesAddedNow',0,
    'ledgerPosted',false);
 END IF;

 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(
 physical_flight_id,airline_id,aircraft_inventory_id,
 arrived_engine_event_id,departed_engine_event_id,
 elapsed_flight_hours,flight_cycles
 ) VALUES(p_physical_flight_id,arrival.airline_id,arrival.aircraft_inventory_id,
 arrival.engine_event_id,departure.engine_event_id,hours_to_add,1);
 UPDATE airlinerra_game.aircraft_maintenance_state_v1
 SET tracked_flight_hours=tracked_flight_hours+hours_to_add,
     tracked_flight_cycles=tracked_flight_cycles+1,
     updated_at=clock_timestamp()
 WHERE aircraft_inventory_id=arrival.aircraft_inventory_id
 AND airline_id=arrival.airline_id
 AND tracked_flight_hours IS NOT NULL
 AND tracked_flight_cycles IS NOT NULL;
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_AIRFRAME_COUNTER_UPDATE_UNCONFIRMED_ROLLBACK';END IF;
 RETURN jsonb_build_object('status','arrived_airframe_usage_recorded_once',
   'flightOccurrenceId',p_physical_flight_id,
   'usageApplied',true,'replayed',false,
   'flightHoursAddedNow',hours_to_add,'flightCyclesAddedNow',1,
   'trackedFlightHoursTotal',state_row.tracked_flight_hours+hours_to_add,
   'trackedCyclesTotal',state_row.tracked_flight_cycles+1,
   'aircraftMaintenanceRecheckRequired',true,
   'ledgerPosted',false);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(p_physical_flight_id text, p_arrival_engine_event_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 departure record;arrival record;fuel_custody record;receipt record;
 hour_proof jsonb;new_kg numeric(14,3);inserted int;updated int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_FUEL_ARRIVAL_TRUSTED_WORKER_ONLY';END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'fuelBurnRecorded',false,'ledgerPosted',false);END IF;
 SELECT * INTO departure FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id;
 SELECT * INTO arrival FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id
  AND engine_event_id=p_arrival_engine_event_id AND phase='arrived'
  AND world_id=1;
 IF departure.physical_flight_id IS NULL OR arrival.engine_event_id IS NULL
 OR arrival.source_kind IS DISTINCT FROM 'signed_operated_game_flight_v1'
 OR arrival.airline_id IS DISTINCT FROM departure.airline_id
 OR arrival.aircraft_inventory_id IS DISTINCT FROM departure.aircraft_inventory_id
 OR arrival.origin_airport_key IS DISTINCT FROM departure.departure_airport_key
 OR arrival.destination_airport_key IS DISTINCT FROM departure.destination_airport_key
 OR arrival.actual_event_utc>(hour_proof->>'gameHourUtc')::timestamptz
 OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.engine_event_id=departure.departure_engine_event_id
  AND m.phase='departed'
  AND m.flight_occurrence_id=p_physical_flight_id
  AND m.actual_event_utc<arrival.actual_event_utc)
 THEN RETURN jsonb_build_object('status','blocked_missing_signed_departure_or_arrival_fuel_proof',
  'fuelBurnRecorded',false,'ledgerPosted',false);END IF;
 SELECT * INTO receipt FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF receipt.arrival_engine_event_id IS DISTINCT FROM arrival.engine_event_id
  OR receipt.aircraft_inventory_id IS DISTINCT FROM departure.aircraft_inventory_id
  OR receipt.airline_id IS DISTINCT FROM departure.airline_id
  OR receipt.trip_burn_kg IS DISTINCT FROM departure.planned_trip_burn_kg
  THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_ARRIVAL_FUEL_REPLAY_INCONSISTENT';END IF;
  RETURN jsonb_build_object('status','signed_game_fuel_burn_already_applied',
   'replayed',true,'fuelBurnRecorded',false,'ledgerPosted',false);
 END IF;
 SELECT * INTO fuel_custody FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 c
 WHERE c.aircraft_inventory_id=departure.aircraft_inventory_id
 AND c.airline_id=departure.airline_id FOR UPDATE;
 IF NOT FOUND
 OR fuel_custody.revision IS DISTINCT FROM departure.fuel_custody_revision
 OR fuel_custody.source_event_id IS DISTINCT FROM departure.fuel_custody_source_event_id
 OR fuel_custody.onboard_kg IS DISTINCT FROM departure.onboard_at_departure_kg
 OR fuel_custody.at_airport_key IS DISTINCT FROM departure.departure_airport_key
 THEN RAISE EXCEPTION USING ERRCODE='40001',
    MESSAGE='SECTION9_FLIGHT_FUEL_CUSTODY_CHANGED_IN_TRANSIT_ROLLBACK';END IF;
 new_kg:=fuel_custody.onboard_kg-departure.planned_trip_burn_kg;
 IF new_kg<departure.planned_contingency_kg+departure.planned_holding_reserve_kg
 OR new_kg<0 THEN RAISE EXCEPTION USING ERRCODE='23514',
   MESSAGE='SECTION9_ARRIVAL_FUEL_RESERVE_BELOW_GAME_MINIMUM';END IF;

 INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(
 physical_flight_id,airline_id,aircraft_inventory_id,arrival_engine_event_id,
 trip_burn_kg,onboard_after_arrival_kg,location_airport_key
 ) VALUES(p_physical_flight_id,arrival.airline_id,arrival.aircraft_inventory_id,
 arrival.engine_event_id,departure.planned_trip_burn_kg,new_kg,arrival.destination_airport_key);
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_ARRIVAL_FUEL_RECEIPT_NOT_WRITTEN';END IF;
 UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1
 SET onboard_kg=new_kg,at_airport_key=arrival.destination_airport_key,
  source_event_id=arrival.engine_event_id,
  source_event_kind='signed_arrival_burn',
  evidence_reference='signed-game-arrival-burn:'||arrival.engine_event_id,
  game_hour_utc=arrival.actual_event_utc,revision=revision+1,
  recorded_at=clock_timestamp()
 WHERE aircraft_inventory_id=departure.aircraft_inventory_id
  AND airline_id=departure.airline_id
  AND revision=departure.fuel_custody_revision;
 GET DIAGNOSTICS updated=ROW_COUNT;
 IF updated<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_ARRIVAL_FUEL_CUSTODY_NOT_ATOMIC_ROLLBACK';END IF;
 RETURN jsonb_build_object(
 'status','signed_game_arrival_fuel_burn_recorded_once',
 'physicalFlightId',p_physical_flight_id,
 'tripFuelBurnKg',departure.planned_trip_burn_kg,
 'onboardAfterArrivalKg',new_kg,
 'arrivedAirport',arrival.destination_airport_key,
 'fuelBurnRecorded',true,'replayed',false,
 'fuelChargePosted',false,'ledgerPosted',false);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_verified_departure_fuel_v1(p_physical_flight_id text, p_departure_engine_event_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 movement record;
 proof jsonb;
 custody record;
 existing record;
 inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUEL_DEPARTURE_TRUSTED_WORKER_ONLY';END IF;
 SELECT * INTO movement FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id
  AND engine_event_id=p_departure_engine_event_id
  AND phase='departed' AND world_id=1;
 IF NOT FOUND OR movement.source_kind IS DISTINCT FROM 'signed_operated_game_flight_v1'
 THEN RETURN jsonb_build_object('status','blocked_unsigned_departure_fuel_event',
  'fuelReceiptCreated',false,'ledgerPosted',false);END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF existing.departure_engine_event_id IS DISTINCT FROM p_departure_engine_event_id
   OR existing.airline_id IS DISTINCT FROM movement.airline_id
   OR existing.aircraft_inventory_id IS DISTINCT FROM movement.aircraft_inventory_id
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_FUEL_DEPARTURE_RECEIPT_REPLAY_CHANGED';END IF;
  RETURN jsonb_build_object('status','game_fuel_departure_already_proven',
   'replayed',true,'fuelReceiptCreated',false,'ledgerPosted',false);
 END IF;
 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(
   p_physical_flight_id);
 IF proof->>'status' IS DISTINCT FROM 'verified_game_fuel_onboard_available_for_planned_trip'
 OR proof->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
 OR proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR proof->>'airlineId' IS DISTINCT FROM movement.airline_id::text
 OR proof->>'aircraftInventoryId' IS DISTINCT FROM movement.aircraft_inventory_id::text
 OR proof->>'originAirport' IS DISTINCT FROM movement.origin_airport_key
 OR proof->>'destinationAirport' IS DISTINCT FROM movement.destination_airport_key
 THEN RETURN jsonb_build_object(
  'status','blocked_game_fuel_departure_evidence',
  'fuelPreflightStatus',proof->>'status',
  'fuelReceiptCreated',false,'ledgerPosted',false);END IF;
 SELECT * INTO custody FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1
 WHERE aircraft_inventory_id=movement.aircraft_inventory_id
 AND airline_id=movement.airline_id FOR UPDATE;
 IF NOT FOUND OR custody.revision IS DISTINCT FROM
   (proof->>'fuelCustodyRevision')::bigint
 OR custody.source_event_id IS DISTINCT FROM proof->>'fuelSourceEventId'
 OR custody.onboard_kg IS DISTINCT FROM (proof->>'fuelOnBoardKg')::numeric
 THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_FUEL_CHANGED_AFTER_TRUSTED_PREFLIGHT';END IF;
 INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(
 physical_flight_id,airline_id,aircraft_inventory_id,
 departure_engine_event_id,departure_airport_key,destination_airport_key,
 configuration_id,fuel_custody_source_event_id,fuel_custody_revision,
 onboard_at_departure_kg,planned_trip_burn_kg,
 planned_contingency_kg,planned_holding_reserve_kg,
 minimum_planned_onboard_kg,model_version,verified_game_hour_utc
 ) VALUES(
 p_physical_flight_id,movement.airline_id,movement.aircraft_inventory_id,
 movement.engine_event_id,movement.origin_airport_key,movement.destination_airport_key,
 (proof->>'configurationId')::bigint,proof->>'fuelSourceEventId',
 (proof->>'fuelCustodyRevision')::bigint,
 (proof->>'fuelOnBoardKg')::numeric,
 (proof->>'plannedTripBurnKg')::numeric,
 (proof->>'plannedContingencyKg')::numeric,
 (proof->>'plannedHoldingReserveKg')::numeric,
 (proof->>'minimumPlannedFuelOnBoardKg')::numeric,
 proof->>'fuelQuoteModelVersion',movement.actual_event_utc);
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_DEPARTURE_FUEL_RECEIPT_NOT_ATOMIC';END IF;
 RETURN jsonb_build_object('status','signed_game_fuel_departure_receipt_created',
  'physicalFlightId',p_physical_flight_id,'fuelReceiptCreated',true,
  'plannedTripBurnKg',proof->'plannedTripBurnKg',
  'onboardAtDepartureKg',proof->'fuelOnBoardKg',
  'fuelAlreadyConsumed',false,'ledgerPosted',false);
END $function$;
