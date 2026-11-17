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

test('future Group 2 releases require explicit validated approval and use dynamic schedule gate',async()=>{
 const release=await read('../supabase/migrations/20261117164500_group2_operational_release_control.sql');
 const catalogue=await read('../supabase/migrations/20261117165000_unified_airport_dynamic_group2_release.sql');
 const guard=await read('../supabase/migrations/20261117165500_unified_airport_admission_schedule_guard.sql');
 assert.match(release,/ready_for_owner_release_review=true/);
 assert.match(release,/documented_commercial_prohibition=false/);
 assert.match(release,/section6_airport_slot_capacity_v1/);
 assert.match(release,/section5_airport_operating_policy_v1/);
 assert.match(release,/enable row level security/i);
 assert.match(catalogue,/rel\.release_status='approved'/);
 assert.match(guard,/dispatch_eligible_by_airport_admission IS DISTINCT FROM true/);
 assert.match(guard,/SECTION6_AIRPORT_NOT_YET_ADMITTED/);
 assert.doesNotMatch(guard,/WHERE g\.airport_key IN\(p_origin_key,p_destination_key\)/);
});

test('all Group 2 airport game inputs now have a shared slot and policy bridge',async()=>{
 const slot=await read('../supabase/migrations/20261117170500_group2_slot_engine_capacity_unified_inputs.sql');
 const policy=await read('../supabase/migrations/20261117171500_group2_section5_policy_game_model_bridge.sql');
 assert.match(slot,/section6_airport_slot_capacity_v1/);
 assert.match(slot,/airport_sections1_8_combined_members_v1/);
 assert.match(slot,/group2_estimated_stand_capacity_v1/);
 assert.match(slot,/1118/);
 assert.match(policy,/section5_airport_operating_policy_v1/);
 assert.match(policy,/GROUP2_GAME_MODEL_ESTIMATE_NOT_REAL_WORLD_VERIFIED/);
 assert.match(policy,/false,'GROUP2_GAME_MODEL_ESTIMATE_NOT_REAL_WORLD_VERIFIED'/);
 assert.match(policy,/UNEXPECTED_COMMERCIAL_RELEASE/);
});
