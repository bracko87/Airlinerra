/** Airlinerra maintenance policy v1: GAME DESIGN, not an approved real-world
 * maintenance programme or enabled flight/financial operation.
 * Read-only, deterministic and cheap: one condition score + counters/dates.
 * Historical baselines must never be synthesized from model production years.
 */
export const MAINTENANCE_CHECKS=Object.freeze({
 daily:Object.freeze({label:'Daily',durationHours:1,calendarHours:24,flightHours:null,airportScope:'any_approved'}),
 weekly:Object.freeze({label:'Weekly',durationHours:3,calendarHours:168,flightHours:null,airportScope:'any_approved'}),
 a:Object.freeze({label:'A check',durationHours:6,calendarHours:null,flightHours:500,airportScope:'type_approved_mro'}),
 b:Object.freeze({label:'B check',durationHours:24,calendarHours:null,flightHours:750,airportScope:'type_approved_mro'}),
 c:Object.freeze({label:'C check',durationHours:168,calendarMonths:24,flightHours:5500,airportScope:'type_approved_mro'}),
 d:Object.freeze({label:'D / Heavy check',durationHours:504,calendarMonths:96,flightHours:null,airportScope:'type_approved_mro'})
});
export const MAINTENANCE_AGE_TIERS=Object.freeze([
 Object.freeze({min:0,max:5,multiplier:1}),
 Object.freeze({min:6,max:12,multiplier:1.1}),
 Object.freeze({min:13,max:20,multiplier:1.25}),
 Object.freeze({min:21,max:30,multiplier:1.45}),
 Object.freeze({min:31,max:200,multiplier:1.7})
]);
/** All prices are provisional USD game estimates, not vendor quotes. */
export const MAINTENANCE_COST_GROUPS=Object.freeze([
 Object.freeze({id:1,name:'Light utility',daily:30,weekly:100,a:600,b:1500,c:10000,d:50000}),
 Object.freeze({id:2,name:'Small commuter',daily:50,weekly:180,a:1200,b:4000,c:20000,d:85000}),
 Object.freeze({id:3,name:'Regional turboprop',daily:90,weekly:260,a:2500,b:8000,c:35000,d:180000}),
 Object.freeze({id:4,name:'Regional jet / midsize',daily:140,weekly:550,a:6000,b:16000,c:90000,d:350000}),
 Object.freeze({id:5,name:'Small narrowbody',daily:240,weekly:900,a:12000,b:30000,c:200000,d:850000}),
 Object.freeze({id:6,name:'Standard narrowbody',daily:300,weekly:1100,a:18000,b:48000,c:280000,d:1200000}),
 Object.freeze({id:7,name:'Medium / large widebody',daily:500,weekly:1900,a:32000,b:85000,c:600000,d:2500000}),
 Object.freeze({id:8,name:'Heavy / special aircraft',daily:1000,weekly:3500,a:58000,b:160000,c:1100000,d:4800000})
]);
const finiteNonnegative=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
const validDate=s=>typeof s==='string'&&/^\d{4}-\d\d-\d\dT/.test(s)&&!Number.isNaN(Date.parse(s))?new Date(s):null;
export function maintenanceGroupForModel({mtowKg,model='',family=''}={}){
 const mass=Number(mtowKg);
 if(!Number.isFinite(mass)||mass<=0)return null;
 // Classification is an approximate game size tier, not a manufacturer
 // maintenance approval. All configurations have source MTOW at present.
 if(mass<=8000)return 1;
 if(mass<=16000)return 2;
 const name=(String(model)+' '+String(family)).toLowerCase();
 const prop=/atr|dash 8|q400|saab|f27|f50|an-24|an-26|an-32|ma60|ma600|l-410|short|dornier 328|d328eco|d328\b|c-295|cn-235|twin otter/.test(name);
 if(mass<=36000&&prop)return 3;
 if(mass<=55000)return 4;
 if(mass<=76000)return 5;
 if(mass<=125000)return 6;
 if(mass<=290000)return 7;
 return 8;
}
export function airframeAge(buildYear,gameDate){
 const date=validDate(gameDate);
 if(!date||!Number.isInteger(buildYear)||buildYear<1900||
   buildYear>date.getUTCFullYear())return null;
 // Manufacture YEAR only is available: never invent an exact birthday.
 return date.getUTCFullYear()-buildYear;
}
export function quoteAircraftCheck({check,groupId,buildYear,gameDate}={}){
 const rule=MAINTENANCE_CHECKS[check],group=MAINTENANCE_COST_GROUPS.find(x=>x.id===groupId);
 if(!rule||!group)return Object.freeze({status:'invalid_check_or_group'});
 const age=airframeAge(buildYear,gameDate);
 if(age===null)return Object.freeze({status:'build_year_required',check,groupId,
  baseUsd:group[check],durationHours:rule.durationHours,estimatedUsd:null});
 const factor=MAINTENANCE_AGE_TIERS.find(x=>age>=x.min&&age<=x.max)?.multiplier;
 if(factor===undefined)return Object.freeze({status:'age_not_supported'});
 return Object.freeze({status:'game_estimate',check,groupId,ageYears:age,ageMultiplier:factor,
  baseUsd:group[check],estimatedUsd:Math.round(group[check]*factor),
  durationHours:rule.durationHours,source:'provisional_airlinerra_game_tariff_v1'});
}
function addUtcMonths(date,n){
 const next=new Date(date.getTime()),day=next.getUTCDate();
 next.setUTCDate(1);next.setUTCMonth(next.getUTCMonth()+n);
 const last=new Date(Date.UTC(next.getUTCFullYear(),next.getUTCMonth()+1,0)).getUTCDate();
 next.setUTCDate(Math.min(day,last));return next;
}
/** Strict baseline: without recorded check or verified entry baseline, due is
 * unknown, never automatically "not due". This avoids inventing history.
 * trackedFlightHours is since verified tracking began, not lifetime hours.
 */
export function maintenanceDue({check,asOfUtc,trackedFlightHours,trackingStartedUtc,
 lastCompletedUtc,lastCompletedAtFlightHours}={}){
 const rule=MAINTENANCE_CHECKS[check],now=validDate(asOfUtc);
 if(!rule||!now)return Object.freeze({status:'invalid_input'});
 const last=validDate(lastCompletedUtc);
 const start=validDate(trackingStartedUtc);
 // A baseline is not implicitly a completed check. A last recorded check is
 // authoritative for calendar due only; hours require its counter snapshot.
 let dueAt=null,remainingHours=null;
 if(rule.calendarHours!==undefined&&rule.calendarHours!==null&&last)
  dueAt=new Date(last.getTime()+rule.calendarHours*3600000);
 if(rule.calendarMonths!==undefined&&last)dueAt=addUtcMonths(last,rule.calendarMonths);
 if(rule.flightHours!==null){
  if(!start||!finiteNonnegative(trackedFlightHours)||
    !finiteNonnegative(lastCompletedAtFlightHours)||!last||
    lastCompletedAtFlightHours>trackedFlightHours)
   return Object.freeze({status:'unverified_flight_hour_baseline',check});
  remainingHours=Math.max(0,Math.round((rule.flightHours-(trackedFlightHours-lastCompletedAtFlightHours))*100)/100);
 }
 if(!dueAt&&remainingHours===null)
  return Object.freeze({status:'unverified_check_history',check});
 const overdue=Boolean((dueAt&&now>=dueAt)||(remainingHours!==null&&remainingHours===0));
 const near=Boolean((dueAt&&dueAt.getTime()-now.getTime()<=72*3600000)||
  (remainingHours!==null&&remainingHours<=rule.flightHours*.1));
 return Object.freeze({status:overdue?'due':near?'due_soon':'not_due',check,
  dueAtUtc:dueAt?.toISOString()||null,remainingFlightHours:remainingHours,
  durationHours:rule.durationHours});
}
export function maintenanceLocationEligibility({check,approvedAirport=false,
 verifiedGroundAirportKey=null,targetAirportKey=null,capability=null}={}){
 const rule=MAINTENANCE_CHECKS[check];
 if(!rule)return Object.freeze({allowed:false,reason:'unknown_check'});
 if(!approvedAirport||!targetAirportKey)return Object.freeze({allowed:false,reason:'airport_not_approved'});
 if(verifiedGroundAirportKey!==targetAirportKey)
  return Object.freeze({allowed:false,reason:'aircraft_must_reach_maintenance_airport_by_verified_flight'});
 if(rule.airportScope==='any_approved')return Object.freeze({allowed:true,reason:'line_check_any_approved_airport'});
 if(capability?.approvalStatus!=='game_approved'||capability?.check!==check||
  capability?.airportKey!==targetAirportKey)
  return Object.freeze({allowed:false,reason:'no_aircraft_type_approved_mro_at_airport'});
 return Object.freeze({allowed:true,reason:'approved_game_maintenance_facility'});
}
