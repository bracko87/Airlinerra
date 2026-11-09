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
      delivery=payload.deliveryEvidence||{},rights=payload.routeRights||{},
      staffing=payload.crewStaffing||{},permissions=payload.operatingPermissionEvidence||{};
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
     const rest=payload.crewRest||{};
     addFact(doc,evidenceHost,'Game crew duty conflicts',
      Number.isInteger(rest.overlapConflicts)?rest.overlapConflicts:'Not checked');
     addFact(doc,evidenceHost,'Insufficient game crew rest',
      Number.isInteger(rest.insufficientRest)?rest.insufficientRest:'Not checked');
     addFact(doc,evidenceHost,'Crew at wrong airport',
      Number.isInteger(rest.crewWrongAirport)?rest.crewWrongAirport:'Not checked');
     addFact(doc,evidenceHost,'Crew duty rules',
      'Provisional game policy · not aviation certification');
     addFact(doc,evidenceHost,'Crew staffing requirement',
      Number.isInteger(staffing.catalogCrewRequirement)?
       staffing.catalogCrewRequirement:'Not verified');
     addFact(doc,evidenceHost,'Weekly flights missing registered crew',
      Number.isInteger(staffing.entriesMissingRegisteredCrew)?
       staffing.entriesMissingRegisteredCrew:'Unknown');
     addFact(doc,evidenceHost,'Other-route crew reuse needs conflict checks',
      Number.isInteger(staffing.otherRouteReuseNeedsConflictAndRestChecks)?
       staffing.otherRouteReuseNeedsConflictAndRestChecks:'Unknown');
     addFact(doc,evidenceHost,'Game airline licence evidence on record',
      permissions.gameOperatorLicenceEvidenceRecorded===true?'Yes':'No');
     addFact(doc,evidenceHost,'Game route-permission evidence on record',
      Number.isInteger(permissions.gameRoutePermissionEvidenceRecorded)?
       permissions.gameRoutePermissionEvidenceRecorded+' of '+
       (permissions.requiredServiceTypes??'unknown'):'Unknown');
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
  const rosterService=getServer?.()?.scheduler;
  if(typeof rosterService?.crewRoster==='function'){
   const crewButton=el(doc,'button','Plan weekly crew');
   crewButton.type='button';crewButton.className='secondary';
   const crewMessage=el(doc,'p','Crew plans require separately registered airline employees.');
   crewMessage.className='hint';
   const crewHost=el(doc,'div');crewHost.className='section9-crew-planner';
   control.append(crewButton);host.append(crewMessage,crewHost);
   let crewSerial=0;
   crewButton.addEventListener('click',async()=>{
    const requestId=++crewSerial;
    crewButton.disabled=true;crewMessage.textContent='Reading airline crew roster...';
    crewHost.replaceChildren();
    try{
     const response=await getServer().scheduler.crewRoster({
      airlineId,scheduleId:route.serverScheduleId
     });
     if(requestId!==crewSerial||current!==serial)return;
     if(response?.readOnly!==true||
      response?.canActivateNormalFlight!==false||
      !Array.isArray(response.crewAvailableForPlanning)||
      !Array.isArray(response.proposals))throw Error('Unsafe roster response');
     const crew=response.crewAvailableForPlanning
      .filter(x=>x.aircraftQualificationMatches===true);
     crewMessage.textContent=crew.length?
      'Crew-duty proposals are not flight clearance. Verified employment and rest rules are separately required.':
      'No crew members qualified for this aircraft are registered with this airline. No assignment is possible yet.';
     for(const planned of response.proposals.slice(0,60)){
      crewHost.append(el(doc,'p','Weekly entry '+planned.weeklyEntry+
       ' · '+planned.crewId+(planned.stale?' · needs resaving':'')));
     }
     if(!crew.length||typeof getServer().scheduler.crewPlan!=='function')return;
     const crewLabel=el(doc,'label','Registered crew member');
     const crewSelect=el(doc,'select');
     for(const member of crew.slice(0,200)){
      const opt=el(doc,'option',member.crewReference+
       (member.employmentStatus==='verified_employed'?'':' · employment not verified'));
      opt.value=member.crewId;crewSelect.append(opt);
     }
     crewSelect.value=crew[0].crewId;crewLabel.append(crewSelect);
     const entryLabel=el(doc,'label','Weekly flight entry');
     const entrySelect=el(doc,'select');
     const entries=Math.min(7,Math.max(1,Array.isArray(route.schedule)?route.schedule.length:1));
     for(let i=1;i<=entries;i++){
      const opt=el(doc,'option','Entry '+i);opt.value=String(i);
      entrySelect.append(opt);
     }
     entrySelect.value='1';entryLabel.append(entrySelect);
     const plan=el(doc,'button','Propose assignment');
     const remove=el(doc,'button','Remove proposal');
     plan.type='button';remove.type='button';
     const send=async decision=>{
      plan.disabled=true;remove.disabled=true;
      try{
       const reply=await getServer().scheduler.crewPlan({
        airlineId,scheduleId:route.serverScheduleId,
        crewId:crewSelect.value,weeklyEntry:Number(entrySelect.value),decision
       });
       if(reply?.status!=='planned_not_verified'||
          reply.canActivateNormalFlight!==false)throw Error('Unsafe crew plan response');
       crewMessage.textContent='Crew duty proposal updated. Flights remain inactive. Recheck operational readiness.';
      }catch{
       crewMessage.textContent='Crew duty proposal was not saved. Flight activation remains blocked.';
      }finally{plan.disabled=false;remove.disabled=false;}
     };
     plan.addEventListener('click',()=>send('plan'));
     remove.addEventListener('click',()=>send('remove'));
     crewHost.append(crewLabel,entryLabel,plan,remove);
    }catch{
     if(current===serial)crewMessage.textContent=
      'Crew roster unavailable. No crew was assigned and no flight activated.';
    }finally{crewButton.disabled=false;}
   });
  }
  if(typeof rosterService?.crewOffers==='function' &&
     typeof rosterService?.crewHire==='function'){
   const hireButton=el(doc,'button','Hire game crew');
   hireButton.type='button';hireButton.className='secondary';
   const hireMessage=el(doc,'p',
    'Game-generated crew have monthly salary contracts. Payroll requires the verified game clock.');
   hireMessage.className='hint';
   const offerHost=el(doc,'div');offerHost.className='section9-crew-hiring';
   control.append(hireButton);host.append(hireMessage,offerHost);
   hireButton.addEventListener('click',async()=>{
    hireButton.disabled=true;offerHost.replaceChildren();
    hireMessage.textContent='Checking game crew candidates...';
    try{
     const market=await getServer().scheduler.crewOffers({
      airlineId,scheduleId:route.serverScheduleId
     });
     if(current!==serial)return;
     if(market?.status!=='game_npc_crew_market'||market.readOnly!==true||
        market.canActivateNormalFlight!==false||!Array.isArray(market.offers))
      throw Error('Untrusted crew market');
     hireMessage.textContent=market.offers.length?
      'Choose a provisional monthly game salary contract. Aviation qualifications remain unverified.':
      'No unclaimed candidates for this aircraft.';
     for(const offer of market.offers.slice(0,12)){
      if(!Number.isInteger(offer.candidateSlot)||
         offer.candidateSlot<1||offer.candidateSlot>2000||
         !Number.isFinite(Number(offer.monthlySalaryUsd)))continue;
      const row=el(doc,'div');row.className='detail-row';
      const label=el(doc,'span',offer.crewReference+' - USD '+
       Number(offer.monthlySalaryUsd).toLocaleString('en-US')+' per month');
      const hire=el(doc,'button','Hire');
      hire.type='button';hire.className='secondary';
      hire.addEventListener('click',async()=>{
       hire.disabled=true;
       try{
        const signed=await getServer().scheduler.crewHire({
         airlineId,scheduleId:route.serverScheduleId,
         candidateSlot:offer.candidateSlot
        });
        if(signed?.status!=='game_crew_contract_signed'||
           signed.ledgerPosted!==false||
           signed.canActivateNormalFlight!==false)
         throw Error('Unverified crew contract');
        row.replaceChildren(label,el(doc,'span','Hired'));
        hireMessage.textContent=signed.newContract?
         'Game crew contract signed. No salary charged yet. Use Plan weekly crew to assign them.':
         'Crew contract already exists; no duplicate created.';
        if(typeof getServer().scheduler.crewSalary==='function'){
         const payroll=await getServer().scheduler.crewSalary({airlineId});
         if(payroll?.status==='game_crew_salary_forecast'&&
           payroll.readOnly===true)
          hireMessage.textContent+=' Monthly salary commitment: USD '+
           Number(payroll.monthlySalaryCommitmentUsd).toLocaleString('en-US')+
           '. Payroll posting remains disabled until the game clock is verified.';
        }
       }catch{
        hireMessage.textContent='Crew was not hired. No flights were activated.';
        hire.disabled=false;
       }
      });
      row.append(label,hire);offerHost.append(row);
     }
    }catch{
     if(current===serial)hireMessage.textContent=
      'Game crew market unavailable. No contract or flight was created.';
    }finally{hireButton.disabled=false;}
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
