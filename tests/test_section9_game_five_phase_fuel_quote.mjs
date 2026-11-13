import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const migrationPath='../supabase/migrations/20261113083000_section9_game_five_phase_fuel_preview_only_v1.sql';
const load=()=>readFile(new URL(migrationPath,import.meta.url),'utf8');

test('five-phase fuel estimate stays private and read-only',async()=>{
 const sql=await load();
 assert.match(sql,/section9_game_five_phase_fuel_quote_v1/);
 assert.match(sql,/LANGUAGE plpgsql\s+STABLE SECURITY INVOKER/i);
 assert.match(sql,/REVOKE ALL ON FUNCTION[^;]+FROM PUBLIC,anon,authenticated,service_role/i);
 assert.doesNotMatch(sql,/\b(?:INSERT INTO|UPDATE|DELETE FROM)\s+airlinerra_game\./i);
 assert.match(sql,/'previewOnly',true/);
 assert.match(sql,/'flightCreated',false/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.match(sql,/'fuelChargeUsd',NULL/);
 assert.match(sql,/'dispatchApproved',false/);
 assert.match(sql,/'accountingApproved',false/);
});
test('uses only versioned stored source fuel inputs, with no invented tank',async()=>{
 const sql=await load();
 assert.match(sql,/section9_game_fuel_model_snapshot_v1/);
 assert.match(sql,/AIRLINERRA_FIVE_PHASE_FUEL_GAME_V1_2026_11_12/);
 assert.match(sql,/m\.game_calculation_ready IS DISTINCT FROM true/);
 assert.match(sql,/m\.tank_capacity_kg IS NULL/);
 assert.match(sql,/'status','model_incomplete'/);
 assert.match(sql,/'totalKg',NULL/);
 assert.match(sql,/'reserveFuelIncluded',false/);
 assert.match(sql,/'withinModelTankWithoutReserve'/);
});
test('explicitly separates all five phases with unverified game coefficients',async()=>{
 const sql=await load();
 for (const key of ['taxiOut','climb','cruise','descent','taxiIn'])
   assert.match(sql,new RegExp("'"+key+"'"));
 assert.match(sql,/GAME_ASSUMPTION_V1_UNVERIFIED_NOT_AIRCRAFT_SPECIFIC/);
 assert.match(sql,/p_load_percent\s*<=\s*50/);
 assert.match(sql,/p_load_percent-50/);
 for(const coefficient of ['0.18','1.35','0.40'])
   assert.ok(sql.includes(coefficient),coefficient);
 assert.match(sql,/SECTION9_INVALID_FUEL_QUOTE_INPUT/);
 assert.match(sql,/SECTION9_FUEL_QUOTE_DURATION_EXCEEDS_GAME_LIMIT/);
});
