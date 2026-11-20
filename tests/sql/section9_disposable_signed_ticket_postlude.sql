-- Stage 2 for the disposable-only settlement harness.
-- Replace isolated proof stubs with the ACTUAL production HMAC and ticket
-- reconciliation functions, using signed synthetic records in local PG17.
-- This file is NEVER applied to production.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable'
 OR current_user<>'postgres'
 OR to_regnamespace('auth') IS NOT NULL THEN
  RAISE EXCEPTION 'SECTION9_SIGNED_FIXTURE_DISPOSABLE_ONLY'; END IF;
END $guard$;
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA vault;
CREATE TABLE vault.decrypted_secrets(
 name text PRIMARY KEY,decrypted_secret text NOT NULL);
INSERT INTO vault.decrypted_secrets VALUES
 ('airlinerra_operated_flight_auto_signing_v1',
  'local-disposable-signed-test-48-byte-key-abcdef0123456789-abcdef0123456789');
CREATE TABLE airlinerra_game.section9_operated_flight_movements_v1(
 world_id smallint not null,engine_event_id text primary key,
 flight_occurrence_id text not null,phase text not null,
 airline_id uuid not null, aircraft_inventory_id uuid not null,
 schedule_id uuid not null,schedule_version integer not null,
 flight_local_date date not null,weekly_entry integer not null,
 scheduled_departure_utc timestamptz not null,
 scheduled_arrival_utc timestamptz not null,
 actual_event_utc timestamptz not null,source_kind text not null,
 event_hmac_sha256 text not null);
CREATE TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id text PRIMARY KEY,schedule_id uuid,airline_id uuid,
 local_departure_date date,weekly_entry integer,schedule_version integer,
 commercial_version integer,departure_utc timestamptz,
 arrival_utc timestamptz,passenger_capacity integer,passengers_held integer);
CREATE TABLE airlinerra_game.section9_dated_flight_occurrences_v1(
 id uuid PRIMARY KEY,schedule_id uuid,flight_local_date date,
 weekly_entry integer,booked_seats integer,verified_passenger_seats integer,
 booking_status text,source_kind text,schedule_version integer,
 departure_utc timestamptz,arrival_utc timestamptz);
CREATE TABLE airlinerra_game.airline_aircraft_inventory(
 id uuid PRIMARY KEY,airline_id uuid,fleet_status text);
CREATE TABLE airlinerra_game.section9_route_commercial_plans_v1(
 schedule_id uuid,airline_id uuid,version integer);
CREATE TABLE airlinerra_game.section9_passenger_reservation_batches_v1(
 id uuid PRIMARY KEY,occurrence_id uuid, reservation_status text,
 seats_requested integer,quoted_fare_usd numeric,
 paid_upfront boolean,recognized_revenue_usd numeric);
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN aircraft_inventory_id uuid;
-- The fixture is a synthetic already-certified flight, not flight activation.
UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET aircraft_inventory_id='77777777-7777-4777-8777-777777777777'
 WHERE id='44444444-4444-4444-8444-444444444444';
INSERT INTO airlinerra_game.airline_aircraft_inventory
VALUES('77777777-7777-4777-8777-777777777777',
 '11111111-1111-4111-8111-111111111111','in_service');
INSERT INTO airlinerra_game.section9_route_commercial_plans_v1
VALUES('44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',1);
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1
 VALUES('44444444-4444-4444-8444-444444444444:2026-11-20:5',
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 DATE '2026-11-20',5,1,1,'2026-11-20 10:00:00+00',
 '2026-11-20 11:00:00+00',100,20);
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1
 VALUES('88888888-8888-4888-8888-888888888888',
 '44444444-4444-4444-8444-444444444444',DATE '2026-11-20',5,
 20,100,'closed','game_verified_saleable_schedule_v1',1,
 '2026-11-20 10:00:00+00','2026-11-20 11:00:00+00');
INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1
 VALUES
 ('99999999-9999-4999-8999-999999999999',
 '88888888-8888-4888-8888-888888888888','reserved',10,50,false,0),
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
 '88888888-8888-4888-8888-888888888888','reserved',10,50,false,0);
-- The already checked money fixture's 20 passengers and $1000
-- exactly match these two genuine reservation batches.

-- Replace the *clock only* stub; the signed game-hour implementation still
-- requires independent World 1 clock receipts not installed in this fixture.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb LANGUAGE sql AS $fn$
 SELECT jsonb_build_object('authoritativeGameHourAvailable',true,
  'gameHourUtc','2026-11-20T12:00:00Z','status','fixture_verified_game_hour');
$fn$;
-- Remove the two stand-in proof readers before extracting their actual source.
DROP FUNCTION airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(text);
DROP FUNCTION airlinerra_game.section9_postarrival_ticket_reconciliation_v1(text);
-- Real signed records, created only in isolated CI, with distinct event IDs.
INSERT INTO airlinerra_game.section9_operated_flight_movements_v1
(world_id,engine_event_id,flight_occurrence_id,phase,airline_id,
 aircraft_inventory_id,schedule_id,schedule_version,flight_local_date,
 weekly_entry,scheduled_departure_utc,scheduled_arrival_utc,
 actual_event_utc,source_kind,event_hmac_sha256)
SELECT 1,x.event_id,
 '44444444-4444-4444-8444-444444444444:2026-11-20:5',x.phase,
 '11111111-1111-4111-8111-111111111111'::uuid,
 '77777777-7777-4777-8777-777777777777'::uuid,
 '44444444-4444-4444-8444-444444444444'::uuid,1,
 DATE '2026-11-20',5,
 '2026-11-20 10:00:00+00'::timestamptz,
 '2026-11-20 11:00:00+00'::timestamptz,
 x.actual_utc,'signed_operated_game_flight_v1',
 encode(extensions.hmac(
 pg_catalog.convert_to(concat_ws(E'\n',
 'airlinerra-operated-game-event-v1','1',
 '11111111-1111-4111-8111-111111111111',
 '44444444-4444-4444-8444-444444444444',
 '1','2026-11-20','5',x.phase,
 to_char(x.actual_utc AT TIME ZONE 'UTC',
 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),x.event_id),'UTF8'),
 pg_catalog.convert_to(v.decrypted_secret,'UTF8'),'sha256'),'hex')
 FROM (VALUES
 ('departed','2026-11-20 10:02:00+00'::timestamptz,'signed-departure-01'),
 ('arrived','2026-11-20 11:02:00+00'::timestamptz,'signed-arrival-01')
 ) AS x(phase,actual_utc,event_id)
 CROSS JOIN vault.decrypted_secrets v
 WHERE v.name='airlinerra_operated_flight_auto_signing_v1';
-- Original finance evidence already points to 'arrived-proof-1' stub.
UPDATE airlinerra_game.section9_actual_ticket_finance_preparations_v1
 SET arrival_event_id='signed-arrival-01'
 WHERE schedule_id='44444444-4444-4444-8444-444444444444';
UPDATE airlinerra_game.section9_flight_final_cost_approvals_v1
 SET arrived_event_id='signed-arrival-01'
 WHERE airline_id='11111111-1111-4111-8111-111111111111';

-- To obtain real signatures in the following acceptance, the extracted
-- production verifier must read these canonical events unchanged.
