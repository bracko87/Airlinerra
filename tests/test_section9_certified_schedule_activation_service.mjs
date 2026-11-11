import test from 'node:test';
import assert from 'node:assert/strict';
import {
 createSection9CertifiedScheduleActivationService,SECTION9_COMMIT_ACTIVATION_SQL
} from '../server/section9-certified-schedule-activation-service.mjs';

const owner='11111111-1111-4111-8111-111111111111';
const airline='22222222-2222-4222-8222-222222222222';
const schedule='33333333-3333-4333-8333-333333333333';
const data={airlineId:airline,scheduleId:schedule,expectedVersion:3,
 gameDate:'2026-11-11',days:28};
function setup(result,modifyApproval=x=>x){
 const seen=[];
 const database={async connect(){seen.push('connect');return {
   async query(sql,args){seen.push({sql,args});return {rowCount:1,
     rows:[{result}]};},
   release(){seen.push('release');}
 };}};
 const releaseAuthority={async authorizeActivation(req){seen.push('authority');
   return modifyApproval({authorized:true,
    source:'independent_operational_release_authority',
    ownerPlayerId:owner,...req});
 }};
 return {service:createSection9CertifiedScheduleActivationService({
   database,releaseAuthority}),seen};
}
const safe={flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false};
test('successful certified schedule activation uses private DB, not player owner',async()=>{
 const {service,seen}=setup({...safe,status:'certified_schedule_activated',
  scheduleId:schedule,scheduleVersion:3,worldId:1,scheduleActivated:true});
 const result=await service.activate(data);
 assert.equal(result.scheduleActivated,true);
 assert.equal(seen[0],'authority');
 assert.equal(seen[1],'connect');
 assert.deepEqual(seen[2],{sql:SECTION9_COMMIT_ACTIVATION_SQL.commit,
  args:[owner,airline,schedule,3,'2026-11-11',28]});
 assert.equal(seen[3],'release');
});
test('blocked release is reported but not claimed activated',async()=>{
 const {service}=setup({...safe,status:'blocked_activation_not_fully_certified',
  scheduleId:schedule,scheduleActivated:false,blockers:['CREW_MISSING']});
 const x=await service.activate(data);
 assert.equal(x.scheduleActivated,false);
});
test('missing independent release never reaches the database',async()=>{
 const {service,seen}=setup({},x=>({...x,authorized:false}));
 await assert.rejects(()=>service.activate(data),/NOT_AUTHORIZED/);
 assert.deepEqual(seen,['authority']);
});
test('spoofed owner, schedule or game day never reaches DB',async()=>{
 for(const mutator of [
   x=>({...x,ownerPlayerId:'forged'}),
   x=>({...x,scheduleId:airline}),
   x=>({...x,gameDate:'2026-11-12'}),
   x=>({...x,source:'public_client'})
 ]){
  const {service,seen}=setup({},mutator);
  await assert.rejects(()=>service.activate(data),/NOT_AUTHORIZED/);
  assert.deepEqual(seen,['authority']);
 }
});
test('invalid requests rejected before consulting release authority',async()=>{
 const {service,seen}=setup({});
 await assert.rejects(()=>service.activate({...data,days:0}),/INVALID/);
 await assert.rejects(()=>service.activate({...data,scheduleId:'bad'}),/INVALID/);
 assert.deepEqual(seen,[]);
});
test('unsafe DB claims and unknown status rejected, connection released',async()=>{
 for(const response of [
  {...safe,status:'certified_schedule_activated',scheduleId:schedule,
   scheduleVersion:3,worldId:1,scheduleActivated:false},
  {...safe,status:'blocked_activation_not_fully_certified',
   scheduleId:schedule,scheduleActivated:true},
  {...safe,status:'unknown',scheduleId:schedule,scheduleActivated:false},
  {...safe,status:'certified_schedule_activated',scheduleId:schedule,
   scheduleVersion:3,worldId:1,scheduleActivated:true,ledgerPosted:true}
 ]){
  const {service,seen}=setup(response);
  await assert.rejects(()=>service.activate(data));
  assert.equal(seen.at(-1),'release');
 }
});
