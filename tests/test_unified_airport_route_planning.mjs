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

test('mixed Group 1 / Group 2 routes fail closed with airport-specific admission diagnostics',async()=>{
 const source=await read('../supabase/migrations/20261117173000_unified_airport_mixed_route_admission_diagnostics.sql');
 assert.match(source,/SECTION6_AIRPORT_NOT_IN_UNIFIED_CATALOGUE/);
 assert.match(source,/SECTION6_AIRPORT_NOT_YET_ADMITTED/);
 assert.match(source,/unresolvedGates/);
 assert.match(source,/dispatch_eligible_by_airport_admission IS DISTINCT FROM true/);
 assert.doesNotMatch(source,/group2_owned_aircraft_route_preflight_v1/);
 assert.match(source,/p_origin_key,p_destination_key/);
});

test('common mixed-group route diagnostics keep game compatibility separate from flight permission',async()=>{
 const sql=await read('../supabase/migrations/20261117175500_unified_airport_game_route_readiness.sql');
 assert.match(sql,/unified_airport_route_game_readiness_v1/);
 assert.match(sql,/airport_unified_operations_v1/);
 assert.match(sql,/gameStandCapacityAvailable/);
 assert.match(sql,/gameTrafficTypeCompatible/);
 assert.match(sql,/GAME_INPUTS_PREPARED_ADMISSION_BLOCKED/);
 assert.match(sql,/'canActivateFlights',false/);
 assert.match(sql,/revoke all on function airlinerra_game\.unified_airport_route_game_readiness_v1/);
});

test('Group 2 simulation eligibility never upgrades real-world evidence into flight permission',async()=>{
 const sql=await read('../supabase/migrations/20261117182000_group2_simulation_only_admission_candidates.sql');
 assert.match(sql,/documented_commercial_prohibition/);
 assert.match(sql,/simulation_candidate_only/);
 assert.match(sql,/operationally_released/);
 assert.match(sql,/GAME_ESTIMATES_ONLY_NOT_REAL_WORLD_VERIFICATION/);
});
test('schedule, reserved slots and operated movements use unified airport membership keys',async()=>{
 const sql=await read('../supabase/migrations/20261117184500_unified_operational_airport_foreign_keys.sql');
 assert.match(sql,/airline_flight_schedule_unified_origin_fk/);
 assert.match(sql,/airline_flight_schedule_unified_destination_fk/);
 assert.match(sql,/section6_weekly_airport_slot_reservations_unified_airport_fk/);
 assert.match(sql,/section9_operated_flight_movements_unified_origin_fk/);
 assert.match(sql,/section9_operated_flight_movements_unified_destination_fk/);
 assert.match(sql,/airport_sections1_8_combined_members_v1/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.approved_game_airports/i);
});

test('Section 5 common leg checks no longer exclude Group 2 from airport lookup',async()=>{
 const s=await read('../supabase/migrations/20261117192500_section5_universal_restrictions_unified_airport_lookup.sql');
 assert.match(s,/JOIN airlinerra_game\.airport_sections1_8_combined_members_v1/);
 assert.doesNotMatch(s,/JOIN airlinerra_game\.approved_game_airports/);
 assert.match(s,/runway_review|runwayReview|runway_review :=/);
});
test('Section 6 timezone and simplified restriction rules consume both airport groups',async()=>{
 const slot=await read('../supabase/migrations/20261117194500_unified_section6_slot_timezone_lookup.sql');
 const restrictions=await read('../supabase/migrations/20261117190000_group2_simplified_section5_game_restrictions.sql');
 assert.match(slot,/FROM airlinerra_game\.section5_airport_operating_policy_v1 p/g);
 assert.doesNotMatch(slot,/FROM airlinerra_game\.airport_reference_profiles p/);
 assert.match(restrictions,/section5_simplified_rules_unified_airport_fk/);
 assert.match(restrictions,/GROUP2_ESTIMATED_SECTION5_SIMULATION_MODEL_V1/);
 assert.match(restrictions,/GAME_DEFAULT_NOT_CHECKED/);
});

test('unified game readiness is computed across actual Section 5/6 input tables, not flight permits',async()=>{
 const sql=await read('../supabase/migrations/20261117200500_unified_airport_game_subsystem_readiness.sql');
 for (const table of ['airport_unified_operations_v1','section6_airport_slot_capacity_v1',
   'section5_airport_operating_policy_v1','section5_airport_simplified_game_rules_v1',
   'airport_group2_simulation_admission_candidates_v1']){
   assert.ok(sql.includes(table),table);
 }
 assert.match(sql,/airport_game_subsystem_ready/);
 assert.match(sql,/flight_admission_released/);
 assert.match(sql,/GAME_MODEL_READY_DOES_NOT_MEAN_FLIGHT_AUTHORIZED/);
 assert.doesNotMatch(sql,/insert into airlinerra_game\.approved_game_airports/i);
});

test('two prohibited military air bases remain source records but are absent from the player game roster',async()=>{
 const sql=await read('../supabase/migrations/20261117204000_exclude_two_military_airports_from_player_game_roster.sql');
 const onboarding=await read('../server/onboarding-context-service.mjs');
 assert.match(sql,/airport_player_game_roster_v1/);
 assert.match(sql,/4257/);
 assert.match(sql,/1116/);
 assert.match(sql,/OURAIRPORTS:29484/);
 assert.match(sql,/OURAIRPORTS:4436/);
 assert.match(onboarding,/airport_player_game_roster_v1/);
 assert.equal((onboarding.match(/airport_player_game_roster_v1/g)||[]).length,2);
});

test('1,116 Group 2 airports are admitted for game simulation without falsifying real-world approval',async()=>{
 const [ledger,view]=await Promise.all([
  read('../supabase/migrations/20261117211000_group2_owner_simulation_admission_ledger.sql'),
  read('../supabase/migrations/20261117212000_group2_game_admission_unified_view.sql')
 ]);
 assert.match(ledger,/GAME_SIMULATION_ONLY/);
 assert.match(ledger,/simulation_candidate_only and not documented_commercial_prohibition/);
 assert.match(ledger,/GROUP2_GAME_ADMISSION_COUNT_MISMATCH/);
 assert.match(ledger,/OURAIRPORTS:29484/);
 assert.match(ledger,/OURAIRPORTS:4436/);
 assert.match(view,/airport_group2_simulation_admissions_v1/);
 assert.match(view,/GAME_SIMULATION_ADMITTED_REAL_WORLD_EVIDENCE_UNVERIFIED/);
 assert.match(view,/operationally_authorized/);
 assert.match(view,/dispatch_eligible_by_airport_admission/);
 assert.doesNotMatch(view,/insert into airlinerra_game\.airport_group2_operational_releases_v1/i);
});

test('commercial flight release remains blocked until independent fuel, ticket, finance, and execution gates pass',async()=>{
 const s=await read('../supabase/migrations/20261117215000_commercial_flight_release_blockers_readonly.sql');
 for(const n of ['section9_flight_engine_readiness_audit_v1','section9_activation_release_policy_v1',
 'section9_trusted_execution_release_policy_v1','section9_flight_finance_posting_release_v1',
 'section9_game_fuel_model_snapshot_v1','NO_ACTIVE_CERTIFIED_FLIGHTS',
 'TRUSTED_FLIGHT_EXECUTION_RELEASE_DISABLED','FUEL_AND_AUTOMATIC_SETTLEMENT_NOT_ACTIVATED',
 'NO_AIRCRAFT_FUEL_MODEL_OPERATIONALLY_RELEASED','basic_release_gates_satisfied']){
  assert.ok(s.includes(n),n);
 }
 assert.match(s,/security_invoker=true/);
 assert.match(s,/revoke all on airlinerra_game\.section9_commercial_flight_release_blockers_v1/);
 assert.doesNotMatch(s,/UPDATE airlinerra_game\./i);
});

test('validated game fuel models can be released without enabling the cash ledger',async()=>{
 const sql=await read('../supabase/migrations/20261117224500_release_validated_game_estimate_fuel_models.sql');
 assert.match(sql,/section9_game_fuel_model_snapshot_v1/);
 assert.match(sql,/tank_capacity_kg>0/);
 assert.match(sql,/game_calculation_ready=true/);
 assert.match(sql,/financial_settlement_release='RELEASED'/);
 assert.match(sql,/UNEXPECTED_ACTIVE_CASH_POSTING_WHILE_TESTING_GAME_FUEL_MODELS/);
});
test('game fuel and finance release has reviewed evidence policy rather than a permanent false literal',async()=>{
 const sql=await read('../supabase/migrations/20261117230500_section9_reviewed_fuel_finance_release_policy.sql');
 assert.match(sql,/section9_fuel_and_settlement_release_policy_v1/);
 assert.match(sql,/execution_producer_evidence/);
 assert.match(sql,/fuel_writer_evidence/);
 assert.match(sql,/settlement_writer_evidence/);
 assert.match(sql,/section9_flight_engine_readiness_audit_v1/);
 assert.match(sql,/release_state='enabled'/);
 assert.match(sql,/revoke all on airlinerra_game.section9_fuel_and_settlement_release_policy_v1/);
 assert.match(sql,/UNEXPECTED_FLIGHT_FINANCE_RELEASE_DURING_POLICY_INSTALL/);
});
test('trusted execution release has one canonical state in both independent and certified checkers',async()=>{
 const sql=await read('../supabase/migrations/20261117221000_section9_canonical_trusted_flight_execution_state.sql');
 assert.match(sql,/THEN 'ACTIVATED'::text/);
 assert.match(sql,/END AS trusted_flight_execution_release/);
 assert.match(sql,/active_state IS DISTINCT FROM 'ACTIVATED'/);
 assert.doesNotMatch(sql,/active_state IS DISTINCT FROM 'RELEASED'/);
});

test('commercial dispatch recognizes the same certified status as the signed clearance issuer',async()=>{
 const s=await read('../supabase/migrations/20261117235500_section9_dispatch_uses_certified_approval_status.sql');
 assert.match(s,/section9_auto_dispatch_due_flight_events_v1/);
 assert.match(s,/c\.review_status='certified'/);
 assert.doesNotMatch(s,/c\.review_status='verified'/);
 assert.match(s,/section9_schedule_operational_certifications_v1/);
 assert.match(s,/activation\.release_state IS DISTINCT FROM 'enabled'/);
 assert.match(s,/execution\.release_state IS DISTINCT FROM 'enabled'/);
});
