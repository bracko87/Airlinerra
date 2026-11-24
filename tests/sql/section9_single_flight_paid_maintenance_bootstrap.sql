-- Synthetic policy, aircraft usage and money ledger for the exact current
-- GAME maintenance booking/due/dispatch/settlement functions. Never execute
-- against Supabase or a shared player database.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
    OR to_regclass('airlinerra_game.fixture_single_route_control') IS NULL
 THEN RAISE EXCEPTION 'MAINTENANCE_FLIGHT_DISPOSABLE_ONLY'; END IF;
END $guard$;
ALTER TABLE airlinerra_game.airline_aircraft_inventory ADD COLUMN registration text DEFAULT 'TEST-001';
CREATE TABLE airlinerra_game.fixture_game_now (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 simulated_now timestamptz NOT NULL
);
INSERT INTO airlinerra_game.fixture_game_now VALUES(true,'2026-11-21 07:00:00+00');
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_world_instant_v1()
RETURNS timestamptz LANGUAGE sql VOLATILE AS $f$
 SELECT simulated_now FROM airlinerra_game.fixture_game_now WHERE singleton
$f$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
RETURNS jsonb LANGUAGE sql STABLE AS $f$
 SELECT jsonb_build_object('authoritativeGameHourAvailable',true,
 'gameDate',(simulated_now AT TIME ZONE 'Europe/Berlin')::date,
 'gameHourUtc',simulated_now)
 FROM airlinerra_game.fixture_game_now WHERE singleton
$f$;
CREATE TABLE public.airlinerra_game_worlds(id smallint PRIMARY KEY,state text);
INSERT INTO public.airlinerra_game_worlds VALUES (1,'active');
CREATE TABLE airlinerra_game.holding_world_clock_v1(
 world_id smallint PRIMARY KEY,confirmed_game_date date,clock_source text,
 last_verified_at timestamptz);
INSERT INTO airlinerra_game.holding_world_clock_v1
 VALUES (1,'2026-11-21','authoritative_game_engine','2026-11-21 07:00+00');
CREATE TABLE airlinerra_game.maintenance_check_policy_v1(
 check_code text PRIMARY KEY,display_name text,downtime_hours integer,
 calendar_interval_hours integer,calendar_interval_months integer,
 flight_hour_interval numeric,airport_scope text);
INSERT INTO airlinerra_game.maintenance_check_policy_v1
 (check_code,display_name,downtime_hours,calendar_interval_hours,
  calendar_interval_months,flight_hour_interval,airport_scope) VALUES
 ('daily','Daily',1,24,NULL,NULL,'any_approved_airport'),
 ('weekly','Weekly',3,168,NULL,NULL,'any_approved_airport'),
 ('a','A',6,NULL,NULL,500,'type_approved_mro'),
 ('b','B',24,NULL,NULL,750,'type_approved_mro'),
 ('c','C',168,NULL,24,5500,'type_approved_mro'),
 ('d','D',504,NULL,96,NULL,'type_approved_mro');
CREATE TABLE airlinerra_game.section9_starter_game_airframe_baselines_v1(
 aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,owner_player_id uuid,
 world_id smallint,game_baseline_date date,game_age_years smallint,
 game_condition_pct numeric,source_kind text);
INSERT INTO airlinerra_game.section9_starter_game_airframe_baselines_v1 VALUES
 ('33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
  1,'2026-11-13',0,92,'synthetic_game_allocation_v1');
CREATE TABLE airlinerra_game.aircraft_maintenance_state_v1(
 aircraft_inventory_id uuid PRIMARY KEY,airline_id uuid,tracked_flight_hours numeric,
 tracked_flight_cycles bigint,verified_tracking_started_utc timestamptz);
INSERT INTO airlinerra_game.aircraft_maintenance_state_v1 VALUES
 ('33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',0,0,'2026-11-13 00:00+00');
CREATE TABLE airlinerra_game.airline_ledger(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 airline_id uuid NOT NULL,entry_kind text NOT NULL,amount_usd numeric NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now());
INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 VALUES('11111111-1111-4111-8111-111111111111','CAPITAL',5000000);
CREATE TABLE airlinerra_game.section9_game_maintenance_jobs_v1(
 job_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint DEFAULT 1,owner_player_id uuid,airline_id uuid,
 aircraft_inventory_id uuid,check_code text,airport_key text,
 game_start_utc timestamptz,game_end_utc timestamptz,duration_hours integer,
 status text DEFAULT 'scheduled',condition_before_game_pct numeric,
 flight_hours_at_book numeric,engine_start_observed_at timestamptz,
 engine_completion_observed_at timestamptz,quoted_cost_usd numeric,
 paid_ledger_entry_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 created_at timestamptz DEFAULT now(),
 CHECK ((status='completed')=(paid_ledger_entry_id IS NOT NULL)),
 CHECK (status IN ('scheduled','in_progress','payment_required','completed','cancelled')),
 CHECK (game_end_utc=game_start_utc+make_interval(hours=>duration_hours)));
CREATE UNIQUE INDEX only_one_unfinished_maintenance_job_fixture
 ON airlinerra_game.section9_game_maintenance_jobs_v1(aircraft_inventory_id)
 WHERE status IN('scheduled','in_progress','payment_required');
CREATE TABLE airlinerra_game.section9_game_maintenance_service_receipts_v1(
 job_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_game_maintenance_jobs_v1(job_id),
 world_id smallint DEFAULT 1,airline_id uuid,aircraft_inventory_id uuid,
 check_code text,game_completed_at_utc timestamptz,flight_hours_at_game_completion numeric,
 source_kind text DEFAULT 'verified_game_service_job_v1',
 created_at timestamptz DEFAULT now(),
 paid_ledger_entry_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 settled_cost_usd numeric);
CREATE TABLE airlinerra_game.approved_game_airports(world_id smallint,airport_key text,
 PRIMARY KEY(world_id,airport_key));
INSERT INTO airlinerra_game.approved_game_airports VALUES
 (1,'OURAIRPORTS:2212'),(1,'OURAIRPORTS:2218');
-- The real booking function references the heavy-check capability catalogue
-- even when the selected Daily/Weekly policy does not require an MRO.
CREATE TABLE airlinerra_game.maintenance_airport_capabilities_v1(
 world_id smallint,airport_key text,configuration_id bigint,
 check_code text,approval_status text);
-- Synthetic maintenance price quotes; do not imply these are live tariffs.
CREATE TABLE airlinerra_game.aircraft_maintenance_check_overview_v1(
 aircraft_inventory_id uuid,airline_id uuid,check_code text,base_estimate_usd numeric,
 cost_evidence text,PRIMARY KEY(aircraft_inventory_id,check_code));
INSERT INTO airlinerra_game.aircraft_maintenance_check_overview_v1
 VALUES
 ('33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111','daily',125,
  'provisional_game_tariff_not_vendor_quote'),
 ('33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111','weekly',450,
  'provisional_game_tariff_not_vendor_quote');
-- Only the slot service is stubbed; the booking, job advancement,
-- maintenance due, flight-window and dispatch-window SQL is genuine.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_start_utc timestamptz,p_end_utc timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $f$
 SELECT jsonb_build_object('status','hourly_maintenance_slot_clear',
 'slotClear',true,'readOnly',true,'ledgerPosted',false)
$f$;