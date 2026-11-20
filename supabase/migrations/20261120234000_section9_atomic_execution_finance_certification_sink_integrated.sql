-- Section 9: FINAL certification sink hook for independently signed
-- trusted_flight_execution and commercial_finance evidence.
--
-- Must run after 20261120211500 fail-closed sink and
-- 20261120232000 locked source-reference recheck.
-- Does NOT bypass HMAC verification in private Node ingress, turn on
-- commercial operations, or create an issuance when source is blocked.
--
-- Source checks are recomputed under the certification sink's schedule
-- FOR UPDATE lock *inside the same transaction* as immutable audit writes.
DO $patch$
DECLARE
 definition text;
 prior_branch text;
 verified_branch text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game'
  AND p.proname='section9_record_verified_certification_event_v1'
  AND pg_get_function_identity_arguments(p.oid)=
  'p_airline uuid, p_schedule uuid, p_schedule_version integer, p_clearance_type text, p_action text, p_event_id text, p_source_reference text, p_reviewer_reference text, p_valid_from date, p_valid_until date, p_verified_hmac text';
 IF definition IS NULL THEN
  RAISE EXCEPTION 'SECTION9_SIGNED_CERTIFICATION_SINK_UNAVAILABLE';
 END IF;
 prior_branch:=$old$  ELSE
   -- Neither trusted flight execution nor commercial finance has an
   -- independently released live source verifier. A signed payload alone
   -- cannot certify operational readiness for either clearance type.
   -- This block must be replaced only alongside a verified private source
   -- reader, independent signing authority, and atomic SQL evidence recheck.
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION';
  END IF;$old$;
 verified_branch:=$new$  ELSIF p_clearance_type IN
    ('trusted_flight_execution','commercial_finance') THEN
   -- The private backend has already checked the independent per-type
   -- HMAC. Never accept a generic signed payload as sufficient: recompute
   -- the exact persisted source fingerprint and reviewer WITHIN this
   -- locked schedule transaction, before the audit INSERT below.
   fresh_execution_finance_proof:=
    airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
      p_airline,p_schedule,p_schedule_version,p_valid_from,
      p_clearance_type,p_source_reference,p_reviewer_reference);
   eligible:=fresh_execution_finance_proof->>'status'=
       'matching_source_candidate_rechecked'
    AND fresh_execution_finance_proof->>'sourceCandidateMatches'='true'
    AND fresh_execution_finance_proof->>'certificationIssued'='false'
    AND fresh_execution_finance_proof->>'certificateAuthorityReleased'='false'
    AND fresh_execution_finance_proof->>'readOnly'='true'
    AND fresh_execution_finance_proof->>'flightActivated'='false'
    AND fresh_execution_finance_proof->>'ledgerPosted'='false';
  ELSE
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNEXPECTED_CERTIFICATION_AUTHORITY';
  END IF;$new$;
 IF position(prior_branch IN definition)=0 THEN
  IF position('fresh_execution_finance_proof:=' IN definition)>0
  THEN
   RAISE NOTICE 'Section9 execution/finance atomic source checks already integrated';
   RETURN;
  END IF;
  RAISE EXCEPTION 'SECTION9_UNEXPECTED_CERTIFICATION_SINK_DEFINITION';
 END IF;
 IF length(definition)-length(replace(definition,prior_branch,''))<>length(prior_branch)
 THEN RAISE EXCEPTION 'SECTION9_AMBIGUOUS_CERTIFICATION_BRANCH'; END IF;
 IF position(' fresh_operator_proof jsonb;fresh_route_proof jsonb;' IN definition)=0
 THEN RAISE EXCEPTION 'SECTION9_UNEXPECTED_CERTIFICATION_DECLARATION'; END IF;
 definition:=replace(definition,
   ' fresh_operator_proof jsonb;fresh_route_proof jsonb;',
   ' fresh_operator_proof jsonb;fresh_route_proof jsonb;'||
   E'\n fresh_execution_finance_proof jsonb;');
 definition:=replace(definition,prior_branch,verified_branch);
 IF position('fresh_execution_finance_proof:=' IN definition)=0
 OR position('SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION' IN definition)>0
 THEN RAISE EXCEPTION 'SECTION9_CERTIFICATION_INTEGRATION_INCOMPLETE'; END IF;
 EXECUTE definition;
END $patch$;
-- Preserve no service-role/browser execution access.
REVOKE ALL ON FUNCTION airlinerra_game.section9_record_verified_certification_event_v1(
 uuid,uuid,integer,text,text,text,text,text,date,date,text)
 FROM PUBLIC,anon,authenticated,service_role;
