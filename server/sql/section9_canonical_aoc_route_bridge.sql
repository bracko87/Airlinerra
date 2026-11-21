-- Use the canonical company AOC rather than requiring a second, paid legacy
-- certificate from the original airline. Keep paid subsidiary provenance,
-- verified clock, suspension, expiry and route-specific rights checks.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(p_airline uuid,p_day date,p_days integer)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
 SELECT coalesce(airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline,p_day)->>'authorized'='true',false)
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c
 WHERE c.airline_id=p_airline AND c.world_id=1 AND c.status='active'
 AND c.issued_game_day<=p_day AND c.expires_game_day>p_day+p_days)
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(uuid,date,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_activation_evidence_fingerprint_v1(p_schedule uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
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
 'companyAoc',(SELECT to_jsonb(ac) FROM airlinerra_game.section9_aoc_certificates_v1 ac WHERE ac.airline_id=s.airline_id AND ac.world_id=1),
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
$function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 clock_proof jsonb;now_utc timestamptz;
 activation record;execution record;engine record;
 evt record;matches jsonb;candidate jsonb;
 maintenance jsonb;movement jsonb;airframe_usage jsonb;fuel_check jsonb;fuel_receipt jsonb;fuel_supply jsonb;
 required_permission_code text;movement_event_id text;
 signer_key text;payload text;event_signature text;
 used integer:=0;departures integer:=0;arrivals integer:=0;
 blocked integer:=0;reason text;warnings jsonb:='{}'::jsonb;
 changed integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_DISPATCH_POSTGRES_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_DISPATCH_LIMIT_INVALID';END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_game_hour_not_verified',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 now_utc:=(clock_proof->>'gameHourUtc')::timestamptz;
 SELECT * INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
 OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR activation.enabled_at IS NULL
 OR execution.release_state IS DISTINCT FROM 'enabled'
 OR execution.enabled_at IS NULL
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_flight_engine_release',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10041) THEN
  RETURN jsonb_build_object('status','flight_dispatch_already_running',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 SELECT decrypted_secret INTO signer_key FROM vault.decrypted_secrets
 WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF signer_key IS NULL OR length(signer_key)<64 THEN
  RETURN jsonb_build_object('status','blocked_missing_private_event_signer',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;

 FOR evt IN
  SELECT o.id AS occurrence_id,o.schedule_id,o.airline_id,
   o.aircraft_inventory_id,o.schedule_version,o.flight_local_date,
   o.weekly_entry,o.departure_utc,o.arrival_utc,o.booking_status,
   o.booked_seats,o.verified_passenger_seats,
   o.origin_airport_key,o.destination_airport_key,
   o.schedule_id::text||':'||o.flight_local_date::text||':'||
     o.weekly_entry::text physical_id,
   s.reference_departure_utc,s.reference_arrival_utc,
   s.version as schedule_version_current,s.configuration_id,
   fleet.fleet_status,fleet.ownership_type,fleet.configuration_id AS fleet_configuration,
   conf.use_type,
   airline.owner_player_id,
   a_home.country_iso as home_country,
   a_origin.country_iso as origin_country,
   a_dest.country_iso as destination_country,
   cap.passenger_capacity,cap.passengers_held,
   cap.schedule_version AS capacity_version,
   cap.commercial_version AS capacity_commercial_version,
   cap.departure_utc AS capacity_departure_utc,
   cap.arrival_utc AS capacity_arrival_utc,
   plan.version AS plan_version,
   phase.phase,phase.event_time,
   (
    SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
    WHERE c.schedule_id=o.schedule_id
    AND c.airline_id=o.airline_id
    AND c.schedule_version=o.schedule_version
    AND c.review_status='certified'
    AND c.valid_from_game_date<=o.flight_local_date
    AND c.valid_to_game_date>=o.flight_local_date
   ) as certification_count
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
   ON s.id=o.schedule_id AND s.airline_id=o.airline_id
    AND s.version=o.schedule_version AND s.status='active'
    AND s.operationally_verified=true
  JOIN airlinerra_game.airline_aircraft_inventory fleet
   ON fleet.id=o.aircraft_inventory_id
    AND fleet.airline_id=o.airline_id
  JOIN airlinerra.aircraft_catalog_configuration_inventory conf
   ON conf.configuration_id=s.configuration_id
  JOIN airlinerra_game.airlines airline ON airline.id=o.airline_id
  LEFT JOIN airlinerra_game.airport_reference_profiles a_home
   ON a_home.world_id=1 AND a_home.airport_key=airline.home_airport_key
  LEFT JOIN airlinerra_game.airport_reference_profiles a_origin
   ON a_origin.world_id=1 AND a_origin.airport_key=o.origin_airport_key
  LEFT JOIN airlinerra_game.airport_reference_profiles a_dest
   ON a_dest.world_id=1 AND a_dest.airport_key=o.destination_airport_key
  LEFT JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
   ON cap.physical_flight_id=o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text
  LEFT JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
   ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
  CROSS JOIN LATERAL(VALUES('departed'::text,o.departure_utc),
                            ('arrived'::text,o.arrival_utc)) phase(phase,event_time)
  WHERE o.world_id=1
   AND o.source_kind='game_verified_saleable_schedule_v1'
   AND o.booking_status IN('open','closed')
   AND phase.event_time>now_utc-interval '10 minutes'
   AND phase.event_time<=now_utc
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
    WHERE m.flight_occurrence_id=o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text
      AND m.phase=phase.phase)
  ORDER BY phase.event_time,o.schedule_id,o.flight_local_date,o.weekly_entry,phase.phase
  LIMIT p_limit
 LOOP
  used:=used+1;reason:=NULL;
  IF evt.owner_player_id IS NULL
   OR evt.fleet_status<>'in_service'
   OR evt.ownership_type NOT IN ('owned','leased')
   OR evt.fleet_configuration IS DISTINCT FROM evt.configuration_id
   OR evt.use_type<>'passenger'
   OR evt.reference_arrival_utc<=evt.reference_departure_utc
   OR evt.verified_passenger_seats IS NULL
   OR evt.verified_passenger_seats<1
   OR evt.booked_seats>evt.verified_passenger_seats
   OR evt.passenger_capacity IS DISTINCT FROM evt.verified_passenger_seats
   OR evt.passengers_held<evt.booked_seats
   OR evt.passengers_held>evt.passenger_capacity
   OR evt.capacity_version IS DISTINCT FROM evt.schedule_version
   OR evt.capacity_commercial_version IS DISTINCT FROM evt.plan_version
   OR evt.capacity_departure_utc IS DISTINCT FROM evt.departure_utc
   OR evt.capacity_arrival_utc IS DISTINCT FROM evt.arrival_utc
   OR evt.certification_count<5
   OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_schedule_activation_preparations_v1 prep
    WHERE prep.schedule_id=evt.schedule_id
    AND prep.schedule_version=evt.schedule_version
    AND prep.airline_id=evt.airline_id
    AND prep.aircraft_inventory_id=evt.aircraft_inventory_id
    AND prep.verified_game_date<=evt.flight_local_date
    AND prep.verified_game_date+prep.certified_horizon_days>=evt.flight_local_date
    AND prep.fingerprint_md5~'^[a-f0-9]{32}$'
    AND length(prep.release_reference)>=12)
  THEN reason:='INCOMPLETE_CERTIFIED_OPERATING_SCHEDULE';END IF;
  IF reason IS NULL AND (
     NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slots
       WHERE slots.schedule_id=evt.schedule_id
        AND slots.airport_key=evt.origin_airport_key AND slots.direction='departure')
     OR NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slots
       WHERE slots.schedule_id=evt.schedule_id
        AND slots.airport_key=evt.destination_airport_key AND slots.direction='arrival')
  ) THEN reason:='AIRPORT_SLOTS_NOT_RESERVED';END IF;
  IF reason IS NULL AND NOT airlinerra_game.section9_canonical_aoc_covers_v1(evt.airline_id,airlinerra_game.section9_verified_permission_game_day_v1(),0) THEN reason:='ISSUED_OPERATOR_GAME_LICENCE_MISSING';END IF;
  IF reason IS NULL THEN
   required_permission_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
    evt.home_country,evt.origin_country,evt.destination_country,
    'passenger',evt.flight_local_date);
   IF required_permission_code IS NULL OR NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 r
    JOIN airlinerra_game.section9_game_permission_applications_v1 a
     ON a.id=r.issued_application_id
      AND a.airline_id=r.airline_id
      AND a.status='issued'
      AND a.ledger_entry_id IS NOT NULL
      AND a.permission_code=required_permission_code
      AND a.issued_game_date=r.valid_from
      AND a.valid_until_game_date=r.valid_until
    WHERE r.world_id=1 AND r.airline_id=evt.airline_id
     AND r.origin_airport_key=evt.origin_airport_key
     AND r.destination_airport_key=evt.destination_airport_key
     AND r.service_type='passenger'
     AND r.evidence_status='verified'
     AND r.valid_from<=evt.flight_local_date
     AND r.valid_until>=evt.flight_local_date
     AND r.evidence_reference='game-permission-issued-v1-'||a.id::text)
    THEN reason:='ISSUED_ROUTE_GAME_RIGHTS_MISSING';END IF;
  END IF;
  IF reason IS NULL AND evt.phase='departed' THEN
   maintenance:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
      evt.owner_player_id,evt.airline_id,evt.aircraft_inventory_id,
      evt.departure_utc,evt.arrival_utc);
   IF maintenance->>'gameMaintenanceClear' IS DISTINCT FROM 'true'
   THEN reason:='GAME_MAINTENANCE_DISPATCH_BLOCKED';END IF;
  END IF;
  -- Fuel must already exist on this exact game aircraft, at this
  -- exact departure airport, backed by an approved game-source receipt
  -- or signed prior arrival. Generic airport fuel_available is insufficient.
  IF reason IS NULL AND evt.phase='departed' THEN
    -- A trusted GAME-ONLY airport supply fills a verified fuel gap when
    -- the airplane is on the authoritative game ground airport. No
    -- client payment, no real-world fuel certification, no ledger charge.
    fuel_supply:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(
       evt.physical_id);
    IF fuel_supply->>'status' NOT IN
      ('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient')
      OR fuel_supply->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN
      reason:='GAME_AIRPORT_FUEL_TOPUP_NOT_AVAILABLE';
    ELSE
      fuel_check:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(
        evt.physical_id);
      IF fuel_check->>'status' IS DISTINCT FROM
          'verified_game_fuel_onboard_available_for_planned_trip'
        OR fuel_check->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
        OR fuel_check->>'ledgerPosted' IS DISTINCT FROM 'false'
      THEN reason:='AIRCRAFT_FUEL_NOT_PROVEN_AT_ORIGIN';END IF;
    END IF;

  END IF;
  IF reason IS NULL AND evt.phase='arrived' AND
     NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
      WHERE m.flight_occurrence_id=evt.physical_id AND m.phase='departed')
  THEN reason:='ARRIVAL_WITHOUT_VERIFIED_DEPARTURE';END IF;
  IF reason IS NULL THEN
   matches:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
     evt.airline_id,evt.aircraft_inventory_id,
     (evt.event_time AT TIME ZONE 'UTC')::date);
   IF matches->>'status' IS DISTINCT FROM 'verified_operational_candidates_only'
    OR jsonb_typeof(matches->'candidates')<>'array'
   THEN reason:='VERIFIED_AIRCRAFT_DAY_EVENTS_MISSING';
   ELSE
    candidate:=NULL;
    SELECT value INTO candidate
    FROM jsonb_array_elements(matches->'candidates') c(value)
    WHERE c.value->>'scheduleId'=evt.schedule_id::text
     AND c.value->>'scheduleVersion'=evt.schedule_version::text
     AND c.value->>'flightLocalDate'=evt.flight_local_date::text
     AND c.value->>'weeklyEntry'=evt.weekly_entry::text
     AND c.value->>'phase'=evt.phase
     AND (c.value->>'scheduledEventUtc')::timestamptz=evt.event_time
    LIMIT 1;
    IF candidate IS NULL THEN
     reason:='SIGNED_AIRCRAFT_TIMETABLE_MISMATCH';END IF;
   END IF;
  END IF;
  IF reason IS NOT NULL THEN
    blocked:=blocked+1;
    warnings:=jsonb_set(warnings,ARRAY[reason],
      to_jsonb(coalesce((warnings->>reason)::integer,0)+1),true);
    CONTINUE;
  END IF;
  movement_event_id:=candidate->>'eventId';
  IF movement_event_id IS NULL OR length(movement_event_id) NOT BETWEEN 12 AND 128
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_INVALID_VERIFIED_DISPATCH_EVENT_ID';END IF;
  payload:=concat_ws(E'\n',
   'airlinerra-operated-game-event-v1','1',evt.airline_id::text,
   evt.schedule_id::text,evt.schedule_version::text,
   evt.flight_local_date::text,evt.weekly_entry::text,evt.phase,
   to_char(evt.event_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   movement_event_id);
  event_signature:=encode(extensions.hmac(
   pg_catalog.convert_to(payload,'UTF8'),
   pg_catalog.convert_to(signer_key,'UTF8'),'sha256'),'hex');
  movement:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   evt.airline_id,evt.schedule_id,evt.schedule_version,
   evt.flight_local_date,evt.weekly_entry,evt.phase,
   evt.event_time,movement_event_id,event_signature);
  IF movement->>'movementRecorded' IS DISTINCT FROM 'true'
   OR movement->>'replayed' IS DISTINCT FROM 'false'
   OR movement->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AUTOMATIC_DISPATCH_MOVEMENT_NOT_CONFIRMED_ROLLBACK';END IF;
  IF evt.phase='departed' THEN
    fuel_receipt:=airlinerra_game.section9_capture_verified_departure_fuel_v1(
      evt.physical_id,movement_event_id);
    IF fuel_receipt->>'status' IS DISTINCT FROM
       'signed_game_fuel_departure_receipt_created'
      OR fuel_receipt->>'fuelReceiptCreated' IS DISTINCT FROM 'true'
      OR fuel_receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='SECTION9_UNVERIFIED_DEPARTURE_FUEL_ROLLS_BACK_MOVEMENT';END IF;
    UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
    SET booking_status='closed' WHERE id=evt.occurrence_id
      AND booking_status='open';
    GET DIAGNOSTICS changed=ROW_COUNT;
    IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_DEPARTURE_BOOKING_CLOSE_UNCONFIRMED_ROLLBACK';END IF;
    departures:=departures+1;
  ELSE
    airframe_usage:=airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(
      evt.physical_id);
    IF airframe_usage->>'status' IS DISTINCT FROM 'arrived_airframe_usage_recorded_once'
    OR airframe_usage->>'usageApplied' IS DISTINCT FROM 'true'
    OR airframe_usage->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_ARRIVAL_AIRFRAME_USAGE_NOT_ATOMIC_ROLLBACK';END IF;
    fuel_receipt:=airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(
      evt.physical_id,movement_event_id);
    IF fuel_receipt->>'status' IS DISTINCT FROM
        'signed_game_arrival_fuel_burn_recorded_once'
      OR fuel_receipt->>'fuelBurnRecorded' IS DISTINCT FROM 'true'
      OR fuel_receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='SECTION9_UNVERIFIED_ARRIVAL_FUEL_ROLLS_BACK_MOVEMENT';END IF;
    arrivals:=arrivals+1;
  END IF;
 END LOOP;
 RETURN jsonb_build_object(
   'status','trusted_game_dispatch_cycle_completed',
   'verifiedGameHourUtc',now_utc,
   'candidatesChecked',used,
   'departuresRecorded',departures,'arrivalsRecorded',arrivals,
   'blocked',blocked,'blockerCounts',warnings,
   'signingSecretExposed',false,
   'ticketRevenueRecognized',false,'ledgerPosted',false,
   'actualFuelSettlementConnected',false,'gameFuelCustodyTrackingConnected',true);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_decide_game_permission_application_v1(p_application uuid, p_event_id text, p_decision text, p_review_reference text, p_verified_hmac text, p_game_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE application_row record;old_event record;airline_row record;
 policy_row record;catalog_row record;day_now date;
 origin_country text;destination_country text;home_country text;
 expected_code text;entry_id bigint;new_expiry date;
 new_status text;
BEGIN
 IF p_application IS NULL OR p_event_id IS NULL OR
  p_event_id !~ '^[A-Za-z0-9._:-]{16,128}$' OR
  p_decision NOT IN('approve','reject','revoke') OR
  length(coalesce(p_review_reference,'')) NOT BETWEEN 12 AND 160 OR
  p_verified_hmac IS NULL OR p_verified_hmac !~ '^[a-f0-9]{64}$' OR
  p_game_date IS NULL OR p_game_date NOT BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_SIGNED_GAME_PERMISSION_DECISION';END IF;
 -- Lock airline before application to serialize cash with all other
 -- purchases and admissions for the SAME company.
 SELECT a.* INTO airline_row
 FROM airlinerra_game.airlines a
 WHERE a.id=(SELECT application_source.airline_id
  FROM airlinerra_game.section9_game_permission_applications_v1 application_source
  WHERE application_source.id=p_application)
 AND a.world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_DECISION_AIRLINE_NOT_FOUND';END IF;
 SELECT * INTO application_row
 FROM airlinerra_game.section9_game_permission_applications_v1 p
 WHERE p.id=p_application AND p.airline_id=airline_row.id
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_DECISION_APPLICATION_NOT_FOUND';END IF;
 SELECT * INTO old_event
 FROM airlinerra_game.section9_game_permission_review_events_v1 event
 WHERE event.event_id=p_event_id;
 IF FOUND THEN
  IF old_event.application_id IS DISTINCT FROM p_application
   OR old_event.airline_id IS DISTINCT FROM application_row.airline_id
   OR old_event.decision IS DISTINCT FROM p_decision
   OR old_event.game_date IS DISTINCT FROM p_game_date
   OR old_event.reviewer_reference IS DISTINCT FROM p_review_reference
   OR old_event.verified_hmac_sha256 IS DISTINCT FROM p_verified_hmac
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_GAME_PERMISSION_DECISION_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object(
   'status','game_permission_decision_replayed',
   'applicationId',p_application,'eventId',p_event_id,
   'replayed',true,'applicationStatus',application_row.status,
   'chargedNow',false,'licenceIssuedNow',false,
   'flightActivated',false,'ledgerPostedNow',false);
 END IF;

 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL OR day_now IS DISTINCT FROM p_game_date
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day',
  'applicationId',p_application,'chargedNow',false,
  'licenceIssuedNow',false,'flightActivated',false,
  'ledgerPostedNow',false);END IF;
 IF p_decision IN ('approve','reject') AND
   (application_row.status IS DISTINCT FROM 'submitted'
    OR application_row.due_game_date>day_now)
 THEN RETURN jsonb_build_object(
  'status','blocked_application_not_due_or_processed',
  'applicationId',p_application,'chargedNow',false,
  'licenceIssuedNow',false,'flightActivated',false,
  'ledgerPostedNow',false);END IF;
 IF p_decision='revoke' AND application_row.status IS DISTINCT FROM 'issued'
 THEN RETURN jsonb_build_object(
  'status','blocked_application_not_issued',
  'applicationId',p_application,'chargedNow',false,
  'licenceIssuedNow',false,'flightActivated',false,
  'ledgerPostedNow',false);END IF;

 IF p_decision='approve' THEN
  SELECT * INTO policy_row
  FROM airlinerra_game.section9_game_permission_issuance_policy_v1 p
  WHERE p.permission_code=application_row.permission_code FOR SHARE;
  SELECT * INTO catalog_row
  FROM airlinerra_game.business_permission_catalog_v1 c
  WHERE c.permission_code=application_row.permission_code FOR SHARE;
  IF policy_row.release_enabled IS DISTINCT FROM true OR
   policy_row.released_at IS NULL OR
   policy_row.policy_revision IS DISTINCT FROM application_row.policy_revision OR
   policy_row.validity_game_days IS DISTINCT FROM application_row.validity_game_days OR
   catalog_row.enabled_in_game IS DISTINCT FROM true OR
   catalog_row.game_fee_usd IS DISTINCT FROM application_row.fee_usd OR
   catalog_row.processing_game_days IS DISTINCT FROM
    (application_row.due_game_date-application_row.applied_game_date)
  THEN RETURN jsonb_build_object(
   'status','blocked_permission_policy_changed_or_disabled',
   'applicationId',p_application,'chargedNow',false,
   'licenceIssuedNow',false,'flightActivated',false,
   'ledgerPostedNow',false);END IF;
  SELECT home.country_iso INTO home_country
  FROM airlinerra_game.airport_reference_profiles home
  WHERE home.world_id=1 AND home.airport_key=airline_row.home_airport_key;
  IF home_country IS NULL OR home_country !~ '^[A-Z]{2}$'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_GAME_PERMISSION_AIRLINE_JURISDICTION_CHANGED';END IF;
  IF application_row.permission_code='AIR_OPERATOR_CERTIFICATE' THEN
   IF application_row.jurisdiction_iso2 IS DISTINCT FROM home_country
   THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_OPERATOR_LICENCE_JURISDICTION_CHANGED';END IF;
  ELSE
   SELECT country_iso INTO origin_country
   FROM airlinerra_game.airport_reference_profiles
   WHERE world_id=1 AND airport_key=application_row.origin_airport_key;
   SELECT country_iso INTO destination_country
   FROM airlinerra_game.airport_reference_profiles
   WHERE world_id=1 AND airport_key=application_row.destination_airport_key;
   expected_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
    home_country,origin_country,destination_country,
    application_row.service_type,p_game_date);
   IF expected_code IS DISTINCT FROM application_row.permission_code
   THEN RETURN jsonb_build_object(
    'status','blocked_game_traffic_rights_policy_changed',
    'applicationId',p_application,'chargedNow',false,
    'licenceIssuedNow',false,'flightActivated',false,
    'ledgerPostedNow',false);END IF;
   IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(application_row.airline_id,day_now,28) THEN RETURN jsonb_build_object(
     'status','blocked_operator_licence_expired_or_revoked',
     'applicationId',p_application,'chargedNow',false,
     'licenceIssuedNow',false,'flightActivated',false,
     'ledgerPostedNow',false);END IF;
  END IF;
  IF EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 other
   WHERE other.airline_id=application_row.airline_id AND other.scope_key=application_row.scope_key
    AND other.id<>application_row.id AND other.status='issued'
    AND other.valid_until_game_date>=day_now+28
  ) THEN RETURN jsonb_build_object(
   'status','blocked_permission_already_valid',
   'applicationId',p_application,'chargedNow',false,
   'licenceIssuedNow',false,'flightActivated',false,
   'ledgerPostedNow',false);END IF;
  IF airline_row.cash_usd<application_row.fee_usd
  THEN RETURN jsonb_build_object(
   'status','blocked_insufficient_airline_cash',
   'applicationId',p_application,'chargedNow',false,
   'licenceIssuedNow',false,'flightActivated',false,
   'ledgerPostedNow',false);END IF;
  -- Atomic financial settlement (one transaction and one airline lock).
  -- The existing ledger requires EXPENSE with nonzero negative amount.
  UPDATE airlinerra_game.airlines
  SET cash_usd=cash_usd-application_row.fee_usd
  WHERE id=application_row.airline_id AND cash_usd>=application_row.fee_usd;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_GAME_PERMISSION_CASH_CHANGED_CONCURRENTLY';END IF;
  INSERT INTO airlinerra_game.airline_ledger(
   airline_id,entry_kind,amount_usd)
  VALUES(application_row.airline_id,'EXPENSE',-application_row.fee_usd)
  RETURNING id INTO entry_id;
  new_expiry:=day_now+application_row.validity_game_days;
  IF application_row.permission_code='AIR_OPERATOR_CERTIFICATE' THEN
   INSERT INTO airlinerra_game.section9_operator_licence_evidence_v1(
    world_id,airline_id,jurisdiction_iso2,evidence_status,
    evidence_reference,reviewed_at,valid_from,valid_until,
    issued_application_id)
   VALUES(1,application_row.airline_id,home_country,'verified',
    'game-permission-issued-v1-'||application_row.id::text,
    clock_timestamp(),day_now,new_expiry,application_row.id)
   ON CONFLICT(airline_id,jurisdiction_iso2) DO UPDATE SET
    evidence_status='verified',
    evidence_reference=EXCLUDED.evidence_reference,
    reviewed_at=EXCLUDED.reviewed_at,
    valid_from=EXCLUDED.valid_from,
    valid_until=EXCLUDED.valid_until,
    issued_application_id=EXCLUDED.issued_application_id;
  ELSE
   INSERT INTO airlinerra_game.section9_route_operating_permission_evidence_v1(
    world_id,airline_id,origin_airport_key,destination_airport_key,
    service_type,evidence_status,evidence_reference,
    reviewed_at,valid_from,valid_until,issued_application_id)
   VALUES(1,application_row.airline_id,application_row.origin_airport_key,
    application_row.destination_airport_key,application_row.service_type,'verified',
    'game-permission-issued-v1-'||application_row.id::text,
    clock_timestamp(),day_now,new_expiry,application_row.id)
   ON CONFLICT(airline_id,origin_airport_key,destination_airport_key,service_type)
   DO UPDATE SET evidence_status='verified',
    evidence_reference=EXCLUDED.evidence_reference,
    reviewed_at=EXCLUDED.reviewed_at,
    valid_from=EXCLUDED.valid_from,
    valid_until=EXCLUDED.valid_until,
    issued_application_id=EXCLUDED.issued_application_id;
  END IF;
  UPDATE airlinerra_game.section9_game_permission_applications_v1
  SET status='issued',issued_game_date=day_now,
   valid_until_game_date=new_expiry,ledger_entry_id=entry_id,
   reviewed_by=p_review_reference,reviewed_at=clock_timestamp(),
   last_review_event_id=p_event_id,updated_at=clock_timestamp()
  WHERE id=p_application;
  new_status:='issued';
 ELSIF p_decision='reject' THEN
  UPDATE airlinerra_game.section9_game_permission_applications_v1
  SET status='rejected',reviewed_by=p_review_reference,
   reviewed_at=clock_timestamp(),last_review_event_id=p_event_id,
   updated_at=clock_timestamp()
  WHERE id=p_application;
  new_status:='rejected';
 ELSE
  UPDATE airlinerra_game.section9_game_permission_applications_v1
  SET status='revoked',reviewed_by=p_review_reference,
   reviewed_at=clock_timestamp(),last_review_event_id=p_event_id,
   updated_at=clock_timestamp()
  WHERE id=p_application;
  IF application_row.permission_code='AIR_OPERATOR_CERTIFICATE' THEN
   UPDATE airlinerra_game.section9_operator_licence_evidence_v1
   SET evidence_status='revoked',reviewed_at=clock_timestamp()
   WHERE issued_application_id=p_application;
  ELSE
   UPDATE airlinerra_game.section9_route_operating_permission_evidence_v1
   SET evidence_status='revoked',reviewed_at=clock_timestamp()
   WHERE issued_application_id=p_application;
  END IF;
  new_status:='revoked';
 END IF;

 INSERT INTO airlinerra_game.section9_game_permission_review_events_v1(
  event_id,application_id,airline_id,decision,game_date,
  reviewer_reference,verified_hmac_sha256)
 VALUES(p_event_id,p_application,application_row.airline_id,p_decision,p_game_date,
  p_review_reference,p_verified_hmac);
 -- An operator revocation/expiration affects ALL routes of the airline.
 DELETE FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE airline_id=application_row.airline_id;
 RETURN jsonb_build_object(
  'status','game_permission_'||new_status,
  'applicationId',p_application,'eventId',p_event_id,
  'applicationStatus',new_status,'validUntilGameDate',
   CASE WHEN new_status='issued' THEN new_expiry ELSE application_row.valid_until_game_date END,
  'feeChargedUsd',CASE WHEN new_status='issued' THEN application_row.fee_usd ELSE 0 END,
  'ledgerEntryId',entry_id,
  'replayed',false,'chargedNow',(new_status='issued'),
  'licenceIssuedNow',(new_status='issued'),
  'flightActivated',false,'ledgerPostedNow',(new_status='issued'),
  'bookingsCreated',false,'movementRecorded',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_licence_preflight_v1(p_player uuid, p_airline uuid, p_schedule uuid, p_date date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE s record;crew_required integer;crew_details jsonb;
 insufficient_days integer;qualified_count integer;proposed_count integer;
 stale_count integer;possible_other_routes integer;
 approved_operator record;
 approved_rights integer;required_rights integer;
 permissions jsonb; country_hint text;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
 OR p_date IS NULL OR p_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_CREW_RIGHTS_READINESS_REQUEST';END IF;
 SELECT d.id,d.airline_id,d.configuration_id,d.weekly_schedule,d.version,
  d.status,d.origin_airport_key,d.destination_airport_key,
  c.crew_required,c.use_type,a.home_airport_key,
  home.country_iso AS home_country
 INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a ON a.id=d.airline_id
  AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra.aircraft_configurations c ON c.id=d.configuration_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=a.home_airport_key
 WHERE d.id=p_schedule AND d.airline_id=p_airline AND d.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CREW_RIGHTS_SCHEDULE_NOT_OWNED';END IF;
 crew_required:=CASE WHEN s.crew_required>0 THEN s.crew_required ELSE NULL END;
 country_hint:=s.home_country;

 WITH entries AS (
  SELECT e.ordinality::int AS entry
  FROM jsonb_array_elements(s.weekly_schedule)
  WITH ORDINALITY AS e(item,ordinality)
 ), counts AS (
  SELECT e.entry,
   count(d.crew_id)::int AS proposed_total,
   count(d.crew_id) FILTER(WHERE
    d.schedule_version=s.version
    AND cr.qualified_configuration_id=s.configuration_id
    AND cr.employment_status='verified_employed')::int AS registered_count,
   count(d.crew_id) FILTER(WHERE
    d.schedule_version<>s.version)::int AS stale_total
  FROM entries e
  LEFT JOIN airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
   ON d.schedule_id=s.id AND d.weekly_entry=e.entry
  LEFT JOIN airlinerra_game.section9_airline_crew_roster_v1 cr
   ON cr.crew_id=d.crew_id AND cr.airline_id=p_airline
  GROUP BY e.entry
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'weeklyEntry',entry,'proposed',proposed_total,
   'registeredVerifiedEmployment',registered_count,
   'missingRegisteredCrew',CASE WHEN crew_required IS NULL THEN NULL
     ELSE greatest(0,crew_required-registered_count) END,
   'outdatedAssignments',stale_total)
  ORDER BY entry),'[]'::jsonb),
  count(*) FILTER(WHERE crew_required IS NULL
   OR registered_count<crew_required)::int,
  coalesce(sum(registered_count),0)::int,
  coalesce(sum(proposed_total),0)::int,
  coalesce(sum(stale_total),0)::int
 INTO crew_details,insufficient_days,qualified_count,proposed_count,stale_count
 FROM counts;

 -- Multiple scheduled routes with the same crew are NOT necessarily
 -- overlapping. Report all reuse for duty rest/concurrency validation.
 -- No fake "conflict-free" certification is issued from this count.
 SELECT count(*)::int INTO possible_other_routes
 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
 WHERE d.airline_id=p_airline AND d.schedule_id<>s.id
 AND EXISTS(
   SELECT 1 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 own
   WHERE own.schedule_id=s.id AND own.crew_id=d.crew_id
 );

 SELECT o.* INTO approved_operator
 FROM airlinerra_game.section9_operator_licence_evidence_v1 o
 WHERE o.world_id=1 AND o.airline_id=p_airline
  AND o.jurisdiction_iso2=country_hint
  AND o.evidence_status='verified'
  AND o.reviewed_at IS NOT NULL
  AND o.valid_from<=p_date
  AND (o.valid_until IS NULL OR o.valid_until>=p_date+p_days)
 ORDER BY o.reviewed_at DESC LIMIT 1;

 WITH needed AS (
  SELECT x.role
  FROM unnest(CASE s.use_type
    WHEN 'cargo' THEN ARRAY['cargo']::text[]
    WHEN 'combi' THEN ARRAY['passenger','cargo']::text[]
    ELSE ARRAY['passenger']::text[] END) AS x(role)
 ), checks AS (
  SELECT n.role,
   EXISTS(SELECT 1 FROM
    airlinerra_game.section9_route_operating_permission_evidence_v1 e
    WHERE e.world_id=1 AND e.airline_id=p_airline
      AND e.origin_airport_key=s.origin_airport_key
      AND e.destination_airport_key=s.destination_airport_key
      AND e.service_type=n.role AND e.evidence_status='verified'
      AND e.reviewed_at IS NOT NULL AND e.valid_from<=p_date
      AND (e.valid_until IS NULL OR e.valid_until>=p_date+p_days)
   ) AS evidence_present
  FROM needed n
 )
 SELECT count(*),count(*) FILTER(WHERE evidence_present),
 coalesce(jsonb_agg(jsonb_build_object('serviceType',role,
  'privatelyReviewedRecordPresent',evidence_present)
  ORDER BY role),'[]'::jsonb)
 INTO required_rights,approved_rights,permissions
 FROM checks;

 RETURN jsonb_build_object(
  'status','STAFFING_AND_PERMISSION_NOT_OPERATIONALLY_CERTIFIED',
  'scheduleId',s.id,'scheduleVersion',s.version,
  'crew',jsonb_build_object(
   'catalogCrewRequirement',crew_required,
   'catalogCrewRequirementKnown',crew_required IS NOT NULL,
   'weeklyEntries',crew_details,
   'entriesMissingRegisteredCrew',insufficient_days,
   'registeredEmployeeAssignments',qualified_count,
   'proposedAssignments',proposed_count,
   'staleAssignments',stale_count,
   'otherRouteReuseNeedsConflictAndRestChecks',possible_other_routes,
   'dutyRestAndQualificationsOperationallyCertified',false,
   'flightCrewAuthorized',false),
  'permissions',jsonb_build_object(
   'operatorJurisdictionHint',country_hint,
   'gameOperatorLicenceEvidenceRecorded',airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,p_date,p_days),
   'requiredServiceTypes',required_rights,
   'gameRoutePermissionEvidenceRecorded',approved_rights,
   'individualServiceTypes',permissions,
   'legalOperatingLicenceIndependentlyConfirmed',false,
   'trafficRightsOperationallyGranted',false),
  'gameDate',p_date,'previewDays',p_days,
  'readOnly',true,'canActivateNormalFlight',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_submit_game_permission_application_v1(p_player uuid, p_airline uuid, p_request_key uuid, p_permission_code text, p_origin text DEFAULT NULL::text, p_destination text DEFAULT NULL::text, p_service_type text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE owner_row record;existing_row record;policy_row record;catalog_row record;
 day_now date;home_country text;origin_country text;destination_country text;
 expected_code text;scope text;review_fee numeric;review_days integer;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_request_key IS NULL OR
  length(coalesce(p_permission_code,''))<3
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PERMISSION_APPLICATION';END IF;
 SELECT a.*,home.country_iso INTO owner_row
 FROM airlinerra_game.airlines a
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=a.world_id AND home.airport_key=a.home_airport_key
 WHERE a.id=p_airline AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND OR owner_row.owner_player_id IS DISTINCT FROM p_player
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_APPLICATION_NOT_OWNED';END IF;
 SELECT * INTO existing_row
 FROM airlinerra_game.section9_game_permission_applications_v1 app
 WHERE app.airline_id=p_airline AND app.request_key=p_request_key;
 IF FOUND THEN
  IF existing_row.permission_code IS DISTINCT FROM p_permission_code OR
   existing_row.origin_airport_key IS DISTINCT FROM p_origin OR
   existing_row.destination_airport_key IS DISTINCT FROM p_destination OR
   existing_row.service_type IS DISTINCT FROM p_service_type
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_PERMISSION_REQUEST_KEY_CONFLICT';END IF;
  RETURN jsonb_build_object(
   'status','permission_application_replayed','applicationId',existing_row.id,
   'applicationStatus',existing_row.status,'replayed',true,
   'charged',false,'licenceIssued',false,'flightActivated',false,
   'ledgerPosted',false);END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN RETURN jsonb_build_object(
   'status','blocked_unverified_world_or_game_day','submitted',false,
   'charged',false,'licenceIssued',false,'flightActivated',false,
   'ledgerPosted',false);END IF;
 SELECT * INTO catalog_row
 FROM airlinerra_game.business_permission_catalog_v1 c
 WHERE c.permission_code=p_permission_code FOR SHARE;
 SELECT * INTO policy_row
 FROM airlinerra_game.section9_game_permission_issuance_policy_v1 p
 WHERE p.permission_code=p_permission_code FOR SHARE;
 IF catalog_row.enabled_in_game IS DISTINCT FROM true OR
  catalog_row.game_fee_usd IS NULL OR catalog_row.game_fee_usd<=0 OR
  catalog_row.game_fee_usd>1000000 OR
  catalog_row.processing_game_days NOT BETWEEN 1 AND 90 OR
  policy_row.release_enabled IS DISTINCT FROM true OR
  policy_row.released_at IS NULL OR
  policy_row.validity_game_days NOT BETWEEN 35 AND 1095
 THEN RETURN jsonb_build_object(
  'status','blocked_game_permission_issuance_disabled',
  'permissionCode',p_permission_code,'submitted',false,
  'charged',false,'licenceIssued',false,'flightActivated',false,
  'ledgerPosted',false);END IF;
 IF owner_row.country_iso IS NULL OR
  owner_row.country_iso !~ '^[A-Z]{2}$' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AIRLINE_HOME_JURISDICTION_MISSING';END IF;
 home_country:=owner_row.country_iso;
 IF p_permission_code='AIR_OPERATOR_CERTIFICATE' THEN
  IF p_origin IS NOT NULL OR p_destination IS NOT NULL
   OR p_service_type IS NOT NULL OR catalog_row.category<>'airline'
   OR catalog_row.holder_scope<>'operating_company'
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_OPERATOR_LICENSE_SCOPE_INVALID';END IF;
  scope:='operator:'||home_country;
 ELSE
  IF catalog_row.category<>'traffic_rights' OR
   catalog_row.holder_scope<>'route' OR
   p_origin IS NULL OR p_destination IS NULL OR
   p_origin=p_destination OR
   p_service_type NOT IN('passenger','cargo')
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_ROUTE_PERMISSION_SCOPE_INVALID';END IF;
  SELECT country_iso INTO origin_country
  FROM airlinerra_game.airport_reference_profiles
  WHERE world_id=1 AND airport_key=p_origin;
  SELECT country_iso INTO destination_country
  FROM airlinerra_game.airport_reference_profiles
  WHERE world_id=1 AND airport_key=p_destination;
  expected_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
   home_country,origin_country,destination_country,p_service_type,day_now);
  IF expected_code IS DISTINCT FROM p_permission_code
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ROUTE_GAME_PERMISSION_POLICY_NOT_SUPPORTED';END IF;
  IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,day_now,28)
  THEN RETURN jsonb_build_object(
   'status','blocked_operator_licence_required','submitted',false,
   'charged',false,'licenceIssued',false,'flightActivated',false,
   'ledgerPosted',false);END IF;
  scope:='route:'||p_origin||':'||p_destination||':'||p_service_type;
 END IF;

 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
  WHERE app.airline_id=p_airline AND app.scope_key=scope
   AND app.status='issued'
   AND app.valid_until_game_date>=day_now+28)
 THEN RETURN jsonb_build_object(
  'status','blocked_game_permission_already_valid',
  'submitted',false,'charged',false,'licenceIssued',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
  WHERE app.airline_id=p_airline AND app.scope_key=scope
   AND app.status='submitted')
 THEN RETURN jsonb_build_object(
  'status','blocked_game_permission_application_pending',
  'submitted',false,'charged',false,'licenceIssued',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_game_permission_applications_v1(
  airline_id,applicant_player_id,request_key,permission_code,scope_key,
  jurisdiction_iso2,origin_airport_key,destination_airport_key,service_type,
  applied_game_date,due_game_date,policy_revision,
  fee_usd,validity_game_days)
 VALUES(p_airline,p_player,p_request_key,p_permission_code,scope,
  CASE WHEN p_permission_code='AIR_OPERATOR_CERTIFICATE'
   THEN home_country ELSE NULL END,
  p_origin,p_destination,p_service_type,
  day_now,day_now+catalog_row.processing_game_days,
  policy_row.policy_revision,catalog_row.game_fee_usd,
  policy_row.validity_game_days)
 RETURNING id,due_game_date,fee_usd INTO existing_row;
 RETURN jsonb_build_object(
  'status','permission_application_submitted',
  'applicationId',existing_row.id,'dueGameDate',existing_row.due_game_date,
  'feeAtIssuanceUsd',existing_row.fee_usd,'submitted',true,
  'charged',false,'licenceIssued',false,'flightActivated',false,
  'ledgerPosted',false);
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
  target.status IS DISTINCT FROM 'draft' OR
  target.operationally_verified IS DISTINCT FROM false
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
COMMIT;
