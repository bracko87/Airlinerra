import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const sqlPath='supabase/migrations/20261120152500_licence8_aircraft_leasing_phase1_foundation.sql';
test('Licence 8 is one dry aircraft leasing licence, not wet lease or ACMI',async()=>{
 const item=LICENCE_PLAN.find(x=>x.code==='AIRCRAFT_LEASING');
 assert.ok(item);
 const s=JSON.stringify(item);
 assert.match(s,/Licence 8/);
 assert.match(s,/100,000/);
 assert.match(s,/7 verified game days/);
 assert.match(s,/no minimum leasing-company age/);
 assert.match(s,/own holding airlines and to other players/);
 assert.match(s,/Wet lease \/ ACMI.*not authorized by Licence 8/);
 assert.match(s,/OFF by default/);
});
test('licence8 schema has future company kind and $100k 7-day records with unlisted offers',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/'aircraft_leasing'/);
 assert.match(sql,/'reference_only',100000,7,false/);
 assert.match(sql,/CHECK\(due_game_day=applied_game_day\+7\)/);
 assert.match(sql,/CHECK\(application_fee_usd=0\)/);
 assert.match(sql,/CHECK\(fee_on_approval_usd=100000\)/);
 assert.match(sql,/is_listed boolean NOT NULL DEFAULT false CHECK\(is_listed=false\)/);
 assert.match(sql,/can_accept_contracts boolean NOT NULL DEFAULT false CHECK\(can_accept_contracts=false\)/);
});
test('licence8 phase 1 cannot register companies, issue, charge or execute aircraft leases',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/licence8_phase1_hard_lock_v1/);
 assert.match(sql,/NOT company_registration_enabled AND NOT applications_enabled/);
 assert.match(sql,/NOT issuance_enabled AND NOT fee_collection_enabled/);
 assert.match(sql,/NOT marketplace_enabled AND NOT lease_execution_enabled/);
 assert.match(sql,/'status','NOT_RELEASED'/);
 assert.match(sql,/'submitted',false,[\s\S]*?'charged',false,'issued',false/);
 assert.match(sql,/'reviewed',0,[\s\S]*?'issued',0,'charged',false/);
 for(const table of ['release','applications','approvals','offer_drafts']){
  const t='licence8_leasing_'+table+'_v1';
  assert.match(sql,new RegExp('CREATE TABLE airlinerra_game\\.'+t));
  assert.match(sql,new RegExp('ALTER TABLE airlinerra_game\\.'+t+' ENABLE ROW LEVEL SECURITY'));
 }
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
});
test('licence 8 separate compliance and contract preservation are documented',async()=>{
 const doc=await read('docs/AIRLINERRA_LICENCE8_AIRCRAFT_LEASING_REQUIREMENTS_2026-11-20.md');
 assert.match(doc,/dry leasing/);
 assert.match(doc,/365 verified game days/);
 assert.match(doc,/not silently change an accepted contract/);
 assert.match(doc,/NOT a working leasing marketplace/);
});
