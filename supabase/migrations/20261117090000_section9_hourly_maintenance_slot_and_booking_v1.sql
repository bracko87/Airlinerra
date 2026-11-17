-- Airlinerra: time-accurate maintenance booking for all owned/leased aircraft.
-- A recurring flight schedule does not block maintenance for an entire day.
-- Only a real overlap between [maintenance start,end] and [departure,arrival],
-- including game turnaround, blocks the service slot.
-- Origin-local timetable uses verified IANA time zone including DST.
-- Maintenance price/payment and grounded-aircraft checks remain unchanged.
-- All user and anonymous direct RPC access is still revoked.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_start_utc timestamp with time zone, p_end_utc timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 clock_proof jsonb;
 schedule_row record;
 weekly_item jsonb;
 day_value date;
 local_departure timestamp;
 departure_utc timestamptz;
 arrival_utc timestamptz;
 turnaround_min integer;
 policy_role text;
 n_active integer:=0;
 checked_occurrences integer:=0;
 n_conflicts integer:=0;
 invalid_count integer:=0;
 total_buffer_min integer;
 first_conflict jsonb:=NULL;
 starting_day date;
 ending_day date;
 evidence record;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_MAINTENANCE_AIRCRAFT_OWNER_REQUIRED';END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.airlines a
  JOIN airlinerra_game.world_memberships m
   ON m.world_id=a.world_id AND m.player_id=p_player AND m.state='active'
  JOIN airlinerra_game.airline_aircraft_inventory f
   ON f.airline_id=a.id AND f.id=p_aircraft
   AND f.ownership_type IN('owned','leased') AND f.fleet_status='in_service'
  WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player
 ) THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_MAINTENANCE_AIRCRAFT_NOT_OWNED';END IF;
 IF p_start_utc IS NULL OR p_end_utc IS NULL
 OR p_end_utc<=p_start_utc OR p_end_utc>p_start_utc+interval '504 hours'
 THEN RETURN jsonb_build_object('status','blocked_invalid_maintenance_interval',
   'slotClear',false,'readOnly',true,'chargesPosted',false);END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR p_start_utc<(clock_proof->>'gameHourUtc')::timestamptz
 OR p_start_utc>(clock_proof->>'gameHourUtc')::timestamptz+interval '42 days'
 THEN RETURN jsonb_build_object('status','blocked_unverified_maintenance_game_clock',
   'slotClear',false,'readOnly',true,'chargesPosted',false);END IF;

 SELECT count(*) INTO n_active FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.world_id=1 AND s.airline_id=p_airline
  AND s.aircraft_inventory_id=p_aircraft AND s.status='active';
 IF n_active>250 THEN RETURN jsonb_build_object(
  'status','blocked_too_many_active_aircraft_schedules','slotClear',false,
  'readOnly',true,'chargesPosted',false);END IF;

 FOR schedule_row IN
  SELECT s.*,cap.schedule_version as capacity_version,
   cap.passenger_seats,cap.cargo_capacity_tonnes,
   aircraft.use_type,
   tz.timezone_iana as origin_tz,
   fleet.configuration_id AS active_configuration,
   fleet.fleet_status
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  LEFT JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
    ON cap.schedule_id=s.id AND cap.airline_id=s.airline_id
  LEFT JOIN airlinerra.aircraft_configurations aircraft
    ON aircraft.id=s.configuration_id
  LEFT JOIN airlinerra_game.airport_reference_profiles tz
    ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
  LEFT JOIN airlinerra_game.airline_aircraft_inventory fleet
    ON fleet.id=s.aircraft_inventory_id AND fleet.airline_id=s.airline_id
  WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=p_aircraft AND s.status='active'
  ORDER BY s.id
 LOOP
  IF schedule_row.operationally_verified IS DISTINCT FROM true
    OR schedule_row.fleet_status IS DISTINCT FROM 'in_service'
    OR schedule_row.active_configuration IS DISTINCT FROM schedule_row.configuration_id
    OR schedule_row.capacity_version IS DISTINCT FROM schedule_row.version
    OR schedule_row.use_type NOT IN ('passenger','cargo','combi')
    OR schedule_row.origin_tz IS NULL
    OR NOT EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names
        WHERE name=schedule_row.origin_tz)
    OR schedule_row.reference_arrival_utc IS NULL
    OR schedule_row.reference_departure_utc IS NULL
    OR schedule_row.reference_arrival_utc<=schedule_row.reference_departure_utc
    OR schedule_row.reference_arrival_utc>schedule_row.reference_departure_utc+
       interval '72 hours'
    OR jsonb_typeof(schedule_row.weekly_schedule) IS DISTINCT FROM 'array'
    OR jsonb_array_length(schedule_row.weekly_schedule) NOT BETWEEN 1 AND 7
  THEN RETURN jsonb_build_object('status','blocked_invalid_activated_aircraft_schedule',
    'slotClear',false,'readOnly',true,'scheduleId',schedule_row.id,
    'chargesPosted',false);END IF;
  policy_role:=CASE WHEN schedule_row.use_type='cargo' THEN 'cargo'
   ELSE 'passenger' END;
  SELECT min_ground_minutes INTO turnaround_min
  FROM airlinerra_game.section9_game_turnaround_policy_v1
  WHERE role=policy_role
    AND max_seats>=coalesce(schedule_row.passenger_seats,0)
  ORDER BY max_seats LIMIT 1;
  IF turnaround_min IS NULL OR turnaround_min NOT BETWEEN 15 AND 360
  THEN RETURN jsonb_build_object('status','blocked_missing_turnaround_policy',
    'slotClear',false,'readOnly',true,'scheduleId',schedule_row.id,
    'chargesPosted',false);END IF;
  total_buffer_min:=greatest(45,turnaround_min);
  starting_day:=((p_start_utc-interval '4 days') AT TIME ZONE
     schedule_row.origin_tz)::date;
  ending_day:=((p_end_utc+interval '1 day') AT TIME ZONE
     schedule_row.origin_tz)::date;
  FOR weekly_item IN
     SELECT value FROM jsonb_array_elements(schedule_row.weekly_schedule)
  LOOP
   IF jsonb_typeof(weekly_item) IS DISTINCT FROM 'object'
   OR coalesce(weekly_item->>'day','') !~ '^[0-6]$'
   OR coalesce(weekly_item->>'time','') !~
    '^([01][0-9]|2[0-3]):[0-5][0-9]$'
   THEN RETURN jsonb_build_object('status','blocked_invalid_weekly_departure',
     'slotClear',false,'readOnly',true,'scheduleId',schedule_row.id,
     'chargesPosted',false);END IF;
   FOR day_value IN
    SELECT v::date FROM generate_series(starting_day::timestamp,
            ending_day::timestamp,interval '1 day') AS v
    WHERE extract(isodow FROM v)::int-1=(weekly_item->>'day')::int
   LOOP
    local_departure:=day_value::timestamp+(weekly_item->>'time')::time;
    departure_utc:=local_departure AT TIME ZONE schedule_row.origin_tz;
    arrival_utc:=departure_utc+
      (schedule_row.reference_arrival_utc-schedule_row.reference_departure_utc);
    IF departure_utc AT TIME ZONE schedule_row.origin_tz
      IS DISTINCT FROM local_departure
      OR EXISTS(
       SELECT 1 FROM generate_series(-12,12) AS alt(i)
       WHERE alt.i<>0 AND
       (departure_utc+make_interval(mins=>alt.i*15)) AT TIME ZONE
         schedule_row.origin_tz=local_departure)
    THEN RETURN jsonb_build_object('status','blocked_ambiguous_or_nonexistent_flight_time',
      'slotClear',false,'readOnly',true,'scheduleId',schedule_row.id,
      'localDeparture',local_departure,'chargesPosted',false);END IF;
    checked_occurrences:=checked_occurrences+1;
    -- Exact overlap, including safe on-ground time around each leg.
    -- e.g., a check may finish 45 minutes before the next departure.
    IF departure_utc<p_end_utc+make_interval(mins=>total_buffer_min)
     AND arrival_utc>p_start_utc-make_interval(mins=>total_buffer_min)
    THEN
     n_conflicts:=n_conflicts+1;
     IF first_conflict IS NULL THEN
      first_conflict:=jsonb_build_object(
        'scheduleId',schedule_row.id,'flightNumber',schedule_row.flight_number,
        'flightDay',day_value,'flightDepartureUtc',departure_utc,
        'flightArrivalUtc',arrival_utc,'groundBufferMinutes',total_buffer_min);
     END IF;
    END IF;
   END LOOP;
  END LOOP;
 END LOOP;
 -- A dated flight remains blocking even if its recurring schedule
 -- later changed, until its dated booking is explicitly cancelled.
 SELECT count(*) INTO invalid_count
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft
  AND o.arrival_utc>p_start_utc-interval '45 minutes'
  AND o.departure_utc<p_end_utc+interval '45 minutes';
 RETURN jsonb_build_object(
  'status',CASE WHEN n_conflicts=0 AND invalid_count=0
    THEN 'hourly_maintenance_slot_clear'
    ELSE 'maintenance_conflicts_with_flight_time' END,
  'slotClear',n_conflicts=0 AND invalid_count=0,
  'airlineId',p_airline,'aircraftInventoryId',p_aircraft,
  'worldId',1,'maintenanceStartUtc',p_start_utc,
  'maintenanceEndUtc',p_end_utc,
  'activeSchedulesInspected',n_active,
  'weeklyOccurrencesChecked',checked_occurrences,
  'overlappingRecurringFlights',n_conflicts,
  'overlappingDatedFlights',invalid_count,
  'firstConflict',first_conflict,
  'readOnly',true,'bookingCreated',false,
  'ledgerPosted',false,'chargesPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(uuid,uuid,uuid,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_job_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_action text, p_check_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_now timestamptz; f record; pos jsonb; policy record; slot_proof jsonb;
 active_job record; next_start timestamptz;
 j_id uuid; jobs jsonb; completed integer; setup record;
 quote_usd numeric; available_usd numeric; quotes jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
    OR p_action NOT IN ('status','book','cancel') OR p_action IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_MAINTENANCE_JOB_ACTION';END IF;
 SELECT fleet.id,fleet.airline_id,fleet.registration,fleet.configuration_id,
        fleet.fleet_status,airline.home_airport_key
 INTO f FROM airlinerra_game.airline_aircraft_inventory fleet
 JOIN airlinerra_game.airlines airline ON airline.id=fleet.airline_id
   AND airline.world_id=1 AND airline.owner_player_id=p_player
 JOIN airlinerra_game.world_memberships w
 ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE fleet.id=p_aircraft AND fleet.airline_id=p_airline
 AND fleet.ownership_type IN ('owned','leased')
 FOR UPDATE OF fleet;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_MAINTENANCE_JOB_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF f.fleet_status<>'in_service' THEN RAISE EXCEPTION USING ERRCODE='55000',
 MESSAGE='SECTION9_AIRCRAFT_NOT_IN_SERVICE';END IF;
 SELECT jsonb_agg(jsonb_build_object(
  'jobId',j.job_id,'checkCode',j.check_code,'airportKey',j.airport_key,
  'gameStartUtc',j.game_start_utc,'gameEndUtc',j.game_end_utc,
  'status',j.status,'quotedCostUsd',j.quoted_cost_usd,
  'costPosted',j.paid_ledger_entry_id IS NOT NULL,'isGameService',true)
  ORDER BY j.created_at DESC)
 INTO jobs FROM (
  SELECT * FROM airlinerra_game.section9_game_maintenance_jobs_v1
  WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
  ORDER BY created_at DESC LIMIT 15
 ) j;
 SELECT jsonb_object_agg(check_code,base_estimate_usd) INTO quotes
 FROM airlinerra_game.aircraft_maintenance_check_overview_v1
 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
 AND cost_evidence='provisional_game_tariff_not_vendor_quote' AND base_estimate_usd>0;
 IF p_action='status' THEN
  RETURN jsonb_build_object('status','game_maintenance_jobs',
   'jobs',coalesce(jobs,'[]'::jsonb),
   'quotedGameServicePricesUsd',coalesce(quotes,'{}'::jsonb),
   'tariffSource','provisional_game_tariff_not_vendor_quote',
   'gameNowUtc',v_now,'aircraftGroundedForJob',
   EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1
    WHERE aircraft_inventory_id=p_aircraft AND status IN ('in_progress','payment_required')),
   'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_action='cancel' THEN
  UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
  SET status='cancelled'
  WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
   AND status='scheduled' AND game_start_utc>v_now
  RETURNING job_id INTO j_id;
  IF j_id IS NULL THEN RETURN jsonb_build_object('status','no_cancelable_service',
    'changed',false,'flightActivated',false,'ledgerPosted',false);END IF;
  RETURN jsonb_build_object('status','cancelled','jobId',j_id,
   'changed',true,'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_check_code IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_MAINTENANCE_CHECK_REQUIRED';END IF;
 SELECT * INTO policy FROM airlinerra_game.maintenance_check_policy_v1
 WHERE check_code=p_check_code;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_UNKNOWN_MAINTENANCE_CHECK';END IF;
 -- Booking now must use only the fully trusted current instant; a future
 -- start can be added once reliable aircraft-time rotation reservations exist.
 next_start:=date_trunc('minute',v_now)+interval '2 minutes';
 SELECT * INTO setup
 FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b
 JOIN airlinerra_game.aircraft_maintenance_state_v1 m
 ON m.aircraft_inventory_id=b.aircraft_inventory_id
 AND m.airline_id=b.airline_id
 WHERE b.aircraft_inventory_id=p_aircraft AND b.airline_id=p_airline
 AND b.owner_player_id=p_player;
 IF NOT FOUND OR setup.tracked_flight_hours IS NULL OR
    setup.game_baseline_date> (v_now AT TIME ZONE 'Europe/Berlin')::date
 THEN RETURN jsonb_build_object('status','missing_game_airframe_baseline',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
  p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified'<>'true' OR pos->>'atGroundAirport'<>'true'
   OR pos->>'airportKey' IS NULL
 THEN RETURN jsonb_build_object('status','aircraft_location_unverified',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.approved_game_airports a
  WHERE a.world_id=1 AND a.airport_key=pos->>'airportKey'
 ) THEN RETURN jsonb_build_object('status','airport_not_in_game',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF policy.airport_scope='type_approved_mro' AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.maintenance_airport_capabilities_v1 a
 WHERE a.world_id=1 AND a.airport_key=pos->>'airportKey'
 AND a.configuration_id=f.configuration_id
 AND a.check_code=policy.check_code
 AND a.approval_status='game_approved')
 THEN RETURN jsonb_build_object('status','airport_not_approved_for_heavy_check',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
  WHERE j.aircraft_inventory_id=p_aircraft
  AND j.status IN ('scheduled','in_progress','payment_required'))
 THEN RETURN jsonb_build_object('status','aircraft_already_booked_for_maintenance',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 slot_proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(
    p_player,p_airline,p_aircraft,next_start,
    next_start+make_interval(hours=>policy.downtime_hours));
 IF slot_proof->>'status' IS DISTINCT FROM 'hourly_maintenance_slot_clear'
 OR slot_proof->>'slotClear' IS DISTINCT FROM 'true'
 OR slot_proof->>'readOnly' IS DISTINCT FROM 'true'
 OR slot_proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
   'status','aircraft_flight_or_slot_conflict_not_clear',
   'hourAccurateConflictCheck',true,
   'slotStatus',slot_proof->>'status',
   'slotEvidence',slot_proof,
   'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT base_estimate_usd INTO quote_usd
 FROM airlinerra_game.aircraft_maintenance_check_overview_v1
 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
 AND check_code=policy.check_code
 AND cost_evidence='provisional_game_tariff_not_vendor_quote';
 IF NOT FOUND OR quote_usd IS NULL OR quote_usd<=0 THEN
  RETURN jsonb_build_object('status','game_maintenance_cost_unverified',
   'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO available_usd
 FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF available_usd<quote_usd THEN
  RETURN jsonb_build_object('status','game_maintenance_insufficient_funds',
   'created',false,'requiredUsd',quote_usd,'balanceUsd',available_usd,
   'flightActivated',false,'ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_game_maintenance_jobs_v1
  (owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,
   game_start_utc,game_end_utc,duration_hours,condition_before_game_pct,
   flight_hours_at_book,quoted_cost_usd)
 VALUES(p_player,p_airline,p_aircraft,policy.check_code,pos->>'airportKey',
  next_start,next_start+make_interval(hours=>policy.downtime_hours),
  policy.downtime_hours,setup.game_condition_pct,setup.tracked_flight_hours,quote_usd)
 RETURNING job_id INTO j_id;
 RETURN jsonb_build_object('status','scheduled','created',true,
  'jobId',j_id,'checkCode',policy.check_code,'airportKey',pos->>'airportKey',
  'startUtc',next_start,
  'endUtc',next_start+make_interval(hours=>policy.downtime_hours),
  'gameJobOnly',true,'groundDuringService',true,
  'quotedCostUsd',quote_usd,'chargedNow',false,
  'chargedAtServiceCompletion',true,
  'tariffSource','provisional_game_tariff_not_vendor_quote',
  'physicalInspectionVerified',false,'flightActivated',false,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_game_maintenance_job_v1(uuid,uuid,uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
