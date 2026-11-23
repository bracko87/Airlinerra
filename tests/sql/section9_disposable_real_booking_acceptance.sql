-- Disposable-only harness for the UNCHANGED real direct passenger reservation function.
-- Install after the synthetic FRA-MUC pair activation acceptance.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_dated_flight_occurrences_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'REAL_BOOKING_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(
 id uuid PRIMARY KEY,airline_id uuid NOT NULL,schedule_id uuid NOT NULL,
 aircraft_inventory_id uuid NOT NULL,schedule_version int NOT NULL,
 weekly_entry int NOT NULL,flight_local_date date NOT NULL,
 verified_passenger_seats int,booked_seats int NOT NULL DEFAULT 0,
 booking_status text NOT NULL,source_kind text NOT NULL,
 departure_utc timestamptz NOT NULL);
CREATE TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id text PRIMARY KEY,schedule_id uuid NOT NULL,
 airline_id uuid NOT NULL,schedule_version int NOT NULL,
 commercial_version int NOT NULL,passenger_capacity int NOT NULL,
 passengers_held int NOT NULL DEFAULT 0,status text NOT NULL);
CREATE TABLE airlinerra_game.section9_passenger_reservation_batches_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 occurrence_id uuid NOT NULL,reservation_key text NOT NULL,
 fare_class text NOT NULL,seats_requested int NOT NULL,
 quoted_fare_usd numeric NOT NULL,
 reservation_status text NOT NULL,paid_upfront boolean NOT NULL,
 recognized_revenue_usd numeric NOT NULL,
 UNIQUE(occurrence_id,reservation_key));
CREATE TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1(
 schedule_id uuid NOT NULL,direction text NOT NULL);
CREATE TABLE airlinerra_game.section9_operated_flight_movements_v1(
 schedule_id uuid NOT NULL,flight_local_date date NOT NULL,weekly_entry int NOT NULL);
CREATE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1()
 RETURNS date LANGUAGE sql STABLE AS $fn$ SELECT DATE '2026-11-20' $fn$;

INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1 VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '11111111-1111-4111-8111-111111111111',
 '44444444-4444-4444-8444-444444444444',
 '33333333-3333-4333-8333-333333333333',
 1,1,DATE '2026-11-21',110,0,'open',
 'game_verified_saleable_schedule_v1','2026-11-21T10:00:00Z');
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1
 VALUES('44444444-4444-4444-8444-444444444444:2026-11-21:1',
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',1,1,110,0,'preflight_only');
INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
 VALUES('44444444-4444-4444-8444-444444444444','departure'),
 ('44444444-4444-4444-8444-444444444444','arrival');
-- All preceding are controlled synthetic fixtures. The booking procedure
-- installed by CI is extracted unchanged from the actual game migration.

DO $test$
DECLARE x jsonb;v_count int;v_booked int;v_held int;
 occ uuid:='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
BEGIN
 BEGIN
  PERFORM airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
   occ,'bad!','economy',1);
  RAISE EXCEPTION 'Bad key was accepted';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 x:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','fixture.missing','economy',1);
 IF x->>'status'<>'blocked_unknown_flight' THEN
  RAISE EXCEPTION 'Unknown occurrence should block: %',x; END IF;

 x:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  occ,'fixture.booking.one','economy',3);
 IF x->>'status'<>'game_passenger_seats_reserved'
 OR x->>'seatsReservedNow'<>'3'
 OR x->>'chargedNow'<>'false'
 OR x->>'ledgerPosted'<>'false' THEN
  RAISE EXCEPTION 'Real booking function failed synthetic positive: %',x;END IF;
 SELECT count(*) INTO v_count FROM airlinerra_game.section9_passenger_reservation_batches_v1;
 SELECT booked_seats INTO v_booked FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=occ;
 SELECT passengers_held INTO v_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1;
 IF v_count<>1 OR v_booked<>3 OR v_held<>3 THEN
  RAISE EXCEPTION 'Direct booking not atomic: % % %',v_count,v_booked,v_held;END IF;

 x:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  occ,'fixture.booking.one','economy',3);
 IF x->>'status'<>'game_passenger_reservation_replayed' THEN
  RAISE EXCEPTION 'Booking idempotent replay failed: %',x;END IF;
 SELECT count(*) INTO v_count FROM airlinerra_game.section9_passenger_reservation_batches_v1;
 SELECT booked_seats INTO v_booked FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=occ;
 IF v_count<>1 OR v_booked<>3 THEN RAISE EXCEPTION 'Booking replay altered seats';END IF;

 x:=airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(
  occ,'fixture.booking.overcapacity','economy',108);
 IF x->>'status'<>'blocked_insufficient_available_seats'
 OR x->>'ledgerPosted'<>'false' THEN
  RAISE EXCEPTION 'Over-capacity must block before writes: %',x;END IF;
 SELECT count(*) INTO v_count FROM airlinerra_game.section9_passenger_reservation_batches_v1;
 SELECT booked_seats INTO v_booked FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=occ;
 SELECT passengers_held INTO v_held FROM airlinerra_game.section9_occurrence_capacity_inventory_v1;
 IF v_count<>1 OR v_booked<>3 OR v_held<>3 THEN
  RAISE EXCEPTION 'Over-capacity attempt altered seats';END IF;
 RAISE NOTICE 'PASS unchanged direct-booking SQL: validation, positive seat reservation, replay, capacity and zero ledger';
END $test$;
