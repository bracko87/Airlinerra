// Manual crew hiring: only server quotes are authoritative.
export const crewHiringMarkup=()=>`<section aria-label="Manual crew recruitment">
 <h3>Hire flight crew</h3>
 <p id="crew-hire-forecast" class="hint">Loading staff and payroll forecast…</p>
 <div class="workspace-money-grid">
 <label class="workspace-label">Operational base<select id="crew-hire-base" disabled></select></label>
 <label class="workspace-label">Aircraft family<select id="crew-hire-family" disabled></select></label>
 <label class="workspace-label">Captains<input id="crew-hire-captains" type="number" min="0" max="200" step="1" value="0" disabled></label>
 <label class="workspace-label">Co-pilots<input id="crew-hire-officers" type="number" min="0" max="200" step="1" value="0" disabled></label>
 <label class="workspace-label">Flight attendants<input id="crew-hire-cabin" type="number" min="0" max="200" step="1" value="0" disabled></label>
 </div><div class="workspace-actions">
 <button id="crew-hire-quote" type="button" class="secondary" disabled>Review recruitment cost</button>
 <button id="crew-hire-confirm" type="button" class="primary" disabled>Confirm employment</button>
 <button id="crew-hire-refresh" type="button" class="secondary">Refresh staff</button></div>
 <p id="crew-hire-result" class="hint" role="status" aria-live="polite">Recruitment is not yet activated.</p>
 </section>`;
export function readCrewHireCounts(values){
 const counts=values.map(v=>typeof v==='string'&&/^\d{1,3}$/.test(v)?Number(v):NaN);
 if(counts.length!==3||counts.some(n=>!Number.isInteger(n)||n<0||n>200)||counts.reduce((a,b)=>a+b,0)<1||counts.reduce((a,b)=>a+b,0)>200)return null;
 return {captains:counts[0],firstOfficers:counts[1],cabinCrew:counts[2]};
}
export function createCrewHiringPanel({doc,getData}){
 const $=id=>doc.getElementById(id);
 const fields=['crew-hire-base','crew-hire-family','crew-hire-captains','crew-hire-officers','crew-hire-cabin'];
 const counts=fields.slice(2);
 let overview=null,quote=null,version=0,busy=false,airlineId=null;
 // Any uncertain confirmation remains tied to its original immutable payload.
 // Persist only an opaque request and payload, never authorization tokens.
 const pendingKey=id=>'airlinerra:crew-hire-pending:'+id;
 let pending=null;
 const message=t=>{if($('crew-hire-result'))$('crew-hire-result').textContent=t;};
 const money=v=>v==null||!Number.isFinite(Number(v))?'Unavailable':new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(Number(v));
 function controls(){
  for(const id of fields)if($(id))$(id).disabled=!overview||busy||!!pending;
  if($('crew-hire-quote'))$('crew-hire-quote').disabled=!overview||busy||!!pending;
  if($('crew-hire-confirm')){$('crew-hire-confirm').disabled=busy||overview?.manualHiringEnabled!==true||!(pending||quote?.value?.oneMonthAffordability===true&&quote?.value?.cabinHeadcountReconciled===true);$('crew-hire-confirm').textContent=pending?'Retry same confirmation':'Confirm employment';}
  if($('crew-hire-refresh'))$('crew-hire-refresh').disabled=busy;
 }
 function options(id,items,key,label){
  const el=$(id);if(!el)return;
  el.replaceChildren();
  for(const item of items){const opt=doc.createElement('option');opt.value=String(item[key]);opt.textContent=String(item[label]);el.append(opt);}
 }
 function reset(nextId){
  version++;busy=false;overview=null;quote=null;airlineId=nextId;pending=null;
  for(const id of counts)if($(id))$(id).value='0';
  options(fields[0],[],'airportKey','airportKey');options(fields[1],[],'qualificationGroup','label');
  if($('crew-hire-forecast'))$('crew-hire-forecast').textContent='Staff forecast not loaded.';
  if(nextId){
   try{const raw=doc.defaultView?.localStorage?.getItem(pendingKey(nextId));if(raw){const saved=JSON.parse(raw);if(saved.airlineId===nextId&&typeof saved.requestId==='string')pending=saved;}}catch{}
  }
  controls();message(pending?'Previous confirmation needs reconciliation. Retry the same request after loading staff.':'Recruitment is not yet activated.');
 }
 async function refresh(){
  const data=getData(),id=data.airline?.id||null;
  if(id!==airlineId)reset(id);
  if(!$(fields[0])||busy)return;
  if(!data.connected||!id||!data.fleetClient?.crewHireOverview){overview=null;quote=null;controls();return;}
  const ticket=++version;busy=true;quote=null;controls();
  try{
   const r=await data.fleetClient.crewHireOverview(id);
   if(ticket!==version||getData().airline?.id!==id)return;
   if(r?.status!=='shared_crew_hiring_overview'||r.airlineId!==id||!Array.isArray(r.bases)||!Array.isArray(r.families))throw Error('Invalid hiring overview');
   overview=r;options(fields[0],r.bases,'airportKey','airportKey');options(fields[1],r.families,'qualificationGroup','label');
   const f=r.forecast;
   $('crew-hire-forecast').textContent='Pilots: '+f.pilotCount+' | Cabin crew: '+f.cabinCrewCount+' | Monthly salary commitment: '+money(f.totalMonthlySalaryUsd);
   message(pending?'A previous confirmation needs reconciliation.':r.manualHiringEnabled?'Choose staff and review the server quote.':'Review mode only — employment confirmation is disabled.');
  }catch{if(ticket===version){overview=null;message('Could not load verified hiring data.');}}
  finally{if(ticket===version){busy=false;controls();}}
 }
 function invalidate(){if(!pending){quote=null;controls();message('Review the updated recruitment cost before confirming.');}}
 async function getQuote(){
  if(busy||!overview||pending)return;
  const data=getData(),id=airlineId,quantity=readCrewHireCounts(counts.map(k=>$(k).value));
  if(!quantity){message('Enter 1–200 staff in total, using whole numbers.');return;}
  const baseAirportKey=$(fields[0]).value,qualificationGroup=quantity.captains+quantity.firstOfficers>0?$(fields[1]).value:null;
  if(!baseAirportKey||qualificationGroup===''){message('Choose a registered base and aircraft family for pilots.');return;}
  const payload={airlineId:id,baseAirportKey,qualificationGroup,...quantity},ticket=++version;
  busy=true;quote=null;controls();
  try{
   const value=await data.fleetClient.crewHireQuote(payload);
   if(ticket!==version||getData().airline?.id!==id)return;
   if(value?.airlineId!==id||value.status!=='shared_crew_hire_quote'){message('Quote unavailable: '+String(value?.status||'unverified'));return;}
   if(value.baseAirportKey!==baseAirportKey||value.qualificationGroup!==qualificationGroup||['captains','firstOfficers','cabinCrew'].some(k=>value[k]!==quantity[k])||!Number.isFinite(Number(value.additionalMonthlySalaryUsd))||Number(value.additionalMonthlySalaryUsd)<0)throw Error('Quote mismatch');
   quote={payload,value};
   message('Additional monthly salary: '+money(value.additionalMonthlySalaryUsd)+' | Current payroll: '+money(value.currentMonthlySalaryUsd)+' | '+(value.oneMonthAffordability?'Affordability check passed.':'Insufficient cash or unreconciled staff.')+(overview.manualHiringEnabled?'':' Employment is disabled.'));
  }catch{if(ticket===version)message('Recruitment quote could not be verified.');}
  finally{if(ticket===version){busy=false;controls();}}
 }
 async function confirm(){
  if(busy||overview?.manualHiringEnabled!==true||(!pending&&(!quote||quote.value.oneMonthAffordability!==true||quote.value.cabinHeadcountReconciled!==true)))return;
  const data=getData(),id=airlineId;
  if(!pending){
   const requestId=globalThis.crypto?.randomUUID?.();if(!requestId){message('Secure request ID unavailable.');return;}
   pending={...quote.payload,requestId,monthlyLimitUsd:Number(quote.value.additionalMonthlySalaryUsd).toFixed(2)};
   try{const store=doc.defaultView?.localStorage;if(!store)throw Error('Storage unavailable');store.setItem(pendingKey(id),JSON.stringify(pending));}catch{pending=null;message('Cannot safely store confirmation request.');return;}
  }
  const ticket=++version;busy=true;controls();
  try{
   const r=await data.fleetClient.crewHireConfirm(pending);
   if(ticket!==version||getData().airline?.id!==id)return;
   if(r?.airlineId!==id||typeof r.status!=='string')throw Error('Unverified response');
   // A definite server response resolves this request. A transport failure does not.
   doc.defaultView?.localStorage?.removeItem(pendingKey(id));pending=null;quote=null;
   busy=false;await refresh();
   if(getData().airline?.id===id)message(r.status==='shared_crew_hired'?'Employment confirmed. Additional monthly salary: '+money(r.additionalMonthlySalaryUsd):'No employment confirmed: '+r.status);
  }catch{if(ticket===version)message('Confirmation not verified. Retry the same request; do not create a new one.');}
  finally{if(ticket===version){busy=false;controls();}}
 }
 doc.getElementById('player-main')?.addEventListener('input',e=>{if(fields.includes(e.target.id))invalidate();});
 doc.getElementById('player-main')?.addEventListener('change',e=>{if(fields.includes(e.target.id))invalidate();});
 doc.getElementById('player-main')?.addEventListener('click',e=>{
  const id=e.target.closest('button')?.id;
  if(id==='crew-hire-refresh')void refresh();
  if(id==='crew-hire-quote')void getQuote();
  if(id==='crew-hire-confirm')void confirm();
 });
 return {refresh,reset};
}
