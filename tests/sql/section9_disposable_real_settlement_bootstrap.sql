-- Only for a fresh, isolated PostgreSQL 17 instance named airlinerra_disposable.
-- Never run in any live/shared Supabase database.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable'
 OR current_user<>'postgres'
 OR to_regnamespace('airlinerra_game') IS NOT NULL
 OR to_regnamespace('auth') IS NOT NULL THEN
  RAISE EXCEPTION 'SECTION9_SETTLEMENT_FIXTURE_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE SCHEMA airlinerra_game;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE TABLE airlinerra_game.section9_flight_finance_posting_release_v1(
 world_id smallint primary key,release_state text,approved_at timestamptz,approval_reference text);
CREATE TABLE airlinerra_game.section9_activation_release_policy_v1(
 world_id smallint primary key,release_state text,enabled_at timestamptz,crew_mode text);
CREATE TABLE airlinerra_game.section9_trusted_execution_release_policy_v1(
 world_id smallint primary key,release_state text,enabled_at timestamptz);
CREATE TABLE airlinerra_game.section9_flight_engine_readiness_audit_v1(
 world_id smallint primary key,trusted_flight_execution_release text,
 fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled boolean);
CREATE TABLE airlinerra_game.airlines(
 id uuid primary key,world_id smallint,cash_usd numeric(16,2));
CREATE TABLE airlinerra_game.airline_ledger(
 id bigserial primary key,airline_id uuid,entry_kind text,amount_usd numeric(16,2));
CREATE TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1(
 physical_flight_id text primary key,airline_id uuid,schedule_id uuid,
 flight_local_date date,arrival_event_id text,passenger_count int,
 ticket_quote_usd numeric(16,2),preparation_status text,source_version text);
CREATE TABLE airlinerra_game.section9_flight_final_cost_approvals_v1(
 physical_flight_id text primary key,airline_id uuid,arrived_event_id text,
 approval_state text,approved_at timestamptz,approval_reference text,
 fuel_reserve_verified boolean,fuel_reserve_kg numeric(14,3),
 fuel_source_reference text,tariff_source_reference text,
 fuel_cost_usd numeric(16,2),airport_navigation_cost_usd numeric(16,2),
 crew_cost_usd numeric(16,2),maintenance_cost_usd numeric(16,2),
 ownership_cost_usd numeric(16,2),other_cost_usd numeric(16,2),
 airport_fee_lines jsonb,tariff_model_version text);
CREATE TABLE airlinerra_game.airline_flight_schedule_drafts_v1(
 id uuid primary key,airline_id uuid,version int,configuration_id bigint,
 status text,operationally_verified boolean);
CREATE TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1(
 configuration_id bigint primary key,financial_settlement_release text,
 operational_dispatch_release text,game_calculation_ready boolean);
CREATE TABLE airlinerra_game.section9_route_posted_flight_financials_v1(
 physical_flight_id text primary key,schedule_id uuid,airline_id uuid,
 flown_game_day date,arrived_event_id text,passenger_count integer,
 cargo_tonnes numeric,ticket_income_usd numeric(16,2),cargo_income_usd numeric(16,2),
 other_income_usd numeric(16,2),airport_navigation_cost_usd numeric(16,2),
 fuel_cost_usd numeric(16,2),crew_cost_usd numeric(16,2),
 maintenance_cost_usd numeric(16,2),ownership_cost_usd numeric(16,2),
 other_cost_usd numeric(16,2),airport_fee_lines jsonb,
 revenue_ledger_id bigint,expense_ledger_id bigint,
 tariff_model_version text,settlement_source_reference text,
 record_status text);
-- Controlled stand-ins for independently certified services ONLY.
-- No stub posts funds; the real production function under test does that.
CREATE TABLE airlinerra_game.test_independent_evidence(
 physical_flight_id text primary key, verified boolean not null default true);
CREATE FUNCTION airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(p_id text)
RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE r record;
BEGIN
 SELECT p.airline_id,p.schedule_id,p.arrival_event_id,e.verified INTO r
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 p
 LEFT JOIN airlinerra_game.test_independent_evidence e
 ON e.physical_flight_id=p.physical_flight_id
 WHERE p.physical_flight_id=p_id;
 RETURN jsonb_build_object(
  'status',CASE WHEN r.verified=true THEN 'signed_departure_and_arrival_verified'
  ELSE 'blocked_missing_mock_signed_events' END,
  'signatureVerified',coalesce(r.verified,false),
  'arrivalEventId',r.arrival_event_id,'scheduleId',r.schedule_id,
  'airlineId',r.airline_id);
END $fn$;
CREATE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
RETURNS jsonb LANGUAGE sql AS $fn$
 SELECT '{"authoritativeGameHourAvailable":true}'::jsonb;
$fn$;
CREATE FUNCTION airlinerra_game.section9_postarrival_ticket_reconciliation_v1(p_id text)
RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE r record;
BEGIN
 SELECT passenger_count,ticket_quote_usd INTO r
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=p_id;
 RETURN jsonb_build_object('status','postarrival_ticket_totals_reconciled',
  'reconciled',true,'financeAlreadyPosted',false,
  'ticketPassengers',r.passenger_count,'ticketIncomeUsd',r.ticket_quote_usd);
END $fn$;
INSERT INTO airlinerra_game.section9_flight_finance_posting_release_v1
 VALUES(1,'approved',now(),'disposable-independent-finance-proof-00001');
INSERT INTO airlinerra_game.section9_activation_release_policy_v1
 VALUES(1,'enabled',now(),'deferred_phase1');
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1
 VALUES(1,'enabled',now());
INSERT INTO airlinerra_game.section9_flight_engine_readiness_audit_v1
 VALUES(1,'ACTIVATED','ACTIVATED',true);
INSERT INTO airlinerra_game.section9_game_fuel_model_snapshot_v1
 VALUES(1,'RELEASED','RELEASED',true);
-- Three isolated scenarios: valid, insufficient cash, inconsistent ledger.
DO $fixtures$
DECLARE
 ids uuid[]:=ARRAY[
 '11111111-1111-4111-8111-111111111111'::uuid,
 '22222222-2222-4222-8222-222222222222'::uuid,
 '33333333-3333-4333-8333-333333333333'::uuid];
 schedules uuid[]:=ARRAY[
 '44444444-4444-4444-8444-444444444444'::uuid,
 '55555555-5555-4555-8555-555555555555'::uuid,
 '66666666-6666-4666-8666-666666666666'::uuid];
 amounts numeric[]:=ARRAY[5000,100,5000];
 i integer; fid text;fee jsonb;
BEGIN
 fee:=jsonb_build_object(
 'departureAirportMovementUsd',20,'arrivalLandingUsd',40,
 'departureGroundHandlingUsd',20,'arrivalStandParkingUsd',25,
 'departureTerminalAirTrafficControlUsd',20,'enrouteAirTrafficControlUsd',50,
 'departingPassengerFacilityUsd',10,'departingPassengerSecurityUsd',10,
 'internationalPassengerProcessingUsd',0,'originCargoHandlingUsd',0,
 'destinationCargoHandlingUsd',5);
 FOR i IN 1..3 LOOP
  fid:=schedules[i]::text||':2026-11-20:5';
  INSERT INTO airlinerra_game.airlines VALUES(ids[i],1,amounts[i]);
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
  VALUES(ids[i],'OPENING',CASE WHEN i=3 THEN 4999 ELSE amounts[i] END);
  INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1
  VALUES(schedules[i],ids[i],1,1,'active',true);
  INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1
  VALUES(fid,ids[i],schedules[i],DATE '2026-11-20',
   'arrived-proof-'||i,20,CASE WHEN i=2 THEN 0 ELSE 1000 END,
   'UNPOSTED_GAME_ESTIMATE','ACTUAL_TICKET_POSTARRIVAL_PREP_V1');
  INSERT INTO airlinerra_game.test_independent_evidence VALUES(fid,true);
  INSERT INTO airlinerra_game.section9_flight_final_cost_approvals_v1
  VALUES(fid,ids[i],'arrived-proof-'||i,'approved',now(),
    'disposable-final-cost-approval-0000'||i,
    true,150,'disposable-fuel-reserve-proof-000'||i,
    'disposable-airport-tariff-proof-000'||i,
    300,200,0,0,0,0,fee,'DISPOSABLE_TARIFF_MODEL_V1');
 END LOOP;
END $fixtures$;
-- Make overlapping real-function calls deterministic for the concurrency test.
CREATE FUNCTION airlinerra_game.test_pause_revenue_post()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
 IF NEW.entry_kind='REVENUE' THEN PERFORM pg_sleep(0.8); END IF;
 RETURN NEW;
END $fn$;
CREATE TRIGGER test_pause_finance_revenue
BEFORE INSERT ON airlinerra_game.airline_ledger
FOR EACH ROW EXECUTE FUNCTION airlinerra_game.test_pause_revenue_post();
