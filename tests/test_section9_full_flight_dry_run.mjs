/**
 * End-to-end SYNTHETIC test: server-owned schedule => five phases =>
 * independent source signed departure/arrival => protected dispatcher =>
 * movement results => arrival-to-fuel forecast. All adapters are mocks;
 * no production game clock, movement, refuelling or ledger is invoked.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {planSection9FivePhaseFlight,inspectSection9FlightProjection}
 from '../server/section9-flight-phase-timeline.mjs';
import {createSection9IndependentOperationAuthorizer,
 independentOperationAttestationPayload}
 from '../server/section9-independent-flight-operation-authorizer.mjs';
import {createSection9VerifiedFlightOperationsDispatcher}
 from '../server/section9-verified-flight-operations-dispatcher.mjs';
import {inspectVerifiedArrivalForFuel}
 from '../server/section9-verified-flight-fuel-bridge.mjs';
import {section9MovementSignaturePayload}
 from '../server/section9-operated-flight-movement-ingress.mjs';

const airlineId='11111111-1111-4111-8111-111111111111',
 aircraftId='22222222-2222-4222-8222-222222222222',
 scheduleId='33333333-3333-4333-8333-333333333333',
 gameDate='2026-11-11',weeklyEntry=3,
 origin='OURAIRPORTS:1',destination='OURAIRPORTS:2',
 attestationSecret='independent-world1-synthetic-source-secret-01',
 movementSecret='world1-separate-movement-ingress-secret-01';
const occurrence=scheduleId+':'+gameDate+':'+weeklyEntry;
const aircraft={
 id:aircraftId,airlineId,configurationId:16,
 fuelFamily:'TURBINE_KEROSENE_ASSUMED',
 cruiseSpeedKmh:840,emptyFuelKgPer100Km:266.6,
 halfFuelKgPer100Km:288.3,fullFuelKgPer100Km:310,
 fuelTankCapacityKg:24152
};
const route={
 airlineId,scheduleId,aircraftInventoryId:aircraftId,
 originAirportKey:origin,destinationAirportKey:destination,
 distanceKm:1000,scheduledDepartureUtc:'2026-11-11T08:00:00Z'
};
const plan=()=>planSection9FivePhaseFlight({
 airlineId,aircraftInventoryId:aircraftId,scheduleId,
 flightLocalDate:gameDate,weeklyEntry,
 scheduledDepartureUtc:route.scheduledDepartureUtc,
 originAirportKey:origin,destinationAirportKey:destination,
 distanceKm:route.distanceKm,aircraft,payloadFraction:.65,
 fuelPriceUsdPerKg:.931
});
const event=(phase,utc)=>({
 worldId:1,airlineId,aircraftInventoryId:aircraftId,
 scheduleId,scheduleVersion:1,flightOccurrenceId:occurrence,
 flightLocalDate:gameDate,weeklyEntry,phase,
 eventId:'operate-v1.'+scheduleId.replaceAll('-','')+'.20261111.3.'+phase,
 scheduledEventUtc:utc,originAirportKey:origin,destinationAirportKey:destination,
 activatedAndCapacityVerified:true
});
const signedAttestation=c=>{
 const record={
  worldId:1,airlineId,aircraftInventoryId:aircraftId,
  scheduleId,scheduleVersion:1,flightOccurrenceId:occurrence,
  flightLocalDate:gameDate,weeklyEntry,phase:c.phase,
  eventId:c.eventId,scheduledEventUtc:c.scheduledEventUtc,
  actualEventUtc:new Date(Date.parse(c.scheduledEventUtc)+30_000)
   .toISOString().replace('.000Z','Z'),
  operationReference:'trusted-world1-execution-'+c.phase+'-001',
  certifiedClockReceiptId:'world1-authoritative-day-20261111',
  evidenceSource:'independent_trusted_flight_engine'
 };
 record.signature=createHmac('sha256',attestationSecret)
  .update(independentOperationAttestationPayload(record),'utf8')
  .digest('hex');
 return record;
};
function makeHarness({withIndependentProof=true}={}){
 const flight=plan();
 assert.equal(flight.status,'FLIGHT_PHASE_DRY_RUN_PLAN');
 const candidates=[
  event('departed',route.scheduledDepartureUtc),
  event('arrived',flight.plannedCompletionUtc)
 ];
 const attestationByEvent=new Map(
  candidates.map(c=>[c.eventId,signedAttestation(c)]));
 let signedMovements=0,actualArrivals=0,replayCounter=0;
 let lastArrival=null;
 const source={
  readIndependentOperationAttestation:async identity=>
   withIndependentProof?attestationByEvent.get(identity.eventId)??null:null
 };
 const authorizer=createSection9IndependentOperationAuthorizer({
  evidenceSource:source,operationAttestationSecret:attestationSecret
 });
 const serverOwnedCandidates={
  worldId:1,readOnly:true,requiresTrustedOperationDecision:true,
  status:'verified_operational_candidates_only',
  flightActivated:false,movementRecorded:false,
  airlineId,aircraftInventoryId:aircraftId,gameDate,
  eventCount:2,candidates
 };
 const database={connect:async()=>({
  query:async()=>({rowCount:1,rows:[{result:serverOwnedCandidates}]}),
  release(){}
 })};
 const movementIngress={
  acceptSignedFlightEvent:async signed=>{
   const expected=createHmac('sha256',movementSecret)
    .update(section9MovementSignaturePayload(signed),'utf8')
    .digest('hex');
   assert.equal(signed.signature,expected);
   signedMovements++;
   const duplicated=signedMovements>2;
   if(duplicated){
    replayCounter++;
    return {status:'operated_movement_replayed',movementRecorded:false,
     replayed:true,phase:signed.phase,flightOccurrenceId:occurrence};
   }
   const r=signed.phase==='departed'?
    {status:'operated_flight_departure_recorded',
     phase:'departed',locationStatus:'in_flight'}:
    {status:'operated_flight_arrival_recorded',
     phase:'arrived',locationStatus:'grounded',
     lastVerifiedAirport:destination,canActivateNormalFlight:false};
   const receipt={...r,flightOccurrenceId:occurrence,
    movementRecorded:true,replayed:false,
    flightActivated:false,ledgerPosted:false,bookingsCreated:false};
   if(signed.phase==='arrived'){actualArrivals++;lastArrival=receipt;}
   return receipt;
  }
 };
 const dispatcher=createSection9VerifiedFlightOperationsDispatcher({
  database,operationsAuthorizer:authorizer,movementIngress,
  operatedFlightEngineSecret:movementSecret
 });
 return {
  flight,dispatcher,candidates,
  counts:()=>({signedMovements,actualArrivals,replayCounter,lastArrival})
 };
}
test('complete five-phase simulated flight can reach signed mock departure/arrival and fuel bridge',async()=>{
 const harness=makeHarness();
 const phaseStates=harness.flight.phases;
 assert.deepEqual(phaseStates.map(p=>p.key),
  ['taxiOut','climb','cruise','descent','taxiIn']);
 assert.equal(phaseStates[0].durationSeconds,900);
 assert.equal(phaseStates[1].durationSeconds,1200);
 assert.equal(phaseStates[3].durationSeconds,1200);
 assert.equal(phaseStates[4].durationSeconds,600);
 let previous=-1;
 for(const phase of phaseStates){
  const t=phase.scheduledStartUtc;
  const projection=inspectSection9FlightProjection(harness.flight,t);
  assert.ok(projection.projectedFuelBurnKg>=previous);
  previous=projection.projectedFuelBurnKg;
  assert.equal(projection.actualDepartureVerified,false);
 }
 const movement=await harness.dispatcher.dispatchAircraftDay({
  airlineId,aircraftId,gameDate
 });
 assert.equal(movement.status,'aircraft_day_movement_events_accepted');
 assert.equal(movement.processed,2);
 assert.equal(movement.replayed,0);
 const {lastArrival,actualArrivals}=harness.counts();
 assert.equal(actualArrivals,1);
 const fuel=inspectVerifiedArrivalForFuel({
  movementReceipt:lastArrival,
  movementEvent:harness.candidates[1],
  aircraft,route,
  departureAirport:{key:origin,category:'Major Hub',categoryStatus:'approved'},
  payloadFraction:.65
 });
 assert.equal(fuel.status,'ARRIVAL_FUEL_DRY_RUN_READY');
 assert.equal(fuel.projectedTimeline.status,'FLIGHT_PHASE_DRY_RUN_PLAN');
 assert.equal(fuel.flightOccurrenceId,occurrence);
 assert.equal(fuel.idempotencyCandidate,'fuel:'+occurrence);
 assert.equal(fuel.fuel.phases.length,5);
 assert.ok(fuel.fuel.tripFuelKg>0);
 assert.equal(fuel.ledgerPosted,false);
 assert.equal(fuel.flightFuelWritten,false);
 assert.equal(fuel.financialSettlementAuthorized,false);
});
test('replaying the same mock flight does not record a second arrival or fuel debit',async()=>{
 const h=makeHarness();
 const first=await h.dispatcher.dispatchAircraftDay({airlineId,aircraftId,gameDate});
 const second=await h.dispatcher.dispatchAircraftDay({airlineId,aircraftId,gameDate});
 assert.equal(first.processed,2);
 assert.equal(second.processed,2);
 assert.equal(second.replayed,2);
 assert.equal(h.counts().actualArrivals,1);
 assert.equal(h.counts().replayCounter,2);
 assert.equal(second.ledgerPosted,false);
});
test('missing independent flight execution evidence blocks the entire flight, even with a valid phase timeline',async()=>{
 const h=makeHarness({withIndependentProof:false});
 const result=await h.dispatcher.dispatchAircraftDay({airlineId,aircraftId,gameDate});
 assert.equal(h.flight.status,'FLIGHT_PHASE_DRY_RUN_PLAN');
 assert.equal(result.status,'blocked_unverified_actual_operation');
 assert.equal(result.processed,0);
 assert.equal(result.movementRecorded,false);
 assert.equal(h.counts().signedMovements,0);
 assert.equal(result.requiresTrustedOperationDecision,true);
});
