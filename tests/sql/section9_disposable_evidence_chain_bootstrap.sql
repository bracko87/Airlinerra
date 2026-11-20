-- World 1 completion-chain fixture. MUST run on an empty disposable PostgreSQL 17
-- database named airlinerra_disposable, never against production Supabase.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable'
    OR current_user<>'postgres'
    OR to_regnamespace('airlinerra_game') IS NOT NULL
    OR to_regnamespace('auth') IS NOT NULL
 THEN RAISE EXCEPTION 'SECTION9_FIXTURE_DISPOSABLE_DATABASE_ONLY';END IF;
END $guard$;
CREATE SCHEMA airlinerra_game;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(
 id uuid primary key, world_id smallint not null, schedule_id uuid not null,
 airline_id uuid not null, aircraft_inventory_id uuid not null,
 schedule_version integer not null, weekly_entry integer not null,
 flight_local_date date not null, booked_seats integer not null,
 verified_passenger_seats integer not null,
 UNIQUE(schedule_id,flight_local_date,weekly_entry));
CREATE TABLE airlinerra_game.section9_passenger_reservation_batches_v1(
 id uuid primary key, occurrence_id uuid not null,
 seats_requested integer not null,reservation_status text not null,
 paid_upfront boolean not null default false,
 recognized_revenue_usd numeric not null default 0);
CREATE TABLE airlinerra_game.section9_operated_flight_movements_v1(
 world_id smallint not null, flight_occurrence_id text not null,
 phase text not null, engine_event_id text primary key,
 airline_id uuid not null,schedule_id uuid not null,
 schedule_version integer not null,aircraft_inventory_id uuid not null,
 actual_event_utc timestamptz not null,recorded_at timestamptz not null);
CREATE TABLE airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(
 physical_flight_id text primary key,
 arrived_engine_event_id text not null,departed_engine_event_id text not null);
CREATE TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1(
 physical_flight_id text primary key,arrival_event_id text not null);
CREATE TABLE airlinerra_game.section9_flight_final_cost_approvals_v1(
 physical_flight_id text primary key,approval_state text not null,
 arrived_event_id text not null);
CREATE TABLE airlinerra_game.section9_route_posted_flight_financials_v1(
 physical_flight_id text primary key,arrived_event_id text not null,
 revenue_ledger_id bigint not null,expense_ledger_id bigint not null);
