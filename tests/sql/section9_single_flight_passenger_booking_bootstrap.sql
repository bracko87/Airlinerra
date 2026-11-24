-- Controlled only: isolated ticket occurrence and booking capacity derived
-- from the SAME single-route creation and paid aircraft maintenance flow.
-- The real private passenger-reservation SQL is loaded separately unchanged.
-- No demand-engine signatures, HMAC, cash sale or real flight are fabricated.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
  OR to_regclass('airlinerra_game.fixture_ticket_occurrences') IS NULL
  OR to_regclass('airlinerra_game.section9_game_maintenance_jobs_v1') IS NULL
 THEN RAISE EXCEPTION 'BOOKING_FIXTURE_DISPOSABLE_ONLY_AND_AFTER_MAINTENANCE'; END IF;
END $guard$;
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 schedule_id uuid NOT NULL,
 airline_id uuid NOT NULL,
 aircraft_inventory_id uuid NOT NULL,
 flight_local_date date NOT NULL,
 weekly_entry integer NOT NULL,
 schedule_version integer NOT NULL,
 commercial_version integer NOT NULL,
 verified_passenger_seats integer NOT NULL,
 booked_seats integer NOT NULL DEFAULT 0,
 source_kind text NOT NULL,
 booking_status text NOT NULL,
 UNIQUE(schedule_id,flight_local_date,weekly_entry),
 CHECK (booked_seats BETWEEN 0 AND verified_passenger_seats)
);
CREATE TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id text PRIMARY KEY,
 schedule_id uuid NOT NULL,
 airline_id uuid NOT NULL,
 passenger_capacity integer NOT NULL,
 schedule_version integer NOT NULL,
 commercial_version integer NOT NULL,
 passengers_held integer NOT NULL DEFAULT 0,
 status text NOT NULL,
 CHECK (passengers_held BETWEEN 0 AND passenger_capacity)
);
CREATE TABLE airlinerra_game.section9_passenger_reservation_batches_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 occurrence_id uuid NOT NULL REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 reservation_key text NOT NULL,
 fare_class text NOT NULL,
 seats_requested integer NOT NULL,
 quoted_fare_usd numeric NOT NULL,
 reservation_status text NOT NULL,
 paid_upfront boolean NOT NULL,
 recognized_revenue_usd numeric NOT NULL,
 UNIQUE(occurrence_id,reservation_key)
);
CREATE TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1(
 schedule_id uuid NOT NULL,
 direction text NOT NULL CHECK(direction IN('departure','arrival')),
 PRIMARY KEY(schedule_id,direction)
);
CREATE TABLE airlinerra_game.section9_operated_flight_movements_v1(
 event_id text PRIMARY KEY,
 schedule_id uuid NOT NULL,
 flight_local_date date NOT NULL,
 weekly_entry integer NOT NULL
);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1()
RETURNS date LANGUAGE sql STABLE AS $fn$
 SELECT (simulated_now AT TIME ZONE 'Europe/Berlin')::date
 FROM airlinerra_game.fixture_game_now WHERE singleton
$fn$;
