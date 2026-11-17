import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=()=>readFile(new URL(
 '../supabase/migrations/20261117091000_section9_postarrival_provisional_fuel_airport_cost_quote_v1.sql',
 import.meta.url),'utf8');

test('requires a truly arrived and signed flight plus once-only airframe usage receipt',async()=>{
 const s=await sql();
 assert.match(s,/section9_operated_flight_movements_v1/);
 assert.match(s,/phase='departed'/);
 assert.match(s,/phase='arrived'/);
 assert.match(s,/section9_arrived_aircraft_usage_receipts_v1/);
 assert.match(s,/usage\.arrived_engine_event_id IS DISTINCT FROM arr\.engine_event_id/);
 assert.match(s,/usage\.departed_engine_event_id IS DISTINCT FROM dep\.engine_event_id/);
 assert.match(s,/flight\.booking_status<>'closed'/);
 assert.match(s,/flight\.operationally_verified IS DISTINCT FROM true/);
});

test('use only durable paid-status-agnostic reserved ticket counts, never passenger forecast',async()=>{
 const s=await sql();
 assert.match(s,/section9_passenger_reservation_batches_v1/);
 assert.match(s,/reservation_status='reserved'/);
 assert.match(s,/actual_ticket_seats IS DISTINCT FROM flight\.booked_seats/);
 assert.match(s,/actual_ticket_seats>flight\.verified_passenger_seats/);
 assert.match(s,/bookedPassengers',actual_ticket_seats/);
 assert.match(s,/quotedTicketFareUsd',ticket_quote_total/);
});

test('five phase estimated fuel and airport charges remain explicitly unapproved',async()=>{
 const s=await sql();
 assert.match(s,/section9_game_five_phase_fuel_quote_v1/);
 assert.match(s,/section8_airport_operating_tariffs_v1/);
 assert.match(s,/fuel_price_assumption_usd_per_kg/);
 assert.match(s,/GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF/);
 assert.match(s,/GAME_COST_PREVIEW_V1_NEVER_POST/);
 assert.match(s,/reserveFuelIncluded',false/);
 assert.match(s,/crewCostsIncluded',false/);
 assert.match(s,/maintenanceChargesIncluded',false/);
 assert.match(s,/realWorldOperatingCostVerified',false/);
 assert.match(s,/readyForActualExpensePosting',false/);
 assert.match(s,/accountingApproved',false/);
 assert.match(s,/dispatchApproved',false/);
});

test('does not insert ledger/charge and stays private',async()=>{
 const s=await sql();
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_completed_flight_game_cost_preview_v1/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/);
 assert.doesNotMatch(s,/\bINSERT INTO\b/i);
 assert.doesNotMatch(s,/\bUPDATE\s+airlinerra_game\./i);
 assert.doesNotMatch(s,/\bDELETE\s+FROM\s+airlinerra_game\./i);
});
