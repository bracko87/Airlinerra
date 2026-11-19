import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createIndependentAocCorrectionVerifier,aocCorrectionAttestationPayload}
 from '../server/section9-independent-aoc-correction-verifier.mjs';
import {createAocSignedAttestationPublisher,AOC_SIGNED_ATTESTATION_PUBLISH_SQL}
 from '../server/section9-aoc-signed-attestation-publisher.mjs';
const secret='unit-test-aoc-game-inspection-hmac-key-00001';
const request={
 airlineId:'22222222-2222-4222-8222-222222222222',
 taskId:'33333333-3333-4333-8333-333333333333',
 eventId:'aoc-game-incident-0001',workKind:'safety_inspection',
 receiptReference:'aoc-game-signed-receipt-0001',
 completedGameDay:'2026-11-19',paidLedgerEntryId:'789',
 paidAmountUsdCents:160000
};
const evidence={worldId:1,...request,
 producerEventId:'aoc-game-inspection-event-0001',
 producerReference:'trusted-game-inspection-worker-0001',
 evidenceSource:'independent_trusted_game_safety_producer'};
const signature=e=>createHmac('sha256',secret)
 .update(aocCorrectionAttestationPayload(e),'utf8').digest('hex');
const valid={...evidence,signature:signature(evidence)};
const make=(source,dbResult={status:'AOC_INDEPENDENT_PRODUCER_NOT_RELEASED',
 published:false,charged:false,incidentResolved:false})=>{
 const calls=[];
 const verifier=createIndependentAocCorrectionVerifier({
  evidenceSource:{readSignedCorrectionReceipt:async()=>source},
  verificationSecret:secret
 });
 const publisher=createAocSignedAttestationPublisher({
  verifier,database:{connect:async()=>{
   calls.push('connect');
   return {query:async(sql,args)=>{
    calls.push({sql,args});
    return {rowCount:1,rows:[{result:dbResult}]};
   },release:()=>calls.push('release')};
  }}
 });
 return {publisher,calls};
};
test('independently signed inspection reaches private DB but cannot publish when unreleased',async()=>{
 const {publisher,calls}=make(valid);
 const result=await publisher.publish(request);
 assert.equal(result.published,false);
 assert.equal(result.status,'AOC_INDEPENDENT_PRODUCER_NOT_RELEASED');
 assert.deepEqual(calls[1].args.slice(0,10),[
  request.airlineId,request.taskId,request.eventId,request.workKind,
  request.receiptReference,request.completedGameDay,request.paidLedgerEntryId,
  request.paidAmountUsdCents,evidence.producerEventId,evidence.producerReference
 ]);
 assert.equal(calls[1].args[10],valid.signature);
 assert.match(calls[1].args[11],/^[a-f0-9]{64}$/);
 assert.equal(calls[1].sql,AOC_SIGNED_ATTESTATION_PUBLISH_SQL);
 assert.equal(calls.at(-1),'release');
});
test('missing, forged or cross-company inspection never reaches publishing SQL',async()=>{
 for(const changed of [
  null,{...valid,signature:'f'.repeat(64)},
  {...valid,taskId:'44444444-4444-4444-8444-444444444444'},
  {...valid,airlineId:'44444444-4444-4444-8444-444444444444'},
  {...valid,paidLedgerEntryId:'790'},
  {...valid,paidAmountUsdCents:1},
  {...valid,evidenceSource:'browser_supplied'}
 ]){
  const {publisher,calls}=make(changed);
  const result=await publisher.publish(request);
  assert.equal(result.published,false);
  assert.deepEqual(calls,[]);
 }
});
test('DB missing service receipt and replay remain uncharged and unpublished',async()=>{
 for(const status of [
  'AOC_COMPLETED_GAME_INSPECTION_NOT_VERIFIED','AOC_ATTESTATION_REPLAY'
 ]){
  const {publisher}=make(valid,{status,published:false,
   charged:false,incidentResolved:false});
  const result=await publisher.publish(request);
  assert.equal(result.status,status);
  assert.equal(result.charged,false);
  assert.equal(result.published,false);
 }
});
test('publisher refuses forged DB success and always releases connection',async()=>{
 const {publisher,calls}=make(valid,{status:'AOC_SIGNED_ATTESTATION_PUBLISHED',
  published:true,charged:true,incidentResolved:false});
 await assert.rejects(publisher.publish(request),/AOC_UNSAFE_ATTESTATION_PUBLISH_RESULT/);
 assert.equal(calls.at(-1),'release');
});
