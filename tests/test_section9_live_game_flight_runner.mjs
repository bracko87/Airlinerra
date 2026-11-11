import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createSection9LiveGameFlightRunner,SECTION9_GAME_FLIGHT_RUN_SQL}
 from '../server/section9-live-game-flight-runner.mjs';
import {section9MovementSignaturePayload}
 from '../server/section9-operated-flight-movement-ingress.mjs';

const AIRLINE='11111111-1111-4111-8111-111111111111';
const AIRCRAFT='22222222-2222-4222-8222-222222222222';
const SCHEDULE='33333333-3333-4333-8333-333333333333';
const DAY='2026-11-11';
const SECRET='only-a-private-test-movement-signing-key-that-is-not-production';
const event={worldId:1,airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
 scheduleId:SCHEDULE,scheduleVersion:1,flightLocalDate:DAY,weeklyEntry:1,
 flightOccurrenceId:SCHEDULE+':'+DAY+':1',phase:'departed',
 scheduledEventUtc:DAY+'T10:00:00Z',
 eventId:'operate-v1.'+SCHEDULE.replaceAll('-','')+'.20261111.1.departed',
 originAirportKey:'OURAIRPORTS:4610',
 destinationAirportKey:'OURAIRPORTS:3471',
 activatedAndCapacityVerified:true};
const ready={world_id:1,world_state:'active',
 authoritative_clock_connected:true,
 trusted_flight_execution_release:'RELEASED',
 active_flight_schedules:'1',operational_certification_records:'6',
 automatic_flight_and_fuel_settlement_enabled:false,
 fuel_transaction_release:'NOT_ACTIVATED'};

const due=(events=[])=>({status:'verified_due_operation_candidates_only',
 readOnly:true,requiresTrustedOperationDecision:true,
 movementRecorded:false,ledgerPosted:false,dueEvents:events});
function factory({readiness=ready,events=[event],locked=true,attestorResult=null,
 authorizerResult=null,movementResult=null}={}){
 const calls=[];let releases=0,attested=0,authorized=0,moved=0;
 const database={async connect(){return {
  release(){releases++;},
  async query(sql,args=[]){
   calls.push({sql,args});
   if(sql===SECTION9_GAME_FLIGHT_RUN_SQL.lock)
    return {rowCount:1,rows:[{acquired:locked}]};
   if(sql===SECTION9_GAME_FLIGHT_RUN_SQL.unlock)
    return {rowCount:1,rows:[{released:true}]};
   if(sql===SECTION9_GAME_FLIGHT_RUN_SQL.readiness)
    return {rowCount:1,rows:[readiness]};
   if(sql===SECTION9_GAME_FLIGHT_RUN_SQL.now)
    return {rowCount:1,rows:[{utc_date:DAY}]};
   if(sql===SECTION9_GAME_FLIGHT_RUN_SQL.fleet)
    return {rowCount:1,rows:[{airlineId:AIRLINE,aircraftId:AIRCRAFT,
     totalAircraft:1}]};
   if(sql===SECTION9_GAME_FLIGHT_RUN_SQL.due)
    return {rowCount:1,rows:[{result:args[2]===DAY?due(events):due([])}]};
   throw Error('Unexpected SQL');
  }
 };}};
 const attestor={async attestDuePhase(args){
  attested++;assert.equal(args.eventId,event.eventId);
  return attestorResult??{status:'independent_phase_attestation_recorded'};
 }};
 const operationAuthorizer={async confirmActualOperation(c){
  authorized++;return authorizerResult??{
   decision:'verified_operated',worldId:1,eventId:c.eventId,
   flightOccurrenceId:c.flightOccurrenceId,
   actualEventUtc:DAY+'T10:00:05Z'};
 }};
 const movementIngress={async acceptSignedFlightEvent(signed){
  moved++;
  const signature=createHmac('sha256',SECRET)
    .update(section9MovementSignaturePayload(signed),'utf8').digest('hex');
  assert.equal(signed.signature,signature);
  return movementResult??{status:'operated_flight_departure_recorded',
   movementRecorded:true,replayed:false};
 }};
 return {runner:createSection9LiveGameFlightRunner({
  database,attestor,operationAuthorizer,movementIngress,
  movementSecret:SECRET}),calls,released:()=>releases,
  counts:()=>({attested,authorized,moved})};
}
test('disabled execution release cannot query fleet or create movements',async()=>{
 const m=factory({readiness:{...ready,trusted_flight_execution_release:'NOT_ACTIVATED'}});
 const r=await m.runner.runOnce();
 assert.equal(r.status,'flight_execution_not_ready');
 assert.equal(m.counts().moved,0);
 assert.deepEqual(m.calls.map(x=>x.sql),[
  SECTION9_GAME_FLIGHT_RUN_SQL.lock,
  SECTION9_GAME_FLIGHT_RUN_SQL.readiness,
  SECTION9_GAME_FLIGHT_RUN_SQL.unlock]);
 assert.equal(m.released(),1);
});
test('concurrent worker cannot operate an aircraft',async()=>{
 const m=factory({locked:false});
 const r=await m.runner.runOnce();
 assert.equal(r.status,'flight_execution_already_running');
 assert.equal(m.counts().attested,0);
 assert.deepEqual(m.calls.map(x=>x.sql),[
  SECTION9_GAME_FLIGHT_RUN_SQL.lock]);
 assert.equal(m.released(),1);
});
test('certified due game event becomes signed movement, not a financial transaction',async()=>{
 const m=factory();const r=await m.runner.runOnce();
 assert.equal(r.status,'flight_execution_batch_complete');
 assert.equal(r.movementsRecorded,1);
 assert.equal(r.eventsAttested,1);
 assert.equal(r.ledgerPosted,false);
 assert.equal(r.bookingsCreated,false);
 assert.equal(m.counts().attested,1);
 assert.equal(m.counts().authorized,1);
 assert.equal(m.counts().moved,1);
 assert.equal(m.calls.at(-1).sql,SECTION9_GAME_FLIGHT_RUN_SQL.unlock);
 assert.equal(m.released(),1);
});
test('missing independent attestation stops before movement',async()=>{
 const m=factory({attestorResult:{status:'six_signed_clearances_missing'}});
 const r=await m.runner.runOnce();
 assert.equal(r.blockedEvents,1);
 assert.equal(r.movementsRecorded,0);
 assert.equal(m.counts().authorized,0);
 assert.equal(m.counts().moved,0);
});
test('incorrect independent authorizer signature proof stops before movement',async()=>{
 const m=factory({authorizerResult:{decision:'unverified_operation'}});
 const r=await m.runner.runOnce();
 assert.equal(r.blockedEvents,1);
 assert.equal(r.movementsRecorded,0);
 assert.equal(m.counts().moved,0);
});
test('future event date mismatch fails closed rather than signing',async()=>{
 const m=factory({events:[{...event,scheduledEventUtc:'2026-11-12T10:00:00Z'}]});
 await assert.rejects(m.runner.runOnce(),/INVALID_PRIVATE_DUE_FLIGHT_EVENT/);
 assert.equal(m.counts().moved,0);
 assert.equal(m.calls.at(-1).sql,SECTION9_GAME_FLIGHT_RUN_SQL.unlock);
});
test('operation budgets must be bounded',async()=>{
 const m=factory();
 await assert.rejects(m.runner.runOnce({maxAircraft:500}),/BATCH_LIMITS/);
 await assert.rejects(m.runner.runOnce({maxEvents:0}),/BATCH_LIMITS/);
 assert.equal(m.calls.length,0);
});
