-- Two-phase independent certification: COMMIT ONLY ALREADY-SAVED signed
-- schedule drafts; attempt to self-certify a newly inserted schedule is
-- impossible because external signing needs a persisted draft/version.
-- Both pre-certified legs + authoritative clock + approved game finance +
-- aircraft game-fuel release + verified cabin capacity are required.
-- If either leg cannot become active AND open each eligible ticket date,
-- raise and roll back both activation writes and all ticket inventory.
-- This function never writes to the airline ledger or issues licences;
-- it neither creates reservations nor moves aircraft on its own.
-- Initial release in World 1 is PAUSED, so live money and flights stay off.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(p_player uuid, p_airline uuid, p_out_schedule uuid, p_back_schedule uuid, p_out_version integer, p_back_version integer, p_game_day date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 v_airline record;v_fleet record;v_out record;v_back record;
 v_activation record;v_execution record;v_finance record;v_engine record;
 v_fuel_model record;v_payload record;v_config record;
 v_plan_out record;v_plan_back record;
 v_hour jsonb;v_signed_count int;
 v_out_activated jsonb;v_back_activated jsonb;
 v_capacity jsonb;v_ticket jsonb;v_window jsonb;
 v_item record;v_date date;v_weekday int;v_index int;
 v_seats integer;v_opened_out integer:=0;v_opened_back integer:=0;
 v_flights_considered integer:=0;v_active integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CERTIFIED_PAIR_PRIVATE_GAME_ENGINE_ONLY';END IF;
 IF p_player IS NULL OR p_airline IS NULL
  OR p_out_schedule IS NULL OR p_back_schedule IS NULL
  OR p_out_schedule=p_back_schedule
  OR p_out_version IS NULL OR p_back_version IS NULL
  OR p_out_version<1 OR p_back_version<1
  OR p_game_day IS NULL OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_CERTIFIED_PAIR_INVALID_INPUT';END IF;

 -- No schedule, passenger, fuel or ledger changes while ANY release is paused.
 SELECT * INTO v_activation FROM airlinerra_game.section9_activation_release_policy_v1
 WHERE world_id=1 FOR SHARE;
 SELECT * INTO v_execution FROM airlinerra_game.section9_trusted_execution_release_policy_v1
 WHERE world_id=1 FOR SHARE;
 SELECT * INTO v_finance FROM airlinerra_game.section9_flight_finance_posting_release_v1
 WHERE world_id=1 FOR SHARE;
 SELECT * INTO v_engine FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
 WHERE world_id=1;
 v_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF v_activation.release_state IS DISTINCT FROM 'enabled'
 OR v_activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR v_activation.enabled_at IS NULL OR v_activation.reviewed_at IS NULL
 OR v_execution.release_state IS DISTINCT FROM 'enabled'
 OR v_execution.enabled_at IS NULL
 OR v_finance.release_state IS DISTINCT FROM 'approved'
 OR v_finance.approved_at IS NULL
 OR v_engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR v_engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR v_engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 OR v_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR (v_hour->>'gameDate')::date IS DISTINCT FROM p_game_day
 THEN RETURN jsonb_build_object(
  'status','blocked_operating_or_finance_release',
  'pairActivated',false,'ticketsOpened',0,
  'bookingCreated',false,'ledgerPosted',false);END IF;

 -- Deterministic lock order for airline, aircraft and both draft schedules.
 SELECT a.id,a.owner_player_id,a.world_id INTO v_airline
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships wm
  ON wm.world_id=a.world_id AND wm.player_id=p_player
   AND wm.state='active'
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player
 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CERTIFIED_PAIR_AIRLINE_NOT_OWNED';END IF;
 SELECT * INTO v_out FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.id=p_out_schedule AND s.airline_id=p_airline AND s.world_id=1;
 SELECT * INTO v_back FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.id=p_back_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF v_out.id IS NULL OR v_back.id IS NULL
 OR v_out.aircraft_inventory_id IS DISTINCT FROM v_back.aircraft_inventory_id
 THEN RETURN jsonb_build_object(
  'status','blocked_pair_draft_not_found_or_aircraft_mismatch',
  'pairActivated',false,'ticketsOpened',0,'ledgerPosted',false);END IF;

 SELECT * INTO v_fleet FROM airlinerra_game.airline_aircraft_inventory f
 WHERE f.id=v_out.aircraft_inventory_id AND f.airline_id=p_airline
 FOR UPDATE;
 PERFORM 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.id IN(p_out_schedule,p_back_schedule)
 ORDER BY s.id FOR UPDATE;
 GET DIAGNOSTICS v_active=ROW_COUNT;
 IF v_active<>2 OR v_fleet.fleet_status IS DISTINCT FROM 'in_service'
 OR v_fleet.ownership_type NOT IN ('owned','leased')
 OR v_fleet.configuration_id IS DISTINCT FROM v_out.configuration_id
 OR v_fleet.configuration_id IS DISTINCT FROM v_back.configuration_id
 THEN RETURN jsonb_build_object(
  'status','blocked_aircraft_or_draft_lock_changed',
  'pairActivated',false,'ticketsOpened',0,'ledgerPosted',false);END IF;
 -- Refresh after locking, rather than relying on pre-lock draft rows.
 SELECT * INTO v_out FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_out_schedule AND airline_id=p_airline;
 SELECT * INTO v_back FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_back_schedule AND airline_id=p_airline;
 IF v_out.version IS DISTINCT FROM p_out_version
 OR v_back.version IS DISTINCT FROM p_back_version
 OR v_out.status IS DISTINCT FROM 'draft'
 OR v_back.status IS DISTINCT FROM 'draft'
 OR v_out.operationally_verified IS DISTINCT FROM false
 OR v_back.operationally_verified IS DISTINCT FROM false
 OR v_out.origin_airport_key IS DISTINCT FROM v_back.destination_airport_key
 OR v_out.destination_airport_key IS DISTINCT FROM v_back.origin_airport_key
 OR v_out.flight_number=v_back.flight_number
 THEN RETURN jsonb_build_object(
  'status','blocked_pair_stale_or_not_a_return_route',
  'pairActivated',false,'ticketsOpened',0,'ledgerPosted',false);END IF;

 -- The aircraft configuration must have separately prepared game fuel
 -- eligibility and a verified simultaneous passenger payload.
 SELECT * INTO v_fuel_model
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
 WHERE configuration_id=v_fleet.configuration_id;
 SELECT * INTO v_payload
 FROM airlinerra.aircraft_service_payload_game_v1
 WHERE configuration_id=v_fleet.configuration_id;
 SELECT * INTO v_config
 FROM airlinerra.aircraft_configurations
 WHERE id=v_fleet.configuration_id;
 IF v_config.use_type IS DISTINCT FROM 'passenger'
 OR v_fuel_model.game_calculation_ready IS DISTINCT FROM true
 OR v_fuel_model.operational_dispatch_release IS DISTINCT FROM 'RELEASED'
 OR v_fuel_model.financial_settlement_release IS DISTINCT FROM 'RELEASED'
 OR v_payload.simultaneous_passenger_seats IS NULL
 OR v_payload.simultaneous_passenger_seats<=0
 OR v_config.maximum_passenger_seats<=0
 THEN RETURN jsonb_build_object(
  'status','blocked_unreleased_game_fuel_or_unverified_passenger_payload',
  'pairActivated',false,'ticketsOpened',0,'ledgerPosted',false);END IF;
 v_seats:=least(1000,v_payload.simultaneous_passenger_seats,
  v_config.maximum_passenger_seats);
 IF v_seats NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION USING ERRCODE='23514',
    MESSAGE='SECTION9_PAIR_INVALID_SIMULTANEOUS_SEAT_CAPACITY';END IF;
 SELECT * INTO v_plan_out
 FROM airlinerra_game.section9_route_commercial_plans_v1
 WHERE schedule_id=p_out_schedule AND airline_id=p_airline FOR SHARE;
 SELECT * INTO v_plan_back
 FROM airlinerra_game.section9_route_commercial_plans_v1
 WHERE schedule_id=p_back_schedule AND airline_id=p_airline FOR SHARE;
 IF v_plan_out.version IS NULL OR v_plan_back.version IS NULL
 OR v_plan_out.economy_fare_usd<=0 OR v_plan_back.economy_fare_usd<=0
 OR v_plan_out.economy_fare_usd IS NULL
 OR v_plan_back.economy_fare_usd IS NULL
 OR v_plan_out.marketing_budget_usd_per_day IS DISTINCT FROM 0
 OR v_plan_back.marketing_budget_usd_per_day IS DISTINCT FROM 0
 THEN RETURN jsonb_build_object(
   'status','blocked_missing_or_unsupported_commercial_fare',
   'pairActivated',false,'ticketsOpened',0,'ledgerPosted',false);END IF;

 -- Five individually signed, non-crew certifications must ALREADY exist
 -- for each saved draft. They cannot be invented inside this transaction.
 SELECT count(*)::int INTO v_signed_count
 FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
 JOIN airlinerra_game.section9_operational_certification_events_v1 e
 ON e.event_id=c.last_verified_event_id
  AND e.schedule_id=c.schedule_id
  AND e.schedule_version=c.schedule_version
  AND e.clearance_type=c.clearance_type
  AND e.action='certify'
 WHERE c.schedule_id IN(p_out_schedule,p_back_schedule)
  AND c.airline_id=p_airline AND c.review_status='certified'
  AND c.clearance_type<>'crew_duty'
  AND c.valid_from_game_date<=p_game_day
  AND c.valid_to_game_date>=p_game_day+p_days;
 IF v_signed_count<>10 THEN
  RETURN jsonb_build_object(
    'status','blocked_ten_independent_signed_certifications_missing',
    'certificationsFound',v_signed_count,
    'pairActivated',false,'ticketsOpened',0,'ledgerPosted',false);END IF;

 -- Activation and seat inventory are ONE database transaction.
 -- Every downstream result must be independently verified or RAISE,
 -- which automatically undoes both activated schedules and all tickets.
 v_out_activated:=airlinerra_game.section9_commit_certified_schedule_activation_v1(
   p_player,p_airline,p_out_schedule,p_out_version,p_game_day,p_days);
 v_back_activated:=airlinerra_game.section9_commit_certified_schedule_activation_v1(
   p_player,p_airline,p_back_schedule,p_back_version,p_game_day,p_days);
 IF v_out_activated->>'status' IS DISTINCT FROM 'certified_schedule_activated'
 OR v_back_activated->>'status' IS DISTINCT FROM 'certified_schedule_activated'
 OR v_out_activated->>'scheduleActivated' IS DISTINCT FROM 'true'
 OR v_back_activated->>'scheduleActivated' IS DISTINCT FROM 'true'
 OR v_out_activated->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR v_back_activated->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PAIR_ACTIVATION_CERTIFICATION_FAILED_FULL_ROLLBACK';END IF;

 FOR v_item IN
 SELECT unnest(ARRAY[p_out_schedule,p_back_schedule]::uuid[]) schedule_id
 LOOP
  v_capacity:=airlinerra_game.section9_register_verified_schedule_capacity_v1(
    v_item.schedule_id,p_airline,v_seats,0,
    'GAME_SIMULTANEOUS_PASSENGER_PAYLOAD_CERTIFIED_V1');
  IF v_capacity->>'verified' IS DISTINCT FROM 'true'
   OR (v_capacity->>'passengerSeats')::integer<>v_seats
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PAIR_VERIFIED_CAPACITY_FAILED_FULL_ROLLBACK';END IF;
 END LOOP;

 -- Open ALL eligible departures for the next seven exact 24-hour days.
 -- No passenger demand or actual sale is generated by this step.
 FOR v_item IN
 SELECT s.id,s.weekly_schedule
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.id IN(p_out_schedule,p_back_schedule) AND s.status='active'
 ORDER BY s.id
 LOOP
  FOR v_date IN
    SELECT d::date FROM generate_series(
     p_game_day::timestamp,(p_game_day+7)::timestamp,
     interval '1 day') AS d
  LOOP
   v_weekday:=extract(isodow from v_date)::integer-1;
   FOR v_index IN 1..jsonb_array_length(v_item.weekly_schedule)
   LOOP
    IF (v_item.weekly_schedule->(v_index-1)->>'day')::integer=v_weekday
    THEN
     v_window:=airlinerra_game.section9_verified_saleable_departure_window_v1(
       v_item.id,v_date,v_index,(v_hour->>'gameHourUtc')::timestamptz);
     IF v_window->>'withinWindow' IS DISTINCT FROM 'true' THEN CONTINUE;END IF;
     v_flights_considered:=v_flights_considered+1;
     v_ticket:=airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(
       v_item.id,v_date,v_index);
     IF v_ticket->>'status' IS DISTINCT FROM 'verified_ticket_sales_open'
      OR v_ticket->>'sevenDayWindowVerified' IS DISTINCT FROM 'true'
      OR (v_ticket->>'passengerSeats')::integer<>v_seats
      OR v_ticket->>'ledgerPosted' IS DISTINCT FROM 'false'
     THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_PAIR_TICKET_INVENTORY_FAILED_FULL_ROLLBACK';END IF;
     IF v_item.id=p_out_schedule THEN
       v_opened_out:=v_opened_out+1;
     ELSE v_opened_back:=v_opened_back+1;END IF;
    END IF;
   END LOOP;
  END LOOP;
 END LOOP;
 IF v_opened_out<1 OR v_opened_back<1
  OR v_opened_out+v_opened_back<>v_flights_considered
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_PAIR_SEVEN_DAY_BOOKING_WINDOW_INCOMPLETE_FULL_ROLLBACK';END IF;

 RETURN jsonb_build_object(
  'status','certified_roundtrip_schedules_activated_and_tickets_open',
  'outboundScheduleId',p_out_schedule,
  'returnScheduleId',p_back_schedule,
  'verifiedPassengerSeatsPerFlight',v_seats,
  'outboundSaleableOccurrences',v_opened_out,
  'returnSaleableOccurrences',v_opened_back,
  'operatingSchedulesActivated',true,
  'ticketSalesOpen',true,'ticketsSold',0,
  'flightDeparted',false,'ledgerPosted',false,
  'crewMode','deferred_phase1',
  'certifiedHorizonDays',p_days);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_commit_certified_pair_and_ticket_inventory_v1(
uuid,uuid,uuid,uuid,integer,integer,date,integer)
FROM PUBLIC,anon,authenticated,service_role;