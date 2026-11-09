-- Trusted engine-only physical flight movement ingestion.
-- HMAC must be verified by private backend using a distinct operated-flight
-- engine secret BEFORE invoking this SQL transaction.
-- No player SQL/API access. No draft flight activation. No bookings or money.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 p_airline uuid,p_schedule uuid,p_schedule_version int,
 p_local_date date,p_weekly_entry int,p_phase text,
 p_event_utc timestamptz,p_event_id text,p_verified_hmac text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE world_state record;clock_row record;s record;
 capacity record;origin_tz text; weekly_item jsonb;
 local_departure timestamp; scheduled_dep timestamptz;
 scheduled_arr timestamptz; occurrence text;
 fleet record; anchor record;pos record; existing record;
 position_exists boolean:=false; resolution jsonb;
 change_count int;
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
 FOR SHARE OF d,f;
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
 local_departure:=p_local_date::timestamp+
  (weekly_item->>'time')::time;
 scheduled_dep:=local_departure AT TIME ZONE origin_tz;
 scheduled_arr:=scheduled_dep+
  (s.reference_arrival_utc-s.reference_departure_utc);
 IF (scheduled_dep AT TIME ZONE origin_tz) IS DISTINCT FROM local_departure
  OR ((scheduled_dep-interval '1 hour') AT TIME ZONE origin_tz)=local_departure
  OR ((scheduled_dep+interval '1 hour') AT TIME ZONE origin_tz)=local_departure
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
 IF NOT FOUND OR anchor.order_registration IS DISTINCT FROM
   anchor.fleet_registration
  OR anchor.order_configuration IS DISTINCT FROM s.configuration_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_DELIVERY_ANCHOR_UNVERIFIED';END IF;
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
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 uuid,uuid,int,date,int,text,timestamptz,text,text)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 uuid,uuid,int,date,int,text,timestamptz,text,text) IS
 'Private trusted signed operated-flight departure/arrival. Requires active operationally-verified schedule and capacity proof, signed engine event checked by backend, real clock receipt and immutable delivery anchor. Serializes physical aircraft; no tickets or money. Currently impossible for draft-only live schedules.';
