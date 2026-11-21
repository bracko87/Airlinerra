-- Actual flight dispatch uses a reserved dated pair, without rewriting the immutable weekly timetable or commercial records.
ALTER TABLE airlinerra_game.section9_disruption_release_v1 ADD COLUMN IF NOT EXISTS delayed_execution_enabled boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_effective_dispatch_window_v1(p_occurrence uuid)
RETURNS TABLE(effective_departure_utc timestamptz,effective_arrival_utc timestamptz,is_delayed boolean,dispatch_allowed boolean)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
 SELECT coalesce(p.revised_departure_utc,o.departure_utc),coalesce(p.revised_arrival_utc,o.arrival_utc),
 p.occurrence_id IS NOT NULL,
 CASE WHEN p.occurrence_id IS NULL THEN true ELSE
  coalesce(r.delayed_execution_enabled,false)
  AND p.aircraft_inventory_id=o.aircraft_inventory_id
  AND p.original_departure_utc=o.departure_utc AND p.original_arrival_utc=o.arrival_utc
  AND p.available_utc=p.revised_arrival_utc+make_interval(mins=>o.turnaround_minutes)
  AND p.revised_departure_utc=date_trunc('second',p.revised_departure_utc)
  AND p.revised_arrival_utc=date_trunc('second',p.revised_arrival_utc)
  AND EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_replacement_slots_v1 z
    WHERE z.occurrence_id=o.id AND z.world_id=o.world_id AND z.direction='departure' AND z.airport_key=o.origin_airport_key AND z.movement_utc=p.revised_departure_utc AND z.stand_type=s.departure_stand_type)
  AND EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_replacement_slots_v1 z
    WHERE z.occurrence_id=o.id AND z.world_id=o.world_id AND z.direction='arrival' AND z.airport_key=o.destination_airport_key AND z.movement_utc=p.revised_arrival_utc AND z.stand_type=s.arrival_stand_type)
 END
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id
 LEFT JOIN airlinerra_game.section9_replacement_slot_pairs_v1 p ON p.occurrence_id=o.id
 LEFT JOIN airlinerra_game.section9_disruption_release_v1 r ON r.world_id=o.world_id
 WHERE o.id=p_occurrence;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_effective_dispatch_window_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_delayed_turnaround_clear_v1(p_aircraft uuid,p_occurrence uuid,p_departure timestamptz)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
 SELECT NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p
  JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=p.occurrence_id
  LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 arr ON arr.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text AND arr.phase='arrived'
  WHERE p.aircraft_inventory_id=p_aircraft AND p.occurrence_id<>p_occurrence AND o.booking_status<>'cancelled'
   AND p_departure>=p.original_departure_utc
   AND (p_departure<coalesce(arr.actual_event_utc+make_interval(mins=>o.turnaround_minutes),p.available_utc)
    OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text AND m.phase='arrived'))
 );
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_delayed_turnaround_clear_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

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
   phase.phase,phase.event_time,phase.original_event_time,
   timing.effective_departure_utc,timing.effective_arrival_utc,timing.is_delayed,
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
  CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) timing
  CROSS JOIN LATERAL(VALUES('departed'::text,timing.effective_departure_utc,o.departure_utc),
                            ('arrived'::text,timing.effective_arrival_utc,o.arrival_utc)) phase(phase,event_time,original_event_time)
  WHERE o.world_id=1
   AND o.source_kind='game_verified_saleable_schedule_v1'
   AND o.booking_status IN('open','closed')
   AND timing.dispatch_allowed
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
  IF reason IS NULL AND evt.phase='departed' AND NOT airlinerra_game.section9_delayed_turnaround_clear_v1(evt.aircraft_inventory_id,evt.occurrence_id,evt.event_time) THEN
   reason:='DELAYED_AIRCRAFT_TURNAROUND_NOT_COMPLETE';END IF;
  IF reason IS NULL AND evt.phase='departed' THEN
   maintenance:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
      evt.owner_player_id,evt.airline_id,evt.aircraft_inventory_id,
      evt.effective_departure_utc,evt.effective_arrival_utc);
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
     (evt.original_event_time AT TIME ZONE 'UTC')::date);
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
     AND (c.value->>'scheduledEventUtc')::timestamptz=evt.original_event_time
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

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 proof jsonb;hour_proof jsonb;
 flight record;state record;model record;
 pos jsonb;auto_source text;
 event_id text;expected_qty numeric(14,3);
 prior_qty numeric(14,3):=0;
 add_qty numeric(14,3);
 supplied int;updated int;current_game_date date;
 v_enabled boolean; relocation record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_GAME_ONLY_AUTOFUEL_TRUSTED_ENGINE_ONLY';END IF;
 IF p_physical_flight_id IS NULL
  OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_AUTO_FUEL_INVALID_PHYSICAL_FLIGHT_ID';END IF;
 -- Cannot allocate game fuel while World 1 operations are paused.
 SELECT (a.release_state='enabled' AND a.enabled_at IS NOT NULL
  AND a.crew_mode='deferred_phase1'
  AND e.release_state='enabled' AND e.enabled_at IS NOT NULL) INTO v_enabled
 FROM airlinerra_game.section9_activation_release_policy_v1 a
 JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e
 ON e.world_id=a.world_id WHERE a.world_id=1;
 IF v_enabled IS DISTINCT FROM true THEN
 RETURN jsonb_build_object('status','blocked_game_fuel_auto_supply_unreleased',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT o.airline_id,o.aircraft_inventory_id,o.origin_airport_key,
  CASE WHEN timing.dispatch_allowed THEN timing.effective_departure_utc ELSE NULL END AS departure_utc,o.flight_local_date,o.booking_status,o.source_kind,
  s.configuration_id,s.operationally_verified,s.status AS schedule_status,
  a.owner_player_id
 INTO flight
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
 ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.airlines a ON a.id=o.airline_id AND a.world_id=1
 CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) timing
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
  AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
  AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::integer
  AND o.world_id=1;
 IF NOT FOUND THEN
  SELECT * INTO relocation FROM airlinerra_game.section9_relocation_leg_evidence_v1(p_physical_flight_id);
  IF NOT FOUND OR relocation.departure_utc>(hour_proof->>'gameHourUtc')::timestamptz+interval '7 days' OR relocation.departure_utc<=(hour_proof->>'gameHourUtc')::timestamptz-interval '10 minutes' THEN RETURN jsonb_build_object('status','blocked_nonoperating_or_out_of_window_flight','gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
  SELECT relocation.airline_id AS airline_id,relocation.aircraft_inventory_id AS aircraft_inventory_id,relocation.origin_airport_key AS origin_airport_key,relocation.configuration_id AS configuration_id,relocation.owner_player_id AS owner_player_id INTO flight;
 ELSE
 IF flight.operationally_verified IS DISTINCT FROM true
 OR flight.schedule_status IS DISTINCT FROM 'active'
 OR flight.booking_status IS DISTINCT FROM 'open'
 OR flight.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
 OR flight.departure_utc IS NULL
 OR flight.departure_utc>(hour_proof->>'gameHourUtc')::timestamptz+interval '7 days'
 OR flight.departure_utc<=(hour_proof->>'gameHourUtc')::timestamptz-interval '10 minutes'
 THEN RETURN jsonb_build_object('status','blocked_nonoperating_or_out_of_window_flight',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 END IF;

 IF NOT pg_catalog.pg_try_advisory_xact_lock(
     583731,pg_catalog.hashtext(flight.aircraft_inventory_id::text))
 THEN RETURN jsonb_build_object('status','game_auto_fuel_aircraft_busy',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id);
 IF proof->>'status'='verified_game_fuel_onboard_available_for_planned_trip'
 AND proof->>'fuelVerifiedForGame'='true'
 THEN RETURN jsonb_build_object('status','game_fuel_already_sufficient',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF proof->>'status' NOT IN (
  'blocked_missing_verified_aircraft_fuel_onboard',
  'blocked_insufficient_aircraft_fuel_including_reserve'
 ) THEN RETURN jsonb_build_object('status','blocked_game_fuel_preflight_evidence',
  'preflightStatus',proof->>'status',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 IF proof->>'airportFuelServiceListed' IS DISTINCT FROM 'true' THEN
 RETURN jsonb_build_object('status','blocked_no_game_airport_fuel_service',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT * INTO model FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=flight.configuration_id;
 IF NOT FOUND OR model.game_calculation_ready IS DISTINCT FROM true
 OR model.fuel_game_family IS NULL OR model.tank_capacity_kg<=0
 THEN RETURN jsonb_build_object('status','blocked_incomplete_game_fuel_model',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 expected_qty:=(proof->>'minimumPlannedFuelOnBoardKg')::numeric(14,3);
 IF expected_qty IS NULL OR expected_qty<=0
 OR expected_qty>model.tank_capacity_kg
 THEN RETURN jsonb_build_object('status','blocked_game_fuel_minimum_exceeds_tank',
  'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;

 -- Starting custody may ONLY be created at the authoritative game
 -- starter airport. Once signed arrivals exist, all future refuelling
 -- must use the fuel custody location, not the player's home airport.
 SELECT * INTO state FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1
 WHERE aircraft_inventory_id=flight.aircraft_inventory_id
 AND airline_id=flight.airline_id FOR UPDATE;
 IF NOT FOUND THEN
   current_game_date:=((hour_proof->>'gameHourUtc')::timestamptz
    AT TIME ZONE 'Europe/Berlin')::date;
   pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
     flight.owner_player_id,flight.airline_id,
     flight.aircraft_inventory_id,current_game_date);
   IF pos->>'verified' IS DISTINCT FROM 'true'
    OR pos->>'atGroundAirport' IS DISTINCT FROM 'true'
    OR pos->>'airportKey' IS DISTINCT FROM flight.origin_airport_key
    OR pos->>'status' IS DISTINCT FROM 'verified_original_game_starter_position'
   THEN RETURN jsonb_build_object('status','blocked_unverified_aircraft_fuel_starter_location',
     'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 ELSE
   prior_qty:=state.onboard_kg;
   IF state.at_airport_key IS DISTINCT FROM flight.origin_airport_key
    OR state.fuel_game_family IS DISTINCT FROM model.fuel_game_family
    OR state.configuration_id IS DISTINCT FROM flight.configuration_id
   THEN RETURN jsonb_build_object('status','blocked_fuel_custody_not_at_departure',
    'gameFuelAddedKg',0,'chargedNow',false,'ledgerPosted',false);END IF;
 END IF;
 add_qty:=expected_qty-prior_qty;
 IF add_qty<=0 THEN
 RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='SECTION9_AUTOFUEL_NONPOSITIVE_TOPUP_WITH_UNVERIFIED_CUSTODY';END IF;

 -- A game-only airport supplier receipt. This is NOT proof that the
 -- actual aircraft's installed engines or real fuel grade were certified.
 auto_source:='GAME_ONLY_AUTO_FUEL_SERVICE_V1_'||flight.origin_airport_key;
 event_id:='game-auto-fuel-v1-'||md5(p_physical_flight_id);
 INSERT INTO airlinerra_game.section9_game_approved_fuel_load_receipts_v1(
  source_event_id,airline_id,aircraft_inventory_id,at_airport_key,
  fuel_family,load_added_kg,fuel_after_load_kg,
  game_hour_utc,game_supplier_reference,source_status
 ) VALUES(event_id,flight.airline_id,flight.aircraft_inventory_id,
  flight.origin_airport_key,model.fuel_game_family,add_qty,expected_qty,
  (hour_proof->>'gameHourUtc')::timestamptz,
  auto_source,'game_authority_approved');
 GET DIAGNOSTICS supplied=ROW_COUNT;
 IF supplied<>1 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_DUPLICATE_GAME_FUEL_AUTO_SUPPLY_EVENT';END IF;
 IF state.aircraft_inventory_id IS NULL THEN
  INSERT INTO airlinerra_game.section9_aircraft_game_fuel_custody_v1(
   aircraft_inventory_id,airline_id,configuration_id,at_airport_key,
   fuel_game_family,onboard_kg,source_event_id,source_event_kind,
   evidence_reference,game_hour_utc,revision
  ) VALUES(flight.aircraft_inventory_id,flight.airline_id,
   flight.configuration_id,flight.origin_airport_key,
   model.fuel_game_family,expected_qty,event_id,'approved_game_fuel_load',
   auto_source,(hour_proof->>'gameHourUtc')::timestamptz,1);
 ELSE
  UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1
  SET onboard_kg=expected_qty,
   source_event_id=event_id,source_event_kind='approved_game_fuel_load',
   evidence_reference=auto_source,
   game_hour_utc=(hour_proof->>'gameHourUtc')::timestamptz,
   revision=revision+1,recorded_at=clock_timestamp()
  WHERE aircraft_inventory_id=flight.aircraft_inventory_id
  AND airline_id=flight.airline_id AND revision=state.revision;
  GET DIAGNOSTICS updated=ROW_COUNT;
  IF updated<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_GAME_FUEL_TOPUP_CONCURRENT_CONFLICT';END IF;
 END IF;
 proof:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_physical_flight_id);
 IF proof->>'status' IS DISTINCT FROM
   'verified_game_fuel_onboard_available_for_planned_trip'
 OR proof->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_GAME_AUTO_FUEL_NOT_VERIFIED_ROLLBACK';END IF;
 RETURN jsonb_build_object(
   'status','game_only_auto_fuel_supply_recorded',
   'physicalFlightId',p_physical_flight_id,
   'fuelTopUpKg',add_qty,'fuelOnBoardKg',expected_qty,
   'gameFuelFamily',model.fuel_game_family,
   'gameSupplySource',auto_source,
   'fuelVerifiedForGame',true,
   'realWorldFuelGradeCertified',false,
   'chargedNow',false,'ledgerPosted',false,
   'gameFuelSupplierEventCreated',true);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_record_signed_operated_flight_movement_v1(p_airline uuid, p_schedule uuid, p_schedule_version integer, p_local_date date, p_weekly_entry integer, p_phase text, p_event_utc timestamp with time zone, p_event_id text, p_verified_hmac text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE world_state record;clock_row record;s record;
 hour_proof jsonb;activation_guard record;execution_guard record;engine_guard record;
 capacity record;origin_tz text; weekly_item jsonb;
 local_departure timestamp; scheduled_dep timestamptz;
 scheduled_arr timestamptz; occurrence text;
 fleet record; anchor record;pos record; existing record;
 position_exists boolean:=false; resolution jsonb;starter jsonb;
 timing record; dated_id uuid; dated_status text;
 change_count int; v_signer_secret text; v_expected_sig text; v_signing_payload text;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL
  OR p_schedule_version IS NULL OR p_schedule_version<1
  OR p_local_date IS NULL OR p_local_date NOT BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-31'
  OR p_weekly_entry IS NULL OR p_weekly_entry NOT BETWEEN 1 AND 7
  OR p_phase IS NULL OR p_phase NOT IN ('departed','arrived')
  OR p_event_utc IS NULL
  OR (p_event_utc AT TIME ZONE 'UTC')::date NOT BETWEEN
      DATE '2000-01-01' AND DATE '2199-12-31'
  OR length(coalesce(p_event_id,'')) NOT BETWEEN 12 AND 128
  OR coalesce(p_event_id,'') !~ '^[A-Za-z0-9._:-]+$'
  OR coalesce(p_verified_hmac,'') !~ '^[a-f0-9]{64}$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATED_FLIGHT_ENGINE_EVENT';END IF;
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_TRUSTED_MOVEMENT_ENGINE_ONLY';END IF;
 -- Require the exact canonical HMAC of this game event, not merely
 -- a 64-character hex string. Only the trusted game scheduler has
 -- access to the encrypted signing secret.
 IF date_trunc('second',p_event_utc) IS DISTINCT FROM p_event_utc THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_MOVEMENT_TIME_MUST_BE_EXACT_SECOND';END IF;
 SELECT decrypted_secret INTO v_signer_secret FROM vault.decrypted_secrets
 WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF v_signer_secret IS NULL OR length(v_signer_secret)<64 THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_MOVEMENT_SIGNING_KEY_MISSING';END IF;
 v_signing_payload:=concat_ws(E'\n',
  'airlinerra-operated-game-event-v1','1',p_airline::text,
  p_schedule::text,p_schedule_version::text,p_local_date::text,
  p_weekly_entry::text,p_phase,
  to_char(p_event_utc AT TIME ZONE 'UTC',
   'YYYY-MM-DD"T"HH24:MI:SS"Z"'),p_event_id);
 v_expected_sig:=encode(extensions.hmac(
  pg_catalog.convert_to(v_signing_payload,'UTF8'),
  pg_catalog.convert_to(v_signer_secret,'UTF8'),
  'sha256'),'hex');
 IF v_expected_sig IS DISTINCT FROM p_verified_hmac THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_MOVEMENT_EVENT_SIGNATURE_INVALID';END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR p_event_utc>(hour_proof->>'gameHourUtc')::timestamptz+interval '2 seconds' THEN
  RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'movementRecorded',false,'ledgerPosted',false,'bookingsCreated',false,
  'flightActivated',false);END IF;
 SELECT release_state,enabled_at INTO activation_guard
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_guard
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO engine_guard
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation_guard.release_state IS DISTINCT FROM 'enabled'
 OR activation_guard.enabled_at IS NULL
 OR execution_guard.release_state IS DISTINCT FROM 'enabled'
 OR execution_guard.enabled_at IS NULL
 OR engine_guard.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine_guard.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine_guard.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_unreleased_movement_engine',
   'movementRecorded',false,'ledgerPosted',false,'bookingsCreated',false,
   'flightActivated',false);END IF;
 -- Signed proof cannot turn a future scheduled event into an early movement.
 IF p_event_utc>clock_timestamp()+interval '2 seconds' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUTURE_OPERATED_MOVEMENT_FORBIDDEN';
 END IF;
 SELECT state,opens_at INTO world_state
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 IF world_state.state IS DISTINCT FROM 'active'
  OR world_state.opens_at IS NULL
  OR world_state.opens_at>clock_timestamp() THEN
  RETURN jsonb_build_object('status','blocked_world_not_open',
   'movementRecorded',false,'bookingsCreated',false,
   'ledgerPosted',false,'flightActivated',false);
 END IF;
 SELECT * INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock_row.confirmed_game_date IS NULL
  OR clock_row.last_verified_at IS NULL
  OR length(coalesce(clock_row.engine_proof_ref,''))<12
  OR clock_row.confirmed_game_date<
      (p_event_utc AT TIME ZONE 'UTC')::date
  OR clock_row.confirmed_game_date<p_local_date
  OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 t
   WHERE t.world_id=1
    AND t.game_date=(p_event_utc AT TIME ZONE 'UTC')::date)
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_clock',
   'movementRecorded',false,'bookingsCreated',false,
   'ledgerPosted',false,'flightActivated',false);
 END IF;

 SELECT d.id,d.airline_id,d.aircraft_inventory_id,d.configuration_id,
  d.version,d.status,d.operationally_verified,d.weekly_schedule,
  d.origin_airport_key,d.destination_airport_key,
  d.reference_departure_utc,d.reference_arrival_utc,
  f.fleet_status,f.configuration_id AS fleet_configuration
 INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=d.aircraft_inventory_id AND f.airline_id=d.airline_id
 WHERE d.world_id=1 AND d.airline_id=p_airline AND d.id=p_schedule
 FOR SHARE OF d;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_FLIGHT_SCHEDULE_NOT_REGISTERED';END IF;
 IF s.version IS DISTINCT FROM p_schedule_version
  OR s.status<>'active' OR s.operationally_verified IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_schedule_not_operational',
   'movementRecorded',false,'bookingsCreated',false,
   'ledgerPosted',false,'flightActivated',false);
 END IF;
 IF s.fleet_status<>'in_service'
  OR s.fleet_configuration IS DISTINCT FROM s.configuration_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_NOT_IN_SERVICE';END IF;
 SELECT cap.schedule_id,cap.verification_source INTO capacity
 FROM airlinerra_game.section9_verified_schedule_capacity_v1 cap
 WHERE cap.schedule_id=p_schedule AND cap.airline_id=p_airline
  AND cap.schedule_version=p_schedule_version FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_FLIGHT_CAPACITY_NOT_VERIFIED';END IF;
 IF p_weekly_entry>jsonb_array_length(s.weekly_schedule) THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_OPERATED_WEEKLY_ENTRY_MISSING';END IF;
 weekly_item:=s.weekly_schedule->(p_weekly_entry-1);
 IF jsonb_typeof(weekly_item)<>'object'
  OR coalesce(weekly_item->>'day','')!~'^[0-6]$'
  OR coalesce(weekly_item->>'time','')!~
      '^([01][0-9]|2[0-3]):[0-5][0-9]$'
  OR (weekly_item->>'day')::int<>extract(isodow FROM p_local_date)::int-1
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_OPERATED_WEEKLY_TIMETABLE_INVALID';END IF;
 SELECT tz.timezone_iana INTO origin_tz
 FROM airlinerra_game.airport_reference_profiles tz
 JOIN pg_catalog.pg_timezone_names names
  ON names.name=tz.timezone_iana
 WHERE tz.world_id=1 AND tz.airport_key=s.origin_airport_key;
 IF origin_tz IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_ORIGIN_TIMEZONE_UNVERIFIED';END IF;
 local_departure:=p_local_date+
  (weekly_item->>'time')::time;
 scheduled_dep:=local_departure AT TIME ZONE origin_tz;
 scheduled_arr:=scheduled_dep+
  (s.reference_arrival_utc-s.reference_departure_utc);
 IF (scheduled_dep AT TIME ZONE origin_tz) IS DISTINCT FROM local_departure
  OR EXISTS(
    SELECT 1 FROM generate_series(-12,12) AS alternative(offset_15m)
    WHERE alternative.offset_15m<>0
      AND ((scheduled_dep+
        make_interval(mins=>alternative.offset_15m*15))
        AT TIME ZONE origin_tz)=local_departure)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_LOCAL_TIME_AMBIGUOUS_OR_NONEXISTENT';END IF;
 -- Provisional GAME event-time envelope, not an airline delay certificate.
 IF (p_phase='departed' AND (
    p_event_utc<scheduled_dep-interval '2 hours'
    OR p_event_utc>scheduled_dep+interval '24 hours'))
  OR (p_phase='arrived' AND (
    p_event_utc<scheduled_dep
    OR p_event_utc>scheduled_arr+interval '48 hours'))
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_OPERATED_EVENT_OUTSIDE_SCHEDULE_WINDOW';END IF;
 occurrence:=p_schedule::text||':'||p_local_date::text||':'||
  p_weekly_entry::text;

 -- Serialize all physical movement updates by aircraft, even if two
 -- independent schedules or concurrent workers try to depart together.
 SELECT id INTO fleet FROM airlinerra_game.airline_aircraft_inventory
 WHERE id=s.aircraft_inventory_id AND airline_id=p_airline
 AND fleet_status='in_service' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_NO_LONGER_AVAILABLE';END IF;

 -- Exact event retries are stable even after another event (e.g. arrival).
 SELECT * INTO existing
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.engine_event_id=p_event_id OR
  (m.flight_occurrence_id=occurrence AND m.phase=p_phase)
 ORDER BY (m.engine_event_id=p_event_id) DESC LIMIT 1;
 IF FOUND THEN
  IF existing.engine_event_id IS DISTINCT FROM p_event_id OR
   existing.event_hmac_sha256 IS DISTINCT FROM p_verified_hmac OR
   existing.airline_id IS DISTINCT FROM p_airline OR
   existing.schedule_id IS DISTINCT FROM p_schedule OR
   existing.schedule_version IS DISTINCT FROM p_schedule_version OR
   existing.weekly_entry IS DISTINCT FROM p_weekly_entry OR
   existing.flight_local_date IS DISTINCT FROM p_local_date OR
   existing.phase IS DISTINCT FROM p_phase OR
   existing.actual_event_utc IS DISTINCT FROM p_event_utc
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_OPERATED_EVENT_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object('status','operated_movement_replayed',
   'flightOccurrenceId',occurrence,'phase',p_phase,
   'movementRecorded',false,'replayed',true,
   'bookingsCreated',false,'ledgerPosted',false,
   'flightActivated',false);
 END IF;

 -- A delayed dated occurrence has an exact authorised time, while its
 -- original timetable remains the immutable signed schedule identity.
 SELECT o.id,o.booking_status INTO dated_id,dated_status
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.schedule_id=p_schedule AND o.schedule_version=p_schedule_version
 AND o.flight_local_date=p_local_date AND o.weekly_entry=p_weekly_entry AND o.airline_id=p_airline;
 IF FOUND THEN
  IF dated_status='cancelled' THEN RAISE EXCEPTION 'SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN';END IF;
  SELECT * INTO timing FROM airlinerra_game.section9_effective_dispatch_window_v1(dated_id);
  IF timing.is_delayed AND (NOT timing.dispatch_allowed OR p_event_utc IS DISTINCT FROM
    CASE WHEN p_phase='departed' THEN timing.effective_departure_utc ELSE timing.effective_arrival_utc END)
  THEN RAISE EXCEPTION 'SECTION9_REPLACEMENT_MOVEMENT_TIME_NOT_AUTHORIZED';END IF;
  IF p_phase='departed' AND NOT airlinerra_game.section9_delayed_turnaround_clear_v1(s.aircraft_inventory_id,dated_id,p_event_utc)
  THEN RAISE EXCEPTION 'SECTION9_DELAYED_TURNAROUND_INCOMPLETE';END IF;
 END IF;

 SELECT delivery_anchor.airport_key,delivery_anchor.anchored_game_date,
  source.order_status,inspection.inspection_status,
  source.registration AS order_registration,
  source.configuration_id AS order_configuration,
  i.registration AS fleet_registration
 INTO anchor
 FROM airlinerra_game.section9_aircraft_delivery_position_v1 delivery_anchor
 JOIN airlinerra_game.aircraft_acquisition_orders_v1 source
  ON source.order_id=delivery_anchor.acquisition_order_id
   AND source.airline_id=delivery_anchor.airline_id
   AND source.aircraft_inventory_id=delivery_anchor.aircraft_inventory_id
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 inspection
  ON inspection.inspection_id=delivery_anchor.inspection_id
   AND inspection.order_id=source.order_id
   AND inspection.inspection_status='approved'
   AND inspection.reviewed_at=delivery_anchor.inspection_reviewed_at
   AND inspection.reviewer_reference=delivery_anchor.reviewer_reference
 JOIN airlinerra_game.airline_aircraft_inventory i
  ON i.id=delivery_anchor.aircraft_inventory_id AND i.airline_id=delivery_anchor.airline_id
 WHERE delivery_anchor.aircraft_inventory_id=s.aircraft_inventory_id
  AND delivery_anchor.airline_id=p_airline
  AND delivery_anchor.anchored_game_date<=
   (p_event_utc AT TIME ZONE 'UTC')::date
  AND source.delivery_home_airport_key=delivery_anchor.airport_key
  AND source.order_status='delivered_pending_inspection';
 IF NOT FOUND THEN
  starter:=airlinerra_game.section9_starter_origin_evidence_v1(
   p_airline,s.aircraft_inventory_id,
   (p_event_utc AT TIME ZONE 'Europe/Berlin')::date);
  IF starter->>'verified' IS DISTINCT FROM 'true' THEN
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_OPERATED_AIRCRAFT_INITIAL_POSITION_UNVERIFIED';
  END IF;
  anchor.airport_key:=starter->>'airportKey';
 ELSIF anchor.order_registration IS DISTINCT FROM anchor.fleet_registration
  OR anchor.order_configuration IS DISTINCT FROM s.configuration_id
 THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_AIRCRAFT_DELIVERY_ANCHOR_UNVERIFIED';
 END IF;
 SELECT * INTO pos
 FROM airlinerra_game.section9_aircraft_current_position_v1
 WHERE aircraft_inventory_id=s.aircraft_inventory_id FOR UPDATE;
 position_exists:=FOUND;
 IF position_exists AND pos.airline_id IS DISTINCT FROM p_airline THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_AIRCRAFT_POSITION_AIRLINE_CHANGED';END IF;
 IF p_phase='arrived' AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
  WHERE m.flight_occurrence_id=occurrence AND m.phase='departed'
   AND m.aircraft_inventory_id=s.aircraft_inventory_id)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_ARRIVAL_WITHOUT_DEPARTURE_EVENT';END IF;
 resolution:=airlinerra_game.section9_aircraft_movement_decision_v1(
  p_phase,
  CASE WHEN position_exists THEN pos.location_status ELSE 'grounded' END,
  CASE WHEN position_exists THEN pos.airport_key ELSE anchor.airport_key END,
  CASE WHEN position_exists THEN pos.current_flight_occurrence_id ELSE NULL END,
  CASE WHEN position_exists THEN pos.last_event_utc ELSE NULL END,
  CASE WHEN position_exists THEN pos.last_departure_utc ELSE NULL END,
  s.origin_airport_key,s.destination_airport_key,occurrence,p_event_utc
 );
 IF resolution->>'allowed'<>'true' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_'||resolution->>'reason';END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(
  world_id,engine_event_id,event_hmac_sha256,
  airline_id,aircraft_inventory_id,schedule_id,schedule_version,
  weekly_entry,flight_local_date,flight_occurrence_id,phase,
  origin_airport_key,destination_airport_key,
  scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,p_event_id,p_verified_hmac,p_airline,s.aircraft_inventory_id,
  p_schedule,p_schedule_version,p_weekly_entry,p_local_date,
  occurrence,p_phase,s.origin_airport_key,s.destination_airport_key,
  scheduled_dep,scheduled_arr,p_event_utc);
 INSERT INTO airlinerra_game.section9_aircraft_current_position_v1(
  aircraft_inventory_id,world_id,airline_id,
  location_status,airport_key,current_flight_occurrence_id,
  last_event_utc,last_departure_utc,last_arrival_utc,
  last_engine_event_id)
 VALUES(s.aircraft_inventory_id,1,p_airline,
  resolution->>'newState',resolution->>'newAirport',
  CASE WHEN p_phase='departed' THEN occurrence ELSE NULL END,
  p_event_utc,
  CASE WHEN p_phase='departed' THEN p_event_utc ELSE pos.last_departure_utc END,
  CASE WHEN p_phase='arrived' THEN p_event_utc
       ELSE pos.last_arrival_utc END,
  p_event_id)
 ON CONFLICT(aircraft_inventory_id) DO UPDATE SET
  location_status=excluded.location_status,
  airport_key=excluded.airport_key,
  current_flight_occurrence_id=excluded.current_flight_occurrence_id,
  last_event_utc=excluded.last_event_utc,
  last_departure_utc=excluded.last_departure_utc,
  last_arrival_utc=excluded.last_arrival_utc,
  last_engine_event_id=excluded.last_engine_event_id,
  updated_at=clock_timestamp()
 WHERE airlinerra_game.section9_aircraft_current_position_v1.airline_id=
  excluded.airline_id;
 GET DIAGNOSTICS change_count=ROW_COUNT;
 IF change_count<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_POSITION_WRITE_CONFLICT';END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN p_phase='departed' THEN
    'operated_flight_departure_recorded' ELSE
    'operated_flight_arrival_recorded' END,
  'flightOccurrenceId',occurrence,'phase',p_phase,
  'aircraftInventoryId',s.aircraft_inventory_id,
  'locationStatus',resolution->>'newState',
  'lastVerifiedAirport',resolution->>'newAirport',
  'movementRecorded',true,'replayed',false,
  'bookingsCreated',false,'ledgerPosted',false,
  'flightActivated',false,'canActivateNormalFlight',false);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reserve_replacement_slot_pair_v1(p_occurrence uuid, p_max_delay_minutes integer DEFAULT 240)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE o record; existing record; planned jsonb; d timestamptz; a timestamptz; ready timestamptz; now_utc timestamptz; physical text; n integer; technical integer;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_REPLACEMENT_RESERVATION';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_disruption_release_v1 WHERE world_id=1 AND replacement_reservation_enabled) THEN
  RETURN jsonb_build_object('status','replacement_reservation_not_released','reserved',false);
 END IF;
 IF p_max_delay_minutes IS NULL OR p_max_delay_minutes NOT BETWEEN 1 AND 720 THEN RAISE EXCEPTION 'INVALID_REPLACEMENT_DELAY_LIMIT';END IF;
 -- Same lock as dispatch prevents a reservation from racing a selected movement.
 IF NOT pg_try_advisory_xact_lock(583729,10041) THEN RETURN jsonb_build_object('status','replacement_dispatch_busy','reserved',false);END IF;
 SELECT x.*,s.configuration_id,s.departure_stand_type,s.arrival_stand_type
 INTO o FROM airlinerra_game.section9_dated_flight_occurrences_v1 x
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=x.schedule_id AND s.airline_id=x.airline_id AND s.aircraft_inventory_id=x.aircraft_inventory_id AND s.version=x.schedule_version
 WHERE x.id=p_occurrence AND x.world_id=1 AND x.booking_status='open' AND x.source_kind='game_verified_saleable_schedule_v1' AND s.status='active' AND s.operationally_verified
 FOR UPDATE OF x;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','replacement_occurrence_unavailable','reserved',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=o.aircraft_inventory_id FOR UPDATE;
 physical:=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=physical)
 THEN RETURN jsonb_build_object('status','flight_already_operated','reserved',false);END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=p_occurrence;
 IF FOUND THEN RETURN jsonb_build_object('status','replacement_pair_already_reserved','reserved',true,'replayed',true,'departureUtc',existing.revised_departure_utc,'arrivalUtc',existing.revised_arrival_utc,'availableUtc',existing.available_utc);END IF;
 SELECT technical_delay_minutes INTO technical FROM airlinerra_game.section9_flight_disruption_decisions_v1 WHERE occurrence_id=p_occurrence AND physical_flight_id=physical;
 IF technical IS NULL OR technical<=0 THEN RETURN jsonb_build_object('status','positive_technical_delay_required','reserved',false);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR now_utc<o.departure_utc-interval '10 minutes' OR now_utc>o.departure_utc+make_interval(mins=>p_max_delay_minutes)
 THEN RETURN jsonb_build_object('status','replacement_outside_window','reserved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c WHERE c.world_id=o.world_id
 AND c.airport_key IN(o.origin_airport_key,o.destination_airport_key) ORDER BY c.airport_key FOR UPDATE;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>2 THEN RETURN jsonb_build_object('status','replacement_airport_capacity_missing','reserved',false);END IF;
 planned:=airlinerra_game.section9_preview_replacement_slot_pair_v1(o.world_id,o.origin_airport_key,o.destination_airport_key,o.configuration_id,o.departure_stand_type,o.arrival_stand_type,o.departure_utc,o.arrival_utc,greatest(date_trunc('second',now_utc)+interval '1 second',o.departure_utc+make_interval(mins=>technical)),o.turnaround_minutes,p_max_delay_minutes);
 IF planned->>'status'<>'replacement_slot_pair_preview' THEN RETURN planned||jsonb_build_object('reserved',false);END IF;
 d:=(planned->>'departureUtc')::timestamptz;a:=(planned->>'arrivalUtc')::timestamptz;ready:=(planned->>'availableUtc')::timestamptz;
 -- Do not allow a reservation to overlap another dated aircraft assignment.
 -- Consequentially delayed legs require the later atomic rotation integration.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 x LEFT JOIN airlinerra_game.section9_replacement_slot_pairs_v1 p ON p.occurrence_id=x.id
 WHERE x.aircraft_inventory_id=o.aircraft_inventory_id AND x.id<>o.id AND x.booking_status IN('open','closed')
 AND tstzrange(coalesce(p.revised_departure_utc,x.departure_utc),coalesce(p.available_utc,x.arrival_utc+make_interval(mins=>x.turnaround_minutes)),'[)') && tstzrange(d,ready,'[)'))
 THEN RETURN jsonb_build_object('status','replacement_requires_rotation_replan','reserved',false);END IF;
 INSERT INTO airlinerra_game.section9_replacement_slot_pairs_v1(occurrence_id,world_id,aircraft_inventory_id,original_departure_utc,original_arrival_utc,revised_departure_utc,revised_arrival_utc,available_utc)
 VALUES(o.id,o.world_id,o.aircraft_inventory_id,o.departure_utc,o.arrival_utc,d,a,ready);
 INSERT INTO airlinerra_game.section9_dated_replacement_slots_v1(occurrence_id,world_id,airport_key,stand_type,direction,movement_utc,local_date,weekday,minute_of_day)
 SELECT o.id,o.world_id,m.airport_key,m.stand_type,m.direction,m.movement_utc,z.local_dt::date,(extract(isodow FROM z.local_dt)::int-1)::smallint,(extract(hour FROM z.local_dt)::int*60+(extract(minute FROM z.local_dt)::int/10)*10)::smallint
 FROM (VALUES(o.origin_airport_key,o.departure_stand_type,'departure',d),(o.destination_airport_key,o.arrival_stand_type,'arrival',a)) m(airport_key,stand_type,direction,movement_utc)
 JOIN airlinerra_game.section5_airport_operating_policy_v1 pol ON pol.world_id=o.world_id AND pol.airport_key=m.airport_key
 CROSS JOIN LATERAL(SELECT m.movement_utc AT TIME ZONE pol.timezone_iana AS local_dt) z;
 GET DIAGNOSTICS n=ROW_COUNT;
 IF n<>2 THEN RAISE EXCEPTION 'REPLACEMENT_PAIR_NOT_ATOMIC';END IF;
 RETURN planned||jsonb_build_object('status','replacement_pair_reserved','reserved',true,'replayed',false,'readOnly',false,'slotsReserved',true);
END;
$function$;
