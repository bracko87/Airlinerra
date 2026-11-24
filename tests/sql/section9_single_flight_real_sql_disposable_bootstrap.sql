-- Disposable-only dependencies for the exact current single-flight route SQL.
-- The production route functions are loaded UNCHANGED; external operational
-- authorities (slots, AOC/rights, maintenance, ticket gateway) are test doubles.
-- This cannot certify actual signed issuers or settlement.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.airline_aircraft_inventory') IS NULL
 THEN RAISE EXCEPTION 'SINGLE_FLIGHT_BOOTSTRAP_REQUIRES_DISPOSABLE_PAIR_FIXTURE'; END IF;
END $guard$;

ALTER TABLE airlinerra_game.airlines ADD COLUMN iata_code text NOT NULL DEFAULT 'AL';
ALTER TABLE airlinerra_game.airlines ADD COLUMN home_airport_key text NOT NULL DEFAULT 'OURAIRPORTS:2212';
ALTER TABLE airlinerra_game.airlines ADD COLUMN cash_usd numeric NOT NULL DEFAULT 5000000;
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN reference_departure_utc timestamptz,
 ADD COLUMN reference_arrival_utc timestamptz,
 ADD COLUMN departure_stand_type text,
 ADD COLUMN arrival_stand_type text;
CREATE TABLE airlinerra_game.airport_reference_profiles(
 world_id smallint NOT NULL,airport_key text NOT NULL,timezone_iana text NOT NULL,
 PRIMARY KEY(world_id,airport_key)
);
INSERT INTO airlinerra_game.airport_reference_profiles VALUES
 (1,'OURAIRPORTS:2212','Europe/Berlin'),
 (1,'OURAIRPORTS:2218','Europe/Berlin');
CREATE TABLE airlinerra_game.section9_fuel_and_settlement_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text NOT NULL);
INSERT INTO airlinerra_game.section9_fuel_and_settlement_release_policy_v1 VALUES(1,'enabled');
CREATE TABLE airlinerra_game.section9_verified_schedule_capacity_v1(
 schedule_id uuid PRIMARY KEY,airline_id uuid,schedule_version integer,
 passenger_seats integer,cargo_capacity_tonnes numeric,verification_source text);
CREATE TABLE airlinerra_game.fixture_single_route_control(
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 fail_at text NOT NULL DEFAULT 'none',
 position_airport text NOT NULL DEFAULT 'OURAIRPORTS:2212');
INSERT INTO airlinerra_game.fixture_single_route_control VALUES(true,'none','OURAIRPORTS:2212');
CREATE TABLE airlinerra_game.fixture_slot_reservations(
 schedule_id uuid NOT NULL,airport_key text NOT NULL,stand_type text,PRIMARY KEY(schedule_id,airport_key));
CREATE TABLE airlinerra_game.fixture_certificates(
 schedule_id uuid NOT NULL,kind text NOT NULL,PRIMARY KEY(schedule_id,kind));
CREATE TABLE airlinerra_game.airline_route_planning_drafts_v1(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 world_id smallint NOT NULL,airline_id uuid NOT NULL,aircraft_inventory_id uuid,
 flight_number text NOT NULL,origin_airport_key text,destination_airport_key text,
 weekly_schedule jsonb,departure_stand_type text,arrival_stand_type text,
 turnaround_minutes integer,planning_options jsonb,
 reference_departure_utc timestamptz,reference_arrival_utc timestamptz,
 created_by_player_id uuid,updated_at timestamptz DEFAULT now(),
 version integer NOT NULL DEFAULT 1,
 UNIQUE(airline_id,flight_number)
);
CREATE TABLE airlinerra_game.section9_onboard_service_release_v1(
 world_id smallint PRIMARY KEY,snapshot_enabled boolean,settlement_enabled boolean,
 custom_route_packages_enabled boolean NOT NULL DEFAULT false);
INSERT INTO airlinerra_game.section9_onboard_service_release_v1 VALUES(1,false,false,false);
CREATE TABLE airlinerra_game.section9_onboard_service_catalog_v1(
 item_id text PRIMARY KEY,sort_order integer NOT NULL,basic_delivery_supported boolean NOT NULL);
INSERT INTO airlinerra_game.section9_onboard_service_catalog_v1 VALUES('water',1,true);
CREATE TABLE airlinerra_game.airline_cabin_service_settings_v1(
 airline_id uuid,world_id smallint,version integer,state jsonb);
CREATE TABLE airlinerra_game.section9_route_onboard_packages_v1(
 schedule_id uuid PRIMARY KEY REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id),
 airline_id uuid NOT NULL, schedule_version integer NOT NULL,
 package_id text NOT NULL,package_version integer NOT NULL,package_items jsonb NOT NULL);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_operational_position_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_day date)
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT jsonb_build_object('verified',true,'atGroundAirport',true,
 'airportKey',position_airport) FROM airlinerra_game.fixture_single_route_control
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_departure_utc timestamptz,p_arrival_utc timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT jsonb_build_object('flightWindowClear',fail_at<>'maintenance',
 'blockers',CASE WHEN fail_at='maintenance' THEN '["MAINTENANCE_BOOKED"]'::jsonb ELSE '[]'::jsonb END)
 FROM airlinerra_game.fixture_single_route_control
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_route_phase_profile_v1(
 p_configuration bigint,p_origin text,p_destination text,p_scheduled_minutes integer DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT jsonb_build_object('totalMinutes',60)
 WHERE p_configuration=100 AND p_origin<>p_destination
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_flight text,p_origin text,p_destination text,
 p_dep timestamptz,p_arr timestamptz,p_weekly jsonb,p_existing uuid,
 p_depart_stand text,p_arrive_stand text)
RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE sid uuid:=gen_random_uuid();bad text;
BEGIN
 SELECT fail_at INTO bad FROM airlinerra_game.fixture_single_route_control;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1
 (id,world_id,airline_id,aircraft_inventory_id,configuration_id,version,status,
 operationally_verified,origin_airport_key,destination_airport_key,
 flight_number,weekly_schedule,reference_departure_utc,reference_arrival_utc,
 departure_stand_type,arrival_stand_type)
 VALUES(sid,1,p_airline,p_aircraft,100,1,'draft',false,p_origin,p_destination,
 p_flight,p_weekly,p_dep,p_arr,p_depart_stand,p_arrive_stand);
 INSERT INTO airlinerra_game.fixture_slot_reservations VALUES(sid,p_origin,p_depart_stand),(sid,p_destination,p_arrive_stand);
 IF bad='slots' THEN RETURN jsonb_build_object('status','blocked_test_slots','slotsReserved',false);END IF;
 RETURN jsonb_build_object('status','draft','slotsReserved',true,'scheduleId',sid,'version',1);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_save_owned_commercial_plan_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_fare numeric,
 p_cargo numeric,p_marketing numeric)
RETURNS jsonb LANGUAGE plpgsql AS $fn$
BEGIN
 INSERT INTO airlinerra_game.section9_route_commercial_plans_v1
 (schedule_id,airline_id,version,economy_fare_usd,marketing_budget_usd_per_day)
 VALUES(p_schedule,p_airline,1,p_fare,p_marketing);
 RETURN jsonb_build_object('economyFareUsd',p_fare,'bookingsEnabled',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_issue_queued_game_clearance_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_day date,p_kind text)
RETURNS jsonb LANGUAGE plpgsql AS $fn$
BEGIN
 IF (SELECT fail_at FROM airlinerra_game.fixture_single_route_control)=p_kind THEN
  RETURN jsonb_build_object('status','blocked_test_clearance','kind',p_kind);
 END IF;
 INSERT INTO airlinerra_game.fixture_certificates VALUES(p_schedule,p_kind);
 RETURN jsonb_build_object('status','certification_event_recorded');
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(
 p_schedule uuid,p_date date,p_entry integer)
RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE seats integer;
BEGIN
 IF (SELECT fail_at FROM airlinerra_game.fixture_single_route_control)='tickets'
 THEN RETURN jsonb_build_object('status','blocked_test_tickets','sevenDayWindowVerified',false);END IF;
 SELECT passenger_seats INTO seats FROM airlinerra_game.section9_verified_schedule_capacity_v1
 WHERE schedule_id=p_schedule;
 INSERT INTO airlinerra_game.fixture_ticket_occurrences VALUES(p_schedule,p_date,p_entry,seats);
 RETURN jsonb_build_object('status','verified_ticket_sales_open',
 'sevenDayWindowVerified',true,'passengerSeats',seats,'ledgerPosted',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_day date,p_days integer)
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"wrongAirportDepartures":[{"flightLocalDate":"2026-11-28","reason":"return_not_scheduled"}]}'::jsonb
$fn$;
