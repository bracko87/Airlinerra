import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const source=()=>readFile(new URL(
 '../supabase/migrations/20261113224000_section9_trusted_demand_hold_to_ticket_bridge_v1.sql',
 import.meta.url),'utf8');

test('conversion needs a completed private demand plan with exact hold provenance',async()=>{
 const sql=await source();
 assert.match(sql,/section9_capacity_hold_plan_items_v1/);
 assert.match(sql,/section9_capacity_hold_plans_v1/);
 assert.match(sql,/plan\.status='completed'/);
 assert.match(sql,/plan\.next_allocation_seq=plan\.allocation_count/);
 assert.match(sql,/i\.physical_flight_ids=h\.physical_flight_ids/);
 assert.match(sql,/i\.passengers=h\.passengers/);
 assert.match(sql,/h\.cargo_tonnes IS DISTINCT FROM 0/);
 assert.match(sql,/SECTION9_DEMAND_HOLD_LEG_PROOF_MISMATCH/);
 assert.match(sql,/cardinality\(h\.physical_flight_ids\) NOT BETWEEN 1 AND 2/);
});
test('two-leg conversions are atomic, idempotent and cannot double-count held seats',async()=>{
 const sql=await source();
 assert.match(sql,/reservation_key:='demand\.'\|\|p_allocation_key/);
 assert.match(sql,/SECTION9_PARTIALLY_ISSUED_CONNECTING_JOURNEY/);
 assert.match(sql,/SECTION9_DEMAND_TICKET_REPLAY_CHANGED/);
 assert.match(sql,/SECTION9_DEMAND_SEAT_ISSUANCE_CONCURRENT_CONFLICT/);
 assert.match(sql,/SET booked_seats=booked_seats\+h\.passengers/);
 assert.doesNotMatch(sql,/SET passengers_held=passengers_held\+h\.passengers/);
 assert.match(sql,/inv\.passengers_held<flight\.booked_seats\+h\.passengers/);
 assert.match(sql,/FOR UPDATE OF o/);
 assert.match(sql,/FOR UPDATE/);
 assert.match(sql,/RETURNING id INTO issued_id/);
 assert.match(sql,/written<>nlegs/);
});
test('direct bookings and demand bookings share lock order and separate keys',async()=>{
 const sql=await source();
 assert.match(sql,/p_reservation_key LIKE 'demand\.s9g1:%'/);
 assert.match(sql,/FOR UPDATE OF cap[\s\S]*FOR UPDATE OF o/);
 assert.match(sql,/capacity\.passengers_held<row_value\.booked_seats/);
 assert.match(sql,/passenger_capacity>=passengers_held\+p_seats/);
 assert.match(sql,/SECTION9_PASSENGER_CAPACITY_CHANGED_CONCURRENTLY/);
});
test('no signed operating release or game-hour means no issued tickets',async()=>{
 const sql=await source();
 assert.match(sql,/section9_verified_berlin_game_hour_v1/);
 assert.match(sql,/section9_verified_saleable_departure_window_v1/);
 assert.match(sql,/section9_trusted_execution_release_policy_v1/);
 assert.match(sql,/automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true/);
 assert.match(sql,/fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'/);
 assert.match(sql,/blocked_operating_game_releases/);
 assert.match(sql,/blocked_unreleased_flight_engine/);
 assert.match(sql,/section9_operated_flight_movements_v1/);
 assert.match(sql,/current_user IS DISTINCT FROM 'postgres'/);
});
test('bookings keep recognition and ledger strictly separate from sale',async()=>{
 const sql=await source();
 assert.match(sql,/reservation_status,paid_upfront,recognized_revenue_usd/);
 assert.match(sql,/'reserved',false,0/);
 assert.match(sql,/revenueRecognized',false/);
 assert.match(sql,/chargedNow',false/);
 assert.match(sql,/ledgerPosted',false/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(sql,/UPDATE airlinerra_game\.airlines/i);
 assert.doesNotMatch(sql,/SECURITY DEFINER/i);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
});
test('automatic converter is bounded and never creates demand forecasts itself',async()=>{
 const sql=await source();
 assert.match(sql,/section9_promote_completed_demand_holds_batch_v1/);
 assert.match(sql,/p_limit NOT BETWEEN 1 AND 100/);
 assert.match(sql,/pg_try_advisory_xact_lock\(583729,10029\)/);
 assert.match(sql,/NOT EXISTS\([\s\S]*section9_dated_flight_occurrences_v1/);
 assert.match(sql,/status','verified_demand_ticket_conversion_batch_completed/);
 assert.match(sql,/WHERE jobname='airlinerra-game-demand-tickets-v1'/);
 assert.match(sql,/'\*\/5 \* \* \* \*'/);
 assert.match(sql,/SELECT airlinerra_game\.section9_promote_completed_demand_holds_batch_v1\(50\)/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.section9_demand_jobs_v1/i);
});
