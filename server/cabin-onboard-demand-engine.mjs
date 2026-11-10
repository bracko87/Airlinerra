/**
 * Airlinerra onboard sales — deterministic game simulation core.
 *
 * PREPARATORY / NOT DEPLOYED AS A FLIGHT EXECUTOR.
 * This function never reads a DB, sends a payment, updates inventory, or
 * posts income. The trusted flight worker must supply the actual passenger
 * count, verified flight duration, airline reputation and a unique flight
 * event key, and post a single idempotent transaction separately.
 */
import {forecastCabinServiceFlight} from '../website/cabin-services-manager.mjs';

/** Portable 32-bit FNV-1a seed; never dependent on current clock or browser. */
const hashSeed=text=>{
 let hash=2166136261>>>0;
 for(let i=0;i<text.length;i++){hash^=text.charCodeAt(i);hash=Math.imul(hash,16777619)>>>0;}
 return hash||0x9e3779b9;
};
const rngFromSeed=key=>{
 let state=hashSeed(key);
 return ()=>{
  state^=state<<13;state^=state>>>17;state^=state<<5;
  return (state>>>0)/4294967296;
 };
};

/** Pure read-only result: quantities actually drawn by the game engine. */
export function simulateCabinOnboardPurchases(pkg,{flightEventKey,passengers,
 durationMinutes,reputationScore}={}){
 if(typeof flightEventKey!=='string'||!/^[-A-Za-z0-9:_]{8,150}$/.test(flightEventKey))
  throw Error('Unique verified flight event key required');
 const scenario=forecastCabinServiceFlight(pkg,{passengers,durationMinutes,reputationScore});
 const nextRandom=rngFromSeed(flightEventKey);
 const rows=scenario.rows.map(row=>{
  if(row.mode!=='onboard')return {...row,actualSales:0};
  let wants=0;
  for(let p=0;p<passengers;p++)if(nextRandom()<row.purchaseRate)wants++;
  const isDigital=['newspaper','wifi','fullwifi','entertainment'].includes(row.id);
  // Digital services have no physical units; all other products need stock.
  const actualSales=Math.min(wants,isDigital?passengers:row.loadedUnits);
  const unitCostCents=row.unitCostCents;
  const airlineCostCents=isDigital?actualSales*unitCostCents:row.airlineCostCents;
  return {...row,actualSales,airlineCostCents,
   onboardRevenueCents:actualSales*row.passengerPriceCents,
   unsoldUnits:isDigital?0:row.loadedUnits-actualSales};
 });
 const totalCostCents=rows.reduce((a,r)=>a+r.airlineCostCents,0);
 const onboardRevenueCents=rows.reduce((a,r)=>a+r.onboardRevenueCents,0);
 return Object.freeze({
  flightEventKey,passengers,durationMinutes,reputationScore,
  attractiveness:scenario.attractiveness,paidBonus:scenario.paidBonus,
  totalCostCents,onboardRevenueCents,netCostCents:totalCostCents-onboardRevenueCents,
  rows,
  simulated:true,transactionPosted:false,inventoryWritten:false,
  passengerBookingsCreated:false
 });
}
