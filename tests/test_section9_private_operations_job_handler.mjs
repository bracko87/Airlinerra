import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9AircraftOperationsJobHandler,
 flightOperationsReleaseIsReady,
 SECTION9_WORKER_RELEASE_SQL}
 from '../server/section9-aircraft-operations-job-handler.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const token='world1-production-worker-token-test-123456789abcdef';
const approved={
 world_id:1,world_state:'active',
 authoritative_clock_connected:true,clock_producer_configured:true,
 clock_producer_enabled:true,active_flight_schedules:1,
 operational_certification_records:6,
 trusted_flight_execution_release:'RELEASED',
 fuel_transaction_release:'NOT_ACTIVATED',
 automatic_flight_and_fuel_settlement_enabled:false
};
const request=(method='POST',body='{}',sentToken=token)=>new Request(
 'https://private.invalid/worker',{method,
 headers:{'x-airlinerra-operations-job-token':sentToken},
 ...(['GET','HEAD'].includes(method)?{}:{body})});
const make=(row,runBatch)=>({
 worker:{runBatch},database:{connect:async()=>({
  query:async(sql)=>{
   assert.equal(sql,SECTION9_WORKER_RELEASE_SQL.readiness);
   return row?{rowCount:1,rows:[row]}:{rowCount:0,rows:[]};
  },release(){}
 })},jobToken:token
});
test('new World 1 audit blocks flight worker even when schedule count is positive',()=>{
 const values=[
  null,{...approved,authoritative_clock_connected:false},
  {...approved,clock_producer_enabled:false},
  {...approved,active_flight_schedules:0},
  {...approved,operational_certification_records:0},
  {...approved,trusted_flight_execution_release:'NOT_ACTIVATED'},
  {...approved,fuel_transaction_release:'RELEASED'},
  {...approved,automatic_flight_and_fuel_settlement_enabled:true},
  {...approved,world_id:2}
 ];
 for(const r of values)assert.equal(flightOperationsReleaseIsReady(r),false);
 assert.equal(flightOperationsReleaseIsReady(approved),true);
});
test('blocked official release calls no aircraft jobs at all',async()=>{
 let invoked=0;
 const f=createSection9AircraftOperationsJobHandler(make({
  ...approved,trusted_flight_execution_release:'NOT_ACTIVATED'
 },async()=>{invoked++;throw Error('SHOULD_NOT_CALL')}));
 const response=await f(request());
 assert.equal(response.status,423);
 assert.equal((await response.json()).status,'flight_operations_release_blocked');
 assert.equal(invoked,0);
});
test('missing clock and no schedules blocks even with hypothetical release',async()=>{
 let invoked=0;
 const f=createSection9AircraftOperationsJobHandler(make({
  ...approved,authoritative_clock_connected:false,active_flight_schedules:0
 },async()=>{invoked++;throw Error('MUST_BLOCK')}));
 assert.equal((await f(request())).status,423);
 assert.equal(invoked,0);
});
test('no browser user-selected airline, game time or batch size accepted',async()=>{
 let queried=0;
 const f=createSection9AircraftOperationsJobHandler({
  ...make(approved,async()=>({})),
  database:{connect:async()=>{queried++;throw Error('NO_DB_SHOULD_BE_READ')}}
 });
 assert.equal((await f(request('POST','{"gameDate":"2026-11-11"}'))).status,400);
 assert.equal((await f(request('GET'))).status,405);
 assert.equal((await f(request('POST','{}','wrong-token'))).status,401);
 assert.equal(queried,0);
});
test('released authenticated worker uses bounded batch, never reports fuel or cash writes',async()=>{
 let runs=0;
 const f=createSection9AircraftOperationsJobHandler(make(approved,async({maxJobs})=>{
  runs++;assert.equal(maxJobs,20);
  return {status:'bounded_batch_completed',jobsClaimed:1,
   completed:1,queued:0,failed:0,flightActivated:false};
 }));
 const r=await f(request());
 assert.equal(r.status,200);
 assert.equal(runs,1);
 const body=await r.json();
 assert.equal(body.ledgerPosted,false);
 assert.equal(body.bookingsCreated,false);
});
test('inconsistent worker accounting result fails closed',async()=>{
 const bad=[
  {jobsClaimed:2,completed:1,queued:0,failed:0},
  {jobsClaimed:1,completed:1,queued:-1,failed:1},
  {jobsClaimed:21,completed:21,queued:0,failed:0}
 ];
 for(const data of bad){
  const f=createSection9AircraftOperationsJobHandler(make(approved,
   async()=>({status:'bounded_batch_completed',...data,flightActivated:false})));
  assert.equal((await f(request())).status,503);
 }
});
test('deployed edge entry requires four independent permissions and has no automatic scheduler',async()=>{
 const source=await read('server/section9-aircraft-operations-edge-entry.ts');
 for(const key of ['AIRLINERRA_FLIGHT_OPERATIONS_DEPLOYMENT_APPROVED',
  'AIRLINERRA_FLIGHT_OPERATIONS_JOB_TOKEN',
  'AIRLINERRA_INDEPENDENT_FLIGHT_ATTESTATION_SECRET',
  'AIRLINERRA_OPERATED_FLIGHT_ENGINE_SECRET','SUPABASE_DB_URL']){
  assert.ok(source.includes(key),key);
 }
 assert.match(source,/INDEPENDENT_SECRET!==MOVEMENT_SECRET/);
 assert.match(source,/flight_operations_not_released/);
 assert.match(source,/createSection9AircraftOperationsWorker/);
 assert.match(source,/createSection9IndependentOperationEvidenceReader/);
 assert.doesNotMatch(source,/cron\.schedule|Deno\.cron|setInterval/);
});
