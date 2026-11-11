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
 originAirportKey=null,destinationAirportKey=null,distanceKm=null
}={}){
 const knownOrigin=Object.prototype.hasOwnProperty.call(TAXI_CATEGORY_MINUTES,originAirportCategory);
 const knownDestination=Object.prototype.hasOwnProperty.call(TAXI_CATEGORY_MINUTES,destinationAirportCategory);
 const anyKnown=knownOrigin||knownDestination;
 if(!anyKnown)return Object.freeze({
  taxiOutMinutes:15,taxiInMinutes:10,climbMinutes:20,descentMinutes:20,
  categoryBased:false,originCategoryKnown:false,destinationCategoryKnown:false
 });
 const origin=knownOrigin?TAXI_CATEGORY_MINUTES[originAirportCategory]:{out:[7,14]};
 const destination=knownDestination?TAXI_CATEGORY_MINUTES[destinationAirportCategory]:{in:[5,10]};
 const seed=String(originAirportKey||originAirportCategory||'generic')+'|'+
  String(destinationAirportKey||destinationAirportCategory||'generic');
 const distance=Number.isFinite(distanceKm)?distanceKm:1000;
 // Typical 10–20 min climb/descent reference, scaled down only on very
 // short sectors when there is insufficient distance for a normal climb.
 const range=distance<300?[10,14]:[12,20];
 return Object.freeze({
  taxiOutMinutes:pick(origin.out,seed+'|taxi-out'),
  taxiInMinutes:pick(destination.in,seed+'|taxi-in'),
  climbMinutes:pick(range,seed+'|climb'),
  descentMinutes:pick(range,seed+'|descent'),
  categoryBased:true,originCategoryKnown:knownOrigin,
  destinationCategoryKnown:knownDestination
 });
}
