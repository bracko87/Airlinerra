/** Read-only replan of future allocations using verified absence/qualification and
 * revised flight data. Already-started duties require the future live-duty adapter. */
import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';
export function previewCrewSubstitutions(input,{previousAssignments,planningCutoffUtc,flightUpdates=[]}={}){
 const parse=v=>typeof v==='string'&&/(Z|[+-]\d\d:\d\d)$/.test(v)?Date.parse(v):NaN;
 const cutoff=parse(planningCutoffUtc);
 if(!Number.isFinite(cutoff)||!Array.isArray(previousAssignments)||!Array.isArray(flightUpdates)||!Array.isArray(input?.flights)||parse(input.windowStartUtc)<cutoff)throw Error('INVALID_SUBSTITUTION_WINDOW');
 const knownFlights=new Map(input.flights.map(f=>[f.id,f]));
 const old=new Map(),updates=new Map();
 for(const item of previousAssignments){
  if(!knownFlights.has(item?.flightId)||old.has(item.flightId)||!Array.isArray(item.captains)||!Array.isArray(item.firstOfficers)||!Array.isArray(item.cabinCrew))throw Error('INVALID_PREVIOUS_ASSIGNMENT');
  old.set(item.flightId,item);
 }
 for(const u of flightUpdates){
  if(!knownFlights.has(u?.flightId)||updates.has(u.flightId)||!['delayed','cancelled'].includes(u.status))throw Error('INVALID_FLIGHT_UPDATE');
  if(u.status==='delayed'&&(!Number.isFinite(parse(u.departureUtc))||!Number.isFinite(parse(u.arrivalUtc))||parse(u.departureUtc)<parse(knownFlights.get(u.flightId).departureUtc)||parse(u.arrivalUtc)<=parse(u.departureUtc)))throw Error('INVALID_DELAY_TIMES');
  updates.set(u.flightId,u);
 }
 const deferred=[],cancelled=[];
 const flights=[];
 const end=parse(input.windowStartUtc)+168*3600000;
 for(const f of input.flights){
  const u=updates.get(f.id);
  // Already reported/started sectors need actual live duty state. This
  // preview cannot release or replace an employee on those sectors.
  if(parse(f.departureUtc)-120*60000<cutoff){
   return {status:'live_duty_state_required',flightId:f.id,assignments:[],changes:[],shortages:[],dispatchEnforced:false,changesPersisted:false};
  }
  if(u?.status==='cancelled'){cancelled.push(f.id);continue;}
  const next=u?.status==='delayed'?{...f,departureUtc:u.departureUtc,arrivalUtc:u.arrivalUtc}:f;
  if(parse(next.departureUtc)>=end){deferred.push(f.id);continue;}
  flights.push(next);
 }
 let result;
 try{result=planWeeklyCrew({...input,flights,preferredAssignments:previousAssignments,planNotBeforeUtc:planningCutoffUtc});}
 catch(e){if(e.message==='INVALID_AIRCRAFT_ROTATION')return {status:'aircraft_rotation_replan_required',assignments:[],changes:[],shortages:[],dispatchEnforced:false,changesPersisted:false};throw e;}
 const changes=[];
 for(const a of result.assignments){
  const prior=old.get(a.flightId);
  const replacements={};
  for(const role of ['captains','firstOfficers','cabinCrew']){
   const before=new Set(prior?.[role]||[]),after=new Set(a[role]);
   replacements[role]={removed:[...before].filter(id=>!after.has(id)),added:[...after].filter(id=>!before.has(id))};
  }
  if(Object.values(replacements).some(r=>r.added.length||r.removed.length))changes.push({flightId:a.flightId,reason:prior?'crew_reallocated':'new_assignment',replacements});
 }
 return {...result,status:'crew_substitution_preview',changes,cancelledFlightIds:cancelled,deferredFlightIds:deferred,requiresAttention:result.shortages.length>0||deferred.length>0,changesPersisted:false,liveDutyStateIntegrated:false};
}
