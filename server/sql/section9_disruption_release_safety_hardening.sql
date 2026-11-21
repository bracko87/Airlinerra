-- Final-release safety hardening. No activation in this migration.
-- An unflown overdue leg must not leave a tail permanently stuck.
-- Reconcile only already-departed arrivals; never backdate a missed departure.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_preceding_legs_clear_v1(p_occurrence uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
 SELECT NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 earlier
  LEFT JOIN airlinerra_game.section9_replacement_slot_pairs_v1 p ON p.occurrence_id=earlier.id
  LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 arrived
    ON arrived.flight_occurrence_id=earlier.schedule_id::text||':'||earlier.flight_local_date::text||':'||earlier.weekly_entry::text
    AND arrived.phase='arrived'
  WHERE earlier.aircraft_inventory_id=o.aircraft_inventory_id AND earlier.id<>o.id
    AND earlier.booking_status IN('open','closed')
    AND earlier.departure_utc<=o.departure_utc
    AND (arrived.actual_event_utc IS NULL OR
         arrived.actual_event_utc+make_interval(mins=>earlier.turnaround_minutes)>timing.effective_departure_utc)
 ) AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_atomic_itinerary_holds_v1 h
  LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 inbound
    ON inbound.flight_occurrence_id=h.physical_flight_ids[1] AND inbound.phase='arrived'
  LEFT JOIN airlinerra_game.section9_airport_transfer_policy_v1 transfer
    ON transfer.world_id=o.world_id AND transfer.airport_key=o.origin_airport_key
  WHERE h.status='preflight_only' AND cardinality(h.physical_flight_ids)=2
   AND h.physical_flight_ids[2]=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
   AND (inbound.actual_event_utc IS NULL OR transfer.minimum_transfer_minutes IS NULL
      OR inbound.actual_event_utc+make_interval(mins=>transfer.minimum_transfer_minutes)>timing.effective_departure_utc)
 )
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) timing
 WHERE o.id=p_occurrence;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_preceding_legs_clear_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_cancel_expired_unflown_departures_v1(p_limit integer DEFAULT 40)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE now_utc timestamptz; candidate record; response jsonb; reason text; n int:=0; failed int:=0; scanned int:=0; warnings jsonb:='{}';
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_EXPIRED_DEPARTURE_SWEEP';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_EXPIRED_DEPARTURE_LIMIT';END IF;
 IF NOT airlinerra_game.section9_automatic_disruption_ready_v1() THEN RETURN jsonb_build_object('status','expired_departure_sweep_not_released','cancelledFlights',0,'blocked',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583729,10041) THEN RETURN jsonb_build_object('status','expired_departure_sweep_busy','cancelledFlights',0,'blocked',0);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL THEN RETURN jsonb_build_object('status','expired_departure_clock_unverified','cancelledFlights',0,'blocked',0);END IF;
 FOR candidate IN
 SELECT o.id
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.version=o.schedule_version AND s.status='active' AND s.operationally_verified
 CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) timing
 WHERE o.world_id=1 AND o.booking_status='open' AND o.source_kind='game_verified_saleable_schedule_v1'
 AND now_utc>greatest(o.departure_utc+interval '240 minutes',timing.effective_departure_utc+interval '10 minutes')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text)
 ORDER BY o.departure_utc,o.id LIMIT p_limit
 LOOP
 scanned:=scanned+1;reason:=NULL;
 BEGIN
 response:=airlinerra_game.section9_cancel_with_passenger_recovery_v1(candidate.id,'maximum_delay_exceeded');
 IF response->>'cancelled'='true' THEN n:=n+1;
 ELSE reason:=coalesce(response->>'status','expiry_cancellation_failed');END IF;
 EXCEPTION WHEN OTHERS THEN reason:='expiry_transaction_'||SQLSTATE;
 END;
 IF reason IS NOT NULL THEN failed:=failed+1;warnings:=jsonb_set(warnings,ARRAY[reason],to_jsonb(coalesce((warnings->>reason)::int,0)+1),true);END IF;
 END LOOP;
 RETURN jsonb_build_object('status','expired_departure_sweep_completed','scanned',scanned,'cancelledFlights',n,'blocked',failed,'blockerCounts',warnings);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_cancel_expired_unflown_departures_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_disruption_departure_clear_v1(p_occurrence uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
 SELECT CASE WHEN NOT coalesce(r.automatic_disruption_enabled,false) THEN true
 WHEN NOT airlinerra_game.section9_automatic_disruption_ready_v1() THEN false
 ELSE
 (EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p WHERE p.occurrence_id=o.id)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_disruption_decisions_v1 d WHERE d.occurrence_id=o.id AND d.technical_delay_minutes=0))
 AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 earlier
 JOIN airlinerra_game.section9_flight_disruption_decisions_v1 d ON d.occurrence_id=earlier.id AND d.technical_delay_minutes>0
 WHERE earlier.aircraft_inventory_id=o.aircraft_inventory_id AND earlier.id<>o.id AND earlier.booking_status='open'
 AND earlier.departure_utc<=o.departure_utc
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p WHERE p.occurrence_id=earlier.id))
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_invalid_connection_holds_v1() h WHERE p_occurrence IN(h.first_occurrence,h.second_occurrence))
 AND airlinerra_game.section9_preceding_legs_clear_v1(o.id)
 END
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o LEFT JOIN airlinerra_game.section9_disruption_release_v1 r ON r.world_id=o.world_id
 WHERE o.id=p_occurrence;
$function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_disruption_cycle_v1(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE now_utc timestamptz; candidate record; h record; response jsonb; reason text;
 expiry jsonb; assessed int:=0; rotations int:=0; recovered int:=0; blocked int:=0; delayed int:=0; cancelled int:=0; warnings jsonb:='{}'::jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_AUTOMATIC_DISRUPTION_ENGINE';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_DISRUPTION_BATCH_LIMIT';END IF;
 IF NOT airlinerra_game.section9_automatic_disruption_ready_v1() THEN RETURN jsonb_build_object('status','automatic_disruptions_not_released','enabled',false);END IF;
 IF NOT pg_try_advisory_xact_lock(583729,10041) THEN RETURN jsonb_build_object('status','disruption_dispatch_busy','enabled',true);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL THEN RETURN jsonb_build_object('status','disruption_clock_unverified','enabled',true);END IF;
 expiry:=airlinerra_game.section9_cancel_expired_unflown_departures_v1(p_limit);
 cancelled:=coalesce((expiry->>'cancelledFlights')::int,0);
 blocked:=coalesce((expiry->>'blocked')::int,0);
 warnings:=coalesce(expiry->'blockerCounts','{}'::jsonb);
 -- Only assess near original departure. Previously delayed rotation legs
 -- already have a persistent disposition and must not be rerandomised.
 FOR candidate IN SELECT o.id,d.technical_delay_minutes
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.version=o.schedule_version AND s.status='active' AND s.operationally_verified
 LEFT JOIN airlinerra_game.section9_flight_disruption_decisions_v1 d ON d.occurrence_id=o.id
 WHERE o.world_id=1 AND o.booking_status='open' AND o.source_kind='game_verified_saleable_schedule_v1'
 AND o.departure_utc<=now_utc+interval '10 minutes'
 AND ((d.occurrence_id IS NULL AND o.departure_utc>=now_utc-interval '10 minutes') OR d.technical_delay_minutes>0)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p WHERE p.occurrence_id=o.id)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text)
 ORDER BY o.departure_utc,o.id LIMIT p_limit
 LOOP
  reason:=NULL;
  BEGIN
   -- Refresh after an earlier candidate's cascade.
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=candidate.id AND o.booking_status='open')
   OR EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p WHERE p.occurrence_id=candidate.id) THEN CONTINUE;END IF;
   response:=airlinerra_game.section9_assess_technical_disruption_v1(candidate.id);
   IF response->>'status' IS DISTINCT FROM 'technical_decision_recorded' THEN reason:=coalesce(response->>'status','assessment_failed');
   ELSE
    assessed:=assessed+1;
    IF (response->>'technicalDelayMinutes')::int>0 THEN
     response:=airlinerra_game.section9_reschedule_disrupted_rotation_v1(candidate.id,240);
     IF response->>'committed' IS DISTINCT FROM 'true' THEN reason:=coalesce(response->>'status','rotation_failed');
     ELSE
      IF response->>'replayed' IS DISTINCT FROM 'true' THEN
       rotations:=rotations+1;delayed:=delayed+(response->>'delayedFlights')::int;cancelled:=cancelled+(response->>'cancelledFlights')::int;
      END IF;
     END IF;
    END IF;
   END IF;
  EXCEPTION WHEN OTHERS THEN reason:='disruption_transaction_'||SQLSTATE;
  END;
  IF reason IS NOT NULL THEN blocked:=blocked+1;warnings:=jsonb_set(warnings,ARRAY[reason],to_jsonb(coalesce((warnings->>reason)::int,0)+1),true);END IF;
 END LOOP;
 FOR h IN SELECT * FROM airlinerra_game.section9_invalid_connection_holds_v1() ORDER BY allocation_key LIMIT p_limit LOOP
  reason:=NULL;
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_invalid_connection_holds_v1() x WHERE x.allocation_key=h.allocation_key) THEN CONTINUE;END IF;
   response:=airlinerra_game.section9_recover_connecting_passengers_v1(h.allocation_key,NULL,1440);
   IF response->>'recovered'='true' THEN recovered:=recovered+1;
   ELSE reason:=coalesce(response->>'status','connection_recovery_failed');END IF;
  EXCEPTION WHEN OTHERS THEN reason:='connection_transaction_'||SQLSTATE;
  END;
  IF reason IS NOT NULL THEN blocked:=blocked+1;warnings:=jsonb_set(warnings,ARRAY[reason],to_jsonb(coalesce((warnings->>reason)::int,0)+1),true);END IF;
 END LOOP;
 RETURN jsonb_build_object('status','automatic_disruption_cycle_completed','enabled',true,'assessed',assessed,'rotationsRescheduled',rotations,'delayedFlights',delayed,'cancelledFlights',cancelled,'connectionsRecovered',recovered,'expiredDepartureSweep',expiry,'blocked',blocked,'blockerCounts',warnings,'ledgerPosted',false);
END;
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
 changed integer:=0;disruption_result jsonb;
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

 disruption_result:=airlinerra_game.section9_auto_disruption_cycle_v1(p_limit);
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
   AND (phase.phase='arrived' OR airlinerra_game.section9_disruption_departure_clear_v1(o.id))
   AND (phase.event_time>now_utc-interval '10 minutes'
        OR (airlinerra_game.section9_automatic_disruption_ready_v1()
            AND phase.phase='arrived'
            AND phase.event_time>now_utc-interval '24 hours'
            AND EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 departed
              WHERE departed.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
              AND departed.phase='departed')))
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
   'disruptionCycle',disruption_result,'signingSecretExposed',false,
   'ticketRevenueRecognized',false,'ledgerPosted',false,
   'actualFuelSettlementConnected',false,'gameFuelCustodyTrackingConnected',true);
END $function$;
