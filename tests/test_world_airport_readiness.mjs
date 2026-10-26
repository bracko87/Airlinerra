import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createWorldAirportReadinessService, WORLD_AIRPORT_READINESS_SQL
} from '../server/world-airport-readiness.mjs';

const baseline=()=>({
  activated_records:3140, missing_registry:0,
  fully_review_approved:0, unresolved_approvals:3140
});
function setup({enabled=true,row=baseline()}={}) {
  const calls=[];
  const service=createWorldAirportReadinessService({
    enabled,
    database:{async query(sql,params) {
      calls.push({sql,params});
      return {rows:[row]};
    }}
  });
  return {service,calls};
}
test('default disabled cannot query live airport research',async()=>{
  const {service,calls}=setup({enabled:false});
  await assert.rejects(service.summarizeWorld(1),/disabled/);
  assert.equal(calls.length,0);
});
test('World 01 has 3140 active but zero handoff approvals',async()=>{
  const {service,calls}=setup();
  assert.deepEqual(await service.summarizeWorld(1),{
    worldId:1,activated:3140,reviewApproved:0,unresolved:3140,
    missingRegistry:0,approvalFullyReconciled:false
  });
  assert.deepEqual(calls[0].params,[1]);
  assert.equal(calls[0].sql,WORLD_AIRPORT_READINESS_SQL);
});
test('synthetic fully reconciled world can be flagged for manual handoff',async()=>{
  const {service}=setup({row:{
    activated_records:12,missing_registry:0,
    fully_review_approved:12,unresolved_approvals:0
  }});
  const result=await service.summarizeWorld(1);
  assert.equal(result.approvalFullyReconciled,true);
  assert.equal(result.mayCreateAirline,undefined);
  assert.equal(result.airportKeys,undefined);
  assert.ok(Object.isFrozen(result));
});
test('missing registry rows keep handoff locked even with review approvals',async()=>{
  const {service}=setup({row:{
    activated_records:1,missing_registry:1,
    fully_review_approved:1,unresolved_approvals:0
  }});
  assert.equal((await service.summarizeWorld(1)).approvalFullyReconciled,false);
});
test('rejects invalid world and missing records without query',async()=>{
  const {service,calls}=setup();
  for(const id of [0,4,'1',null,1.5]){
    await assert.rejects(service.summarizeWorld(id),/Invalid game world/);
  }
  assert.equal(calls.length,0);
});
test('invalid or inconsistent research counts fail closed',async()=>{
  for(const row of [
    {...baseline(),unresolved_approvals:3139},
    {...baseline(),missing_registry:3141},
    {...baseline(),activated_records:'bogus'},
    {...baseline(),fully_review_approved:-1},
    {...baseline(),activated_records:null}
  ]) {
    const {service}=setup({row});
    await assert.rejects(service.summarizeWorld(1),/invalid counts|inconsistent/);
  }
});
test('no automatic writes, imports or approvals in read-only query',()=>{
  assert.match(WORLD_AIRPORT_READINESS_SQL,/from airlinerra\.airport_world_activation/);
  assert.match(WORLD_AIRPORT_READINESS_SQL,/w\.active = true/);
  assert.match(WORLD_AIRPORT_READINESS_SQL,/game_admission_status = 'APPROVED'/);
  assert.match(WORLD_AIRPORT_READINESS_SQL,/category_approved_at is not null/);
  assert.doesNotMatch(WORLD_AIRPORT_READINESS_SQL,/\b(insert|update|delete|grant|create)\b/i);
  assert.ok(!WORLD_AIRPORT_READINESS_SQL.includes('approved_game_airports'));
});
