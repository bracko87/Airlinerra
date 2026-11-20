-- Private, independently recomputed SOURCE SNAPSHOT for future flight
-- execution / commercial finance authorities.
-- A candidate snapshot is NOT a signed certificate or final authority.
-- The live certification sink STILL rejects these two unimplemented types.
-- The function is read-only, has no keys, and never enables release flags.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_execution_finance_source_snapshot_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_game_date date,
 p_clearance_type text
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $snapshot$
DECLARE
 candidate jsonb; schedule_row record;fleet_row record;
 activation_row record;execution_row record;finance_row record;
 fuel_row record;run_row record;fingerprint text;source_version text;
 blockers jsonb;ready boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PRIVATE_EXECUTION_FINANCE_SOURCE_SNAPSHOT_ONLY';
 END IF;
 IF p_airline IS NULL OR p_schedule IS NULL OR p_version IS NULL
 OR p_version<1 OR p_game_date IS NULL
 OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_clearance_type IS NULL
 OR p_clearance_type NOT IN ('trusted_flight_execution','commercial_finance')
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_EXECUTION_FINANCE_SOURCE_SNAPSHOT_SCOPE';END IF;

 -- The canonical private preflight rechecks signed-verified Berlin time,
 -- release approvals, fleet ownership, released fuel model, three earlier
 -- independently signed certificates and their audit event identity.
 candidate:=airlinerra_game.section9_execution_finance_certificate_source_preflight_v1(
  p_airline,p_schedule,p_version,p_game_date,p_clearance_type);
 IF candidate->>'worldId' IS DISTINCT FROM '1'
 OR candidate->>'airlineId' IS DISTINCT FROM p_airline::text
 OR candidate->>'scheduleId' IS DISTINCT FROM p_schedule::text
 OR candidate->>'scheduleVersion' IS DISTINCT FROM p_version::text
 OR candidate->>'gameDate' IS DISTINCT FROM p_game_date::text
 OR candidate->>'clearanceType' IS DISTINCT FROM p_clearance_type
 OR candidate->>'readOnly' IS DISTINCT FROM 'true'
 OR candidate->>'certificateIssued' IS DISTINCT FROM 'false'
 OR candidate->>'verified' IS DISTINCT FROM 'false'
 OR jsonb_typeof(candidate->'blockers') IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_SOURCE_PREFLIGHT_UNTRUSTED_RESULT';END IF;

 blockers:=candidate->'blockers';
 ready:=candidate->>'status'='source_preflight_complete_not_certifiable'
 AND jsonb_array_length(blockers)=0;

 SELECT id,airline_id,version,aircraft_inventory_id,configuration_id,
        origin_airport_key,destination_airport_key,reference_departure_utc,
        reference_arrival_utc,weekly_schedule,status,operationally_verified
 INTO schedule_row
 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_schedule AND airline_id=p_airline AND world_id=1
 AND version=p_version;
 IF NOT FOUND THEN ready:=false;
 ELSE
  SELECT id,airline_id,configuration_id,ownership_type,fleet_status
  INTO fleet_row FROM airlinerra_game.airline_aircraft_inventory
  WHERE id=schedule_row.aircraft_inventory_id AND airline_id=p_airline;
  IF NOT FOUND OR fleet_row.configuration_id IS DISTINCT FROM schedule_row.configuration_id
  THEN ready:=false;END IF;
 END IF;
 SELECT * INTO activation_row
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO execution_row
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO finance_row
 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1;
 SELECT * INTO fuel_row
 FROM airlinerra_game.section9_fuel_and_settlement_release_policy_v1 WHERE world_id=1;
 SELECT * INTO run_row
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;

 IF activation_row.release_state IS DISTINCT FROM 'enabled'
 OR execution_row.release_state IS DISTINCT FROM 'enabled'
 OR fuel_row.release_state IS DISTINCT FROM 'enabled'
 OR run_row.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR run_row.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR run_row.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 OR length(coalesce(fuel_row.execution_producer_evidence,''))<20
 OR length(coalesce(fuel_row.fuel_writer_evidence,''))<20
 OR length(coalesce(fuel_row.settlement_writer_evidence,''))<20
 THEN ready:=false;END IF;
 IF p_clearance_type='commercial_finance'
 AND (finance_row.release_state IS DISTINCT FROM 'approved'
 OR finance_row.approved_at IS NULL
 OR length(coalesce(finance_row.approval_reference,''))<20)
 THEN ready:=false;END IF;

 source_version:='SECTION9_INDEPENDENT_SOURCE_SNAPSHOT_CANDIDATE_V1';
 IF ready THEN
  -- Compute the fingerprint inside Postgres from persisted version-bound
  -- flight identity, reviewed release references and verified game day.
  -- None of these are accepted from the caller as arbitrary JSON.
  fingerprint:=md5(concat_ws(E'\n',source_version,p_clearance_type,
   p_airline::text,p_schedule::text,p_version::text,p_game_date::text,
   schedule_row.aircraft_inventory_id::text,
   schedule_row.configuration_id::text,
   schedule_row.origin_airport_key,schedule_row.destination_airport_key,
   schedule_row.reference_departure_utc::text,
   schedule_row.reference_arrival_utc::text,
   schedule_row.weekly_schedule::text,
   fleet_row.ownership_type,fleet_row.fleet_status,
   activation_row.release_reference,execution_row.release_reference,
   fuel_row.review_reference,fuel_row.execution_producer_evidence,
   fuel_row.fuel_writer_evidence,fuel_row.settlement_writer_evidence,
   CASE WHEN p_clearance_type='commercial_finance'
    THEN finance_row.approval_reference ELSE 'NOT_FINANCE_AUTHORITY' END));
 END IF;

 RETURN jsonb_build_object(
  'status',CASE WHEN ready
   THEN 'source_snapshot_candidate_not_authorized'
   ELSE 'blocked_unreleased_execution_finance_source_snapshot' END,
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_version,'gameDate',p_game_date,
  'clearanceType',p_clearance_type,'snapshotVersion',source_version,
  'sourceFingerprint',fingerprint,
  'sourceReference',CASE WHEN ready THEN
   'candidate-execution-finance-v1-'||fingerprint ELSE NULL END,
  'blockers',blockers,'candidateReady',ready,
  'verified',false,'certificateIssued',false,
  'sourceAuthorityReleased',false,'readOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $snapshot$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_execution_finance_source_snapshot_v1(
 uuid,uuid,integer,date,text)
 FROM PUBLIC,anon,authenticated,service_role;
