-- Fresh PG17 disposable database only, never use on production.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('airlinerra_game') IS NOT NULL
 OR to_regnamespace('auth') IS NOT NULL THEN
  RAISE EXCEPTION 'SNAPSHOT_FIXTURE_DISPOSABLE_ONLY';
 END IF;
END $guard$;
CREATE SCHEMA airlinerra_game;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,crew_mode text,
 enabled_at timestamptz,reviewed_at timestamptz,release_reference text);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,enabled_at timestamptz,
 reviewed_at timestamptz,approved_by text,release_reference text);
CREATE TABLE airlinerra_game.section9_flight_finance_posting_release_v1(
 world_id smallint PRIMARY KEY,release_state text,
 approved_at timestamptz,approval_reference text);
CREATE TABLE airlinerra_game.section9_fuel_and_settlement_release_policy_v1(
 world_id smallint PRIMARY KEY,release_state text,
 review_reference text,execution_producer_evidence text,
 fuel_writer_evidence text,settlement_writer_evidence text);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(
 world_id smallint PRIMARY KEY,
 trusted_flight_execution_release text,
 fuel_transaction_release text,
 automatic_flight_and_fuel_settlement_enabled boolean);
CREATE TABLE airlinerra_game.fixture_verified_clock(
 game_date date,enabled boolean);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
RETURNS jsonb LANGUAGE sql STABLE AS $fn$
 SELECT jsonb_build_object(
  'status',CASE WHEN enabled THEN 'verified_berlin_realtime_hour'
       ELSE 'blocked_game_day_hour_not_synchronized' END,
  'authoritativeGameHourAvailable',enabled,
  'gameDate',game_date,'berlinDate',game_date,'readOnly',true)
 FROM airlinerra_game.fixture_verified_clock
 LIMIT 1;
$fn$;
CREATE TABLE airlinerra_game.airline_flight_schedule_drafts_v1(
 id uuid PRIMARY KEY,airline_id uuid,world_id smallint,
 version integer,status text,operationally_verified boolean,
 aircraft_inventory_id uuid,configuration_id bigint,
 origin_airport_key text,destination_airport_key text,
 reference_departure_utc timestamptz,reference_arrival_utc timestamptz,
 weekly_schedule jsonb);
CREATE TABLE airlinerra_game.airline_aircraft_inventory(
 id uuid PRIMARY KEY,airline_id uuid,configuration_id bigint,
 ownership_type text,fleet_status text);
CREATE TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1(
 configuration_id bigint PRIMARY KEY,game_calculation_ready boolean,
 operational_dispatch_release text,financial_settlement_release text);
CREATE TABLE airlinerra_game.section9_operational_certification_events_v1(
 event_id text PRIMARY KEY,schedule_id uuid,
 schedule_version integer,clearance_type text,action text,
 source_kind text,source_reference text,reviewer_reference text);
CREATE TABLE airlinerra_game.section9_schedule_operational_certifications_v1(
 schedule_id uuid,schedule_version integer,airline_id uuid,
 clearance_type text,review_status text,last_verified_event_id text,
 source_kind text,source_reference text,reviewer_reference text,
 valid_from_game_date date,valid_to_game_date date,
 PRIMARY KEY(schedule_id,schedule_version,clearance_type));
INSERT INTO airlinerra_game.section9_activation_release_policy_v1
VALUES(1,'enabled','deferred_phase1',now(),now(),'disposable-activation-approval-2026-11-20');
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1
VALUES(1,'enabled',now(),now(),'disposable-operator-1',
 'disposable-trusted-execution-release-2026');
INSERT INTO airlinerra_game.section9_flight_finance_posting_release_v1
VALUES(1,'approved',now(),'disposable-finance-post-approval-2026');
INSERT INTO airlinerra_game.section9_fuel_and_settlement_release_policy_v1
VALUES(1,'enabled','disposable-reviewed-fuel-release-2026',
 'disposable-execution-producer-evidence-2026',
 'disposable-fuel-writer-source-evidence-2026',
 'disposable-settlement-writer-evidence-2026');
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1
VALUES(1,'ACTIVATED','ACTIVATED',true);
INSERT INTO airlinerra_game.fixture_verified_clock
VALUES(DATE '2026-11-20',true);
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1
VALUES(
 '44444444-4444-4444-8444-444444444444',
 '11111111-1111-4111-8111-111111111111',
 1,1,'draft',false,
 '33333333-3333-4333-8333-333333333333',100,
 'OURAIRPORTS:2212','OURAIRPORTS:2218',
 '2026-11-21 10:00:00+00','2026-11-21 11:00:00+00',
 '[{"weekday":6,"departure":"10:00"}]'::jsonb
);
INSERT INTO airlinerra_game.airline_aircraft_inventory VALUES(
 '33333333-3333-4333-8333-333333333333',
 '11111111-1111-4111-8111-111111111111',100,'owned','in_service');
INSERT INTO airlinerra_game.section9_game_fuel_model_snapshot_v1
VALUES(100,true,'RELEASED','RELEASED');
DO $fixture$
DECLARE kind text; evt text;
BEGIN
 FOREACH kind IN ARRAY ARRAY[
  'operator_licence','route_traffic_rights','airport_slot_capacity']
 LOOP
  evt:='disposable-'||kind||'-certification-2026-11-20';
  INSERT INTO airlinerra_game.section9_operational_certification_events_v1
  VALUES(evt,'44444444-4444-4444-8444-444444444444',1,kind,'certify',
    'disposable-'||kind,'disposable-cert-reference-'||kind,
    'disposable-reviewer-2026');
  INSERT INTO airlinerra_game.section9_schedule_operational_certifications_v1
  VALUES('44444444-4444-4444-8444-444444444444',1,
   '11111111-1111-4111-8111-111111111111',kind,'certified',evt,
   'disposable-'||kind,'disposable-cert-reference-'||kind,
   'disposable-reviewer-2026',DATE '2026-11-20',DATE '2026-12-31');
 END LOOP;
END $fixture$;
