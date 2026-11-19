import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createAocIndependentAttestationReader,AOC_INDEPENDENT_ATTESTATION_SQL}
 from '../server/section9-aoc-independent-attestation-reader.mjs';
import {createIndependentAocCorrectionVerifier,aocCorrectionAttestationPayload}
 from '../server/section9-independent-aoc-correction-verifier.mjs';
import {createAocVerifiedCorrectionCommitService}
 from '../server/section9-aoc-verified-correction-commit-service.mjs';

const airlineId='22222222-2222-4222-8222-222222222222';
const taskId='33333333-3333-4333-8333-333333333333';
const secret='only-unit-test-aoc-attestation-signing-key';
const request={airlineId,taskId,eventId:'incident-game-test-0001',
 workKind:'safety_inspection',receiptReference:'receipt-game-test-0001',
 completedGameDay:'2026-11-19',paidLedgerEntryId:'123',paidAmountUsdCents:150000};
const signed={worldId:1,...request,producerEventId:'producer-game-test-0001',
 producerReference:'independent-game-safety-worker-01',
 evidenceSource:'independent_trusted_game_safety_producer'};
signed.signature=createHmac('sha256',secret)
 .update(aocCorrectionAttestationPayload(signed),'utf8').digest('hex');
const dbRow={...signed,amountCentsText:String(signed.paidAmountUsdCents)};
delete dbRow.paidAmountUsdCents;

function make(rows){
 const calls=[];
 const database={connect:async()=>{calls.push('connect');return {
  query:async(sql,args)=>{
   calls.push({sql,args});
   if(sql===AOC_INDEPENDENT_ATTESTATION_SQL.read)
    return {rowCount:rows.length,rows};
   throw Error('UNEXPECTED_WRITE_ATTEMPT');
  },release:()=>calls.push('release')
 };}};
 const reader=createAocIndependentAttestationReader({database});
 const verifier=createIndependentAocCorrectionVerifier({
  evidenceSource:reader,verificationSecret:secret});
 return {reader,verifier,calls};
}
test('AOC signed receipt reader selects exact immutable airline/task/receipt',async()=>{
 const {verifier,calls}=make([dbRow]);
 const result=await verifier.verify(request);
 assert.equal(result.verified,true);
 assert.equal(result.paidLedgerEntryId,'123');
 assert.equal(result.paidAmountUsdCents,150000);
 assert.deepEqual(calls[1].args,[airlineId,taskId,request.receiptReference]);
 assert.match(calls[1].sql,/section9_aoc_independent_correction_attestations_v1/);
 assert.equal(calls.at(-1),'release');
});
test('absent AOC independent evidence blocks completion without DB writes',async()=>{
 const {verifier,calls}=make([]);
 const completionDb={connect:()=>{throw Error('SHOULD_NOT_OPEN_COMPLETION_DB')}};
 const service=createAocVerifiedCorrectionCommitService({verifier,database:completionDb});
 const result=await service.commit(request);
 assert.equal(result.staged,false);
 assert.equal(result.status,'AOC_CORRECTION_NOT_VERIFIED');
 assert.equal(result.reason,'INDEPENDENT_CORRECTION_RECEIPT_MISSING');
 assert.equal(calls.at(-1),'release');
});
test('AOC reader rejects cross-airline, invalid money and ambiguous attestations',async()=>{
 for(const rows of [
  [{...dbRow,airlineId:'44444444-4444-4444-8444-444444444444'}],
  [{...dbRow,amountCentsText:'9007199254740993'}],
  [{...dbRow,amountCentsText:'0'}],
  [dbRow,dbRow]
 ]){
  const {reader,calls}=make(rows);
  await assert.rejects(reader.readSignedCorrectionReceipt({
   worldId:1,airlineId,taskId,receiptReference:request.receiptReference
  }),/AOC_(?:INCONSISTENT|AMBIGUOUS)_INDEPENDENT_ATTESTATION/);
  assert.equal(calls.at(-1),'release');
 }
});
test('forged stored AOC signature rejected even with perfect receipt scope',async()=>{
 const {verifier}=make([{...dbRow,signature:'f'.repeat(64)}]);
 const result=await verifier.verify(request);
 assert.equal(result.verified,false);
 assert.equal(result.reason,'CORRECTION_SIGNATURE_INVALID');
});
