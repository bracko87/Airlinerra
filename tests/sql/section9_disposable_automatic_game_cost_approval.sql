-- Disposable test only: uses the existing real HMAC and ticket functions,
-- with controlled game tariff / clock fixtures and synthetic fuel receipts.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('auth') IS NOT NULL THEN RAISE EXCEPTION 'DISPOSABLE_ONLY';END IF;
END $$;
CREATE SCHEMA airlinerra;
CREATE TABLE airlinerra.aircraft_expansion_group3_economics_v1(fuel_price_assumption_usd_per_kg numeric);
INSERT INTO airlinerra.aircraft_expansion_group3_economics_v1 VALUES(1),(1);
CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(
 physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,configuration_id bigint,
 departure_engine_event_id text,planned_trip_burn_kg numeric,onboard_at_departure_kg numeric,
 planned_holding_reserve_kg numeric,planned_contingency_kg numeric);
CREATE TABLE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(
 physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,arrival_engine_event_id text,
 trip_burn_kg numeric,onboard_after_arrival_kg numeric);
INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 VALUES
 ('44444444-4444-4444-8444-444444444444:2026-11-20:5','11111111-1111-4111-8111-111111111111',
 '77777777-7777-4777-8777-777777777777',1,'signed-departure-01',300,500,150,20);
INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 VALUES
 ('44444444-4444-4444-8444-444444444444:2026-11-20:5','11111111-1111-4111-8111-111111111111',
 '77777777-7777-4777-8777-777777777777','signed-arrival-01',300,200);
-- Fixed synthetic tariff data. The production game tariff calculator is not
-- exercised by this test; real movement HMAC and ticket functions ARE.
CREATE TABLE airlinerra_game.test_game_tariffs(fee_lines jsonb);
INSERT INTO airlinerra_game.test_game_tariffs SELECT airport_fee_lines
 FROM airlinerra_game.section9_flight_final_cost_approvals_v1
 WHERE physical_flight_id='44444444-4444-4444-8444-444444444444:2026-11-20:5';
CREATE FUNCTION airlinerra_game.section9_completed_flight_game_cost_preview_v1(p_id text)
 RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('status','game_only_completed_flight_cost_estimate','physicalFlightId',p_id,
  'bookedPassengers',20,'quotedTicketFareUsd',1000,
  'airportTariffSource','SECTION8_PROVISIONAL_GAME_TARIFF_NOT_REAL_BILL','feeLinesAreItemized',true,
  'airportFeeQuoteModelVersion','DISPOSABLE_TARIFF_MODEL_V1',
  'originTariffVersion','disposable-origin-tariff','destinationTariffVersion','disposable-destination-tariff',
  'fuelPriceAssumptionUsdPerKg',1,'airportFeeLinesUsd',fee_lines,'airportCostEstimateUsd',200)
 FROM airlinerra_game.test_game_tariffs;
 $$;
DELETE FROM airlinerra_game.section9_flight_final_cost_approvals_v1
 WHERE physical_flight_id='44444444-4444-4444-8444-444444444444:2026-11-20:5';
\ir ../../server/sql/section9_completed_game_flight_cost_approval.sql
DO $test$
DECLARE fid text:='44444444-4444-4444-8444-444444444444:2026-11-20:5'; r jsonb;
BEGIN
 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1 SET release_state='paused';
 r:=airlinerra_game.section9_approve_completed_game_flight_cost_v1(fid);
 IF r->>'status'<>'blocked_game_cost_release' THEN RAISE EXCEPTION 'PAUSED: %',r;END IF;
 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1 SET release_state='approved';
 UPDATE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SET trip_burn_kg=301;
 r:=airlinerra_game.section9_approve_completed_game_flight_cost_v1(fid);
 IF r->>'status'<>'blocked_signed_fuel_or_movement_evidence' THEN RAISE EXCEPTION 'FUEL: %',r;END IF;
 UPDATE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SET trip_burn_kg=300;
 UPDATE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SET onboard_after_arrival_kg=149;
 r:=airlinerra_game.section9_approve_completed_game_flight_cost_v1(fid);
 IF r->>'status'<>'blocked_signed_fuel_or_movement_evidence' THEN RAISE EXCEPTION 'RESERVE: %',r;END IF;
 UPDATE airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 SET onboard_after_arrival_kg=200;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_final_cost_approvals_v1 WHERE physical_flight_id=fid)
 THEN RAISE EXCEPTION 'DENIED_APPROVAL_INSERTED';END IF;
 r:=airlinerra_game.section9_approve_completed_game_flight_cost_v1(fid);
 IF r->>'status'<>'game_flight_cost_approved' OR (r->>'fuelCostUsd')::numeric<>300
 OR (r->>'airportCostUsd')::numeric<>200 OR r->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'APPROVAL: %',r;END IF;
 r:=airlinerra_game.section9_approve_completed_game_flight_cost_v1(fid);
 IF r->>'status'<>'game_flight_cost_approval_replayed' THEN RAISE EXCEPTION 'REPLAY: %',r;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_flight_final_cost_approvals_v1 WHERE physical_flight_id=fid)<>1
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 WHERE physical_flight_id=fid)
 THEN RAISE EXCEPTION 'PREMATURE_SETTLEMENT';END IF;
 IF has_function_privilege('authenticated','airlinerra_game.section9_approve_completed_game_flight_cost_v1(text)','EXECUTE')
 THEN RAISE EXCEPTION 'PLAYER_APPROVAL_EXPOSED';END IF;
END $test$;
-- The next CI stage uses the original settlement function with this generated
-- approval and races six calls to verify one actual $1000-$500 ledger posting.
