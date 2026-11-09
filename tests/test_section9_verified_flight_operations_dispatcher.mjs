import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {createSection9VerifiedFlightOperationsDispatcher,
 SECTION9_OPERATIONS_DISPATCH_SQL}
 from '../server/section9-verified-flight-operations-dispatcher.mjs';
import {section9MovementSignaturePayload}
 from '../server/section9-operated-flight-movement-ingress.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const AIRCRAFT='33333333-3333-4333-8333-333333333333';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const DAY='2000-11-09';
const SECRET='flight-movement-separate-private-test-secret-v1';
const occurrence=SCHEDULE+':'+DAY+':1';
const candidate=(phase='departed',time='10:00:00')=>({
 worldId:1,airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
 scheduleId:SCHEDULE,scheduleVersion:3,flightLocalDate:DAY,
 weeklyEntry:1,flightOccurrenceId:occurrence,
 phase,scheduledEventUtc:DAY+'T'+time+'Z',
 originAirportKey:'OURAIRPORTS:2212',
 destinationAirportKey:'OURAIRPORTS:4610',
 activatedAndCapacityVerified:true,
 eventId:'operate-v1.'+SCHEDULE.replaceAll('-','')+'.20001109.1.'+phase
});
const ready=(candidates=[candidate()])=>({
 status:'verified_operational_candidates_only',
 worldId:1,airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
 gameDate:DAY,eventCount:candidates.length,readOnly:true,
 requiresTrustedOperationDecision:true,flightActivated:false,
 movementRecorded:false,candidates
});
const closed=()=>({
 status:'blocked_world_not_open',worldId:1,readOnly:true,
 requiresTrustedOperationDecision:true,flightActivated:false,
 movementRecorded:false,candidates:[]
});
function make(plan,authorizer,ingest){
 let sqlCalls=0, released=0, approvals=0, ingested=[];
 const database={connect:async()=>({
  query:async(sql,args)=>{
   sqlCalls++;
   assert.equal(sql,SECTION9_OPERATIONS_DISPATCH_SQL.candidates);
   assert.deepEqual(args,[AIRLINE,AIRCRAFT,DAY]);
   return {rowCount:1,rows:[{result:plan}]};
  },release:()=>{released++}
 })};
 const operationsAuthorizer={confirmActualOperation:async c=>{
  approvals++;return authorizer(c);
 }};
 const movementIngress={acceptSignedFlightEvent:async e=>{
  ingested.push(e);return ingest(e);
 }};
 const dispatcher=createSection9VerifiedFlightOperationsDispatcher({
  database,operationsAuthorizer,movementIngress,
  operatedFlightEngineSecret:SECRET
 });
 return {dispatcher,sqlCalls:()=>sqlCalls,released:()=>released,
  approvals:()=>approvals,ingested};
}
const confirm=c=>({
 decision:'verified_operated',worldId:1,eventId:c.eventId,
 flightOccurrenceId:c.flightOccurrenceId,
 actualEventUtc:c.scheduledEventUtc,
 operationReference:'trusted-operation-'+c.phase
});
const success=e=>({
 status:e.phase==='departed'?
  'operated_flight_departure_recorded':'operated_flight_arrival_recorded',
 movementRecorded:true,replayed:false
});
const run=d=>d.dispatchAircraftDay({
 airlineId:AIRLINE,aircraftId:AIRCRAFT,gameDate:DAY
});

test('cannot construct dispatcher without private database, secret, ingress and operations authority',()=>{
 assert.throws(()=>createSection9VerifiedFlightOperationsDispatcher({}),
  /PRIVATE_DATABASE/);
 assert.throws(()=>createSection9VerifiedFlightOperationsDispatcher({
  database:{connect:async()=>{}}
 }),/TRUSTED_OPERATION_AUTHORIZER/);
 assert.throws(()=>createSection9VerifiedFlightOperationsDispatcher({
  database:{connect:async()=>{}},operationsAuthorizer:{confirmActualOperation:()=>{}}
 }),/PRIVATE_MOVEMENT_INGRESS/);
});
test('world not open yields no authorization, no signature and no movement write',async()=>{
 const m=make(closed(),()=>{throw Error('Must not authorize')},
  ()=>{throw Error('Must not write')});
 const r=await run(m.dispatcher);
 assert.equal(r.status,'blocked_world_not_open');
 assert.equal(r.processed,0);
 assert.equal(m.approvals(),0);
 assert.equal(m.ingested.length,0);
 assert.equal(m.sqlCalls(),1);
 assert.equal(m.released(),1);
});
test('no active schedules never generates departed or arrived events',async()=>{
 const m=make({...closed(),status:'no_verified_activated_schedules'},
  ()=>{throw Error('No decision')},()=>{throw Error('No writes')});
 assert.equal((await run(m.dispatcher)).status,'no_verified_activated_schedules');
 assert.equal(m.ingested.length,0);
});
test('every departure and arrival needs its own authoritative operations decision',async()=>{
 const m=make(ready([candidate('departed'),candidate('arrived','12:00:00')]),
  c=>c.phase==='departed'?confirm(c):{decision:'flight_not_operated'},success);
 const r=await run(m.dispatcher);
 assert.equal(r.status,'blocked_unverified_actual_operation');
 assert.equal(r.processed,1);
 assert.equal(m.approvals(),2);
 assert.equal(m.ingested.length,1);
 assert.equal(m.ingested[0].phase,'departed');
});
test('authorized aircraft departs, then arrives; exact signed fields and sequence are preserved',async()=>{
 const m=make(ready([candidate('departed'),candidate('arrived','12:00:00')]),
  confirm,success);
 const r=await run(m.dispatcher);
 assert.equal(r.status,'aircraft_day_movement_events_accepted');
 assert.equal(r.processed,2);
 assert.equal(r.replayed,0);
 assert.equal(r.bookingsCreated,false);
 assert.equal(r.ledgerPosted,false);
 assert.equal(r.flightActivated,false);
 assert.deepEqual(m.ingested.map(e=>e.phase),['departed','arrived']);
 for(const signed of m.ingested){
  const expected=createHmac('sha256',SECRET)
   .update(section9MovementSignaturePayload(signed)).digest('hex');
  assert.equal(signed.signature,expected);
  assert.equal(signed.eventId,candidate(signed.phase).eventId);
 }
 assert.equal(m.released(),1);
});
test('engine retry replay is recognized without double claiming a new movement',async()=>{
 const m=make(ready(),confirm,()=>({
  status:'operated_movement_replayed',replayed:true,movementRecorded:false
 }));
 const r=await run(m.dispatcher);
 assert.equal(r.processed,1);
 assert.equal(r.replayed,1);
 assert.equal(r.movementRecorded,false);
});
test('blocked database movement stops the aircraft; never attempts a later arrival',async()=>{
 const m=make(ready([candidate('departed'),candidate('arrived','12:00:00')]),
  confirm,()=>({status:'blocked_schedule_not_operational',
   movementRecorded:false}));
 const r=await run(m.dispatcher);
 assert.equal(r.status,'blocked_movement_ingress');
 assert.equal(r.processed,0);
 assert.equal(m.approvals(),1);
 assert.equal(m.ingested.length,1);
});
test('a planned event without an actual, external operations decision is rejected',async()=>{
 const m=make(ready(),()=>({
  decision:'verified_operated',worldId:1,eventId:candidate().eventId,
  flightOccurrenceId:occurrence,operationReference:'trusted-operation-departed'
 }),success);
 assert.equal((await run(m.dispatcher)).status,'blocked_unverified_actual_operation');
 assert.equal(m.ingested.length,0);
});
test('operation authority cannot move event to another game day',async()=>{
 const m=make(ready(),c=>({...confirm(c),
  actualEventUtc:'2000-11-10T10:00:00Z'}),success);
 assert.equal((await run(m.dispatcher)).status,'blocked_unverified_actual_operation');
 assert.equal(m.ingested.length,0);
});
test('actual operated time cannot run backwards along one aircraft',async()=>{
 const m=make(ready([candidate('departed'),candidate('arrived','12:00:00')]),
  c=>({...confirm(c),actualEventUtc:c.phase==='arrived'?
   DAY+'T09:59:59Z':c.scheduledEventUtc}),success);
 const r=await run(m.dispatcher);
 assert.equal(r.status,'blocked_unverified_actual_operation');
 assert.equal(r.processed,1);
 assert.equal(m.ingested.length,1);
});
test('wrong, duplicate or unsorted candidate identity fails closed before actual-operation decisions',async()=>{
 for(const invalid of [
  ready([candidate('arrived','12:00:00'),candidate('departed')]),
  ready([candidate(),candidate()]),
  ready([{...candidate(),airlineId:'11111111-1111-4111-8111-111111111111'}]),
  ready([{...candidate(),activatedAndCapacityVerified:false}]),
  ready([{...candidate(),eventId:'fake-operation-event'}]),
  ready([{...candidate(),scheduledEventUtc:'2000-11-10T10:00:00Z'}]),
  {...ready(),movementRecorded:true},
  {...ready(),readOnly:false},
  {...ready(),eventCount:999}
 ]){
  const m=make(invalid,()=>{throw Error('Should not authorize')},
   ()=>{throw Error('Should not move')});
  await assert.rejects(run(m.dispatcher),/SECTION9_/);
  assert.equal(m.approvals(),0);
  assert.equal(m.ingested.length,0);
  assert.equal(m.released(),1);
 }
});
test('candidate SQL remains private and the dispatcher is not wired to a player or cron endpoint',async()=>{
 const src=await readFile(new URL('../server/section9-verified-flight-operations-dispatcher.mjs',
  import.meta.url),'utf8');
 assert.match(src,/requiresTrustedOperationDecision/);
 assert.doesNotMatch(src,/createSection9ClockJobHandler|fetch\(/);
 const sql=await readFile(new URL('../supabase/migrations/20261109173000_section9_operated_day_candidates.sql',
  import.meta.url),'utf8');
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/s\.status='active' AND s\.operationally_verified=true/);
 assert.doesNotMatch(sql,/UPDATE airlinerra_game\.section9_aircraft_current_position_v1|INSERT INTO airlinerra_game\.section9_operated_flight_movements_v1/);
});
