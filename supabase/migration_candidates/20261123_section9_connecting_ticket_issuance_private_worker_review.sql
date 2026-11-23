-- REVIEW-ONLY SQL CANDIDATE. NOT an automatic deployment migration.
-- Generated from original private two-leg worker. Do not apply without approval.
-- Verified defect fixes: local variable disambiguation; existing-ticket replay hold check.
-- All other function behavior, release gates, worker permissions and accounting flags retained.
-- Tested against disposable PostgreSQL; see tests/sql/section9_disposable_real_connecting_ticket_acceptance.sql.
--
-- Fail closed if the old function was replaced or public execution was granted.
DO $guard$
DECLARE prior_sql text;privileges_ok boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
   RAISE EXCEPTION 'CONNECTING_TICKET_PATCH_POSTGRES_ONLY';END IF;
 SELECT pg_get_functiondef('airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(text)'::regprocedure)
 INTO prior_sql;
 IF prior_sql IS NULL
 OR position('b.reservation_key=reservation_key' IN prior_sql)=0
 OR position('inv.passengers_held<flight.booked_seats+h.passengers' IN prior_sql)=0
 OR position('SECTION9_DEMAND_TICKET_WORKER_ONLY' IN prior_sql)=0
 OR (SELECT prosecdef FROM pg_proc WHERE oid='airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(text)'::regprocedure)
 THEN RAISE EXCEPTION 'CONNECTING_TICKET_PATCH_UNEXPECTED_SOURCE';END IF;
 IF EXISTS(
  SELECT 1 FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
  CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
  JOIN pg_roles role ON role.oid=acl.grantee
  WHERE p.oid='airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(text)'::regprocedure
    AND role.rolname IN ('anon','authenticated','service_role') AND acl.privilege_type='EXECUTE'
 ) THEN RAISE EXCEPTION 'CONNECTING_TICKET_PATCH_UNSAFE_EXECUTE_PRIVILEGE';END IF;
END $guard$;

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
 v_reservation_key text; total_quoted numeric:=0;
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

 v_reservation_key:='demand.'||p_allocation_key;
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
   OR (inv.passengers_held<flight.booked_seats+h.passengers
     AND NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1 prior_booking
       WHERE prior_booking.occurrence_id=flight.id
         AND prior_booking.reservation_key=v_reservation_key))
   OR flight.booked_seats+h.passengers>flight.verified_passenger_seats
   OR inv.departure_utc<>flight.departure_utc
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_DEMAND_HOLD_VS_TICKET_INVENTORY_CONFLICT';END IF;
  SELECT * INTO previous FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
   WHERE b.occurrence_id=flight.id AND b.reservation_key=v_reservation_key;
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
  VALUES(flight.id,v_reservation_key,'economy',h.passengers,
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
REVOKE ALL ON FUNCTION airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(text)
  FROM PUBLIC, anon, authenticated, service_role;
-- Private worker execution remains with function owner (postgres).
