-- Phase 1 passenger cutover, verified using native rollback-only
-- route tests: Belgrade-Aleksandrovo (short flight) and Belgrade-Tivat
-- (124 reservations; departure, arrival, fuel, usage, settlement, replays).
-- Original company AOC issuance and renewal and active-route refresh passed.
-- No unsupported cabin classes, crew, cargo or subsidiary releases.
BEGIN;
DO $guard$
DECLARE clock jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'Private release only';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1 AND release_state='paused')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1 AND release_state='disabled')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_fuel_and_settlement_release_policy_v1 WHERE world_id=1 AND release_state='paused')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1 AND release_state='paused')
 OR EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE status='active')
 THEN RAISE EXCEPTION 'Expected paused pre-launch world';END IF;
 clock:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Verified game clock unavailable';END IF;
 IF (SELECT count(DISTINCT decrypted_secret) FROM vault.decrypted_secrets WHERE name IN ('airlinerra_game_clearance_operator_licence_v1','airlinerra_game_clearance_route_traffic_rights_v1','airlinerra_game_clearance_airport_slot_capacity_v1','airlinerra_game_clearance_trusted_flight_execution_v1','airlinerra_game_clearance_commercial_finance_v1') AND length(decrypted_secret)>=64)<>5
 THEN RAISE EXCEPTION 'Five private distinct signing keys required';END IF;
 IF NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='airlinerra_game_permission_auto_signing_v1' AND length(decrypted_secret)>=64)
 THEN RAISE EXCEPTION 'Permission signing key required';END IF;
 IF has_function_privilege('authenticated','airlinerra_game.section9_create_active_route_from_weekly_v1(uuid,uuid,uuid,text,text,text,jsonb,text,text,int,numeric)','execute')
 OR has_function_privilege('anon','airlinerra_game.section9_refresh_active_game_route_certifications_v1(int,boolean)','execute')
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-operated-flight-dispatch-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-route-passenger-demand-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-approved-final-flight-finance-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-active-route-recertification-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-aoc-routine-renewal-v1' AND active)
 THEN RAISE EXCEPTION 'Private production job or permission check failed';END IF;
END $guard$;
-- Replace the temporary prelaunch hard stops with scoped, reviewed phase-1
-- release constraints. Do not expose additional permissions.
ALTER TABLE airlinerra_game.business_permission_catalog_v1 DROP CONSTRAINT business_permission_catalog_v1_enabled_in_game_check;
ALTER TABLE airlinerra_game.business_permission_catalog_v1 ADD CONSTRAINT business_permission_catalog_v1_phase1_passenger_release_check CHECK (NOT enabled_in_game OR permission_code IN ('DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM'));
UPDATE airlinerra_game.business_permission_catalog_v1 SET enabled_in_game=true,updated_at=now() WHERE permission_code IN ('DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM');
UPDATE airlinerra_game.section9_game_permission_issuance_policy_v1
 SET release_enabled=true,released_at=now(),reviewed_at=now(),reviewed_by='AIRLINERRA_GAME_AUTHORITY_AUTO_V1',release_reference='AUTO_GAME_AUTHORITY_PHASE1_PASSENGER_20261121'
 WHERE permission_code IN ('DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM');
ALTER TABLE airlinerra_game.section9_aoc_release_policy_v1 DROP CONSTRAINT section9_aoc_release_not_before_verified_cutover_v1;
ALTER TABLE airlinerra_game.section9_aoc_release_policy_v1 ADD CONSTRAINT section9_aoc_verified_phase1_cutover_v1 CHECK (
  (NOT issuance_enabled AND NOT safety_events_enabled AND NOT renewal_enabled AND NOT flight_enforcement_enabled)
  OR (issuance_enabled AND safety_events_enabled AND renewal_enabled AND flight_enforcement_enabled AND reviewed_by='AIRLINERRA_VERIFIED_PASSENGER_PHASE1_20261121'));
UPDATE airlinerra_game.section9_aoc_release_policy_v1 SET issuance_enabled=true,safety_events_enabled=true,renewal_enabled=true,flight_enforcement_enabled=true,reviewed_by='AIRLINERRA_VERIFIED_PASSENGER_PHASE1_20261121',updated_at=now() WHERE world_id=1;
-- Free original AOC only. Do not change balances, maintenance, aircraft or
-- traffic-rights applications on behalf of any player.
DO $aoc$
DECLARE a record; proof jsonb; issued jsonb;
BEGIN
 FOR a IN SELECT id FROM airlinerra_game.airlines WHERE world_id=1 LOOP
  IF EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c WHERE c.airline_id=a.id) THEN CONTINUE;END IF;
  proof:=airlinerra_game.section9_aoc_original_backfill_readiness_v1(a.id);
  IF proof->>'canIssue' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Original AOC issuance readiness failed';END IF;
  issued:=airlinerra_game.section9_aoc_issue_original_v1(a.id);
  IF issued->>'issued' IS DISTINCT FROM 'true' OR issued->>'charged' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'Free original AOC issuance failed';END IF;
 END LOOP;
END $aoc$;
UPDATE airlinerra_game.section9_activation_release_policy_v1 SET release_state='enabled',enabled_at=now(),reviewed_at=now(),approved_by='AIRLINERRA_PASSENGER_PHASE1_VERIFIED',release_reference='PASSENGER_ATOMIC_ROUTE_ACCEPTANCE_20261121' WHERE world_id=1;
UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1 SET release_state='enabled',enabled_at=now(),reviewed_at=now(),updated_at=now(),approved_by='AIRLINERRA_PASSENGER_PHASE1_VERIFIED',release_reference='NATIVE_DISPATCH_ARRIVAL_PASSENGER_ACCEPTANCE_20261121' WHERE world_id=1;
UPDATE airlinerra_game.section9_fuel_and_settlement_release_policy_v1 SET release_state='enabled',enabled_at=now(),approved_at=now(),approved_by='AIRLINERRA_PASSENGER_PHASE1_VERIFIED',review_reference='ROLLBACK_FULL_LIFECYCLE_ACCEPTANCE_20261121',execution_producer_evidence='REAL_NATIVE_DISPATCH_DEPARTURE_ARRIVAL_TEST_20261121',fuel_writer_evidence='SHARED_PHASE_FUEL_RECEIPTS_ARRIVAL_TEST_20261121',settlement_writer_evidence='PASSENGER_COST_SETTLEMENT_REPLAY_TEST_20261121' WHERE world_id=1;
UPDATE airlinerra_game.section9_flight_finance_posting_release_v1 SET release_state='approved',approved_at=now(),approval_reference='REAL_ROLLBACK_PASSENGER_FINANCE_ACCEPTANCE_20261121' WHERE world_id=1;
DO $verify$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1 AND automatic_flight_and_fuel_settlement_enabled AND trusted_flight_execution_release='ACTIVATED' AND fuel_transaction_release='ACTIVATED') THEN RAISE EXCEPTION 'Commercial release readiness not confirmed';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airlines a WHERE a.world_id=1 AND airlinerra_game.section9_aoc_flight_release_readiness_v1(a.id,airlinerra_game.section9_verified_permission_game_day_v1())->>'authorized' IS DISTINCT FROM 'true') THEN RAISE EXCEPTION 'Company AOC not active';END IF;
END $verify$;
COMMIT;
