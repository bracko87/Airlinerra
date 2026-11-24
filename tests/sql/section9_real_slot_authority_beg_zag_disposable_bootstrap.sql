-- Real SOURCE slot authority test on synthetic World1 draft/slots,
-- with actual read-only 2026-11-24 A319 BEG/ZAG/MUC 4-week game screens.
-- No real slot authority is impersonated and no certificate is issued.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.fixture_source_route_game_evidence') IS NULL
 OR to_regclass('airlinerra_game.section9_aoc_certificates_v1') IS NULL
 THEN RAISE EXCEPTION 'SLOT_TEST_REQUIRES_DISPOSABLE_AOC_SOURCE_AND_GAME_EVIDENCE';END IF;
END $guard$;

ALTER TABLE airlinerra_game.airport_unified_operations_v1
 ADD COLUMN game_runway_length_m numeric,
 ADD COLUMN operationally_authorized boolean NOT NULL DEFAULT true;
UPDATE airlinerra_game.airport_unified_operations_v1
 SET game_runway_length_m=CASE airport_key
  WHEN 'OURAIRPORTS:4610' THEN 3500
  WHEN 'OURAIRPORTS:3993' THEN 3251.9
  WHEN 'OURAIRPORTS:2218' THEN 3999.9
  ELSE 4000 END;

ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN reference_departure_utc timestamptz,
 ADD COLUMN reference_arrival_utc timestamptz,
 ADD COLUMN departure_stand_type text,
 ADD COLUMN arrival_stand_type text;
UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET reference_departure_utc='2026-11-28 10:00+00',
 reference_arrival_utc='2026-11-28 10:54+00',
 departure_stand_type='terminal',arrival_stand_type='terminal',
 weekly_schedule='[{"day":5,"time":"11:00"}]'::jsonb
 WHERE id='44444444-4444-4444-8444-444444444444';
UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET origin_airport_key='OURAIRPORTS:4610',
 destination_airport_key='OURAIRPORTS:2218',
 reference_departure_utc='2026-11-28 10:00+00',
 reference_arrival_utc='2026-11-28 11:34+00',
 departure_stand_type='terminal',arrival_stand_type='terminal',
 weekly_schedule='[{"day":5,"time":"11:00"}]'::jsonb
 WHERE id='55555555-5555-4555-8555-555555555555';

CREATE TABLE airlinerra_game.section6_airport_slot_capacity_v1(
 world_id smallint NOT NULL,airport_key text NOT NULL,
 game_total_slots_per_10m integer NOT NULL DEFAULT 20,
 game_stand_type text NOT NULL DEFAULT 'terminal',
 PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.section6_airport_slot_capacity_v1(world_id,airport_key)
 VALUES(1,'OURAIRPORTS:4610'),(1,'OURAIRPORTS:3993'),(1,'OURAIRPORTS:2218');

CREATE TABLE airlinerra_game.section9_verified_schedule_capacity_v1(
 schedule_id uuid NOT NULL,airline_id uuid NOT NULL,
 schedule_version integer NOT NULL,passenger_seats integer NOT NULL,
 PRIMARY KEY(schedule_id,schedule_version));
INSERT INTO airlinerra_game.section9_verified_schedule_capacity_v1
 SELECT id,airline_id,version,125 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id IN ('44444444-4444-4444-8444-444444444444',
              '55555555-5555-4555-8555-555555555555');

CREATE TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1(
 schedule_id uuid NOT NULL,airport_key text NOT NULL,
 stand_type text NOT NULL,direction text NOT NULL,
 weekday integer NOT NULL,minute_of_day integer NOT NULL,
 PRIMARY KEY(schedule_id,airport_key,direction,weekday,minute_of_day));

-- Two real-shaped bookings for one planned Saturday occurrence; they are
-- explicitly synthetic reservation source records, not signed by airport.
INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
 VALUES
 ('44444444-4444-4444-8444-444444444444','OURAIRPORTS:4610','terminal','departure',5,660),
 ('44444444-4444-4444-8444-444444444444','OURAIRPORTS:3993','terminal','arrival',5,714),
 ('55555555-5555-4555-8555-555555555555','OURAIRPORTS:4610','terminal','departure',5,660),
 ('55555555-5555-4555-8555-555555555555','OURAIRPORTS:2218','terminal','arrival',5,754);

CREATE TABLE airlinerra_game.fixture_slot_availability(
 singleton boolean PRIMARY KEY DEFAULT true,available boolean NOT NULL);
INSERT INTO airlinerra_game.fixture_slot_availability VALUES(true,true);

-- Reservation proposal and capacity engine are synthetic boundaries, but
-- the game slot AUTHORITY below is the actual unmodified deployed SQL.
CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_proposals_v1(
 p_world smallint,p_origin text,p_destination text,
 p_depart timestamptz,p_arrival timestamptz,
 p_weekly jsonb,p_depart_stand text,p_arrive_stand text)
RETURNS TABLE(airport_key text,stand_type text,direction text,
 weekday integer,minute_of_day integer)
LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT p_origin,p_depart_stand,'departure',5,
  extract(hour from p_depart at time zone 'Europe/Belgrade')::int*60
  +extract(minute from p_depart at time zone 'Europe/Belgrade')::int
 UNION ALL
 SELECT p_destination,p_arrive_stand,'arrival',5,
  extract(hour from p_arrival at time zone 'Europe/Berlin')::int*60
  +extract(minute from p_arrival at time zone 'Europe/Berlin')::int
$fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_preflight_v1(
 p_world smallint,p_origin text,p_destination text,
 p_depart timestamptz,p_arrival timestamptz,
 p_weekly jsonb,p_depart_stand text,p_arrive_stand text,p_schedule uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT jsonb_build_object('available',available,
 'departureAvailable',available,'arrivalAvailable',available)
 FROM airlinerra_game.fixture_slot_availability WHERE singleton
$fn$;

-- Supply the actual read-only game Section5 receipts. The route authority
-- independently validates every nested leg using real Section9 GAME SQL.
-- Fail closed for any source/timing changes.
CREATE OR REPLACE FUNCTION airlinerra_game.section5_weekly_route_restriction_gate_v1(
 p_world smallint,p_origin text,p_destination text,p_config bigint,
 p_depart timestamptz,p_arrival timestamptz,p_weekly jsonb)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT COALESCE(
 (SELECT screen.weekly_screen FROM airlinerra_game.fixture_source_route_game_evidence screen
 WHERE p_world=1 AND p_origin='OURAIRPORTS:4610'
 AND screen.destination_airport_key=p_destination
 AND p_config=100 AND p_depart='2026-11-28 10:00+00'::timestamptz
 AND (screen.phase_profile->>'totalMinutes')::int
  =extract(epoch from (p_arrival-p_depart))::int/60
 AND p_weekly='[{"day":5,"time":"11:00"}]'::jsonb),
 '{"weeklyTimetableChecked":false,"gameHardBlocked":true,"needsReview":true,"occurrences":[]}'::jsonb)
$fn$;
