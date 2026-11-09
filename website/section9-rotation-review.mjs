/** Read-only, owner-scoped aircraft rotation diagnostics, never activation. */
const el=(doc,tag,value='')=>{const node=doc.createElement(tag);
 node.textContent=value;return node;};
const addFact=(doc,host,label,value)=>{
 const row=el(doc,'div');row.className='detail-row';
 row.append(el(doc,'span',label),el(doc,'strong',String(value)));host.append(row);
};
export function createSection9RotationReview({doc,host,getServer}={}){
 if(!doc||!host)return Object.freeze({open:async()=>{}});
 let serial=0;
 async function open(route,airlineId){
  const current=++serial;host.replaceChildren();
  host.append(el(doc,'h4','Aircraft rotation – schedule safety'));
  const info=el(doc,'p',
    'Check overlapping flights and aircraft locations for all planned routes sharing this aircraft. This does not activate flights or verify crews, initial aircraft position or turnaround rules.');
  info.className='hint';host.append(info);
  if(!route?.serverScheduleId||!airlineId||
     typeof getServer?.()?.scheduler?.rotationPreview!=='function'){
   const unavailable=el(doc,'p',
     'Save a protected schedule to check aircraft rotation. No commercial flight is activated.');
   unavailable.className='hint';host.append(unavailable);return;
  }
  const control=el(doc,'div');control.className='workspace-actions';
  const dateLabel=el(doc,'label','Start of 28-day preview');
  const input=el(doc,'input');input.type='date';input.id='section9-rotation-start';
  const ref=Date.parse(route.referenceDepartureUtc||'');
  input.value=Number.isFinite(ref)?
    new Date(ref).toISOString().slice(0,10):new Date().toISOString().slice(0,10);
  dateLabel.append(input);
  const check=el(doc,'button','Check aircraft rotation');
  check.type='button';check.className='secondary';
  const result=el(doc,'div');result.className='section9-rotation-result';
  const state=el(doc,'p','Choose a date and check this aircraft.');state.className='hint';
  control.append(dateLabel,check);host.append(control,state,result);
  // Separate evidence review: a clean rotation is not the same as having
  // certified turnaround, crew, aircraft position or traffic rights.
  const operations=getServer?.()?.scheduler?.operationsPreview;
  if(typeof operations==='function'){
   const evidenceButton=el(doc,'button','Check operational readiness');
   evidenceButton.type='button';evidenceButton.className='secondary';
   const evidenceState=el(doc,'p','Crew, legal rights and turnaround are checked separately.');
   evidenceState.className='hint';
   const evidenceHost=el(doc,'div');evidenceHost.className='section9-operation-evidence';
   control.append(evidenceButton);host.append(evidenceState,evidenceHost);
   evidenceButton.addEventListener('click',async()=>{
    const date=input.value;
    if(!/^\d{4}-\d{2}-\d{2}$/.test(date)){
     evidenceState.textContent='Select a valid start date.';return;
    }
    evidenceButton.disabled=true;evidenceHost.replaceChildren();
    evidenceState.textContent='Checking aircraft and operational evidence...';
    try{
     const payload=await getServer().scheduler.operationsPreview({
      airlineId,scheduleId:route.serverScheduleId,startDate:date,days:28
     });
     if(current!==serial)return;
     if(payload?.readOnly!==true||payload?.canActivateNormalFlight!==false||
        !Array.isArray(payload.blockers))
      throw Error('Unsafe operational evidence response');
     const ground=payload.turnaround||{},crew=payload.crew||{},
      delivery=payload.deliveryEvidence||{},rights=payload.routeRights||{};
     evidenceState.textContent='Operational flight activation remains blocked until all evidence is verified.';
     addFact(doc,evidenceHost,'Provisional minimum aircraft ground time',
      Number.isInteger(ground.minimumMinutes)?ground.minimumMinutes+' minutes':'Not known');
     addFact(doc,evidenceHost,'Short aircraft ground stops',
      Number.isInteger(ground.shortTurnaroundOccurrences)?
       ground.shortTurnaroundOccurrences:'Unknown');
     addFact(doc,evidenceHost,'Aircraft delivery inspection approved',
      delivery.inspectionApproved===true?'Yes':'No');
     addFact(doc,evidenceHost,'Crew requirement known',
      crew.catalogRequirementKnown===true?'Yes':'No');
     addFact(doc,evidenceHost,'Crew assignments verified','No');
     addFact(doc,evidenceHost,'Operating licence / traffic rights authorized',
      rights.operationallyAuthorized===true?'Requires independent verification':'No');
     evidenceHost.append(el(doc,'h4','Outstanding activation requirements'));
     const ul=el(doc,'ul');
     for(const reason of payload.blockers.slice(0,18)){
      ul.append(el(doc,'li',String(reason).replaceAll('_',' ')));
     }
     evidenceHost.append(ul);
     const note=el(doc,'p',
      'Turnaround figures are provisional game estimates, not published aircraft certifications. Route legal principles are advisory, not operating rights.');
     note.className='hint';evidenceHost.append(note);
    }catch{
     if(current===serial)evidenceState.textContent=
      'Operational evidence unavailable. No flight was activated.';
    }finally{evidenceButton.disabled=false;}
   });
  }
  check.addEventListener('click',async()=>{
   const date=input.value;
   if(!/^\d{4}-\d{2}-\d{2}$/.test(date)){
    state.textContent='Select a valid start date.';return;
   }
   check.disabled=true;result.replaceChildren();
   state.textContent='Checking verified airline and aircraft schedule ownership...';
   try{
    const server=getServer?.()||{};
    const response=await server.scheduler.rotationPreview({
     airlineId,scheduleId:route.serverScheduleId,startDate:date,days:28
    });
    if(current!==serial)return;
    if(response?.readOnly!==true||response?.canActivateNormalFlight!==false)
     throw Error('Unexpected rotation result');
    const count=v=>Number.isInteger(v)&&v>=0?v:'Unknown';
    state.textContent=response.status==='ROTATION_PREVIEW_NO_CONFLICTS'?
     'No overlaps or airport-position conflicts found in the 28-day window.' :
     'Aircraft rotation requires attention. See the conflicts below.';
    addFact(doc,result,'Scheduled flights checked',count(response.flightOccurrences));
    addFact(doc,result,'Overlapping flights',count(response.overlappingFlights));
    addFact(doc,result,'Wrong-airport departures',count(response.wrongAirportDepartures));
    addFact(doc,result,'Daylight-saving issues',count(response.daylightSavingTimeIssues));
    addFact(doc,result,'Invalid weekly entries',count(response.invalidWeeklyEntries));
    addFact(doc,result,'Unknown origin time zones',count(response.unknownOriginTimezones));
    const slots=response.slotsRecorded||{};
    addFact(doc,result,'Departure / arrival slots recorded',
     (slots.departure===true?'Yes':'No')+' / '+(slots.arrival===true?'Yes':'No'));
    const errors=Array.isArray(response.sampleConflicts)?response.sampleConflicts:[];
    if(errors.length){
     result.append(el(doc,'h4','Examples requiring correction'));
     const ul=el(doc,'ul');
     for(const c of errors.slice(0,12)){
      ul.append(el(doc,'li',String(c.flightNumber||'Flight')+' · '+
       String(c.reason||'Conflict')+' · '+String(c.origin||'?')+' → '+
       String(c.destination||'?')));
     }
     result.append(ul);
    }
    const pending=el(doc,'p',
     'Activation remains blocked: initial fleet position, aircraft turnaround policy, crew, traffic rights and operational readiness have not been fully verified.');
    pending.className='hint';result.append(pending);
   }catch{
    if(current===serial)
     state.textContent='Rotation check unavailable. No flight has been activated.';
   }finally{check.disabled=false;}
  });
 }
 return Object.freeze({open});
}
