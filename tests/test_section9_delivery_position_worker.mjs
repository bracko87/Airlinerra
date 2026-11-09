import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9DeliveryPositionWorker,SECTION9_POSITION_SQL}
 from '../server/section9-delivery-position-worker.mjs';

function fakeDb(response,{fail=false}={}){
 const calls=[];let released=0;
 const database={connect:async()=>({
  release(){released++},
  async query(sql,params){
   calls.push({sql,params});
   if(fail)throw Error('PRIVATE_POSTGRES_NOT_AVAILABLE');
   return {rowCount:1,rows:[{result:response}]};
  }
 })};
 return {database,calls,releases:()=>released};
}
test('Unopened world refuses delivery location updates and financial actions',async()=>{
 const blocked={status:'blocked_unverified_world_clock',recorded:0,
  readOnlyCommercialFlights:true,bookingsCreated:false,ledgerPosted:false};
 const db=fakeDb(blocked);
 const worker=createSection9DeliveryPositionWorker({database:db.database});
 const result=await worker.runBatch({maxPositions:25});
 assert.equal(result.status,'blocked_unverified_world_clock');
 assert.deepEqual(db.calls,[{sql:SECTION9_POSITION_SQL.sync,params:[25]}]);
 assert.equal(db.releases(),1);
});
test('Approved delivery sync is bounded, private and does not release flights',async()=>{
 const result={status:'delivery_position_batch_processed',recorded:12,
  maxBatch:20,readOnlyCommercialFlights:true,
  bookingsCreated:false,ledgerPosted:false};
 const db=fakeDb(result);
 const worker=createSection9DeliveryPositionWorker({database:db.database});
 const next=await worker.runBatch({maxPositions:20});
 assert.equal(next.recorded,12);
 assert.equal(next.bookingsCreated,false);
 assert.equal(next.ledgerPosted,false);
 assert.deepEqual(db.calls[0].params,[20]);
});
test('Invalid requested batch never opens private database',async()=>{
 let connected=false;
 const worker=createSection9DeliveryPositionWorker({database:{
  connect:async()=>{connected=true;throw Error('should not connect')}
 }});
 for(const value of [0,101,-1,2.5,'25',null]){
  await assert.rejects(worker.runBatch({maxPositions:value}),
   /SECTION9_INVALID_POSITION_SYNC_LIMIT/);
 }
 assert.equal(connected,false);
});
test('Fake DB success or claimed commercial settlement fails closed',async()=>{
 for(const unsafe of [
  {status:'delivery_position_batch_processed',recorded:1,
   maxBatch:25,readOnlyCommercialFlights:false,bookingsCreated:false,ledgerPosted:false},
  {status:'delivery_position_batch_processed',recorded:26,
   maxBatch:25,readOnlyCommercialFlights:true,bookingsCreated:false,ledgerPosted:false},
  {status:'blocked_unverified_world_clock',recorded:1,
   readOnlyCommercialFlights:true,bookingsCreated:false,ledgerPosted:false},
  {status:'delivery_position_batch_processed',recorded:1,
   maxBatch:25,readOnlyCommercialFlights:true,bookingsCreated:true,ledgerPosted:false},
  {status:'delivery_position_batch_processed',recorded:1,
   maxBatch:25,readOnlyCommercialFlights:true,bookingsCreated:false,ledgerPosted:true},
  {status:'flight_operated',recorded:1,maxBatch:25,
   readOnlyCommercialFlights:true,bookingsCreated:false,ledgerPosted:false}
 ]){
  const db=fakeDb(unsafe);
  const worker=createSection9DeliveryPositionWorker({database:db.database});
  await assert.rejects(worker.runBatch(),/SECTION9_UNTRUSTED_DELIVERY_POSITION_RESULT|SECTION9_POSITION_RECORDED_WITHOUT_CLOCK/);
  assert.equal(db.releases(),1);
 }
});
test('Database execution failures release connection and do not invent a position',async()=>{
 const db=fakeDb(null,{fail:true});
 const worker=createSection9DeliveryPositionWorker({database:db.database});
 await assert.rejects(worker.runBatch(),/PRIVATE_POSTGRES_NOT_AVAILABLE/);
 assert.equal(db.releases(),1);
});
