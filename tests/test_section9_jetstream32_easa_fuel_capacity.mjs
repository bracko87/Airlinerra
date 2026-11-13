import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const migration=()=>readFile(new URL(
 '../supabase/migrations/20261113095000_section9_jetstream32_easa_usable_tank_capacity_v1.sql',
 import.meta.url),'utf8');

test('Jetstream 32 gets EASA certified TYPE-level usable fuel capacity, not total or a guess',async()=>{
 const sql=await migration();
 assert.match(sql,/configuration_id=98/);
 assert.match(sql,/selected.*technical/i.test(sql)?/section9_fuel_tank_capacity_evidence_v1/:/airlinerra\.aircraft_technical_specs/);
 assert.match(sql,/EASA\.A\.191/);
 assert.match(sql,/DATE '2015-01-15'/);
 assert.match(sql,/Section 3: Jetstream Series 3200, III\.9\.1 Fuel Capacity/);
 assert.match(sql,/USABLE_FUEL',1477,1846/);
 assert.match(sql,/manufacturer_usable_fuel_mass_kg=1477/);
 assert.match(sql,/tank_capacity_kg=1477/);
 assert.match(sql,/total 1491 kg/i);
 assert.match(sql,/easa\.europa\.eu\/sites\/default\/files\/dfu\//);
});
test('never write to the derived view or change unrelated Jetstream models',async()=>{
 const sql=await migration();
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.aircraft_fuel_planning_profiles_v1/i);
 assert.match(sql,/UPDATE\s+airlinerra\.aircraft_technical_specs\s+SET/);
 assert.match(sql,/WHERE id=136 AND configuration_id=98/);
 assert.match(sql,/UPDATE\s+airlinerra_game\.section9_game_fuel_model_snapshot_v1\s+SET/);
 assert.match(sql,/AND tank_capacity_kg IS NULL/);
 assert.match(sql,/SECTION9_JETSTREAM32_SOURCE_BASELINE_CHANGED/);
});
test('published usable fuel capacity does not approve guessed burn rates, dispatch or financial charges',async()=>{
 const sql=await migration();
 assert.match(sql,/approved_for_dispatch=false AND approved_for_accounting=false/);
 assert.match(sql,/requires_further_evidence=true/);
 assert.match(sql,/operational_dispatch_release='NOT_RELEASED'/);
 assert.match(sql,/financial_settlement_release='NOT_RELEASED'/);
 assert.match(sql,/REVOKE ALL ON TABLE airlinerra_game\.section9_fuel_tank_capacity_evidence_v1/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/game_calculation_ready=true\)<>271/);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\.section9_trusted_execution_release_policy_v1/i);
});
