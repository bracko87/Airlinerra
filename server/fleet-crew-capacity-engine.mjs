import {estimateWeeklyCrewRecruitment} from './weekly-crew-recruitment-engine.mjs';
export function crewCapacityStatus(percent){
 if(percent===null||!Number.isFinite(percent)||percent<0)return {status:'unknown',crewShortageCancellationEligible:null};
 return {status:percent>110?'strong_reserves':percent>=100?'fully_staffed':percent>=90?'sufficient':percent>=80?'understaffed':percent>=60?'high_risk':'critical',crewShortageCancellationEligible:percent<80};
}
export function buildFleetCrewCapacity(snapshot){
 if(snapshot?.status!=='fleet_crew_capacity_input')throw Error('UNVERIFIED_CAPACITY_INPUT');
 const {fleet,bases,input,forecast,availableFromUtc}=snapshot;
 const baseResult={status:'fleet_crew_capacity',airlineId:snapshot.airlineId,windowStartUtc:input.windowStartUtc,forecast,sharedCabinPool:true,dispatchEnforced:false,scheduleCompletenessVerified:input.scheduleCompletenessVerified===true,dutyHistoryIntegrated:input.dutyHistoryIntegrated===true};
 const qualifiedCount=f=>input.pilots.filter(p=>p.permissions.some(q=>q.group===f.qualificationGroup&&q.active&&(q.captain||q.firstOfficer)&&q.issued<=input.windowStartUtc.slice(0,10)&&q.expires>input.windowStartUtc.slice(0,10))).length;
 const unknown=reason=>({...baseResult,reason,families:fleet.map(f=>({...f,qualifiedPilotCount:qualifiedCount(f),pilotRequired:null,pilotAvailable:null,pilotShortage:null,pilotPct:null,cabinPct:null,overallPct:null,...crewCapacityStatus(null)})),cabin:{available:forecast.cabinCrewCount,required:null,shortage:null,percent:null}});
 if(input.invalidOccurrenceCount!==0||input.cabinHeadcountReconciled!==true)return unknown('incomplete_or_unreconciled_data');
 if(!input.flights.length)return unknown('no_dated_flights');
 try{
 const opts={bases:bases.map(b=>({airport:b.airportKey,timezone:b.timezone})),availableFromUtc,salaryByRole:{captain:0,firstOfficer:0,cabin:0}};
 const reference=estimateWeeklyCrewRecruitment({...input,pilots:[],cabinMembers:[]},opts);
 const current=estimateWeeklyCrewRecruitment(input,opts);
 if(!reference.coverageComplete||!current.coverageComplete)return unknown('unresolved_schedule_requirements');
 const from=Date.parse(input.windowStartUtc),to=from+168*3600000,ready=Date.parse(availableFromUtc);
 const day=(t,z)=>{const p=new Intl.DateTimeFormat('en-CA',{timeZone:z,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(t);return ['year','month','day'].map(k=>p.find(x=>x.type===k).value).join('-');};
 const usable=p=>Date.parse(p.locationEffectiveUtc)<=ready&&p.employmentFrom<=day(ready,p.baseTimezone)&&!(p.absences||[]).some(a=>Date.parse(a.startUtc)<to&&Date.parse(a.endUtc)>from);
 const pool=input.pilots.filter(usable),claimed=new Set();
 const targets=reference.hireGroups.filter(g=>g.role!=='cabin').map(g=>({...g,eligible:pool.filter(p=>p.baseAirportKey===g.baseAirport&&p.permissions.some(q=>q.group===g.qualificationGroup&&q.active&&q[g.role]&&q.issued<=day(ready,p.baseTimezone)&&q.expires>day(to,p.baseTimezone)))}));
 targets.sort((a,b)=>a.eligible.length-b.eligible.length||a.qualificationGroup.localeCompare(b.qualificationGroup)||a.role.localeCompare(b.role));
 const assigned=new Map();
 const credit=(group,id)=>{claimed.add(id);assigned.set(group,(assigned.get(group)||0)+1);};
 for(const g of targets)for(const p of g.eligible.sort((a,b)=>a.permissions.length-b.permissions.length||a.id.localeCompare(b.id)).filter(p=>!claimed.has(p.id)).slice(0,g.count))credit(g.qualificationGroup,p.id);
 // Unused, qualified reserves are attributed to only one family.
 for(const p of pool.filter(p=>!claimed.has(p.id))){const g=targets.find(g=>g.eligible.some(e=>e.id===p.id));if(g)credit(g.qualificationGroup,p.id);}
 const cabinRequired=reference.additionalStaff.cabin,cabinShortage=current.additionalStaff.cabin,cabinAvailable=input.cabinMembers.filter(usable).length;
 const cabinPct=cabinRequired?Math.min(100*cabinAvailable/cabinRequired,cabinShortage?100*Math.max(0,cabinRequired-cabinShortage)/cabinRequired:Infinity):null;
 const pct=x=>x===null?null:Math.round(x*10)/10;
 const families=fleet.map(f=>{
  const required=targets.filter(g=>g.qualificationGroup===f.qualificationGroup).reduce((n,g)=>n+g.count,0);
  const shortage=current.hireGroups.filter(g=>g.qualificationGroup===f.qualificationGroup&&g.role!=='cabin').reduce((n,g)=>n+g.count,0);
  const available=assigned.get(f.qualificationGroup)||0;
  const pilotPct=required?Math.min(100*available/required,shortage?100*Math.max(0,required-shortage)/required:Infinity):null;
  const needsCabin=input.flights.some(x=>x.group===f.qualificationGroup&&x.cabinRequired>0);
  const overall=pilotPct===null?null:needsCabin&&cabinPct!==null?Math.min(pilotPct,cabinPct):pilotPct;
  return {...f,qualifiedPilotCount:qualifiedCount(f),pilotRequired:required||null,pilotAvailable:required?available:null,pilotShortage:required?Math.max(shortage,required-available,0):null,pilotPct:pct(pilotPct),cabinPct:needsCabin?pct(cabinPct):null,overallPct:pct(overall),...crewCapacityStatus(overall)};
 });
 return {...baseResult,reason:'estimated_weekly_staffing',families,cabin:{available:cabinAvailable,required:cabinRequired,shortage:Math.max(cabinShortage,cabinRequired-cabinAvailable,0),percent:pct(cabinPct)},referenceIsApproximate:true};
 }catch{return unknown('planning_calculation_unavailable');}
}
