import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const get=async file=>readFile(new URL(file,import.meta.url),'utf8');

test('Group 2 airport expansion models the same eight sections as Group 1',async()=>{
 const sql=await get('../supabase/migrations/20261110102000_group2_owner_preapproved_1118_game_models.sql');
 const suffixes=['identity','classification','runways','facilities',
  'restrictions','capacity','demand','economics'];
 for(let i=1;i<=8;i++){
  assert.ok(sql.includes('CREATE VIEW airlinerra_game.airport_group2_section'+
   i+'_'+suffixes[i-1]+'_v1'), 'Missing Group2 section '+i);
 }
 assert.match(sql,/airlinerra\.airport_candidate_preapproval_pool/);
 assert.match(sql,/airlinerra\.airport_registry/);
 assert.match(sql,/COUNT\(\*\) FROM airlinerra_game\.airport_group2_game_profiles_v1/i);
 assert.match(sql,/1828/);
 assert.match(sql,/1118/);
 assert.match(sql,/GAME_MODEL_PREPARED_ESTIMATED/);
});

test('Group 2 respects real-world evidence gaps, original owner tiers and release protection',async()=>{
 const sql=await get('../supabase/migrations/20261110102000_group2_owner_preapproved_1118_game_models.sql');
 const inventory=await get('../supabase/migrations/20261110103500_airport_group1_group2_inventory.sql');
 assert.match(sql,/owner_category/);
 assert.match(sql,/game_traffic_type/);
 assert.match(sql,/runway_width_game_basis/);
 assert.match(sql,/NEAREST_SAME_COUNTRY_GAME_ESTIMATE/);
 assert.match(sql,/UA_COUNTRY_GAME_ESTIMATE/);
 assert.match(sql,/UNSOURCED_NO_OPERATIONAL_CLEARANCE/);
 assert.match(sql,/game_nighttime_ban boolean,/);
 assert.match(sql,/game_noise_restrictions boolean,/);
 assert.match(sql,/commercial_playable boolean NOT NULL DEFAULT false CHECK\(commercial_playable=false\)/);
 assert.match(sql,/commercial_access_verified boolean NOT NULL DEFAULT false/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL ON airlinerra_game\.airport_group2_game_profiles_v1/);
 assert.match(inventory,/GROUP_1/);
 assert.match(inventory,/GROUP_2/);
 assert.match(inventory,/4259/);
 assert.match(inventory,/approved_game_roster_member/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.approved_game_airports/);
 assert.doesNotMatch(sql,/UPDATE airlinerra\.airport_candidate_preapproval_pool/);
 assert.doesNotMatch(sql,/UPDATE public\.airlinerra_game_worlds/);
 assert.doesNotMatch(inventory,/UPDATE\s+airlinerra_game\.airline_ledger/);
});

test('Group 2 documented validation verifies original 3,141 and new 1,118 separately',async()=>{
 const sql=await get('../tests/sql/group2_1118_airport_game_data_acceptance.sql');
 const doc=await get('../docs/GROUP2_1118_PREAPPROVED_GAME_DATA_2026-11-10.md');
 assert.match(sql,/GROUP2_SOURCE_UNKNOWN_MISREPRESENTED_AS_REAL_CLEARANCE/);
 assert.match(sql,/GROUP2_SOURCE_SET_OR_GROUP1_ROSTER_CHANGED|GROUP1_PRESERVATION_OR_OPERATIONAL_GATE_VIOLATION/);
 assert.match(sql,/1118/);
 assert.match(sql,/3141/);
 assert.match(sql,/1828/);
 assert.match(doc,/commercial/i);
 assert.match(doc,/Group 2/i);
 assert.match(doc,/Group 1/i);
});
