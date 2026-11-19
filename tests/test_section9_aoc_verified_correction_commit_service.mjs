import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac,createHash} from 'node:crypto';
import {createIndependentAocCorrectionVerifier,aocCorrectionAttestationPayload}
 from '../server/section9-independent-aoc-correction-verifier.mjs';
import {createAocVerifiedCorrectionCommitService,AOC_VERIFIED_CORRECTION_COMMIT_SQL}
 from '../server/section9-aoc-verified-correction-commit-service.mjs';
const secret='aoc-correction-test-private-key-never-production';
const request={
 airlineId:'22222222-2222-4222-8222-222222222222',
 taskId:'33333333-3333-4333-8333-333333333333',
 eventId:'corrective-incident-event-001',
 workKind:'safety_inspection',receiptReference:'corrective-receipt-001',
 completedGameDay:'2026-11-19',paidLedgerEntryId:'100',
 paidAmountUsdCents:150000
};
const proof={...request,worldId:1,producerEventId:'trusted-producer-event-001',
 producerReference:'producer-operation-001',
 evidenceSource:'independent_trusted_game_safety_producer'};
const signature=createHmac('sha256',secret)
 .update(aocCorrectionAttestationPayload(proof),'utf8').digest('hex');
const digest=createHash('sha256')
 .update(aocCorrectionAttestationPayload(proof),'utf8').digest('hex');
function setup(record={...proof,signature},dbResult={
 status:'INDEPENDENT_AOC_PRODUCER_NOT_RELEASED',
 staged:false,charged:false,incidentResolved:false,certificateIssued:false
}){
 const calls=[];
 const verifier=createIndependentAocCorrectionVerifier({
  evidenceSource:{readSignedCorrectionReceipt:async()=>record},
  verificationSecret:secret
 });
 const service=createAocVerifiedCorrectionCommitService({
  verifier,database:{connect:async()=>{calls.push('connect');
   return {query:async(sql,params)=>{calls.push({sql,params});
    return {rowCount:1,rows:[{result:dbResult}]};},
   release(){calls.push('release');}};}}
 });
 return {service,calls};
}
test('trusted AOC receipt is passed to private writer but blocked while producer is off',async()=>{
 const {service,calls}=setup();
 const result=await service.commit(request);
 assert.equal(result.staged,false);
 assert.equal(result.charged,false);
 assert.equal(result.status,'INDEPENDENT_AOC_PRODUCER_NOT_RELEASED');
 assert.deepEqual(calls,['connect',{sql:AOC_VERIFIED_CORRECTION_COMMIT_SQL,
  params:[request.airlineId,request.taskId,request.eventId,
   request.workKind,request.receiptReference,'2026-11-19','100',
   1500,'trusted-producer-event-001',digest]},'release']);
});
test('untrusted, forged and wrong-airline corrective receipts never connect to DB',async()=>{
 for(const altered of [
  null,{...proof,signature:'f'.repeat(64)},
  {...proof,signature,airlineId:'44444444-4444-4444-8444-444444444444'},
  {...proof,signature,paidAmountUsdCents:100},
  {...proof,signature,workKind:'compliance_audit'},
  {...proof,signature,producerEventId:'x'},
 ]){
  const {service,calls}=setup(altered);
  const result=await service.commit(request);
  assert.equal(result.staged,false);
  assert.deepEqual(calls,[]);
 }
});
test('fake positive DB result is rejected and connection is returned',async()=>{
 for(const bad of [
  {status:'INDEPENDENT_AOC_CORRECTION_STAGED',staged:true,charged:true,
   incidentResolved:false,certificateIssued:false,flightActivated:false},
  {status:'INDEPENDENT_AOC_CORRECTION_STAGED',staged:false,charged:false,
   incidentResolved:false,certificateIssued:false,flightActivated:false},
  {status:'INDEPENDENT_AOC_CORRECTION_STAGED',staged:true,charged:false,
   incidentResolved:false,certificateIssued:true,flightActivated:false}
 ]){
  const {service,calls}=setup(undefined,bad);
  await assert.rejects(service.commit(request),/AOC_UNSAFE_CORRECTION_DB_RESULT/);
  assert.equal(calls.at(-1),'release');
 }
});

test('atomic writer reports resolved incident only after all paid corrections complete',async()=>{
 const yes=setup(undefined,{status:'INDEPENDENT_AOC_CORRECTION_STAGED',
  staged:true,charged:false,incidentResolved:true,
  certificateIssued:false,flightActivated:false});
 const actual=await yes.service.commit(request);
 assert.equal(actual.staged,true);
 assert.equal(actual.incidentResolved,true);
 assert.equal(actual.charged,false);
 const no=setup(undefined,{status:'INDEPENDENT_AOC_CORRECTION_STAGED',
  staged:true,charged:false,incidentResolved:false,
  certificateIssued:false,flightActivated:false});
 assert.equal((await no.service.commit(request)).incidentResolved,false);
});
