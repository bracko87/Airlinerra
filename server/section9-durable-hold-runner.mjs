/**
 * Section 9 - durable private capacity-hold plans.
 *
 * Source: ONLY server-derived shared-calendar demand using verified flight
 * occurrences, real market demand and signed interline agreements.
 *
 * stage(): save immutable plan in SQL batches, restartable from any chunk.
 * processNext(): one bounded SQL function/transaction. The batch's physical
 * holds and progress checkpoint commit together or roll back together.
 *
 * No live passenger ticket, revenue, marketing payment or cash movement.
 * No autonomous game clock is enabled here.
 */
import {createHash} from 'node:crypto';
import {createSection9SharedWindowRunner} from './section9-shared-window-runner.mjs';
import {section9ValidateHoldPreview}
 from './section9-atomic-hold-runner.mjs';

export const SECTION9_DURABLE_HOLD_SQL=Object.freeze({
 create:`SELECT airlinerra_game.section9_create_hold_plan_v1(
  $1::date,$2::integer,$3::text,$4::integer) AS result`,
 stage:`SELECT airlinerra_game.section9_stage_hold_plan_chunk_v1(
  $1::uuid,$2::jsonb) AS result`,
 seal:`SELECT airlinerra_game.section9_seal_hold_plan_v1(
  $1::uuid) AS result`,
 process:`SELECT airlinerra_game.section9_apply_hold_plan_batch_v1(
  $1::uuid,$2::integer) AS result`
});
const DAY=/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const boundedInt=(n,min,max)=>Number.isInteger(n)&&n>=min&&n<=max;
const readonlySafety=r=>r?.preflightOnly===true&&
 r?.bookingsCreated===false&&r?.ledgerPosted===false;
function canonicalPlan(result,allocations,flights,startGameDate,marketDays){
 const normalized=allocations.map((a,sequence)=>({
  sequence,
  allocationKey:a.allocationKey,
  flightIds:a.flightIds,
  passengers:a.passengers,
  cargoTonnes:Math.round(a.cargoTonnes*1000)/1000
 }));
 if(normalized.length>100000)throw Error('SECTION9_HOLD_PLAN_TOO_LARGE');
 const proofFlights=[...flights.values()].map(f=>[
   f.flightId,f.scheduleVersion,f.commercialPlanVersion,
   f.passengerSeats,f.cargoCapacityTonnes,f.passengers,
   Math.round(f.cargoTonnes*1000)/1000
 ]).sort((a,b)=>a[0].localeCompare(b[0]));
 const paxMarkets=[...result.passengers.markets].sort(
  (a,b)=>a.marketId.localeCompare(b.marketId));
 const cargoMarkets=[...result.cargo.markets].sort(
  (a,b)=>a.marketId.localeCompare(b.marketId));
 // Hash all source provenance, not merely allocation keys. A changed
 // demand estimate, aircraft version or price plan cannot reuse this job.
 const digest=createHash('sha256');
 for(const segment of [
  ['section9_shared_hold_manifest_v1',startGameDate,marketDays],
  proofFlights,paxMarkets,cargoMarkets,normalized
 ])digest.update(JSON.stringify(segment)).update('\n');
 return {manifestSha256:digest.digest('hex'),allocations:normalized};
}
async function runSql(client,statement,params){
 const reply=await client.query(statement,params);
 if(reply.rowCount!==1||!reply.rows?.[0]||
    !Object.hasOwn(reply.rows[0],'result')||
    !reply.rows[0].result)
  throw Error('SECTION9_DURABLE_HOLD_DATABASE_UNAVAILABLE');
 return reply.rows[0].result;
}
export function createSection9DurableHoldRunner({database,sharedRunner}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 const source=sharedRunner||createSection9SharedWindowRunner({database});
 if(typeof source?.preview!=='function')
  throw Error('SECTION9_VERIFIED_SHARED_WINDOW_REQUIRED');
 return Object.freeze({
  async stage({startGameDate,marketDays=3,chunkSize=75}={}){
   if(!validDay(startGameDate)||!boundedInt(marketDays,2,7)||
      !boundedInt(chunkSize,1,100))
    throw Error('SECTION9_INVALID_DURABLE_HOLD_STAGE');
   const preview=await source.preview({startGameDate,marketDays});
   if(preview.status==='no_active_flights')return {
    status:'blocked_no_active_flights',preflightOnly:true,
    bookingsCreated:false,ledgerPosted:false,allocations:0
   };
   const {allocations,flights}=section9ValidateHoldPreview(preview);
   if(!Array.isArray(preview.passengers?.markets)||
      !Array.isArray(preview.cargo?.markets))
    throw Error('SECTION9_DURABLE_HOLD_MARKET_PROOF_MISSING');
   const manifest=canonicalPlan(preview,allocations,flights,
    startGameDate,marketDays);
   const client=await database.connect();
   try{
    const created=await runSql(client,SECTION9_DURABLE_HOLD_SQL.create,[
     startGameDate,marketDays,manifest.manifestSha256,allocations.length]);
    if(!readonlySafety(created)||!UUID.test(created.planId)||
       created.expected!==allocations.length)
     throw Error('SECTION9_UNTRUSTED_DURABLE_PLAN_RESPONSE');
    if(created.status==='staging'){
     for(let i=0;i<manifest.allocations.length;i+=chunkSize){
      const chunk=manifest.allocations.slice(i,i+chunkSize);
      const stage=await runSql(client,SECTION9_DURABLE_HOLD_SQL.stage,
       [created.planId,JSON.stringify(chunk)]);
      if(!readonlySafety(stage)||stage.status!=='staged'||
        stage.received!==chunk.length)
       throw Error('SECTION9_UNTRUSTED_STAGING_RESPONSE');
     }
     const seal=await runSql(client,SECTION9_DURABLE_HOLD_SQL.seal,
      [created.planId]);
     if(!readonlySafety(seal)||
       !['ready','completed'].includes(seal.status)||
       seal.expected!==manifest.allocations.length)
      throw Error('SECTION9_HOLD_PLAN_NOT_SEALED');
     return {status:seal.status,planId:created.planId,
      allocationCount:allocations.length,manifestSha256:manifest.manifestSha256,
      nextSequence:0,preflightOnly:true,
      bookingsCreated:false,ledgerPosted:false};
    }
    if(!['ready','completed'].includes(created.status)||
      !boundedInt(created.nextSequence,0,allocations.length))
     throw Error('SECTION9_HOLD_PLAN_UNEXPECTED_STATUS');
    return {status:created.status,planId:created.planId,
     allocationCount:allocations.length,nextSequence:created.nextSequence,
     manifestSha256:manifest.manifestSha256,preflightOnly:true,
     bookingsCreated:false,ledgerPosted:false};
   }finally{client.release();}
  },
  async processNext({planId,batchSize=50}={}){
   if(!UUID.test(planId||'')||!boundedInt(batchSize,1,100))
    throw Error('SECTION9_INVALID_DURABLE_HOLD_PROCESS');
   const client=await database.connect();
   try{
    const value=await runSql(client,SECTION9_DURABLE_HOLD_SQL.process,
     [planId,batchSize]);
    if(!readonlySafety(value)||value.planId!==planId||
       !['ready','completed','busy_or_unknown','not_ready'].includes(value.status))
     throw Error('SECTION9_UNSAFE_HOLD_BATCH_RESULT');
    if(['ready','completed'].includes(value.status)){
     if(!boundedInt(value.processed,0,batchSize)||
       !boundedInt(value.expected,0,100000)||
       !boundedInt(value.nextSequence,0,value.expected))
      throw Error('SECTION9_INCONSISTENT_HOLD_BATCH_PROGRESS');
     if(value.status==='completed'&&value.nextSequence!==value.expected)
      throw Error('SECTION9_PREMATURE_HOLD_PLAN_COMPLETION');
    }
    return value;
   }finally{client.release();}
  },
  async processBounded({planId,batchSize=50,maxBatches=10}={}){
   if(!boundedInt(maxBatches,1,20))
    throw Error('SECTION9_INVALID_BATCH_BUDGET');
   let processed=0;
   for(let i=0;i<maxBatches;i++){
    const step=await this.processNext({planId,batchSize});
    processed+=step.processed||0;
    if(step.status!=='ready')return {
     ...step,processedThisRun:processed,batches:i+1
    };
   }
   return {status:'more_batches_required',planId,processedThisRun:processed,
    batches:maxBatches,preflightOnly:true,
    bookingsCreated:false,ledgerPosted:false};
  }
 });
}
