-- Airlinerra Section 9: private commercial schedule activation CERTIFICATION
-- preparation. No live flight activation, permission grant, movement or money.
-- The existing status='draft' and operationally_verified=false CHECKs remain
-- unchanged. Preparation is a durable version-bound review snapshot only.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_activation_release_policy_v1(
 world_id smallint PRIMARY KEY REFERENCES public.airlinerra_game_worlds(id)
   CHECK(world_id=1),
 release_state text NOT NULL DEFAULT 'paused'
   CHECK(release_state IN ('paused','enabled')),
 release_reference text NOT NULL
   CHECK(char_length(release_reference) BETWEEN 16 AND 160),
 approved_by text NOT NULL CHECK(char_length(approved_by) BETWEEN 8 AND 160),
 reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 enabled_at timestamptz,
 CHECK((release_state='paused' AND enabled_at IS NULL)
    OR (release_state='enabled' AND enabled_at IS NOT NULL))
);
ALTER TABLE airlinerra_game.section9_activation_release_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_activation_release_policy_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_activation_release_policy_v1 IS
 'Private administrator-controlled release record. No row inserted, no activation enabled by migration. An enabled row is not enough to release flights.';

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_schedule_operational_certifications_v1(
 schedule_id uuid NOT NULL REFERENCES
  airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id)
  ON DELETE RESTRICT,
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 clearance_type text NOT NULL CHECK(clearance_type IN (
  'crew_duty', 'operator_licence', 'route_traffic_rights',
  'airport_slot_capacity', 'trusted_flight_execution',
  'commercial_finance')),
 review_status text NOT NULL DEFAULT 'pending'
  CHECK(review_status IN ('pending','certified','revoked')),
 source_kind text NOT NULL CHECK(source_kind IN (
  'verified_crew_duty_engine', 'verified_game_licence_engine',
  'verified_game_traffic_rights_engine',
  'verified_airport_slot_engine', 'trusted_flight_operations_engine',
  'verified_commercial_settlement_engine')),
 source_reference text NOT NULL CHECK(char_length(source_reference) BETWEEN 16 AND 160),
 reviewer_reference text NOT NULL CHECK(char_length(reviewer_reference) BETWEEN 12 AND 160),
 reviewed_at timestamptz NOT NULL,
 valid_from_game_date date NOT NULL,
 valid_to_game_date date NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(schedule_id,schedule_version,clearance_type),
 CHECK(valid_to_game_date>=valid_from_game_date
   AND valid_to_game_date<=valid_from_game_date+365),
 CHECK((clearance_type='crew_duty' AND
   source_kind='verified_crew_duty_engine') OR
  (clearance_type='operator_licence' AND
   source_kind='verified_game_licence_engine') OR
  (clearance_type='route_traffic_rights' AND
   source_kind='verified_game_traffic_rights_engine') OR
  (clearance_type='airport_slot_capacity' AND
   source_kind='verified_airport_slot_engine') OR
  (clearance_type='trusted_flight_execution' AND
   source_kind='trusted_flight_operations_engine') OR
  (clearance_type='commercial_finance' AND
   source_kind='verified_commercial_settlement_engine'))
);
ALTER TABLE airlinerra_game.section9_schedule_operational_certifications_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_schedule_operational_certifications_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_schedule_certifications_airline_idx
 ON airlinerra_game.section9_schedule_operational_certifications_v1
 (airline_id,schedule_id,schedule_version);
COMMENT ON TABLE airlinerra_game.section9_schedule_operational_certifications_v1 IS
 'Private evidence from six independently connected verifier services. Source references are NOT self-validating: services must verify and issue these records before release. No such services or seeded approvals are installed.';

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_schedule_activation_preparations_v1(
 schedule_id uuid NOT NULL REFERENCES
  airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE CASCADE,
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL REFERENCES
  airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 verified_game_date date NOT NULL,
 certified_horizon_days integer NOT NULL CHECK(certified_horizon_days BETWEEN 7 AND 42),
 fingerprint_md5 text NOT NULL CHECK(fingerprint_md5~'^[a-f0-9]{32}$'),
 release_reference text NOT NULL,
 prepared_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(schedule_id,schedule_version)
);
ALTER TABLE airlinerra_game.section9_schedule_activation_preparations_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_schedule_activation_preparations_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_schedule_activation_preparations_v1 IS
 'Version-scoped checkpoint, NOT activated flight. Fingerprint is only for detecting changes, not an authentication signature.';

-- Detect crew/slot/rights/certificate/equipment changes between preparation
-- and the future activation commit. Source rows are read-only to players.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_activation_evidence_fingerprint_v1(
 p_schedule uuid
) RETURNS text LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
 SELECT md5(jsonb_build_object(
 'schedule',to_jsonb(s),
 'aircraft',(SELECT to_jsonb(f)
   FROM airlinerra_game.airline_aircraft_inventory f
   WHERE f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id),
 'crew',(SELECT coalesce(jsonb_agg(to_jsonb(d) ORDER BY d.weekly_entry,d.crew_id),'[]'::jsonb)
  FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
  WHERE d.schedule_id=s.id),
 'crewRoster',(SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.crew_id),'[]'::jsonb)
  FROM airlinerra_game.section9_airline_crew_roster_v1 c
  WHERE c.airline_id=s.airline_id AND EXISTS(
   SELECT 1 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
   WHERE d.schedule_id=s.id AND d.crew_id=c.crew_id)),
 'slots',(SELECT coalesce(jsonb_agg(to_jsonb(slot)
   ORDER BY slot.airport_key,slot.stand_type,slot.direction,slot.weekday,
            slot.minute_of_day),'[]'::jsonb)
  FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
  WHERE slot.schedule_id=s.id),
 'capacity',(SELECT to_jsonb(cap)
  FROM airlinerra_game.section9_verified_schedule_capacity_v1 cap
  WHERE cap.schedule_id=s.id),
 'licences',(SELECT coalesce(jsonb_agg(to_jsonb(l) ORDER BY l.licence_id),'[]'::jsonb)
  FROM airlinerra_game.section9_operator_licence_evidence_v1 l
  WHERE l.airline_id=s.airline_id),
 'routeRights',(SELECT coalesce(jsonb_agg(to_jsonb(r)
     ORDER BY r.permission_id),'[]'::jsonb)
  FROM airlinerra_game.section9_route_operating_permission_evidence_v1 r
  WHERE r.airline_id=s.airline_id AND
   r.origin_airport_key=s.origin_airport_key AND
   r.destination_airport_key=s.destination_airport_key),
 'certificates',(SELECT coalesce(jsonb_agg(to_jsonb(cert)
  ORDER BY cert.clearance_type),'[]'::jsonb)
  FROM airlinerra_game.section9_schedule_operational_certifications_v1 cert
  WHERE cert.schedule_id=s.id AND cert.schedule_version=s.version)
 )::text)
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.id=p_schedule
$f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_activation_evidence_fingerprint_v1(uuid)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_certified_schedule_activation_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_expected_version integer,p_game_date date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE target record;world_row record;clock_row record;
 control_row record; gate jsonb;checklist jsonb; blocker text;
 blocked text[]:=ARRAY[]::text[];
 certificate_count integer;slot_count integer;expected_slots integer;
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
 AND c.valid_from_game_date<=p_game_date
 AND c.valid_to_game_date>=p_game_date+p_days
 AND c.reviewed_at<=clock_timestamp()
 AND length(c.source_reference)>=16
 AND length(c.reviewer_reference)>=12;
 IF certificate_count<>6
 THEN blocked:=array_append(blocked,'SIX_INDEPENDENT_OPERATIONAL_CERTIFICATIONS_MISSING');END IF;

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
 IF checklist->>'proposedCrewAssignmentsComplete' IS DISTINCT FROM 'true'
 THEN blocked:=array_append(blocked,'CREW_ASSIGNMENTS_INCOMPLETE');END IF;
 IF checklist->>'crewRestPreviewConflictFree' IS DISTINCT FROM 'true'
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
   'requiredCertifications',6,
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
  'scheduleId',p_schedule,'scheduleVersion',target.version,
  'prepared',true,'fingerprint',fingerprint,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false,
  'note','Prepared evidence is NOT operational schedule activation. Draft-only database constraint remains.');
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_prepare_certified_schedule_activation_v1(
 uuid,uuid,uuid,integer,date,integer)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION
 airlinerra_game.section9_prepare_certified_schedule_activation_v1(
 uuid,uuid,uuid,integer,date,integer)
 IS 'Private locked, version-fenced certification preparation only; no flight activation. All six independent evidence sources and explicit administrator release are required.';

