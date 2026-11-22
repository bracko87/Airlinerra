/** Deterministic server-side weekly allocation preview. Inputs must be assembled
 * from authoritative employment, permission, location and duty records.
 * Greedy feasible allocation, not proof of minimum headcount; no writes. */
export function planWeeklyCrew(input,{externalCrewPreview=false}={}) {
 const MIN=60000,DAY=86400000;
 const time=v=>typeof v==='string'&&/(Z|[+-]\d\d:\d\d)$/.test(v)?Date.parse(v):NaN;
 const start=time(input?.windowStartUtc),end=start+7*DAY;
 if(!Number.isFinite(start)||!Array.isArray(input.flights)||!Array.isArray(input.pilots)||!Array.isArray(input.cabinMembers)||input.flights.length>50000)throw Error('INVALID_WEEKLY_CREW_INPUT');
 const notBefore=input.planNotBeforeUtc===undefined?null:time(input.planNotBeforeUtc);
 if(notBefore!==null&&!Number.isFinite(notBefore))throw Error('INVALID_PLANNING_CUTOFF');
 const preferred=new Map();
 for(const a of input.preferredAssignments||[]){
  if(!a||typeof a.flightId!=='string'||preferred.has(a.flightId)||!Array.isArray(a.captains)||!Array.isArray(a.firstOfficers)||!Array.isArray(a.cabinCrew))throw Error('INVALID_PREFERRED_ASSIGNMENT');
  preferred.set(a.flightId,{captain:new Set(a.captains),firstOfficer:new Set(a.firstOfficers),cabin:new Set(a.cabinCrew)});
 }
 const iso=t=>new Date(t).toISOString();
 const dateCache=new Map();
 const localDate=(t,z)=>{
  const key=z+':'+t;
  if(dateCache.has(key))return dateCache.get(key);
  const parts=new Intl.DateTimeFormat('en-CA',{timeZone:z,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(t));
  const d=Date.parse(parts.find(x=>x.type==='year').value+'-'+parts.find(x=>x.type==='month').value+'-'+parts.find(x=>x.type==='day').value+'T00:00:00Z')/DAY;
  dateCache.set(key,d);return d;
 };
 const validDay=v=>typeof v==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(v)&&Number.isFinite(Date.parse(v+'T00:00:00Z'))&&iso(Date.parse(v+'T00:00:00Z')).slice(0,10)===v;
 const dayNum=v=>Date.parse(v+'T00:00:00Z')/DAY;
 const validAirport=v=>typeof v==='string'&&v.length>0&&v.length<=100;
 const ids=new Set();
 const makeMember=(m,kind)=>{
  if(!m||typeof m.id!=='string'||!m.id||ids.has(m.id)||!validAirport(m.initialAirport)||!Number.isFinite(time(m.locationEffectiveUtc))||!validDay(m.employmentFrom)||!Array.isArray(m.history))throw Error('INVALID_OR_DUPLICATE_CREW_MEMBER');
  ids.add(m.id);localDate(start,m.baseTimezone);
  const dates=new Set();let lastEnd=null,airport=m.initialAirport,lastArrival=null;
  // History contains completed duties ending before the preview starts, sorted.
  // Initial location is the checkpoint BEFORE history.
  for(const duty of m.history){
   const s=time(duty.startUtc),e=time(duty.endUtc);
   if(!Number.isFinite(s)||!Number.isFinite(e)||e<=s||e-s>720*MIN||s<time(m.locationEffectiveUtc)||e>start||!validAirport(duty.destination)||duty.origin!==airport||(lastEnd!==null&&s-lastEnd<720*MIN))throw Error('INVALID_CREW_HISTORY');
   dates.add(localDate(s,m.baseTimezone));lastEnd=e;airport=duty.destination;
  }
  if(kind==='pilot'&&(!Array.isArray(m.permissions)||m.permissions.some(q=>!q||typeof q.group!=='string'||!validDay(q.issued)||!validDay(q.expires)||q.issued>=q.expires)))throw Error('INVALID_PILOT_PERMISSIONS');
  if(m.absences!==undefined&&(!Array.isArray(m.absences)||m.absences.some(a=>!Number.isFinite(time(a.startUtc))||!Number.isFinite(time(a.endUtc))||time(a.endUtc)<=time(a.startUtc))))throw Error('INVALID_CREW_ABSENCE');
  return {m,kind,airport,lastEnd,lastArrival,duty:null,dates,assignedMinutes:0};
 };
 const pilots=input.pilots.map(m=>makeMember(m,'pilot')), cabin=input.cabinMembers.map(m=>makeMember(m,'cabin'));
 const flights=input.flights.map(f=>{
  const dep=time(f.departureUtc),arr=time(f.arrivalUtc);
  if(!f||typeof f.id!=='string'||!f.id||typeof f.aircraftId!=='string'||!f.aircraftId||typeof f.group!=='string'||!f.group||!validAirport(f.origin)||!validAirport(f.destination)||f.origin===f.destination||!Number.isFinite(dep)||!Number.isFinite(arr)||dep<start||dep>=end||arr<=dep||!Number.isInteger(f.cabinRequired)||f.cabinRequired<0||f.cabinRequired>40)throw Error('INVALID_WEEKLY_FLIGHT');
  return {...f,dep,arr};
 }).sort((a,b)=>a.dep-b.dep||a.id.localeCompare(b.id));
 const flightIds=new Set(),airframes=new Map();
 for(const f of flights){
  if(flightIds.has(f.id))throw Error('DUPLICATE_FLIGHT');flightIds.add(f.id);
  const previous=airframes.get(f.aircraftId);
  if(previous&&(previous.arr>f.dep||previous.destination!==f.origin))throw Error('INVALID_AIRCRAFT_ROTATION');
  airframes.set(f.aircraftId,f);
 }
 const permitted=(s,f,role)=>{
  const first=localDate(f.dep,s.m.baseTimezone),last=localDate(f.arr,s.m.baseTimezone);
  if(first<dayNum(s.m.employmentFrom))return false;
  if(s.kind==='cabin')return ['flight_attendant','cabin_supervisor','purser'].includes(s.m.role);
  return s.m.permissions.some(q=>q.group===f.group&&q.active===true&&dayNum(q.issued)<=first&&dayNum(q.expires)>last&&q[role]===true);
 };
 const proposed=(s,f,role)=>{
  if(!permitted(s,f,role)||s.airport!==f.origin)return null;
  const e=f.arr+30*MIN;
  // Carry the same duty forward; a turnaround doesn't reset reporting or rest.
  const extend=s.duty&&s.lastArrival<=f.dep&&e-s.duty.start<=720*MIN;
  const ds=extend?s.duty.start:f.dep-120*MIN;
  if(e-ds>720*MIN||ds<time(s.m.locationEffectiveUtc)||(!extend&&notBefore!==null&&ds<notBefore))return null;
  if(!extend&&s.lastEnd!==null&&ds-s.lastEnd<720*MIN)return null;
  if((s.m.absences||[]).some(a=>time(a.startUtc)<e&&time(a.endUtc)>ds))return null;
  const report=localDate(ds,s.m.baseTimezone);
  if(report<dayNum(s.m.employmentFrom))return null;
  if(!extend){
   for(let w=report-6;w<=report;w++){
    let n=0;
    for(let d=w;d<w+7;d++)if(d===report||s.dates.has(d))n++;
    if(n>5)return null;
   }
  }
  return {s,ds,e,extend:!!extend,role,report,preferred:preferred.get(f.id)?.[role]?.has(s.m.id)===true};
 };
 const ordered=(a,b)=>Number(b.preferred)-Number(a.preferred)||Number(b.extend)-Number(a.extend)||a.s.assignedMinutes-b.s.assignedMinutes||a.s.m.id.localeCompare(b.s.m.id);
 const apply=(p,f)=>{
  const s=p.s;
  s.dates.add(p.report);
  s.duty={start:p.ds,end:p.e};
  s.lastEnd=p.e;s.lastArrival=f.arr;s.airport=f.destination;s.assignedMinutes+=(f.arr-f.dep)/MIN;
 };
 const assignments=[],shortages=[],externalContracts=[];
 for(const f of flights){
  const needed=f.arr-f.dep>360*MIN?2:1;
  if(f.arr-f.dep+150*MIN>720*MIN){
   shortages.push({flightId:f.id,reason:'extended_duty_policy_required',requiredCaptains:needed,requiredFirstOfficers:needed,requiredCabinCrew:f.cabinRequired});continue;
  }
  const cap=pilots.map(s=>proposed(s,f,'captain')).filter(Boolean).sort(ordered);
  const fo=pilots.map(s=>proposed(s,f,'firstOfficer')).filter(Boolean).sort(ordered);
  const fa=cabin.map(s=>proposed(s,f,'cabin')).filter(Boolean).sort(ordered);
  // Reserve captain-only candidates first; ensure flexible captain/FO
  // identities cannot occupy two slots on a flight.
  const foIds=new Set(fo.map(p=>p.s.m.id));
  const chosenCap=[...cap].sort((a,b)=>Number(foIds.has(a.s.m.id))-Number(foIds.has(b.s.m.id))||ordered(a,b)).slice(0,needed);
  const capIds=new Set(chosenCap.map(p=>p.s.m.id));
  const chosenFo=fo.filter(p=>!capIds.has(p.s.m.id)).slice(0,needed);
  if(chosenCap.length<needed||chosenFo.length<needed||fa.length<f.cabinRequired){
   const shortage={flightId:f.id,reason:'crew_shortage',requiredCaptains:needed,requiredFirstOfficers:needed,requiredCabinCrew:f.cabinRequired,availableCaptains:cap.length,availableFirstOfficers:fo.length,distinctEligiblePilots:new Set([...cap,...fo].map(p=>p.s.m.id)).size,availableCabinCrew:fa.length,missingCaptains:needed-chosenCap.length,missingFirstOfficers:needed-chosenFo.length,missingCabinCrew:Math.max(0,f.cabinRequired-fa.length)};
   if(externalCrewPreview!==true){shortages.push(shortage);continue;}
   // A preview may fill only missing seats with contractors. Internal crew
   // still consume their own duty/rest/location state; no synthetic employee.
   externalContracts.push({flightId:f.id,qualificationGroup:f.group,origin:f.origin,departureUtc:iso(f.dep),arrivalUtc:iso(f.arr),captains:shortage.missingCaptains,firstOfficers:shortage.missingFirstOfficers,cabinCrew:shortage.missingCabinCrew,authorizationRequired:true});
  }
  const chosenCabin=fa.slice(0,f.cabinRequired);
  const chosen=[...chosenCap,...chosenFo,...chosenCabin];
  for(const p of chosen)apply(p,f);
  assignments.push({flightId:f.id,aircraftId:f.aircraftId,departureUtc:iso(f.dep),arrivalUtc:iso(f.arr),captains:chosenCap.map(p=>p.s.m.id),firstOfficers:chosenFo.map(p=>p.s.m.id),cabinCrew:chosenCabin.map(p=>p.s.m.id),duties:chosen.map(p=>({employeeId:p.s.m.id,role:p.role,dutyStartUtc:iso(p.ds),dutyEndUtc:iso(p.e),continuedDuty:p.extend}))});
 }
 return {status:externalCrewPreview===true?'weekly_mixed_crew_preview':'weekly_crew_allocation_preview',...(externalCrewPreview===true?{externalContracts,externalContractCount:externalContracts.length,contractingPerformed:false}:{}),windowStartUtc:iso(start),windowEndUtc:iso(end),flightCount:flights.length,assignedFlightCount:assignments.length,unassignedFlightCount:shortages.length,assignments,shortages,dispatchEnforced:false,guaranteedOptimal:false,hiringPerformed:false};
}
