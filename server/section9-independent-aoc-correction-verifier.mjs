/**
 * Independent AOC corrective-work attestation verifier (private server only).
 *
 * A signed receipt is evidence, not permission to spend, resolve incidents or
 * issue an AOC. The database must independently verify the same airline, event,
 * task, paid ledger entry, and immutable signed record before recording completion.
 *
 * This module DOES NOT sign attestations, mutate the database, or expose HTTP.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const REFERENCE=/^[a-zA-Z0-9._:-]{12,160}$/;
const DIGEST=/^[a-f0-9]{64}$/;
const KINDS=new Set(['safety_inspection','compliance_audit']);
const isDay=value=>typeof value==='string'&&DAY.test(value)&&
 Number.isFinite(Date.parse(value+'T00:00:00Z'))&&
 new Date(value+'T00:00:00Z').toISOString().slice(0,10)===value;
const denied=reason=>Object.freeze({verified:false,reason,
 feeCharged:false,incidentResolved:false,certificateIssued:false,
 flightActivated:false,ledgerPosted:false});
const FIELDS=Object.freeze([
 'worldId','airlineId','taskId','eventId','workKind','receiptReference',
 'completedGameDay','paidLedgerEntryId','paidAmountUsdCents',
 'producerEventId','producerReference'
]);
export function aocCorrectionAttestationPayload(a){
 return ['airlinerra-aoc-corrective-proof-v1',
  ...FIELDS.map(field=>String(a?.[field]??''))].join('\n');
}
export function createIndependentAocCorrectionVerifier({evidenceSource,verificationSecret}={}){
 if(typeof evidenceSource?.readSignedCorrectionReceipt!=='function')
  throw Error('AOC_INDEPENDENT_CORRECTION_READER_REQUIRED');
 if(typeof verificationSecret!=='string'||verificationSecret.length<32)
  throw Error('AOC_CORRECTION_VERIFICATION_KEY_REQUIRED');
 const secret=Buffer.from(verificationSecret,'utf8');
 return Object.freeze({
  async verify({airlineId,taskId,eventId,workKind,receiptReference,
   completedGameDay,paidLedgerEntryId,paidAmountUsdCents}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(taskId||'')||
      !REFERENCE.test(eventId||'')||!KINDS.has(workKind)||
      !REFERENCE.test(receiptReference||'')||!isDay(completedGameDay)||
      !/^[1-9][0-9]{0,17}$/.test(String(paidLedgerEntryId??''))||
      !Number.isSafeInteger(paidAmountUsdCents)||paidAmountUsdCents<=0)
    return denied('INVALID_CORRECTION_REQUEST');
   const requested={worldId:1,airlineId,taskId,eventId,workKind,
    receiptReference,completedGameDay,
    paidLedgerEntryId:String(paidLedgerEntryId),paidAmountUsdCents};
   const record=await evidenceSource.readSignedCorrectionReceipt(
    Object.freeze({worldId:1,airlineId,taskId,receiptReference}));
   if(!record)return denied('INDEPENDENT_CORRECTION_RECEIPT_MISSING');
   for(const field of Object.keys(requested))
    if(record[field]!==requested[field])
     return denied('CORRECTION_RECEIPT_SCOPE_MISMATCH');
   if(record.evidenceSource!=='independent_trusted_game_safety_producer'||
      !REFERENCE.test(record.producerEventId||'')||
      !REFERENCE.test(record.producerReference||'')||
      !DIGEST.test(record.signature||''))
    return denied('CORRECTION_EVIDENCE_NOT_TRUSTED');
   const expected=createHmac('sha256',secret)
    .update(aocCorrectionAttestationPayload(record),'utf8').digest();
   const received=Buffer.from(record.signature,'hex');
   if(received.length!==expected.length||!timingSafeEqual(received,expected))
    return denied('CORRECTION_SIGNATURE_INVALID');
   return Object.freeze({verified:true,
    evidenceSource:'independent_trusted_game_safety_producer',
    airlineId,taskId,eventId,receiptReference,completedGameDay,
    paidLedgerEntryId:String(paidLedgerEntryId),paidAmountUsdCents,
    producerEventId:record.producerEventId,
    feeCharged:false,incidentResolved:false,certificateIssued:false,
    flightActivated:false,ledgerPosted:false});
  }
 });
}
