import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const sql=()=>readFile(new URL(
 '../supabase/migrations/20261113225000_section9_postarrival_ticket_revenue_reconciliation_v1.sql',
 import.meta.url),'utf8');

test('money recognition requires both recorded departure and arrival',async()=>{
 const s=await sql();
 assert.match(s,/section9_postarrival_ticket_reconciliation_v1/);
 assert.match(s,/phase='departed'/);
 assert.match(s,/phase='arrived'/);
 assert.match(s,/blocked_missing_departure/);
 assert.match(s,/blocked_missing_arrival/);
 assert.match(s,/arrival\.actual_event_utc<=departure\.actual_event_utc/);
 assert.match(s,/blocked_arrival_not_reached/);
 assert.match(s,/section9_verified_berlin_game_hour_v1/);
 assert.match(s,/arrival\.schedule_version IS DISTINCT FROM rec\.schedule_version/);
});
test('actual saved reservations determine revenue rather than the demand forecast',async()=>{
 const s=await sql();
 assert.match(s,/section9_passenger_reservation_batches_v1/);
 assert.match(s,/b\.reservation_status='reserved'/);
 assert.match(s,/b\.seats_requested\*b\.quoted_fare_usd/);
 assert.match(s,/ticket\.actual_passengers IS DISTINCT FROM rec\.booked_seats/);
 assert.match(s,/b\.paid_upfront=false AND b\.recognized_revenue_usd=0/);
 assert.match(s,/ticket\.actual_revenue/);
 assert.match(s,/movementSignatureVerifiedIndependently',false/);
 assert.match(s,/readyToPostCompleteFlightFinance',false/);
});
test('forecast can only produce unposted intents after matching arrived tickets',async()=>{
 const s=await sql();
 assert.match(s,/section9_prepare_verified_settlement_batch_v1/);
 assert.match(s,/section9_postarrival_ticket_reconciliation_v1/);
 assert.match(s,/ticket_proof->>'status' IS DISTINCT FROM 'postarrival_ticket_totals_reconciled'/);
 assert.match(s,/ticket_proof->>'ticketPassengers'\)::integer IS DISTINCT FROM rec\.passengers/);
 assert.match(s,/ticket_proof->>'ticketIncomeUsd'\)::numeric IS DISTINCT FROM rec\.ticket_revenue_usd/);
 assert.match(s,/SECTION9_DEMAND_FORECAST_NOT_RECONCILED_WITH_ARRIVED_TICKET_BOOKINGS/);
 assert.match(s,/rec\.cargo_tonnes>0 OR rec\.cargo_revenue_usd>0/);
 assert.match(s,/section9_unposted_revenue_intents_v1/);
});
test('never allows duplicated ledger posting or untrusted direct access',async()=>{
 const s=await sql();
 assert.match(s,/section9_route_posted_flight_financials_v1/);
 assert.match(s,/already_posted_do_not_rebook/);
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/);
 assert.doesNotMatch(s,/INSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/UPDATE airlinerra_game\.airlines/i);
});
