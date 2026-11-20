-- PostgreSQL 17 disposable-only minimal setup for the actual production
-- certified round-trip activation function. No browser or live DB access.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('airlinerra_game') IS NOT NULL
 OR to_regnamespace('auth') IS NOT NULL THEN
 RAISE EXCEPTION 'SECTION9_ACTIVATION_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE SCHEMA airlinerra_game;
CREATE SCHEMA airlinerra;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,crew_mode text,
 enabled_at timestamptz,reviewed_at timestamptz);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,enabled_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_finance_posting_release_v1(
 world_id smallint PRIMARY KEY,release_state text,approved_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(
 world_id smallint PRIMARY KEY,trusted_flight_execution_release text,
 fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled boolean);
CREATE TABLE airlinerra_game.fixture_clock(
 world_id smallint PRIMARY KEY,day date,verified boolean);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb LANGUAGE sql STABLE AS $clock$
 SELECT jsonb_build_object(
 'authoritativeGameHourAvailable',verified,
 'gameDate',day,
 'gameHourUtc','2026-11-20T12:00:00Z')
 FROM airlinerra_game.fixture_clock WHERE world_id=1;
$clock$;
CREATE TABLE airlinerra_game.airlines(
 id uuid PRIMARY KEY,world_id smallint,owner_player_id uuid);
CREATE TABLE airlinerra_game.world_memberships(
 world_id smallint,player_id uuid,state text);
CREATE TABLE airlinerra_game.fixture_effects(
 id integer PRIMARY KEY,kind text NOT NULL);
INSERT INTO airlinerra_game.section9_activation_release_policy_v1
 VALUES(1,'paused','deferred_phase1',NULL,NULL);
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1
 VALUES(1,'disabled',NULL);
INSERT INTO airlinerra_game.section9_flight_finance_posting_release_v1
 VALUES(1,'paused',NULL);
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1
 VALUES(1,'NOT_ACTIVATED','NOT_ACTIVATED',false);
INSERT INTO airlinerra_game.fixture_clock VALUES(1,DATE '2026-11-20',true);
INSERT INTO airlinerra_game.airlines VALUES(
 '11111111-1111-4111-8111-111111111111',1,
 '22222222-2222-4222-8222-222222222222');
INSERT INTO airlinerra_game.world_memberships VALUES(
 1,'22222222-2222-4222-8222-222222222222','active');
