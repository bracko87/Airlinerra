-- Isolated runtime test of actual captured function bodies. All data,
-- airport services, fuel model output and due-check output are synthetic.
SAVEPOINT actual_fuel_outbound;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT clock_timestamp();
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1 ADD COLUMN source_kind text NOT NULL DEFAULT 'signed_operated_game_flight_v1';
ALTER TABLE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 ADD COLUMN onboard_after_arrival_kg numeric;
ALTER TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1 ADD COLUMN tank_capacity_kg numeric, ADD COLUMN fuel_game_family text;
UPDATE airlinerra_game.section9_game_fuel_model_snapshot_v1 SET tank_capacity_kg=10000,fuel_game_family='JET';
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(world_id smallint PRIMARY KEY,release_state text,enabled_at timestamptz,crew_mode text);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(world_id smallint PRIMARY KEY,release_state text,enabled_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(world_id smallint PRIMARY KEY,trusted_flight_execution_release text,fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled boolean);
INSERT INTO airlinerra_game.section9_activation_release_policy_v1 VALUES(1,'enabled',clock_timestamp(),'deferred_phase1');
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1 VALUES(1,'enabled',clock_timestamp());
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1 VALUES(1,'ACTIVATED','ACTIVATED',true);
CREATE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(uuid,date,integer) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1() RETURNS date LANGUAGE sql AS $$SELECT (airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date$$;
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1 ADD COLUMN id uuid,ADD COLUMN world_id smallint,ADD COLUMN configuration_id bigint,ADD COLUMN version integer,ADD COLUMN operationally_verified boolean;
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(id uuid,airline_id uuid,schedule_id uuid,aircraft_inventory_id uuid,world_id smallint,schedule_version int,weekly_entry int,flight_local_date date,departure_utc timestamptz,arrival_utc timestamptz,origin_airport_key text,destination_airport_key text,verified_passenger_seats int,booked_seats int,booking_status text,source_kind text);
CREATE TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1(physical_flight_id text,airline_id uuid,passenger_capacity int,passengers_held int,cargo_held_tonnes numeric,schedule_version int,departure_utc timestamptz,arrival_utc timestamptz);
CREATE FUNCTION airlinerra_game.section9_effective_dispatch_window_v1(uuid) RETURNS TABLE(dispatch_allowed boolean,effective_departure_utc timestamptz) LANGUAGE sql AS $$SELECT false,NULL::timestamptz$$;
CREATE TABLE airlinerra_game.airport_facilities(world_id smallint,airport_key text,fuel_available boolean);
CREATE TABLE airlinerra_game.section9_aircraft_game_fuel_custody_v1(aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,world_id smallint DEFAULT 1,configuration_id bigint,at_airport_key text,fuel_game_family text,onboard_kg numeric(14,3),source_event_id text,source_event_kind text,evidence_reference text,game_hour_utc timestamptz,revision bigint,recorded_at timestamptz DEFAULT clock_timestamp());
CREATE TABLE airlinerra_game.section9_game_approved_fuel_load_receipts_v1(source_event_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,at_airport_key text,fuel_family text,load_added_kg numeric,fuel_after_load_kg numeric,game_hour_utc timestamptz,game_supplier_reference text,source_status text);
CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,departure_engine_event_id text,departure_airport_key text,destination_airport_key text,configuration_id bigint,fuel_custody_source_event_id text,fuel_custody_revision bigint,onboard_at_departure_kg numeric,planned_trip_burn_kg numeric,planned_contingency_kg numeric,planned_holding_reserve_kg numeric,minimum_planned_onboard_kg numeric,model_version text,verified_game_hour_utc timestamptz);
CREATE TABLE airlinerra_game.aircraft_maintenance_state_v1(aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,tracked_flight_hours numeric,tracked_flight_cycles integer,verified_tracking_started_utc timestamptz,updated_at timestamptz);
ALTER TABLE airlinerra_game.section9_game_maintenance_jobs_v1 ADD COLUMN world_id smallint,ADD COLUMN game_start_utc timestamptz,ADD COLUMN game_end_utc timestamptz;
CREATE FUNCTION airlinerra_game.section9_owned_game_maintenance_due_v1(uuid,uuid,uuid,date) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('readOnly',true,'dueCheckCount',0,'gameJobBlocksDate',false,'status','game_maintenance_preview_not_dispatch_approved','checks',
 (SELECT jsonb_agg(jsonb_build_object('checkCode',v,'currentlyDue',current_setting('test.storage_maintenance',true)='blocked')) FROM unnest(ARRAY['daily','weekly','a','b','c','d']) v))
$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_reserve_aware_fuel_quote_v1(bigint,numeric,integer,integer,integer,integer,integer) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('status','game_reserve_aware_fuel_estimate_only','tripBurnKg',1000,'withinGameTankIncludingReserve',true,'fuelPlanningReserveIncluded',true,'accountingApproved',false,'dispatchApproved',false,'minimumPlannedFuelOnBoardKg',1200,'contingencyKg',50,'holdingReserveKg',150,'modelVersion','synthetic-quote')
$$;
-- The legacy phase profile is not used by the storage branch.
CREATE FUNCTION airlinerra_game.section9_game_route_phase_profile_v1(bigint,text,text,integer) RETURNS jsonb LANGUAGE sql AS $$SELECT NULL::jsonb$$;

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

DO $test$
DECLARE s record; r record; owner_id uuid; rid uuid; dep timestamptz; j jsonb; cash_held numeric; original_revision bigint; physical text;
BEGIN
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 -- Start with the reserve left by the signed inbound arrival, not a
 -- fabricated new load at a commercial airport.
 UPDATE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SET onboard_after_arrival_kg=200 WHERE physical_flight_id=s.physical_flight_id;
 INSERT INTO airlinerra_game.section9_aircraft_game_fuel_custody_v1(aircraft_inventory_id,airline_id,configuration_id,at_airport_key,fuel_game_family,onboard_kg,source_event_id,source_event_kind,evidence_reference,game_hour_utc,revision)
 VALUES(s.aircraft_inventory_id,s.airline_id,1,s.airport_key,'JET',200,s.arrival_engine_event_id,'signed_arrival_burn','signed-game-arrival-burn:'||s.arrival_engine_event_id,s.storage_started_utc,2);
 INSERT INTO airlinerra_game.aircraft_maintenance_state_v1 VALUES(s.aircraft_inventory_id,s.airline_id,12,5,s.storage_started_utc-interval '1 day',clock_timestamp());
 SELECT owner_player_id INTO owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 j:=airlinerra_game.post_aircraft_storage_month_v1(s.airline_id,s.request_id,1);
 IF j->>'status' IS DISTINCT FROM 'paid' THEN RAISE EXCEPTION 'fixture billing: %',j;END IF;
 dep:=date_trunc('second',s.storage_started_utc+interval '2 minutes');
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',dep,2688.13,gen_random_uuid());
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'fixture request: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid;
 j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(owner_id,s.airline_id,rid);
 IF j->>'slotsReserved' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'fixture slots: %',j;END IF;
 j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(owner_id,s.airline_id,rid);
 IF j->>'fundsHeld' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'fixture hold: %',j;END IF;
 SELECT cash_usd INTO cash_held FROM airlinerra_game.airlines WHERE id=s.airline_id;
 UPDATE airlinerra_game.aircraft_storage_execution_release_v1 SET fuel_adapter_enabled=true,execution_enabled=true WHERE world_id=1;
 UPDATE airlinerra_game.aircraft_storage_signed_movement_release_v1 SET enabled=true WHERE world_id=1;
 PERFORM set_config('test.storage_hour',dep::text,true);
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'departed');
 IF j->>'status' IS DISTINCT FROM 'reactivation_not_released' THEN RAISE EXCEPTION 'outbound release bypass: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=true WHERE world_id=1;
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'departed');
 IF j->>'status' IS DISTINCT FROM 'storage_dispatch_clearance_missing' THEN RAISE EXCEPTION 'clearance bypass: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_dispatch_clearance_v1(request_id,configuration_id,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,runway_review_reference,airport_restriction_review_reference,ferry_licence_review_reference,crew_review_reference,approved_at)
 VALUES(rid,1,r.origin_airport_key,r.destination_airport_key,dep,r.arrival_utc,'fixture','fixture','fixture','fixture',dep-interval '1 minute');
 PERFORM set_config('test.storage_maintenance','blocked',true);
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'departed');
 IF j->>'status' IS DISTINCT FROM 'storage_maintenance_blocked' THEN RAISE EXCEPTION 'maintenance bypass: %',j;END IF;
 PERFORM set_config('test.storage_maintenance','clear',true);
 -- No fuel supplier approved at this storage-only origin: do not top up.
 physical:=rid::text||':'||(dep AT TIME ZONE 'UTC')::date::text||':1';
 j:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(physical);
 IF j->>'status' IS DISTINCT FROM 'blocked_no_game_airport_fuel_service' THEN RAISE EXCEPTION 'storage fuel supplier bypass: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_fuel_services_v1 VALUES(1,s.airport_key,'JET','synthetic approval only');
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,movementRecorded}' IS DISTINCT FROM 'true' OR j#>>'{results,0,settlement,billingStopped}' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'automatic outbound departure: %',j;END IF;
 PERFORM set_config('test.storage_hour',r.arrival_utc::text,true);
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 WHERE physical_flight_id=physical AND onboard_at_departure_kg=1200 AND planned_trip_burn_kg=1000 AND planned_contingency_kg=50 AND planned_holding_reserve_kg=150) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_approved_fuel_load_receipts_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND at_airport_key=s.airport_key AND load_added_kg=1000 AND fuel_after_load_kg=1200) THEN RAISE EXCEPTION 'actual fuel topup or departure receipt missing';END IF;
 SELECT revision INTO original_revision FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id;
 UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1 SET revision=revision+1 WHERE aircraft_inventory_id=r.aircraft_inventory_id;
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,status}' IS DISTINCT FROM 'storage_leg_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=rid AND phase='arrived') OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND location_status='in_flight') THEN RAISE EXCEPTION 'arrival rollback failed: %',j;END IF;
 IF (SELECT tracked_flight_cycles FROM airlinerra_game.aircraft_maintenance_state_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id)<>5 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 WHERE physical_flight_id=physical) THEN RAISE EXCEPTION 'airframe usage escaped failed transaction';END IF;
 UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1 SET revision=original_revision WHERE aircraft_inventory_id=r.aircraft_inventory_id;
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,settlement,status}' IS DISTINCT FROM 'aircraft_reactivated' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='in_service') OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=r.airline_id) IS DISTINCT FROM cash_held THEN RAISE EXCEPTION 'automatic outbound arrival: %',j;END IF;
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'arrived');
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'worker replay: %',j;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND onboard_kg=200 AND at_airport_key=r.destination_airport_key AND source_event_kind='signed_arrival_burn' AND revision=original_revision+1) THEN RAISE EXCEPTION 'actual arrival custody not reconciled';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_maintenance_state_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND tracked_flight_cycles=6 AND tracked_flight_hours=12+round(extract(epoch FROM(r.arrival_utc-r.departure_utc))/3600,3)) THEN RAISE EXCEPTION 'actual airframe usage not reconciled';END IF;
 RAISE NOTICE 'Actual fuel custody, receipt and maintenance-window runtime acceptance passed (synthetic model and due-check inputs)';
END $test$;
ROLLBACK TO SAVEPOINT actual_fuel_outbound;
