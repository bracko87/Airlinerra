import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('EU L2 Level 1 has 20 directed routes and other level caps remain unchanged',async()=>{
 const policy=await read('supabase/migrations/20261118105000_licence2_foreign_network_20_directed_routes_policy.sql');
 const design=await read('docs/AIRLINERRA_LICENCE2_FOREIGN_NETWORK_2026-11-17.md');
 const planner=LICENCE_PLAN.find(x=>x.code==='FOREIGN_NETWORK_LICENCE_2');
 for(const [level,limit,category] of [[1,20,'Medium'],[2,50,'Large'],[3,150,'Major Hub']])
  assert.ok(policy.includes("('L2-EU',"+level+','+limit+",'"+category+"',true)"));
 assert.match(policy,/\('L2-EU',4,null,'Mega Hub',true\)/);
 assert.match(design,/\| 1 \| \*\*20\*\*/);
 assert.match(planner.operation.join(' '),/Level 1 = 20, Level 2 = 50, Level 3 = 150, Level 4 = unlimited/);
 assert.doesNotMatch(planner.operation.join(' '),/Level 1 = 10,/);
});
test('US, UK and Japan market levels are prepared but numeric permissions not invented',async()=>{
 const policy=await read('supabase/migrations/20261118105000_licence2_foreign_network_20_directed_routes_policy.sql');
 for(const m of ['L2-EU','L2-US','L2-UK','L2-JP'])assert.ok(policy.includes(m));
 assert.match(policy,/\('L2-US',4,null,null,false\)/);
 assert.match(policy,/\('L2-UK',2,null,null,false\)/);
 assert.match(policy,/\('L2-JP',2,null,null,false\)/);
 assert.match(policy,/issuance_enabled boolean not null default false/);
 assert.match(policy,/enforcement_enabled boolean not null default false/);
 assert.match(policy,/licence2_policy_no_unreviewed_release/);
 assert.match(policy,/primary key\(world_id,airline_id,market_code\)/);
 assert.match(policy,/enable row level security/g);
 assert.match(policy,/revoke all on airlinerra_game\.licence2_airline_market_permits_v1/);
});
test('merged-airport route preview leaves AOC and commercial execution separate',async()=>{
 const classifier=await read('supabase/migrations/20261118113000_licence2_no_permit_route_preview_fail_closed.sql');
 assert.match(classifier,/airport_unified_operations_v1/);
 assert.match(classifier,/L1_HOME_MARKET_ROUTE/);
 assert.match(classifier,/L2_ISSUANCE_NOT_RELEASED/);
 assert.match(classifier,/L2_TARGET_MARKET_SELECTION_REQUIRED_OR_UNAVAILABLE/);
 assert.match(classifier,/L2_ACTIVE_FOREIGN_HUB_NOT_VERIFIED/);
 assert.match(classifier,/L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK/);
 assert.match(classifier,/canActivateFlights',false/);
 assert.match(classifier,/licence2_country_market_v1/);
 assert.doesNotMatch(classifier,/insert into airlinerra_game\.licence2_airline_market_permits_v1/i);
 assert.doesNotMatch(classifier,/update airlinerra_game\.airline_flight_schedule_drafts_v1/i);
});

test('L2 readiness uses existing AOC and aircraft evidence and does not claim invented company maturity',async()=>{
 const s=await read('supabase/migrations/20261118114500_licence2_readonly_application_eligibility.sql');
 for(const phrase of ['section9_aoc_certificates_v1','airline_aircraft_inventory',
  'section9_aoc_safety_incidents_v1','holding_world_clock_v1',
  'COMPANY_90_GAME_DAY_AGE_NOT_VERIFIED',
  'NINETY_DAY_OPERATING_COST_RESERVE_NOT_VERIFIED',
  'CRITICAL_MAINTENANCE_CLEARANCE_NOT_VERIFIED',
  'ACTIVE_OWN_AOC_NOT_VERIFIED','READ_ONLY_PREAPPLICATION_ASSESSMENT']){
  assert.ok(s.includes(phrase),phrase);
 }
 assert.match(s,/rightsGranted',false/);
 assert.match(s,/feeCharged',false/);
 assert.match(s,/revoke all on function airlinerra_game\.licence2_application_readiness_v1/);
});
test('owner draft application is idempotent and cannot be issued or charged as a draft',async()=>{
 const s=await read('supabase/migrations/20261118120500_licence2_owner_application_draft_ledger.sql');
 assert.match(s,/licence2_market_applications_v1/);
 assert.match(s,/licence2_one_open_application_per_market_v1/);
 assert.match(s,/a\.owner_player_id=p_player/);
 assert.match(s,/wm\.state='active'/);
 assert.match(s,/current_user is distinct from 'postgres'/);
 assert.match(s,/LICENCE2_SUBMISSION_REVIEW_APPROVAL_NOT_RELEASED/);
 assert.match(s,/on conflict \(world_id,airline_id,market_code\)/);
 assert.match(s,/feeCharged',false/);
 assert.match(s,/enable row level security/);
 assert.match(s,/revoke all on airlinerra_game\.licence2_market_applications_v1/);
});

test('verified company registration day and reserves never infer eligibility from creation timestamp or raw cash',async()=>{
 const source=await read('supabase/migrations/20261118133000_licence2_verified_company_age_and_financial_reserves.sql');
 const readiness=await read('supabase/migrations/20261118134500_licence2_readiness_consumes_verified_company_and_reserve_evidence.sql');
 assert.match(source,/licence2_company_game_registration_evidence_v1/);
 assert.match(source,/licence2_airline_operating_reserve_evidence_v1/);
 assert.match(source,/registered_game_date/);
 assert.match(source,/projected_daily_operating_cost_usd/);
 assert.match(source,/reserve_days>=90/);
 assert.match(source,/security_invoker=true/);
 assert.match(source,/enable row level security/g);
 assert.match(readiness,/verified_company_game_days/);
 assert.match(readiness,/COMPANY_YOUNGER_THAN_90_GAME_DAYS/);
 assert.match(readiness,/INSUFFICIENT_VERIFIED_NINETY_DAY_OPERATING_RESERVE/);
 assert.match(readiness,/NINETY_DAY_OPERATING_COST_RESERVE_NOT_VERIFIED/);
 assert.doesNotMatch(readiness,/v_age:=null/);
 assert.match(readiness,/rightsGranted',false/);
 assert.match(readiness,/feeCharged',false/);
});
test('directional allocation counts direction once, holds quota lock and blocks release without approvals',async()=>{
 const schema=await read('supabase/migrations/20261118141000_licence2_atomic_directional_route_allocation_boundary.sql');
 const guard=await read('supabase/migrations/20261118142000_licence2_directional_quota_insert_update_guard_fix.sql');
 assert.match(schema,/licence2_directed_route_allocations_v1/);
 assert.match(schema,/primary key\(world_id,airline_id,market_code,origin_airport_key,destination_airport_key\)/);
 assert.match(schema,/licence2_one_active_source_per_directed_pair_v1/);
 assert.match(schema,/allocation_state in \('reserved','active'\)/);
 assert.match(schema,/licence2_market_route_quota_usage_v1/);
 assert.match(schema,/enable row level security/);
 assert.match(guard,/pg_advisory_xact_lock/);
 assert.match(guard,/LICENCE2_ROUTE_ALLOCATION_RELEASE_DISABLED/);
 assert.match(guard,/LICENCE2_VALID_APPROVED_PERMIT_REQUIRED/);
 assert.match(guard,/L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK/);
 assert.match(guard,/LICENCE2_DIRECTED_ROUTE_QUOTA_FULL/);
 assert.match(guard,/if tg_op='INSERT' then/);
 assert.match(guard,/v_used>=v_tier.max_active_directed_routes/);
});

test('licence 2 submission requires fresh owner verified eligibility and never charges at submission',async()=>{
 const sql=await read('supabase/migrations/20261118153000_licence2_verified_submission_no_fee.sql');
 for(const term of ['licence2_submit_owner_application_v1','LICENCE2_PRIVATE_OWNER_SERVICE_ONLY',
  "wm.state='active'","app.owner_player_id=p_player","a.owner_player_id=p_player",
  "v_readiness->>'eligible' is distinct from 'true'",
  'LICENCE2_SUBMISSION_REQUIRES_LIVE_VERIFIED_READINESS',
  'LICENCE2_REVIEW_APPROVAL_NOT_RELEASED',
  'APPLICATION_SUBMITTED_FOR_REVIEW',"feeCharged',false","rightsGranted',false"]){
  assert.ok(sql.includes(term),term);
 }
 assert.match(sql,/for update of app/);
 assert.match(sql,/revoke all on function airlinerra_game\.licence2_submit_owner_application_v1/);
 assert.doesNotMatch(sql,/insert into airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(sql,/update airlinerra_game\.airlines set cash_usd/i);
});
test('licence 2 uses authoritative paid-correction AOC safety rating and reviewed maintenance evidence',async()=>{
 const sql=await read('supabase/migrations/20261118155500_licence2_verified_aoc_safety_and_maintenance_check.sql');
 const evidence=await read('supabase/migrations/20261118154500_licence2_critical_maintenance_review_evidence.sql');
 assert.match(sql,/section9_aoc_safety_score_v1/);
 assert.match(sql,/licence2_critical_maintenance_clearance_v1/);
 assert.match(sql,/UNRESOLVED_MAINTENANCE_JOB_REQUIRES_REVIEW/);
 assert.match(sql,/CRITICAL_MAINTENANCE_CLEARANCE_NOT_VERIFIED/);
 assert.doesNotMatch(sql,/100-coalesce\(sum\(penalty_points\)/);
 assert.match(evidence,/clearance_reference text not null/);
 assert.match(evidence,/enable row level security/);
 assert.match(evidence,/revoke all on airlinerra_game\.licence2_critical_maintenance_clearance_v1/);
});

test('Licence 2 approval preview requires independently reviewed fees and reconciled real ledger',async()=>{
 const sql=await read('supabase/migrations/20261118164500_licence2_approval_fee_policy_preflight.sql');
 for(const phrase of [
  'licence2_reviewed_fee_policy_v1','application_kind',
  'review_state', 'fee_usd numeric(18,2)', 'processing_game_days',
  'APPROVAL_BLOCKED','LICENCE2_ISSUANCE_PAUSED',
  'FEE_AND_PROCESSING_POLICY_NOT_APPROVED',
  'APPLICATION_NOT_SUBMITTED','PROCESSING_PERIOD_NOT_FINISHED',
  'YEARLY_UPGRADE_WINDOW_NOT_REACHED','ALREADY_HAS_THIS_OR_HIGHER_LEVEL',
  'CURRENT_ELIGIBILITY_NOT_PASSED',
  'CASH_LEDGER_NOT_RECONCILED_OR_FEE_UNSET',
  'INSUFFICIENT_COMPANY_FUNDS_FOR_FEE',
  'FEE_ALREADY_LINKED_TO_APPLICATION',
  'airlinerra_game.airline_ledger',
  'airlinerra_game.licence2_application_readiness_v1'
 ])assert.ok(sql.includes(phrase),phrase);
 assert.match(sql,/revoke all on airlinerra_game\.licence2_reviewed_fee_policy_v1/);
 assert.match(sql,/revoke all on function airlinerra_game\.licence2_approval_preflight_v1/);
 assert.match(sql,/'cashChanged',false/);
 assert.match(sql,/'feeCharged',false/);
 assert.match(sql,/'permitIssued',false/);
 assert.doesNotMatch(sql,/update airlinerra_game\.airlines set cash_usd/i);
 assert.doesNotMatch(sql,/insert into airlinerra_game\.airline_ledger/i);
});
