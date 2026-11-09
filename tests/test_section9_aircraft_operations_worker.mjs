import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {
 createSection9AircraftOperationsWorker,SECTION9_AIRCRAFT_WORK_SQL
} from '../server/section9-aircraft-operations-worker.mjs';
import {createSection9OperatedFlightMovementIngress,SECTION9_MOVEMENT_SQL,
 section9MovementSignaturePayload}
 from '../server/section9-operated-flight-movement-ingress.mjs';
import {createSection9VerifiedFlightOperationsDispatcher,
 SECTION9_OPERATIONS_DISPATCH_SQL}
 from '../server/section9-verified-flight-operations-dispatcher.mjs';

const JOB='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const AIRCRAFT='33333333-3333-4333-8333-333333333333';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const LEASE='55555555-5555-4555-8555-555555555555';
const DAY='2000-11-09';
const SECRET='private-distinct-flight-engine-movement-secret-testing-only';
const claim={status:'claimed',jobId:JOB,airlineId:AIRLINE,
 aircraftId:AIRCRAFT,worldId:1,gameDate:DAY,attempt:1,
 leaseToken:LEASE,leaseSeconds:180,flightActivated:false};
const completion=(processed=0,replayed=0)=>({
 status:'completed',jobId:JOB,processed,replayed,
 movementEventsConfirmed:true,flightActivated:false,
 bookingsCreated:false,ledgerPosted:false
});
const fail=(code,status='queued')=>({
 status,jobId:JOB,attempt:1,failureCode:code,flightActivated:false
});
const done=(processed=0,replayed=0)=>({
 status:'aircraft_day_movement_events_accepted',processed,replayed,
 flightActivated:false,bookingsCreated:false,ledgerPosted:false
});
const mkDb=handler=>{
 const queries=[];let released=0;
 const database={connect:async()=>({
  release(){released++},
  async query(sql,args){
   queries.push({sql,args});
   const result=await handler(sql,args);
   return {rowCount:1,rows:[{result}]};
  }
 })};
 return {database,queries,released:()=>released};
};
test('worker is private and refuses missing dependencies',()=>{
 assert.throws(()=>createSection9AircraftOperationsWorker({}),
  /PRIVATE_DB_REQUIRED/);
 assert.throws(()=>createSection9AircraftOperationsWorker({
  database:{connect:async()=>{}}
 }),/VERIFIED_DISPATCHER_REQUIRED/);
});
test('unopened game cannot enqueue any jobs',async()=>{
 const d=mkDb((sql,args)=>{
  assert.equal(sql,SECTION9_AIRCRAFT_WORK_SQL.enqueue);
  assert.deepEqual(args,[DAY,null,200]);
  return {status:'blocked_unverified_world_or_game_day',
   jobsEnqueued:0,flightActivated:false,movementRecorded:false};
 });
 const w=createSection9AircraftOperationsWorker({
  database:d.database,dispatcher:{dispatchAircraftDay(){throw Error('never')}}});
 const r=await w.enqueueGameDay({gameDate:DAY});
 assert.equal(r.jobsEnqueued,0);
 assert.equal(r.status,'blocked_unverified_world_or_game_day');
 assert.equal(d.queries.length,1);
 assert.equal(d.released(),1);
});
test('keyset batch enqueue is monotonic, bounded and resumes without duplicate range',async()=>{
 const cursors=[null,AIRCRAFT];
 const responses=[
  {status:'aircraft_operation_jobs_enqueued',worldId:1,
   gameDate:DAY,jobsEnqueued:2,aircraftScanned:2,
   afterAircraftId:AIRCRAFT,hasMore:true,
   flightActivated:false,movementRecorded:false,ledgerPosted:false},
  {status:'aircraft_operation_jobs_enqueued',worldId:1,
   gameDate:DAY,jobsEnqueued:1,aircraftScanned:1,
   afterAircraftId:LEASE,hasMore:false,
   flightActivated:false,movementRecorded:false,ledgerPosted:false}
 ];
 let index=0;
 const d=mkDb((sql,args)=>{
  assert.equal(sql,SECTION9_AIRCRAFT_WORK_SQL.enqueue);
  assert.deepEqual(args,[DAY,cursors[index],2]);
  return responses[index++];
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay(){throw Error('never')}}});
 const r=await w.enqueueGameDay({gameDate:DAY,pageSize:2,maxPages:3});
 assert.equal(r.status,'enqueue_page_complete');
 assert.equal(r.jobsEnqueued,3);
 assert.equal(r.aircraftScanned,3);
 assert.equal(index,2);
 assert.equal(d.released(),2);
});
test('claim is a no-op when no validated aircraft job exists',async()=>{
 const d=mkDb((sql)=>{assert.equal(sql,SECTION9_AIRCRAFT_WORK_SQL.claim);return null;});
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay(){throw Error('never')}}});
 assert.deepEqual(await w.runOnce(),{
  status:'no_claimable_aircraft_jobs',processed:0,flightActivated:false});
 assert.equal(d.released(),1);
});
test('leased dispatcher is called with the exact aircraft and live heartbeat; DB confirms completion',async()=>{
 let dispatched=0,heartbeats=0;
 const d=mkDb((sql,args)=>{
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.claim)return claim;
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.heartbeat){
   heartbeats++;assert.deepEqual(args,[JOB,LEASE]);return true;
  }
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.complete){
   assert.deepEqual(args,[JOB,LEASE,2,1]);return completion(2,1);
  }
  throw Error('unexpected SQL');
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{async dispatchAircraftDay(args){
   dispatched++;
   assert.deepEqual([args.airlineId,args.aircraftId,args.gameDate],
    [AIRLINE,AIRCRAFT,DAY]);
   assert.deepEqual([args.lease.jobId,args.lease.leaseToken],[JOB,LEASE]);
   await args.lease.heartbeat();
   return done(2,1);
  }}});
 const r=await w.runOnce();
 assert.equal(r.status,'completed');
 assert.equal(r.processed,2);
 assert.equal(dispatched,1);
 assert.equal(heartbeats,3);
 assert.equal(d.released(),5);
});
test('unconfirmed operation is retried, never silently completed',async()=>{
 let failCalled=0;
 const d=mkDb((sql,args)=>{
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.claim)return claim;
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.heartbeat)return true;
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.fail){
   failCalled++;assert.deepEqual(args,[JOB,LEASE,'OPERATION_DECISION_MISSING']);
   return fail('OPERATION_DECISION_MISSING');
  }
  throw Error('Unexpected completion');
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay:async()=>({
   status:'blocked_unverified_actual_operation',processed:0})}});
 const result=await w.runOnce();
 assert.equal(result.status,'queued');
 assert.equal(result.failureCode,'OPERATION_DECISION_MISSING');
 assert.equal(failCalled,1);
});
test('worker exception is captured privately and retried, not published as success',async()=>{
 const d=mkDb((sql,args)=>{
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.claim)return claim;
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.heartbeat)return true;
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.fail){
   assert.deepEqual(args,[JOB,LEASE,'ENGINE_EXCEPTION']);
   return fail('ENGINE_EXCEPTION');
  }
  throw Error('Unexpected SQL');
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay:async()=>{throw Error('private stack/secret')}}});
 const r=await w.runOnce();
 assert.equal(r.status,'queued');
 assert.equal(r.failureCode,'ENGINE_EXCEPTION');
 assert.equal(JSON.stringify(r).includes('private stack'),false);
});
test('lost lease fails closed rather than claiming a successful event',async()=>{
 const d=mkDb((sql)=>{
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.claim)return claim;
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.heartbeat)throw Error('LEASE_EXPIRED');
  if(sql===SECTION9_AIRCRAFT_WORK_SQL.fail)throw Error('STALE_LEASE');
  throw Error('Never dispatch');
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay:async()=>{throw Error('Never dispatch')}}});
 await assert.rejects(w.runOnce(),/SECTION9_AIRCRAFT_WORKER_LEASE_LOST/);
 assert.equal(d.released(),3);
});
test('malformed claim is rejected before dispatching',async()=>{
 const d=mkDb(sql=>{
  assert.equal(sql,SECTION9_AIRCRAFT_WORK_SQL.claim);
  return {...claim,aircraftId:'not-a-uuid'};
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay:async()=>{throw Error('Never dispatch')}}});
 await assert.rejects(w.runOnce(),/INVALID_AIRCRAFT_JOB_CLAIM/);
});
test('500-player / 25,000-aircraft queue page budget is bounded in simulation',async()=>{
 let pages=0;const total=25000;
 const d=mkDb((sql,args)=>{
  assert.equal(sql,SECTION9_AIRCRAFT_WORK_SQL.enqueue);
  const i=pages++;
  // A deterministic UUID-like page cursor for this simulated load only.
  const cursor=(i+1).toString(16).padStart(12,'0');
  const hasMore=i<Math.ceil(total/200)-1;
  return {status:'aircraft_operation_jobs_enqueued',worldId:1,
   gameDate:DAY,jobsEnqueued:200,aircraftScanned:200,
   afterAircraftId:'00000000-0000-4000-8000-'+cursor,hasMore,
   flightActivated:false,movementRecorded:false,ledgerPosted:false};
 });
 const w=createSection9AircraftOperationsWorker({database:d.database,
  dispatcher:{dispatchAircraftDay(){throw Error('No real flight here')}}});
 const result=await w.enqueueGameDay({gameDate:DAY,pageSize:200,maxPages:150});
 assert.equal(result.jobsEnqueued,total);
 assert.equal(result.hasMore,false);
 assert.equal(pages,125);
 assert.equal(d.released(),125);
});
test('leased signed ingress sends one atomic fenced SQL call and rejects invalid lease before DB',async()=>{
 const event={worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,
  scheduleVersion:1,flightLocalDate:DAY,weeklyEntry:1,
  phase:'departed',actualEventUtc:DAY+'T10:00:00Z',
  eventId:'verified-operation-000011'};
 event.signature=createHmac('sha256',SECRET)
  .update(section9MovementSignaturePayload(event)).digest('hex');
 const reply={status:'blocked_schedule_not_operational',movementRecorded:false,
  bookingsCreated:false,ledgerPosted:false,flightActivated:false};
 const d=mkDb((sql,args)=>{
  assert.equal(sql,SECTION9_MOVEMENT_SQL.leased);
  assert.deepEqual(args,[JOB,LEASE,AIRLINE,SCHEDULE,1,DAY,1,
   'departed',DAY+'T10:00:00Z',event.eventId,event.signature]);
  return reply;
 });
 const ingress=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET});
 assert.deepEqual(await ingress.acceptSignedLeasedFlightEvent(event,
  {jobId:JOB,leaseToken:LEASE}),reply);
 assert.equal(d.released(),1);
 await assert.rejects(ingress.acceptSignedLeasedFlightEvent(event,
  {jobId:JOB,leaseToken:'bad-token'}),/INVALID_MOVEMENT_WORK_LEASE/);
 assert.equal(d.queries.length,1);
});
test('leased dispatcher heartbeats before independent decision AND before fenced movement',async()=>{
 const candidate={worldId:1,airlineId:AIRLINE,
  aircraftInventoryId:AIRCRAFT,scheduleId:SCHEDULE,scheduleVersion:1,
  flightLocalDate:DAY,weeklyEntry:1,phase:'departed',
  scheduledEventUtc:DAY+'T10:00:00Z',
  eventId:'operate-v1.'+SCHEDULE.replaceAll('-','')+'.20001109.1.departed',
  flightOccurrenceId:SCHEDULE+':'+DAY+':1',
  originAirportKey:'OURAIRPORTS:2212',destinationAirportKey:'OURAIRPORTS:4610',
  activatedAndCapacityVerified:true};
 const plan={status:'verified_operational_candidates_only',worldId:1,
  airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,gameDate:DAY,eventCount:1,
  readOnly:true,requiresTrustedOperationDecision:true,
  flightActivated:false,movementRecorded:false,candidates:[candidate]};
 const events=[];let heartbeats=0;
 const d=mkDb((sql,args)=>{
  assert.equal(sql,SECTION9_OPERATIONS_DISPATCH_SQL.candidates);
  assert.deepEqual(args,[AIRLINE,AIRCRAFT,DAY]);return plan;
 });
 const dispatcher=createSection9VerifiedFlightOperationsDispatcher({
  database:d.database,operatedFlightEngineSecret:SECRET,
  operationsAuthorizer:{async confirmActualOperation(c){
   events.push('decision');assert.equal(heartbeats,1);
   return {decision:'verified_operated',worldId:1,
    eventId:c.eventId,flightOccurrenceId:c.flightOccurrenceId,
    operationReference:'trusted-operation-departed',
    actualEventUtc:c.scheduledEventUtc};
  }},
  movementIngress:{
   acceptSignedFlightEvent(){throw Error('Unleased write forbidden')},
   async acceptSignedLeasedFlightEvent(event,lease){
    assert.equal(heartbeats,2);
    assert.deepEqual(lease,{jobId:JOB,leaseToken:LEASE});
    events.push('leased-movement');
    return {status:'operated_flight_departure_recorded',
     movementRecorded:true,replayed:false};
   }
  }
 });
 const result=await dispatcher.dispatchAircraftDay({
  airlineId:AIRLINE,aircraftId:AIRCRAFT,gameDate:DAY,
  lease:{jobId:JOB,leaseToken:LEASE,async heartbeat(){
   heartbeats++;events.push('heartbeat');
  }}
 });
 assert.equal(result.status,'aircraft_day_movement_events_accepted');
 assert.deepEqual(events,['heartbeat','decision','heartbeat','leased-movement']);
 assert.equal(result.processed,1);
});
