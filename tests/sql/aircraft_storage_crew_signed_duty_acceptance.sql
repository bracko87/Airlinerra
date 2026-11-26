-- Signed crew duty integration: synthetic fuel, maintenance, and accelerated reporting policy.
SAVEPOINT automatic_outbound;
ALTER TABLE airlinerra_game.section9_aircraft_current_position_v1 ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT clock_timestamp();
CREATE TABLE airlinerra_game.section9_crew_scheduler_policy_v2(world_id smallint PRIMARY KEY,preflight_minutes int,postflight_minutes int,minimum_rest_minutes int);
INSERT INTO airlinerra_game.section9_crew_scheduler_policy_v2 VALUES(1,1,30,720);
CREATE TABLE airlinerra_game.section9_flight_crew_model_policy_v1(configuration_id bigint PRIMARY KEY,qualification_group text,minimum_cabin_crew int);
INSERT INTO airlinerra_game.section9_flight_crew_model_policy_v1 VALUES(1,'fixture',0);
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
-- Controlled commercial history input; signed storage receipts are real review records.
CREATE FUNCTION airlinerra_game.section9_crew_actual_history_v1(p_airline uuid,p_employee uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT coalesce(nullif(current_setting('test.storage_commercial_history',true),'')::jsonb,jsonb_build_object('availableForNewDuty',true,'history','[]'::jsonb))
$$;
DO $test$
DECLARE s record; r record; owner_id uuid; rid uuid; dep timestamptz; j jsonb; cash_held numeric; cap uuid:=gen_random_uuid();fo uuid:=gen_random_uuid();h jsonb;
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
 INSERT INTO airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,airline_id,employee_id,seat_role,qualification_group,duty_start_utc,duty_end_utc,origin_airport_key,destination_airport_key,reserved_at)
 VALUES(rid,s.airline_id,cap,'captain','fixture',dep-interval '1 minute',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,s.storage_started_utc),
 (rid,s.airline_id,fo,'first_officer','fixture',dep-interval '1 minute',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,s.storage_started_utc);
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
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND arrival_engine_event_id IS NULL)<>2 THEN RAISE EXCEPTION 'signed crew departure receipts missing';END IF;
 PERFORM set_config('test.storage_hour',r.arrival_utc::text,true);
 PERFORM set_config('test.storage_fail_burn','yes',true);
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,status}' IS DISTINCT FROM 'storage_leg_rolled_back' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=rid AND phase='arrived') OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND location_status='in_flight') THEN RAISE EXCEPTION 'arrival rollback failed: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND arrival_engine_event_id IS NOT NULL) THEN RAISE EXCEPTION 'failed arrival completed crew duty';END IF;
 PERFORM set_config('test.storage_fail_burn','no',true);
 j:=airlinerra_game.advance_aircraft_storage_relocations_v1(10);
 IF j#>>'{results,0,settlement,status}' IS DISTINCT FROM 'aircraft_reactivated' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='in_service') OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=r.airline_id) IS DISTINCT FROM cash_held THEN RAISE EXCEPTION 'automatic outbound arrival: %',j;END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE request_id=rid AND actual_arrival_utc=r.arrival_utc AND completed_duty_end_utc=r.arrival_utc+interval '30 minutes' AND rest_complete_utc=r.arrival_utc+interval '12 hours 30 minutes')<>2 THEN RAISE EXCEPTION 'completed crew duties missing';END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'crew custody released prematurely';END IF;
 h:=airlinerra_game.storage_crew_completed_duty_history_v1(s.airline_id,cap,r.arrival_utc);
 IF h->>'lastAirport' IS DISTINCT FROM r.destination_airport_key OR h->>'restComplete' IS DISTINCT FROM 'false' OR jsonb_array_length(h->'history')<>0 THEN RAISE EXCEPTION 'crew arrival read model incorrect: %',h;END IF;
 h:=airlinerra_game.storage_crew_completed_duty_history_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes');
 IF h->>'restComplete' IS DISTINCT FROM 'true' OR h->>'availableForNewDuty' IS DISTINCT FROM 'false' OR jsonb_array_length(h->'history')<>1 THEN RAISE EXCEPTION 'crew rest/handoff state incorrect: %',h;END IF;
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc,r.origin_airport_key,dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_storage_duty_pending' THEN RAISE EXCEPTION 'combined history accepted postflight: %',h;END IF;
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 29 minutes',r.origin_airport_key,dep-interval '10 days');
 IF h->>'eligibleByHistory' IS DISTINCT FROM 'false' OR h->>'lastAirport' IS DISTINCT FROM r.destination_airport_key THEN RAISE EXCEPTION 'combined history premature rest: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history',jsonb_build_object('availableForNewDuty',true,'history',jsonb_build_array(jsonb_build_object('startUtc',dep-interval '2 days','endUtc',dep-interval '2 days'+interval '4 hours','origin','OURAIRPORTS:999','destination',r.origin_airport_key)))::text,true);
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes','OURAIRPORTS:999',dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' OR h->>'availableForNewDuty' IS DISTINCT FROM 'false' OR h->>'lastAirport' IS DISTINCT FROM r.destination_airport_key OR h->>'storageDutyCount' IS DISTINCT FROM '1' OR h->>'commercialDutyCount' IS DISTINCT FROM '1' OR jsonb_array_length(h->'history')<>2 OR h#>>'{history,0,destination}' IS DISTINCT FROM r.origin_airport_key THEN RAISE EXCEPTION 'combined history merge failed: %',h;END IF;
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes','WRONG',dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_crew_history_conflict' THEN RAISE EXCEPTION 'wrong checkpoint accepted: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history',jsonb_build_object('availableForNewDuty',true,'history',jsonb_build_array(jsonb_build_object('startUtc',dep-interval '4 hours','endUtc',dep-interval '2 hours','origin','OURAIRPORTS:999','destination',r.origin_airport_key)))::text,true);
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes','OURAIRPORTS:999',dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_crew_history_conflict' THEN RAISE EXCEPTION 'inadequate inter-duty rest accepted: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history',jsonb_build_object('availableForNewDuty',false,'history','[]'::jsonb)::text,true);
 h:=airlinerra_game.storage_crew_combined_history_preview_v1(s.airline_id,cap,r.arrival_utc+interval '12 hours 30 minutes',r.origin_airport_key,dep-interval '10 days');
 IF h->>'status' IS DISTINCT FROM 'combined_commercial_history_unverified' THEN RAISE EXCEPTION 'unverified commercial history accepted: %',h;END IF;
 PERFORM set_config('test.storage_commercial_history','',true);
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff')<>2 THEN RAISE EXCEPTION 'history preview released custody';END IF;
 RAISE NOTICE 'Combined commercial and signed storage crew history acceptance passed (synthetic commercial history)';

 j:=airlinerra_game.execute_aircraft_storage_leg_v1(rid,'arrived');
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'worker replay: %',j;END IF;
 RAISE NOTICE 'Signed storage crew duty receipt acceptance passed (synthetic fuel, maintenance and reporting policy)';
END $test$;
ROLLBACK TO SAVEPOINT automatic_outbound;

ROLLBACK TO SAVEPOINT storage_crew_guard;
