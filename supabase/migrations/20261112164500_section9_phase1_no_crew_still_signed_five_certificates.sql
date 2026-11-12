-- Crew is deliberately excluded from first operational release at product owner's request.
-- This does NOT certify the other five operational dependencies, create approval rows,
-- relax the commercial release, or activate any flight.
BEGIN;
ALTER TABLE airlinerra_game.section9_activation_release_policy_v1
 ADD COLUMN IF NOT EXISTS crew_mode text NOT NULL DEFAULT 'deferred_phase1'
 CHECK (crew_mode IN ('deferred_phase1','required'));
COMMENT ON COLUMN airlinerra_game.section9_activation_release_policy_v1.crew_mode
 IS 'deferred_phase1: crew checks out of first release; required: full later crew integration. Both modes still require all other independent signed sources and explicit commercial release.';
CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_certified_schedule_activation_v1(p_player uuid, p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_date date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE target record;world_row record;clock_row record;
 control_row record; gate jsonb;checklist jsonb; blocker text;
 blocked text[]:=ARRAY[]::text[];
 certificate_count integer;required_certificate_count integer;
 crew_deferred boolean;slot_count integer;expected_slots integer;
 fresh_game_operator jsonb;fresh_game_rights jsonb;
 fingerprint text;certified_record record;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
 OR p_expected_version IS NULL OR p_expected_version<1
 OR p_game_date IS NULL OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ACTIVATION_PREPARATION';END IF;
 -- Atomic identity and version fence: saves/updates hold the same schedule
 -- lock and cannot change evidence half-way through this preparation.
 SELECT s.*,a.owner_player_id,f.fleet_status,f.configuration_id AS fleet_config
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id AND a.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR UPDATE OF s, f;
 IF NOT FOUND OR target.owner_player_id IS DISTINCT FROM p_player
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ACTIVATION_PREPARATION_NOT_OWNED';END IF;
 IF target.version IS DISTINCT FROM p_expected_version
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_schedule_version','scheduleId',p_schedule,
  'expectedVersion',p_expected_version,'currentVersion',target.version,
  'prepared',false,'flightActivated',false,'bookingsCreated',false,
  'movementRecorded',false,'ledgerPosted',false);END IF;
 IF target.status<>'draft' OR target.operationally_verified IS DISTINCT FROM false
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_INVALID_ACTIVATION_PREPARATION_STATE';END IF;
 -- Lock private certificates while evaluating so that revocation of existing
 -- grants cannot interleave the preparation in this transaction.
 PERFORM 1 FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
 WHERE c.schedule_id=p_schedule AND c.schedule_version=p_expected_version
 ORDER BY c.clearance_type FOR SHARE;
 SELECT state,opens_at INTO world_row
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,engine_proof_ref,last_verified_at
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 SELECT * INTO control_row
 FROM airlinerra_game.section9_activation_release_policy_v1
 WHERE world_id=1 FOR SHARE;
 IF world_row.state IS DISTINCT FROM 'active' OR
  world_row.opens_at IS NULL OR world_row.opens_at>clock_timestamp()
 THEN blocked:=array_append(blocked,'WORLD_NOT_OPEN');END IF;
 IF clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock_row.confirmed_game_date IS DISTINCT FROM p_game_date
  OR length(coalesce(clock_row.engine_proof_ref,''))<12
  OR clock_row.last_verified_at IS NULL
  OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
    WHERE r.world_id=1 AND r.game_date=p_game_date)
 THEN blocked:=array_append(blocked,'SIGNED_GAME_CLOCK_NOT_CURRENT');END IF;
 crew_deferred:=coalesce(control_row.crew_mode,'required')='deferred_phase1';
 required_certificate_count:=CASE WHEN crew_deferred THEN 5 ELSE 6 END;
 IF control_row.release_state IS DISTINCT FROM 'enabled'
  OR control_row.enabled_at IS NULL
  OR control_row.reviewed_at IS NULL
 THEN blocked:=array_append(blocked,'COMMERCIAL_ACTIVATION_ADMIN_RELEASE_MISSING');END IF;
 IF target.fleet_status IS DISTINCT FROM 'in_service'
  OR target.configuration_id IS DISTINCT FROM target.fleet_config
 THEN blocked:=array_append(blocked,'AIRCRAFT_CONFIG_OR_SERVICE_INVALID');END IF;
 SELECT count(*)::int INTO certificate_count
 FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
 WHERE c.schedule_id=p_schedule AND c.airline_id=p_airline
 AND c.schedule_version=p_expected_version AND c.review_status='certified'
 AND (NOT crew_deferred OR c.clearance_type<>'crew_duty')
 AND c.valid_from_game_date<=p_game_date
 AND c.valid_to_game_date>=p_game_date+p_days
 AND c.reviewed_at<=clock_timestamp()
 AND length(c.source_reference)>=16
 AND length(c.reviewer_reference)>=12
 -- A row in the certificate table by itself is NOT an approval.
 -- Require it to match the latest append-only independently signed event.
 AND c.last_verified_event_id IS NOT NULL
 AND EXISTS(
  SELECT 1 FROM airlinerra_game.section9_operational_certification_events_v1 e
  WHERE e.event_id=c.last_verified_event_id
   AND e.airline_id=c.airline_id
   AND e.schedule_id=c.schedule_id
   AND e.schedule_version=c.schedule_version
   AND e.clearance_type=c.clearance_type
   AND e.action='certify'
   AND e.source_kind=c.source_kind
   AND e.source_reference=c.source_reference
   AND e.reviewer_reference=c.reviewer_reference
   AND e.recorded_at=c.reviewed_at
   AND e.valid_from_game_date=c.valid_from_game_date
   AND e.valid_to_game_date=c.valid_to_game_date
 );
 IF certificate_count<>required_certificate_count
 THEN blocked:=array_append(blocked,
  CASE WHEN crew_deferred
   THEN 'FIVE_NON_CREW_OPERATIONAL_CERTIFICATIONS_MISSING'
   ELSE 'SIX_INDEPENDENT_OPERATIONAL_CERTIFICATIONS_MISSING'
  END);END IF;
 -- Signed audit events are necessary but not sufficient. If the
 -- underlying game-operator licence or route grant has been revoked,
 -- expired or its catalogue release disabled, stale signed clearance
 -- must not remain usable for a new activation preparation.
 fresh_game_operator:=airlinerra_game.section9_verify_game_operator_licence_v1(
  p_airline,p_schedule,p_expected_version,p_game_date);
 fresh_game_rights:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(
  p_airline,p_schedule,p_expected_version,p_game_date);
 IF fresh_game_operator->>'status'<>'verified_game_operator_licence'
 OR fresh_game_operator->>'verified' IS DISTINCT FROM 'true'
 OR NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_schedule_operational_certifications_v1 cert
  WHERE cert.schedule_id=p_schedule AND cert.airline_id=p_airline
   AND cert.schedule_version=p_expected_version
   AND cert.clearance_type='operator_licence'
   AND cert.review_status='certified'
   AND cert.source_reference=fresh_game_operator->>'sourceReference'
   AND cert.reviewer_reference=fresh_game_operator->>'reviewerReference')
 THEN blocked:=array_append(blocked,'OPERATOR_GAME_LICENCE_SIGNED_PROOF_STALE');END IF;
 IF fresh_game_rights->>'status'<>'verified_game_route_traffic_rights'
 OR fresh_game_rights->>'verified' IS DISTINCT FROM 'true'
 OR NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_schedule_operational_certifications_v1 cert
  WHERE cert.schedule_id=p_schedule AND cert.airline_id=p_airline
   AND cert.schedule_version=p_expected_version
   AND cert.clearance_type='route_traffic_rights'
   AND cert.review_status='certified'
   AND cert.source_reference=fresh_game_rights->>'sourceReference'
   AND cert.reviewer_reference=fresh_game_rights->>'reviewerReference')
 THEN blocked:=array_append(blocked,'ROUTE_GAME_RIGHTS_SIGNED_PROOF_STALE');END IF;

 -- Re-evaluate contemporary restrictions, rotation, crew, slot reservations
 -- and initial aircraft location. These are previews; never infer independent
 -- legal/operational authorization from their provisional checks.
 gate:=airlinerra_game.section9_owned_commercial_activation_preflight_v1(
  p_player,p_airline,p_schedule,p_game_date,p_days);
 IF gate->>'readOnly' IS DISTINCT FROM 'true'
   OR gate->>'canActivateNormalFlight' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNSAFE_ACTIVATION_EVIDENCE_GATE';END IF;
 checklist:=gate->'activationChecklist';
 IF checklist->>'airportRestrictionPreviewPassed' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'AIRPORT_RESTRICTIONS_NOT_CLEARED');END IF;
 IF checklist->>'aircraftRotationPreviewConflictFree' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'AIRCRAFT_ROTATION_NOT_CLEARED');END IF;
 IF checklist->>'departureArrivalSlotRecordsPresent' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'SCHEDULED_SLOTS_NOT_RECORDED');END IF;
 IF checklist->>'aircraftDeliveryAnchorVerified' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'AIRCRAFT_DELIVERY_NOT_VERIFIED');END IF;
 IF checklist->>'aircraftInFlight' IS NOT DISTINCT FROM 'true'
  OR checklist->>'lastVerifiedGroundAirport' IS NULL
 THEN blocked:=array_append(blocked,'AIRCRAFT_LOCATION_NOT_GROUNDED');END IF;
 IF NOT crew_deferred AND checklist->>'proposedCrewAssignmentsComplete' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'CREW_ASSIGNMENTS_INCOMPLETE');END IF;
 IF NOT crew_deferred AND checklist->>'crewRestPreviewConflictFree' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'CREW_REST_PREVIEW_NOT_CLEARED');END IF;
 IF checklist->>'operatorLicenceEvidenceRecorded' IS DISTINCT FROM 'true'
  OR checklist->>'routePermissionEvidenceComplete' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'LICENCE_AND_ROUTE_EVIDENCE_MISSING');END IF;
 IF checklist->>'worldClockConnected' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'GAME_CLOCK_NOT_CONNECTED');END IF;
 IF (gate->'turnaround'->>'shortTurnaroundOccurrences')::int IS DISTINCT FROM 0
 OR gate->'turnaround'->>'minimumMinutes' IS NULL
 THEN blocked:=array_append(blocked,'TURNAROUND_POLICY_NOT_CLEARED');END IF;
 -- Compare the full reservation set, not just a Yes/No summary.
 SELECT count(*) INTO expected_slots
 FROM airlinerra_game.section6_weekly_slot_proposals_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.reference_departure_utc,target.reference_arrival_utc,
  target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type);
 SELECT count(*) INTO slot_count
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=p_schedule;
 IF slot_count<>expected_slots OR expected_slots=0 OR EXISTS(
  (SELECT p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
   FROM airlinerra_game.section6_weekly_slot_proposals_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,
    target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type) p
   EXCEPT
   SELECT s.airport_key,s.stand_type,s.direction,s.weekday,s.minute_of_day
   FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 s
   WHERE s.schedule_id=p_schedule)
 ) THEN blocked:=array_append(blocked,'SLOT_RESERVATION_MISMATCH');END IF;
 -- Re-run slot capacity with the schedule's own reserved rows excluded.
 IF (airlinerra_game.section6_weekly_slot_preflight_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.reference_departure_utc,target.reference_arrival_utc,
  target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type,
  p_schedule)->>'available') IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'AIRPORT_SLOT_CAPACITY_CHANGED');END IF;

 IF cardinality(blocked)>0 THEN
 RETURN jsonb_build_object(
   'status','blocked_activation_preparation','scheduleId',p_schedule,
   'scheduleVersion',target.version,
   'blockers',to_jsonb(blocked),
   'acceptedCertifications',certificate_count,
   'requiredCertifications',required_certificate_count,
   'crewMode',CASE WHEN crew_deferred THEN 'deferred_phase1' ELSE 'required' END,
   'prepared',false,'flightActivated',false,'movementRecorded',false,
   'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 fingerprint:=airlinerra_game.section9_activation_evidence_fingerprint_v1(p_schedule);
 IF fingerprint IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PREPARATION_EVIDENCE_FINGERPRINT_UNAVAILABLE';END IF;
 INSERT INTO airlinerra_game.section9_schedule_activation_preparations_v1(
  schedule_id,schedule_version,airline_id,aircraft_inventory_id,
  verified_game_date,certified_horizon_days,fingerprint_md5,
  release_reference)
 VALUES(p_schedule,target.version,p_airline,target.aircraft_inventory_id,
   p_game_date,p_days,fingerprint,control_row.release_reference)
 ON CONFLICT(schedule_id,schedule_version) DO NOTHING;
 SELECT * INTO certified_record
 FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=p_schedule AND schedule_version=target.version;
 IF certified_record.fingerprint_md5 IS DISTINCT FROM fingerprint
  OR certified_record.release_reference IS DISTINCT FROM control_row.release_reference
  OR certified_record.verified_game_date IS DISTINCT FROM p_game_date
  OR certified_record.certified_horizon_days IS DISTINCT FROM p_days
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_ACTIVATION_PREPARATION_CONFLICT';END IF;
 RETURN jsonb_build_object(
  'status','prepared_for_future_activation_commit',
  'crewMode',CASE WHEN crew_deferred THEN 'deferred_phase1' ELSE 'required' END,
  'scheduleId',p_schedule,'scheduleVersion',target.version,
  'prepared',true,'fingerprint',fingerprint,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false,
  'note','Prepared evidence is NOT operational schedule activation. Draft-only database constraint remains.');
END $function$;
COMMIT;
