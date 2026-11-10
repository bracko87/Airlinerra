/**
 * Airlinerra trusted-flight-operation VERIFIER (source only).
 *
 * A schedule candidate or a five-phase projection is NEVER a real flight.
 * Only a separate trusted flight-execution producer may issue an immutable
 * signed operation attestation after observing independently certified game
 * clock, actual phase progression and physical flight state.
 *
 * This verifier has NO signer. It consumes a private evidence reader injected
 * by the server, authenticates the independent attestation, and produces the
 * contract required by section9-verified-flight-operations-dispatcher.
 *
 * No DB mutation, automatic dispatch, invented evidence or HTTP surface.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const EVENT=/^[A-Za-z0-9._:-]{12,128}$/;
const PROOF=/^[a-f0-9]{64}$/;
const validUtc=s=>typeof s==='string'&&UTC.test(s)&&
 Number.isFinite(Date.parse(s))&&new Date(s).toISOString().slice(0,19)+'Z'===s;
const deny=reason=>Object.freeze({
 decision:'unverified_operation',reason,verified:false,
 movementRecorded:false,ledgerPosted:false,flightActivated:false
});
const required=Object.freeze([
 'worldId','airlineId','aircraftInventoryId','scheduleId','scheduleVersion',
 'flightOccurrenceId','flightLocalDate','weeklyEntry','phase','eventId',
 'scheduledEventUtc','actualEventUtc','operationReference',
 'certifiedClockReceiptId','evidenceSource'
]);
/** This payload is purpose-separated from the movement HMAC secret.
 * No automatic emission of a signed "flight operated" proof is allowed. */
export function independentOperationAttestationPayload(p){
 return [
  'airlinerra-independent-operated-flight-v1',
  ...required.map(name=>String(p?.[name]??''))
 ].join('\n');
}

export function createSection9IndependentOperationAuthorizer({
 evidenceSource,operationAttestationSecret
}={}){
 if(typeof evidenceSource?.readIndependentOperationAttestation!=='function')
  throw Error('SECTION9_INDEPENDENT_OPERATION_EVIDENCE_SOURCE_REQUIRED');
 if(typeof operationAttestationSecret!=='string'||
    operationAttestationSecret.length<32)
  throw Error('SECTION9_INDEPENDENT_OPERATION_SECRET_REQUIRED');
 const secret=Buffer.from(operationAttestationSecret,'utf8');
 return Object.freeze({
  async confirmActualOperation(candidate){
   if(!candidate||candidate.worldId!==1||
      !UUID.test(candidate.airlineId||'')||
      !UUID.test(candidate.aircraftInventoryId||'')||
      !UUID.test(candidate.scheduleId||'')||
      !DAY.test(candidate.flightLocalDate||'')||
      ![ 'departed','arrived' ].includes(candidate.phase)||
      !EVENT.test(candidate.eventId||'')||
      !Number.isSafeInteger(candidate.scheduleVersion)||
      candidate.scheduleVersion<1||
      !Number.isInteger(candidate.weeklyEntry)||
      candidate.weeklyEntry<1||candidate.weeklyEntry>7||
      !validUtc(candidate.scheduledEventUtc)||
      candidate.activatedAndCapacityVerified!==true||
      candidate.flightOccurrenceId!==
       candidate.scheduleId+':'+candidate.flightLocalDate+':'+candidate.weeklyEntry)
    return deny('INVALID_VERIFIED_OPERATION_CANDIDATE');
   // The reader MUST resolve a durable record by exact event ID, not synthesize
   // evidence from the candidate or player request.
   const record=await evidenceSource.readIndependentOperationAttestation(
    Object.freeze({
     worldId:1,airlineId:candidate.airlineId,
     aircraftInventoryId:candidate.aircraftInventoryId,
     eventId:candidate.eventId,flightOccurrenceId:candidate.flightOccurrenceId
    })
   );
   if(!record)return deny('INDEPENDENT_OPERATION_PROOF_NOT_FOUND');
   for(const key of [
    'worldId','airlineId','aircraftInventoryId','scheduleId','scheduleVersion',
    'flightOccurrenceId','flightLocalDate','weeklyEntry','phase','eventId',
    'scheduledEventUtc'
   ]){
    if(record[key]!==candidate[key])
     return deny('INDEPENDENT_OPERATION_IDENTITY_MISMATCH');
   }
   if(record.evidenceSource!=='independent_trusted_flight_engine'||
      !EVENT.test(record.operationReference||'')||
      !EVENT.test(record.certifiedClockReceiptId||'')||
      !validUtc(record.actualEventUtc)||
      record.actualEventUtc.slice(0,10)!==
       candidate.scheduledEventUtc.slice(0,10)||
      Date.parse(record.actualEventUtc)<Date.parse(candidate.scheduledEventUtc)||
      Date.parse(record.actualEventUtc)>
       Date.parse(candidate.scheduledEventUtc)+3*3600000||
      !PROOF.test(record.signature||''))
    return deny('INDEPENDENT_OPERATION_PROOF_INVALID');
   const signature=createHmac('sha256',secret)
    .update(independentOperationAttestationPayload(record),'utf8').digest();
   const observed=Buffer.from(record.signature,'hex');
   if(observed.length!==signature.length||
      !timingSafeEqual(signature,observed))
    return deny('INDEPENDENT_OPERATION_SIGNATURE_REJECTED');
   return Object.freeze({
    decision:'verified_operated',worldId:1,
    eventId:candidate.eventId,
    flightOccurrenceId:candidate.flightOccurrenceId,
    operationReference:record.operationReference,
    actualEventUtc:record.actualEventUtc,
    independentSource:'independent_trusted_flight_engine',
    // The dispatcher signs a DISTINCT database movement receipt separately.
    movementRecorded:false,ledgerPosted:false,flightActivated:false
   });
  }
 });
}
