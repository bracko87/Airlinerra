import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('Licence 7 company foundation, application and approval records are private and release locked',async()=>{
 const sql=await read('supabase/migrations/20261120150000_licence7_academy_phase1_foundation.sql');
 assert.match(sql,/ADD CONSTRAINT holding_subsidiaries_v1_company_kind_check/);
 assert.match(sql,/'flight_academy'/);
 assert.match(sql,/licence7_academy_release_v1/);
 assert.match(sql,/licence7_phase1_hard_lock_v1/);
 assert.match(sql,/NOT company_registration_enabled AND NOT applications_enabled/);
 assert.match(sql,/NOT issuance_enabled AND NOT fee_collection_enabled/);
 assert.match(sql,/NOT marketplace_enabled/);
 for(const name of ['licence7_academy_applications_v1','licence7_academy_approvals_v1','licence7_academy_course_offers_v1']){
  assert.match(sql,new RegExp('CREATE TABLE airlinerra_game\\.'+name));
  assert.match(sql,new RegExp('ALTER TABLE airlinerra_game\\.'+name+' ENABLE ROW LEVEL SECURITY'));
 }
 assert.match(sql,/REVOKE ALL ON airlinerra_game\.licence7_academy_release_v1/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
});
test('Licence 7 never submits, charges, issues, or publicly sells during phase 1',async()=>{
 const sql=await read('supabase/migrations/20261120150000_licence7_academy_phase1_foundation.sql');
 assert.match(sql,/licence7_submit_academy_application_v1/);
 assert.match(sql,/licence7_review_due_academy_applications_v1/);
 assert.match(sql,/'status','NOT_RELEASED'/);
 assert.match(sql,/'applicationSubmitted',false,'charged',false,'issued',false/);
 assert.match(sql,/'reviewed',0,[\s\S]*?'issued',0,'charged',false/);
 assert.match(sql,/is_listed boolean NOT NULL DEFAULT false CHECK\(is_listed=false\)/);
 assert.match(sql,/accepts_external_bookings boolean NOT NULL DEFAULT false CHECK\(accepts_external_bookings=false\)/);
});
test('Phase 1 records agreed $40k fee, zero application fee, 7 game days, one small aircraft prerequisite',async()=>{
 const sql=await read('supabase/migrations/20261120150000_licence7_academy_phase1_foundation.sql');
 assert.match(sql,/game_fee_usd,processing_game_days,enabled_in_game/);
 assert.match(sql,/'reference_only',40000,7,false/);
 assert.match(sql,/CHECK\(fee_on_approval_usd=40000\)/);
 assert.match(sql,/CHECK\(application_fee_usd=0\)/);
 assert.match(sql,/CHECK \(due_game_day=applied_game_day\+7\)/);
 assert.match(sql,/ONE_PURCHASED_OPERATIONAL_SMALL_TRAINING_AIRCRAFT_NOT_VERIFIED/);
 const entry=LICENCE_PLAN.find(x=>x.code==='FLIGHT_ACADEMY');
 assert.ok(entry);
 assert.match(JSON.stringify(entry),/Licence 7/);
});
