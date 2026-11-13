-- Airlinerra World 1: post-arrival, real ticket revenue reconciliation.
-- FORECAST passengers and their estimated income are not earned revenue.
-- Verify immutable departure AND arrival movement records, exact schedule
-- version, actual durable reserved seats, fare total and verified game-hour.
-- A proposed settlement MUST match these totals before even preparing
-- UNPOSTED revenue intents. Cargo remains blocked until independently
-- evidenced cargo bookings; fuel/airport/maintenance proof and a genuine
-- cryptographic movement-event verifier are also still outstanding.
-- No money or financial ledger records are posted by these functions.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_postarrival_ticket_reconciliation_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 rec record;departure record;arrival record;ticket record;
 hour_proof jsonb;
 inspected_now timestamptz;
 success boolean:=false;
 posted boolean:=false;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_POSTARRIVAL_FINANCE_REVIEWER_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR
   p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_INVALID_FINANCE_PHYSICAL_FLIGHT_ID';END IF;
 SELECT c.physical_flight_id,c.schedule_id,c.airline_id,
  c.local_departure_date,c.weekly_entry,
  c.schedule_version,c.commercial_version,c.departure_utc,c.arrival_utc,
  c.passenger_capacity,c.passengers_held,
  o.id AS occurrence_id,o.booked_seats,o.verified_passenger_seats,
  o.booking_status,o.source_kind,o.schedule_version AS occurrence_version,
  o.departure_utc AS occurrence_departure,o.arrival_utc AS occurrence_arrival,
  s.status AS schedule_status,s.operationally_verified,
  s.version AS current_schedule_version,
  commercial.version AS current_commercial_version,
  fleet.fleet_status
 INTO rec
 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 c
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o
  ON o.schedule_id=c.schedule_id
   AND o.flight_local_date=c.local_departure_date
   AND o.weekly_entry=c.weekly_entry
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=c.schedule_id AND s.airline_id=c.airline_id
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=s.aircraft_inventory_id AND fleet.airline_id=s.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 commercial
  ON commercial.schedule_id=s.id AND commercial.airline_id=s.airline_id
 WHERE c.physical_flight_id=p_physical_flight_id;
 IF NOT FOUND
 OR rec.physical_flight_id IS DISTINCT FROM
    rec.schedule_id::text||':'||rec.local_departure_date::text||':'||rec.weekly_entry::text
 OR rec.source_kind IS DISTINCT FROM 'game_verified_saleable_schedule_v1'
 OR rec.booking_status NOT IN ('open','closed')
 OR rec.schedule_status IS DISTINCT FROM 'active'
 OR rec.operationally_verified IS DISTINCT FROM true
 OR rec.fleet_status IS DISTINCT FROM 'in_service'
 OR rec.schedule_version IS DISTINCT FROM rec.current_schedule_version
 OR rec.schedule_version IS DISTINCT FROM rec.occurrence_version
 OR rec.commercial_version IS DISTINCT FROM rec.current_commercial_version
 OR rec.departure_utc IS DISTINCT FROM rec.occurrence_departure
 OR rec.arrival_utc IS DISTINCT FROM rec.occurrence_arrival
 OR rec.passenger_capacity IS DISTINCT FROM rec.verified_passenger_seats
 OR rec.booked_seats>rec.passengers_held
 OR rec.passengers_held>rec.passenger_capacity
 THEN RETURN jsonb_build_object(
   'status','blocked_unverified_flight_or_ticket_inventory',
   'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);END IF;

 SELECT * INTO departure
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.flight_occurrence_id=p_physical_flight_id AND m.phase='departed';
 IF NOT FOUND THEN
  RETURN jsonb_build_object('status','blocked_missing_departure',
  'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);
 END IF;
 SELECT * INTO arrival
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.flight_occurrence_id=p_physical_flight_id AND m.phase='arrived';
 IF NOT FOUND THEN
  RETURN jsonb_build_object('status','blocked_missing_arrival',
  'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);
 END IF;
 IF departure.engine_event_id IS NULL OR arrival.engine_event_id IS NULL
 OR departure.schedule_id IS DISTINCT FROM rec.schedule_id
 OR arrival.schedule_id IS DISTINCT FROM rec.schedule_id
 OR departure.airline_id IS DISTINCT FROM rec.airline_id
 OR arrival.airline_id IS DISTINCT FROM rec.airline_id
 OR departure.schedule_version IS DISTINCT FROM rec.schedule_version
 OR arrival.schedule_version IS DISTINCT FROM rec.schedule_version
 OR departure.scheduled_departure_utc IS DISTINCT FROM rec.departure_utc
 OR arrival.scheduled_arrival_utc IS DISTINCT FROM rec.arrival_utc
 OR departure.actual_event_utc IS NULL
 OR arrival.actual_event_utc IS NULL
 OR arrival.actual_event_utc<=departure.actual_event_utc
 THEN RETURN jsonb_build_object(
   'status','blocked_missing_or_mismatched_departure_and_arrival',
   'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);END IF;

 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object(
   'status','blocked_unverified_postarrival_game_hour',
   'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);END IF;
 inspected_now:=(hour_proof->>'gameHourUtc')::timestamptz;
 IF arrival.actual_event_utc>inspected_now
 THEN RETURN jsonb_build_object(
   'status','blocked_arrival_not_reached',
   'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);END IF;
 SELECT count(*) FILTER(WHERE b.reservation_status='reserved')::int AS reserved_rows,
  coalesce(sum(b.seats_requested) FILTER(
    WHERE b.reservation_status='reserved'),0)::int AS actual_passengers,
  coalesce(sum(b.seats_requested*b.quoted_fare_usd) FILTER(
    WHERE b.reservation_status='reserved'),0)::numeric(16,2) AS actual_revenue,
  coalesce(bool_and(
     b.paid_upfront=false AND b.recognized_revenue_usd=0
     AND b.reservation_status IN ('reserved','cancelled')),true)
      AS no_premature_accounting,
  count(*)::int AS all_rows
 INTO ticket
 FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
 WHERE b.occurrence_id=rec.occurrence_id;
 IF ticket.no_premature_accounting IS DISTINCT FROM true
 OR ticket.actual_passengers IS DISTINCT FROM rec.booked_seats
 OR ticket.actual_passengers>rec.passenger_capacity
 THEN RETURN jsonb_build_object(
   'status','blocked_ticket_seat_or_revenue_reconciliation_mismatch',
   'reconciled',false,'ledgerPosted',false,'bookingsCreated',false);END IF;
 SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 p
   WHERE p.physical_flight_id=p_physical_flight_id
 ) INTO posted;
 RETURN jsonb_build_object(
 'status',CASE WHEN posted THEN 'already_posted_do_not_rebook'
    ELSE 'postarrival_ticket_totals_reconciled' END,
 'physicalFlightId',p_physical_flight_id,
 'ticketPassengers',ticket.actual_passengers,
 'ticketIncomeUsd',ticket.actual_revenue,
 'reservedTicketBatches',ticket.reserved_rows,
 'gameHourAtOrAfterArrival',true,
 'reconciled',true,
 'financeAlreadyPosted',posted,
 'requiresSeparateFuelAirportAndMaintenanceCostProofs',true,
 'movementSignatureVerifiedIndependently',false,
 'readyToPostCompleteFlightFinance',false,
 'ledgerPosted',false,
 'bookingsCreated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_postarrival_ticket_reconciliation_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_verified_settlement_batch_v1(p_world_id smallint, p_target_date date, p_after_flight_id text DEFAULT NULL::text, p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE jobs_count int;materialized_ok bool;source_proofs jsonb;
 ticket_proof jsonb;
 rec record;oper record;processed int:=0;new_count int:=0;new_intents int:=0;
 added int;cursor_id text;exists_before int;
BEGIN
 IF p_world_id<>1 OR p_target_date IS NULL OR
  p_target_date NOT BETWEEN DATE '2000-01-01' AND DATE '2200-12-31'
  OR p_limit NOT BETWEEN 1 AND 250
  OR (p_after_flight_id IS NOT NULL AND
       (length(p_after_flight_id)>120 OR length(p_after_flight_id)<10))
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PREPARE_BATCH'; END IF;

 -- Three completed demand days are required to account for inbound,
 -- outbound and midnight-crossing connections to the same physical flight.
 SELECT count(*),coalesce(bool_and(
  j.status='completed' AND j.completed_flight_rows IS NOT NULL
  AND j.completed_flight_rows=(
    SELECT count(*) FROM airlinerra_game.section9_completed_flight_contributions_v1 c
    WHERE c.job_id=j.id)),false)
 INTO jobs_count,materialized_ok
 FROM airlinerra_game.section9_demand_jobs_v1 j
 WHERE j.world_id=p_world_id AND j.model_version='network_forecast_v1'
   AND j.game_date BETWEEN p_target_date-1 AND p_target_date+1;
 IF jobs_count<>3 OR NOT materialized_ok THEN
  RETURN jsonb_build_object('status','blocked_incomplete_or_unmaterialized_forecasts',
   'gameDate',p_target_date,'completedDays',jobs_count,
   'materialized',materialized_ok,'settlementPrepared',false,
   'ledgerPosted',false,'bookingsCreated',false);
 END IF;

 SELECT jsonb_agg(jsonb_build_object('jobId',id,'attempt',attempt,
  'gameDate',game_date) ORDER BY game_date)
 INTO source_proofs FROM airlinerra_game.section9_demand_jobs_v1
 WHERE world_id=p_world_id AND model_version='network_forecast_v1'
  AND game_date BETWEEN p_target_date-1 AND p_target_date+1;

 -- Work is bounded and indexed by actual local departure date. No
 -- scans across 3,141 airports or arbitrary player market pairs.
 FOR rec IN
  WITH selected_flights AS (
   SELECT DISTINCT c.physical_flight_id
   FROM airlinerra_game.section9_completed_flight_contributions_v1 c
   JOIN airlinerra_game.section9_demand_jobs_v1 j ON j.id=c.job_id
   WHERE j.world_id=p_world_id AND j.model_version='network_forecast_v1'
    AND j.game_date BETWEEN p_target_date-1 AND p_target_date+1
    AND c.local_departure_date=p_target_date
    AND (p_after_flight_id IS NULL OR c.physical_flight_id>p_after_flight_id)
   ORDER BY c.physical_flight_id
   LIMIT p_limit
  )
  SELECT c.physical_flight_id, min(c.schedule_id::text)::uuid AS schedule_id,
    min(c.airline_id::text)::uuid AS airline_id,
    min(c.schedule_version) AS schedule_version,
    min(c.commercial_version) AS commercial_version,
    min(c.passenger_seats) AS passenger_seats,
    min(c.cargo_capacity_tonnes) AS cargo_capacity_tonnes,
    sum(c.passengers)::integer AS passengers,
    sum(c.cargo_tonnes)::numeric(12,3) AS cargo_tonnes,
    sum(c.ticket_revenue_usd)::numeric(16,2) AS ticket_revenue_usd,
    sum(c.cargo_revenue_usd)::numeric(16,2) AS cargo_revenue_usd,
    count(DISTINCT c.job_id) AS contributor_count,
    count(DISTINCT c.schedule_id) AS schedule_id_variants,
    count(DISTINCT c.airline_id) AS airline_id_variants,
    count(DISTINCT c.schedule_version) AS schedule_version_variants,
    count(DISTINCT c.commercial_version) AS commercial_version_variants,
    count(DISTINCT c.passenger_seats) AS passenger_capacity_variants,
    count(DISTINCT c.cargo_capacity_tonnes) AS cargo_capacity_variants,
    count(DISTINCT c.row_payload->>'departureUtc') AS departure_variants,
    count(DISTINCT c.row_payload->>'arrivalUtc') AS arrival_variants,
    min((c.row_payload->>'weeklyEntry')::integer) AS weekly_entry
  FROM selected_flights sf
  JOIN airlinerra_game.section9_completed_flight_contributions_v1 c
    ON c.physical_flight_id=sf.physical_flight_id
   AND c.local_departure_date=p_target_date
  JOIN airlinerra_game.section9_demand_jobs_v1 j ON j.id=c.job_id
   AND j.world_id=p_world_id
   AND j.game_date BETWEEN p_target_date-1 AND p_target_date+1
   AND j.model_version='network_forecast_v1'
  GROUP BY c.physical_flight_id
  ORDER BY c.physical_flight_id
 LOOP
  IF rec.contributor_count NOT BETWEEN 1 AND 3 OR
    rec.schedule_id_variants<>1 OR rec.airline_id_variants<>1 OR
    rec.schedule_version_variants<>1 OR rec.commercial_version_variants<>1 OR
    rec.passenger_capacity_variants<>1 OR rec.cargo_capacity_variants<>1 OR
    rec.departure_variants<>1 OR rec.arrival_variants<>1 OR
    rec.passengers>rec.passenger_seats OR
    rec.cargo_tonnes>rec.cargo_capacity_tonnes OR
    rec.ticket_revenue_usd<0 OR rec.cargo_revenue_usd<0
  THEN RAISE EXCEPTION USING ERRCODE='22023',
     MESSAGE='SECTION9_CROSS_DAY_CAPACITY_OR_VERSION_CONFLICT';END IF;
  -- Independently recheck activated schedule, verified capacity, exact
  -- version and fleet status under a shared row lock.
  SELECT d.airline_id,d.version,d.status,d.operationally_verified,
   d.weekly_schedule,d.aircraft_inventory_id,f.fleet_status,
   cap.passenger_seats,cap.cargo_capacity_tonnes,
   cap.schedule_version,plan.version AS commercial_version
  INTO oper
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.airline_aircraft_inventory f
    ON f.id=d.aircraft_inventory_id AND f.airline_id=d.airline_id
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
    ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
  JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
    ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
  WHERE d.id=rec.schedule_id
  FOR SHARE OF d,f,cap,plan;
  IF NOT FOUND OR oper.status<>'active' OR
    oper.operationally_verified IS DISTINCT FROM true OR
    oper.fleet_status<>'in_service' OR
    oper.airline_id<>rec.airline_id OR
    oper.version<>rec.schedule_version OR
    oper.schedule_version<>rec.schedule_version OR
    oper.commercial_version<>rec.commercial_version OR
    oper.passenger_seats<>rec.passenger_seats OR
    oper.cargo_capacity_tonnes<>rec.cargo_capacity_tonnes OR
    rec.weekly_entry NOT BETWEEN 1 AND jsonb_array_length(oper.weekly_schedule) OR
    ((oper.weekly_schedule->(rec.weekly_entry-1)->>'day')::int
      IS DISTINCT FROM extract(isodow from p_target_date)::int-1)
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATION_NOT_ACTIVATED_OR_VERIFIED';END IF;
  IF NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
    WHERE slot.schedule_id=rec.schedule_id AND slot.direction='departure'
  ) OR NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
    WHERE slot.schedule_id=rec.schedule_id AND slot.direction='arrival'
  ) THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_VERIFIED_AIRPORT_SLOTS_MISSING'; END IF;

  -- Forecast demand is not ticket income. Require an independently
  -- recorded departure AND arrival and cross-check actual durable ticket
  -- bookings, both seat count and gross fare value. All other costs and
  -- final ledger posting remain separate.
  ticket_proof:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(
    rec.physical_flight_id);
  IF ticket_proof->>'status' IS DISTINCT FROM 'postarrival_ticket_totals_reconciled'
   OR ticket_proof->>'reconciled' IS DISTINCT FROM 'true'
   OR ticket_proof->>'financeAlreadyPosted' IS DISTINCT FROM 'false'
   OR ticket_proof->>'ledgerPosted' IS DISTINCT FROM 'false'
   OR (ticket_proof->>'ticketPassengers')::integer IS DISTINCT FROM rec.passengers
   OR (ticket_proof->>'ticketIncomeUsd')::numeric IS DISTINCT FROM rec.ticket_revenue_usd
   OR rec.cargo_tonnes>0 OR rec.cargo_revenue_usd>0
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_DEMAND_FORECAST_NOT_RECONCILED_WITH_ARRIVED_TICKET_BOOKINGS';
  END IF;

  INSERT INTO airlinerra_game.section9_prepared_occurrence_settlements_v1(
   physical_flight_id,schedule_id,airline_id,local_departure_date,
   schedule_version,commercial_version,passenger_seats,passengers,
   cargo_capacity_tonnes,cargo_tonnes,ticket_revenue_usd,cargo_revenue_usd,
   source_job_proofs)
  VALUES(rec.physical_flight_id,rec.schedule_id,rec.airline_id,
   p_target_date,rec.schedule_version,rec.commercial_version,
   rec.passenger_seats,rec.passengers,rec.cargo_capacity_tonnes,
   rec.cargo_tonnes,rec.ticket_revenue_usd,rec.cargo_revenue_usd,
   source_proofs)
  ON CONFLICT (physical_flight_id) DO NOTHING;
  GET DIAGNOSTICS added=ROW_COUNT;
  new_count:=new_count+added;
  IF EXISTS(
   SELECT 1 FROM airlinerra_game.section9_prepared_occurrence_settlements_v1 x
   WHERE x.physical_flight_id=rec.physical_flight_id
    AND (x.schedule_id<>rec.schedule_id OR x.airline_id<>rec.airline_id
     OR x.local_departure_date<>p_target_date
     OR x.schedule_version<>rec.schedule_version
     OR x.commercial_version<>rec.commercial_version
     OR x.passenger_seats<>rec.passenger_seats OR x.passengers<>rec.passengers
     OR x.cargo_capacity_tonnes<>rec.cargo_capacity_tonnes
     OR x.cargo_tonnes<>rec.cargo_tonnes
     OR x.ticket_revenue_usd<>rec.ticket_revenue_usd
     OR x.cargo_revenue_usd<>rec.cargo_revenue_usd
     OR x.source_job_proofs<>source_proofs)
  ) THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_PREPARED_SETTLEMENT_REPLAY_CONFLICT';END IF;

  IF rec.ticket_revenue_usd>0 THEN
   INSERT INTO airlinerra_game.section9_unposted_revenue_intents_v1(
    physical_flight_id,revenue_kind,airline_id,amount_usd)
   VALUES(rec.physical_flight_id,'PASSENGER_REVENUE',
    rec.airline_id,rec.ticket_revenue_usd)
   ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS added=ROW_COUNT;
   new_intents:=new_intents+added;
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_unposted_revenue_intents_v1
     WHERE physical_flight_id=rec.physical_flight_id
      AND revenue_kind='PASSENGER_REVENUE'
      AND airline_id=rec.airline_id AND amount_usd=rec.ticket_revenue_usd)
   THEN RAISE EXCEPTION USING ERRCODE='23505',
     MESSAGE='SECTION9_PASSENGER_REVENUE_INTENT_CONFLICT';END IF;
  END IF;
  IF rec.cargo_revenue_usd>0 THEN
   INSERT INTO airlinerra_game.section9_unposted_revenue_intents_v1(
    physical_flight_id,revenue_kind,airline_id,amount_usd)
   VALUES(rec.physical_flight_id,'CARGO_REVENUE',
    rec.airline_id,rec.cargo_revenue_usd)
   ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS added=ROW_COUNT;
   new_intents:=new_intents+added;
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_unposted_revenue_intents_v1
     WHERE physical_flight_id=rec.physical_flight_id
      AND revenue_kind='CARGO_REVENUE'
      AND airline_id=rec.airline_id AND amount_usd=rec.cargo_revenue_usd)
   THEN RAISE EXCEPTION USING ERRCODE='23505',
     MESSAGE='SECTION9_CARGO_REVENUE_INTENT_CONFLICT';END IF;
  END IF;
  processed:=processed+1;cursor_id:=rec.physical_flight_id;
 END LOOP;

 RETURN jsonb_build_object('status','prepared_unposted',
  'gameDate',p_target_date,'flightsInspected',processed,
  'newProofs',new_count,'newRevenueIntents',new_intents,
  'nextFlightCursor',cursor_id,
  'hasMore',processed=p_limit,
  'ledgerPosted',false,'bookingsCreated',false,
  'operationalActivationChanged',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_prepare_verified_settlement_batch_v1(smallint,date,text,integer) FROM PUBLIC,anon,authenticated,service_role;
