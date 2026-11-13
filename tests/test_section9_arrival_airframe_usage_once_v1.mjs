import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const migration=()=>readFile(new URL(
 '../supabase/migrations/20261113233000_section9_once_only_arrival_airframe_hours_cycles_v1.sql',
 import.meta.url),'utf8');

test('one physical arrival has a single durable usage receipt',async()=>{
 const sql=await migration();
 assert.match(sql,/section9_arrived_aircraft_usage_receipts_v1/);
 assert.match(sql,/physical_flight_id text PRIMARY KEY/);
 assert.match(sql,/arrived_engine_event_id text NOT NULL UNIQUE/);
 assert.match(sql,/REFERENCES airlinerra_game\.section9_operated_flight_movements_v1\(engine_event_id\)/);
 assert.match(sql,/section9_arrived_usage_flight_id_format_v1/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
});
test('usage is allowed only after matching signed departure and arrival',async()=>{
 const sql=await migration();
 assert.match(sql,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(sql,/section9_verified_berlin_game_hour_v1/);
 assert.match(sql,/phase='arrived'/);
 assert.match(sql,/phase='departed'/);
 assert.match(sql,/source_kind<>'signed_operated_game_flight_v1'/);
 assert.match(sql,/arrival\.actual_event_utc<=departure\.actual_event_utc/);
 assert.match(sql,/arrival\.actual_event_utc>departure\.actual_event_utc\+interval '72 hours'/);
 assert.match(sql,/SECTION9_REPLAYED_AIRFRAME_USAGE_INCONSISTENT/);
});
test('arrival updates usage counters once and requires verified initial state',async()=>{
 const sql=await migration();
 assert.match(sql,/aircraft_maintenance_state_v1/);
 assert.match(sql,/verified_tracking_started_utc IS NULL/);
 assert.match(sql,/FOR UPDATE/);
 assert.match(sql,/INSERT INTO airlinerra_game\.section9_arrived_aircraft_usage_receipts_v1/);
 assert.match(sql,/tracked_flight_hours=tracked_flight_hours\+hours_to_add/);
 assert.match(sql,/tracked_flight_cycles=tracked_flight_cycles\+1/);
 assert.match(sql,/SECTION9_AIRFRAME_COUNTER_UPDATE_UNCONFIRMED_ROLLBACK/);
 assert.match(sql,/airframe_usage_already_applied/);
 assert.match(sql,/flightCyclesAddedNow',1/);
});
test('dispatcher commits arrival and usage atomically, never revenue',async()=>{
 const sql=await migration();
 assert.match(sql,/section9_auto_dispatch_due_flight_events_v1/);
 assert.match(sql,/section9_apply_arrival_airframe_usage_once_v1\(/);
 assert.match(sql,/SECTION9_ARRIVAL_AIRFRAME_USAGE_NOT_ATOMIC_ROLLBACK/);
 assert.match(sql,/'ticketRevenueRecognized',false,'ledgerPosted',false/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(sql,/SECURITY DEFINER/i);
});
