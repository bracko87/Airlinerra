-- Disposable PostgreSQL 17 ONLY. Exact deployed (2026-11-24) canonical
-- AOC and Licence1/Licence2 functions run on synthetically seeded source
-- documents using true source checks. No real airline/customer data copied.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.airline_flight_schedule_drafts_v1') IS NULL
 OR to_regclass('airlinerra_game.section9_aoc_certificates_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'CANONICAL_AOC_RIGHTS_REQUIRES_CLEAN_DISPOSABLE_FLIGHT_FIXTURE';END IF;
END $guard$;
ALTER TABLE airlinerra_game.airlines ADD COLUMN home_airport_key text;
UPDATE airlinerra_game.airlines SET home_airport_key='OURAIRPORTS:4610' WHERE world_id=1;
CREATE TABLE public.airlinerra_game_worlds(
 id smallint PRIMARY KEY,state text,opens_at timestamptz);
INSERT INTO public.airlinerra_game_worlds VALUES(1,'active',now()-interval '7 days');
CREATE TABLE airlinerra_game.holding_world_clock_v1(
 world_id smallint PRIMARY KEY,confirmed_game_date date,clock_source text,
 last_verified_at timestamptz,engine_proof_ref text);
INSERT INTO airlinerra_game.holding_world_clock_v1
 VALUES(1,'2026-11-24','authoritative_game_engine',now(),
 'SYNTHETIC_VERIFIED_TICK_NO_PRODUCTION_PLAYER_DATA');
CREATE TABLE airlinerra_game.section9_verified_game_tick_receipts_v1(
 world_id smallint NOT NULL,game_date date NOT NULL,engine_event_id text,
 PRIMARY KEY(world_id,game_date));
INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1
 VALUES(1,'2026-11-24','synthetic-ci-tick-only');
CREATE TABLE airlinerra_game.airport_reference_profiles(
 world_id smallint NOT NULL,airport_key text NOT NULL,country_iso text,
 PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.airport_reference_profiles VALUES
(1,'OURAIRPORTS:4610','RS'),(1,'OURAIRPORTS:3993','HR'),
(1,'OURAIRPORTS:2212','DE'),(1,'OURAIRPORTS:2218','DE');
CREATE TABLE airlinerra_game.airport_unified_operations_v1(
 world_id smallint,airport_key text,country_iso text,game_category text,
 dispatch_eligible_by_airport_admission boolean,
 PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.airport_unified_operations_v1 VALUES
(1,'OURAIRPORTS:4610','RS','Major Hub',true),
(1,'OURAIRPORTS:3993','HR','Large',true),
(1,'OURAIRPORTS:2212','DE','Major Hub',true),
(1,'OURAIRPORTS:2218','DE','Major Hub',true);
CREATE TABLE airlinerra_game.aviation_countries_v1(iso2 text PRIMARY KEY);
INSERT INTO airlinerra_game.aviation_countries_v1 VALUES('RS'),('HR'),('DE');
CREATE TABLE airlinerra_game.section9_aoc_release_policy_v1(
 world_id smallint PRIMARY KEY,
 issuance_enabled boolean NOT NULL,
 safety_events_enabled boolean NOT NULL,
 renewal_enabled boolean NOT NULL,
 flight_enforcement_enabled boolean NOT NULL);
INSERT INTO airlinerra_game.section9_aoc_release_policy_v1
 VALUES(1,true,true,true,true);
CREATE TABLE airlinerra_game.section9_aoc_operating_companies_v1(
 world_id smallint NOT NULL,airline_id uuid NOT NULL,
 business_kind text,company_source text,identity_evidence_reference text,
 PRIMARY KEY(world_id,airline_id));
INSERT INTO airlinerra_game.section9_aoc_operating_companies_v1
 SELECT 1,a.id,'passenger','original',
 'verified-original-airline-registration-v1-'||a.id::text
 FROM airlinerra_game.airlines a WHERE world_id=1;
CREATE TABLE airlinerra_game.section9_aoc_certificates_v1(
 airline_id uuid NOT NULL,world_id smallint NOT NULL,
 status text,issued_game_day date,expires_game_day date,
 initial_issue_source text,initial_issue_application_id uuid,
 initial_issue_ledger_id bigint,
 PRIMARY KEY(world_id,airline_id));
INSERT INTO airlinerra_game.section9_aoc_certificates_v1
 SELECT a.id,1,'active','2026-11-21','2027-11-21',
 'original_free_registration',NULL,NULL
 FROM airlinerra_game.airlines a WHERE world_id=1;
CREATE TABLE airlinerra_game.fixture_safety_rating(
 airline_id uuid PRIMARY KEY,game_rating integer NOT NULL DEFAULT 90);
INSERT INTO airlinerra_game.fixture_safety_rating
 SELECT id,90 FROM airlinerra_game.airlines WHERE world_id=1;
-- Safety source only is synthetic: the AOC verifier and 70-point bound
-- are actual deployed game SQL, no real safety record is fabricated.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_safety_score_v1(
 p_airline uuid,p_day date)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT jsonb_build_object('rating',r.game_rating)
 FROM airlinerra_game.fixture_safety_rating r WHERE r.airline_id=p_airline
$fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1()
RETURNS date LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT confirmed_game_date FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1
$fn$;
CREATE TABLE airlinerra_game.licence2_market_policy_v1(
 market_code text PRIMARY KEY,issuance_enabled boolean,enforcement_enabled boolean);
INSERT INTO airlinerra_game.licence2_market_policy_v1 VALUES
('L2-EU',false,false);
CREATE TABLE airlinerra_game.licence2_airline_market_permits_v1(
 world_id smallint,airline_id uuid,market_code text,level integer,status text);
CREATE TABLE airlinerra_game.licence2_market_levels_v1(
 market_code text,level integer,quota_approved boolean,
 max_category text,max_active_directed_routes integer);
CREATE TABLE airlinerra_game.airport_offices(
 world_id smallint,airline_id uuid,office_type text,office_status text,airport_key text);
CREATE TABLE airlinerra_game.licence2_directed_route_allocations_v1(
 world_id smallint,airline_id uuid,origin_airport_key text,
 destination_airport_key text,market_code text,allocation_state text);

-- Existing two synthetic route drafts from the shared disposable fixture.
-- This verifies BOTH the L1 international home-origin case and L2-only
-- foreign-to-foreign FRA->MUC denial for a Serbia-home airline.
UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET origin_airport_key='OURAIRPORTS:4610',
 destination_airport_key='OURAIRPORTS:3993'
 WHERE id='44444444-4444-4444-8444-444444444444';
-- Other draft is FRA->MUC from the common fixture.
