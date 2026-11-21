-- PRE-LAUNCH acceptance only. No production state is committed.
-- Requires world 1 paused, one in-service original airline and starter aircraft,
-- current verified game day and installed single-route engine. Only test clock,
-- maintenance baseline and permit due date are simulated. Real signing, demand,
-- movement, fuel receipt and finance code are exercised.
BEGIN;
DO $guard$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1 AND release_state='paused')
 OR EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE status='active')
 OR (SELECT count(*) FROM airlinerra_game.airlines WHERE world_id=1)<>1
 THEN RAISE EXCEPTION 'Only an empty paused prelaunch world may run this rollback test';END IF;
END $guard$;
UPDATE airlinerra_game.section9_activation_release_policy_v1 SET release_state='enabled',enabled_at=now(),reviewed_at=now(),approved_by='rollback acceptance test',release_reference='ROLLBACK_SINGLE_ROUTE_ACCEPTANCE_ONLY' WHERE world_id=1;
UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1 SET release_state='enabled',enabled_at=now(),reviewed_at=now(),approved_by='rollback acceptance test',release_reference='ROLLBACK_SINGLE_ROUTE_ACCEPTANCE_ONLY' WHERE world_id=1;
UPDATE airlinerra_game.section9_fuel_and_settlement_release_policy_v1 SET release_state='enabled',enabled_at=now(),approved_at=now(),approved_by='rollback acceptance test',review_reference='ROLLBACK_SINGLE_ROUTE_ACCEPTANCE_ONLY',execution_producer_evidence='ROLLBACK_ACCEPTANCE_TEST_ONLY',fuel_writer_evidence='ROLLBACK_ACCEPTANCE_TEST_ONLY',settlement_writer_evidence='ROLLBACK_ACCEPTANCE_TEST_ONLY' WHERE world_id=1;
UPDATE airlinerra_game.section9_flight_finance_posting_release_v1 SET release_state='approved',approved_at=now(),approval_reference='ROLLBACK_SINGLE_ROUTE_ACCEPTANCE_ONLY' WHERE world_id=1;
ALTER TABLE airlinerra_game.section9_aoc_release_policy_v1 DROP CONSTRAINT section9_aoc_release_not_before_verified_cutover_v1;
UPDATE airlinerra_game.section9_aoc_release_policy_v1 SET issuance_enabled=true,renewal_enabled=true,safety_events_enabled=true,flight_enforcement_enabled=true WHERE world_id=1;
SELECT airlinerra_game.section9_aoc_issue_original_v1(id) FROM airlinerra_game.airlines;
UPDATE airlinerra_game.section9_starter_game_airframe_baselines_v1 SET game_baseline_date=current_date WHERE world_id=1;
ALTER TABLE airlinerra_game.business_permission_catalog_v1 DROP CONSTRAINT business_permission_catalog_v1_enabled_in_game_check;
UPDATE airlinerra_game.business_permission_catalog_v1 SET enabled_in_game=true WHERE permission_code='DOMESTIC_TRAFFIC';
UPDATE airlinerra_game.section9_game_permission_issuance_policy_v1 SET release_enabled=true,released_at=now(),reviewed_by='AIRLINERRA_GAME_AUTHORITY_AUTO_V1',release_reference='AUTO_GAME_AUTHORITY_PHASE1_ROLLBACK_ONLY' WHERE permission_code='DOMESTIC_TRAFFIC';
CREATE TEMP TABLE test_receipts(k text,r jsonb);
INSERT INTO test_receipts SELECT 'submit',airlinerra_game.section9_submit_game_permission_application_v1(a.owner_player_id,a.id,gen_random_uuid(),'DOMESTIC_TRAFFIC',a.home_airport_key,'FICTIONAL:fictional:RS:LYAL','passenger') FROM airlinerra_game.airlines a;
UPDATE airlinerra_game.section9_game_permission_applications_v1 SET applied_game_date=applied_game_date-1,due_game_date=due_game_date-1 WHERE permission_code='DOMESTIC_TRAFFIC' AND status='submitted' AND id=(SELECT (r->>'applicationId')::uuid FROM test_receipts WHERE k='submit');
INSERT INTO test_receipts SELECT 'review',airlinerra_game.section9_review_due_game_permissions_auto_v1(5);
CREATE TEMP TABLE acceptance_clock AS SELECT airlinerra_game.section9_verified_berlin_game_hour_v1() AS proof,date_trunc('minute',now())-interval '45 minutes' AS departure;
UPDATE acceptance_clock SET proof=jsonb_set(proof,'{gameHourUtc}',to_jsonb(departure-interval '30 minutes'));
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1() RETURNS jsonb LANGUAGE sql AS $test$ SELECT proof FROM pg_temp.acceptance_clock $test$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS $test$ SELECT (proof->>'gameHourUtc')::timestamptz FROM pg_temp.acceptance_clock $test$;
INSERT INTO test_receipts SELECT 'create',airlinerra_game.section9_create_active_route_from_weekly_v1(a.owner_player_id,a.id,f.id,a.iata_code||'991',a.home_airport_key,'FICTIONAL:fictional:RS:LYAL',jsonb_build_array(jsonb_build_object('day',extract(isodow from current_date)::int-1,'time',to_char(c.departure AT TIME ZONE 'Europe/Belgrade','HH24:MI'))),'terminal','terminal',45,50) FROM airlinerra_game.airlines a JOIN airlinerra_game.airline_aircraft_inventory f ON f.airline_id=a.id CROSS JOIN acceptance_clock c LIMIT 1;
INSERT INTO test_receipts SELECT 'demand',airlinerra_game.section9_auto_reserve_verified_flight_demand_v1(10);
INSERT INTO test_receipts SELECT 'demandReplay',airlinerra_game.section9_auto_reserve_verified_flight_demand_v1(10);
UPDATE acceptance_clock SET proof=jsonb_set(proof,'{gameHourUtc}',to_jsonb(departure+interval '1 minute'));
INSERT INTO test_receipts SELECT 'departure',airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
INSERT INTO test_receipts SELECT 'departureReplay',airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
UPDATE acceptance_clock SET proof=jsonb_set(proof,'{gameHourUtc}',to_jsonb((SELECT coalesce((r->>'referenceArrivalUtc')::timestamptz,now()) FROM test_receipts WHERE k='create')+interval '1 minute'));
INSERT INTO test_receipts SELECT 'arrival',airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
INSERT INTO test_receipts SELECT 'arrivalReplay',airlinerra_game.section9_auto_dispatch_due_flight_events_v1(10);
INSERT INTO test_receipts SELECT 'financePrepare',airlinerra_game.section9_prepare_arrived_actual_ticket_finance_batch_v1(10);
INSERT INTO test_receipts SELECT 'cost',airlinerra_game.section9_auto_approve_completed_game_flight_costs_v1(10);
INSERT INTO test_receipts SELECT 'finance',airlinerra_game.section9_auto_post_complete_game_flights_v1(10);
INSERT INTO test_receipts SELECT 'financeReplay',airlinerra_game.section9_auto_post_complete_game_flights_v1(10);
SELECT jsonb_object_agg(k,r) receipts FROM test_receipts;
ROLLBACK;
