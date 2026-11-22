/** Simulation-only additional hiring estimate. The schedule is reallocated for
 * the whole airline after each additional cohort; this is not an exact optimizer.
 * Base and salary inputs must come from trusted server planning data. */
import {planWeeklyCrew} from './weekly-crew-allocation-engine.mjs';
export function estimateWeeklyCrewRecruitment(input,{bases,availableFromUtc,salaryByRole,maxHires=2000,maxPasses=200}={}){
 const roles=['captain','firstOfficer','cabin'];
 if(!Array.isArray(bases)||!bases.length||!Number.isInteger(maxHires)||maxHires<0||maxHires>2000||!Number.isInteger(maxPasses)||maxPasses<1||maxPasses>200)throw Error('INVALID_RECRUITMENT_OPTIONS');
 if(!salaryByRole||roles.some(r=>!Number.isSafeInteger(salaryByRole[r])||salaryByRole[r]<0||salaryByRole[r]>100000))throw Error('INVALID_SALARY_ESTIMATE');
 const ready=typeof availableFromUtc==='string'&&/(Z|[+-]\d\d:\d\d)$/.test(availableFromUtc)?Date.parse(availableFromUtc):NaN;
 if(!Number.isFinite(ready))throw Error('INVALID_RECRUITMENT_READY_TIME');
 const baseMap=new Map();
 for(const b of bases){
  if(!b||typeof b.airport!=='string'||!b.airport||baseMap.has(b.airport)||typeof b.timezone!=='string'||!b.timezone)throw Error('INVALID_RECRUITMENT_BASE');
  new Intl.DateTimeFormat('en',{timeZone:b.timezone}).format(ready);baseMap.set(b.airport,b);
 }
 const working={...input,pilots:[...input.pilots],cabinMembers:[...input.cabinMembers]};
 const baseline=planWeeklyCrew(working);
 let current=baseline,passes=0,serial=0,stop='no_resolvable_base_shortage';
 const hires=[],usedIds=new Set([...working.pilots,...working.cabinMembers].map(x=>x.id));
 const flights=new Map(input.flights.map(f=>[f.id,f]));
 const day=(instant,tz)=>{
  const p=new Intl.DateTimeFormat('en-CA',{timeZone:tz,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(instant);
  return ['year','month','day'].map(k=>p.find(x=>x.type===k).value).join('-');
 };
 const hire=(role,f,b)=>{
  let id;do{id='recruitment-preview-'+(++serial);}while(usedIds.has(id));usedIds.add(id);
  const from=day(ready,b.timezone);
  const expiry=new Date(Date.parse(from+'T00:00:00Z')+365*86400000).toISOString().slice(0,10);
  const person={id,initialAirport:b.airport,locationEffectiveUtc:new Date(ready).toISOString(),baseTimezone:b.timezone,employmentFrom:from,history:[],recruitmentCandidate:true};
  if(role==='cabin'){person.role='flight_attendant';working.cabinMembers.push(person);}
  else{person.permissions=[{group:f.group,issued:from,expires:expiry,active:true,captain:role==='captain',firstOfficer:role==='firstOfficer'}];working.pilots.push(person);}
  hires.push({id,role,baseAirport:b.airport,qualificationGroup:role==='cabin'?null:f.group,estimatedMonthlySalaryUsd:salaryByRole[role]});
 };
 while(current.shortages.length&&passes<maxPasses){
  // An aircraft may not be crewable at an outstation. Never invent a base,
  // teleport a recruit or solve an extended-duty limitation by hiring.
  const shortage=current.shortages.find(s=>{
   const f=flights.get(s.flightId);
   return s.reason==='crew_shortage'&&baseMap.has(f.origin)&&Date.parse(f.departureUtc)-120*60000>=ready;
  });
  if(!shortage)break;
  const f=flights.get(shortage.flightId),b=baseMap.get(f.origin);
  const needs={captain:shortage.missingCaptains,firstOfficer:shortage.missingFirstOfficers,cabin:shortage.missingCabinCrew};
  const total=roles.reduce((n,r)=>n+needs[r],0);
  if(total<=0)break;
  if(hires.length+total>maxHires){stop='hire_limit_reached';break;}
  for(const role of roles)for(let i=0;i<needs[role];i++)hire(role,f,b);
  passes++;
  current=planWeeklyCrew(working);
 }
 if(!current.shortages.length)stop='all_preview_flights_covered';
 else if(passes===maxPasses)stop='calculation_pass_limit_reached';
 // Drop candidates never used in the final deterministic plan. Removing
 // unused identities does not affect the chosen assignments.
 const assigned=new Set(current.assignments.flatMap(a=>[...a.captains,...a.firstOfficers,...a.cabinCrew]));
 const proposed=hires.filter(h=>assigned.has(h.id));
 const summary=Object.fromEntries(roles.map(r=>[r,proposed.filter(h=>h.role===r).length]));
 const groups=new Map();
 for(const h of proposed){
  const key=JSON.stringify([h.baseAirport,h.qualificationGroup,h.role]);
  if(!groups.has(key))groups.set(key,{baseAirport:h.baseAirport,qualificationGroup:h.qualificationGroup,role:h.role,count:0,estimatedMonthlySalaryUsd:0});
  const g=groups.get(key);g.count++;g.estimatedMonthlySalaryUsd+=h.estimatedMonthlySalaryUsd;
 }
 return {status:'weekly_crew_recruitment_preview',baselineAssignedFlights:baseline.assignedFlightCount,baselineUnassignedFlights:baseline.unassignedFlightCount,plannedAircraftCount:new Set(input.flights.map(f=>f.aircraftId)).size,flightCount:current.flightCount,coveredFlights:current.assignedFlightCount,uncoveredFlights:current.unassignedFlightCount,additionalStaff:summary,additionalStaffCount:proposed.length,additionalMonthlySalaryUsd:proposed.reduce((n,h)=>n+h.estimatedMonthlySalaryUsd,0),hireGroups:[...groups.values()],proposedHires:proposed,remainingShortages:current.shortages,calculationPasses:passes,completionReason:stop,coverageComplete:!current.shortages.length,guaranteedMinimum:false,staffingEstimateOnly:true,hiringPerformed:false,dispatchEnforced:false};
}
