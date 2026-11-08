import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9AtomicHoldRunner,SECTION9_ATOMIC_HOLD_SQL}
 from '../server/section9-atomic-hold-runner.mjs';

const day='2026-11-09',next='2026-11-10';
const A='11111111-1111-4111-8111-111111111111';
const B='22222222-2222-4222-8222-222222222222';
const airline='33333333-3333-4333-8333-333333333333';
const id=(schedule,date)=>schedule+':'+date+':1';
const leg=(schedule,date,pax,cargo)=>({
 flightId:id(schedule,date),scheduleId:schedule,airlineId:airline,
 marketDate:date,weeklyEntry:1,scheduleVersion:1,commercialPlanVersion:1,
 capacitySource:'verified_activated_schedule',
 verificationSource:'verified-fixture',
 passengerSeats:100,passengers:pax,directPassengers:0,
 connectingPassengers:pax,cargoCapacityTonnes:2,cargoTonnes:cargo,
 departureUtc:date+'T10:00:00Z',arrivalUtc:date+'T11:00:00Z',
 ticketRevenueUsd:pax*100,cargoRevenueUsd:cargo*80
});
const base=()=>({
 version:'section9_shared_window_v1',previewOnly:true,
 status:'read_only_global_capacity_preview',
 source:'verified_operational_schedules',
 window:{sharedPhysicalInventory:true},
 settlementAuthority:false,bookingsCreated:false,ledgerPosted:false,
 flights:[leg(A,day,40,1),leg(B,next,40,1)],
 passengers:{allocations:[{marketId:day+'|A|C',offerId:'A>C',
  flightIds:[id(A,day),id(B,next)],allocated:40}]},
 cargo:{allocations:[{marketId:day+'|A|C',offerId:'A>C',
  flightIds:[id(A,day),id(B,next)],allocated:1}]}
});
function database({failLeg=false,replay=false}={}){
 const calls=[];let released=0;
 return {calls,releaseCount:()=>released,
 database:{connect:async()=>({
  release(){released++},
  async query(sql,args){
   calls.push([sql,args]);
   if(sql===SECTION9_ATOMIC_HOLD_SQL.init)
    return {rowCount:1,rows:[{result:{
     status:'capacity_preflight_initialized',
     physicalFlightId:id(args[0],args[1]),bookingsCreated:false,
     ledgerPosted:false}}]};
   if(sql===SECTION9_ATOMIC_HOLD_SQL.hold){
    if(failLeg)throw Error('SECTION9_ATOMIC_FLIGHT_CAPACITY_EXCEEDED');
    return {rowCount:1,rows:[{result:{status:'preflight_held',
     replayed:replay,bookingsCreated:false,ledgerPosted:false}}]};
   }
   throw Error('Unknown SQL');
  }
 })}};
}
test('Both direct/connecting flight legs initialize from verified server preview only',async()=>{
 const db=database();
 const runner=createSection9AtomicHoldRunner({
  database:db.database,sharedRunner:{preview:async()=>base()}});
 const value=await runner.prepare({startGameDate:day,marketDays:2});
 assert.equal(value.status,'preflight_capacity_held');
 assert.equal(value.holds,1);assert.equal(value.bookingsCreated,false);
 assert.equal(value.ledgerPosted,false);
 assert.equal(db.releaseCount(),1);
 const inits=db.calls.filter(x=>x[0]===SECTION9_ATOMIC_HOLD_SQL.init);
 const holds=db.calls.filter(x=>x[0]===SECTION9_ATOMIC_HOLD_SQL.hold);
 assert.equal(inits.length,2);assert.equal(holds.length,1);
 assert.deepEqual(holds[0][1].slice(1),
  [[id(A,day),id(B,next)],40,1]);
 assert.match(holds[0][1][0],/^s9g1:[a-f0-9]{64}$/);
});
test('Replaying source allocation returns no additional seats and same key',async()=>{
 const db=database({replay:true});
 const runner=createSection9AtomicHoldRunner({
  database:db.database,sharedRunner:{preview:async()=>base()}});
 const first=await runner.prepare({startGameDate:day,marketDays:2});
 const second=await runner.prepare({startGameDate:day,marketDays:2});
 assert.equal(first.replayed,1);assert.equal(second.replayed,1);
 const holds=db.calls.filter(x=>x[0]===SECTION9_ATOMIC_HOLD_SQL.hold);
 assert.equal(holds[0][1][0],holds[1][1][0]);
 assert.equal(second.holds,0);
});
test('Incomplete operational certification fails before querying capacity database',async()=>{
 for(const mutate of [
  x=>{x.source='browser';},
  x=>{x.flights[0].scheduleVersion=null;},
  x=>{x.flights[0].flightId='fake';},
  x=>{x.flights[0].passengers=99;},
  x=>{x.passengers.allocations[0].allocated=110;},
  x=>{x.cargo.allocations[0].allocated=2;},
  x=>{x.window.sharedPhysicalInventory=false;}
 ]){
  const x=base();mutate(x);
  const db=database();
  const runner=createSection9AtomicHoldRunner({
   database:db.database,sharedRunner:{preview:async()=>x}});
  await assert.rejects(runner.prepare({startGameDate:day,marketDays:2}),
   /SECTION9_ATOMIC_HOLD_/);
  assert.equal(db.calls.length,0);
 }
});
test('Missing active flights returns blocked and does not initialize an inventory',async()=>{
 const db=database();
 const runner=createSection9AtomicHoldRunner({
  database:db.database,sharedRunner:{preview:async()=>({status:'no_active_flights'})}});
 const result=await runner.prepare({startGameDate:day,marketDays:2});
 assert.equal(result.status,'blocked_no_active_flights');
 assert.equal(db.calls.length,0);
});
test('Capacity SQL error is not turned into fictitious confirmed bookings',async()=>{
 const db=database({failLeg:true});
 const runner=createSection9AtomicHoldRunner({
  database:db.database,sharedRunner:{preview:async()=>base()}});
 await assert.rejects(runner.prepare({startGameDate:day,marketDays:2}),
  /SECTION9_ATOMIC_FLIGHT_CAPACITY_EXCEEDED/);
 assert.equal(db.releaseCount(),1);
});
test('Source too large requires durable sharding rather than partial held batches',async()=>{
 const db=database();
 const runner=createSection9AtomicHoldRunner({
  database:db.database,sharedRunner:{preview:async()=>base()}});
 const result=await runner.prepare({startGameDate:day,marketDays:2,maxAllocations:1});
 assert.equal(result.status,'preflight_capacity_held');
 assert.equal(result.holds,1);
});
test('Invalid run horizon and allocation cap fail before network',async()=>{
 let previewed=false;
 const runner=createSection9AtomicHoldRunner({
  database:{connect:async()=>{throw Error('must not connect')}},
  sharedRunner:{preview:async()=>{previewed=true}}
 });
 for(const arg of [
  {startGameDate:'2026-02-31',marketDays:2},
  {startGameDate:day,marketDays:1},
  {startGameDate:day,marketDays:8},
  {startGameDate:day,marketDays:2,maxAllocations:251}
 ]){
  await assert.rejects(runner.prepare(arg),/SECTION9_INVALID_ATOMIC_HOLD_RUN/);
 }
 assert.equal(previewed,false);
});
