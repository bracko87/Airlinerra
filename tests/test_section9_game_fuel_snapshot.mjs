import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('game fuel snapshot is source-labelled, versioned and keeps unknown tank values missing',async()=>{
 const sql=await read('supabase/migrations/20261112191500_section9_game_fuel_model_snapshot_v1.sql');
 assert.match(sql,/CREATE TABLE airlinerra_game\.section9_game_fuel_model_snapshot_v1/);
 assert.match(sql,/model_version text NOT NULL/);
 assert.match(sql,/EXISTING_PROVISIONAL_DISTANCE_RATE/);
 assert.match(sql,/DERIVED_PEER_AIRCRAFT_GAME_ESTIMATE/);
 assert.match(sql,/fuel_game_family text NOT NULL DEFAULT 'TURBINE_KEROSENE_ASSUMED'/);
 assert.match(sql,/tank_capacity_kg numeric\(13,2\) CHECK\(tank_capacity_kg>0\)/);
 assert.match(sql,/tank_capacity_kg IS NOT NULL/);
 assert.match(sql,/p\.fuel_tank_capacity_kg/);
 assert.match(sql,/p\.reference_peer_configuration_id/);
 assert.doesNotMatch(sql,/coalesce\(p\.fuel_tank_capacity_kg,\s*\d/);
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.aircraft_fuel_planning_profiles_v1/i);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL ON TABLE/);
});
test('game calculations are not aircraft dispatch or refuelling or financial settlement releases',async()=>{
 const sql=await read('supabase/migrations/20261112191500_section9_game_fuel_model_snapshot_v1.sql');
 assert.match(sql,/operational_dispatch_release text NOT NULL DEFAULT 'NOT_RELEASED'/);
 assert.match(sql,/financial_settlement_release text NOT NULL DEFAULT 'NOT_RELEASED'/);
 assert.doesNotMatch(sql,/operational_dispatch_release\s*=\s*'RELEASED'/);
 assert.doesNotMatch(sql,/financial_settlement_release\s*=\s*'RELEASED'/);
 const server=await read('server/flight-schedule-service.mjs');
 assert.match(server,/section9_game_fuel_model_snapshot_v1/);
 assert.match(server,/gameFuelEstimateReady/);
 assert.match(server,/AIRCRAFT_FUEL_GAME_INPUTS_INCOMPLETE/);
 assert.match(server,/fuelDispatchModelApproved/);
 assert.match(server,/fuelAccountingModelApproved/);
 assert.match(server,/maintenanceUsageTrackingStarted/);
 assert.match(server,/maintenanceBaselineVerified/);
 assert.match(server,/routeCreated:false/);
});
test('original starter usage zero is SINCE assignment only, not a physical maintenance or age estimate',async()=>{
 const sql=await read('supabase/migrations/20261112190000_section9_verified_starter_usage_tracking_baseline_v1.sql');
 assert.match(sql,/verified_tracking_started_utc=source_row\.assigned_at/);
 assert.match(sql,/tracking_source='verified_original_starter_allocation_since_assignment'/);
 assert.match(sql,/tracked_flight_hours=0/);
 assert.match(sql,/tracked_flight_cycles=0/);
 assert.match(sql,/aircraftConditionVerified',false/);
 assert.match(sql,/manufactureYearVerified',false/);
 assert.match(sql,/ledgerPosted',false/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
});
