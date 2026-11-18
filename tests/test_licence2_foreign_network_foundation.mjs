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
