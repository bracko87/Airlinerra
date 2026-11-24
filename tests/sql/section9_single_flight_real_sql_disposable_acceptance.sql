-- Current server SQL, not rewritten: real single-route and cabin-aware
-- transaction with synthetic operator, slot, location, clearance and tickets.
-- No real flight movement, signer, finance posting, player auth or refund proof.
\set ON_ERROR_STOP on
BEGIN;
DO $accept$
DECLARE
 player uuid:='22222222-2222-4222-8222-222222222222';
 airline uuid:='11111111-1111-4111-8111-111111111111';
 aircraft uuid:='33333333-3333-4333-8333-333333333333';
 weekdays jsonb:='[{"day":5,"time":"11:00"}]'::jsonb;
 result jsonb;stage text;sid uuid;pre_cash numeric;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'SINGLE_FLIGHT_TEST_WRONG_DATABASE';END IF;
 SELECT cash_usd INTO pre_cash FROM airlinerra_game.airlines WHERE id=airline;
 IF pre_cash<>5000000 THEN RAISE EXCEPTION 'Fixture opening cash incorrect'; END IF;
 -- Package invalid and non-owner must both fail without any route effects.
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL103','OURAIRPORTS:2212','OURAIRPORTS:2218',
  weekdays,'terminal','terminal',60,90,'custom-invalid');
 IF result->>'status'<>'blocked_invalid_cabin_package' OR result->>'routeCreated'<>'false'
 THEN RAISE EXCEPTION 'Bad cabin package not rejected: %',result;END IF;
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',airline,aircraft,'AL103',
  'OURAIRPORTS:2212','OURAIRPORTS:2218',weekdays,'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_airline_not_owned' OR result->>'routeCreated'<>'false'
 THEN RAISE EXCEPTION 'Foreign owner not rejected: %',result;END IF;
 -- Check that every broken dependency, including failures AFTER inserts,
 -- leaves zero schedules, slots, fares, certificates, tickets and cabin rows.
 FOREACH stage IN ARRAY ARRAY['slots','maintenance','operator_licence','tickets']
 LOOP
  UPDATE airlinerra_game.fixture_single_route_control SET fail_at=stage;
  result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
   player,airline,aircraft,'AL103','OURAIRPORTS:2212','OURAIRPORTS:2218',
   weekdays,'terminal','terminal',60,90,'basic');
  IF result->>'routeCreated'<>'false' OR result->>'slotsReserved' IS DISTINCT FROM 'false'
  OR result->>'activated' IS DISTINCT FROM 'false'
  OR result->>'bookingEnabled' IS DISTINCT FROM 'false'
  OR result->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN RAISE EXCEPTION 'Failed gate % returned unsafe receipt: %',stage,result;END IF;
  IF (stage='slots' AND result->>'status'<>'blocked_schedule_or_slots')
  OR (stage='maintenance' AND
      (result->>'status'<>'blocked_first_departure' OR result#>>'{details,reason}'<>'MAINTENANCE_FLIGHT_WINDOW_BLOCKED'))
  OR (stage='operator_licence' AND
      (result->>'status'<>'blocked_operational_requirement' OR result->>'clearanceType'<>'operator_licence'))
  OR (stage='tickets' AND result->>'status'<>'blocked_ticket_inventory')
  THEN RAISE EXCEPTION 'Wrong gate code at %: %',stage,result;END IF;
  IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1)<>2
  OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
  OR (SELECT count(*) FROM airlinerra_game.section9_route_commercial_plans_v1)<>2
  OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_certificates)
  OR EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_schedule_capacity_v1)
  OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
  OR EXISTS(SELECT 1 FROM airlinerra_game.airline_route_planning_drafts_v1)
  OR EXISTS(SELECT 1 FROM airlinerra_game.section9_route_onboard_packages_v1)
  THEN RAISE EXCEPTION 'Atomic rollback leaked intermediate data at stage %',stage;END IF;
  IF (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=airline)<>pre_cash
  THEN RAISE EXCEPTION 'Blocked route changed airline money at %',stage;END IF;
 END LOOP;
 UPDATE airlinerra_game.fixture_single_route_control
 SET fail_at='none',position_airport='OURAIRPORTS:2218';
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL103','OURAIRPORTS:2212','OURAIRPORTS:2218',
  weekdays,'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_first_departure' OR result#>>'{details,reason}'<>'AIRCRAFT_CANNOT_REACH_FIRST_DEPARTURE'
 THEN RAISE EXCEPTION 'Wrong airport should block first departure: %',result;END IF;
 UPDATE airlinerra_game.fixture_single_route_control SET position_airport='OURAIRPORTS:2212';
 IF EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 THEN RAISE EXCEPTION 'Wrong-airport failure leaked slots'; END IF;
 -- Happy path: one active AL103, two reserved airport stands, five
 -- controlled synthetic certification records, 110 verified seats,
 -- one genuinely saleable occurrence, and no money posting.
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL103','OURAIRPORTS:2212','OURAIRPORTS:2218',
  weekdays,'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'active' OR result->>'routeCreated'<>'true'
 OR result->>'activated'<>'true' OR result->>'slotsReserved'<>'true'
 OR result->>'bookingEnabled'<>'true' OR result->>'ledgerPosted'<>'false'
 OR result->>'saleableDepartures'<>'1' OR result->>'cabinPackageId'<>'basic'
 OR result->>'estimatedDurationMinutes'<>'60'
 OR jsonb_array_length(result->'futurePositionWarnings')<>1
 THEN RAISE EXCEPTION 'Single-route positive receipt incomplete: %',result;END IF;
 sid:=(result->>'scheduleId')::uuid;
 IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1
     WHERE id=sid AND flight_number='AL103' AND status='active' AND operationally_verified)<>1
 OR (SELECT count(*) FROM airlinerra_game.fixture_slot_reservations WHERE schedule_id=sid)<>2
 OR (SELECT count(*) FROM airlinerra_game.fixture_certificates WHERE schedule_id=sid)<>5
 OR (SELECT passenger_seats FROM airlinerra_game.section9_verified_schedule_capacity_v1 WHERE schedule_id=sid)<>110
 OR (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences
     WHERE schedule_id=sid AND flight_local_date='2026-11-21' AND passenger_seats=110)<>1
 OR (SELECT count(*) FROM airlinerra_game.airline_route_planning_drafts_v1
     WHERE airline_id=airline AND flight_number='AL103')<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_route_onboard_packages_v1
     WHERE schedule_id=sid AND package_id='basic')<>1
 THEN RAISE EXCEPTION 'Single route did not atomically persist exact expected effects';END IF;
 IF (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=airline)<>pre_cash
 THEN RAISE EXCEPTION 'Route creation incorrectly posted finance';END IF;
 -- Replaying creation must fail, not duplicate a schedule, slots, ticket or charge.
 result:=airlinerra_game.section9_create_active_route_with_cabin_v1(
  player,airline,aircraft,'AL103','OURAIRPORTS:2212','OURAIRPORTS:2218',
  weekdays,'terminal','terminal',60,90,'basic');
 IF result->>'status'<>'blocked_flight_number_exists' OR result->>'routeCreated'<>'false'
 OR (SELECT count(*) FROM airlinerra_game.fixture_ticket_occurrences WHERE schedule_id=sid)<>1
 OR (SELECT count(*) FROM airlinerra_game.fixture_slot_reservations WHERE schedule_id=sid)<>2
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=airline)<>pre_cash
 THEN RAISE EXCEPTION 'Duplicate route attempted second effect: %',result;END IF;
 RAISE NOTICE 'PASS current single-flight SQL: owner/cabin checks, slots, first departure, maintenance, five synthetic clearances, activation, saleable ticket inventory, atomic rollbacks and idempotent replay. NOT a full real signed flight/settlement.';
END $accept$;
ROLLBACK;
-- The test DB retains only the original pre-existing synthetic pair rows.
DO $clean$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1)<>2
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_slot_reservations)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_certificates)
 OR EXISTS(SELECT 1 FROM airlinerra_game.fixture_ticket_occurrences)
 OR EXISTS(SELECT 1 FROM airlinerra_game.airline_route_planning_drafts_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_route_onboard_packages_v1)
 THEN RAISE EXCEPTION 'Disposable acceptance transaction did not roll back';END IF;
END $clean$;
