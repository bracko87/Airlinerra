-- Same-transaction source-reference recheck for the future two authorities.
-- THIS IS NOT CERTIFICATION ISSUANCE. Existing certificate sink continues
-- explicitly denying both clearance types. No change to any release policy.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_game_date date,
 p_clearance_type text,p_source_reference text,p_reviewer_reference text
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $verify$
DECLARE snapshot jsonb; is_valid boolean:=false;expected_reviewer text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PRIVATE_EXECUTION_FINANCE_SAME_TRANSACTION_ONLY';
 END IF;
 IF p_airline IS NULL OR p_schedule IS NULL
 OR p_version IS NULL OR p_version<1 OR p_game_date IS NULL
 OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_clearance_type IS NULL OR p_clearance_type
  NOT IN ('trusted_flight_execution','commercial_finance')
 OR length(coalesce(p_source_reference,''))<16
 OR length(coalesce(p_source_reference,''))>160
 OR length(coalesce(p_reviewer_reference,''))<12
 OR length(coalesce(p_reviewer_reference,''))>160
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_EXECUTION_FINANCE_RECHECK_SCOPE';END IF;

 expected_reviewer:=CASE p_clearance_type
  WHEN 'trusted_flight_execution'
   THEN 'independent-trusted-flight-execution-authority-v1'
  WHEN 'commercial_finance'
   THEN 'independent-commercial-finance-authority-v1'
 END;
 -- Lock version-bound schedule for the duration of caller's transaction.
 -- Run after the caller's own row lock when integrated in certification sink.
 PERFORM 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_schedule AND airline_id=p_airline AND world_id=1
 AND version=p_version AND status='draft'
 AND operationally_verified=false FOR SHARE;
 IF FOUND THEN
  snapshot:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
   p_airline,p_schedule,p_version,p_game_date,p_clearance_type);
  is_valid:=snapshot->>'status'='source_snapshot_candidate_not_authorized'
   AND snapshot->>'candidateReady'='true'
   AND snapshot->>'readOnly'='true'
   AND snapshot->>'verified'='false'
   AND snapshot->>'certificateIssued'='false'
   AND snapshot->>'sourceAuthorityReleased'='false'
   AND snapshot->>'flightActivated'='false'
   AND snapshot->>'ledgerPosted'='false'
   AND snapshot->>'scheduleId'=p_schedule::text
   AND snapshot->>'scheduleVersion'=p_version::text
   AND snapshot->>'gameDate'=p_game_date::text
   AND snapshot->>'clearanceType'=p_clearance_type
   AND snapshot->>'sourceReference'=p_source_reference
   AND p_reviewer_reference=expected_reviewer
   AND snapshot->>'sourceFingerprint'~'^[a-f0-9]{32}$';
 END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN is_valid THEN 'matching_source_candidate_rechecked'
   ELSE 'blocked_execution_finance_source_reference' END,
  'sourceCandidateMatches',is_valid,'certificationIssued',false,
  'certificateAuthorityReleased',false,'readOnly',true,
  'flightActivated',false,'bookingsCreated',false,'ledgerPosted',false);
END $verify$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_recheck_execution_finance_source_reference_v1(
 uuid,uuid,integer,date,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;
