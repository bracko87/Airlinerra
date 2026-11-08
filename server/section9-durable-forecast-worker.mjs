/**
 * Server-only Section 9 forecast processor.
 *
 * No player/HTTP endpoint is exposed. The future game clock must enqueue
 * authoritative in-game dates after flight activation. Processing is durable:
 * SKIP LOCKED claim, fencing token, heartbeat, bounded immutable chunks,
 * validated terminal publication. No commercial financial settlement.
 */
import {createSection9DayPreviewRunner}
 from './section9-day-preview-runner.mjs';

export const SECTION9_JOB_SQL=Object.freeze({
 enqueue:`SELECT airlinerra_game.section9_enqueue_forecast_day_v1(
  1::smallint,$1::date) AS result`,
 claim:`SELECT airlinerra_game.section9_claim_forecast_v1() AS result`,
 heartbeat:`SELECT airlinerra_game.section9_extend_forecast_lease_v1(
  $1::uuid,$2::uuid) AS result`,
 stage:`SELECT airlinerra_game.section9_stage_forecast_chunk_v1(
  $1::uuid,$2::uuid,$3::text,$4::integer,$5::jsonb) AS result`,
 complete:`SELECT airlinerra_game.section9_complete_forecast_v1(
  $1::uuid,$2::uuid,$3::integer,$4::integer) AS result`,
 materialize:`SELECT airlinerra_game.section9_materialize_completed_flights_v1(
  $1::uuid) AS result`,
 fail:`SELECT airlinerra_game.section9_fail_forecast_v1(
  $1::uuid,$2::uuid,$3::text) AS result`
});
const GAME_DAY=/^\d{4}-\d{2}-\d{2}$/;
const isGameDay=s=>typeof s==='string'&&GAME_DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const uuid=s=>typeof s==='string'&&
 /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(s);
function failureCode(error){
 const message=String(error?.message||'');
 if(/MARKET|BASELINE|SEASON/.test(message))return 'MARKET_DATA_UNAVAILABLE';
 if(/CAPACITY|SEATS|TONNE|OVERBOOK/.test(message))return 'CAPACITY_INVALID';
 if(/CONNECTION|PARTNER|AGREEMENT/.test(message))return 'CONNECTIONS_INVALID';
 if(/TIMEOUT|EXPIRED|DEADLINE/.test(message))return 'TIMEOUT';
 if(/SOURCE|INVALID_FLIGHT|UNVERIFIED|DUPLICATE_AUTHENTICATED/.test(message))
  return 'INVALID_SOURCE';
 if(/RESULT|CHUNK|INCOMPLETE/.test(message))return 'RESULT_INVALID';
 return 'INTERNAL_ERROR';
}
function validateOutput(result){
 if(!result||result.previewOnly!==true||
    result.writesToAirlineLedger!==false||
    result.authorizesFlightActivation!==false||
    result.flightActivationAllowed!==false||
    !['forecast_only','no_active_flights'].includes(result.status)||
    !Array.isArray(result.flights)||!Array.isArray(result.passengers?.markets)||
    !Array.isArray(result.cargo?.markets)||
    result.flights.length>300000||result.passengers.markets.length>100000)
  throw Error('SECTION9_RESULT_NOT_SAFE_TO_STAGE');
 const cargo=new Map(result.cargo.markets.map(m=>[m.marketId,m]));
 const pax=result.passengers.markets;
 if(new Set(pax.map(m=>m.marketId)).size!==pax.length||
    new Set(result.flights.map(f=>f.flightId)).size!==result.flights.length)
  throw Error('SECTION9_RESULT_DUPLICATE_IDENTITIES');
 const validTotals=x=>Number.isFinite(x.demand)&&Number.isFinite(x.allocated)&&
  Number.isFinite(x.unserved)&&x.demand>=0&&x.allocated>=0&&x.unserved>=0&&
  Math.abs(x.allocated+x.unserved-x.demand)<0.021;
 if(!pax.every(validTotals)||!result.cargo.markets.every(validTotals))
  throw Error('SECTION9_RESULT_MARKET_TOTALS_INVALID');
 if(pax.length!==cargo.size)throw Error('SECTION9_RESULT_MARKET_MISMATCH');
 const marketRows=pax.map(p=>{
  const c=cargo.get(p.marketId);
  if(!c)throw Error('SECTION9_RESULT_MARKET_MISMATCH');
  return {marketId:p.marketId,demand:p.demand,allocated:p.allocated,
   unserved:p.unserved,cargoDemandTonnes:c.demand,
   cargoAllocatedTonnes:c.allocated,cargoUnservedTonnes:c.unserved};
 });
 // A completed job must contain materializable evidence. Reject bad source
 // identities BEFORE publishing, since a completed job cannot be retried via
 // the ordinary queued worker.
 const physicalId=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 const date=/^\\d{4}-\\d{2}-\\d{2}$/;
 const amount=v=>typeof v==='number'&&Number.isFinite(v)&&v>=0&&
  v<=1000000000000&&Math.abs(Math.round(v*100)/100-v)<0.000001;
 for(const f of result.flights){
  if(!physicalId.test(f.scheduleId||'')||
     !physicalId.test(f.airlineId||'')||
     !Number.isInteger(f.weeklyEntry)||f.weeklyEntry<1||f.weeklyEntry>10000||
     !date.test(f.marketDate||'')||
     f.flightId!==f.scheduleId+':'+f.marketDate+':'+f.weeklyEntry||
     !Number.isSafeInteger(f.scheduleVersion)||f.scheduleVersion<1||
     !Number.isSafeInteger(f.commercialPlanVersion)||f.commercialPlanVersion<1||
     f.capacitySource!=='verified_activated_schedule'||
     typeof f.verificationSource!=='string'||f.verificationSource.length<6||
     !Number.isFinite(Date.parse(f.departureUtc||''))||
     !Number.isFinite(Date.parse(f.arrivalUtc||''))||
     Date.parse(f.arrivalUtc)<=Date.parse(f.departureUtc)||
     !amount(f.ticketRevenueUsd)||!amount(f.cargoRevenueUsd))
   throw Error('SECTION9_INVALID_VERIFIED_FLIGHT_EVIDENCE');
 }
 // Positive, bounded demand and physical-leg capacities are engine invariants.
 let occupiedSeats=0,occupiedCargo=0;
 for(const f of result.flights){
  if(typeof f.flightId!=='string'||typeof f.airlineId!=='string'||
   !Number.isSafeInteger(f.passengers)||f.passengers<0||
   !Number.isSafeInteger(f.passengerSeats)||f.passengerSeats<0||
   f.passengers>f.passengerSeats||!Number.isFinite(f.cargoTonnes)||
   f.cargoTonnes<0||!Number.isFinite(f.cargoCapacityTonnes)||
   f.cargoCapacityTonnes<0||f.cargoTonnes>f.cargoCapacityTonnes+0.001||
   !Number.isSafeInteger(f.directPassengers)||
   !Number.isSafeInteger(f.connectingPassengers)||
   f.directPassengers<0||f.connectingPassengers<0||
   f.directPassengers+f.connectingPassengers!==f.passengers||
   !Number.isFinite(f.ticketRevenueUsd)||f.ticketRevenueUsd<0||
   !Number.isFinite(f.cargoRevenueUsd)||f.cargoRevenueUsd<0)
   throw Error('SECTION9_RESULT_INVALID_FLIGHT_CAPACITY');
  occupiedSeats+=f.passengers;occupiedCargo+=f.cargoTonnes;
 }
 const servedP=pax.reduce((sum,m)=>sum+m.allocated,0);
 const servedC=result.cargo.markets.reduce((sum,m)=>sum+m.allocated,0);
 if(occupiedSeats<servedP-0.021||occupiedSeats>2*servedP+0.021||
  occupiedCargo<servedC-0.021||occupiedCargo>2*servedC+0.021)
  throw Error('SECTION9_RESULT_CONSERVATION_FAILED');
 return {flights:result.flights,markets:marketRows};
}
export function createSection9DurableWorker({database,previewRunner}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 const runner=previewRunner||createSection9DayPreviewRunner({database});
 if(typeof runner?.preview!=='function')
  throw Error('SECTION9_PREVIEW_RUNNER_REQUIRED');
 async function runSql(sql,args=[]){
  const client=await database.connect();
  try{
   const r=await client.query(sql,args);
   if(r.rowCount!==1||!r.rows?.[0]||!Object.hasOwn(r.rows[0],'result'))
    throw Error('SECTION9_JOB_DB_RESULT_UNAVAILABLE');
   return r.rows[0].result;
  }finally{client.release();}
 }
 async function enqueue({gameDate}={}){
  if(!isGameDay(gameDate))throw Error('SECTION9_INVALID_GAME_DATE');
  const result=await runSql(SECTION9_JOB_SQL.enqueue,[gameDate]);
  if(!uuid(result?.jobId))throw Error('SECTION9_ENQUEUE_UNCONFIRMED');
  return result;
 }

 async function materializeCompleted({jobId}={}){
  if(!uuid(jobId))throw Error('SECTION9_INVALID_COMPLETED_JOB_ID');
  const result=await runSql(SECTION9_JOB_SQL.materialize,[jobId]);
  if(result?.status!=='materialized'||result.bookingsCreated!==false||
   result.ledgerPosted!==false||result.storedRows!==result.forecastRows)
   throw Error('SECTION9_COMPLETED_MATERIALIZATION_UNCONFIRMED');
  return {jobId,status:'materialized',flightRows:result.storedRows,
   readOnly:true,bookingsCreated:false,ledgerPosted:false};
 }
 async function runOne(){
  const job=await runSql(SECTION9_JOB_SQL.claim);
  if(job===null)return {status:'idle',readOnly:true};
  const {jobId,leaseToken,gameDate}=job;
  if(!uuid(jobId)||!uuid(leaseToken)||!isGameDay(gameDate))
   throw Error('SECTION9_INVALID_CLAIM');
  let lastHeartbeat=Date.now();
  const heartbeat=async(force=false)=>{
   if(!force&&Date.now()-lastHeartbeat<30000)return;
   const ok=await runSql(SECTION9_JOB_SQL.heartbeat,[jobId,leaseToken]);
   if(ok!==true)throw Error('SECTION9_STALE_WORKER');
   lastHeartbeat=Date.now();
  };
  try{
   const output=await runner.preview({
    gameDate,worldId:1,onProgress:()=>heartbeat()
   });
   await heartbeat(true);
   const {flights,markets}=validateOutput(output);
   async function stage(kind,rows){
    let chunkNumber=0;
    for(let offset=0;offset<rows.length;offset+=250){
     const chunk=rows.slice(offset,offset+250);
     await runSql(SECTION9_JOB_SQL.stage,[
      jobId,leaseToken,kind,chunkNumber++,JSON.stringify(chunk)]);
     await heartbeat();
    }
   }
   await stage('flight',flights);
   await stage('market',markets);
   await heartbeat(true);
   const published=await runSql(SECTION9_JOB_SQL.complete,[
    jobId,leaseToken,flights.length,markets.length]);
   if(published?.status!=='completed'||published.bookingsCreated!==false||
    published.ledgerPosted!==false)
    throw Error('SECTION9_JOB_COMPLETION_UNCONFIRMED');
   // Publication and normalization are independent. A crash here does not
   // lose the completed job; an operator/worker can safely call
   // materializeCompleted again, but we must NOT claim it is ready meanwhile.
   try{
    const materialized=await materializeCompleted({jobId});
    if(materialized.flightRows!==flights.length)
     throw Error('SECTION9_COMPLETED_MATERIALIZATION_ROW_MISMATCH');
   }catch{
    return {status:'completed_materialization_pending',jobId,gameDate,
     flightRows:flights.length,marketRows:markets.length,
     bookingsCreated:false,ledgerPosted:false,readOnly:true};
   }
   return {status:'completed',jobId,gameDate,
    flightRows:flights.length,marketRows:markets.length,
    bookingsCreated:false,ledgerPosted:false,readOnly:true};
  }catch(error){
   // Never report success if a worker's lease expired or the database lost
   // the connection; a subsequent worker will retry after the lease.
   let report=null;
   try{
    report=await runSql(SECTION9_JOB_SQL.fail,[
     jobId,leaseToken,failureCode(error)]);
   }catch{/* stale worker or database outage; recovery is lease-based */}
   return {status:report?.status||'retry_after_lease',
    jobId,gameDate,attempt:job.attempt,
    code:failureCode(error),readOnly:true};
  }
 }
 return Object.freeze({enqueue,runOne,materializeCompleted});
}
