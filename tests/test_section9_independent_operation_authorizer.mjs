import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createSection9IndependentOperationAuthorizer,
 independentOperationAttestationPayload}
 from '../server/section9-independent-flight-operation-authorizer.mjs';
import {createSection9VerifiedFlightOperationsDispatcher}
 from '../server/section9-verified-flight-operations-dispatcher.mjs';
import {section9MovementSignaturePayload}
 from '../server/section9-operated-flight-movement-ingress.mjs';

const secret='independent-test-flight-source-key-000000001',
 movementSecret='independent-movement-secret-00000000002',
 airlineId='11111111-1111-4111-8111-111111111111',
 aircraftId='22222222-2222-4222-8222-222222222222',
 scheduleId='33333333-3333-4333-8333-333333333333',
 gameDate='2026-11-11';
const occurrence=scheduleId+':'+gameDate+':3';
const candidate=()=>({
 worldId:1,airlineId,aircraftInventoryId:aircraftId,
 scheduleId,scheduleVersion:1,flightOccurrenceId:occurrence,
 flightLocalDate:gameDate,weeklyEntry:3,phase:'departed',
 eventId:'operate-v1.'+scheduleId.replaceAll('-','')+'.20261111.3.departed',
 scheduledEventUtc:'2026-11-11T08:00:00Z',
 originAirportKey:'OURAIRPORTS:1',destinationAirportKey:'OURAIRPORTS:2',
 activatedAndCapacityVerified:true
});
const attest=(c=candidate(),edit=null)=>{
 const obj={
  worldId:1,airlineId:c.airlineId,aircraftInventoryId:c.aircraftInventoryId,
  scheduleId:c.scheduleId,scheduleVersion:c.scheduleVersion,
  flightOccurrenceId:c.flightOccurrenceId,flightLocalDate:c.flightLocalDate,
  weeklyEntry:c.weeklyEntry,phase:c.phase,eventId:c.eventId,
  scheduledEventUtc:c.scheduledEventUtc,actualEventUtc:'2026-11-11T08:00:30Z',
  operationReference:'flight-engine-event-001',
  certifiedClockReceiptId:'world1-verified-day-2026-11-11',
  evidenceSource:'independent_trusted_flight_engine'
 };
 edit?.(obj);
 if(!Object.hasOwn(obj,'signature'))
  obj.signature=createHmac('sha256',secret)
   .update(independentOperationAttestationPayload(obj),'utf8').digest('hex');
 return obj;
};
const authorizer=(attestation)=>createSection9IndependentOperationAuthorizer({
 operationAttestationSecret:secret,
 evidenceSource:{readIndependentOperationAttestation:async()=>attestation}
});
test('no proof never marks a flight operated',async()=>{
 const result=await authorizer(null).confirmActualOperation(candidate());
 assert.equal(result.decision,'unverified_operation');
 assert.equal(result.reason,'INDEPENDENT_OPERATION_PROOF_NOT_FOUND');
 assert.equal(result.flightActivated,false);
 assert.equal(result.movementRecorded,false);
});
test('independently signed execution receipt fulfils existing dispatcher decision contract',async()=>{
 const c=candidate(),proof=attest(c);
 const res=await authorizer(proof).confirmActualOperation(c);
 assert.deepEqual({
  decision:res.decision,worldId:res.worldId,eventId:res.eventId,
  flightOccurrenceId:res.flightOccurrenceId,
  operationReference:res.operationReference,actualEventUtc:res.actualEventUtc
 },{
  decision:'verified_operated',worldId:1,eventId:c.eventId,
  flightOccurrenceId:occurrence,
  operationReference:'flight-engine-event-001',
  actualEventUtc:'2026-11-11T08:00:30Z'
 });
 assert.equal(res.movementRecorded,false);
 assert.equal(res.ledgerPosted,false);
});
test('bad signature or cross-airline, phase, clock or event identity cannot authorize',async()=>{
 const cases=[
  p=>{p.signature='0'.repeat(64)},
  p=>{p.airlineId='44444444-4444-4444-8444-444444444444'},
  p=>{p.eventId='changed-flight-event-id'},
  p=>{p.phase='arrived'},
  p=>{p.flightOccurrenceId='other-flight'},
  p=>{p.certifiedClockReceiptId=''},
  p=>{p.evidenceSource='untrusted_player_browser'},
  p=>{p.actualEventUtc='2026-11-11T07:59:00Z'},
  p=>{p.actualEventUtc='2026-11-11T13:10:00Z'}
 ];
 for(const edit of cases){
  const c=candidate();const proof=attest(c,edit);
  // Even if independent metadata fields were signed, identity/time gates hold.
  const result=await authorizer(proof).confirmActualOperation(c);
  assert.equal(result.decision,'unverified_operation',JSON.stringify(proof));
 }
});
test('no trusted candidate/secret/evidence source leads to a real operated decision',async()=>{
 assert.throws(()=>createSection9IndependentOperationAuthorizer({
  operationAttestationSecret:secret
 }),/EVIDENCE_SOURCE_REQUIRED/);
 assert.throws(()=>createSection9IndependentOperationAuthorizer({
  evidenceSource:{readIndependentOperationAttestation:async()=>null},
  operationAttestationSecret:'bad'
 }),/SECRET_REQUIRED/);
 const c=candidate();c.activatedAndCapacityVerified=false;
 assert.equal((await authorizer(attest()).confirmActualOperation(c)).decision,'unverified_operation');
});
test('dispatcher can compose authorizer and separate signed movement ingestion mock',async()=>{
 const c=candidate(),plan={
  worldId:1,readOnly:true,requiresTrustedOperationDecision:true,
  flightActivated:false,movementRecorded:false,
  status:'verified_operational_candidates_only',
  airlineId,aircraftInventoryId:aircraftId,gameDate,eventCount:1,
  candidates:[c]
 };
 let signedMovements=0;
 const fakeDatabase={
  connect:async()=>({
   query:async()=>({rowCount:1,rows:[{result:plan}]}),
   release(){}
  })
 };
 const fakeIngress={
  acceptSignedFlightEvent:async event=>{
   const expected=createHmac('sha256',movementSecret)
    .update(section9MovementSignaturePayload(event),'utf8').digest('hex');
   assert.equal(event.signature,expected);
   signedMovements++;
   return {status:'operated_flight_departure_recorded',
    movementRecorded:true,replayed:false};
  }
 };
 const dispatcher=createSection9VerifiedFlightOperationsDispatcher({
  database:fakeDatabase,
  operationsAuthorizer:authorizer(attest(c)),
  movementIngress:fakeIngress,
  operatedFlightEngineSecret:movementSecret
 });
 const result=await dispatcher.dispatchAircraftDay({
  airlineId,aircraftId,gameDate
 });
 assert.equal(result.status,'aircraft_day_movement_events_accepted');
 assert.equal(result.processed,1);
 assert.equal(signedMovements,1);
 assert.equal(result.ledgerPosted,false);
 assert.equal(result.flightActivated,false);
});
test('dispatcher never calls movement ingestion if independent proof is unavailable',async()=>{
 const c=candidate();
 const database={connect:async()=>({
  query:async()=>({rowCount:1,rows:[{result:{
   worldId:1,readOnly:true,requiresTrustedOperationDecision:true,
   flightActivated:false,movementRecorded:false,
   status:'verified_operational_candidates_only',
   airlineId,aircraftInventoryId:aircraftId,gameDate,eventCount:1,
   candidates:[c]
  }}]}),
  release(){}
 })};
 let called=false;
 const dispatcher=createSection9VerifiedFlightOperationsDispatcher({
  database,operationsAuthorizer:authorizer(null),
  movementIngress:{acceptSignedFlightEvent:async()=>{called=true;throw Error('UNSAFE')}},
  operatedFlightEngineSecret:movementSecret
 });
 const result=await dispatcher.dispatchAircraftDay({airlineId,aircraftId,gameDate});
 assert.equal(result.status,'blocked_unverified_actual_operation');
 assert.equal(called,false);
 assert.equal(result.movementRecorded,false);
});
