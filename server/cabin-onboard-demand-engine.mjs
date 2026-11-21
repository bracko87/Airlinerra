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
 const rows=scenario.rows.map(row=>{
  const draw=rngFromSeed(flightEventKey+':v2:'+row.id)();
  const rate=row.mode==='included'?0.6+0.2*draw:
   row.mode==='onboard'?Math.min(.65,row.purchaseRate*(.8+.4*draw)):0;
  const lower=Math.ceil(passengers*.6),upper=Math.floor(passengers*.8);
  const rounded=Math.min(passengers,Math.round(passengers*rate));
  const consumedUnits=row.mode==='included'&&lower<=upper?
   Math.max(lower,Math.min(upper,rounded)):rounded;
  const actualSales=row.mode==='onboard'?consumedUnits:0;
  return {...row,consumedUnits,includedUnits:row.mode==='included'?consumedUnits:0,actualSales,
   airlineCostCents:consumedUnits*row.unitCostCents,
   onboardRevenueCents:actualSales*row.passengerPriceCents};
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
