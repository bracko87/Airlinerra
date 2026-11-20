-- Extend the existing disposable real source fixture for the original
-- production 20261109195500 certification sink (no schema shortcuts in
-- the function itself). Rows remain entirely test-only.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.fixture_verified_clock') IS NULL THEN
 RAISE EXCEPTION 'SECTION9_CERTIFICATION_SINK_FIXTURE_NOT_DISPOSABLE';
 END IF;
END $guard$;
CREATE TABLE airlinerra_game.airlines(
 id uuid PRIMARY KEY,world_id smallint,owner_player_id uuid);
INSERT INTO airlinerra_game.airlines VALUES(
 '11111111-1111-4111-8111-111111111111',1,
 '22222222-2222-4222-8222-222222222222');
ALTER TABLE airlinerra_game.section9_operational_certification_events_v1
 ADD COLUMN airline_id uuid,
 ADD COLUMN valid_from_game_date date,
 ADD COLUMN valid_to_game_date date,
 ADD COLUMN verified_hmac_sha256 text,
 ADD COLUMN recorded_at timestamptz DEFAULT clock_timestamp();
ALTER TABLE airlinerra_game.section9_schedule_operational_certifications_v1
 ADD COLUMN reviewed_at timestamptz DEFAULT clock_timestamp();
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN departure_stand_type text DEFAULT 'terminal',
 ADD COLUMN arrival_stand_type text DEFAULT 'terminal';
CREATE TABLE airlinerra_game.section9_schedule_activation_preparations_v1(
 schedule_id uuid,schedule_version integer,PRIMARY KEY(schedule_id,schedule_version));
-- Stubs required by the unchanged function's non-execution/non-finance
-- branches at function compilation time. Those branches are not used in
-- this integration and are tested elsewhere with their real implementations.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_licence_preflight_v1(
 uuid,uuid,uuid,date,integer)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"permissions":{"gameOperatorLicenceEvidenceRecorded":false}}'::jsonb;
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_rest_preview_v1(
 uuid,uuid,uuid,date,integer)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{}'::jsonb;
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_operator_licence_v1(
 uuid,uuid,integer,date)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"verified":false}'::jsonb;
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_game_route_traffic_rights_v1(
 uuid,uuid,integer,date)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"verified":false}'::jsonb;
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_slot_clearance_source_v1(
 uuid,uuid,integer,date)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"verified":false}'::jsonb;
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_proposals_v1(
 smallint,text,text,timestamptz,timestamptz,jsonb,text,text)
 RETURNS TABLE(airport_key text,stand_type text,direction text,
 weekday int,minute_of_day int)
 LANGUAGE sql STABLE AS $fn$
 SELECT NULL::text,NULL::text,NULL::text,NULL::int,NULL::int WHERE false;
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_preflight_v1(
 smallint,text,text,timestamptz,timestamptz,jsonb,text,text,uuid)
 RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT '{"available":false}'::jsonb;
$fn$;
CREATE TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1(
 schedule_id uuid,airport_key text,stand_type text,direction text,
 weekday integer,minute_of_day integer);
