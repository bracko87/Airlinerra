import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {
 createSection9OperatedFlightMovementIngress,
 SECTION9_MOVEMENT_SQL,section9MovementSignaturePayload
} from '../server/section9-operated-flight-movement-ingress.mjs';

const SECRET='private-operated-engine-test-signature-separate-from-clock-123456';
const AIRLINE='9c5c6aff-588f-4d25-abe5-dd91efc2e0d1';
const SCHEDULE='05ad4964-f8ac-4954-af96-767ea47f28a6';
const EVENT_ID='flight-engine-operation-0001';
const base={worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,
 scheduleVersion:1,flightLocalDate:'2000-01-03',weeklyEntry:1,
 phase:'departed',actualEventUtc:'2000-01-03T10:00:00Z',
 eventId:EVENT_ID};
const sign=event=>{
 const e={...base,...event};
 return {...e,signature:createHmac('sha256',SECRET)
  .update(section9MovementSignaturePayload(e),'utf8').digest('hex')};
};
function db(response,{fails=false}={}){
 const calls=[];let connected=0,released=0;
 return {database:{connect:async()=>{
  connected++;
  return {release(){released++},async query(sql,args){
   calls.push({sql,args});
   if(fails)throw Error('OPERATED_ENGINE_DATABASE_FAILED');
   const r=typeof response==='function'?response(sql,args):response;
   return {rowCount:1,rows:[{result:r}]};
  }};
 }},calls,count:()=>({connected,released})};
}
const occurrence=SCHEDULE+':2000-01-03:1';
const departure={status:'operated_flight_departure_recorded',
 flightOccurrenceId:occurrence,phase:'departed',movementRecorded:true,
 replayed:false,locationStatus:'in_flight',lastVerifiedAirport:null,
 canActivateNormalFlight:false,bookingsCreated:false,ledgerPosted:false,
 flightActivated:false};
const arrival={...departure,status:'operated_flight_arrival_recorded',
 phase:'arrived',locationStatus:'grounded',
 lastVerifiedAirport:'OURAIRPORTS:2212'};
const blocked={status:'blocked_schedule_not_operational',
 movementRecorded:false,bookingsCreated:false,ledgerPosted:false,
 flightActivated:false};
test('Operated-flight movement ingress requires a separate private engine signing key',()=>{
 assert.throws(()=>createSection9OperatedFlightMovementIngress({
  database:{connect:async()=>{}},operatedFlightEngineSecret:'short'}),
  /SECTION9_PRIVATE_FLIGHT_ENGINE_SECRET_REQUIRED/);
 assert.throws(()=>createSection9OperatedFlightMovementIngress({
  database:{connect:async()=>{}}}),
  /SECTION9_PRIVATE_FLIGHT_ENGINE_SECRET_REQUIRED/);
});
test('Reject fabricated, modified or malformed flight events before touching PostgreSQL',async()=>{
 const d=db(departure);
 const service=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET
 });
 const correct=sign();
 for(const bad of [
  {...correct,signature:'0'.repeat(64)},
  {...correct,scheduleId:'not-a-uuid'},
  {...correct,phase:'arrived'},
  {...correct,actualEventUtc:'2000-01-04T10:00:00Z'},
  {...correct,weeklyEntry:2},
  {...correct,scheduleVersion:2},
  {...correct,eventId:'forged-event'},
  {...correct,worldId:2},
  {...correct,phase:'cancelled'},
  {...correct,weeklyEntry:0},
  {...correct,scheduleVersion:0},
  {...correct,actualEventUtc:'2000-02-30T10:00:00Z'},
  {...correct,actorId:AIRLINE},
  {...correct,bookingsCreated:true},
  {...correct,signature:'bad'}
 ]){
  await assert.rejects(service.acceptSignedFlightEvent(bad),
   /SECTION9_INVALID_OPERATED_FLIGHT_EVENT|SECTION9_UNTRUSTED_OPERATED_FLIGHT_SIGNATURE/);
 }
 assert.deepEqual(d.count(),{connected:0,released:0});
});
test('Signed departure is sent to one private atomic SQL operation',async()=>{
 const d=db(departure);
 const service=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET
 });
 const e=sign();
 assert.deepEqual(await service.acceptSignedFlightEvent(e),departure);
 assert.equal(d.calls.length,1);
 assert.equal(d.calls[0].sql,SECTION9_MOVEMENT_SQL.ingest);
 assert.deepEqual(d.calls[0].args,[
  AIRLINE,SCHEDULE,1,'2000-01-03',1,'departed',
  '2000-01-03T10:00:00Z',EVENT_ID,e.signature]);
 assert.deepEqual(d.count(),{connected:1,released:1});
});
test('Trusted signed arrival confirms only destination, never revenue or activation',async()=>{
 const e=sign({phase:'arrived',actualEventUtc:'2000-01-03T11:00:00Z'});
 const d=db(arrival);
 const service=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET
 });
 const r=await service.acceptSignedFlightEvent(e);
 assert.equal(r.locationStatus,'grounded');
 assert.equal(r.lastVerifiedAirport,'OURAIRPORTS:2212');
 assert.equal(r.bookingsCreated,false);
 assert.equal(r.ledgerPosted,false);
 assert.equal(r.flightActivated,false);
});
test('Draft-only schedules remain blocked, even for correctly signed events',async()=>{
 const d=db(blocked);
 const service=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET
 });
 const r=await service.acceptSignedFlightEvent(sign());
 assert.equal(r.status,'blocked_schedule_not_operational');
 assert.equal(r.movementRecorded,false);
 assert.equal(r.ledgerPosted,false);
});
test('Exact repeated engine event produces a no-op receipt',async()=>{
 const d=db({status:'operated_movement_replayed',
  flightOccurrenceId:occurrence,phase:'departed',
  movementRecorded:false,replayed:true,
  bookingsCreated:false,ledgerPosted:false,flightActivated:false});
 const service=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET
 });
 const r=await service.acceptSignedFlightEvent(sign());
 assert.equal(r.replayed,true);
 assert.equal(r.movementRecorded,false);
});
test('Fail closed if SQL pretends to activate aircraft, book or credit',async()=>{
 const e=sign();
 for(const fake of [
  {...departure,ledgerPosted:true},
  {...departure,bookingsCreated:true},
  {...departure,flightActivated:true},
  {...departure,lastVerifiedAirport:'OURAIRPORTS:4610'},
  {...departure,locationStatus:'grounded'},
  {...departure,flightOccurrenceId:'another-flight'},
  {...departure,movementRecorded:false},
  {...arrival,phase:'arrived'},
  {...departure,status:'unrecognized'}
 ]){
  const d=db(fake);
  const service=createSection9OperatedFlightMovementIngress({
   database:d.database,operatedFlightEngineSecret:SECRET
  });
  await assert.rejects(service.acceptSignedFlightEvent(e),
   /SECTION9_UNSAFE_FLIGHT_MOVEMENT_DB_RESPONSE/);
  assert.deepEqual(d.count(),{connected:1,released:1});
 }
});
test('Failed private DB transactions release connections without inventing flights',async()=>{
 const d=db(null,{fails:true});
 const service=createSection9OperatedFlightMovementIngress({
  database:d.database,operatedFlightEngineSecret:SECRET
 });
 await assert.rejects(service.acceptSignedFlightEvent(sign()),
  /OPERATED_ENGINE_DATABASE_FAILED/);
 assert.deepEqual(d.count(),{connected:1,released:1});
});
