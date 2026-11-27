-- Disposable CI only; install after stored-aircraft read fixture.
-- Only screens and crew candidate input are synthetic; booking functions,
-- reservations, holds, cancellation and triggers are real review code.
BEGIN;
CREATE TABLE airlinerra_game.section9_crew_plan_batches_v1(plan_id uuid PRIMARY KEY,airline_id uuid,status text);
CREATE TABLE airlinerra_game.section9_planned_crew_duties_v1(plan_id uuid,airline_id uuid,pilot_id uuid,employee_id uuid GENERATED ALWAYS AS(pilot_id) STORED,duty_end_utc timestamptz);
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_operational_screen_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure)||jsonb_build_object('airportScreenPassed',true,'departureScreen',jsonb_build_object('passed',true),'arrivalScreen',jsonb_build_object('passed',true),'licenceScreen',jsonb_build_object('allowed',true),'crewScreen',jsonb_build_object('requirementsVerified',true))
$$;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_crew_candidates_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('status','storage_crew_candidates_found','captainsRequired',1,'firstOfficersRequired',1,'minimumCabinCrew',0,'qualificationGroup','fixture','candidateCaptains',jsonb_build_array('00000000-0000-4000-8000-000000000005'),'candidateFirstOfficers',jsonb_build_array('00000000-0000-4000-8000-000000000006'),'candidateCabinCrew','[]'::jsonb,'rotation',jsonb_build_object('startingAirport',q->>'originAirportKey','endingAirport',p_destination,'dutyStartUtc',p_departure-interval '1 hour','dutyEndUtc',(q->>'arrivalUtc')::timestamptz+interval '30 minutes'))
 FROM (SELECT airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure) q) x
$$;
CREATE FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(uuid,uuid,uuid,timestamptz,timestamptz) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameMaintenanceClear',true)$$;
CREATE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('status','game_fuel_already_sufficient')$$;
CREATE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('fuelVerifiedForGame',true,'plannedTripBurnKg',1000)$$;
-- Synthetic execution receipts, same fixtures used by isolated outbound acceptance.
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT clock_timestamp();
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(world_id smallint PRIMARY KEY,release_state text);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(world_id smallint PRIMARY KEY,release_state text);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(world_id smallint PRIMARY KEY,trusted_flight_execution_release text,fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled boolean);
INSERT INTO airlinerra_game.section9_activation_release_policy_v1 VALUES(1,'enabled');
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1 VALUES(1,'enabled');
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1 VALUES(1,'ACTIVATED','ACTIVATED',true);
CREATE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(uuid,date,integer) RETURNS boolean LANGUAGE sql AS $SELECT true$;
CREATE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1() RETURNS date LANGUAGE sql AS $SELECT (airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date$;



CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,departure_engine_event_id text,planned_trip_burn_kg numeric);
CREATE FUNCTION airlinerra_game.section9_capture_verified_departure_fuel_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $
BEGIN
 INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 SELECT $1,airline_id,aircraft_inventory_id,$2,1000 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=$2 AND phase='departed' AND flight_occurrence_id=$1;
 RETURN jsonb_build_object('fuelReceiptCreated',FOUND);
END $;
CREATE FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(text) RETURNS jsonb LANGUAGE plpgsql AS $
BEGIN
 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 SELECT a.flight_occurrence_id,a.airline_id,a.aircraft_inventory_id,a.engine_event_id,d.engine_event_id,1,1 FROM airlinerra_game.section9_operated_flight_movements_v1 a JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.flight_occurrence_id=a.flight_occurrence_id AND d.phase='departed' WHERE a.flight_occurrence_id=$1 AND a.phase='arrived';
 RETURN jsonb_build_object('usageApplied',FOUND);
END $;
CREATE FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $
BEGIN
 IF current_setting('test.storage_fail_burn',true)='yes' THEN RETURN jsonb_build_object('fuelBurnRecorded',false);END IF;
 INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SELECT $1,airline_id,aircraft_inventory_id,$2,1000,destination_airport_key FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=$2 AND phase='arrived' AND flight_occurrence_id=$1;
 RETURN jsonb_build_object('fuelBurnRecorded',FOUND);
END $;

COMMIT;
