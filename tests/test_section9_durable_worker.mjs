import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9DurableWorker,SECTION9_JOB_SQL}
 from '../server/section9-durable-forecast-worker.mjs';

const jobId='11111111-1111-4111-8111-111111111111';
const token='22222222-2222-4222-8222-222222222222';
const day='2090-03-12';
const originalFlight=(id,i=0)=>{
 const scheduleId='11111111-1111-4111-8111-111111111111';
 const weeklyEntry=i+1;
 return {
  flightId:scheduleId+':'+day+':'+weeklyEntry,scheduleId,weeklyEntry,
  airlineId:'33333333-3333-4333-8333-333333333333',
  marketDate:day,origin:'A',destination:'B',
  departureUtc:day+'T09:00:00Z',arrivalUtc:day+'T10:00:00Z',
  scheduleVersion:1,commercialPlanVersion:1,
  capacitySource:'verified_activated_schedule',
  verificationSource:'rollback-only-fixture',
  passengerSeats:100,passengers:50,
  connectingPassengers:10,directPassengers:40,
  cargoTonnes:1,cargoCapacityTonnes:2,ticketRevenueUsd:5000,
  cargoRevenueUsd:60
 };
};
const preview=(n=1)=>{
 const flights=Array.from({length:n},(_,i)=>originalFlight('f'+i,i));
 return {previewOnly:true,flightActivationAllowed:false,
  writesToAirlineLedger:false,authorizesFlightActivation:false,
  status:n?'forecast_only':'no_active_flights',flights,
  passengers:{markets:n?[{marketId:'A-B',demand:50*n,allocated:50*n,unserved:0}]:[]},
  cargo:{markets:n?[{marketId:'A-B',demand:n,allocated:n,unserved:0}]:[]}};
};
function fakeDb({queued=true,failStage=false,failMaterialize=false}={}){
 let acquired=0,released=0,claimUsed=false,completed=0,failed=0,heartbeats=0;
 const chunks=[],events=[];
 return {
  events,chunks,
  stats:()=>({acquired,released,completed,failed,heartbeats}),
  database:{async connect(){
   acquired++;
   return {release(){released++;},
    async query(sql,args){
     events.push({sql,args});
     let value;
     if(sql===SECTION9_JOB_SQL.enqueue)value={jobId,gameDate:args[0],status:'queued'};
     else if(sql===SECTION9_JOB_SQL.claim){
      value=!queued||claimUsed?null:
       {jobId,leaseToken:token,gameDate:day,attempt:1};
      claimUsed=true;
     }else if(sql===SECTION9_JOB_SQL.heartbeat){
      assert.deepEqual(args,[jobId,token]);
      heartbeats++;value=true;
     }else if(sql===SECTION9_JOB_SQL.stage){
      if(failStage)throw Error('SECTION9_INCOMPLETE_RESULT');
      assert.equal(args[0],jobId);assert.equal(args[1],token);
      const rows=JSON.parse(args[4]);
      assert.ok(rows.length>0&&rows.length<=250);
      chunks.push({kind:args[2],chunkNumber:args[3],rows});
      value={staged:true};
     }else if(sql===SECTION9_JOB_SQL.complete){
      completed++;
      assert.equal(args[2],chunks.filter(x=>x.kind==='flight')
       .reduce((n,x)=>n+x.rows.length,0));
      assert.equal(args[3],chunks.filter(x=>x.kind==='market')
       .reduce((n,x)=>n+x.rows.length,0));
      value={status:'completed',bookingsCreated:false,ledgerPosted:false};
     }else if(sql===SECTION9_JOB_SQL.materialize){
      if(failMaterialize)throw Error('SECTION9_MATERIALIZATION_UNAVAILABLE');
      const number=chunks.filter(x=>x.kind==='flight')
       .reduce((n,x)=>n+x.rows.length,0);
      value={status:'materialized',forecastRows:number,storedRows:number,
       insertedNow:number,bookingsCreated:false,ledgerPosted:false};
     }else if(sql===SECTION9_JOB_SQL.fail){
      failed++;assert.match(args[2],/^[A-Z_]+$/);
      value={status:'queued'};
     }else throw Error('Unrecognized SQL');
     return {rowCount:1,rows:[{result:value}]};
    }
   };
  }}
 };
}
test('No queued work is idle and never invokes the forecast runner',async()=>{
 let called=false;const mock=fakeDb({queued:false});
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>{called=true}}});
 assert.equal((await worker.runOne()).status,'idle');
 assert.equal(called,false);
 assert.equal(mock.stats().acquired,mock.stats().released);
});
test('Safe empty world game day completes and records zero chunks',async()=>{
 const mock=fakeDb();
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>preview(0)}});
 assert.equal((await worker.enqueue({gameDate:day})).status,'queued');
 const result=await worker.runOne();
 assert.equal(result.status,'completed');
 assert.equal(result.flightRows,0);
 assert.equal(result.marketRows,0);
 assert.equal(mock.chunks.length,0);
 assert.equal(mock.stats().completed,1);
 assert.equal(mock.stats().acquired,mock.stats().released);
 assert.equal((await worker.runOne()).status,'idle');
});
test('260 flight results staged in bounded, ordered chunks, market output once',async()=>{
 const mock=fakeDb();
 let progress=false;
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async({onProgress})=>{
   await onProgress();progress=true;return preview(260);
  }}});
 const result=await worker.runOne();
 assert.equal(result.status,'completed');assert.equal(result.flightRows,260);
 assert.equal(result.marketRows,1);
 assert.deepEqual(mock.chunks.map(x=>[x.kind,x.chunkNumber,x.rows.length]),
  [['flight',0,250],['flight',1,10],['market',0,1]]);
 assert.ok(progress);assert.ok(mock.stats().heartbeats>=2);
 assert.equal(mock.stats().acquired,mock.stats().released);
});
test('Invalid preview cannot be marked complete or credited to an airline',async()=>{
 const mock=fakeDb();
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>({...preview(),previewOnly:false})}});
 const result=await worker.runOne();
 assert.equal(result.status,'queued');
 assert.equal(result.code,'RESULT_INVALID');
 assert.equal(mock.stats().completed,0);
 assert.equal(mock.stats().failed,1);
 assert.equal(mock.chunks.length,0);
});
test('Invalid two-leg seat/cargo allocation rejects posting',async()=>{
 const mock=fakeDb();
 const bad=preview();bad.flights[0].passengers=101;
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>bad}});
 const result=await worker.runOne();
 assert.equal(result.status,'queued');
 assert.equal(result.code,'CAPACITY_INVALID');
 assert.equal(mock.stats().completed,0);
});
test('Failed DB chunk insert queues automatic retry; no completion',async()=>{
 const mock=fakeDb({failStage:true});
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>preview()}});
 const result=await worker.runOne();
 assert.equal(result.status,'queued');
 assert.equal(mock.stats().completed,0);
 assert.equal(mock.stats().failed,1);
});

test('Interrupted completed-job materialization cannot be mistaken for settled work',async()=>{
 const mock=fakeDb({failMaterialize:true});
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>preview(1)}});
 const result=await worker.runOne();
 assert.equal(result.status,'completed_materialization_pending');
 assert.equal(result.ledgerPosted,false);
 assert.equal(mock.stats().completed,1);
 assert.equal(mock.stats().failed,0);
 await assert.rejects(worker.materializeCompleted({jobId}),/MATERIALIZATION_UNAVAILABLE/);
});
test('Materialization can be safely retried by internal worker with a known job id',async()=>{
 const mock=fakeDb();
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>preview(1)}});
 assert.equal((await worker.runOne()).status,'completed');
 const reread=await worker.materializeCompleted({jobId});
 assert.equal(reread.status,'materialized');
 assert.equal(reread.ledgerPosted,false);
 assert.equal(reread.flightRows,1);
});

test('Malformed flight evidence is rejected before completing immutable job',async()=>{
 const mock=fakeDb();
 const invalid=preview(1);
 invalid.flights[0].verificationSource='browser';
 const worker=createSection9DurableWorker({database:mock.database,
  previewRunner:{preview:async()=>invalid}});
 const result=await worker.runOne();
 assert.equal(result.status,'queued');
 assert.equal(mock.stats().completed,0);
 assert.equal(mock.stats().failed,1);
 assert.equal(result.code,'INVALID_SOURCE');
});
