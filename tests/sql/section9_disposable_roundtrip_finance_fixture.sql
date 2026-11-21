-- Continuation of the same two clock-driven flights, not a new fixture.
-- Only the fare/demand records and game tariff quote are synthetic. Actual
-- movements, usage, fuel receipts, reconciliation, cost approval and ledger
-- posting refer to the exact same physical occurrence identities.
\set ON_ERROR_STOP on
DO $$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('auth') IS NOT NULL
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>4
 THEN RAISE EXCEPTION 'DISPOSABLE_OPERATED_PAIR_ONLY';END IF;
END $$;
ALTER TABLE airlinerra_game.airlines ADD COLUMN cash_usd numeric(16,2);
UPDATE airlinerra_game.airlines SET cash_usd=5000000;
CREATE TABLE airlinerra_game.airline_ledger(id bigserial PRIMARY KEY,airline_id uuid,entry_kind text,amount_usd numeric(16,2));
INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd) SELECT id,'OPENING',cash_usd FROM airlinerra_game.airlines;
ALTER TABLE airlinerra_game.section9_flight_finance_posting_release_v1 ADD COLUMN approval_reference text;
UPDATE airlinerra_game.section9_flight_finance_posting_release_v1 SET approval_reference='fixture-reviewed-commercial-game-finance';
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1 ADD COLUMN schedule_id uuid,ADD COLUMN airline_id uuid,
 ADD COLUMN local_departure_date date,ADD COLUMN weekly_entry int,ADD COLUMN cargo_held_tonnes numeric NOT NULL DEFAULT 0;
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1 c SET schedule_id=o.schedule_id,airline_id=o.airline_id,
 local_departure_date=o.flight_local_date,weekly_entry=o.weekly_entry
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE c.physical_flight_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry;
CREATE TABLE airlinerra_game.section9_passenger_reservation_batches_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),occurrence_id uuid, reservation_status text,seats_requested int,
 quoted_fare_usd numeric,paid_upfront boolean,recognized_revenue_usd numeric);
INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(occurrence_id,reservation_status,seats_requested,quoted_fare_usd,paid_upfront,recognized_revenue_usd)
 SELECT o.id,'reserved',10,p.economy_fare_usd,false,0
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.section9_route_commercial_plans_v1 p ON p.schedule_id=o.schedule_id
 CROSS JOIN generate_series(1,2);
CREATE TABLE airlinerra.aircraft_expansion_group3_economics_v1(fuel_price_assumption_usd_per_kg numeric);
INSERT INTO airlinerra.aircraft_expansion_group3_economics_v1 VALUES(1);
CREATE FUNCTION airlinerra_game.section9_completed_flight_game_cost_preview_v1(p_id text) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object(
 'status','game_only_completed_flight_cost_estimate','sourceVersion','GAME_COST_PREVIEW_V1_NEVER_POST',
 'physicalFlightId',p_id,'bookedPassengers',o.booked_seats,'quotedTicketFareUsd',o.booked_seats*p.economy_fare_usd,
 'readOnly',true,'ledgerPosted',false,'readyForActualExpensePosting',false,'accountingApproved',false,
 'fuelPlanningReserveIncluded',true,'withinGameTankIncludingReserve',true,'reserveFuelChargedAsBurn',false,
 'feeLinesAreItemized',true,'fuelPriceAssumptionUsdPerKg',1,'fuelCostEstimateUsd',300,
 'airportCostEstimateUsd',200,'operatingCostEstimateUsd',500,'airportTariffSource','SECTION8_PROVISIONAL_GAME_TARIFF_NOT_REAL_BILL',
 'airportFeeQuoteModelVersion','DISPOSABLE_TARIFF_MODEL_V1','originTariffVersion','fixture-origin-tariff','destinationTariffVersion','fixture-destination-tariff',
 'airportFeeLinesUsd',jsonb_build_object(
 'departureAirportMovementUsd',20,'arrivalLandingUsd',40,'departureGroundHandlingUsd',20,'arrivalStandParkingUsd',25,
 'departureTerminalAirTrafficControlUsd',20,'enrouteAirTrafficControlUsd',50,'departingPassengerFacilityUsd',10,
 'departingPassengerSecurityUsd',10,'internationalPassengerProcessingUsd',0,'originCargoHandlingUsd',0,'destinationCargoHandlingUsd',5))
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.section9_route_commercial_plans_v1 p ON p.schedule_id=o.schedule_id
 WHERE p_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry
 $$;
-- Exact production prep and approval DDL and actual functions are installed
-- by CI. The ledger/posted-finance schemas are minimal settlement fixtures.
