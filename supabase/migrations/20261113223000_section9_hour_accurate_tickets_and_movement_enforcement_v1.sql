-- Airlinerra trusted World 1 flight timing and ticket enforcement.
-- Signed daily producer tick + matching Berlin date + trusted UTC clock
-- define current GAME hour, only while the world stays synchronized.
-- Flight availability: now through 7 x 24 hours, including later
-- departures today. Never sell tickets after departure.
-- Independently disabled commercial/engine releases remain disabled.
-- No upfront ticket revenue, no unsigned aircraft movement, no public RPC.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_saleable_departure_window_v1(p_schedule uuid, p_local_date date, p_weekly_entry integer, p_hour_utc timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 flight record;
 weekly_item jsonb;
 expected_local timestamp;
 expected_utc timestamptz;
 valid_time boolean:=false;
BEGIN
 IF p_schedule IS NULL OR p_local_date IS NULL
 OR p_weekly_entry IS NULL OR p_weekly_entry NOT BETWEEN 1 AND 7
 OR p_hour_utc IS NULL
 THEN RETURN jsonb_build_object('withinWindow',false,'readOnly',true);END IF;
 SELECT s.weekly_schedule,s.reference_departure_utc,
  s.reference_arrival_utc,s.status,s.operationally_verified,
  tz.timezone_iana
 INTO flight
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airport_reference_profiles tz
 ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
 JOIN pg_catalog.pg_timezone_names n ON n.name=tz.timezone_iana
 WHERE s.id=p_schedule AND s.world_id=1;
 IF NOT FOUND OR flight.status<>'active' OR
  flight.operationally_verified IS DISTINCT FROM true
 OR jsonb_typeof(flight.weekly_schedule) IS DISTINCT FROM 'array'
 OR jsonb_array_length(flight.weekly_schedule)<p_weekly_entry
 OR flight.reference_arrival_utc<=flight.reference_departure_utc
 OR flight.reference_arrival_utc>flight.reference_departure_utc+interval '72 hours'
 THEN RETURN jsonb_build_object('withinWindow',false,'readOnly',true);END IF;
 weekly_item:=flight.weekly_schedule->(p_weekly_entry-1);
 IF jsonb_typeof(weekly_item)<>'object'
 OR coalesce(weekly_item->>'day','') !~ '^[0-6]$'
 OR coalesce(weekly_item->>'time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 OR (weekly_item->>'day')::integer<>extract(isodow from p_local_date)::integer-1
 THEN RETURN jsonb_build_object('withinWindow',false,'readOnly',true);END IF;
 expected_local:=p_local_date::timestamp+(weekly_item->>'time')::time;
 expected_utc:=expected_local AT TIME ZONE flight.timezone_iana;
 valid_time:=(expected_utc AT TIME ZONE flight.timezone_iana)=expected_local
  AND NOT EXISTS(
   SELECT 1 FROM generate_series(-12,12) alt(i)
   WHERE alt.i<>0 AND ((expected_utc+make_interval(mins=>alt.i*15))
    AT TIME ZONE flight.timezone_iana)=expected_local
  );
 RETURN jsonb_build_object(
  'withinWindow',coalesce(valid_time,false)
   AND expected_utc>p_hour_utc
   AND expected_utc<=p_hour_utc+interval '7 days',
  'departureUtc',expected_utc,
  'readOnly',true,
  'scheduleProof',true,
  'gameClockReferenceUtc',p_hour_utc);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verified_saleable_departure_window_v1(uuid,date,integer,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(p_schedule uuid, p_local_date date, p_weekly_entry integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 s record; guard record; execution_guard record; readiness record;
 verified_date date;hour_proof jsonb;
 min_ground_minutes integer; proof jsonb; capacity record;
 existing record; inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_TICKET_ENGINE_ONLY';END IF;
 IF p_schedule IS NULL OR p_local_date IS NULL OR
    p_weekly_entry IS NULL OR p_weekly_entry NOT BETWEEN 1 AND 7
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_TICKET_OCCURRENCE';END IF;
 verified_date:=airlinerra_game.section9_verified_permission_game_day_v1();
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' OR
 verified_date IS NULL OR p_local_date<verified_date
    OR p_local_date>verified_date+7 THEN
  RETURN jsonb_build_object('status','blocked_game_date_or_seven_day_window',
   'opened',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT release_state,enabled_at,crew_mode INTO guard
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_guard
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO readiness
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF guard.release_state IS DISTINCT FROM 'enabled'
 OR guard.enabled_at IS NULL OR guard.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR execution_guard.release_state IS DISTINCT FROM 'enabled'
 OR execution_guard.enabled_at IS NULL
 OR readiness.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_unreleased_flight_engine',
  'opened',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT d.id,d.world_id,d.airline_id,d.aircraft_inventory_id,
  d.version,d.configuration_id,d.status,d.operationally_verified,
  d.origin_airport_key,d.destination_airport_key,
  c.passenger_seats,c.schedule_version,
  c.verification_source,
  commercial.economy_fare_usd,
  commercial.version as commercial_version
 INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=d.aircraft_inventory_id
   AND fleet.airline_id=d.airline_id AND fleet.fleet_status='in_service'
 JOIN airlinerra_game.section9_verified_schedule_capacity_v1 c
  ON c.schedule_id=d.id AND c.airline_id=d.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 commercial
  ON commercial.schedule_id=d.id AND commercial.airline_id=d.airline_id
 WHERE d.id=p_schedule
 FOR SHARE OF d,fleet,c,commercial;
 IF NOT FOUND OR s.world_id<>1 OR s.status<>'active'
 OR s.operationally_verified IS DISTINCT FROM true
 OR s.schedule_version IS DISTINCT FROM s.version
 OR length(coalesce(s.verification_source,''))<6
 OR s.passenger_seats IS NULL OR s.passenger_seats<=0
 OR s.economy_fare_usd IS NULL OR s.economy_fare_usd<=0
 OR s.commercial_version IS NULL THEN
  RETURN jsonb_build_object('status','blocked_unverified_schedule_capacity_or_fare',
   'opened',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF coalesce((airlinerra_game.section9_verified_saleable_departure_window_v1(
  p_schedule,p_local_date,p_weekly_entry,
  (hour_proof->>'gameHourUtc')::timestamptz)->>'withinWindow')::boolean,false)=false
 THEN RETURN jsonb_build_object('status','blocked_departure_past_or_beyond_seven_days',
   'opened',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT t.min_ground_minutes INTO min_ground_minutes
 FROM airlinerra_game.section9_game_turnaround_policy_v1 t
 WHERE t.role='passenger' AND t.max_seats>=s.passenger_seats
 ORDER BY t.max_seats LIMIT 1;
 IF min_ground_minutes IS NULL OR min_ground_minutes NOT BETWEEN 15 AND 360
 THEN RETURN jsonb_build_object('status','blocked_game_turnaround_policy_missing',
  'opened',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 -- This initialization rechecks the ACTUAL matching weekly airport slots,
 -- local dates (including DST), aircraft and commercial version.
 proof:=airlinerra_game.section9_initialize_verified_occurrence_v1(
  p_schedule,p_local_date,p_weekly_entry);
 IF proof->>'status' IS DISTINCT FROM 'capacity_preflight_initialized'
 OR proof->>'bookingsCreated' IS DISTINCT FROM 'false'
 OR proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_TICKET_OCCURRENCE_CAPACITY_PROOF_UNSAFE';END IF;
 SELECT * INTO capacity
 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 c
 WHERE c.physical_flight_id=proof->>'physicalFlightId' FOR UPDATE;
 IF NOT FOUND OR capacity.airline_id IS DISTINCT FROM s.airline_id
 OR capacity.schedule_version IS DISTINCT FROM s.version
 OR capacity.commercial_version IS DISTINCT FROM s.commercial_version
 OR capacity.passenger_capacity IS DISTINCT FROM s.passenger_seats
 OR capacity.passengers_held<>0
 OR capacity.status<>'preflight_only'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_TICKET_CAPACITY_PROOF_CHANGED';END IF;
 -- The schedule must have never departed or arrived before tickets open.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 mv
   WHERE mv.schedule_id=p_schedule AND mv.flight_local_date=p_local_date
    AND mv.weekly_entry=p_weekly_entry)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_CANNOT_OPEN_ALREADY_OPERATED_FLIGHT';END IF;
 INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
  world_id,airline_id,schedule_id,aircraft_inventory_id,
  schedule_version,weekly_entry,flight_local_date,
  origin_airport_key,destination_airport_key,
  departure_utc,arrival_utc,turnaround_minutes,
  verified_passenger_seats,booking_status,booked_seats,
  source_kind)
 VALUES(1,s.airline_id,p_schedule,s.aircraft_inventory_id,
  s.version,p_weekly_entry,p_local_date,
  s.origin_airport_key,s.destination_airport_key,
  capacity.departure_utc,capacity.arrival_utc,greatest(45,min_ground_minutes),
  s.passenger_seats,'open',0,'game_verified_saleable_schedule_v1')
 ON CONFLICT(schedule_id,flight_local_date,weekly_entry) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO existing
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.schedule_id=p_schedule AND o.flight_local_date=p_local_date
  AND o.weekly_entry=p_weekly_entry FOR UPDATE;
 IF NOT FOUND OR existing.world_id<>1
  OR existing.source_kind<>'game_verified_saleable_schedule_v1'
  OR existing.booking_status<>'open'
  OR existing.schedule_version<>s.version
  OR existing.airline_id<>s.airline_id
  OR existing.verified_passenger_seats<>s.passenger_seats
  OR existing.departure_utc<>capacity.departure_utc
  OR existing.arrival_utc<>capacity.arrival_utc
 THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_SALEABLE_TICKET_OCCURRENCE_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','verified_ticket_sales_open',
 'occurrenceId',existing.id,'flightLocalDate',p_local_date,
 'passengerSeats',existing.verified_passenger_seats,
 'existingBookedSeats',existing.booked_seats,
 'newOccurrence',inserted=1,'farePerEconomySeatUsd',s.economy_fare_usd,
 'sevenDayWindowVerified',true,'bookingsCreated',false,
 'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(uuid,date,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(p_occurrence uuid, p_reservation_key text, p_fare_class text, p_seats integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 row_value record;capacity record;prior record;release_record record;
 execution_record record; readiness record;
 verified_day date; hour_proof jsonb; inserted_id uuid; updated_count integer;
BEGIN
 -- This is the signed/verified DEMAND ENGINE's private writer.
 -- A player cannot book fictional passengers to inflate income.
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PASSENGER_RESERVATION_ENGINE_ONLY';END IF;
 IF p_occurrence IS NULL
 OR p_reservation_key IS NULL OR length(p_reservation_key) NOT BETWEEN 8 AND 100
 OR p_reservation_key !~ '^[A-Za-z0-9._:-]+$'
 OR p_fare_class IS DISTINCT FROM 'economy'
 OR p_seats IS NULL OR p_seats NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PASSENGER_RESERVATION';END IF;

 -- Lock physical occurrence and capacity BEFORE counting seats.
 SELECT o.*,s.status schedule_status,s.operationally_verified,
  s.version AS current_schedule_version,
  f.fleet_status,plan.economy_fare_usd,plan.version AS commercial_version
 INTO row_value
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
 ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.airline_aircraft_inventory f
 ON f.id=o.aircraft_inventory_id AND f.airline_id=o.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
 ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
 WHERE o.id=p_occurrence FOR UPDATE OF o;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked_unknown_flight',
   'reserved',false,'chargedNow',false,'ledgerPosted',false); END IF;

 SELECT * INTO prior FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
 WHERE b.occurrence_id=p_occurrence AND b.reservation_key=p_reservation_key
 FOR UPDATE;
 IF FOUND THEN
  IF prior.fare_class IS DISTINCT FROM p_fare_class
  OR prior.seats_requested IS DISTINCT FROM p_seats
  OR prior.quoted_fare_usd IS DISTINCT FROM row_value.economy_fare_usd
  THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_PASSENGER_RESERVATION_REPLAY_MISMATCH'; END IF;
  RETURN jsonb_build_object('status','game_passenger_reservation_replayed',
   'reservationId',prior.id,'reservationStatus',prior.reservation_status,
   'seats',prior.seats_requested,'replayed',true,'reservedNow',false,
   'chargedNow',false,'ledgerPosted',false,'flightActivated',false);
 END IF;

 verified_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 SELECT release_state,enabled_at INTO release_record
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_record
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO readiness
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF verified_day IS NULL
 OR hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR row_value.flight_local_date<verified_day
 OR row_value.flight_local_date>verified_day+7
 OR coalesce((airlinerra_game.section9_verified_saleable_departure_window_v1(
  row_value.schedule_id,row_value.flight_local_date,row_value.weekly_entry,
  (hour_proof->>'gameHourUtc')::timestamptz)->>'withinWindow')::boolean,false)=false
 OR release_record.release_state IS DISTINCT FROM 'enabled'
 OR release_record.enabled_at IS NULL
 OR execution_record.release_state IS DISTINCT FROM 'enabled'
 OR execution_record.enabled_at IS NULL
 OR readiness.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_booking_window_or_unreleased_engine',
   'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT * INTO capacity
 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
 WHERE cap.physical_flight_id=row_value.schedule_id::text||':'||
  row_value.flight_local_date::text||':'||row_value.weekly_entry::text
 FOR UPDATE;
 IF NOT FOUND OR capacity.schedule_id<>row_value.schedule_id
 OR capacity.airline_id<>row_value.airline_id
 OR capacity.passenger_capacity<>row_value.verified_passenger_seats
 OR capacity.schedule_version<>row_value.schedule_version
 OR capacity.commercial_version<>row_value.commercial_version
 OR capacity.passengers_held<>row_value.booked_seats
 OR capacity.status<>'preflight_only'
 OR row_value.source_kind<>'game_verified_saleable_schedule_v1'
 OR row_value.booking_status<>'open'
 OR row_value.schedule_status<>'active'
 OR row_value.operationally_verified IS DISTINCT FROM true
 OR row_value.current_schedule_version<>row_value.schedule_version
 OR row_value.fleet_status<>'in_service'
 OR row_value.economy_fare_usd IS NULL OR row_value.economy_fare_usd<=0
 OR row_value.verified_passenger_seats IS NULL
 THEN RETURN jsonb_build_object('status','blocked_stale_or_unverified_saleable_inventory',
  'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;
 IF NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
 WHERE slot.schedule_id=row_value.schedule_id AND slot.direction='departure')
 OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
 WHERE slot.schedule_id=row_value.schedule_id AND slot.direction='arrival')
 OR EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.schedule_id=row_value.schedule_id
 AND m.flight_local_date=row_value.flight_local_date
 AND m.weekly_entry=row_value.weekly_entry)
 THEN RETURN jsonb_build_object('status','blocked_slots_or_flight_already_operated',
   'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;
 IF p_seats>capacity.passenger_capacity-capacity.passengers_held THEN
 RETURN jsonb_build_object('status','blocked_insufficient_available_seats',
  'availableSeats',capacity.passenger_capacity-capacity.passengers_held,
  'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;

 UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET passengers_held=passengers_held+p_seats
 WHERE physical_flight_id=capacity.physical_flight_id
 AND passengers_held=capacity.passengers_held
 AND passenger_capacity>=passengers_held+p_seats;
 GET DIAGNOSTICS updated_count=ROW_COUNT;
 IF updated_count<>1 THEN
  RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_PASSENGER_CAPACITY_CHANGED_CONCURRENTLY';END IF;
 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booked_seats=booked_seats+p_seats
 WHERE id=p_occurrence AND booked_seats=row_value.booked_seats
 AND booked_seats+p_seats<=verified_passenger_seats;
 GET DIAGNOSTICS updated_count=ROW_COUNT;
 IF updated_count<>1 THEN
  RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_PASSENGER_OCCURRENCE_CHANGED_CONCURRENTLY';END IF;

 INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(
  occurrence_id,reservation_key,fare_class,seats_requested,
  quoted_fare_usd,reservation_status,paid_upfront,recognized_revenue_usd)
 VALUES(p_occurrence,p_reservation_key,'economy',p_seats,
  row_value.economy_fare_usd,'reserved',false,0)
 RETURNING id INTO inserted_id;

 RETURN jsonb_build_object(
  'status','game_passenger_seats_reserved',
  'reservationId',inserted_id,'occurrenceId',p_occurrence,
  'seatsReservedNow',p_seats,
  'totalSeatsBooked',row_value.booked_seats+p_seats,
  'remainingSeats',capacity.passenger_capacity-capacity.passengers_held-p_seats,
  'economyFarePerSeatUsd',row_value.economy_fare_usd,
  'quotedTotalFareUsd',row_value.economy_fare_usd*p_seats,
  'replayed',false,'chargedNow',false,
  'revenueRecognizedNow',false,'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(uuid,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_open_verified_ticket_window_batch_v1(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 game_day date;hour_proof jsonb;
 activation record; execution record; ready record;
 entry record;opened integer:=0;inspected integer:=0;already_open integer:=0;
 blocked integer:=0;result jsonb;failure_status text;blocked_by_status jsonb:='{}'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TICKET_WINDOW_SCHEDULER_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 200 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_TICKET_WINDOW_BATCH_LIMIT_INVALID';END IF;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_unverified_game_hour',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF game_day IS NULL THEN
  RETURN jsonb_build_object('status','blocked_unverified_game_clock',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT release_state,enabled_at,crew_mode INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO ready
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
  OR activation.enabled_at IS NULL
  OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
  OR execution.release_state IS DISTINCT FROM 'enabled'
  OR execution.enabled_at IS NULL
  OR ready.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
  OR ready.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
  OR ready.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN
  RETURN jsonb_build_object('status','blocked_unreleased_flight_engine',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10027) THEN
  RETURN jsonb_build_object('status','ticket_window_worker_in_progress',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 FOR entry IN
  SELECT d.id AS schedule_id,day_value.day_value::date AS local_date,
    w.ordinality::int AS entry_no
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
    ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
    AND cap.schedule_version=d.version AND cap.passenger_seats>0
  JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
    ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
    AND plan.economy_fare_usd>0
  CROSS JOIN LATERAL generate_series(
     game_day::timestamp,(game_day+7)::timestamp,interval '1 day'
   ) day_value(day_value)
  CROSS JOIN LATERAL jsonb_array_elements(d.weekly_schedule)
    WITH ORDINALITY w(item,ordinality)
  WHERE d.world_id=1 AND d.status='active'
    AND d.operationally_verified=true
    AND w.ordinality BETWEEN 1 AND 7
    AND coalesce(w.item->>'day','') ~ '^[0-6]$'
    AND coalesce(w.item->>'time','') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
    AND (w.item->>'day')::integer=
      extract(isodow FROM day_value.day_value)::integer-1
    AND coalesce((airlinerra_game.section9_verified_saleable_departure_window_v1(
      d.id,day_value.day_value::date,w.ordinality::int,
      (hour_proof->>'gameHourUtc')::timestamptz)->>'withinWindow')::boolean,false)=true
    AND NOT EXISTS (
      SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
      WHERE o.schedule_id=d.id
      AND o.flight_local_date=day_value.day_value::date
      AND o.weekly_entry=w.ordinality)
  ORDER BY day_value.day_value,d.airline_id,d.id,w.ordinality
  LIMIT p_limit
 LOOP
  result:=airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(
    entry.schedule_id,entry.local_date,entry.entry_no);
  inspected:=inspected+1;
  IF result->>'status'='verified_ticket_sales_open'
   AND result->>'ledgerPosted'='false'
   AND result->>'bookingsCreated'='false'
  THEN
   IF result->>'newOccurrence'='true' THEN
    opened:=opened+1;
   ELSE already_open:=already_open+1;END IF;
  ELSIF result->>'status' IN (
   'blocked_game_date_or_seven_day_window',
   'blocked_unreleased_flight_engine',
   'blocked_unverified_schedule_capacity_or_fare',
   'blocked_game_turnaround_policy_missing'
  ) AND result->>'ledgerPosted'='false' THEN
   blocked:=blocked+1;
   failure_status:=result->>'status';
   blocked_by_status:=jsonb_set(blocked_by_status,ARRAY[failure_status],
     to_jsonb(coalesce((blocked_by_status->>failure_status)::integer,0)+1),true);
  ELSE
   RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_UNSAFE_TICKET_WINDOW_WORKER_RESPONSE';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','ticket_window_batch_completed',
 'verifiedGameDate',game_day,'daysAhead',7,
 'scanned',inspected,'opened',opened,
 'previouslyOpened',already_open,'blocked',blocked,
 'blockedReasons',blocked_by_status,
 'ledgerPosted',false,'bookingsCreated',false,
 'hourAccurateSameDayBookingActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_open_verified_ticket_window_batch_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

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
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_TRUSTED_MOVEMENT_ENGINE_ONLY';END IF;
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

