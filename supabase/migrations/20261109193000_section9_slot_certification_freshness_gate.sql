-- Require current independently recalculated airport capacity evidence
-- when recording an airport slot clearance; refuse stale signed decisions.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_record_verified_certification_event_v1(
 p_airline uuid,p_schedule uuid,p_schedule_version integer,
 p_clearance_type text,p_action text,p_event_id text,
 p_source_reference text,p_reviewer_reference text,
 p_valid_from date,p_valid_until date,p_verified_hmac text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE target record;old_event record;existing record;
 evidence jsonb;rest jsonb;fields jsonb;slot_check jsonb;fresh_slot_proof jsonb;
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
  target.status IS DISTINCT FROM 'draft' OR
  target.operationally_verified IS DISTINCT FROM false
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
   eligible:=evidence->'permissions'->>'gameOperatorLicenceEvidenceRecorded'='true';
  ELSIF p_clearance_type='route_traffic_rights' THEN
   eligible:=coalesce((evidence->'permissions'->>'requiredServiceTypes')::int,0)>0
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
  ELSE
   -- There is no live trusted operations/settlement engine yet.
   -- An individually signed event from that future engine is required;
   -- source claims are cryptographically checked by a separate backend.
   eligible:=true;
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
END $f$;

