import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const source=async path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('Cargo and Charter have distinct verified safety thresholds',async()=>{
 const s=await source('supabase/migrations/20261120111000_licence34_safety_thresholds_and_reissue.sql');
 assert.match(s,/SAFETY_BELOW_50_FOR_LICENCE3/);
 assert.match(s,/SAFETY_BELOW_70_FOR_LICENCE4/);
 assert.match(s,/safety_score_v1\(l\.airline_id,d\)->>'rating'\)::integer>=50/);
 assert.match(s,/safety_score_v1\(l\.airline_id,d\)->>'rating'\)::integer>=70/);
});
test('90 game days retain licence; only more than 90 revokes with an audit',async()=>{
 const s=await source('supabase/migrations/20261120110000_licence34_aircraft_90day_grace_lifecycle.sql');
 assert.match(s,/IF d>first_day\+90 THEN/);
 assert.match(s,/no_aircraft_since_game_day=first_day/);
 assert.match(s,/revoked_game_day=d/);
 assert.match(s,/licence34_revocation_history_v1/);
 assert.match(s,/IF own_count>0 THEN/);
 assert.match(s,/no_aircraft_since_game_day=NULL/);
 assert.match(s,/status','NOT_RELEASED'/);
 const independent=await source('supabase/migrations/20261120112000_licence34_independent_grace_release.sql');
 assert.match(independent,/One locked licence must not/);
 assert.match(independent,/IF row_data.licence_code='CARGO_OPERATIONS_SCOPE'/);
 assert.match(independent,/OR row_data.licence_code='CHARTER_VIP_SCOPE'/);
});
test('Grounded aircraft are not counted as operational even when fleet says in service',async()=>{
 const s=await source('supabase/migrations/20261120114000_licence34_active_maintenance_grounding.sql');
 for(const name of ['licence3_cargo_readiness_v1','licence4_charter_readiness_v1',
 'licence3_cargo_flight_scope_v1','licence4_charter_flight_scope_v1',
 'licence34_review_aircraft_grace_v1','licence34_operator_status_v1']){
  assert.ok(s.includes("p.proname='"+name+"'"),name);
 }
 const appearances=s.match(/maint\.status IN \('in_progress','payment_required'\)/g)||[];
 assert.equal(appearances.length,6);
 assert.doesNotMatch(s,/maint\.status IN \('scheduled'/);
});
test('Revocation permits a new application with a fresh full-price atomic charge',async()=>{
 const s=await source('supabase/migrations/20261120111000_licence34_safety_thresholds_and_reissue.sql');
 assert.match(s,/licence34_company_compliance_v1 health/);
 assert.match(s,/health\.revoked_game_day IS NULL/);
 assert.match(s,/ON CONFLICT\(airline_id\) DO UPDATE SET/);
 assert.match(s,/revoked_game_day=NULL,revocation_reason=NULL/);
 assert.match(s,/cash_usd=cash_usd-50000/);
 assert.match(s,/cash_usd=cash_usd-40000/);
});
test('Player status distinguishes temporary suspension from revoked licence',async()=>{
 const read=await source('supabase/migrations/20261120113000_licence34_owner_compliance_status.sql');
 const ui=await source('website/game-permission-applications-view.mjs');
 assert.match(read,/WHEN revoked THEN 'REVOKED'/);
 assert.match(read,/WHEN fleet_count=0 THEN 'SUSPENDED_NO_AIRCRAFT'/);
 assert.match(read,/WHEN rating<threshold THEN 'SUSPENDED_SAFETY'/);
 assert.match(read,/90-\(d-since_day\)/);
 assert.match(ui,/lifecycleStatus==='REVOKED'/);
 assert.match(ui,/lifecycleStatus==='SUSPENDED_NO_AIRCRAFT'/);
 assert.match(ui,/lifecycleStatus==='SUSPENDED_SAFETY'/);
});
