/** Trusted worker planning only. Do not accept snapshot or plan from browser.
 * Reserve staffing is a fixed approximate target derived from an empty-roster
 * reference calculation; existing reserve personnel are counted once. */
import {estimateWeeklyCrewRecruitment} from './weekly-crew-recruitment-engine.mjs';
export function planAutomaticCrewHiring(snapshot,availableFromUtc) {
 const reject=(status,details={})=>({status,hireGroups:[],executeAllowed:false,...details});
 if(snapshot?.status!=='automatic_crew_recruitment_snapshot')return reject('invalid_recruitment_snapshot');
 const {input,overview,settings,salaryPolicy,cabinBaseSalaries}=snapshot;
 if(settings?.mode==='manual')return reject('manual_recruitment_selected');
 if(!['automatic_minimum','automatic_reserves'].includes(settings?.mode)||!Number.isInteger(settings.reservePercent)|| (settings.mode==='automatic_minimum'?settings.reservePercent!==0:![5,10,15,20,25,30].includes(settings.reservePercent)))return reject('invalid_recruitment_preferences');
 if(!input?.flights?.length)return reject('no_scheduled_flights');
 if(input.invalidOccurrenceCount!==0||input.cabinHeadcountReconciled!==true)return reject('incomplete_or_unreconciled_input');
 const bases=overview.bases.map(b=>({airport:b.airportKey,timezone:b.timezone}));
 const baseMap=new Map(bases.map(b=>[b.airport,b]));
 if(!bases.length)return reject('no_registered_crew_bases');
 // Staffing simulation is priced separately using current server salary rates.
 const options={bases,availableFromUtc,salaryByRole:{captain:0,firstOfficer:0,cabin:0},maxHires:200};
 const estimate=estimateWeeklyCrewRecruitment(input,options);
 if(!estimate.coverageComplete)return reject('unresolved_weekly_crew_shortages',{remainingShortages:estimate.remainingShortages});
 const groups=new Map();
 const add=(base,group,role,count,reserve=false)=>{
  const k=JSON.stringify([base,group]);
  if(!groups.has(k))groups.set(k,{baseAirportKey:base,qualificationGroup:group,captains:0,firstOfficers:0,cabinCrew:0,reserveCaptains:0,reserveFirstOfficers:0,reserveCabinCrew:0});
  const g=groups.get(k),field={captain:'captains',firstOfficer:'firstOfficers',cabin:'cabinCrew'}[role];
  g[field]+=count;
  if(reserve)g[{captain:'reserveCaptains',firstOfficer:'reserveFirstOfficers',cabin:'reserveCabinCrew'}[role]]+=count;
 };
 for(const h of estimate.hireGroups)add(h.baseAirport,h.qualificationGroup,h.role,h.count);
 let reserveCount=0;
 if(settings.mode==='automatic_reserves'){
  // Fixed reference roster, not the number of currently assigned employees.
  // Otherwise a load-balancing scheduler may consume reserve employees and
  // inflate the target on each subsequent planning run.
  const reference=estimateWeeklyCrewRecruitment({...input,pilots:[],cabinMembers:[]},options);
  if(!reference.coverageComplete)return reject('reserve_reference_unresolved',{remainingShortages:reference.remainingShortages});
  const windowStart=Date.parse(input.windowStartUtc),windowEnd=windowStart+168*3600000,ready=Date.parse(availableFromUtc);
  const day=(t,z)=>{
   const parts=new Intl.DateTimeFormat('en-CA',{timeZone:z,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(t);
   return ['year','month','day'].map(k=>parts.find(p=>p.type===k).value).join('-');
  };
  const stock=[...input.pilots.map(p=>({...p,kind:'pilot'})),...input.cabinMembers.map(p=>({...p,kind:'cabin'}))];
  const claimed=new Set();
  const eligible=(p,g)=>{
   if(claimed.has(p.id)||p.baseAirportKey!==g.baseAirport||!baseMap.has(p.baseAirportKey)||p.employmentFrom>day(ready,p.baseTimezone)||Date.parse(p.locationEffectiveUtc)>ready)return false;
   const last=p.history?.at(-1);
   if((last?.destination||p.initialAirport)!==g.baseAirport)return false;
   if((p.absences||[]).some(a=>Date.parse(a.startUtc)<windowEnd&&Date.parse(a.endUtc)>windowStart))return false;
   if(g.role==='cabin')return p.kind==='cabin'&&['flight_attendant','cabin_supervisor','purser'].includes(p.role);
   return p.kind==='pilot'&&p.permissions.some(q=>q.group===g.qualificationGroup&&q.active===true&&q[g.role]===true&&q.issued<=day(ready,p.baseTimezone)&&q.expires>day(windowEnd,p.baseTimezone));
  };
  // Each existing employee is credited to at most one reserve target, even
  // with multiple family permissions; explicit candidates are allocated first.
  const ordered=[...reference.hireGroups].sort((a,b)=>a.baseAirport.localeCompare(b.baseAirport)||String(a.qualificationGroup).localeCompare(String(b.qualificationGroup))||a.role.localeCompare(b.role));
  for(const g of ordered){
   const added=estimate.hireGroups.find(h=>h.baseAirport===g.baseAirport&&h.qualificationGroup===g.qualificationGroup&&h.role===g.role)?.count||0;
   const target=g.count+Math.ceil(g.count*settings.reservePercent/100);
   // Credits are based on active staff in the base pool, not on fixed flight assignments.
   let credited=added;
   for(const p of stock.filter(p=>eligible(p,g)).sort((a,b)=>(a.permissions?.length||0)-(b.permissions?.length||0)||a.id.localeCompare(b.id))){
    if(credited>=target)break;claimed.add(p.id);credited++;
   }
   const missing=Math.max(0,target-credited);
   if(missing){add(g.baseAirport,g.qualificationGroup,g.role,missing,true);reserveCount+=missing;}
  }
 }
 const list=[...groups.values()];
 const cents=v=>{const n=Number(v);return v!==null&&v!==undefined&&Number.isFinite(n)&&n>=0&&Math.abs(n*100-Math.round(n*100))<1e-5?Math.round(n*100):NaN;};
 const cap=cents(salaryPolicy.captain),fo=cents(salaryPolicy.first_officer);
 let cost=0,headcount=0;
 for(const g of list){
  const cabin=cents(cabinBaseSalaries?.[g.baseAirportKey]??salaryPolicy.flight_attendant);
  cost+=g.captains*cap+g.firstOfficers*fo+g.cabinCrew*cabin;
  headcount+=g.captains+g.firstOfficers+g.cabinCrew;
 }
 const budget=cents(settings.monthlyBudgetUsd)-cents(snapshot.monthAuthorizedCommitmentsUsd),cash=cents(snapshot.cashUsd),current=cents(overview.forecast.totalMonthlySalaryUsd);
 if(![cost,budget,cash,current].every(Number.isSafeInteger))return reject('salary_or_budget_unverified');
 const hireGroups=list.map(({reserveCaptains,reserveFirstOfficers,reserveCabinCrew,...g})=>g);
 const details={estimatedAdditionalMonthlySalaryUsd:cost/100,additionalStaffCount:headcount,reserveHires:reserveCount,minimumStaffHires:estimate.additionalStaffCount,remainingMonthlyBudgetUsd:Math.max(0,budget)/100,hireGroups,groupBreakdown:list,coverageComplete:true,guaranteedMinimum:false};
 if(!headcount)return reject('staffing_target_met',details);
 if(headcount>200||cost>budget||current+cost>cash)return reject('automatic_hire_budget_or_batch_limit',details);
 if(input.scheduleCompletenessVerified!==true||input.dutyHistoryIntegrated!==true)return reject('authoritative_schedule_or_duty_history_required',details);
 if(overview.manualHiringEnabled!==true||snapshot.automaticHiringEnabled!==true)return reject('automatic_hiring_disabled',details);
 return {status:'automatic_hire_plan_ready',...details,executeAllowed:true};
}
