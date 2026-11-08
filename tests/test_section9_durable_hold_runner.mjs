import test from 'node:test';
import assert from 'node:assert/strict';
import {
 createSection9DurableHoldRunner,SECTION9_DURABLE_HOLD_SQL
} from '../server/section9-durable-hold-runner.mjs';

const date='2026-11-09',planId='44444444-4444-4444-8444-444444444444';
const A='11111111-1111-4111-8111-111111111111';
const B='22222222-2222-4222-8222-222222222222';
const airline='33333333-3333-4333-8333-333333333333';
const fl=(uuid,d,passengers,cargoTonnes)=>({
 flightId:uuid+':'+d+':1',scheduleId:uuid,airlineId:airline,
 marketDate:d,weeklyEntry:1,scheduleVersion:1,commercialPlanVersion:1,
 capacitySource:'verified_activated_schedule',
 verificationSource:'trusted-flight-database',
 passengerSeats:500,passengers,cargoCapacityTonnes:3,cargoTonnes,
 departureUtc:d+'T10:00:00Z',arrivalUtc:d+'T11:00:00Z',
 ticketRevenueUsd:passengers*100,cargoRevenueUsd:cargoTonnes*50
});
function preview({count=1,changedMarket=false}={}){
 const pax=Array.from({length:count},(_,i)=>({
  marketId:date+'|A|C|'+i,offerId:'A>C|'+i,
  flightIds:[A+':'+date+':1',B+':2026-11-10:1'],
  allocated:1
 }));
 const flights=[
  fl(A,date,count,0),fl(B,'2026-11-10',count,0)
 ];
 return {
  status:'read_only_global_capacity_preview',
  version:'section9_shared_window_v1',
  source:'verified_operational_schedules',previewOnly:true,
  settlementAuthority:false,bookingsCreated:false,ledgerPosted:false,
  window:{sharedPhysicalInventory:true},
  flights,
  passengers:{
   allocations:pax,
   markets:pax.map(p=>({marketId:p.marketId,
    allocated:1,demand:changedMarket?3:2,unserved:changedMarket?2:1}))
  },
  cargo:{
   allocations:[],
   markets:pax.map(p=>({marketId:p.marketId,
    allocated:0,demand:0,unserved:0}))
  }
 };
}
function fakeDb({failChunk=-1,overrides=[]}={}){
 const calls=[],items=new Map();
 let released=0,job=null,chunkNumber=0;
 const next=overrides.slice();
 const database={
  async connect(){return {
   release(){released++},
   async query(sql,args){
    calls.push({sql,args});
    let result;
    if(sql===SECTION9_DURABLE_HOLD_SQL.create){
     if(job&&job.hash!==args[2])throw Error('SECTION9_CHANGED_SHARED_CALENDAR_PLAN');
     if(!job)job={hash:args[2],expected:args[3],status:'staging'};
     result={planId,status:job.status,expected:job.expected,
      nextSequence:0,preflightOnly:true,
      bookingsCreated:false,ledgerPosted:false};
    }else if(sql===SECTION9_DURABLE_HOLD_SQL.stage){
     if(chunkNumber++===failChunk)throw Error('database connection failed');
     const entries=JSON.parse(args[1]);
     for(const item of entries){
      const old=items.get(item.sequence);
      if(old&&!Object.is(JSON.stringify(old),JSON.stringify(item)))
       throw Error('STAGED_ALLOCATION_CONFLICT');
      items.set(item.sequence,item);
     }
     result={status:'staged',planId,received:entries.length,
      newItems:entries.length,preflightOnly:true,
      bookingsCreated:false,ledgerPosted:false};
    }else if(sql===SECTION9_DURABLE_HOLD_SQL.seal){
     if(items.size!==job.expected)throw Error('SECTION9_INCOMPLETE_HOLD_PLAN');
     job.status=job.expected?'ready':'completed';
     result={status:job.status,planId,expected:job.expected,
      preflightOnly:true,bookingsCreated:false,ledgerPosted:false};
    }else if(sql===SECTION9_DURABLE_HOLD_SQL.process){
     result=next.shift()||{status:'completed',planId,processed:0,
      expected:job?.expected||0,nextSequence:job?.expected||0,
      preflightOnly:true,bookingsCreated:false,ledgerPosted:false};
    }else throw Error('Unrecognized SQL operation');
    return {rowCount:1,rows:[{result}]};
   }
  }};
 };
 return {database,calls,items,released:()=>released};
}
const worker=(db,p)=>createSection9DurableHoldRunner({
 database:db.database,sharedRunner:{preview:async()=>p}
});
test('Stages 210 verified allocations in immutable chunks <=75 without creating tickets',async()=>{
 const db=fakeDb();
 const runner=worker(db,preview({count:210}));
 const result=await runner.stage({startGameDate:date,marketDays:2,chunkSize:75});
 assert.equal(result.status,'ready');
 assert.equal(result.allocationCount,210);
 assert.match(result.manifestSha256,/^[0-9a-f]{64}$/);
 const chunks=db.calls.filter(x=>x.sql===SECTION9_DURABLE_HOLD_SQL.stage);
 assert.deepEqual(chunks.map(x=>JSON.parse(x.args[1]).length),[75,75,60]);
 assert.equal(new Set([...db.items.values()].map(x=>x.allocationKey)).size,210);
 assert.ok([...db.items.values()].every(x=>x.flightIds.length===2));
 assert.equal(db.released(),1);
});
test('Changed source market demand cannot replay an existing immutable snapshot',async()=>{
 const db=fakeDb();
 const one=worker(db,preview());
 await one.stage({startGameDate:date,marketDays:2});
 const changed=worker(db,preview({changedMarket:true}));
 await assert.rejects(changed.stage({startGameDate:date,marketDays:2}),
  /SECTION9_CHANGED_SHARED_CALENDAR_PLAN/);
 assert.equal(db.released(),2);
});
test('Interrupted staging is safe to retry from the start with the exact source',async()=>{
 const db=fakeDb({failChunk:1});
 const runner=worker(db,preview({count:110}));
 await assert.rejects(runner.stage({startGameDate:date,marketDays:2,chunkSize:75}),
  /database connection failed/);
 assert.equal(db.items.size,75);
 const recovered=await runner.stage({startGameDate:date,marketDays:2,chunkSize:75});
 assert.equal(recovered.status,'ready');
 assert.equal(db.items.size,110);
 assert.equal(db.released(),2);
});
test('Completed zero demand forecast seals without inserting any holds',async()=>{
 const db=fakeDb();
 const runner=worker(db,preview({count:0}));
 const v=await runner.stage({startGameDate:date,marketDays:2});
 assert.equal(v.status,'completed');
 assert.equal(v.allocationCount,0);
 assert.equal(db.items.size,0);
 assert.equal(db.calls.filter(x=>x.sql===SECTION9_DURABLE_HOLD_SQL.stage).length,0);
});
test('Batch processing reports exact durable cursor and never financial posting',async()=>{
 const db=fakeDb({overrides:[
  {status:'ready',planId,processed:50,nextSequence:50,expected:70,
   preflightOnly:true,bookingsCreated:false,ledgerPosted:false},
  {status:'completed',planId,processed:20,nextSequence:70,expected:70,
   preflightOnly:true,bookingsCreated:false,ledgerPosted:false}
 ]});
 const runner=worker(db,preview({count:70}));
 await runner.stage({startGameDate:date,marketDays:2});
 const result=await runner.processBounded({planId,batchSize:50,maxBatches:3});
 assert.equal(result.status,'completed');
 assert.equal(result.processedThisRun,70);
 assert.equal(result.batches,2);
 assert.equal(result.ledgerPosted,false);
 assert.equal(result.bookingsCreated,false);
 assert.equal(db.released(),3);
});
test('A bounded worker reports remaining work rather than claiming full completion',async()=>{
 const db=fakeDb({overrides:[
  {status:'ready',planId,processed:10,nextSequence:10,expected:90,
   preflightOnly:true,bookingsCreated:false,ledgerPosted:false}
 ]});
 const runner=worker(db,preview({count:90}));
 const result=await runner.processBounded({planId,batchSize:10,maxBatches:1});
 assert.equal(result.status,'more_batches_required');
 assert.equal(result.processedThisRun,10);
 assert.equal(result.ledgerPosted,false);
});
test('Rejects fabricated success, invalid cursor and unsafe status from the database',async()=>{
 for(const wrong of [
  {status:'completed',planId,processed:10,nextSequence:5,expected:10,
   preflightOnly:true,bookingsCreated:false,ledgerPosted:false},
  {status:'ready',planId,processed:51,nextSequence:51,expected:200,
   preflightOnly:true,bookingsCreated:false,ledgerPosted:false},
  {status:'completed',planId,processed:0,nextSequence:0,expected:0,
   preflightOnly:true,bookingsCreated:true,ledgerPosted:false}
 ]){
  const db=fakeDb({overrides:[wrong]});
  await assert.rejects(worker(db,preview()).processNext({planId,batchSize:50}),
   /SECTION9_INCONSISTENT_HOLD_BATCH_PROGRESS|SECTION9_PREMATURE_HOLD_PLAN_COMPLETION|SECTION9_UNSAFE_HOLD_BATCH_RESULT/);
  assert.equal(db.released(),1);
 }
});
test('Malformed date or batch budget makes zero database calls',async()=>{
 let contacted=false;
 const db={connect:async()=>{contacted=true}};
 const runner=createSection9DurableHoldRunner({
  database:db,sharedRunner:{preview:async()=>{throw Error('should not preview')}}
 });
 await assert.rejects(runner.stage({startGameDate:'2026-02-30',marketDays:2}),
  /SECTION9_INVALID_DURABLE_HOLD_STAGE/);
 await assert.rejects(runner.processNext({planId:'invalid'}),
  /SECTION9_INVALID_DURABLE_HOLD_PROCESS/);
 await assert.rejects(runner.processBounded({planId,maxBatches:50}),
  /SECTION9_INVALID_BATCH_BUDGET/);
 assert.equal(contacted,false);
});
