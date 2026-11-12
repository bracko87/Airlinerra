import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('starter maintenance tracking starts at signed allocation date, not invented historical hours',async()=>{
 const sql=await read('supabase/migrations/20261112190000_section9_verified_starter_usage_tracking_baseline_v1.sql');
 assert.match(sql,/section9_starter_origin_evidence_v1/);
 assert.match(sql,/s\.source_fixture_id IS NOT NULL/);
 assert.match(sql,/s\.registration=f\.registration/);
 assert.match(sql,/s\.configuration_id=f\.configuration_id/);
 assert.match(sql,/s\.assigned_at<=clock_timestamp\(\)/);
 assert.match(sql,/clock_row\.confirmed_game_date IS DISTINCT FROM p_game_date/);
 assert.match(sql,/tracked_flight_hours=0/);
 assert.match(sql,/tracked_flight_cycles=0/);
 assert.match(sql,/verified_tracking_started_utc=source_row\.assigned_at/);
 assert.match(sql,/tracking_source='verified_original_starter_allocation_since_assignment'/);
 assert.match(sql,/lifetimeHoursVerified',false/);
 assert.match(sql,/manufactureYearVerified',false/);
 assert.match(sql,/aircraftConditionVerified',false/);
 assert.doesNotMatch(sql,/SET[\s\S]*?condition_pct\s*=/);
 assert.doesNotMatch(sql,/SET[\s\S]*?manufacture_year\s*=/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.aircraft_maintenance_completions/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.section9_operated_flight_movements/);
});
test('initializer cannot reset after any operation, verified tracking or competing current-position record',async()=>{
 const sql=await read('supabase/migrations/20261112190000_section9_verified_starter_usage_tracking_baseline_v1.sql');
 assert.match(sql,/FOR UPDATE/);
 assert.match(sql,/tracking_row\.verified_tracking_started_utc IS NOT NULL/);
 assert.match(sql,/tracking_row\.tracked_flight_hours IS NOT NULL/);
 assert.match(sql,/tracking_row\.tracked_flight_cycles IS NOT NULL/);
 assert.match(sql,/tracking_row\.tracking_source IS DISTINCT FROM 'not_started'/);
 assert.match(sql,/EXISTS\([\s\S]*?section9_operated_flight_movements_v1/);
 assert.match(sql,/EXISTS\([\s\S]*?section9_aircraft_current_position_v1/);
 assert.match(sql,/WHERE m\.aircraft_inventory_id=p_aircraft AND m\.airline_id=p_airline/);
 assert.match(sql,/GET DIAGNOSTICS updated_count=ROW_COUNT/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/SECURITY INVOKER/);
});
test('new baseline does not by itself satisfy operational maintenance condition or release flight',async()=>{
 const api=await read('server/flight-schedule-service.mjs');
 assert.match(api,/maintenance\.condition_pct IS NOT NULL/);
 assert.match(api,/maintenance\.condition_basis NOT IN \('unverified','unknown'\)/);
 assert.match(api,/maintenance\.tracked_flight_hours IS NOT NULL/);
 assert.match(api,/AIRCRAFT_MAINTENANCE_BASELINE_NOT_VERIFIED/);
 const sql=await read('supabase/migrations/20261112190000_section9_verified_starter_usage_tracking_baseline_v1.sql');
 assert.match(sql,/flightActivated',false/);
 assert.match(sql,/ledgerPosted',false/);
 assert.match(sql,/maintenanceCompleted',false/);
});
