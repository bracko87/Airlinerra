import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9SettlementPreparationRunner,SECTION9_PREPARE_SQL}
 from '../server/section9-settlement-preparation-runner.mjs';

const date='2090-03-12';
const id='11111111-1111-4111-8111-111111111111:2090-03-12:100';
function connectWithReplies(replies){
 const calls=[];let releases=0;
 return {calls,releaseCount:()=>releases,database:{
  connect:async()=>({
   release(){releases++},
   async query(sql,args){
    assert.equal(sql,SECTION9_PREPARE_SQL);
    calls.push(args);
    const next=replies.shift();
    if(next instanceof Error)throw next;
    return {rowCount:1,rows:[{result:next}]};
   }
  })
 }};
}
const page=(count,hasMore,cursor=null,extra={})=>({
 status:'prepared_unposted',gameDate:date,
 ledgerPosted:false,bookingsCreated:false,
 flightsInspected:count,newProofs:count,newRevenueIntents:count*2,
 hasMore,nextFlightCursor:cursor,...extra
});

test('Three absent completed game-day jobs block settlement without writes',async()=>{
 const db=connectWithReplies([{
  status:'blocked_incomplete_or_unmaterialized_forecasts',
  gameDate:date,ledgerPosted:false,bookingsCreated:false
 }]);
 const res=await createSection9SettlementPreparationRunner({database:db.database})
  .prepare({gameDate:date});
 assert.equal(res.status,'blocked_incomplete_or_unmaterialized_forecasts');
 assert.equal(res.proofsCreated,0);
 assert.equal(res.ledgerPosted,false);
 assert.equal(db.calls.length,1);
 assert.equal(db.releaseCount(),1);
});

test('Bounded settlement preflight visits physical flight pages exactly once',async()=>{
 const db=connectWithReplies([page(100,true,id),page(40,false)]);
 const res=await createSection9SettlementPreparationRunner({database:db.database})
  .prepare({gameDate:date,batchSize:100});
 assert.equal(res.status,'prepared_unposted');
 assert.equal(res.processedFlights,140);
 assert.equal(res.proofsCreated,140);
 assert.equal(res.intentsCreated,280);
 assert.equal(res.ledgerPosted,false);
 assert.equal(res.bookingsCreated,false);
 assert.equal(db.calls.length,2);
 assert.deepEqual(db.calls[0],[date,null,100]);
 assert.deepEqual(db.calls[1],[date,id,100]);
 assert.equal(db.releaseCount(),1);
});

test('Any claim that cash or bookings were changed is rejected',async()=>{
 const db=connectWithReplies([page(1,false,null,{ledgerPosted:true})]);
 await assert.rejects(
  createSection9SettlementPreparationRunner({database:db.database})
   .prepare({gameDate:date}),/SECTION9_UNSAFE_SETTLEMENT_RESULT/);
 assert.equal(db.releaseCount(),1);
});

test('Stalled cursor is rejected rather than infinitely processing flights',async()=>{
 const db=connectWithReplies([page(2,true,id),page(2,true,id)]);
 await assert.rejects(
  createSection9SettlementPreparationRunner({database:db.database})
   .prepare({gameDate:date,batchSize:2}),
  /SECTION9_INVALID_SETTLEMENT_CURSOR/);
 assert.equal(db.releaseCount(),1);
});

test('Unbounded or malformed caller inputs never reach the database',async()=>{
 let connected=false;
 const db={connect:async()=>{connected=true}};
 const runner=createSection9SettlementPreparationRunner({database:db});
 for(const input of [
  {gameDate:'2090-02-31'},{gameDate:date,batchSize:300},
  {gameDate:date,maxBatches:1001},{gameDate:date,batchSize:0}
 ]){
  await assert.rejects(runner.prepare(input),
   /SECTION9_INVALID_SETTLEMENT_BATCH_REQUEST/);
 }
 assert.equal(connected,false);
});

test('Database failure does not silently publish preparation success',async()=>{
 const db=connectWithReplies([Error('connection lost')]);
 await assert.rejects(
  createSection9SettlementPreparationRunner({database:db.database})
   .prepare({gameDate:date}),/connection lost/);
 assert.equal(db.releaseCount(),1);
});
