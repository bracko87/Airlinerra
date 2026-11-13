import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const baseline='supabase/migrations/20261113144500_section9_starter_game_airframe_baseline_v1.sql';
const due='supabase/migrations/20261113150000_section9_game_maintenance_due_preview_v1.sql';

test('starter game age and condition are explicit game-only assumptions, never real airframe records',async()=>{
 const sql=await read(baseline);
 assert.match(sql,/starter_game_airframe_v1',8,92/);
 assert.match(sql,/game_design_assumption_not_physical_evidence/);
 assert.match(sql,/assumed_current_at_game_allocation_not_completed/);
 assert.match(sql,/initial_game_age_years/);
 assert.match(sql,/initial_game_condition_pct/);
 assert.match(sql,/section9_starter_commissioning_game_checks_v1/);
 assert.match(sql,/IF checks<>6 THEN/);
 assert.match(sql,/FOR UPDATE OF r/);
 assert.match(sql,/ON CONFLICT\(aircraft_inventory_id\) DO NOTHING/);
 assert.match(sql,/SECURITY INVOKER/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/'physicalConditionVerified',false/);
 assert.match(sql,/'realManufactureYearVerified',false/);
 assert.match(sql,/'dispatchApproved',false/);
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.aircraft_maintenance_state_v1/i);
 assert.doesNotMatch(sql,/INSERT INTO\s+airlinerra_game\.section9_aircraft_condition_assessments_v1/i);
 assert.doesNotMatch(sql,/INSERT INTO\s+airlinerra_game\.aircraft_maintenance_completions_v1/i);
});

test('due gate uses owner and authoritative date, game hour counters and conservative day precision',async()=>{
 const sql=await read(due);
 assert.match(sql,/a\.owner_player_id=p_player/);
 assert.match(sql,/w\.state='active'/);
 assert.match(sql,/clock\.clock_source IS DISTINCT FROM 'authoritative_game_engine'/);
 assert.match(sql,/p_game_day>clock\.confirmed_game_date\+42/);
 assert.match(sql,/ceil\(policy\.calendar_interval_hours::numeric\/24\)::integer/);
 assert.match(sql,/make_interval\(months=>policy\.calendar_interval_months\)/);
 assert.match(sql,/state\.tracked_flight_hours>=due_hours/);
 assert.match(sql,/p_game_day>=due_day/);
 assert.match(sql,/IF total<>6 THEN/);
 assert.match(sql,/gameMaintenanceGrounded/);
 assert.match(sql,/gameDatePrecisionOnly',true/);
 assert.match(sql,/hourlyGroundingEnforced',false/);
 assert.match(sql,/maintenanceCompletionSchedulingConnected',false/);
 assert.match(sql,/SECURITY INVOKER/);
});
test('protected schedule endpoint refuses to activate during due game maintenance',async()=>{
 const source=await read('server/flight-schedule-service.mjs');
 const ui=await read('website/airline-workspace.mjs');
 assert.match(source,/commissioningGameAirframe:`SELECT airlinerra_game\.section9_owned_starter_game_airframe_initialize_v1/);
 assert.match(source,/maintenanceGameDue:`SELECT airlinerra_game\.section9_owned_game_maintenance_due_v1/);
 assert.match(source,/action==='request'\?'initialize':'status'/);
 assert.match(source,/gameMaintenance\.maintenanceReady!==false/);
 assert.match(source,/gameMaintenance\.dispatchApproved!==false/);
 assert.match(source,/gameMaintenance\.gameDatePrecisionOnly!==true/);
 assert.match(source,/GAME_AIRCRAFT_MAINTENANCE_CHECK_DUE/);
 assert.match(source,/MAINTENANCE_HOURLY_GROUNDING_NOT_CONNECTED/);
 assert.match(source,/MAINTENANCE_SERVICE_JOB_AND_RELEASE_NOT_CONNECTED/);
 assert.match(source,/routeCreated:false/);
 assert.match(ui,/GAME values \(not actual inspection\)/);
 assert.match(ui,/gameMaintenanceGrounded/);
 assert.match(ui,/Upcoming checks:/);
});

test('corrected game maintenance provenance is anchored to commissioning, not original allocation',async()=>{
 const sql=await read('supabase/migrations/20261113151500_section9_starter_game_commissioning_date_provenance_fix.sql');
 assert.match(sql,/assumed_current_at_game_commissioning_not_completed/);
 assert.match(sql,/game_assumed_current_at_commissioning_NOT_actual_completion/);
 assert.match(sql,/CREATE OR REPLACE FUNCTION airlinerra_game\.section9_owned_game_maintenance_due_v1/);
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.aircraft_maintenance_state_v1/i);
 assert.doesNotMatch(sql,/INSERT INTO\s+airlinerra_game\.aircraft_maintenance_completions_v1/i);
});
