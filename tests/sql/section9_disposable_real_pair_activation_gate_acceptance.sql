-- Inspect actual certified-pair SQL in a disposable database, transaction
-- rolled back. All releases manipulated here are ISOLATED TEST VALUES ONLY.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE
 player uuid:='22222222-2222-4222-8222-222222222222';
 stranger uuid:='33333333-3333-4333-8333-333333333333';
 airline uuid:='11111111-1111-4111-8111-111111111111';
 outward uuid:='44444444-4444-4444-8444-444444444444';
 homeward uuid:='55555555-5555-4555-8555-555555555555';
 x jsonb;denied boolean:=false;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'ACTIVATION_TEST_NOT_DISPOSABLE';END IF;
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
 player,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_operating_or_finance_release' OR
 x->>'pairActivated'<>'false' OR x->>'ticketsOpened'<>'0' OR
 x->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Paused release did not block: %',x;END IF;

 -- Simulate activation approval alone: independent execution & finance still off.
 UPDATE airlinerra_game.section9_activation_release_policy_v1
 SET release_state='enabled',enabled_at=now(),reviewed_at=now();
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
 player,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_operating_or_finance_release'
 THEN RAISE EXCEPTION 'Incomplete three-way release incorrectly accepted: %',x;END IF;
 UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1
 SET release_state='enabled',enabled_at=now();
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
 player,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_operating_or_finance_release'
 THEN RAISE EXCEPTION 'Unapproved finance release incorrectly accepted: %',x;END IF;
 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='approved',approved_at=now();
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
 player,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_operating_or_finance_release'
 THEN RAISE EXCEPTION 'Non-activated flight/fuel engine incorrectly accepted: %',x;END IF;
 UPDATE airlinerra_game.section9_flight_engine_readiness_audit_v1
 SET trusted_flight_execution_release='ACTIVATED',
 fuel_transaction_release='ACTIVATED',
 automatic_flight_and_fuel_settlement_enabled=true;
 UPDATE airlinerra_game.fixture_clock SET verified=false;
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
 player,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_operating_or_finance_release'
 THEN RAISE EXCEPTION 'Unsigned game hour incorrectly accepted: %',x;END IF;
 UPDATE airlinerra_game.fixture_clock SET verified=true,day=DATE '2026-11-19';
 x:=airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
 player,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 IF x->>'status'<>'blocked_operating_or_finance_release'
 THEN RAISE EXCEPTION 'Stale game date incorrectly accepted: %',x;END IF;
 UPDATE airlinerra_game.fixture_clock SET day=DATE '2026-11-20';

 -- All synthetic release gates are now valid. An unowned request must
 -- reject before looking up any schedule or aircraft.
 BEGIN
  PERFORM airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
   stranger,airline,outward,homeward,1,1,DATE '2026-11-20',28);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Spoofed airline ownership accepted';END IF;

 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
   player,airline,outward,outward,1,1,DATE '2026-11-20',28);
 EXCEPTION WHEN SQLSTATE '22023' THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'Same outbound/return schedule accepted';END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.fixture_effects)
 THEN RAISE EXCEPTION 'Blocked release created an operation';END IF;
 RAISE NOTICE 'PASS: production function denied paused releases, partial approvals, unverified/stale clock, unowned airline, invalid pair';
END $test$;
ROLLBACK;
