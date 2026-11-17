import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const sql=()=>readFile(new URL(
 '../supabase/migrations/20261117094000_section9_auto_prepare_actual_ticket_finance_v1.sql',
 import.meta.url),'utf8');

test('bounded worker only inspects arrived flights with once-only usage receipts',async()=>{
 const s=await sql();
 assert.match(s,/section9_operated_flight_movements_v1/);
 assert.match(s,/section9_arrived_aircraft_usage_receipts_v1/);
 assert.match(s,/m\.phase='arrived'/);
 assert.match(s,/r\.arrived_engine_event_id=m\.engine_event_id/);
 assert.match(s,/p_limit NOT BETWEEN 1 AND 100/);
 assert.match(s,/LIMIT p_limit/);
});
test('worker skips existing financial posting and prior proofs',async()=>{
 const s=await sql();
 assert.match(s,/section9_actual_ticket_finance_preparations_v1/);
 assert.match(s,/section9_route_posted_flight_financials_v1/);
 assert.match(s,/section9_prepare_actual_ticket_postarrival_finance_v1/);
 assert.match(s,/actual_ticket_estimate_prepared/);
 assert.match(s,/actual_ticket_estimate_replayed/);
 assert.match(s,/pg_try_advisory_xact_lock/);
});
test('postarrival scheduler is private and never posts money',async()=>{
 const s=await sql();
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_prepare_arrived_actual_ticket_finance_batch_v1/);
 assert.match(s,/WHERE jobname='airlinerra-game-postarrival-finance-preflight-v1'/);
 assert.match(s,/cron\.schedule/);
 assert.match(s,/'7,17,27,37,47,57 \* \* \* \*'/);
 assert.match(s,/'ledgerPosted',false/);
 assert.match(s,/'fuelChargePosted',false/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.section9_route_posted_flight_financials_v1/i);
});
