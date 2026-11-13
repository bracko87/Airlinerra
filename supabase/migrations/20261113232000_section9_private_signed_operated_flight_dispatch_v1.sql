-- Airlinerra game-only, server-clock driven operated-aircraft dispatcher.
-- The function is POSTGRES-only / security-invoker, and scheduled every minute.
-- A private Vault HMAC signs canonical event identity and UTC second;
-- the actual movement writer verifies that HMAC before any release decision.
-- Reuses certified schedule, origin/destination route rights, airport
-- reservations, maintenance checks, verified seven-day ticket occurrences,
-- and existing aircraft-position/overlap and retry guards.
-- Departure closes new reservations ATOMICALLY with the movement event.
-- Arrival needs an authenticated earlier departure. No fake flights,
-- charges, ticket revenue or fuel accounting are created by this worker.
-- World 1 flight engine remains paused until independent proofs are complete.
DO $set_event_secret$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM vault.secrets
 WHERE name='airlinerra_operated_flight_auto_signing_v1') THEN
  PERFORM vault.create_secret(encode(extensions.gen_random_bytes(48),'hex'),
  'airlinerra_operated_flight_auto_signing_v1',
  'Private signed game flight event HMAC; never log or expose this value');
 END IF;
END $set_event_secret$;
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

 SELECT anchor.airport_key,anchor.anchored_game_date,
  source.order_status,inspection.inspection_status,
  source.registration AS order_registration,
  source.configuration_id AS order_configuration,
  i.registration AS fleet_registration
 INTO anchor
 FROM airlinerra_game.section9_aircraft_delivery_position_v1 anchor
 JOIN airlinerra_game.aircraft_acquisition_orders_v1 source
  ON source.order_id=anchor.acquisition_order_id
   AND source.airline_id=anchor.airline_id
   AND source.aircraft_inventory_id=anchor.aircraft_inventory_id
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 inspection
  ON inspection.inspection_id=anchor.inspection_id
   AND inspection.order_id=source.order_id
   AND inspection.inspection_status='approved'
   AND inspection.reviewed_at=anchor.inspection_reviewed_at
   AND inspection.reviewer_reference=anchor.reviewer_reference
 JOIN airlinerra_game.airline_aircraft_inventory i
  ON i.id=anchor.aircraft_inventory_id AND i.airline_id=anchor.airline_id
 WHERE anchor.aircraft_inventory_id=s.aircraft_inventory_id
  AND anchor.airline_id=p_airline
  AND anchor.anchored_game_date<=
   (p_event_utc AT TIME ZONE 'UTC')::date
  AND source.delivery_home_airport_key=anchor.airport_key
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
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 clock_proof jsonb;now_utc timestamptz;
 activation record;execution record;engine record;
 evt record;matches jsonb;candidate jsonb;
 maintenance jsonb;movement jsonb;
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
  ELSE arrivals:=arrivals+1;END IF;
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

DO $dispatch_cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job
 WHERE jobname='airlinerra-game-operated-flight-dispatch-v1') THEN
  PERFORM cron.schedule(
   'airlinerra-game-operated-flight-dispatch-v1','* * * * *',
   'SELECT airlinerra_game.section9_auto_dispatch_due_flight_events_v1(40);');
 END IF;
END $dispatch_cron$;
