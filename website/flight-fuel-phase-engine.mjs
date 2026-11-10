/** Airlinerra FIVE-PHASE fuel planning V1: forecast only, no financial writes.
 * The factors below are explicit GAME BALANCING ASSUMPTIONS, not OEM performance.
 * A legacy kg/100km rate is a whole-MISSION estimate: it is calibrated on a
 * 1,000-km reference flight, not blindly added to five more fuel burns.
 * Research: EUROCONTROL Standard Inputs edition 10; ICAO LTO reference.
 */
export const FUEL_PHASE_MODEL_VERSION='airlinerra_fuel_phases_preview_v1';
export const DEFAULT_FUEL_GAME_PRICE_USD_PER_KG=0.95; // Group 3 historical game assumption, NOT a quote
export const PHASE_SETTINGS=Object.freeze({
 taxiOut:{minutes:15,factor:.25},climb:{minutes:20,factor:1.35,speedFactor:.65},
 cruise:{factor:1},descent:{minutes:20,factor:.52,speedFactor:.65},
 taxiIn:{minutes:10,factor:.22}
});
const finitePositive=x=>{
 if(x===null||x===undefined||x==='')return null;
 const n=Number(x);return Number.isFinite(n)&&n>0?n:null;
};
const bounded=(x,min,max)=>Math.min(max,Math.max(min,x));
const rounded=x=>Math.round(x*100)/100;
const CODES=[['taxiOut','Taxi out'],['climb','Takeoff and climb'],['cruise','Cruise'],
 ['descent','Descent and landing'],['taxiIn','Taxi in']];
const flightProfile=(distanceKm,speedKmh)=>{
 const climbKm=(PHASE_SETTINGS.climb.minutes/60)*speedKmh*PHASE_SETTINGS.climb.speedFactor;
 const descentKm=(PHASE_SETTINGS.descent.minutes/60)*speedKmh*PHASE_SETTINGS.descent.speedFactor;
 // No negative cruise on short flights. Compress both climb/descent equally.
 const scale=Math.min(1,distanceKm/(climbKm+descentKm));
 const climb=PHASE_SETTINGS.climb.minutes*scale;
 const descent=PHASE_SETTINGS.descent.minutes*scale;
 const cruiseKm=Math.max(0,distanceKm-(climbKm+descentKm)*scale);
 const cruise=cruiseKm/speedKmh*60;
 return [
  {key:'taxiOut',minutes:15,distanceKm:0},
  {key:'climb',minutes:climb,distanceKm:climbKm*scale},
  {key:'cruise',minutes:cruise,distanceKm:cruiseKm},
  {key:'descent',minutes:descent,distanceKm:descentKm*scale},
  {key:'taxiIn',minutes:10,distanceKm:0}
 ];
};
const rateForLoad=(data,loadFraction)=>{
 const empty=finitePositive(data.emptyFuelKgPer100Km);
 const half=finitePositive(data.halfFuelKgPer100Km);
 const full=finitePositive(data.fullFuelKgPer100Km);
 if(full===null)return null;
 if(loadFraction<=.5&&empty!==null){
  const mid=half??((empty+full)/2);
  return empty+(mid-empty)*(loadFraction/.5);
 }
 if(half!==null)return half+(full-half)*((loadFraction-.5)/.5);
 return full*(.86+.14*loadFraction); // fallback assumption explicitly tagged
};
/** Read-only benchmark: phase rates are modelled from actual catalog model inputs.
 * referenceMissionKm=1000 anchors LEGACY mission fuel rates to the whole trip.
 * payloadFraction is estimated passenger/cargo utilization, not a verified load sheet.
 */
export function estimateFivePhaseFuel({
 distanceKm,cruiseSpeedKmh,cruiseFuelKgPerHour=null,
 emptyFuelKgPer100Km=null,halfFuelKgPer100Km=null,fullFuelKgPer100Km=null,
 fuelTankCapacityKg=null,payloadFraction=.5,
 priceUsdPerKg=DEFAULT_FUEL_GAME_PRICE_USD_PER_KG,
 routingMultiplier=1,referenceMissionKm=1000
}={}){
 const distance=finitePositive(distanceKm),speed=finitePositive(cruiseSpeedKmh);
 const tank=finitePositive(fuelTankCapacityKg),hourly=finitePositive(cruiseFuelKgPerHour);
 const loaded=Number(payloadFraction),price=priceUsdPerKg===null?null:Number(priceUsdPerKg);
 if(distance===null||distance>20000||speed===null||speed>1300||
   !Number.isFinite(loaded)||loaded<0||loaded>1||
   (price!==null&&(!Number.isFinite(price)||price<=0||price>20))||
   !Number.isFinite(routingMultiplier)||routingMultiplier<1||routingMultiplier>1.3||
   !Number.isFinite(referenceMissionKm)||referenceMissionKm<300||referenceMissionKm>4000)
  return {status:'UNAVAILABLE',reason:'Invalid route, aircraft, payload or price inputs',
   previewOnly:true,dispatchApproved:false,ledgerPosted:false};
 const normalizedDistance=distance*routingMultiplier;
 const profile=flightProfile(normalizedDistance,speed);
 const weightedHours=stages=>stages.reduce((sum,stage)=>
  sum+stage.minutes/60*PHASE_SETTINGS[stage.key].factor,0);
 // Use existing distance estimate as a WHOLE TRIP benchmark so phase costs
 // replace its simplification rather than being added on top of it.
 const data={emptyFuelKgPer100Km,halfFuelKgPer100Km,fullFuelKgPer100Km};
 const rate=rateForLoad(data,loaded);
 let kgPerHour=null,source=null;
 if(rate!==null){
  const ref=flightProfile(referenceMissionKm*routingMultiplier,speed);
  kgPerHour=(rate*referenceMissionKm/100)/weightedHours(ref);
  source='CALIBRATED_PROVISIONAL_MISSION_DISTANCE_RATE';
 }else if(hourly!==null){
  kgPerHour=hourly*(.86+.14*loaded);
  source='CATALOG_HOURLY_REFERENCE_WITH_LOAD_ESTIMATE';
 }
 if(kgPerHour===null||kgPerHour<=0)
  return {status:'UNAVAILABLE',reason:'No positive aircraft fuel-burn reference',
   previewOnly:true,dispatchApproved:false,ledgerPosted:false};
 const phases=profile.map((stage,i)=>{
  const kg=stage.minutes/60*PHASE_SETTINGS[stage.key].factor*kgPerHour;
  return {key:stage.key,label:CODES[i][1],minutes:rounded(stage.minutes),
   distanceKm:rounded(stage.distanceKm),fuelKg:rounded(kg),
   fuelUsd:price===null?null:rounded(kg*price)};
 });
 const flightMinutes=profile.reduce((n,p)=>n+p.minutes,0);
 const burned=profile.reduce((n,p)=>
  n+p.minutes/60*PHASE_SETTINGS[p.key].factor*kgPerHour,0);
 // Simplified screening reserve: 5% contingency plus 30 minutes holding.
 // Not a real regulatory dispatch fuel calculation (alternate/wind/weather
 // and full weight/balance requirements remain unverified).
 const reserve=burned*.05+kgPerHour*.5*.5;
 const uplift=burned+reserve;
 return {
  status:'PLANNING_ESTIMATE',modelVersion:FUEL_PHASE_MODEL_VERSION,source,
  routeDistanceKm:rounded(distance),modelFlightDistanceKm:rounded(normalizedDistance),
  payloadFraction:loaded,cruiseSpeedKmh:speed,estimatedCruiseKgPerHour:rounded(kgPerHour),
  totalMinutes:rounded(flightMinutes),tripFuelKg:rounded(burned),
  screeningReserveFuelKg:rounded(reserve),screeningFuelLoadKg:rounded(uplift),
  fuelPriceUsdPerKg:price,estimatedBurnCostUsd:price===null?null:rounded(burned*price),
  fuelTankCapacityKg:tank,referenceTankScreen:tank===null?'UNKNOWN':
   uplift>tank?'EXCEEDS_REFERENCE_TANK':'WITHIN_REFERENCE_TANK',
  phases,rateEvidence:source,priceEvidence:price===null?'UNKNOWN_OR_UNSUPPORTED_FUEL_FAMILY':'GAME_BALANCING_ASSUMPTION',
  previewOnly:true,dispatchApproved:false,ledgerPosted:false,
  note:'Reference/game balance only. No confirmed weather, winds, alternate, fuel uplift, airport quote, aircraft mass, flight movement or charge.'
 };
}
