import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source=()=>readFile(new URL(
 '../supabase/migrations/20261117103500_section9_reserve_fuel_itemized_airport_estimates_v1.sql',
 import.meta.url),'utf8');

test('reserve-aware fuel adds protected reserve and contingency to the existing five-phase model',async()=>{
 const s=await source();
 assert.match(s,/section9_game_reserve_aware_fuel_quote_v1/);
 assert.match(s,/section9_game_five_phase_fuel_quote_v1/);
 assert.match(s,/reference_reserve_minutes integer:=45/);
 assert.match(s,/reference_reserve_burn_factor numeric:=0\.60/);
 assert.match(s,/contingency_fraction numeric:=0\.05/);
 assert.match(s,/required_kg:=trip_kg\+contingency_kg\+reserve_kg/);
 assert.match(s,/withinGameTankIncludingReserve',required_kg<=tank_kg/);
 assert.match(s,/reserveConsumedOrBilledNow',false/);
 assert.match(s,/alternateAirportFuelCalculated',false/);
 assert.match(s,/actualFuelOnBoardVerified',false|aircraftActualFuelOnBoardVerified',false/);
});
test('invalid or overlong fuel phases are rejected before legacy estimator throws',async()=>{
 const s=await source();
 assert.match(s,/blocked_fuel_quote_duration_exceeds_game_limit/);
 const duration=s.indexOf('blocked_fuel_quote_duration_exceeds_game_limit');
 const quote=s.indexOf('existing:=airlinerra_game.section9_game_five_phase_fuel_quote_v1');
 assert.ok(duration>=0&&quote>duration);
 assert.match(s,/p_taxi_out_minutes\+p_climb_minutes\+p_cruise_minutes/);
 assert.match(s,/blocked_incomplete_fuel_model/);
 assert.match(s,/withinGameTankIncludingReserve/);
});
test('airport quote includes all 11 accounting-compatible fee lines',async()=>{
 const s=await source();
 for(const field of [
   'departureAirportMovementUsd','arrivalLandingUsd',
   'departureGroundHandlingUsd','arrivalStandParkingUsd',
   'departureTerminalAirTrafficControlUsd','enrouteAirTrafficControlUsd',
   'departingPassengerFacilityUsd','departingPassengerSecurityUsd',
   'internationalPassengerProcessingUsd','originCargoHandlingUsd',
   'destinationCargoHandlingUsd']) assert.match(s,new RegExp("'"+field+"'"));
 assert.match(s,/section8_airport_operating_tariffs_v1/);
 assert.match(s,/actualAirTrafficControlInvoiceVerified',false/);
 assert.match(s,/NEUTRAL_GAME_PROXY_35_PERCENT_OF_BOTH_TERMINAL_FEES/);
 assert.match(s,/sum_cost:=depart_movement\+arrival_landing\+depart_handling\+arrival_parking/);
 assert.match(s,/readyForActualExpensePosting',false/);
});
test('airport stand, turnaround, passenger and international tariffs are distinct',async()=>{
 const s=await source();
 assert.match(s,/p_departure_stand_type NOT IN\('terminal','remote','cargo'\)/);
 assert.match(s,/p_arrival_stand_type NOT IN\('terminal','remote','cargo'\)/);
 assert.match(s,/origin_row\.terminal_stand_multiplier/);
 assert.match(s,/dest_row\.remote_parking_reference_per_day_usd/);
 assert.match(s,/p_turnaround_minutes\/1440\.0\*dest_factor/);
 assert.match(s,/international_passenger:=round\(p_departing_passengers/);
 assert.match(s,/origin_row\.security_per_departing_passenger_usd/);
 assert.match(s,/p_cargo_tonnes\*dest_row\.cargo_handling_per_tonne_usd/);
});
test('postarrival cost estimate consumes new itemizations but still never posts to ledger',async()=>{
 const s=await source();
 assert.match(s,/fuel:=airlinerra_game.section9_game_reserve_aware_fuel_quote_v1/);
 assert.match(s,/airport_quote:=airlinerra_game.section9_game_itemized_airport_fee_quote_v1/);
 assert.match(s,/estimated_fuel_usd:=round\(\(fuel->>'tripBurnKg'\)::numeric\*fuel_price,2\)/);
 assert.match(s,/minimumPlannedFuelOnBoardKg/);
 assert.match(s,/airportFeeLinesUsd',airport_quote->'feeLinesUsd'/);
 assert.match(s,/fuelReserveIncluded',true/);
 assert.match(s,/reserveFuelChargedAsBurn',false/);
 assert.match(s,/feeLinesAreItemized',true/);
 assert.match(s,/readyForActualExpensePosting',false/);
 assert.match(s,/accountingApproved',false/);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.airline_ledger\b/i);
});
test('unposted finance preparation rejects nonitemized totals or missing reserve',async()=>{
 const s=await source();
 assert.match(s,/section9_prepare_actual_ticket_postarrival_finance_v1/);
 assert.match(s,/quote->>'fuelPlanningReserveIncluded' IS DISTINCT FROM 'true'/);
 assert.match(s,/quote->>'withinGameTankIncludingReserve' IS DISTINCT FROM 'true'/);
 assert.match(s,/quote->>'feeLinesAreItemized' IS DISTINCT FROM 'true'/);
 assert.match(s,/jsonb_each_text\(quote->'airportFeeLinesUsd'\)/);
 assert.match(s,/quote->>'reserveFuelChargedAsBurn' IS DISTINCT FROM 'false'/);
 assert.match(s,/UNPOSTED_GAME_ESTIMATE/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});
