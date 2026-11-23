-- Additional synthetic dependency tables for executing the unmodified real signed writer.
CREATE SCHEMA IF NOT EXISTS vault;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE TABLE vault.decrypted_secrets(name text PRIMARY KEY,decrypted_secret text NOT NULL);
INSERT INTO vault.decrypted_secrets VALUES('airlinerra_operated_flight_auto_signing_v1',repeat('a',80));
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1
 (world_id int PRIMARY KEY, release_state text, enabled_at timestamptz);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1
 (world_id int PRIMARY KEY, release_state text, enabled_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1
 (world_id int PRIMARY KEY, trusted_flight_execution_release text, fuel_transaction_release text,
 automatic_flight_and_fuel_settlement_enabled boolean);
INSERT INTO airlinerra_game.section9_activation_release_policy_v1 VALUES(1,'enabled',now());
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1 VALUES(1,'enabled',now());
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1 VALUES(1,'ACTIVATED','ACTIVATED',true);
CREATE TABLE public.airlinerra_game_worlds (id int PRIMARY KEY,state text,opens_at timestamptz);
INSERT INTO public.airlinerra_game_worlds VALUES(1,'active',now()-interval '3 days');
CREATE TABLE airlinerra_game.holding_world_clock_v1
 (world_id int PRIMARY KEY,clock_source text,confirmed_game_date date,last_verified_at timestamptz,engine_proof_ref text);
INSERT INTO airlinerra_game.holding_world_clock_v1 VALUES
 (1,'authoritative_game_engine','2026-11-23',now(),'SYNTHETIC-CLOCK-FIXTURE-ONLY');
CREATE TABLE airlinerra_game.section9_verified_game_tick_receipts_v1(world_id int,game_date date);
INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1 VALUES(1,'2026-11-23');
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1 ADD COLUMN origin_airport_key text;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1 ADD COLUMN destination_airport_key text;
CREATE TABLE airlinerra_game.airline_aircraft_inventory
 (id uuid PRIMARY KEY,airline_id uuid NOT NULL,fleet_status text,configuration_id bigint,registration text);
INSERT INTO airlinerra_game.airline_aircraft_inventory VALUES
 ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222',
 'in_service',100,'D-CI01');
CREATE TABLE airlinerra_game.airline_flight_schedule_drafts_v1(
 id uuid PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,configuration_id bigint,
 version integer,status text,operationally_verified boolean,weekly_schedule jsonb,
 origin_airport_key text,destination_airport_key text,reference_departure_utc timestamptz,
 reference_arrival_utc timestamptz,world_id int);
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1 VALUES
 ('11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',100,1,'active',true,
 '[{"day":"0","time":"18:00"},{"day":"0","time":"18:00"},{"day":"0","time":"18:00"}]'::jsonb,
 'TEST-AAA','TEST-BBB','2026-11-23 18:00+00','2026-11-23 19:00+00',1);
CREATE TABLE airlinerra_game.section9_verified_schedule_capacity_v1
 (schedule_id uuid,airline_id uuid,schedule_version integer,verification_source text);
INSERT INTO airlinerra_game.section9_verified_schedule_capacity_v1 VALUES
 ('11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222',1,'synthetic');
CREATE TABLE airlinerra_game.airport_reference_profiles(world_id int,airport_key text,timezone_iana text);
INSERT INTO airlinerra_game.airport_reference_profiles VALUES(1,'TEST-AAA','UTC');
CREATE TABLE airlinerra_game.section9_aircraft_delivery_position_v1
 (aircraft_inventory_id uuid,airline_id uuid,airport_key text,anchored_game_date date,
 acquisition_order_id uuid,inspection_id uuid,inspection_reviewed_at timestamptz,reviewer_reference text);
CREATE TABLE airlinerra_game.aircraft_acquisition_orders
 (order_id uuid,airline_id uuid,aircraft_inventory_id uuid,order_status text,registration text,
 configuration_id bigint,delivery_home_airport_key text);
CREATE TABLE airlinerra_game.aircraft_delivery_inspections
 (inspection_id uuid,order_id uuid,inspection_status text,reviewed_at timestamptz,reviewer_reference text);
CREATE TABLE airlinerra_game.section9_aircraft_current_position_v1
 (aircraft_inventory_id uuid PRIMARY KEY,world_id int,airline_id uuid,location_status text,
 airport_key text,current_flight_occurrence_id text,last_event_utc timestamptz,
 last_departure_utc timestamptz,last_arrival_utc timestamptz,last_engine_event_id text,
 updated_at timestamptz);
ALTER TABLE airlinerra_game.section9_operated_flight_movements_v1
 ADD COLUMN world_id int, ADD COLUMN event_hmac_sha256 text,
 ADD COLUMN airline_id uuid,ADD COLUMN aircraft_inventory_id uuid,ADD COLUMN schedule_id uuid,
 ADD COLUMN schedule_version integer,ADD COLUMN weekly_entry integer,
 ADD COLUMN flight_local_date date,ADD COLUMN origin_airport_key text,
 ADD COLUMN destination_airport_key text,ADD COLUMN scheduled_departure_utc timestamptz,
 ADD COLUMN scheduled_arrival_utc timestamptz,ADD COLUMN actual_event_utc timestamptz;
-- Fake dependency proof readers are strictly synthetic and never claim real clock or starter evidence.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('authoritativeGameHourAvailable',true,'gameHourUtc','2026-11-23 18:00:00+00')
 $$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_starter_origin_evidence_v1(uuid,uuid,date)
 RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT '{"verified":true,"airportKey":"TEST-AAA"}'::jsonb$$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aircraft_movement_decision_v1(
 text,text,text,text,timestamptz,timestamptz,text,text,text,timestamptz)
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT CASE WHEN $1='departed' AND $2='grounded' AND $3=$7 THEN
 '{"allowed":true,"newState":"airborne","newAirport":"TEST-AAA"}'::jsonb
 ELSE '{"allowed":false,"reason":"TEST_STATE_NOT_ELIGIBLE"}'::jsonb END $$;
-- REAL cryptographic signature produced by pgcrypto with synthetic, nonproduction key.
CREATE FUNCTION airlinerra_game.test_sign_event(p_event text,p_time timestamptz)
RETURNS text LANGUAGE sql STABLE AS $$
 SELECT encode(extensions.hmac(
 convert_to(concat_ws(E'\n','airlinerra-operated-game-event-v1','1',
 '22222222-2222-4222-8222-222222222222',
 '11111111-1111-4111-8111-111111111111','1','2026-11-23','1','departed',
 to_char(p_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),p_event),'UTF8'),
 convert_to(repeat('a',80),'UTF8'),'sha256'),'hex')$$;
