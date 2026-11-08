/** Player-owned airline interline cooperation. Server performs all permission checks. */
const el=(doc,tag,content)=>{
 const x=doc.createElement(tag);
 if(typeof content==='string')x.textContent=content;
 return x;
};
export function createSection9PartnerConsole({doc,host,getServer}={}){
 if(!doc||!host)return Object.freeze({refresh:async()=>{}});
 let requestVersion=0;
 const title=el(doc,'h3','Interline cooperation');
 const intro=el(doc,'p','Partner airlines can provide connecting flights. Both airlines must approve before cooperation becomes active. Commercial passenger bookings remain disabled.');
 intro.className='hint';
 const controls=el(doc,'div');controls.className='workspace-actions';
 const label=el(doc,'label','Partner airline code (IATA or ICAO)');
 const code=el(doc,'input');code.type='text';code.minLength=2;code.maxLength=3;
 code.autocomplete='off';code.placeholder='2–3 letters';
 const propose=el(doc,'button','Request cooperation');propose.type='button';propose.className='secondary';
 const refreshButton=el(doc,'button','Refresh');refreshButton.type='button';
 refreshButton.className='secondary';
 controls.append(label,code,propose,refreshButton);
 const status=el(doc,'p','Connect to an airline to see agreements.');status.className='hint';
 const list=el(doc,'div');list.className='operations-partner-list';
 host.append(title,intro,controls,status,list);
 async function refresh(){
  const token=++requestVersion;
  list.replaceChildren();
  const server=getServer?.()||{},airlineId=server.airline?.id;
  if(!server.connected||!airlineId||typeof server.scheduler?.partnerList!=='function'){
   status.textContent='Verified airline connection required to manage agreements.';return;
  }
  status.textContent='Checking airline partnerships...';
  try{
   const result=await server.scheduler.partnerList(airlineId);
   if(token!==requestVersion)return;
   const agreements=Array.isArray(result?.agreements)?result.agreements:[];
   status.textContent=agreements.length?
     agreements.length+' cooperation request(s) or agreement(s).':'No cooperation agreements yet.';
   for(const p of agreements){
    const row=el(doc,'div');row.className='detail-row';
    const name=el(doc,'span',(p.otherAirlineName||'Other airline')+
     ' ('+(p.otherAirlineCode||'-')+') · '+(p.status||'unknown'));
    row.append(name);
    const agreementId=Number(p.agreementId);
    if(Number.isSafeInteger(agreementId)&&agreementId>0){
     if(p.canApprove===true){
      const accept=el(doc,'button','Approve');accept.className='secondary';
      accept.type='button';accept.dataset.partnerAction='approve';
      accept.dataset.partnerId=String(agreementId);row.append(accept);
     }
     if(['active','proposed'].includes(p.status)){
      const end=el(doc,'button','End');end.type='button';end.className='secondary';
      end.dataset.partnerAction='terminate';
      end.dataset.partnerId=String(agreementId);row.append(end);
     }
    }
    list.append(row);
   }
  }catch{
   if(token===requestVersion)
    status.textContent='Agreement service unavailable. Existing agreements were not changed.';
  }
 }
 propose.addEventListener('click',async()=>{
  const otherAirlineCode=code.value.trim().toUpperCase();
  const server=getServer?.()||{},airlineId=server.airline?.id;
  if(!/^[A-Z0-9]{2,3}$/.test(otherAirlineCode)||
   typeof server.scheduler?.partnerPropose!=='function'||!airlineId){
   status.textContent='Enter a valid 2–3 character partner airline code.';return;
  }
  propose.disabled=true;
  try{
   const result=await server.scheduler.partnerPropose({airlineId,otherAirlineCode});
   code.value='';
   await refresh();
   status.textContent=result.status==='active'?
    'Both airlines approved: connection cooperation is active.':
    'Request sent. Waiting for the other airline to approve.';
  }catch{status.textContent='Request not accepted. Check the partner airline code.';}
  finally{propose.disabled=false;}
 });
 refreshButton.addEventListener('click',()=>{void refresh()});
 list.addEventListener('click',async e=>{
  const target=e.target.closest('button[data-partner-action]');
  if(!target)return;
  const agreementId=Number(target.dataset.partnerId),decision=target.dataset.partnerAction;
  const server=getServer?.()||{},airlineId=server.airline?.id;
  if(!Number.isSafeInteger(agreementId)||agreementId<1||
   !['approve','terminate'].includes(decision)||!airlineId||
   typeof server.scheduler?.partnerDecision!=='function')return;
  target.disabled=true;
  try{
   await server.scheduler.partnerDecision({airlineId,agreementId,decision});
   await refresh();
  }catch{
   target.disabled=false;
   status.textContent='Agreement update not confirmed.';
  }
 });
 return Object.freeze({refresh});
}
