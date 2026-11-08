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
