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
