BEGIN;
-- Active-route certificates can only be refreshed by the private scheduler for the exact locked route. No schedule state changes.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_execution_finance_certificate_source_preflight_v1(p_airline uuid, p_schedule uuid, p_version integer, p_game_date date, p_clearance_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 s record;f record;m record;activation record;execution record;
 finance record;engine record;verified_hour jsonb;
 blockers text[]:=ARRAY[]::text[];required_count integer:=0;
BEGIN
 -- Never present this preflight as independent permission to issue a
 -- certificate, even if its future prerequisites eventually become true.
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PRIVATE_EXECUTION_FINANCE_SOURCE_PREFLIGHT_ONLY';
 END IF;
 IF p_airline IS NULL OR p_schedule IS NULL OR p_version IS NULL
 OR p_version<1 OR p_game_date IS NULL
 OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_clearance_type NOT IN('trusted_flight_execution','commercial_finance')
 OR p_clearance_type IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_EXECUTION_FINANCE_SOURCE_SCOPE';
 END IF;
 SELECT * INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO finance
 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1;
 SELECT * INTO engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
 OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR activation.enabled_at IS NULL OR activation.reviewed_at IS NULL THEN
  blockers:=array_append(blockers,'COMMERCIAL_ACTIVATION_NOT_RELEASED');
 END IF;
 IF execution.release_state IS DISTINCT FROM 'enabled'
 OR execution.enabled_at IS NULL OR execution.reviewed_at IS NULL
 OR length(coalesce(execution.release_reference,''))<16
 OR length(coalesce(execution.approved_by,''))<12 THEN
  blockers:=array_append(blockers,'TRUSTED_EXECUTION_NOT_RELEASED');
 END IF;
 IF engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true THEN
  blockers:=array_append(blockers,'FLIGHT_FUEL_ENGINE_NOT_ACTIVATED');
 END IF;
 IF p_clearance_type='commercial_finance' AND
  (finance.release_state IS DISTINCT FROM 'approved'
  OR finance.approved_at IS NULL
  OR length(coalesce(finance.approval_reference,''))<20) THEN
  blockers:=array_append(blockers,'FINANCE_POSTING_NOT_APPROVED');
 END IF;
 -- Read verified clock, never derive a game day from server UTC time.
 verified_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF verified_hour->>'status' IS DISTINCT FROM 'verified_berlin_realtime_hour'
 OR verified_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR verified_hour->>'gameDate' IS DISTINCT FROM p_game_date::text
 OR verified_hour->>'berlinDate' IS DISTINCT FROM p_game_date::text THEN
  blockers:=array_append(blockers,'AUTHORITATIVE_GAME_DAY_NOT_VERIFIED');
 END IF;
 SELECT * INTO s FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_schedule AND airline_id=p_airline AND world_id=1
 AND version=p_version;
 IF NOT FOUND OR ((s.status IS DISTINCT FROM 'draft' OR s.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND s.status='active' AND s.operationally_verified=true)) THEN
  blockers:=array_append(blockers,'CURRENT_DRAFT_VERSION_NOT_VERIFIED');
 ELSE
  SELECT * INTO f FROM airlinerra_game.airline_aircraft_inventory
  WHERE id=s.aircraft_inventory_id AND airline_id=p_airline;
  IF NOT FOUND OR f.fleet_status IS DISTINCT FROM 'in_service'
   OR f.ownership_type NOT IN('owned','leased')
   OR f.configuration_id IS DISTINCT FROM s.configuration_id THEN
   blockers:=array_append(blockers,'OWNED_OR_LEASED_AIRCRAFT_NOT_READY');
  END IF;
  SELECT * INTO m FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
  WHERE configuration_id=s.configuration_id;
  IF NOT FOUND OR m.game_calculation_ready IS DISTINCT FROM true
   OR m.operational_dispatch_release IS DISTINCT FROM 'RELEASED'
   OR (p_clearance_type='commercial_finance'
     AND m.financial_settlement_release IS DISTINCT FROM 'RELEASED') THEN
   blockers:=array_append(blockers,'AIRCRAFT_GAME_FUEL_MODEL_NOT_RELEASED');
  END IF;
  SELECT count(DISTINCT c.clearance_type)::integer INTO required_count
  FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
  JOIN airlinerra_game.section9_operational_certification_events_v1 e
   ON e.event_id=c.last_verified_event_id
   AND e.schedule_id=c.schedule_id
   AND e.schedule_version=c.schedule_version
   AND e.clearance_type=c.clearance_type AND e.action='certify'
   AND e.source_kind=c.source_kind
   AND e.source_reference=c.source_reference
   AND e.reviewer_reference=c.reviewer_reference
  WHERE c.schedule_id=p_schedule AND c.schedule_version=p_version
   AND c.airline_id=p_airline AND c.review_status='certified'
   AND c.clearance_type IN ('operator_licence','route_traffic_rights',
                             'airport_slot_capacity')
   AND c.valid_from_game_date<=p_game_date
   AND c.valid_to_game_date>=p_game_date+28;
  IF required_count<>3 THEN
   blockers:=array_append(blockers,'PRIOR_INDEPENDENT_CERTIFICATIONS_MISSING');
  END IF;
 END IF;

 RETURN jsonb_build_object(
  'status',CASE WHEN cardinality(blockers)=0
   THEN 'source_preflight_complete_not_certifiable'
   ELSE 'blocked_unreleased_execution_finance_source' END,
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_version,'gameDate',p_game_date,
  'clearanceType',p_clearance_type,'readOnly',true,'verified',false,
  'certificateIssued',false,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,
  'ledgerPosted',false,'sourceAuthorityReleased',false,
  'priorCertificateTypesPresent',required_count,
  'blockers',to_jsonb(blockers));
END $function$;
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
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_operator_licence_v1(p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 target record;world_row record;clock_row record;
 licence_row record;catalog_row record;
 blockers text[]:=ARRAY[]::text[];
 source_hash text;country_code text;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL OR
  p_expected_version IS NULL OR p_expected_version<1 OR
  p_game_day IS NULL OR
  p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_LICENCE_VERIFICATION_REQUEST';END IF;
 SELECT sched.*,airline.home_airport_key,airline.owner_player_id,
  home.country_iso AS home_iso, fleet.configuration_id AS fleet_config,
  fleet.fleet_status
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 sched
 JOIN airlinerra_game.airlines airline ON airline.id=sched.airline_id
  AND airline.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=sched.aircraft_inventory_id
  AND fleet.airline_id=sched.airline_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=airline.home_airport_key
 WHERE sched.id=p_schedule AND sched.airline_id=p_airline AND sched.world_id=1
 FOR SHARE OF sched;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_GAME_LICENCE_SCHEDULE_UNKNOWN';END IF;
 IF target.version IS DISTINCT FROM p_expected_version OR
  ((target.status IS DISTINCT FROM 'draft' OR target.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND target.status='active' AND target.operationally_verified=true))
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_or_non_draft_schedule','worldId',1,
  'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT state,opens_at INTO world_row
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,last_verified_at,engine_proof_ref
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF world_row.state IS DISTINCT FROM 'active' OR
  world_row.opens_at IS NULL OR world_row.opens_at>clock_timestamp() OR
  clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine' OR
  clock_row.confirmed_game_date IS DISTINCT FROM p_game_day OR
  clock_row.last_verified_at IS NULL OR
  length(coalesce(clock_row.engine_proof_ref,''))<12 OR
  NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=p_game_day)
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day','worldId',1,
  'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 country_code:=target.home_iso;
 IF country_code IS NULL OR country_code !~ '^[A-Z]{2}$' OR
  NOT EXISTS(SELECT 1 FROM airlinerra_game.aviation_countries_v1 c
   WHERE c.iso2=country_code)
 THEN blockers:=array_append(blockers,'AIRLINE_JURISDICTION_UNVERIFIED');END IF;
 IF target.fleet_status IS DISTINCT FROM 'in_service' OR
  target.fleet_config IS DISTINCT FROM target.configuration_id
 THEN blockers:=array_append(blockers,'AIRCRAFT_FLEET_CONFIGURATION_CHANGED');END IF;

 SELECT * INTO licence_row FROM airlinerra_game.section9_aoc_certificates_v1 WHERE airline_id=p_airline AND world_id=1 FOR SHARE;
 SELECT * INTO catalog_row FROM airlinerra_game.section9_aoc_release_policy_v1 WHERE world_id=1 FOR SHARE;
 IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,p_game_day,28)
 THEN blockers:=array_append(blockers,'VALID_COMPANY_AOC_REQUIRED');END IF;

 IF cardinality(blockers)>0 THEN RETURN jsonb_build_object(
  'status','blocked_game_operator_licence',
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_expected_version,'gameDate',p_game_day,
  'verified',false,'readOnly',true,'blockers',to_jsonb(blockers),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;
 source_hash:=md5(jsonb_build_object(
  'source','game_operator_licence_v1','scheduleId',target.id,
  'scheduleVersion',target.version,'airlineId',p_airline,
  'gameDate',p_game_day,'jurisdiction',country_code,
  'gamePermissionPolicy',to_jsonb(catalog_row),
  'licenceEvidence',to_jsonb(licence_row),
  'fleetConfig',target.configuration_id)::text);
 RETURN jsonb_build_object(
  'status','verified_game_operator_licence',
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'scheduleVersion',p_expected_version,'gameDate',p_game_day,
  'validThroughGameDate',p_game_day+28,
  'clearanceType','operator_licence',
  'sourceKind','verified_game_licence_engine',
  'sourceReference','game-operator-licence-v1-'||source_hash,
  'reviewerReference','independent-game-licence-authority-v1',
  'proofFingerprint',source_hash,'jurisdictionIso2',country_code,
  'verified',true,'readOnly',true,'gameLicenceOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_route_traffic_rights_v1(p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 target record;operator_source jsonb;
 role_name text;role_names text[];required_permission_code text;
 preview jsonb;game_grant record;catalog_row record;
 blockers text[]:=ARRAY[]::text[];
 rights_details jsonb:='[]'::jsonb;proof_hash text;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL OR
  p_expected_version IS NULL OR p_expected_version<1 OR
  p_game_day IS NULL OR
  p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_TRAFFIC_RIGHTS_REQUEST';END IF;
 SELECT sched.*,airline.owner_player_id,
  home.country_iso AS operator_country,
  origin.country_iso AS origin_country,
  destination.country_iso AS destination_country,
  aircraft.use_type
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 sched
 JOIN airlinerra_game.airlines airline ON airline.id=sched.airline_id
  AND airline.world_id=1
 JOIN airlinerra.aircraft_configurations aircraft
  ON aircraft.id=sched.configuration_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=airline.home_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles origin
  ON origin.world_id=1 AND origin.airport_key=sched.origin_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles destination
  ON destination.world_id=1 AND
  destination.airport_key=sched.destination_airport_key
 WHERE sched.id=p_schedule AND sched.airline_id=p_airline AND sched.world_id=1
 FOR SHARE OF sched;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_GAME_RIGHTS_SCHEDULE_UNKNOWN';END IF;
 IF target.version IS DISTINCT FROM p_expected_version OR
  ((target.status IS DISTINCT FROM 'draft' OR target.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND target.status='active' AND target.operationally_verified=true))
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_or_non_draft_schedule',
  'worldId',1,'verified',false,'readOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 -- A route permission cannot outlive or bypass a verified operator
 -- licence, even when route evidence is marked "verified".
 operator_source:=airlinerra_game.section9_verify_game_operator_licence_v1(
  p_airline,p_schedule,p_expected_version,p_game_day);
 IF operator_source->>'status'<>'verified_game_operator_licence'
  OR operator_source->>'verified' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object(
  'status','blocked_game_route_operator_not_licensed',
  'worldId',1,'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'verified',false,'readOnly',true,
  'blockers',jsonb_build_array('VERIFIED_GAME_OPERATOR_LICENCE_REQUIRED'),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF target.operator_country IS NULL OR target.origin_country IS NULL
  OR target.destination_country IS NULL OR
  target.origin_country !~ '^[A-Z]{2}$' OR
  target.destination_country !~ '^[A-Z]{2}$'
 THEN RETURN jsonb_build_object(
  'status','blocked_game_route_country_unknown','worldId',1,
  'scheduleId',p_schedule,'verified',false,'readOnly',true,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 role_names:=CASE target.use_type
  WHEN 'cargo' THEN ARRAY['cargo']::text[]
  WHEN 'combi' THEN ARRAY['passenger','cargo']::text[]
  WHEN 'passenger' THEN ARRAY['passenger']::text[]
  ELSE ARRAY[]::text[] END;
 IF cardinality(role_names)=0 THEN
  blockers:=array_append(blockers,'AIRCRAFT_SERVICE_TYPE_UNKNOWN');END IF;

 FOREACH role_name IN ARRAY role_names LOOP
  preview:=airlinerra_game.aviation_route_rights_preview_v1(
   target.operator_country,target.origin_country,target.destination_country,
   role_name,p_game_day);

  -- Legal data remains REFERENCE ONLY: never claim genuine real-world
  -- aviation rights from the game. A legal prohibition is a hard block.
  -- An unverified bilateral agreement is NOT a prohibition; it can
  -- progress ONLY after a separately issued, paid, game-only route permit
  -- has passed all the evidence and independent issuance checks below.
  IF preview->>'operationally_authorized' IS DISTINCT FROM 'false'
   OR preview->>'status' IN ('invalid_input','forbidden')
  THEN
   blockers:=array_append(blockers,upper(role_name)||'_LEGAL_REFERENCE_UNRESOLVED');
   CONTINUE;
  END IF;

  -- Use the very same classifier as APPLICATION and APPROVAL. Otherwise
  -- a paid in-game third/fourth-freedom grant could never be used for a
  -- reference-only bilateral route such as Serbia -> Montenegro.
  required_permission_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
   target.operator_country,target.origin_country,target.destination_country,
   role_name,p_game_day);

  IF required_permission_code IS NULL THEN
   blockers:=array_append(blockers,upper(role_name)||'_RIGHTS_CLASSIFICATION_UNVERIFIED');
   CONTINUE;
  END IF;
  SELECT * INTO catalog_row
  FROM airlinerra_game.business_permission_catalog_v1 c
  WHERE c.permission_code=required_permission_code FOR SHARE;
  IF NOT FOUND OR catalog_row.category IS DISTINCT FROM 'traffic_rights'
   OR catalog_row.holder_scope IS DISTINCT FROM 'route'
   OR catalog_row.enabled_in_game IS DISTINCT FROM true
   OR catalog_row.game_fee_usd IS NULL
   OR catalog_row.processing_game_days IS NULL
  THEN
   blockers:=array_append(blockers,upper(role_name)||'_GAME_RIGHTS_GRANTS_DISABLED');
   CONTINUE;
  END IF;

  SELECT * INTO game_grant
  FROM airlinerra_game.section9_route_operating_permission_evidence_v1 r
  WHERE r.world_id=1 AND r.airline_id=p_airline
   AND r.origin_airport_key=target.origin_airport_key
   AND r.destination_airport_key=target.destination_airport_key
   AND r.service_type=role_name FOR SHARE;
  IF NOT FOUND OR game_grant.evidence_status IS DISTINCT FROM 'verified'
   OR game_grant.reviewed_at IS NULL OR
   game_grant.reviewed_at>clock_timestamp() OR
   char_length(coalesce(game_grant.evidence_reference,''))<16 OR
   game_grant.valid_from IS NULL OR game_grant.valid_from>p_game_day OR
   game_grant.valid_until IS NULL OR
   game_grant.valid_until<p_game_day+28 OR
   game_grant.issued_application_id IS NULL OR
   NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
    WHERE app.id=game_grant.issued_application_id
     AND app.airline_id=p_airline
     AND app.status='issued'
     AND app.permission_code=required_permission_code
     AND app.origin_airport_key=target.origin_airport_key
     AND app.destination_airport_key=target.destination_airport_key
     AND app.service_type=role_name
     AND app.issued_game_date=game_grant.valid_from
     AND app.valid_until_game_date=game_grant.valid_until
     AND app.ledger_entry_id IS NOT NULL
     AND game_grant.evidence_reference=
       'game-permission-issued-v1-'||app.id::text)
  THEN
   blockers:=array_append(blockers,upper(role_name)||'_GAME_RIGHTS_GRANT_MISSING_OR_EXPIRED');
   CONTINUE;
  END IF;
  rights_details:=rights_details||jsonb_build_array(jsonb_build_object(
   'serviceType',role_name,'gamePermissionCode',required_permission_code,
   'legalReferenceStatus',preview->>'status',
   'legalReferenceOperationallyAuthorizes',false,
   'gameOnlyPermit',true,
   'realWorldAgreementUnverified',preview->>'status'='agreement_check_required',
   'gameGrant',to_jsonb(game_grant),'gamePolicy',to_jsonb(catalog_row)
  ));
 END LOOP;

 IF cardinality(blockers)>0 OR
    jsonb_array_length(rights_details)<>cardinality(role_names)
 THEN RETURN jsonb_build_object(
  'status','blocked_game_route_traffic_rights','worldId',1,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'verified',false,'readOnly',true,'blockers',to_jsonb(blockers),
  'requiredServiceTypes',to_jsonb(role_names),
  'verifiedServiceTypes',jsonb_array_length(rights_details),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);END IF;

 proof_hash:=md5(jsonb_build_object(
  'source','game_route_rights_v1',
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'gameDate',p_game_day,
  'operatorLicenceSourceReference',operator_source->>'sourceReference',
  'origin',target.origin_airport_key,
  'destination',target.destination_airport_key,
  'serviceGrants',rights_details)::text);
 RETURN jsonb_build_object(
  'status','verified_game_route_traffic_rights',
  'worldId',1,'airlineId',p_airline,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'gameDate',p_game_day,'validThroughGameDate',p_game_day+28,
  'clearanceType','route_traffic_rights',
  'sourceKind','verified_game_traffic_rights_engine',
  'sourceReference','game-route-rights-v1-'||proof_hash,
  'reviewerReference','independent-game-traffic-rights-v1',
  'proofFingerprint',proof_hash,
  'verified',true,'readOnly',true,
  'gameRightsOnly',true,'requiredServiceTypes',to_jsonb(role_names),
  'verifiedServiceTypes',jsonb_array_length(rights_details),
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_slot_clearance_source_v1(p_airline uuid, p_schedule uuid, p_expected_version integer, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 target record;world_row record;clock_row record;
 slot_check jsonb;restriction_check jsonb;
 proposed_count integer;reserved_count integer;mismatch_count integer;
 capacity_count integer;proof text;
 blockers text[]:=ARRAY[]::text[];
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL
  OR p_expected_version IS NULL OR p_expected_version<1
  OR p_game_day IS NULL OR p_game_day NOT BETWEEN
      DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_SLOT_CLEARANCE_REQUEST';END IF;

 SELECT s.*,f.fleet_status,f.configuration_id AS fleet_configuration
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR SHARE OF s,f;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_SLOT_CLEARANCE_SCHEDULE_NOT_FOUND';END IF;
 IF target.version IS DISTINCT FROM p_expected_version OR
  ((target.status IS DISTINCT FROM 'draft' OR target.operationally_verified IS DISTINCT FROM false) AND NOT (current_user='postgres' AND current_setting('airlinerra.active_recertification',true) IS NOT DISTINCT FROM p_schedule::text AND target.status='active' AND target.operationally_verified=true))
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_or_non_draft_schedule',
  'worldId',1,'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT state,opens_at INTO world_row
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,last_verified_at,engine_proof_ref
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF world_row.state IS DISTINCT FROM 'active'
  OR world_row.opens_at IS NULL
  OR world_row.opens_at>clock_timestamp()
  OR clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock_row.confirmed_game_date IS DISTINCT FROM p_game_day
  OR clock_row.last_verified_at IS NULL
  OR length(coalesce(clock_row.engine_proof_ref,''))<12
  OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=p_game_day)
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day',
  'worldId',1,'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;

 -- The schedule writer locks these same per-airport capacity records before
 -- changing recurring reservations. Hold read locks to prevent changes to
 -- the counters while this source-verification statement is executing.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN
  (target.origin_airport_key,target.destination_airport_key)
 ORDER BY c.airport_key FOR SHARE;
 SELECT count(*)::integer INTO capacity_count
 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN
  (target.origin_airport_key,target.destination_airport_key);
 IF capacity_count<>2 THEN
  blockers:=array_append(blockers,'CAPACITY_CONFIGURATION_MISSING');END IF;
 IF target.fleet_status IS DISTINCT FROM 'in_service'
  OR target.fleet_configuration IS DISTINCT FROM target.configuration_id
 THEN blockers:=array_append(blockers,'FLEET_CONFIGURATION_CHANGED');END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_verified_schedule_capacity_v1 cap
  WHERE cap.schedule_id=p_schedule AND cap.airline_id=p_airline
   AND cap.schedule_version=p_expected_version
 ) THEN blockers:=array_append(blockers,'VERIFIED_AIRCRAFT_CAPACITY_MISSING');END IF;

 restriction_check:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.configuration_id,target.reference_departure_utc,
  target.reference_arrival_utc,target.weekly_schedule);
 IF restriction_check->>'weeklyTimetableChecked' IS DISTINCT FROM 'true'
  OR (restriction_check->>'gameHardBlocked') IS DISTINCT FROM 'false'
  OR NOT airlinerra_game.section9_game_route_restrictions_valid_v1(target.origin_airport_key,target.destination_airport_key,restriction_check)
 THEN blockers:=array_append(blockers,'UNRESOLVED_AIRPORT_RESTRICTION');END IF;

 SELECT count(*)::integer INTO proposed_count
 FROM airlinerra_game.section6_weekly_slot_proposals_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.reference_departure_utc,target.reference_arrival_utc,
  target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type);
 SELECT count(*)::integer INTO reserved_count
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
 WHERE r.schedule_id=p_schedule;
 SELECT count(*)::integer INTO mismatch_count FROM (
  (SELECT p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
   FROM airlinerra_game.section6_weekly_slot_proposals_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,
    target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type) p
   EXCEPT
   SELECT r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day
   FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
   WHERE r.schedule_id=p_schedule)
  UNION ALL
  (SELECT r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day
   FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
   WHERE r.schedule_id=p_schedule
   EXCEPT
   SELECT p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
   FROM airlinerra_game.section6_weekly_slot_proposals_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,
    target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type) p)
 ) mismatched;
 IF proposed_count=0 OR proposed_count<>reserved_count OR mismatch_count<>0
 THEN blockers:=array_append(blockers,'RECURRING_SLOT_RESERVATIONS_MISMATCH');END IF;
 slot_check:=airlinerra_game.section6_weekly_slot_preflight_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.reference_departure_utc,target.reference_arrival_utc,
  target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type,
  p_schedule);
 IF slot_check->>'available' IS DISTINCT FROM 'true' OR
  slot_check->>'departureAvailable' IS DISTINCT FROM 'true' OR
  slot_check->>'arrivalAvailable' IS DISTINCT FROM 'true'
 THEN blockers:=array_append(blockers,'AIRPORT_CAPACITY_RECHECK_FAILED');END IF;

 IF cardinality(blockers)>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_slot_clearance_evidence',
   'worldId',1,'verified',false,'readOnly',true,
   'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
   'blockers',to_jsonb(blockers),
   'proposedSlots',proposed_count,'reservedSlots',reserved_count,
   'mismatchedSlots',mismatch_count,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 proof:=md5(jsonb_build_object(
  'scheduleId',target.id,'version',target.version,
  'worldGameDate',p_game_day,
  'model','section6_weekly_stand_capacity_v1',
  'restrictionSnapshot',restriction_check,
  'capacitySource',(SELECT to_jsonb(v)
    FROM airlinerra_game.section9_verified_schedule_capacity_v1 v
    WHERE v.schedule_id=p_schedule AND v.schedule_version=p_expected_version),
  'proposedSlotCount',proposed_count,
  'reservations',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY
    r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day),
    '[]'::jsonb)
    FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
    WHERE r.schedule_id=p_schedule),
  'capacityRows',(SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY
    c.airport_key),'[]'::jsonb)
    FROM airlinerra_game.section6_airport_slot_capacity_v1 c
    WHERE c.world_id=1 AND c.airport_key IN
     (target.origin_airport_key,target.destination_airport_key))
 )::text);
 RETURN jsonb_build_object(
  'status','verified_game_airport_slots',
  'worldId',1,'airlineId',p_airline,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'gameDate',p_game_day,'validThroughGameDate',p_game_day+28,
  'clearanceType','airport_slot_capacity',
  'sourceKind','verified_airport_slot_engine',
  'sourceReference','game-slot-capacity-v1-'||proof,
  'reviewerReference','independent-game-slot-authority-v1',
  'proofFingerprint',proof,
  'verified',true,'readOnly',true,
  'proposedSlots',proposed_count,'reservedSlots',reserved_count,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_refresh_active_game_route_certifications_v1(p_limit int DEFAULT 25,p_force boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE day_now date; q record; kind text; cert jsonb; fingerprint text; rel text;
 done int:=0; blocked int:=0; reason text; reasons jsonb:='{}'; previous_scope text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_ROUTE_RECERTIFICATION_ONLY';END IF;
 IF p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Invalid certification batch limit';END IF;
 SELECT release_reference INTO rel FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1 AND release_state='enabled' AND crew_mode='deferred_phase1';
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF rel IS NULL OR day_now IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1 AND automatic_flight_and_fuel_settlement_enabled) THEN
  RETURN jsonb_build_object('status','recertification_release_blocked','refreshed',0,'blocked',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583729,10061) THEN RETURN jsonb_build_object('status','recertification_running','refreshed',0,'blocked',0);END IF;
 FOR q IN SELECT s.* FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.world_id=1 AND s.status='active' AND s.operationally_verified
 AND (p_force OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
  WHERE c.schedule_id=s.id AND c.schedule_version=s.version AND c.review_status='certified'
  AND c.clearance_type IN ('operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance')
  AND c.valid_to_game_date>=day_now+8)<>5)
 ORDER BY s.id LIMIT p_limit FOR UPDATE OF s SKIP LOCKED
 LOOP
  BEGIN
   previous_scope:=current_setting('airlinerra.active_recertification',true);
   PERFORM set_config('airlinerra.active_recertification',q.id::text,true);
   FOREACH kind IN ARRAY ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance'] LOOP
    cert:=airlinerra_game.section9_issue_queued_game_clearance_v1(q.airline_id,q.id,q.version,day_now,kind);
    IF coalesce(cert->>'status','') NOT IN('certification_event_recorded','certification_event_replayed') THEN reason:=kind;RAISE SQLSTATE 'P9002';END IF;
   END LOOP;
   IF (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
      JOIN airlinerra_game.section9_operational_certification_events_v1 e ON e.event_id=c.last_verified_event_id AND e.schedule_id=c.schedule_id AND e.schedule_version=c.schedule_version AND e.clearance_type=c.clearance_type AND e.action='certify'
      AND e.valid_from_game_date=c.valid_from_game_date AND e.valid_to_game_date=c.valid_to_game_date AND e.source_reference=c.source_reference
      WHERE c.schedule_id=q.id AND c.airline_id=q.airline_id AND c.schedule_version=q.version AND c.review_status='certified' AND c.valid_from_game_date<=day_now AND c.valid_to_game_date>=day_now+28 AND c.clearance_type IN ('operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance'))<>5
    THEN reason:='signed_event_reconciliation';RAISE SQLSTATE 'P9002';END IF;
   fingerprint:=airlinerra_game.section9_activation_evidence_fingerprint_v1(q.id);
   IF fingerprint IS NULL THEN reason:='activation_fingerprint';RAISE SQLSTATE 'P9002';END IF;
   INSERT INTO airlinerra_game.section9_schedule_activation_preparations_v1(schedule_id,schedule_version,airline_id,aircraft_inventory_id,verified_game_date,certified_horizon_days,fingerprint_md5,release_reference)
    VALUES(q.id,q.version,q.airline_id,q.aircraft_inventory_id,day_now,28,fingerprint,rel)
    ON CONFLICT(schedule_id,schedule_version) DO UPDATE SET verified_game_date=excluded.verified_game_date,certified_horizon_days=excluded.certified_horizon_days,fingerprint_md5=excluded.fingerprint_md5,release_reference=excluded.release_reference;
   PERFORM set_config('airlinerra.active_recertification',coalesce(previous_scope,''),true);
   done:=done+1;
  EXCEPTION WHEN SQLSTATE 'P9002' THEN
   blocked:=blocked+1;reasons:=jsonb_set(reasons,ARRAY[reason],to_jsonb(coalesce((reasons->>reason)::int,0)+1),true);
  END;
 END LOOP;
 RETURN jsonb_build_object('status','active_game_route_recertification_completed','refreshed',done,'blocked',blocked,'blockerCounts',reasons,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_refresh_active_game_route_certifications_v1(int,boolean) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
