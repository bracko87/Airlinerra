-- Unchanged production final finance writer acceptance on disposable PG17.
-- Verify release gate, missing preparation, mutex and no live money writes.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regprocedure('airlinerra_game.section9_post_completed_flight_finance_once_v1(text)') IS NOT NULL
 THEN RAISE EXCEPTION 'FINAL_FINANCE_TEST_DISPOSABLE_ONLY';END IF;
END $guard$;
ALTER TABLE airlinerra_game.section9_flight_finance_posting_release_v1
 ADD COLUMN approval_reference text;
ALTER TABLE airlinerra_game.section9_activation_release_policy_v1
 ADD COLUMN approval_reference text;
-- Do not modify the synthetic global game-control policy for other tests
-- except inside individual test transactions which roll back.
\i tests/sql/section9_disposable_original_final_finance_writer.sql
DO $guard_checks$
DECLARE r jsonb; flight text:='bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb:2026-11-21:1';
BEGIN
 r:=airlinerra_game.section9_post_completed_flight_finance_once_v1(flight);
 IF r->>'status'<>'blocked_game_financial_or_flight_release'
 OR r->>'ledgerPosted'<>'false' OR r->>'cashChanged'<>'false'
 THEN RAISE EXCEPTION 'Final finance writer release guard failed: %',r;END IF;
 IF has_function_privilege('anon',
    'airlinerra_game.section9_post_completed_flight_finance_once_v1(text)','EXECUTE')
 OR has_function_privilege('authenticated',
    'airlinerra_game.section9_post_completed_flight_finance_once_v1(text)','EXECUTE')
 OR has_function_privilege('service_role',
    'airlinerra_game.section9_post_completed_flight_finance_once_v1(text)','EXECUTE')
 THEN RAISE EXCEPTION 'Private finance writer exposed to client roles';END IF;
 RAISE NOTICE 'PASS original final finance writer release gate and private privileges';
END $guard_checks$;
-- Apply approved-looking synthetic release state inside rollback-only tx.
-- This tests the real writer's subsequent missing-preparation refusal.
BEGIN;
UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='approved',approved_at=now(),
     approval_reference='isolated-test-approval-ref-20261123'
 WHERE world_id=1;
UPDATE airlinerra_game.section9_activation_release_policy_v1
 SET release_state='enabled',enabled_at=now(),crew_mode='deferred_phase1'
 WHERE world_id=1;
UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1
 SET release_state='enabled',enabled_at=now() WHERE world_id=1;
UPDATE airlinerra_game.section9_flight_engine_readiness_audit_v1
 SET trusted_flight_execution_release='ACTIVATED',
 fuel_transaction_release='ACTIVATED',
 automatic_flight_and_fuel_settlement_enabled=true WHERE world_id=1;
DO $missing_preparation$
DECLARE r jsonb;flight text:='bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb:2026-11-21:1';
BEGIN
 r:=airlinerra_game.section9_post_completed_flight_finance_once_v1(flight);
 IF r->>'status'<>'blocked_missing_completed_ticket_preparation'
 OR r->>'ledgerPosted'<>'false' OR r->>'cashChanged'<>'false'
 THEN RAISE EXCEPTION 'Missing finance preparation not blocked: %',r;END IF;
 RAISE NOTICE 'PASS original final finance writer refuses missing posted-flight preparation';
END $missing_preparation$;
ROLLBACK;
