import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createAocGameInspectionProcessor,AOC_INSPECTION_WORKER_SQL}
 from '../server/section9-aoc-game-inspection-processor.mjs';
import {AOC_SIGNED_ATTESTATION_PUBLISH_SQL}
 from '../server/section9-aoc-signed-attestation-publisher.mjs';
import {AOC_INDEPENDENT_ATTESTATION_SQL}
 from '../server/section9-aoc-independent-attestation-reader.mjs';
import {AOC_VERIFIED_CORRECTION_COMMIT_SQL}
 from '../server/section9-aoc-verified-correction-commit-service.mjs';
import {aocCorrectionAttestationPayload}
 from '../server/section9-independent-aoc-correction-verifier.mjs';
const secret='test-only-game-inspection-worker-hmac-secret-123';
const row={airlineId:'22222222-2222-4222-8222-222222222222',
 taskId:'33333333-3333-4333-8333-333333333333',
 eventId:'game-correction-incident-001',workKind:'safety_inspection',
 receiptReference:'aoc-game-inspection-receipt-v1-33333333-3333-4333-8333-333333333333',
 completedGameDay:'2026-11-19',paidLedgerEntryId:'65',amountCentsText:'150000',
 producerEventId:'aoc-inspection-game-v1-33333333-3333-4333-8333-333333333333-2026-11-19',
 producerReference:'aoc-inspection-tick-v1-signed-independent-game-event-001'};
function mock({released=true,ready=[row],publish=true,complete=true}={}){
 const calls=[];
 const database={connect:async()=>({
  query:async(sql,args)=>{
   calls.push({sql,args});
   if(sql===AOC_INSPECTION_WORKER_SQL.completeDue)
    return {rowCount:1,rows:[{result:released?
     {status:'AOC_INSPECTION_WORKER_PROCESSED',completed:1,charged:false,flightActivated:false}:
     {status:'AOC_INSPECTION_WORKER_NOT_RELEASED',completed:0,charged:false,flightActivated:false}}]};
   if(sql===AOC_INSPECTION_WORKER_SQL.ready)return {rowCount:ready.length,rows:ready};
   if(sql===AOC_SIGNED_ATTESTATION_PUBLISH_SQL)
    return {rowCount:1,rows:[{result:publish?
     {status:'AOC_SIGNED_ATTESTATION_PUBLISHED',published:true,charged:false,incidentResolved:false}:
     {status:'AOC_COMPLETED_GAME_INSPECTION_NOT_VERIFIED',published:false,charged:false,incidentResolved:false}}]};
   if(sql===AOC_INDEPENDENT_ATTESTATION_SQL.read){
    const raw={worldId:1,...row,paidAmountUsdCents:150000,
     evidenceSource:'independent_trusted_game_safety_producer'};
    delete raw.amountCentsText;
    const signature=createHmac('sha256',secret)
     .update(aocCorrectionAttestationPayload(raw),'utf8').digest('hex');
    return {rowCount:1,rows:[{...raw,amountCentsText:'150000',signature}]};
   }
   if(sql===AOC_VERIFIED_CORRECTION_COMMIT_SQL)
    return {rowCount:1,rows:[{result:complete?
     {status:'INDEPENDENT_AOC_CORRECTION_STAGED',staged:true,charged:false,
      incidentResolved:true,certificateIssued:false,flightActivated:false}:
     {status:'AOC_CORRECTION_EVIDENCE_MISMATCH',staged:false,charged:false,
      incidentResolved:false,certificateIssued:false,flightActivated:false}}]};
   throw Error('UNEXPECTED_SQL');
  },release:()=>calls.push({released:true})
 })};
 return {calls,processor:createAocGameInspectionProcessor({database,signingSecret:secret})};
}
test('closed AOC releases do not produce, sign, publish or charge',async()=>{
 const {calls,processor}=mock({released:false});
 const r=await processor.run({limit:5});
 assert.equal(r.status,'AOC_INSPECTION_WORKER_NOT_RELEASED');
 assert.equal(r.published,0);assert.equal(r.resolved,0);
 assert.equal(r.charged,false);assert.equal(r.licencesIssued,0);
 assert.equal(calls.filter(x=>x.sql).length,1);
});
test('completed inspection pipeline signs persisted game evidence, then verifies completion',async()=>{
 const {calls,processor}=mock();
 const r=await processor.run({limit:4});
 assert.equal(r.published,1);
 assert.equal(r.resolved,1);
 assert.equal(r.charged,false);
 assert.equal(r.flightActivated,false);
 assert.equal(r.licencesIssued,0);
 const queries=calls.filter(x=>x.sql);
 assert.deepEqual(queries.map(x=>x.sql),[
  AOC_INSPECTION_WORKER_SQL.completeDue,AOC_INSPECTION_WORKER_SQL.ready,
  AOC_SIGNED_ATTESTATION_PUBLISH_SQL,
  AOC_INDEPENDENT_ATTESTATION_SQL.read,
  AOC_VERIFIED_CORRECTION_COMMIT_SQL]);
 assert.equal(queries[2].args[7],150000);
 assert.equal(queries[4].args[7],1500);
});
test('missing completed game receipt never signs or posts player licence rights',async()=>{
 const {calls,processor}=mock({ready:[]});
 const result=await processor.run();
 assert.equal(result.published,0);assert.equal(result.resolved,0);
 assert.equal(calls.filter(x=>x.sql).length,2);
});
test('failed independent game receipt admission cannot mark safety incident corrected',async()=>{
 const {calls,processor}=mock({publish:false});
 const result=await processor.run();
 assert.equal(result.published,0);assert.equal(result.resolved,0);
 assert.equal(result.blocked,1);
 assert.equal(calls.some(c=>c.sql===AOC_VERIFIED_CORRECTION_COMMIT_SQL),false);
});
test('reject invalid private configuration and excessive inspection batches',async()=>{
 assert.throws(()=>createAocGameInspectionProcessor({database:{connect:async()=>({})},
  signingSecret:'short'}),/SIGNING_SECRET_REQUIRED/);
 const {processor}=mock();
 await assert.rejects(processor.run({limit:101}),/BATCH_LIMIT_INVALID/);
});
