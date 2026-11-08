/**
 * Section 9: read-only multi-date demand reconciliation.
 *
 * Unlike running three separate market-day simulations (which can each fill
 * the same connecting aircraft independently), this function builds ONE
 * shared physical-flight inventory for every supplied origin-day market.
 * Each traveller occupies one seat per leg and never two traveller pools.
 *
 * It is a forecast, NOT a ticket booking or an authoritative settlement.
 * The game clock must later reserve per-occurrence inventory atomically.
 */
import {
 section9SimulateDay,section9DiscoverReachableMarkets
} from './section9-network-demand-engine.mjs';

const ISO_DAY=/^\d{4}-\d{2}-\d{2}$/;
const validDate=d=>typeof d==='string'&&ISO_DAY.test(d)&&
 Number.isFinite(Date.parse(d+'T00:00:00Z'))&&
 new Date(d+'T00:00:00Z').toISOString().slice(0,10)===d;
const nextDay=d=>new Date(Date.parse(d+'T00:00:00Z')+86400000)
 .toISOString().slice(0,10);
function checkWindow(dates){
 if(!Array.isArray(dates)||dates.length<2||dates.length>7||
    !dates.every(validDate))throw Error('SECTION9_INVALID_SHARED_WINDOW');
 for(let i=1;i<dates.length;i++){
  if(dates[i]!==nextDay(dates[i-1]))
   throw Error('SECTION9_WINDOW_DAYS_NOT_CONTIGUOUS');
 }
}
const sum=(rows,field)=>rows.reduce((v,r)=>v+(Number(r[field])||0),0);
const account=(result,markets,flights)=>{
 const byDate={};
 const marketMeta=new Map(markets.map(m=>[m.id,m.marketDate]));
 for(const day of [...new Set(markets.map(m=>m.marketDate))])byDate[day]={
  marketCount:0,passengersDemand:0,passengersAllocated:0,
  cargoDemandTonnes:0,cargoAllocatedTonnes:0
 };
 for(const p of result.passengers.markets){
  const day=marketMeta.get(p.marketId);
  if(!day||!byDate[day])throw Error('SECTION9_UNKNOWN_ALLOCATED_MARKET');
  byDate[day].marketCount++;
  byDate[day].passengersDemand+=p.demand;
  byDate[day].passengersAllocated+=p.allocated;
 }
 for(const c of result.cargo.markets){
  const day=marketMeta.get(c.marketId);
  if(!day||!byDate[day])throw Error('SECTION9_UNKNOWN_CARGO_MARKET');
  byDate[day].cargoDemandTonnes+=c.demand;
  byDate[day].cargoAllocatedTonnes+=c.allocated;
 }
 const capacity=new Map(flights.map(f=>[f.id,{
  seats:f.passengerSeats,cargo:f.cargoTonnes
 }]));
 if(capacity.size!==flights.length)throw Error('SECTION9_DUPLICATE_OCCURRENCE');
 for(const f of result.flights){
  const cap=capacity.get(f.flightId);
  if(!cap||f.passengers>cap.seats||f.cargoTonnes>cap.cargo+0.000001)
   throw Error('SECTION9_SHARED_WINDOW_OVERBOOKING');
 }
 const totalAllocated=sum(result.passengers.markets,'allocated');
 const totalLegSeats=sum(result.flights,'passengers');
 if(totalLegSeats<totalAllocated||totalLegSeats>2*totalAllocated)
  throw Error('SECTION9_SHARED_WINDOW_PASSENGER_CONSERVATION');
 const totalCargo=sum(result.cargo.markets,'allocated');
 const totalLegCargo=sum(result.flights,'cargoTonnes');
 if(totalLegCargo+0.001<totalCargo||totalLegCargo>2*totalCargo+0.001)
  throw Error('SECTION9_SHARED_WINDOW_CARGO_CONSERVATION');
 return byDate;
}
export function section9SimulateSharedWindow({
 marketDates,flights=[],markets=[],airports={},agreements=[],
 holdingGroups={},maxItinerariesPerMarket=10000
}={}){
 checkWindow(marketDates);
 if(!Array.isArray(markets)||!Array.isArray(flights)||flights.length>300000||
    markets.length>100000)throw Error('SECTION9_SHARED_WINDOW_REQUIRES_SHARDING');
 const allowedDays=new Set(marketDates);
 for(const m of markets){
  if(!allowedDays.has(m.marketDate))
   throw Error('SECTION9_MARKET_OUTSIDE_SHARED_WINDOW');
 }
 const result=section9SimulateDay({
  flights,markets,airports,agreements,holdingGroups,maxItinerariesPerMarket
 });
 const marketDays=account(result,markets,flights);
 return {
  ...result,version:'section9_shared_window_v1',
  window:{marketDates:[...marketDates],marketDayTotals:marketDays,
   sharedPhysicalInventory:true,
   allMarketDatesAllocatedTogether:true,
   exactlyOnePhysicalFlightInventory:true},
  settlementAuthority:false,bookingsCreated:false,
  ledgerPosted:false,marketingCharged:false,
  status:'read_only_global_capacity_preview'
 };
}
/** Discover all real direct or one-stop destination markets for the requested
 * date range. Each distinct market-day is modeled only once.
 */
export function section9DiscoverSharedWindowPairs({
 marketDates,flights,airports={},agreements=[],holdingGroups={},
 maxPairs=100000
}={}){
 checkWindow(marketDates);
 if(!Number.isInteger(maxPairs)||maxPairs<1||maxPairs>100000)
  throw Error('SECTION9_INVALID_DISCOVERY_LIMIT');
 const seen=new Set(),groups=[],pairs=[];
 for(const day of marketDates){
  const result=section9DiscoverReachableMarkets({
   flights,airports,agreements,holdingGroups,marketDate:day,
   maxMarketPairs:maxPairs
  });
  const list=[];
  for(const p of result.pairs){
   const k=day+'|'+p.origin+'|'+p.destination;
   if(seen.has(k))throw Error('SECTION9_DUPLICATE_MARKET_DATE_PAIR');
   seen.add(k);
   if(seen.size>maxPairs)throw Error('SECTION9_WINDOW_TOO_MANY_MARKETS_SHARD_REQUIRED');
   list.push(p);pairs.push({...p,marketDate:day});
  }
  groups.push({marketDate:day,pairs:list,
   candidateConnectionsExamined:result.diagnostics.candidateConnectionsExamined});
 }
 return {groups,pairs,count:pairs.length,
  sharedPhysicalInventoryRequired:true};
}
