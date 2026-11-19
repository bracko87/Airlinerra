import test from 'node:test';
import assert from 'node:assert/strict';
import {createLicence2GameReviewProcessor,LICENCE2_PRIVATE_GAME_REVIEW_SQL}
 from '../server/licence2-game-review-processor.mjs';
const app='11111111-1111-4111-8111-111111111111';
const airline='22222222-2222-4222-8222-222222222222';
const secret='private-licence2-game-review-unit-test-key-123';
const candidate={applicationId:app,airlineId:airline,
 requestedLevel:1,reviewedGameDay:'2026-11-19',
 gameTickEventId:'engine-verified-game-tick-2026-11-19',
 preflight:{approvalReady:true,decision:'REVIEW_READY_NOT_APPROVAL',
  applicationId:app,market:'L2-EU',level:1,processingGameDays:3,
  quotedFeeUsd:25000,cashChanged:false,permitIssued:false,flightsActivated:false}};
function setup(rows=[],approval=null){
 const queries=[];
 const database={connect:async()=>({
  query:async(sql,args)=>{
   queries.push({sql,args});
   if(sql===LICENCE2_PRIVATE_GAME_REVIEW_SQL.queue)
    return {rowCount:rows.length,rows};
   if(sql.includes('licence2_approve_application_atomic_v1'))
    return {rowCount:1,rows:[{result:approval??{
     status:'LICENCE2_APPROVAL_NOT_RELEASED',
     chargedNow:false,permitIssuedNow:false,flightActivated:false}}]};
   throw Error('UNEXPECTED_QUERY');
  },release:()=>queries.push({released:true})
 })};
 return {queries,processor:createLicence2GameReviewProcessor({
  database,signingSecret:secret})};
}
test('unreleased Licence 2 reviewer sees no applications and never charges',async()=>{
 const {processor,queries}=setup([]);
 const r=await processor.run();
 assert.equal(r.queued,0);assert.equal(r.approved,0);
 assert.equal(r.flightsActivated,false);
 assert.equal(queries.filter(x=>x.sql).length,1);
 assert.match(queries[0].sql,/r\.approval_enabled=true/);
 assert.match(queries[0].sql,/a\.submitted_game_date<=v\.game_day-3/);
 assert.match(queries[0].sql,/section9_verified_permission_game_day_v1/);
});
test('3-day mature eligible EU application signs review and uses atomic approval once',async()=>{
 const approval={status:'APPROVED_AND_CHARGED_ONCE',
  applicationId:app,reviewEventId:'l2-game-review-v1-'+app+'-2026-11-19',
  chargedNow:true,chargedUsd:25000,permitIssuedNow:true,flightActivated:false};
 const {processor,queries}=setup([candidate],approval);
 const result=await processor.run();
 assert.equal(result.approved,1);assert.equal(result.blocked,0);
 assert.equal(result.flightsActivated,false);
 assert.deepEqual(queries.filter(q=>q.sql).length,2);
 const dbCall=queries.find(q=>q.sql?.includes('licence2_approve_application_atomic_v1'));
 assert.equal(dbCall.args[0],app);
 assert.equal(dbCall.args[1],approval.reviewEventId);
});
test('invalid or incomplete application preflight never signs or charges',async()=>{
 for(const change of [
  {preflight:{...candidate.preflight,approvalReady:false}},
  {preflight:{...candidate.preflight,processingGameDays:4}},
  {preflight:{...candidate.preflight,quotedFeeUsd:1}},
  {requestedLevel:7},
  {gameTickEventId:'short'},
  {preflight:{...candidate.preflight,cashChanged:true}}
 ]){
  const {processor,queries}=setup([{...candidate,...change}]);
  const r=await processor.run();
  assert.equal(r.approved,0);
  assert.equal(r.skipped,1);
  assert.equal(queries.filter(q=>q.sql).length,1);
 }
});
test('private Licence 2 reviewer never calls public approval without secret',async()=>{
 assert.throws(()=>createLicence2GameReviewProcessor({
  database:{connect:async()=>({})},signingSecret:'too-short'
 }),/SIGNING_SECRET_REQUIRED/);
 const {processor}=setup();
 await assert.rejects(processor.run({limit:0}),/BATCH_LIMIT_INVALID/);
});
