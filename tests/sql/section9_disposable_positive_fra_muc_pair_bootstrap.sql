-- Disposable PostgreSQL 17 only. Positive round-trip activation test harness.
-- These are minimal *synthetic* certification/slot mocks, NOT proof that
-- actual operators, AOCs, route rights or aircraft certificates were issued.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('airlinerra_game') IS NOT NULL
 OR to_regnamespace('auth') IS NOT NULL THEN
  RAISE EXCEPTION 'FRA_MUC_POSITIVE_ACTIVATION_DISPOSABLE_DATABASE_ONLY';
 END IF;
END $guard$;
CREATE SCHEMA airlinerra_game;
CREATE SCHEMA airlinerra;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,crew_mode text,
 enabled_at timestamptz, reviewed_at timestamptz);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,enabled_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_finance_posting_release_v1(
 world_id smallint PRIMARY KEY,release_state text,approved_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(
 world_id smallint PRIMARY KEY,trusted_flight_execution_release text,
 fuel_transaction_release text, automatic_flight_and_fuel_settlement_enabled boolean);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"authoritativeGameHourAvailable":true,"gameDate":"2026-11-20","gameHourUtc":"2026-11-20T12:00:00Z"}'::jsonb
$fn$;
CREATE TABLE airlinerra_game.airlines(
 id uuid PRIMARY KEY, world_id smallint, owner_player_id uuid);
CREATE TABLE airlinerra_game.world_memberships(
 world_id smallint, player_id uuid,state text);
CREATE TABLE airlinerra_game.airline_aircraft_inventory(
 id uuid PRIMARY KEY,airline_id uuid,fleet_status text,
 ownership_type text,configuration_id bigint);
CREATE TABLE airlinerra_game.airline_flight_schedule_drafts_v1(
 id uuid PRIMARY KEY,world_id smallint,airline_id uuid,
 aircraft_inventory_id uuid, configuration_id bigint,
 version integer,status text,operationally_verified boolean,
 origin_airport_key text,destination_airport_key text,
 flight_number text, weekly_schedule jsonb);
CREATE TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1(
 configuration_id bigint PRIMARY KEY,game_calculation_ready boolean,
 operational_dispatch_release text, financial_settlement_release text);
CREATE TABLE airlinerra.aircraft_service_payload_game_v1(
 configuration_id bigint PRIMARY KEY,simultaneous_passenger_seats integer);
CREATE TABLE airlinerra.aircraft_configurations(
 id bigint PRIMARY KEY,use_type text, maximum_passenger_seats integer);
CREATE TABLE airlinerra_game.section9_route_commercial_plans_v1(
 schedule_id uuid, airline_id uuid,version integer,economy_fare_usd numeric,
 marketing_budget_usd_per_day numeric,PRIMARY KEY(schedule_id,airline_id));
CREATE TABLE airlinerra_game.section9_schedule_operational_certifications_v1(
 schedule_id uuid,airline_id uuid,schedule_version integer,
 clearance_type text,review_status text,last_verified_event_id text,
 valid_from_game_date date, valid_to_game_date date);
CREATE TABLE airlinerra_game.section9_operational_certification_events_v1(
 event_id text PRIMARY KEY,schedule_id uuid,schedule_version integer,
 clearance_type text, action text);
-- Synthetic postcertification dependencies: fail-switches permit atomic rollback tests.
CREATE TABLE airlinerra_game.fixture_reject(
 name text PRIMARY KEY,schedule_id uuid, enabled boolean NOT NULL DEFAULT false);
CREATE TABLE airlinerra_game.fixture_verified_seat_capacity(
 schedule_id uuid PRIMARY KEY,passenger_seats integer,source text);
CREATE TABLE airlinerra_game.fixture_ticket_occurrences(
 schedule_id uuid,flight_local_date date,weekly_entry integer,
 passenger_seats integer,PRIMARY KEY(schedule_id,flight_local_date,weekly_entry));
CREATE OR REPLACE FUNCTION airlinerra_game.section9_commit_certified_schedule_activation_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_expected_version integer,p_game_date date,p_days integer)
 RETURNS jsonb LANGUAGE plpgsql AS $fn$
BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.fixture_reject
  WHERE name='second_leg' AND schedule_id=p_schedule AND enabled)
 THEN RETURN '{"status":"blocked_test_second_leg","scheduleActivated":false,"ledgerPosted":false}'::jsonb;
 END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET status='active',operationally_verified=true
 WHERE id=p_schedule AND airline_id=p_airline
 AND version=p_expected_version AND status='draft' AND operationally_verified=false;
 IF NOT FOUND THEN RETURN '{"status":"blocked_schedule_not_draft","scheduleActivated":false,"ledgerPosted":false}'::jsonb;
 END IF;
 RETURN '{"status":"certified_schedule_activated","scheduleActivated":true,"ledgerPosted":false}'::jsonb;
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_register_verified_schedule_capacity_v1(
 p_schedule uuid,p_airline uuid,p_seats integer,p_cargo integer,p_source text)
 RETURNS jsonb LANGUAGE plpgsql AS $fn$
BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.fixture_reject
  WHERE name='capacity' AND schedule_id=p_schedule AND enabled)
 THEN RETURN '{"verified":false}'::jsonb;END IF;
 INSERT INTO airlinerra_game.fixture_verified_seat_capacity
 VALUES(p_schedule,p_seats,p_source);
 RETURN jsonb_build_object('verified',true,'passengerSeats',p_seats);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_saleable_departure_window_v1(
 p_schedule uuid,p_date date,p_weekly_entry integer,p_hour timestamptz)
 RETURNS jsonb LANGUAGE sql AS $fn$
 SELECT jsonb_build_object('withinWindow',p_date=DATE '2026-11-21');
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(
 p_schedule uuid,p_date date,p_entry integer)
 RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE seats integer;
BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.fixture_reject
  WHERE name='return_ticket' AND schedule_id=p_schedule AND enabled)
 THEN RETURN '{"status":"blocked_test_second_ticket","sevenDayWindowVerified":false}'::jsonb;END IF;
 SELECT passenger_seats INTO seats
 FROM airlinerra_game.fixture_verified_seat_capacity WHERE schedule_id=p_schedule;
 INSERT INTO airlinerra_game.fixture_ticket_occurrences VALUES(p_schedule,p_date,p_entry,seats);
 RETURN jsonb_build_object('status','verified_ticket_sales_open',
  'sevenDayWindowVerified',true,'passengerSeats',seats,'ledgerPosted',false);
END $fn$;
INSERT INTO airlinerra_game.section9_activation_release_policy_v1
 VALUES(1,'enabled','deferred_phase1',now(),now());
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1
 VALUES(1,'enabled',now());
INSERT INTO airlinerra_game.section9_flight_finance_posting_release_v1
 VALUES(1,'approved',now());
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1
 VALUES(1,'ACTIVATED','ACTIVATED',true);
INSERT INTO airlinerra_game.airlines VALUES(
 '11111111-1111-4111-8111-111111111111',1,
 '22222222-2222-4222-8222-222222222222');
INSERT INTO airlinerra_game.world_memberships VALUES(
 1,'22222222-2222-4222-8222-222222222222','active');
INSERT INTO airlinerra_game.airline_aircraft_inventory VALUES(
 '33333333-3333-4333-8333-333333333333',
 '11111111-1111-4111-8111-111111111111','in_service','owned',100);
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1 VALUES
 ('44444444-4444-4444-8444-444444444444',1,
 '11111111-1111-4111-8111-111111111111',
 '33333333-3333-4333-8333-333333333333',
 100,1,'draft',false,'OURAIRPORTS:2212','OURAIRPORTS:2218',
 'AL101','[{"day":5,"time":"10:00"}]'::jsonb),
 ('55555555-5555-4555-8555-555555555555',1,
 '11111111-1111-4111-8111-111111111111',
 '33333333-3333-4333-8333-333333333333',
 100,1,'draft',false,'OURAIRPORTS:2218','OURAIRPORTS:2212',
 'AL102','[{"day":5,"time":"13:00"}]'::jsonb);
INSERT INTO airlinerra_game.section9_game_fuel_model_snapshot_v1 VALUES
 (100,true,'RELEASED','RELEASED');
INSERT INTO airlinerra.aircraft_service_payload_game_v1 VALUES(100,110);
INSERT INTO airlinerra.aircraft_configurations VALUES(100,'passenger',120);
INSERT INTO airlinerra_game.section9_route_commercial_plans_v1 VALUES
 ('44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',1,90,0),
 ('55555555-5555-4555-8555-555555555555',
 '11111111-1111-4111-8111-111111111111',1,95,0);
INSERT INTO airlinerra_game.fixture_reject VALUES
 ('second_leg','55555555-5555-4555-8555-555555555555',false),
 ('capacity','55555555-5555-4555-8555-555555555555',false),
 ('return_ticket','55555555-5555-4555-8555-555555555555',false);
-- Five distinct certification categories, all pre-existing and version-bound.
DO $cert$
DECLARE s uuid;kind text;e text;
BEGIN
 FOREACH s IN ARRAY ARRAY[
 '44444444-4444-4444-8444-444444444444'::uuid,
 '55555555-5555-4555-8555-555555555555'::uuid]
 LOOP
  FOREACH kind IN ARRAY ARRAY[
  'aircraft','slots','route_rights','aoc','maintenance']
  LOOP
   e:=s::text||':'||kind;
   INSERT INTO airlinerra_game.section9_operational_certification_events_v1
   VALUES(e,s,1,kind,'certify');
   INSERT INTO airlinerra_game.section9_schedule_operational_certifications_v1
   VALUES(s,'11111111-1111-4111-8111-111111111111',1,kind,
   'certified',e,DATE '2026-11-20',DATE '2026-12-31');
  END LOOP;
 END LOOP;
END $cert$;
