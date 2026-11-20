-- Positive/negative checks of exact production SQL verifier, disposable PG17.
\set ON_ERROR_STOP on
DO $verify$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 s uuid:='44444444-4444-4444-8444-444444444444';
 g date:=DATE '2026-11-20';
 kind text;ref text;reviewer text;res jsonb;snapshot jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'SECTION9_RECHECK_DISPOSABLE_ONLY';END IF;
 FOREACH kind IN ARRAY ARRAY['trusted_flight_execution','commercial_finance']
 LOOP
  reviewer:=CASE kind WHEN 'trusted_flight_execution'
   THEN 'independent-trusted-flight-execution-authority-v1'
   ELSE 'independent-commercial-finance-authority-v1' END;
  snapshot:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
   a,s,1,g,kind);
  IF snapshot->>'candidateReady'<>'true'
  THEN RAISE EXCEPTION 'No positive candidate for %: %',kind,snapshot;END IF;
  ref:=snapshot->>'sourceReference';
  res:=airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
   a,s,1,g,kind,ref,reviewer);
  IF res->>'sourceCandidateMatches'<>'true'
   OR res->>'certificationIssued'<>'false' THEN
   RAISE EXCEPTION 'Valid reference not matched: %',res;END IF;
  -- Exactly one changed hex digit is never a valid proof reference.
  res:=airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
   a,s,1,g,kind,ref||'e',reviewer);
  IF res->>'sourceCandidateMatches'<>'false'
  THEN RAISE EXCEPTION 'Tampered fingerprint accepted: %',res;END IF;
  res:=airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
   a,s,1,g,kind,ref,'untrusted-fraudulent-reviewer');
  IF res->>'sourceCandidateMatches'<>'false'
  THEN RAISE EXCEPTION 'Wrong source reviewer accepted: %',res;END IF;
 END LOOP;
 -- Updating saved route after obtaining earlier reference invalidates it.
 snapshot:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
  a,s,1,g,'trusted_flight_execution');
 ref:=snapshot->>'sourceReference';
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET destination_airport_key='OURAIRPORTS:2213' WHERE id=s;
 res:=airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
  a,s,1,g,'trusted_flight_execution',ref,
  'independent-trusted-flight-execution-authority-v1');
 IF res->>'sourceCandidateMatches'<>'false'
 THEN RAISE EXCEPTION 'Old route fingerprint survived changed destination';END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET destination_airport_key='OURAIRPORTS:2218' WHERE id=s;
 -- Certificate revoked between source creation and write must block.
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
 SET review_status='revoked'
 WHERE schedule_id=s AND clearance_type='route_traffic_rights';
 res:=airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
  a,s,1,g,'trusted_flight_execution',ref,
  'independent-trusted-flight-execution-authority-v1');
 IF res->>'sourceCandidateMatches'<>'false'
 THEN RAISE EXCEPTION 'Revoked source clearance survived recheck';END IF;
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
 SET review_status='certified'
 WHERE schedule_id=s AND clearance_type='route_traffic_rights';
 -- Pausing world execution invalidates previous reference.
 UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1
 SET release_state='disabled' WHERE world_id=1;
 res:=airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
  a,s,1,g,'trusted_flight_execution',ref,
  'independent-trusted-flight-execution-authority-v1');
 IF res->>'sourceCandidateMatches'<>'false'
 THEN RAISE EXCEPTION 'Execution released stale evidence';END IF;
 UPDATE airlinerra_game.section9_trusted_execution_release_policy_v1
 SET release_state='enabled' WHERE world_id=1;
 -- Production certification sink remains separately closed.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operational_certification_events_v1
  WHERE clearance_type IN('trusted_flight_execution','commercial_finance'))
 THEN RAISE EXCEPTION 'Verifier wrote unauthorized certificates';END IF;
 RAISE NOTICE 'PASS locked independent source recheck: both candidate types, altered fingerprints, reviewers, changed routes, revoked certificates and disabled release blocked';
END $verify$;
