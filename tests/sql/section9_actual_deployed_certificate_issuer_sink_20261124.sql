-- Exact current 2026-11-24 read-only snapshot of deployed certifier and sink.
-- ONLY for disposable PG17; requires synthetic test-key Vault and source
-- fixture. NEVER deploy as migration or copy real secret values.
\set ON_ERROR_STOP on
DO $guard$ BEGIN IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres' THEN RAISE EXCEPTION 'SIGNER_SINK_SNAPSHOT_DISPOSABLE_ONLY';END IF;END $guard$;
-- Deployed function: section9_record_verified_certification_event_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_record_verified_certification_event_v1(p_airline uuid, p_schedule uuid, p_schedule_version integer, p_clearance_type text, p_action text, p_event_id text, p_source_reference text, p_reviewer_reference text, p_valid_from date, p_valid_until date, p_verified_hmac text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE target record;old_event record;existing record;
 evidence jsonb;rest jsonb;fields jsonb;slot_check jsonb;fresh_slot_proof jsonb;
 fresh_operator_proof jsonb;fresh_route_proof jsonb;
 fresh_execution_finance_proof jsonb;
 source_kind text;accepted_at timestamptz;
 eligible boolean:=false;expected_slots int;stored_slots int;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL
 OR p_schedule_version IS NULL OR p_schedule_version<1
 OR p_clearance_type IS NULL OR p_action IS NULL
 OR p_clearance_type NOT IN ('crew_duty','operator_licence',
  'route_traffic_rights','airport_slot_capacity',
  'trusted_flight_execution','commercial_finance')
 OR p_action NOT IN ('certify','revoke')
 OR p_event_id IS NULL OR
  p_event_id !~ '^[A-Za-z0-9._:-]{16,128}$'
 OR length(coalesce(p_source_reference,'')) NOT BETWEEN 16 AND 160
 OR length(coalesce(p_reviewer_reference,'')) NOT BETWEEN 12 AND 160
 OR p_valid_from IS NULL OR p_valid_until IS NULL OR
  p_valid_from NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_valid_until<p_valid_from
 OR p_valid_until>p_valid_from+365
 OR p_verified_hmac IS NULL OR p_verified_hmac !~ '^[a-f0-9]{64}$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_SIGNED_CERTIFICATION_EVENT';END IF;

 -- Schedule lock serializes approvals with schedule changes, other
 -- certification events and the version-fenced activation preparation.
 SELECT sch.*,a.owner_player_id,f.configuration_id AS aircraft_config,
 f.fleet_status INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 sch
 JOIN airlinerra_game.airlines a ON a.id=sch.airline_id AND a.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=sch.aircraft_inventory_id AND f.airline_id=sch.airline_id
 WHERE sch.id=p_schedule AND sch.airline_id=p_airline AND sch.world_id=1
 FOR UPDATE OF sch;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CERTIFICATION_SCHEDULE_NOT_FOUND';END IF;

 SELECT * INTO old_event
 FROM airlinerra_game.section9_operational_certification_events_v1
 WHERE event_id=p_event_id;
 IF FOUND THEN
  IF old_event.airline_id IS DISTINCT FROM p_airline OR
   old_event.schedule_id IS DISTINCT FROM p_schedule OR
   old_event.schedule_version IS DISTINCT FROM p_schedule_version OR
   old_event.clearance_type IS DISTINCT FROM p_clearance_type OR
   old_event.action IS DISTINCT FROM p_action OR
   old_event.source_reference IS DISTINCT FROM p_source_reference OR
   old_event.reviewer_reference IS DISTINCT FROM p_reviewer_reference OR
   old_event.valid_from_game_date IS DISTINCT FROM p_valid_from OR
   old_event.valid_to_game_date IS DISTINCT FROM p_valid_until OR
   old_event.verified_hmac_sha256 IS DISTINCT FROM p_verified_hmac
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_CERTIFICATION_EVENT_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object('status','certification_event_replayed',
   'eventId',p_event_id,'scheduleId',p_schedule,'replayed',true,
   'certificateChanged',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 IF target.version IS DISTINCT FROM p_schedule_version OR
  ((target.status IS DISTINCT FROM 'draft' OR target.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND target.status='active' AND target.operationally_verified=true))
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CERTIFICATION_REQUIRES_CURRENT_DRAFT_VERSION';END IF;

 source_kind:=CASE p_clearance_type
  WHEN 'crew_duty' THEN 'verified_crew_duty_engine'
  WHEN 'operator_licence' THEN 'verified_game_licence_engine'
  WHEN 'route_traffic_rights' THEN 'verified_game_traffic_rights_engine'
  WHEN 'airport_slot_capacity' THEN 'verified_airport_slot_engine'
  WHEN 'trusted_flight_execution' THEN 'trusted_flight_operations_engine'
  WHEN 'commercial_finance' THEN 'verified_commercial_settlement_engine'
 END;

 SELECT * INTO existing
 FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
 WHERE c.schedule_id=p_schedule AND c.schedule_version=p_schedule_version
  AND c.clearance_type=p_clearance_type FOR UPDATE;

 IF p_action='certify' THEN
  IF target.fleet_status IS DISTINCT FROM 'in_service'
    OR target.aircraft_config IS DISTINCT FROM target.configuration_id
    OR p_valid_until<p_valid_from+28
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CERTIFICATION_AIRCRAFT_OR_VALIDITY_NOT_READY';END IF;
  -- Only independent services can supply the signed proof, and the
  -- database still cross-checks facts it can verify itself. Planning
  -- evidence is never sufficient without that external service proof.
  IF p_clearance_type IN ('crew_duty','operator_licence',
    'route_traffic_rights') THEN
   evidence:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
    target.owner_player_id,p_airline,p_schedule,p_valid_from,28);
  END IF;
  IF p_clearance_type='crew_duty' THEN
   rest:=airlinerra_game.section9_owned_crew_rest_preview_v1(
    target.owner_player_id,p_airline,p_schedule,p_valid_from,28);
   eligible:=coalesce((evidence->'crew'->>'entriesMissingRegisteredCrew')::int,-1)=0
    AND coalesce((evidence->'crew'->>'staleAssignments')::int,-1)=0
    AND coalesce((evidence->'crew'->>'registeredEmployeeAssignments')::int,0)>0
    AND coalesce((rest->>'unverifiedOrStaleAssignments')::int,-1)=0
    AND coalesce((rest->>'overlapConflicts')::int,-1)=0
    AND coalesce((rest->>'insufficientRest')::int,-1)=0
    AND coalesce((rest->>'crewWrongAirport')::int,-1)=0
    AND coalesce((rest->>'overlongDuty')::int,-1)=0
    AND coalesce((rest->>'invalidLocalDeparture')::int,-1)=0;
  ELSIF p_clearance_type='operator_licence' THEN
   fresh_operator_proof:=airlinerra_game.section9_verify_game_operator_licence_v1(
    p_airline,p_schedule,p_schedule_version,p_valid_from);
   eligible:=fresh_operator_proof->>'status'='verified_game_operator_licence'
    AND fresh_operator_proof->>'verified'='true'
    AND fresh_operator_proof->>'sourceReference'=p_source_reference
    AND fresh_operator_proof->>'reviewerReference'=p_reviewer_reference
    AND fresh_operator_proof->>'validThroughGameDate'=p_valid_until::text
    AND evidence->'permissions'->>'gameOperatorLicenceEvidenceRecorded'='true';
  ELSIF p_clearance_type='route_traffic_rights' THEN
   fresh_route_proof:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(
    p_airline,p_schedule,p_schedule_version,p_valid_from);
   eligible:=fresh_route_proof->>'status'='verified_game_route_traffic_rights'
    AND fresh_route_proof->>'verified'='true'
    AND fresh_route_proof->>'sourceReference'=p_source_reference
    AND fresh_route_proof->>'reviewerReference'=p_reviewer_reference
    AND fresh_route_proof->>'validThroughGameDate'=p_valid_until::text
    AND coalesce((evidence->'permissions'->>'requiredServiceTypes')::int,0)>0
    AND coalesce((evidence->'permissions'->>'requiredServiceTypes')::int,-1)=
      coalesce((evidence->'permissions'->>'gameRoutePermissionEvidenceRecorded')::int,-2);
  ELSIF p_clearance_type='airport_slot_capacity' THEN
   SELECT count(*)::int INTO expected_slots
   FROM airlinerra_game.section6_weekly_slot_proposals_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,target.weekly_schedule,
    target.departure_stand_type,target.arrival_stand_type);
   SELECT count(*)::int INTO stored_slots
   FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
   WHERE schedule_id=p_schedule;
   slot_check:=airlinerra_game.section6_weekly_slot_preflight_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,target.weekly_schedule,
    target.departure_stand_type,target.arrival_stand_type,p_schedule);
   -- Recompute the signed source proof inside the SAME write transaction.
   -- Slot data may change after the independent issuer first read it.
   fresh_slot_proof:=airlinerra_game.section9_verify_slot_clearance_source_v1(
    p_airline,p_schedule,p_schedule_version,p_valid_from);
   eligible:=fresh_slot_proof->>'status'='verified_game_airport_slots'
    AND fresh_slot_proof->>'verified'='true'
    AND fresh_slot_proof->>'sourceReference'=p_source_reference
    AND fresh_slot_proof->>'reviewerReference'=p_reviewer_reference
    AND coalesce((slot_check->>'available')::boolean,false)
    AND expected_slots>0 AND stored_slots=expected_slots
    AND NOT EXISTS(
     SELECT * FROM airlinerra_game.section6_weekly_slot_proposals_v1(
      1::smallint,target.origin_airport_key,target.destination_airport_key,
      target.reference_departure_utc,target.reference_arrival_utc,target.weekly_schedule,
      target.departure_stand_type,target.arrival_stand_type)
     EXCEPT
     SELECT r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day
     FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
     WHERE r.schedule_id=p_schedule);
  ELSIF p_clearance_type IN
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
  END IF;
  IF eligible IS DISTINCT FROM true THEN
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CERTIFICATION_SOURCE_FACTS_NOT_VERIFIED';END IF;
 ELSIF existing.schedule_id IS NULL THEN
  -- Revocation without an existing current-version certificate is not
  -- a substitute for independently issued authority.
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_NO_CERTIFICATE_TO_REVOKE';
 END IF;

 accepted_at:=clock_timestamp();
 INSERT INTO airlinerra_game.section9_operational_certification_events_v1(
  event_id,schedule_id,airline_id,schedule_version,clearance_type,
  action,source_kind,source_reference,reviewer_reference,
  valid_from_game_date,valid_to_game_date,verified_hmac_sha256,recorded_at)
 VALUES(p_event_id,p_schedule,p_airline,p_schedule_version,p_clearance_type,
  p_action,source_kind,p_source_reference,p_reviewer_reference,
  p_valid_from,p_valid_until,p_verified_hmac,accepted_at);

 IF p_action='certify' THEN
  INSERT INTO airlinerra_game.section9_schedule_operational_certifications_v1(
   schedule_id,airline_id,schedule_version,clearance_type,
   review_status,source_kind,source_reference,reviewer_reference,
   reviewed_at,valid_from_game_date,valid_to_game_date,last_verified_event_id)
  VALUES(p_schedule,p_airline,p_schedule_version,p_clearance_type,
   'certified',source_kind,p_source_reference,p_reviewer_reference,
   accepted_at,p_valid_from,p_valid_until,p_event_id)
  ON CONFLICT(schedule_id,schedule_version,clearance_type) DO UPDATE SET
   review_status='certified',source_kind=EXCLUDED.source_kind,
   source_reference=EXCLUDED.source_reference,
   reviewer_reference=EXCLUDED.reviewer_reference,
   reviewed_at=EXCLUDED.reviewed_at,
   valid_from_game_date=EXCLUDED.valid_from_game_date,
   valid_to_game_date=EXCLUDED.valid_to_game_date,
   last_verified_event_id=EXCLUDED.last_verified_event_id;
 ELSE
  UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
  SET review_status='revoked',
   source_reference=p_source_reference,
   reviewer_reference=p_reviewer_reference,
   reviewed_at=accepted_at,
   valid_from_game_date=p_valid_from,
   valid_to_game_date=p_valid_until,
   last_verified_event_id=p_event_id
  WHERE schedule_id=p_schedule AND schedule_version=p_schedule_version
   AND clearance_type=p_clearance_type;
 END IF;

 -- Every new decision invalidates a cached preparation immediately.
 DELETE FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=p_schedule AND schedule_version=p_schedule_version;
 RETURN jsonb_build_object(
  'status',CASE WHEN p_action='certify' THEN
   'certification_event_recorded' ELSE 'certification_revoked' END,
  'eventId',p_event_id,'scheduleId',p_schedule,
  'scheduleVersion',p_schedule_version,'clearanceType',p_clearance_type,
  'reviewStatus',CASE WHEN p_action='certify' THEN 'certified' ELSE 'revoked' END,
  'certificateChanged',true,'replayed',false,
  'activationPreparationInvalidated',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$;

-- Deployed function: section9_issue_queued_game_clearance_v1
CREATE OR REPLACE FUNCTION airlinerra_game.section9_issue_queued_game_clearance_v1(p_airline uuid, p_schedule uuid, p_version integer, p_day date, p_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE proof jsonb;receipt jsonb;source_kind text;prefix text;expected_status text;
 reviewer text;source_ref text;fingerprint text;event_id text;payload text;signature text;key_material text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_CLEARANCE_ONLY';END IF;
 CASE p_type
 WHEN 'operator_licence' THEN
  proof:=airlinerra_game.section9_verify_game_operator_licence_v1(p_airline,p_schedule,p_version,p_day);
  expected_status:='verified_game_operator_licence';source_kind:='verified_game_licence_engine';
  prefix:='game-licence-cert-v1';reviewer:='independent-game-licence-authority-v1';
 WHEN 'route_traffic_rights' THEN
  proof:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(p_airline,p_schedule,p_version,p_day);
  expected_status:='verified_game_route_traffic_rights';source_kind:='verified_game_traffic_rights_engine';
  prefix:='game-route-rights-cert-v1';reviewer:='independent-game-traffic-rights-v1';
 WHEN 'airport_slot_capacity' THEN
  proof:=airlinerra_game.section9_verify_slot_clearance_source_v1(p_airline,p_schedule,p_version,p_day);
  expected_status:='verified_game_airport_slots';source_kind:='verified_airport_slot_engine';
  prefix:='slot-clearance-v1';reviewer:='independent-game-slot-authority-v1';
 WHEN 'trusted_flight_execution' THEN
  proof:=airlinerra_game.section9_execution_finance_source_snapshot_v1(p_airline,p_schedule,p_version,p_day,p_type);
  expected_status:='source_snapshot_candidate_not_authorized';source_kind:='trusted_flight_operations_engine';
  prefix:='flight-exec-cert-v1';reviewer:='independent-trusted-flight-execution-authority-v1';
 WHEN 'commercial_finance' THEN
  proof:=airlinerra_game.section9_execution_finance_source_snapshot_v1(p_airline,p_schedule,p_version,p_day,p_type);
  expected_status:='source_snapshot_candidate_not_authorized';source_kind:='verified_commercial_settlement_engine';
  prefix:='commercial-finance-cert-v1';reviewer:='independent-commercial-finance-authority-v1';
 ELSE RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='UNKNOWN_GAME_CLEARANCE';END CASE;
 IF proof->>'status' IS DISTINCT FROM expected_status
 OR proof->>'airlineId' IS DISTINCT FROM p_airline::text
 OR proof->>'scheduleId' IS DISTINCT FROM p_schedule::text
 OR proof->>'scheduleVersion' IS DISTINCT FROM p_version::text
 OR proof->>'gameDate' IS DISTINCT FROM p_day::text
 OR proof->>'clearanceType' IS DISTINCT FROM p_type
 OR proof->>'worldId' IS DISTINCT FROM '1'
 OR proof->>'readOnly' IS DISTINCT FROM 'true'
 OR proof->>'flightActivated' IS DISTINCT FROM 'false'
 OR proof->>'movementRecorded' IS DISTINCT FROM 'false'
 OR proof->>'bookingsCreated' IS DISTINCT FROM 'false'
 OR proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type,'sourceStatus',proof->>'status','blockers',coalesce(proof->'blockers','[]'::jsonb));END IF;
 IF p_type IN ('trusted_flight_execution','commercial_finance') THEN
  fingerprint:=proof->>'sourceFingerprint';
  IF proof->>'candidateReady' IS DISTINCT FROM 'true' OR proof->'blockers' IS DISTINCT FROM '[]'::jsonb
   OR proof->>'sourceAuthorityReleased' IS DISTINCT FROM 'false'
   OR proof->>'sourceReference' IS DISTINCT FROM 'candidate-execution-finance-v1-'||fingerprint
  THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type);END IF;
 ELSE
  fingerprint:=proof->>'proofFingerprint';
  IF proof->>'verified' IS DISTINCT FROM 'true'
   OR proof->>'reviewerReference' IS DISTINCT FROM reviewer
   OR proof->>'sourceKind' IS DISTINCT FROM source_kind
   OR proof->>'validThroughGameDate' IS DISTINCT FROM (p_day+28)::text
  THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type);END IF;
 END IF;
 source_ref:=proof->>'sourceReference';
 IF fingerprint IS NULL OR fingerprint !~ '^[a-f0-9]{32}$' OR source_ref IS NULL
 THEN RETURN jsonb_build_object('status','game_clearance_source_blocked','clearanceType',p_type);END IF;
 SELECT decrypted_secret INTO key_material FROM vault.decrypted_secrets WHERE name='airlinerra_game_clearance_'||p_type||'_v1';
 IF key_material IS NULL OR length(key_material)<64 THEN
  RETURN jsonb_build_object('status','game_clearance_key_missing','clearanceType',p_type);
 END IF;
 event_id:=concat_ws('.',prefix,replace(p_schedule::text,'-',''),p_version::text,to_char(p_day,'YYYYMMDD'),left(fingerprint,12));
 payload:=concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
  p_airline::text,p_schedule::text,p_version::text,p_type,source_kind,'certify',event_id,
  source_ref,reviewer,p_day::text,(p_day+28)::text);
 signature:=encode(extensions.hmac(convert_to(payload,'UTF8'),convert_to(key_material,'UTF8'),'sha256'),'hex');
 -- Real sink independently recomputes the source fingerprint under a
 -- row lock and persists only an eligible, version-bound current decision.
 receipt:=airlinerra_game.section9_record_verified_certification_event_v1(
  p_airline,p_schedule,p_version,p_type,'certify',event_id,source_ref,reviewer,p_day,p_day+28,signature);
 IF receipt->>'status' NOT IN ('certification_event_recorded','certification_event_replayed')
 OR receipt->>'eventId' IS DISTINCT FROM event_id
 OR receipt->>'scheduleId' IS DISTINCT FROM p_schedule::text
 OR receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR receipt->>'flightActivated' IS DISTINCT FROM 'false'
 OR receipt->>'movementRecorded' IS DISTINCT FROM 'false'
 OR receipt->>'bookingsCreated' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='GAME_CLEARANCE_RECEIPT_UNCONFIRMED';END IF;
 RETURN receipt;
END $function$;
