BEGIN;
-- Canonical game licensing: no paid route-by-route permission for Licence 1.
-- Foreign-to-foreign expansion retains the existing Licence 2 market/quota rules.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_route_licence_scope_v1(p_airline uuid,p_origin text,p_destination text,p_day date,p_days int)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE scope jsonb; market text;
BEGIN
 IF NOT airlinerra_game.section9_canonical_aoc_covers_v1(p_airline,p_day,p_days) THEN
 RETURN jsonb_build_object('allowed',false,'decision','VALID_LICENCE_1_REQUIRED');END IF;
 scope:=airlinerra_game.licence2_foreign_route_preview_v1(p_airline,p_origin,p_destination,NULL);
 IF scope->>'decision'='L1_HOME_MARKET_ROUTE' THEN
 RETURN jsonb_build_object('allowed',true,'decision','L1_HOME_MARKET_ROUTE','licence',1,'applicationRequired',false);END IF;
 IF scope->>'requiresLicence2' IS DISTINCT FROM 'true' THEN
 RETURN jsonb_build_object('allowed',false,'decision',coalesce(scope->>'decision','INVALID_ROUTE'));END IF;
 market:=scope->>'market';
 IF scope->>'decision'='L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK' AND EXISTS(
 SELECT 1 FROM airlinerra_game.licence2_directed_route_allocations_v1 x WHERE x.world_id=1 AND x.airline_id=p_airline AND x.origin_airport_key=p_origin AND x.destination_airport_key=p_destination AND x.market_code=market AND x.allocation_state IN ('reserved','active'))
 THEN RETURN jsonb_build_object('allowed',true,'decision','L2_APPROVED_MARKET_ROUTE','licence',2,'market',market,'applicationRequired',false);END IF;
 RETURN jsonb_build_object('allowed',false,'decision',coalesce(scope->>'decision','L2_REQUIRED'),'licence',2,'market',market);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_route_licence_scope_v1(uuid,text,text,date,int) FROM PUBLIC,anon,authenticated,service_role;
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
  IF reason IS NULL AND airlinerra_game.section9_game_route_licence_scope_v1(evt.airline_id,evt.origin_airport_key,evt.destination_airport_key,evt.flight_local_date,0)->>'allowed' IS DISTINCT FROM 'true' THEN reason:='GAME_ROUTE_LICENCE_SCOPE_NOT_AUTHORIZED';END IF;
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
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_origin text, p_destination text, p_departure timestamp with time zone, p_arrival timestamp with time zone, p_weekly jsonb, p_departure_stand text, p_arrival_stand text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 v_now timestamptz;
 target record;
 game_day date;
 roles text[];
 role_name text;
 v_permission_code text;
 permission_ok boolean;
 slot_preview jsonb:=NULL;
 restrict_preview jsonb:=NULL;
 slot_available boolean:=false;
 rights_granted integer:=0;
 blockers text[]:=ARRAY[]::text[];
 details jsonb:='[]'::jsonb;
 airport_findings jsonb:=NULL;
 rotation_preview jsonb:=NULL;
 owner_world integer:=0;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
  OR p_origin IS NULL OR p_destination IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_CANDIDATE_ROUTE_IDENTITY';END IF;

 SELECT a.owner_player_id,a.world_id,
        home.country_iso AS operator_country,
        o.country_iso AS origin_country,
        d.country_iso AS destination_country,
        f.fleet_status,f.ownership_type,f.configuration_id,c.use_type
 INTO target
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active'
 JOIN airlinerra.aircraft_configurations c ON c.id=f.configuration_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=a.home_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles o
  ON o.world_id=1 AND o.airport_key=p_origin
 LEFT JOIN airlinerra_game.airport_reference_profiles d
  ON d.world_id=1 AND d.airport_key=p_destination
 WHERE f.id=p_aircraft AND f.airline_id=p_airline
   AND a.owner_player_id=p_player AND a.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_CANDIDATE_ROUTE_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 game_day:=(v_now AT TIME ZONE 'Europe/Berlin')::date;
 IF target.fleet_status IS DISTINCT FROM 'in_service'
 OR target.ownership_type NOT IN ('owned','leased')
 THEN blockers:=array_append(blockers,'AIRCRAFT_NOT_ELIGIBLE_FOR_ROUTE');END IF;
 IF p_origin=p_destination OR
  target.operator_country IS NULL OR
  target.origin_country IS NULL OR
  target.destination_country IS NULL OR
  target.origin_country !~ '^[A-Z]{2}$' OR
  target.destination_country !~ '^[A-Z]{2}$'
 THEN blockers:=array_append(blockers,'ROUTE_COUNTRIES_OR_AIRPORTS_UNVERIFIED');END IF;
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports airport
     WHERE airport.world_id=1 AND airport.airport_key IN (p_origin,p_destination))<>2
 THEN blockers:=array_append(blockers,'AIRPORT_NOT_ADMITTED_TO_WORLD1');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 g
    WHERE g.airport_key IN(p_origin,p_destination))
 THEN blockers:=array_append(blockers,'GROUP2_AIRPORT_NOT_OPERATIONALLY_ADMITTED');END IF;

 IF p_departure IS NULL OR p_arrival IS NULL OR
  p_departure<=v_now OR p_departure>v_now+interval '42 days' OR
  p_arrival<=p_departure OR p_arrival>p_departure+interval '72 hours'
 THEN blockers:=array_append(blockers,'REFERENCE_UTC_DEPARTURE_AND_ARRIVAL_REQUIRED');END IF;
 IF p_departure_stand NOT IN ('terminal','remote','cargo') OR
  p_arrival_stand NOT IN ('terminal','remote','cargo') OR
  p_departure_stand IS NULL OR p_arrival_stand IS NULL
 THEN blockers:=array_append(blockers,'AIRPORT_STAND_TYPE_NOT_CONFIRMED');END IF;
 IF p_weekly IS NULL OR jsonb_typeof(p_weekly)<>'array' OR
   jsonb_array_length(p_weekly) NOT BETWEEN 1 AND 7
 THEN blockers:=array_append(blockers,'WEEKLY_FLIGHT_SCHEDULE_UNVERIFIED');END IF;

 IF NOT ('REFERENCE_UTC_DEPARTURE_AND_ARRIVAL_REQUIRED'=ANY(blockers)
   OR 'AIRPORT_STAND_TYPE_NOT_CONFIRMED'=ANY(blockers)
   OR 'WEEKLY_FLIGHT_SCHEDULE_UNVERIFIED'=ANY(blockers)
   OR 'AIRPORT_NOT_ADMITTED_TO_WORLD1'=ANY(blockers)
   OR 'GROUP2_AIRPORT_NOT_OPERATIONALLY_ADMITTED'=ANY(blockers))
 THEN
  slot_preview:=airlinerra_game.section6_weekly_slot_preflight_v1(
   1::smallint,p_origin,p_destination,p_departure,p_arrival,
   p_weekly,p_departure_stand,p_arrival_stand,NULL);
  restrict_preview:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
   1::smallint,p_origin,p_destination,target.configuration_id,
   p_departure,p_arrival,p_weekly);
  rotation_preview:=airlinerra_game.section9_owned_candidate_rotation_preflight_v1(
   p_player,p_airline,p_aircraft,p_origin,p_destination,
   p_departure,p_arrival,p_weekly,28);
  IF rotation_preview->>'readOnly' IS DISTINCT FROM 'true'
   OR rotation_preview->>'flightActivated' IS DISTINCT FROM 'false'
   OR rotation_preview->>'airportSlotsReserved' IS DISTINCT FROM 'false'
   OR rotation_preview->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CANDIDATE_ROTATION_EVIDENCE_UNSAFE';END IF;
  slot_available:=
    slot_preview->>'available'='true' AND
    slot_preview->>'departureAvailable'='true' AND
    slot_preview->>'arrivalAvailable'='true' AND
    coalesce((slot_preview->>'windowsChecked')::integer,0)>=2;

  -- Read-only diagnostics aggregated across the same 4-week check used for
  -- the enforceable gate. Missing evidence is never interpreted as approval.
  IF restrict_preview IS NOT NULL THEN
   SELECT jsonb_build_object(
     'readOnly',true,'operationApproved',false,
     'restrictionDecision',restrict_preview->>'decision',
     'weeklyOccurrencesChecked',count(*)::integer,
     'origin',jsonb_build_object(
       'airportKey',p_origin,
       'airportCode',max(x.leg#>>'{origin,airportCode}'),
       'runway',max(x.leg#>>'{origin,selectedRunwayDesignator}'),
       'runwaySourceId',max(x.leg#>>'{origin,selectedRunwaySourceId}'),
       'runwayOperationalStatusVerified',
          coalesce(bool_and(x.leg#>>'{origin,runwayOperationalStatusVerified}'='true'),false),
       'aircraftChapterMatched',
          coalesce(bool_and(x.leg#>>'{origin,aircraftChapterNotConfigurationMatched}'='false'),false),
       'airportResearchNeedsReview',
          coalesce(bool_or(x.leg#>>'{origin,researchReview}'='true'),true),
       'anyHardTimeRuleBlock',
          coalesce(bool_or(x.leg#>>'{origin,blockedByAirportTimeRule}'='true'),false),
       'anyRunwayReview',
          coalesce(bool_or(x.leg#>>'{origin,runwayReview}'='true'),true)),
     'destination',jsonb_build_object(
       'airportKey',p_destination,
       'airportCode',max(x.leg#>>'{destination,airportCode}'),
       'runway',max(x.leg#>>'{destination,selectedRunwayDesignator}'),
       'runwaySourceId',max(x.leg#>>'{destination,selectedRunwaySourceId}'),
       'runwayOperationalStatusVerified',
          coalesce(bool_and(x.leg#>>'{destination,runwayOperationalStatusVerified}'='true'),false),
       'aircraftChapterMatched',
          coalesce(bool_and(x.leg#>>'{destination,aircraftChapterNotConfigurationMatched}'='false'),false),
       'airportResearchNeedsReview',
          coalesce(bool_or(x.leg#>>'{destination,researchReview}'='true'),true),
       'anyHardTimeRuleBlock',
          coalesce(bool_or(x.leg#>>'{destination,blockedByAirportTimeRule}'='true'),false),
       'anyRunwayReview',
          coalesce(bool_or(x.leg#>>'{destination,runwayReview}'='true'),true))
   ) INTO airport_findings
   FROM jsonb_array_elements(coalesce(restrict_preview->'occurrences','[]'::jsonb)) AS x(leg);
  END IF;
  IF rotation_preview->>'gameRotationCompatible' IS DISTINCT FROM 'true' THEN
   blockers:=array_append(blockers,'AIRCRAFT_ROTATION_REQUIRES_RETURN_OR_REPOSITION');
  END IF;
  IF NOT slot_available THEN
   blockers:=array_append(blockers,'AIRPORT_WEEKLY_SLOT_CAPACITY_NOT_AVAILABLE');END IF;
  IF restrict_preview->>'weeklyTimetableChecked' IS DISTINCT FROM 'true'
    OR restrict_preview->>'gameHardBlocked' IS DISTINCT FROM 'false'
    OR restrict_preview->>'needsReview' IS DISTINCT FROM 'false'
  THEN blockers:=array_append(blockers,'AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED');END IF;
 END IF;

 roles:=CASE target.use_type
  WHEN 'passenger' THEN ARRAY['passenger']::text[]
  WHEN 'cargo' THEN ARRAY['cargo']::text[]
  WHEN 'combi' THEN ARRAY['passenger','cargo']::text[]
  ELSE ARRAY[]::text[] END;
 IF cardinality(roles)=0 THEN
  blockers:=array_append(blockers,'AIRCRAFT_GAME_SERVICE_TYPE_UNVERIFIED');END IF;
 FOREACH role_name IN ARRAY roles LOOP
  v_permission_code:=airlinerra_game.section9_game_route_licence_scope_v1(p_airline,p_origin,p_destination,game_day,28)->>'decision';
  permission_ok:=role_name='passenger' AND airlinerra_game.section9_game_route_licence_scope_v1(p_airline,p_origin,p_destination,game_day,28)->>'allowed'='true';
  IF NOT permission_ok THEN
   blockers:=array_append(blockers,
    CASE WHEN v_permission_code IS NULL
      THEN 'ROUTE_GAME_TRAFFIC_CLASSIFICATION_UNVERIFIED'
      ELSE upper(role_name)||'_GAME_TRAFFIC_RIGHTS_NOT_GRANTED' END);
  ELSE rights_granted:=rights_granted+1; END IF;
  details:=details||jsonb_build_array(jsonb_build_object(
   'serviceType',role_name,'requiredGamePermission',v_permission_code,
   'issuedGameGrantVerified',permission_ok));
 END LOOP;

 -- Operator licence remains schedule/version scoped; no candidate-only
 -- preview may assert it has been granted. Nothing is committed here.
 blockers:=array_append(blockers,
   'OPERATOR_LICENCE_AND_ATOMIC_SLOT_RESERVATION_NOT_ACTIVATED');
 RETURN jsonb_build_object(
 'status','candidate_operating_route_preflight_only',
 'worldId',1,'gameDate',game_day,
 'readOnly',true,
 'airportSlotCapacityPreviewAvailable',slot_available,
 -- The following is a GAME-only provisional suitability answer.
 -- Missing real-world runway/noise certificates do not invent a hard
 -- time/length ban, nor become an operational approval or reservation.
 'gameModelPreliminarySuitable',(
    slot_available
    AND rotation_preview->>'gameRotationCompatible'='true'
    AND coalesce((restrict_preview->>'weeklyTimetableChecked')::boolean,false)
    AND coalesce((restrict_preview->>'gameHardBlocked')::boolean,true)=false
    AND target.fleet_status='in_service'
    AND target.ownership_type IN ('owned','leased')
    AND p_origin<>p_destination
    AND cardinality(roles)>0
 ),
 'gameModelEvidenceType','GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE',
 'gameModelChecks',jsonb_build_object(
    'aircraftRotationCompatible',rotation_preview->>'gameRotationCompatible'='true',
    'weeklyRestrictionChecked',coalesce((restrict_preview->>'weeklyTimetableChecked')::boolean,false),
    'noDocumentedHardRestriction',restrict_preview IS NOT NULL
       AND coalesce((restrict_preview->>'gameHardBlocked')::boolean,true)=false,
    'airportSlotCapacityAvailable',slot_available,
    'airportDocumentationStillNeedsReview',
      coalesce((restrict_preview->>'needsReview')::boolean,true),
    'runwayStatusVerified',
      coalesce((airport_findings->'origin'->>'runwayOperationalStatusVerified')::boolean,false)
      AND coalesce((airport_findings->'destination'->>'runwayOperationalStatusVerified')::boolean,false),
    'aircraftNoiseChapterMatched',
      coalesce((airport_findings->'origin'->>'aircraftChapterMatched')::boolean,false)
      AND coalesce((airport_findings->'destination'->>'aircraftChapterMatched')::boolean,false)
 ),
 'gameModelFlightActivated',false,
 'airportSlotsReserved',false,
 'airportRestrictionGateChecked',restrict_preview IS NOT NULL,
 'requiredServiceTypes',roles,'verifiedGameTrafficGrants',rights_granted,
 'gameTrafficGrantDetails',details,
 'trafficRightsOperationallyApproved',false,
 'operatorLicenceOperationallyVerified',false,
 'operatingScheduleCreated',false,'flightActivated',false,
 'bookingEnabled',false,'passengerBookingsCreated',false,
 'ledgerPosted',false,'operationallyApproved',false,
 'airportRestrictionFindings',airport_findings,
 'aircraftRotationCandidate',rotation_preview,
  'blockers',to_jsonb(blockers));
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
   (airlinerra_game.section9_game_route_licence_scope_v1(p_airline,s.origin_airport_key,s.destination_airport_key,p_date,p_days)->>'allowed'='true' AND n.role='passenger') AS evidence_present
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
  preview:=airlinerra_game.section9_game_route_licence_scope_v1(p_airline,target.origin_airport_key,target.destination_airport_key,p_game_day,28);
  IF preview->>'allowed' IS DISTINCT FROM 'true' THEN
   blockers:=array_append(blockers,upper(role_name)||'_'||coalesce(preview->>'decision','LICENCE_SCOPE_UNAVAILABLE'));CONTINUE;
  END IF;
  IF role_name='cargo' THEN
   -- Cargo remains subject to the existing separate Licence 3 release.
   blockers:=array_append(blockers,'CARGO_COMMERCIAL_EXECUTION_NOT_RELEASED');CONTINUE;
  END IF;
  rights_details:=rights_details||jsonb_build_array(jsonb_build_object('serviceType',role_name,'gameLicenceScope',preview,'gameOnly',true));
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
-- Close obsolete paid domestic and third/fourth freedom application paths.
UPDATE airlinerra_game.section9_game_permission_issuance_policy_v1 SET release_enabled=false WHERE permission_code IN ('DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM');
UPDATE airlinerra_game.business_permission_catalog_v1 SET enabled_in_game=false,updated_at=now() WHERE permission_code IN ('DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM');
COMMIT;
