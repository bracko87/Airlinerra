-- Disposable schema only: install the production cancellation FUNCTION unchanged.
-- The game-clock reader below is an explicitly labelled synthetic fixture.
CREATE SCHEMA airlinerra_game;
CREATE TABLE airlinerra_game.section9_disruption_release_v1 (
 world_id smallint PRIMARY KEY, cancellation_enabled boolean NOT NULL);
INSERT INTO airlinerra_game.section9_disruption_release_v1 VALUES (1,true);

CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1 (
 id uuid PRIMARY KEY, schedule_id uuid NOT NULL,flight_local_date date NOT NULL,
 weekly_entry integer NOT NULL,airline_id uuid NOT NULL,aircraft_inventory_id uuid NOT NULL,
 schedule_version integer NOT NULL,booking_status text NOT NULL,source_kind text NOT NULL,
 recognized_revenue_usd numeric NOT NULL DEFAULT 0,booked_seats integer NOT NULL);
CREATE TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1 (
 physical_flight_id text PRIMARY KEY,airline_id uuid NOT NULL,
 schedule_version integer NOT NULL,passengers_held integer NOT NULL,cargo_held_tonnes numeric NOT NULL DEFAULT 0);
CREATE TABLE airlinerra_game.section9_operated_flight_movements_v1 (
 flight_occurrence_id text NOT NULL,phase text NOT NULL,engine_event_id text NOT NULL UNIQUE);
CREATE TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1 (physical_flight_id text PRIMARY KEY);
CREATE TABLE airlinerra_game.section9_atomic_itinerary_holds_v1 (
 physical_flight_ids text[] NOT NULL,status text NOT NULL,cargo_tonnes numeric NOT NULL DEFAULT 0);
CREATE TABLE airlinerra_game.section9_passenger_reservation_batches_v1 (
 occurrence_id uuid NOT NULL,reservation_status text NOT NULL,seats_requested integer NOT NULL,
 quoted_fare_usd numeric NOT NULL,paid_upfront boolean NOT NULL DEFAULT false,
 recognized_revenue_usd numeric NOT NULL DEFAULT 0);
CREATE TABLE airlinerra_game.section9_flight_cancellation_receipts_v1(
 occurrence_id uuid PRIMARY KEY,physical_flight_id text UNIQUE NOT NULL,
 airline_id uuid NOT NULL,cancelled_at timestamptz NOT NULL,reason text NOT NULL,
 cancelled_seats integer NOT NULL,released_held_seats integer NOT NULL,
 cancelled_holds integer NOT NULL,foregone_ticket_quote_usd numeric NOT NULL);
CREATE TABLE airlinerra_game.section9_aircraft_game_fuel_custody_v1(
 aircraft_inventory_id uuid PRIMARY KEY,onboard_kg numeric NOT NULL);
CREATE FUNCTION airlinerra_game.section9_verified_world_instant_v1()
 RETURNS timestamptz LANGUAGE sql STABLE AS $$ SELECT '2026-11-23 18:00:00+00'::timestamptz $$;
DO $$
DECLARE n integer;
BEGIN
 FOR n IN 1..3 LOOP
  INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1
  VALUES (
   ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
   '11111111-1111-4111-8111-111111111111',
   '2026-11-23',n,
   '22222222-2222-4222-8222-222222222222',
   '33333333-3333-4333-8333-333333333333',
   1,'open','game_verified_saleable_schedule_v1',0,2);
  INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1
   VALUES ('11111111-1111-4111-8111-111111111111:2026-11-23:'||n,
    '22222222-2222-4222-8222-222222222222',1,2,0);
  INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1
   VALUES (('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'reserved',2,50,false,0);
 END LOOP;
END $$;
INSERT INTO airlinerra_game.section9_aircraft_game_fuel_custody_v1 VALUES ('33333333-3333-4333-8333-333333333333',500);
