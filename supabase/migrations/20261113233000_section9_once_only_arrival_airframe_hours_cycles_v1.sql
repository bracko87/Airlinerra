-- Exactly-once signed ARRIVAL increments aircraft flight hours and cycles.
-- This is additional to (not a replacement for) the signed movement receipt
-- and requires both matching departure and arrival movement events.
-- The UNIQUE physical-flight receipt protects against retries.
-- It never changes aircraft condition or claims real-world airworthiness.
-- The dispatcher calls this in the SAME transaction as arrival.
-- Any failed usage receipt rolls back the arrival and aircraft position.
-- No revenue, costs, bookings or other ledger charges are posted here.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(
 physical_flight_id text PRIMARY KEY,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL
   REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 arrived_engine_event_id text NOT NULL UNIQUE
   REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 departed_engine_event_id text NOT NULL
   REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 elapsed_flight_hours numeric(10,3) NOT NULL
   CHECK (elapsed_flight_hours>0 AND elapsed_flight_hours<=72),
 flight_cycles integer NOT NULL DEFAULT 1 CHECK(flight_cycles=1),
 processed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 source_kind text NOT NULL DEFAULT 'signed_operated_game_arrival_usage_v1'
   CHECK(source_kind='signed_operated_game_arrival_usage_v1'),
 CONSTRAINT section9_arrived_usage_flight_id_format_v1
  CHECK(physical_flight_id ~
   '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$')
);
ALTER TABLE airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 departure record;arrival record;state_row record;existing record;
 hours_to_add numeric(10,3);
 affected integer:=0;
 hour_proof jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_AIRFRAME_USAGE_ENGINE_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR length(p_physical_flight_id)<40
  OR length(p_physical_flight_id)>140
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_FLIGHT_USAGE_ID';END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_airframe_game_hour',
  'usageApplied',false,'ledgerPosted',false);END IF;

 SELECT * INTO arrival FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='arrived';
 SELECT * INTO departure FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='departed';
 IF arrival.engine_event_id IS NULL OR departure.engine_event_id IS NULL
 OR arrival.world_id<>1 OR departure.world_id<>1
 OR arrival.source_kind<>'signed_operated_game_flight_v1'
 OR departure.source_kind<>'signed_operated_game_flight_v1'
 OR arrival.airline_id IS DISTINCT FROM departure.airline_id
 OR arrival.aircraft_inventory_id IS DISTINCT FROM departure.aircraft_inventory_id
 OR arrival.schedule_id IS DISTINCT FROM departure.schedule_id
 OR arrival.schedule_version IS DISTINCT FROM departure.schedule_version
 OR arrival.actual_event_utc<=departure.actual_event_utc
 OR arrival.actual_event_utc>(hour_proof->>'gameHourUtc')::timestamptz
 OR arrival.actual_event_utc>departure.actual_event_utc+interval '72 hours'
 THEN RETURN jsonb_build_object('status','blocked_unverified_arrival_and_departure',
  'usageApplied',false,'ledgerPosted',false);END IF;
 hours_to_add:=round(
  extract(epoch FROM(arrival.actual_event_utc-departure.actual_event_utc))/3600,3);
 IF hours_to_add<=0 OR hours_to_add>72 THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_INVALID_AIRFRAME_TIME';END IF;

 SELECT * INTO state_row
 FROM airlinerra_game.aircraft_maintenance_state_v1
 WHERE aircraft_inventory_id=arrival.aircraft_inventory_id
  AND airline_id=arrival.airline_id FOR UPDATE;
 IF NOT FOUND OR state_row.verified_tracking_started_utc IS NULL
 OR state_row.tracked_flight_hours IS NULL
 OR state_row.tracked_flight_cycles IS NULL
 OR state_row.tracked_flight_hours<0
 OR state_row.tracked_flight_cycles<0
 THEN RETURN jsonb_build_object('status','blocked_missing_initial_airframe_tracking',
  'usageApplied',false,'ledgerPosted',false);END IF;
 SELECT * INTO existing
 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF existing.airline_id IS DISTINCT FROM arrival.airline_id
   OR existing.aircraft_inventory_id IS DISTINCT FROM arrival.aircraft_inventory_id
   OR existing.arrived_engine_event_id IS DISTINCT FROM arrival.engine_event_id
   OR existing.departed_engine_event_id IS DISTINCT FROM departure.engine_event_id
   OR existing.elapsed_flight_hours IS DISTINCT FROM hours_to_add
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_REPLAYED_AIRFRAME_USAGE_INCONSISTENT';END IF;
  RETURN jsonb_build_object('status','airframe_usage_already_applied',
    'flightOccurrenceId',p_physical_flight_id,
    'usageApplied',false,'replayed',true,
    'flightHoursAddedNow',0,'flightCyclesAddedNow',0,
    'ledgerPosted',false);
 END IF;

 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(
 physical_flight_id,airline_id,aircraft_inventory_id,
 arrived_engine_event_id,departed_engine_event_id,
 elapsed_flight_hours,flight_cycles
 ) VALUES(p_physical_flight_id,arrival.airline_id,arrival.aircraft_inventory_id,
 arrival.engine_event_id,departure.engine_event_id,hours_to_add,1);
 UPDATE airlinerra_game.aircraft_maintenance_state_v1
 SET tracked_flight_hours=tracked_flight_hours+hours_to_add,
     tracked_flight_cycles=tracked_flight_cycles+1,
     updated_at=clock_timestamp()
 WHERE aircraft_inventory_id=arrival.aircraft_inventory_id
 AND airline_id=arrival.airline_id
 AND tracked_flight_hours IS NOT NULL
 AND tracked_flight_cycles IS NOT NULL;
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_AIRFRAME_COUNTER_UPDATE_UNCONFIRMED_ROLLBACK';END IF;
 RETURN jsonb_build_object('status','arrived_airframe_usage_recorded_once',
   'flightOccurrenceId',p_physical_flight_id,
   'usageApplied',true,'replayed',false,
   'flightHoursAddedNow',hours_to_add,'flightCyclesAddedNow',1,
   'trackedFlightHoursTotal',state_row.tracked_flight_hours+hours_to_add,
   'trackedCyclesTotal',state_row.tracked_flight_cycles+1,
   'aircraftMaintenanceRecheckRequired',true,
   'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 clock_proof jsonb;now_utc timestamptz;
 activation record;execution record;engine record;
 evt record;matches jsonb;candidate jsonb;
 maintenance jsonb;movement jsonb;airframe_usage jsonb;
 permission_code text;movement_event_id text;
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
    AND c.review_status='verified'
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
  IF reason IS NULL AND NOT EXISTS(
     SELECT 1 FROM airlinerra_game.section9_operator_licence_evidence_v1 lic
     JOIN airlinerra_game.section9_game_permission_applications_v1 a
       ON a.id=lic.issued_application_id
        AND a.airline_id=lic.airline_id
        AND a.status='issued'
        AND a.permission_code='AIR_OPERATOR_CERTIFICATE'
        AND a.ledger_entry_id IS NOT NULL
        AND a.issued_game_date=lic.valid_from
        AND a.valid_until_game_date=lic.valid_until
     WHERE lic.world_id=1 AND lic.airline_id=evt.airline_id
      AND lic.jurisdiction_iso2=evt.home_country
      AND lic.evidence_status='verified'
      AND lic.valid_from<=evt.flight_local_date
      AND lic.valid_until>=evt.flight_local_date
      AND lic.evidence_reference='game-permission-issued-v1-'||a.id::text
  ) THEN reason:='ISSUED_OPERATOR_GAME_LICENCE_MISSING';END IF;
  IF reason IS NULL THEN
   permission_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
    evt.home_country,evt.origin_country,evt.destination_country,
    'passenger',evt.flight_local_date);
   IF permission_code IS NULL OR NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 r
    JOIN airlinerra_game.section9_game_permission_applications_v1 a
     ON a.id=r.issued_application_id
      AND a.airline_id=r.airline_id
      AND a.status='issued'
      AND a.ledger_entry_id IS NOT NULL
      AND a.permission_code=permission_code
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
   'actualFuelSettlementConnected',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

