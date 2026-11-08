/**
 * Internal, fail-closed Section 9 itinerary capacity preflight.
 *
 * Input comes exclusively from the server-verified multi-date demand
 * simulation. It does NOT create passenger tickets, charge marketing,
 * credit airline accounts, or authorize a new operating flight.
 *
 * Each physical flight is registered from private DB aircraft/schedule
 * evidence; PostgreSQL locks reserve both connection legs atomically.
 */
import {createHash} from 'node:crypto';
import {createSection9SharedWindowRunner} from './section9-shared-window-runner.mjs';

export const SECTION9_ATOMIC_HOLD_SQL=Object.freeze({
 init:`SELECT airlinerra_game.section9_initialize_verified_occurrence_v1(
  $1::uuid,$2::date,$3::integer) AS result`,
 hold:`SELECT airlinerra_game.section9_hold_verified_itinerary_v1(
  $1::text,$2::text[],$3::integer,$4::numeric) AS result`
});
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const signedProof=r=>r?.status==='read_only_global_capacity_preview'&&
 r?.version==='section9_shared_window_v1'&&
 r?.source==='verified_operational_schedules'&&
 r?.settlementAuthority===false&&r?.bookingsCreated===false&&
 r?.ledgerPosted===false&&r?.previewOnly===true&&
 r?.window?.sharedPhysicalInventory===true;
const near=(a,b)=>Math.abs(a-b)<0.000001;
export function section9ValidateHoldPreview(result){
 if(!signedProof(result)||!Array.isArray(result.flights)||
  !Array.isArray(result.passengers?.allocations)||
  !Array.isArray(result.cargo?.allocations))
  throw Error('SECTION9_ATOMIC_HOLD_UNTRUSTED_PREVIEW');
 const flights=new Map();
 for(const f of result.flights){
  if(!UUID.test(f?.scheduleId||'')||!UUID.test(f?.airlineId||'')||
   !validDay(f.marketDate)||
   !Number.isInteger(f.weeklyEntry)||f.weeklyEntry<1||f.weeklyEntry>10000||
   f.flightId!==f.scheduleId+':'+f.marketDate+':'+f.weeklyEntry||
   !Number.isInteger(f.scheduleVersion)||f.scheduleVersion<1||
   !Number.isInteger(f.commercialPlanVersion)||f.commercialPlanVersion<1||
   f.capacitySource!=='verified_activated_schedule'||
   typeof f.verificationSource!=='string'||f.verificationSource.length<6||
   !Number.isSafeInteger(f.passengers)||f.passengers<0||
   !Number.isSafeInteger(f.passengerSeats)||f.passengers>f.passengerSeats||
   typeof f.cargoTonnes!=='number'||!Number.isFinite(f.cargoTonnes)||
   f.cargoTonnes<0||f.cargoTonnes>f.cargoCapacityTonnes+0.000001)
   throw Error('SECTION9_ATOMIC_HOLD_UNVERIFIED_FLIGHT');
  if(flights.has(f.flightId))throw Error('SECTION9_ATOMIC_HOLD_DUPLICATE_FLIGHT');
  flights.set(f.flightId,f);
 }
 const joined=new Map();
 for(const [kind,allocations] of [
  ['passenger',result.passengers.allocations],
  ['cargo',result.cargo.allocations]]){
  for(const a of allocations){
   if(typeof a.marketId!=='string'||!a.marketId||
    typeof a.offerId!=='string'||!a.offerId||
    !Array.isArray(a.flightIds)||a.flightIds.length<1||
    a.flightIds.length>2||new Set(a.flightIds).size!==a.flightIds.length||
    a.flightIds.some(id=>!flights.has(id))||
    typeof a.allocated!=='number'||!Number.isFinite(a.allocated)||
    a.allocated<=0)
    throw Error('SECTION9_ATOMIC_HOLD_INVALID_ALLOCATION');
   const key=JSON.stringify([a.marketId,a.offerId]);
   let r=joined.get(key);
   if(!r){
    r={marketId:a.marketId,offerId:a.offerId,flightIds:[...a.flightIds],
     passengers:0,cargoTonnes:0};
    joined.set(key,r);
   }
   if(JSON.stringify(r.flightIds)!==JSON.stringify(a.flightIds)||
    (kind==='passenger'&&r.passengers>0)||
    (kind==='cargo'&&r.cargoTonnes>0))
    throw Error('SECTION9_ATOMIC_HOLD_ALLOCATION_CONFLICT');
   if(kind==='passenger'){
    if(!Number.isSafeInteger(a.allocated)||a.allocated>1000)
     throw Error('SECTION9_ATOMIC_HOLD_INVALID_PASSENGERS');
    r.passengers=a.allocated;
   }else{
    if(a.allocated>1000||!near(Math.round(a.allocated*1000)/1000,a.allocated))
     throw Error('SECTION9_ATOMIC_HOLD_INVALID_CARGO');
    r.cargoTonnes=a.allocated;
   }
  }
 }
 if(joined.size>100000)throw Error('SECTION9_ATOMIC_HOLD_REQUIRES_SHARDING');
 const perLeg=new Map();
 const output=[...joined.values()].sort((a,b)=>
  JSON.stringify([a.marketId,a.offerId]).localeCompare(
   JSON.stringify([b.marketId,b.offerId])));
 for(const a of output){
  const key='s9g1:'+createHash('sha256').update(
   JSON.stringify([a.marketId,a.offerId,a.flightIds])).digest('hex');
  a.allocationKey=key;
  for(const id of a.flightIds){
   const used=perLeg.get(id)||{pax:0,cargo:0};
   used.pax+=a.passengers;used.cargo+=a.cargoTonnes;
   perLeg.set(id,used);
  }
 }
 for(const [id,usage] of perLeg){
  const f=flights.get(id);
  if(usage.pax>f.passengers||!near(usage.cargo,f.cargoTonnes))
   throw Error('SECTION9_ATOMIC_HOLD_ALLOCATION_USAGE_CONFLICT');
 }
 // A direct or connecting leg with no allocations needs no hold.
 for(const f of flights.values()){
  const usage=perLeg.get(f.flightId);
  if((usage?.pax||0)!==f.passengers||
     !near(usage?.cargo||0,f.cargoTonnes))
   throw Error('SECTION9_ATOMIC_HOLD_ALLOCATION_USAGE_MISMATCH');
 }
 return {allocations:output,flights};
}
export function createSection9AtomicHoldRunner({database,sharedRunner}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 const source=sharedRunner||createSection9SharedWindowRunner({database});
 if(typeof source.preview!=='function')
  throw Error('SECTION9_VERIFIED_SHARED_RUNNER_REQUIRED');
 async function runSql(client,sql,args){
  const reply=await client.query(sql,args);
  if(reply.rowCount!==1||!reply.rows?.[0]?.result)
   throw Error('SECTION9_ATOMIC_HOLD_DATABASE_UNAVAILABLE');
  return reply.rows[0].result;
 }
 return Object.freeze({
  async prepare({startGameDate,marketDays=3,maxAllocations=250}={}){
   if(!validDay(startGameDate)||!Number.isInteger(marketDays)||
     marketDays<2||marketDays>7||!Number.isInteger(maxAllocations)||
     maxAllocations<1||maxAllocations>250)
    throw Error('SECTION9_INVALID_ATOMIC_HOLD_RUN');
   const result=await source.preview({startGameDate,marketDays});
   if(result.status==='no_active_flights')return {
    status:'blocked_no_active_flights',readOnly:true,
    bookingsCreated:false,ledgerPosted:false,holds:0};
   const {allocations,flights}=section9ValidateHoldPreview(result);
   if(allocations.length>maxAllocations)
    return {status:'requires_batched_durable_allocation_job',readOnly:true,
     allocations:allocations.length,holds:0,bookingsCreated:false,ledgerPosted:false};
   const client=await database.connect();
   let holds=0,replayed=0;
   try{
    const flightIds=[...new Set(allocations.flatMap(a=>a.flightIds))].sort();
    for(const id of flightIds){
     const f=flights.get(id);
     const response=await runSql(client,SECTION9_ATOMIC_HOLD_SQL.init,
      [f.scheduleId,f.marketDate,f.weeklyEntry]);
     if(response.status!=='capacity_preflight_initialized'||
       response.physicalFlightId!==f.flightId||
       response.bookingsCreated!==false||response.ledgerPosted!==false)
      throw Error('SECTION9_UNVERIFIED_INVENTORY_RESPONSE');
    }
    for(const a of allocations){
     const response=await runSql(client,SECTION9_ATOMIC_HOLD_SQL.hold,
      [a.allocationKey,a.flightIds,a.passengers,a.cargoTonnes]);
     if(response.status!=='preflight_held'||response.bookingsCreated!==false||
       response.ledgerPosted!==false)
      throw Error('SECTION9_UNSAFE_CAPACITY_HOLD_RESPONSE');
     if(response.replayed===true)replayed++;else holds++;
    }
    return {status:'preflight_capacity_held',readOnly:true,
     holds,replayed,bookingsCreated:false,ledgerPosted:false,
     allocationAuthority:false,settlementAuthority:false};
   }finally{client.release();}
  }
 });
}
