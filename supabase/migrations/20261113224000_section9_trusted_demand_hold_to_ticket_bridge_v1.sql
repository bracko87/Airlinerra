-- Airlinerra: convert COMPLETED, trusted demand itinerary holds into
-- real economy-ticket reservations (one or two flight legs).
-- All use the SAME capacity inventory. Held seats are counted ONCE:
-- the demand planner allocated them already, so issuance updates only
-- dated-flight booked_seats and inserts idempotent reservation rows.
-- Direct bookings now lock inventory FIRST and allow unissued holds.
-- No charge, no ledger posting and no ticket revenue recognition here.
-- No client grants: all trusted functions are private INVOKER functions.
-- Live World 1 flight-operation releases remain independently PAUSED.
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
 OR p_reservation_key LIKE 'demand.s9g1:%'
 OR p_fare_class IS DISTINCT FROM 'economy'
 OR p_seats IS NULL OR p_seats NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PASSENGER_RESERVATION';END IF;

 -- Lock capacity inventory FIRST, then the dated occurrence, so direct
 -- reservations and connected demand holds share the same lock order.
 PERFORM 1 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o
 ON cap.physical_flight_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
 WHERE o.id=p_occurrence FOR UPDATE OF cap;
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
 OR capacity.passengers_held<row_value.booked_seats
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

CREATE OR REPLACE FUNCTION airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(p_allocation_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 h record; leg record; inv record; flight record; commercial record; previous record;
 hour_proof jsonb; now_utc timestamptz;
 active_release record; execution_release record; engine record;
 nlegs int:=0; prior_count int:=0;written int:=0;changed int;
 reservation_key text; total_quoted numeric:=0;
 issued_id uuid;
BEGIN
 -- Only the private game worker can turn COMPLETED demand plan holds
 -- into real tickets. No browser/RPC can claim passengers.
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_DEMAND_TICKET_WORKER_ONLY';END IF;
 IF p_allocation_key IS NULL OR
   p_allocation_key !~ '^s9g1:[0-9a-f]{64}$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_DEMAND_ALLOCATION_KEY';END IF;

 SELECT * INTO h FROM airlinerra_game.section9_atomic_itinerary_holds_v1
 WHERE source_allocation_key=p_allocation_key FOR SHARE;
 IF NOT FOUND OR h.status IS DISTINCT FROM 'preflight_only'
 OR h.passengers IS NULL OR h.passengers NOT BETWEEN 1 AND 1000
 OR h.cargo_tonnes IS DISTINCT FROM 0
 OR cardinality(h.physical_flight_ids) NOT BETWEEN 1 AND 2
 THEN RETURN jsonb_build_object('status','blocked_missing_or_mixed_cargo_hold',
   'ticketsIssued',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 -- Permit only a completed, immutable, owner-independent demand plan
 -- already staged by the existing private allocation engine.
 IF NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_capacity_hold_plan_items_v1 i
   JOIN airlinerra_game.section9_capacity_hold_plans_v1 plan
    ON plan.id=i.plan_id
   WHERE i.allocation_key=p_allocation_key
    AND plan.world_id=1 AND plan.status='completed'
    AND plan.next_allocation_seq=plan.allocation_count
    AND plan.completed_at IS NOT NULL
    AND i.physical_flight_ids=h.physical_flight_ids
    AND i.passengers=h.passengers
    AND i.cargo_tonnes=h.cargo_tonnes
 ) THEN RETURN jsonb_build_object('status','blocked_unfinished_demand_plan',
   'ticketsIssued',false,'bookingsCreated',false,'ledgerPosted',false);END IF;

 SELECT count(*) INTO nlegs FROM
 airlinerra_game.section9_atomic_itinerary_hold_legs_v1 l
 WHERE l.source_allocation_key=p_allocation_key;
 IF nlegs<>cardinality(h.physical_flight_ids)
 OR EXISTS(
   SELECT 1 FROM unnest(h.physical_flight_ids)
   WITH ORDINALITY a(id,ord)
   LEFT JOIN airlinerra_game.section9_atomic_itinerary_hold_legs_v1 l
    ON l.source_allocation_key=p_allocation_key
    AND l.leg_number=a.ord
    AND l.physical_flight_id=a.id
   WHERE l.source_allocation_key IS NULL
 ) THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_DEMAND_HOLD_LEG_PROOF_MISMATCH';END IF;

 reservation_key:='demand.'||p_allocation_key;
 -- Lock ALL involved capacity rows in deterministic order, BEFORE
 -- any dated flight changes, so a connecting journey is all-or-nothing.
 FOR leg IN SELECT DISTINCT u.flight_id
   FROM unnest(h.physical_flight_ids) AS u(flight_id)
   ORDER BY u.flight_id
 LOOP
  SELECT * INTO inv
  FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
  WHERE physical_flight_id=leg.flight_id FOR UPDATE;
  IF NOT FOUND OR inv.status<>'preflight_only'
   OR inv.passenger_capacity<h.passengers
   OR inv.passengers_held<h.passengers
   OR inv.passengers_held>inv.passenger_capacity
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_HELD_SEAT_CAPACITY_UNVERIFIED';END IF;
 END LOOP;
 -- Lock flight rows in the SAME deterministic physical key order.
 FOR leg IN SELECT u.flight_id,u.ordinality
 FROM unnest(h.physical_flight_ids)
 WITH ORDINALITY AS u(flight_id,ordinality)
 ORDER BY u.flight_id
 LOOP
  SELECT o.*,d.status AS schedule_status,d.operationally_verified,
   d.version AS current_schedule_version,
   fleet.fleet_status,commercial_plan.version AS current_commercial_version,
   commercial_plan.economy_fare_usd
  INTO flight
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 d
    ON d.id=o.schedule_id AND d.airline_id=o.airline_id
  JOIN airlinerra_game.airline_aircraft_inventory fleet
    ON fleet.id=o.aircraft_inventory_id
     AND fleet.airline_id=o.airline_id
  JOIN airlinerra_game.section9_route_commercial_plans_v1 commercial_plan
    ON commercial_plan.schedule_id=o.schedule_id
     AND commercial_plan.airline_id=o.airline_id
  WHERE o.schedule_id=split_part(leg.flight_id,':',1)::uuid
   AND o.flight_local_date=split_part(leg.flight_id,':',2)::date
   AND o.weekly_entry=split_part(leg.flight_id,':',3)::int
  FOR UPDATE OF o;
  IF NOT FOUND OR flight.source_kind<>'game_verified_saleable_schedule_v1'
   OR flight.booking_status<>'open'
   OR flight.schedule_status<>'active'
   OR flight.operationally_verified IS DISTINCT FROM true
   OR flight.current_schedule_version<>flight.schedule_version
   OR flight.fleet_status<>'in_service'
   OR flight.current_commercial_version IS NULL
   OR flight.economy_fare_usd IS NULL OR flight.economy_fare_usd<=0
   OR flight.verified_passenger_seats IS NULL
  THEN RETURN jsonb_build_object('status','blocked_unverified_saleable_hold_flight',
   'ticketsIssued',false,'bookingsCreated',false,'ledgerPosted',false);END IF;

  SELECT * INTO inv
   FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 c
   WHERE c.physical_flight_id=leg.flight_id;
  IF NOT FOUND OR inv.airline_id<>flight.airline_id
   OR inv.schedule_id<>flight.schedule_id
   OR inv.schedule_version<>flight.schedule_version
   OR inv.commercial_version<>flight.current_commercial_version
   OR inv.passenger_capacity<>flight.verified_passenger_seats
   OR inv.passengers_held<flight.booked_seats+h.passengers
   OR flight.booked_seats+h.passengers>flight.verified_passenger_seats
   OR inv.departure_utc<>flight.departure_utc
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_DEMAND_HOLD_VS_TICKET_INVENTORY_CONFLICT';END IF;
  SELECT * INTO previous FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
   WHERE b.occurrence_id=flight.id AND b.reservation_key=reservation_key;
  IF FOUND THEN
    IF previous.fare_class<>'economy'
      OR previous.seats_requested<>h.passengers
      OR previous.quoted_fare_usd<>flight.economy_fare_usd
      OR previous.reservation_status<>'reserved'
      OR previous.paid_upfront IS DISTINCT FROM false
      OR previous.recognized_revenue_usd<>0
    THEN RAISE EXCEPTION USING ERRCODE='23505',
     MESSAGE='SECTION9_DEMAND_TICKET_REPLAY_CHANGED';END IF;
    prior_count:=prior_count+1;
  END IF;
 END LOOP;
 IF prior_count=nlegs THEN
   RETURN jsonb_build_object('status','demand_tickets_already_issued',
   'legs',nlegs,'passengers',h.passengers,
   'ticketsIssued',true,'replayed',true,'newBookings',0,
   'ledgerPosted',false,'chargedNow',false);
 END IF;
 IF prior_count<>0 THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_PARTIALLY_ISSUED_CONNECTING_JOURNEY';END IF;

 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 SELECT release_state,enabled_at,crew_mode INTO active_release
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_release
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR active_release.release_state IS DISTINCT FROM 'enabled'
 OR active_release.enabled_at IS NULL
 OR active_release.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR execution_release.release_state IS DISTINCT FROM 'enabled'
 OR execution_release.enabled_at IS NULL
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_operating_game_releases',
   'ticketsIssued',false,'bookingsCreated',false,
   'chargedNow',false,'ledgerPosted',false);END IF;
 now_utc:=(hour_proof->>'gameHourUtc')::timestamptz;

 -- No timestamp or timezone is taken from demand input; both are looked
 -- up from the independently verified current schedule each time.
 FOR leg IN SELECT u.flight_id
  FROM unnest(h.physical_flight_ids) AS u(flight_id)
  ORDER BY u.flight_id
 LOOP
  SELECT o.id,o.schedule_id,o.flight_local_date,o.weekly_entry,
    o.departure_utc,o.economy_fare_usd
   INTO flight
   FROM (
     SELECT o.id,o.schedule_id,o.flight_local_date,o.weekly_entry,
       o.departure_utc,plan.economy_fare_usd
     FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
     JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
       ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
     WHERE o.schedule_id=split_part(leg.flight_id,':',1)::uuid
       AND o.flight_local_date=split_part(leg.flight_id,':',2)::date
       AND o.weekly_entry=split_part(leg.flight_id,':',3)::int
   ) o;
  IF coalesce((airlinerra_game.section9_verified_saleable_departure_window_v1(
     flight.schedule_id,flight.flight_local_date,flight.weekly_entry,now_utc)
       ->>'withinWindow')::boolean,false) IS DISTINCT FROM true
  OR EXISTS(
   SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
    WHERE m.schedule_id=flight.schedule_id
     AND m.flight_local_date=flight.flight_local_date
     AND m.weekly_entry=flight.weekly_entry
  ) THEN RETURN jsonb_build_object('status','blocked_departed_or_outside_booking_window',
   'ticketsIssued',false,'bookingsCreated',false,
   'chargedNow',false,'ledgerPosted',false);END IF;
 END LOOP;
 -- At this point all source holds, saleable dates, permits and time
 -- have been proven for EVERY leg. Physical seats were already held:
 -- increment booked_seats ONLY; never increment inventory held again.
 FOR leg IN SELECT u.flight_id
  FROM unnest(h.physical_flight_ids) AS u(flight_id)
  ORDER BY u.flight_id
 LOOP
  SELECT o.id,o.booked_seats,plan.economy_fare_usd INTO flight
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
   ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
  WHERE o.schedule_id=split_part(leg.flight_id,':',1)::uuid
   AND o.flight_local_date=split_part(leg.flight_id,':',2)::date
   AND o.weekly_entry=split_part(leg.flight_id,':',3)::int;
  UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 o
  SET booked_seats=booked_seats+h.passengers
  WHERE o.id=flight.id AND booked_seats=flight.booked_seats
   AND booked_seats+h.passengers<=verified_passenger_seats;
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_DEMAND_SEAT_ISSUANCE_CONCURRENT_CONFLICT';END IF;
  INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(
   occurrence_id,reservation_key,fare_class,seats_requested,
   quoted_fare_usd,reservation_status,paid_upfront,recognized_revenue_usd)
  VALUES(flight.id,reservation_key,'economy',h.passengers,
    flight.economy_fare_usd,'reserved',false,0)
  RETURNING id INTO issued_id;
  written:=written+1;
  total_quoted:=total_quoted+flight.economy_fare_usd*h.passengers;
 END LOOP;
 IF written<>nlegs THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_ATOMIC_DEMAND_TICKET_ISSUANCE_INCOMPLETE';END IF;
 RETURN jsonb_build_object('status','demand_hold_tickets_issued',
  'legs',nlegs,'passengersPerLeg',h.passengers,
  'ticketsIssued',true,'newBookings',written,
  'quotedGrossFareUsd',total_quoted,
  'chargedNow',false,'ledgerPosted',false,
  'revenueRecognized',false,'movementRecorded',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_promote_completed_demand_holds_batch_v1(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 verified_hour jsonb;
 current_release record;
 execution_release record;
 engine record;
 candidate record;
 result jsonb;
 seen integer:=0;
 issued_count integer:=0;
 passenger_bookings integer:=0;
 blocked_count integer:=0;
 blocked_status jsonb:='{}'::jsonb;
 state text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_DEMAND_CONVERSION_WORKER_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_INVALID_DEMAND_CONVERSION_BATCH_LIMIT';END IF;
 verified_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF verified_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_hour',
   'inspected',0,'ticketsIssued',0,'ledgerPosted',false);END IF;
 SELECT release_state,enabled_at,crew_mode INTO current_release
  FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_release
  FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO engine FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
  WHERE world_id=1;
 IF current_release.release_state IS DISTINCT FROM 'enabled'
 OR current_release.enabled_at IS NULL
 OR current_release.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR execution_release.release_state IS DISTINCT FROM 'enabled'
 OR execution_release.enabled_at IS NULL
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_unreleased_flight_engine',
    'inspected',0,'ticketsIssued',0,'ledgerPosted',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10029) THEN
 RETURN jsonb_build_object('status','demand_ticket_worker_in_progress',
    'inspected',0,'ticketsIssued',0,'ledgerPosted',false);END IF;
 FOR candidate IN
  SELECT DISTINCT h.source_allocation_key
   FROM airlinerra_game.section9_atomic_itinerary_holds_v1 h
   JOIN airlinerra_game.section9_capacity_hold_plan_items_v1 i
     ON i.allocation_key=h.source_allocation_key
   JOIN airlinerra_game.section9_capacity_hold_plans_v1 plan
     ON plan.id=i.plan_id
   WHERE h.status='preflight_only'
    AND h.cargo_tonnes=0 AND h.passengers>0
    AND plan.world_id=1 AND plan.status='completed'
    AND plan.next_allocation_seq=plan.allocation_count
    AND plan.completed_at IS NOT NULL
    AND i.physical_flight_ids=h.physical_flight_ids
    AND i.passengers=h.passengers AND i.cargo_tonnes=h.cargo_tonnes
    -- All legs must be on the verified, already-open saleable list.
    AND NOT EXISTS(
      SELECT 1 FROM unnest(h.physical_flight_ids) f(physical)
      WHERE NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
       WHERE o.schedule_id=split_part(f.physical,':',1)::uuid
        AND o.flight_local_date=split_part(f.physical,':',2)::date
        AND o.weekly_entry=split_part(f.physical,':',3)::integer
        AND o.booking_status='open'
        AND o.source_kind='game_verified_saleable_schedule_v1'
      )
    )
    -- Skip only when every physical leg has its durable reservation.
    -- A partially issued pair is not skipped: its issuer must reject it.
    AND EXISTS(
      SELECT 1 FROM unnest(h.physical_flight_ids) f(physical)
      WHERE NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
       JOIN airlinerra_game.section9_passenger_reservation_batches_v1 b
         ON b.occurrence_id=o.id
        AND b.reservation_key='demand.'||h.source_allocation_key
        AND b.reservation_status='reserved'
       WHERE o.schedule_id=split_part(f.physical,':',1)::uuid
        AND o.flight_local_date=split_part(f.physical,':',2)::date
        AND o.weekly_entry=split_part(f.physical,':',3)::integer
      )
    )
   ORDER BY h.source_allocation_key LIMIT p_limit
 LOOP
  result:=airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(
    candidate.source_allocation_key);
  seen:=seen+1;
  state:=result->>'status';
  IF state='demand_hold_tickets_issued'
   AND result->>'ticketsIssued'='true'
   AND result->>'ledgerPosted'='false'
   AND result->>'chargedNow'='false'
  THEN issued_count:=issued_count+1;
    passenger_bookings:=passenger_bookings+(result->>'newBookings')::integer;
  ELSIF state='demand_tickets_already_issued'
   AND result->>'ledgerPosted'='false'
   AND result->>'chargedNow'='false'
  THEN NULL;
  ELSIF state IN (
    'blocked_operating_game_releases',
    'blocked_departed_or_outside_booking_window',
    'blocked_unverified_saleable_hold_flight',
    'blocked_unfinished_demand_plan'
  ) AND result->>'ledgerPosted'='false'
  THEN blocked_count:=blocked_count+1;
    blocked_status:=jsonb_set(blocked_status,ARRAY[state],
      to_jsonb(coalesce((blocked_status->>state)::integer,0)+1),true);
  ELSE RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_UNSAFE_DEMAND_TICKET_CONVERSION_RESPONSE';END IF;
 END LOOP;
 RETURN jsonb_build_object(
 'status','verified_demand_ticket_conversion_batch_completed',
 'inspected',seen,'itinerariesIssued',issued_count,
 'reservationLegsCreated',passenger_bookings,
 'blocked',blocked_count,'blockedReasons',blocked_status,
 'futureFlightBookingsOnly',true,
 'ledgerPosted',false,'upfrontCharges',false,
 'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_promote_completed_demand_holds_batch_v1(integer) FROM PUBLIC,anon,authenticated,service_role;


-- Install one bounded private worker. While the engine is paused,
-- every run is a harmless zero-write no-op.
DO $demand_cron_setup$
BEGIN
 IF NOT EXISTS(
  SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-demand-tickets-v1'
 ) THEN
  PERFORM cron.schedule(
   'airlinerra-game-demand-tickets-v1',
   '*/5 * * * *',
   'SELECT airlinerra_game.section9_promote_completed_demand_holds_batch_v1(50);'
  );
 END IF;
END $demand_cron_setup$;
