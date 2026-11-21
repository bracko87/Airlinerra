/** Deterministic game estimates for taxi and terminal airborne phases.
 * This is not ADS-B flight history, airport-verified taxi routing, ATC or
 * performance data. Category (if present) comes from the approved airport
 * profile; using a tier is not proof of the actual taxi time.
 */
export const TAXI_CATEGORY_MINUTES=Object.freeze({
 'Local':Object.freeze({out:[3,9],in:[3,6]}),
 'Regional':Object.freeze({out:[5,11],in:[4,8]}),
 'Medium':Object.freeze({out:[7,14],in:[5,10]}),
 'Large':Object.freeze({out:[9,17],in:[7,12]}),
 'Major Hub':Object.freeze({out:[12,21],in:[9,15]}),
 'Mega Hub':Object.freeze({out:[15,28],in:[11,19]})
});
const fingerprint=value=>{
 let hash=2166136261;
 for(const c of String(value||''))hash=Math.imul(hash^c.charCodeAt(0),16777619)>>>0;
 return hash;
};
const pick=(range,key)=>range[0]+fingerprint(key)%(range[1]-range[0]+1);
export function estimateFlightPhaseTiming({
 originAirportCategory=null,destinationAirportCategory=null,
 originAirportKey=null,destinationAirportKey=null,distanceKm=null,aircraftMtowKg=null,cruiseSpeedKmh=null
}={}){
 const knownOrigin=Object.prototype.hasOwnProperty.call(TAXI_CATEGORY_MINUTES,originAirportCategory);
 const knownDestination=Object.prototype.hasOwnProperty.call(TAXI_CATEGORY_MINUTES,destinationAirportCategory);
 const anyKnown=knownOrigin||knownDestination;

 const origin=knownOrigin?TAXI_CATEGORY_MINUTES[originAirportCategory]:{out:[7,14]};
 const destination=knownDestination?TAXI_CATEGORY_MINUTES[destinationAirportCategory]:{in:[5,10]};
 const seed=String(originAirportKey||originAirportCategory||'generic')+'|'+
  String(destinationAirportKey||destinationAirportCategory||'generic');
 const distance=Number.isFinite(distanceKm)?distanceKm:1000;
 // Typical 10–20 min climb/descent reference, scaled down only on very
 // short sectors when there is insufficient distance for a normal climb.
 const range=distance<300?[10,14]:[12,20];
 // Game assumptions: larger aircraft require more ground maneuvering time.
 const mass=Number(aircraftMtowKg);
 const taxiMultiplier=aircraftMtowKg==null||!Number.isFinite(mass)||mass<=0?1:
  mass<20000?.8:mass<50000?.9:mass<100000?1:mass<200000?1.15:1.3;
 const speed=Number(cruiseSpeedKmh);
 // Continuous short-sector adjustment. Approximate standard airborne time
 // before reducing climb/descent; taxi time is deliberately excluded.
 const cruiseEquivalent=Number.isFinite(speed)&&speed>0?distance/speed*60:null;
 const nominalAirborne=cruiseEquivalent===null?null:cruiseEquivalent+10;
 const climbScale=nominalAirborne===null?1:Math.min(1,Math.max(.35,nominalAirborne/45));
 const climbBase=anyKnown?pick(range,seed+'|climb'):20;
 const descentBase=anyKnown?pick(range,seed+'|descent'):20;
 return Object.freeze({
  taxiOutMinutes:Math.max(1,Math.round((anyKnown?pick(origin.out,seed+'|taxi-out'):15)*taxiMultiplier)),
  taxiInMinutes:Math.max(1,Math.round((anyKnown?pick(destination.in,seed+'|taxi-in'):10)*taxiMultiplier)),
  climbMinutes:Math.max(3,Math.round(climbBase*climbScale)),
  descentMinutes:Math.max(3,Math.round(descentBase*climbScale)),
  categoryBased:anyKnown,originCategoryKnown:knownOrigin,
  destinationCategoryKnown:knownDestination
 });
}
