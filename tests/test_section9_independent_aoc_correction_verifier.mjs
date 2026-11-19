import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {
 createIndependentAocCorrectionVerifier,aocCorrectionAttestationPayload
} from '../server/section9-independent-aoc-correction-verifier.mjs';
const airlineId='22222222-2222-4222-8222-222222222222';
const taskId='33333333-3333-4333-8333-333333333333';
const secret='unit-test-only-not-for-production-very-long-secret';
const request={
 airlineId,taskId,eventId:'game-inspection-incident-12345',
 workKind:'safety_inspection',receiptReference:'game-inspection-receipt-12345',
 completedGameDay:'2026-11-19',paidLedgerEntryId:'55',
 paidAmountUsdCents:200000
};
const payload={...request,worldId:1,
 producerEventId:'independent-proof-event-12345',
 producerReference:'trusted-inspection-worker-45678',
 evidenceSource:'independent_trusted_game_safety_producer'};
const signature=p=>createHmac('sha256',secret)
 .update(aocCorrectionAttestationPayload(p),'utf8').digest('hex');
const verifier=(record)=>createIndependentAocCorrectionVerifier({
 evidenceSource:{readSignedCorrectionReceipt:async()=>record},verificationSecret:secret
});
test('independently signed AOC correction evidence remains read-only',async()=>{
 const result=await verifier({...payload,signature:signature(payload)}).verify(request);
 assert.equal(result.verified,true);
 assert.equal(result.airlineId,airlineId);
 assert.equal(result.taskId,taskId);
 assert.equal(result.paidAmountUsdCents,200000);
 for(const field of ['feeCharged','incidentResolved','certificateIssued','flightActivated','ledgerPosted'])
  assert.equal(result[field],false);
});
test('reject missing, forged and cross-company AOC correction receipts',async()=>{
 assert.equal((await verifier(null).verify(request)).reason,
  'INDEPENDENT_CORRECTION_RECEIPT_MISSING');
 const signed={...payload,signature:signature(payload)};
 for(const changed of [
  {...signed,signature:'0'.repeat(64)},
  {...signed,airlineId:'44444444-4444-4444-8444-444444444444'},
  {...signed,taskId:'44444444-4444-4444-8444-444444444444'},
  {...signed,paidAmountUsdCents:100},
  {...signed,eventId:'different-incident-12345'},
  {...signed,workKind:'compliance_audit'},
  {...signed,evidenceSource:'player_supplied'},
  {...signed,completedGameDay:'2026-11-20'}
 ]){
  assert.equal((await verifier(changed).verify(request)).verified,false);
 }
});
test('reject invalid paid work, imaginary receipt and non-verified day',async()=>{
 const signed={...payload,signature:signature(payload)};
 for(const bad of [
  {...request,paidAmountUsdCents:0},
  {...request,paidAmountUsdCents:12.5},
  {...request,paidLedgerEntryId:'0'},
  {...request,completedGameDay:'2026-02-30'},
  {...request,workKind:'aircraft_repair'},
  {...request,receiptReference:'x'},
  {...request,taskId:'invalid'}
 ]){
  const result=await verifier(signed).verify(bad);
  assert.equal(result.verified,false);
  assert.equal(result.reason,'INVALID_CORRECTION_REQUEST');
 }
 assert.throws(()=>createIndependentAocCorrectionVerifier({
  evidenceSource:{readSignedCorrectionReceipt:async()=>signed},
  verificationSecret:'short'}),/AOC_CORRECTION_VERIFICATION_KEY_REQUIRED/);
});
