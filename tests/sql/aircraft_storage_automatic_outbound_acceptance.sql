-- Synthetic worker integration, NOT real fuel or maintenance acceptance.
SAVEPOINT automatic_outbound;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT clock_timestamp();
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(world_id smallint PRIMARY KEY,release_state text);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(world_id smallint PRIMARY KEY,release_state text);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(world_id smallint PRIMARY KEY,trusted_flight_execution_release text,fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled boolean);
INSERT INTO airlinerra_game.section9_activation_release_policy_v1 VALUES(1,'enabled');
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1 VALUES(1,'enabled');
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1 VALUES(1,'ACTIVATED','ACTIVATED',true);
CREATE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(uuid,date,integer) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1() RETURNS date LANGUAGE sql AS $$SELECT (airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date$$;
CREATE OR REPLACE FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(p_owner uuid,p_airline uuid,p_aircraft uuid,p_depart_utc timestamptz,p_arrive_utc timestamptz) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameMaintenanceClear',current_setting('test.storage_maintenance',true)='clear')$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(p_physical_flight_id text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('status','game_fuel_already_sufficient')$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('fuelVerifiedForGame',true,'plannedTripBurnKg',1000)$$;
CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,departure_engine_event_id text,planned_trip_burn_kg numeric);
CREATE FUNCTION airlinerra_game.section9_capture_verified_departure_fuel_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 SELECT $1,airline_id,aircraft_inventory_id,$2,1000 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=$2 AND phase='departed' AND flight_occurrence_id=$1;
 RETURN jsonb_build_object('fuelReceiptCreated',FOUND);
END $$;
CREATE FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 SELECT a.flight_occurrence_id,a.airline_id,a.aircraft_inventory_id,a.engine_event_id,d.engine_event_id,1,1 FROM airlinerra_game.section9_operated_flight_movements_v1 a JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.flight_occurrence_id=a.flight_occurrence_id AND d.phase='departed' WHERE a.flight_occurrence_id=$1 AND a.phase='arrived';
 RETURN jsonb_build_object('usageApplied',FOUND);
END $$;
CREATE FUNCTION airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(text,text) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('test.storage_fail_burn',true)='yes' THEN RETURN jsonb_build_object('fuelBurnRecorded',false);END IF;
 INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SELECT $1,airline_id,aircraft_inventory_id,$2,1000,destination_airport_key FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=$2 AND phase='arrived' AND flight_occurrence_id=$1;
 RETURN jsonb_build_object('fuelBurnRecorded',FOUND);
END $$;
DO $test$
DECLARE s record; r record; owner_id uuid; rid uuid; dep timestamptz; j jsonb; cash_held numeric;
BEGIN
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
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
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,movementRecorded}' IS DISTINCT FROM 'true' OR j#>>'{results,0,settlement,billingStopped}' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'automatic outbound departure: %',j;END IF;
 PERFORM set_config('test.storage_hour',r.arrival_utc::text,true);
 PERFORM set_config('test.storage_fail_burn','yes',true);
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,status}' IS DISTINCT FROM 'storage_leg_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=rid AND phase='arrived') OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND location_status='in_flight') THEN RAISE EXCEPTION 'arrival rollback failed: %',j;END IF;
 PERFORM set_config('test.storage_fail_burn','no',true);
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,settlement,status}' IS DISTINCT FROM 'aircraft_reactivated' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='in_service') OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=r.airline_id) IS DISTINCT FROM cash_held THEN RAISE EXCEPTION 'automatic outbound arrival: %',j;END IF;
 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'arrived');
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'worker replay: %',j;END IF;
 RAISE NOTICE 'Synthetic automatic outbound worker acceptance passed (fuel and maintenance doubles)';
END $test$;
ROLLBACK TO SAVEPOINT automatic_outbound;
