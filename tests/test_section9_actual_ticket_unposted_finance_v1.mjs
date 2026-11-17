import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=()=>readFile(new URL(
 '../supabase/migrations/20261117093000_section9_actual_ticket_postarrival_unposted_finance_v1.sql',
 import.meta.url),'utf8');

test('actual-ticket settlement proof stores one immutable flight and signed arrival',async()=>{
 const s=await sql();
 assert.match(s,/section9_actual_ticket_finance_preparations_v1/);
 assert.match(s,/physical_flight_id text PRIMARY KEY/);
 assert.match(s,/arrival_event_id text NOT NULL UNIQUE REFERENCES/);
 assert.match(s,/aircraft_usage_receipt_flight_id text NOT NULL UNIQUE REFERENCES/);
 assert.match(s,/section9_arrived_aircraft_usage_receipts_v1/);
 assert.match(s,/SECTION9_REPLAYED_ACTUAL_FINANCE_PREPARATION_PROOF_CHANGED/);
});

test('actual ticket settlement does not rely on the legacy three-day demand forecast',async()=>{
 const s=await sql();
 assert.match(s,/section9_postarrival_ticket_reconciliation_v1/);
 assert.match(s,/section9_completed_flight_game_cost_preview_v1/);
 assert.match(s,/quote->>'bookedPassengers'/);
 assert.match(s,/review->>'ticketPassengers'/);
 assert.match(s,/quote->>'quotedTicketFareUsd'/);
 assert.match(s,/review->>'ticketIncomeUsd'/);
 assert.match(s,/::numeric\s+IS DISTINCT FROM \(review->>'ticketIncomeUsd'\)::numeric/);
 assert.doesNotMatch(s,/\bFROM airlinerra_game\.section9_demand_jobs_v1/i);
 assert.doesNotMatch(s,/\bJOIN airlinerra_game\.section9_completed_flight_contributions_v1/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.section9_prepared_occurrence_settlements_v1/i);
});

test('only a verified closed, flown flight with matching once-only usage is prepared',async()=>{
 const s=await sql();
 assert.match(s,/occurrence\.booking_status<>'closed'/);
 assert.match(s,/occurrence\.source_kind<>'game_verified_saleable_schedule_v1'/);
 assert.match(s,/occurrence\.schedule_version IS DISTINCT FROM occurrence\.current_schedule_version/);
 assert.match(s,/occurrence\.cargo_held_tonnes IS DISTINCT FROM 0/);
 assert.match(s,/receipt\.arrived_engine_event_id<>arrival\.engine_event_id/);
 assert.match(s,/section9_verified_berlin_game_hour_v1/);
 assert.match(s,/SECTION9_POSTARRIVAL_TICKET_COST_PROOFS_DISAGREE/);
});

test('cost preparation is never equivalent to posting revenue or approving fuel',async()=>{
 const s=await sql();
 assert.match(s,/UNPOSTED_GAME_ESTIMATE/);
 assert.match(s,/readyToPost',false,'ledgerPosted',false/);
 assert.match(s,/quote->>'accountingApproved' IS DISTINCT FROM 'false'/);
 assert.match(s,/quote->>'readyForActualExpensePosting' IS DISTINCT FROM 'false'/);
 assert.match(s,/provisional_operating_cost_usd=provisional_fuel_cost_usd\+provisional_airport_cost_usd/);
 assert.match(s,/ON CONFLICT\(physical_flight_id\) DO NOTHING/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/\bUPDATE airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.section9_route_posted_flight_financials_v1/i);
});

test('table and function are private to trusted game worker',async()=>{
 const s=await sql();
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/pg_try_advisory_xact_lock/);
 assert.match(s,/ENABLE ROW LEVEL SECURITY/);
 assert.match(s,/REVOKE ALL ON TABLE airlinerra_game\.section9_actual_ticket_finance_preparations_v1/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_prepare_actual_ticket_postarrival_finance_v1/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
});
