import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('both origin and destination use one catalogue for owner route planning',()=>{
 const list=SCHEDULE_SQL.planList;
 const save=SCHEDULE_SQL.planSave;
 assert.equal((list.match(/JOIN airlinerra_game\.airport_unified_operations_v1/g)||[]).length,2);
 assert.equal((save.match(/JOIN airlinerra_game\.airport_unified_operations_v1/g)||[]).length,2);
 assert.match(list,/o\.game_municipality/);
 assert.match(list,/d\.game_municipality/);
 assert.match(list,/o\.timezone_iana/);
 assert.match(list,/d\.timezone_iana/);
 assert.doesNotMatch(save,/JOIN airlinerra_game\.approved_game_airports/);
 assert.match(save,/a\.owner_player_id=\$1::uuid/);
 assert.match(save,/w\.state='active'/);
 assert.match(save,/i\.fleet_status='in_service'/);
});
test('planning foreign keys use unified membership, not flight-authorized registry',async()=>{
 const source=await read('../supabase/migrations/20261117161500_unified_airport_route_planning_foreign_keys.sql');
 assert.match(source,/references airlinerra_game\.airport_sections1_8_combined_members_v1\(world_id,airport_key\)/);
 assert.doesNotMatch(source,/references airlinerra_game\.approved_game_airports/);
 assert.match(source,/planning ONLY/i);
});
test('unified read model cannot silently authorize unverified Group 2 airports',async()=>{
 const source=await read('../supabase/migrations/20261117162800_unified_airport_game_municipality.sql');
 assert.match(source,/airport_group2_admission_readiness_v1/);
 assert.match(source,/coalesce\(r\.can_activate_flights,false\)/);
 assert.match(source,/documented_commercial_prohibition/);
 assert.match(source,/game_municipality/);
 const operational=await read('../supabase/migrations/20261110201000_group2_schedule_save_fail_closed_owner_preflight.sql');
 assert.match(operational,/SECTION6_GROUP2_NOT_YET_ADMITTED/);
 assert.match(operational,/section6_save_owned_aircraft_schedule_with_slots_v1/);
});
