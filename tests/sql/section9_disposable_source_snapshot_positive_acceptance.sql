-- Run only after real production preflight + source snapshot definitions
-- have been installed in an isolated disposable PostgreSQL 17 instance.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 s uuid:='44444444-4444-4444-8444-444444444444';
 day date:=DATE '2026-11-20';
 exec_result jsonb; finance_result jsonb;
 next_result jsonb; original_hash text; finance_hash text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'REFUSE_NON_DISPOSABLE_SNAPSHOT_ASSERTIONS';END IF;
 exec_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 finance_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'commercial_finance');
 IF exec_result->>'status'<>'source_snapshot_candidate_not_authorized'
 OR finance_result->>'status'<>'source_snapshot_candidate_not_authorized'
 OR exec_result->>'candidateReady'<>'true'
 OR finance_result->>'candidateReady'<>'true'
 OR exec_result->>'verified'<>'false'
 OR finance_result->>'verified'<>'false'
 OR exec_result->>'certificateIssued'<>'false'
 OR finance_result->>'certificateIssued'<>'false'
 OR exec_result->>'sourceAuthorityReleased'<>'false'
 OR finance_result->>'sourceAuthorityReleased'<>'false'
 THEN RAISE EXCEPTION 'Real positive snapshots not safe: execution %, finance %',
   exec_result,finance_result;END IF;
 original_hash:=exec_result->>'sourceFingerprint';
 finance_hash:=finance_result->>'sourceFingerprint';
 IF original_hash IS NULL OR original_hash !~ '^[a-f0-9]{32}$'
 OR finance_hash IS NULL OR finance_hash !~ '^[a-f0-9]{32}$'
 OR original_hash=finance_hash THEN
  RAISE EXCEPTION 'Source identity fingerprints invalid or not typed';
 END IF;

 -- Stable requests against unchanged DB produce identical evidence.
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 IF next_result->>'sourceFingerprint'<>original_hash THEN
  RAISE EXCEPTION 'Identical source reads have unstable fingerprint';END IF;

 -- A schedule route change invalidates the original source identity.
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET destination_airport_key='OURAIRPORTS:2213' WHERE id=s;
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 IF next_result->>'sourceFingerprint'=original_hash
 OR next_result->>'candidateReady'<>'true' THEN
  RAISE EXCEPTION 'Changed destination did not alter candidate fingerprint: %',
   next_result;END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET destination_airport_key='OURAIRPORTS:2218' WHERE id=s;

 -- Release evidence changes must change fingerprint.
 UPDATE airlinerra_game.section9_fuel_and_settlement_release_policy_v1
 SET execution_producer_evidence='changed-disposable-execution-producer-evidence-2026'
 WHERE world_id=1;
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 IF next_result->>'sourceFingerprint'=original_hash
 OR next_result->>'candidateReady'<>'true' THEN
  RAISE EXCEPTION 'Changed release evidence not detected: %',next_result;END IF;
 UPDATE airlinerra_game.section9_fuel_and_settlement_release_policy_v1
 SET execution_producer_evidence='disposable-execution-producer-evidence-2026'
 WHERE world_id=1;

 -- Fail closed when an independently issued earlier certificate is revoked.
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
 SET review_status='revoked'
 WHERE schedule_id=s AND clearance_type='route_traffic_rights';
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 IF next_result->>'candidateReady'<>'false'
 OR next_result->>'sourceFingerprint' IS NOT NULL
 OR NOT(next_result->'blockers' ? 'PRIOR_INDEPENDENT_CERTIFICATIONS_MISSING')
 THEN RAISE EXCEPTION 'Revocation did not block source snapshot: %',next_result;
 END IF;
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
 SET review_status='certified'
 WHERE schedule_id=s AND clearance_type='route_traffic_rights';

 -- A finance release being paused blocks FINANCE independently.
 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='paused' WHERE world_id=1;
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'commercial_finance');
 IF next_result->>'candidateReady'<>'false'
 OR NOT(next_result->'blockers' ? 'FINANCE_POSTING_NOT_APPROVED')
 THEN RAISE EXCEPTION 'Unreleased finance approved: %',next_result;END IF;
 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='approved' WHERE world_id=1;

 -- Even with apparently valid release policies, clock identity is mandatory.
 UPDATE airlinerra_game.fixture_verified_clock SET enabled=false;
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 IF next_result->>'candidateReady'<>'false'
 OR NOT(next_result->'blockers' ? 'AUTHORITATIVE_GAME_DAY_NOT_VERIFIED')
 THEN RAISE EXCEPTION 'Unverified clock not blocked: %',next_result;END IF;
 UPDATE airlinerra_game.fixture_verified_clock SET enabled=true;

 -- Never silently treat a version bump as current evidence.
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET version=2 WHERE id=s;
 next_result:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,day,'trusted_flight_execution');
 IF next_result->>'candidateReady'<>'false'
 OR next_result->>'sourceFingerprint' IS NOT NULL
 THEN RAISE EXCEPTION 'Stale schedule version accepted: %',next_result;END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET version=1 WHERE id=s;

 -- Never generate events, movements, bookings or money.
 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_operational_certification_events_v1
  WHERE clearance_type IN ('trusted_flight_execution','commercial_finance'))
 THEN RAISE EXCEPTION 'Snapshot generated forbidden certifications';END IF;
 RAISE NOTICE 'PASS: both real functions positive; deterministic type-scoped fingerprints; schedule/evidence changes reflected; revoked cert, paused finance, bad clock, stale version blocked; zero certificates issued';
END $test$;
