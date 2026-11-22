export const crewCapacityMarkup=()=>'<article class="panel planning-panel"><h2>Fleet &amp; Crew Capacity</h2><p class="hint">Each operating aircraft family. Cabin crew are shared across this airline, never across subsidiaries. Weekly staffing estimates; below 80% indicates future crew-shortage cancellation risk when operationally enabled.</p><div id="crew-capacity-summary" role="status">Loading staffing data…</div><div id="crew-capacity-families"></div><button type="button" class="secondary" id="crew-capacity-refresh">Refresh capacity</button><section class="workspace-task-list"><h3>One-flight external crew</h3><p class="hint">Check the next seven game days for temporary crew coverage. Internal reserves are considered first. A preview never hires staff, charges money or changes flights.</p><button type="button" class="secondary" id="external-crew-preview-refresh">Preview external crew needs</button><p id="external-crew-preview-status" role="status" class="hint">Not calculated.</p><div id="external-crew-preview-rows"></div></section><section class="workspace-task-list"><h3>Delayed flight crew recovery</h3><p class="hint">Read-only review of verified delayed slots, crew duty limits, reserves and potential temporary crew. Delays and contracts are not changed here.</p><button type="button" class="secondary" id="delayed-crew-recovery-refresh">Review delayed crew</button><p id="delayed-crew-recovery-status" role="status" class="hint">Not calculated.</p><div id="delayed-crew-recovery-rows"></div></section></article>';
export const managementResponsibilitiesMarkup=()=>'<article class="panel planning-panel"><h2>Management Responsibilities</h2><p class="hint">Delegate subordinate personnel decisions for this company only. Board and manager appointments remain player-only. Basic crew scheduling stays automatic.</p><div id="management-responsibility-rows"></div><div class="workspace-actions"><button type="button" class="primary" id="management-responsibility-save" disabled>Save responsibilities</button><button type="button" class="secondary" id="management-responsibility-refresh">Refresh</button></div><p id="management-responsibility-status" role="status" class="hint">Loading saved responsibilities…</p><p class="hint">Spending limits and reserve targets are managed under Staff &amp; Management. Delegated hiring is not active until management contracts and operations pass activation tests.</p><a href="#staff" data-view-link="staff">Open recruitment settings</a></article>';
const managerLabels={crew_staffing_manager:'Crew & Staffing Manager',ground_operations_manager:'Ground Operations Manager',technical_manager:'Technical Manager',customer_service_manager:'Customer Service Manager',hr_manager:'HR Manager'};
const labels={strong_reserves:'Strong reserves',fully_staffed:'Fully staffed',sufficient:'Sufficient',understaffed:'Understaffed – protected',high_risk:'High risk',critical:'Critical',unknown:'Not calculated'};
export function createStaffingOverview({doc,getData}){
 const $=id=>doc.getElementById(id);
 let generation=0,airlineId=null,policy=null,busy=false,dirty=false,externalGeneration=0,externalBusy=false,delayedGeneration=0,delayedBusy=false;
 const node=(tag,t)=>{const el=doc.createElement(tag);if(t!==undefined)el.textContent=t;return el;};
 const status=t=>{if($('management-responsibility-status'))$('management-responsibility-status').textContent=t;};
 const control=()=>{if($('management-responsibility-save'))$('management-responsibility-save').disabled=busy||!policy||!dirty;for(const el of $('management-responsibility-rows')?.querySelectorAll('select')||[])el.disabled=busy;};
 function reset(id){generation++;delayedGeneration++;delayedBusy=false;const delayedBtn=$('delayed-crew-recovery-refresh');if(delayedBtn)delayedBtn.disabled=false;if($('delayed-crew-recovery-status'))$('delayed-crew-recovery-status').textContent='Not calculated.';$('delayed-crew-recovery-rows')?.replaceChildren();externalGeneration++;externalBusy=false;const btn=$('external-crew-preview-refresh');if(btn)btn.disabled=false;const ext=$('external-crew-preview-status');if(ext)ext.textContent='Not calculated.';$('external-crew-preview-rows')?.replaceChildren();airlineId=id;policy=null;busy=false;dirty=false;$('crew-capacity-families')?.replaceChildren();$('management-responsibility-rows')?.replaceChildren();if($('crew-capacity-summary'))$('crew-capacity-summary').textContent='Staffing data not loaded.';status('Responsibilities not loaded.');control();}
 function meter(parent,label,pct,detail){
  const line=node('p',label+' — '+(pct==null?'Not calculated':pct.toFixed(1)+'%')+(detail?' · '+detail:''));parent.append(line);
  if(pct!=null){const bar=node('progress');bar.max=100;bar.value=Math.min(100,Math.max(0,pct));bar.setAttribute('aria-label',label+' '+pct+' percent');bar.style.width='100%';bar.style.accentColor=pct>=90?'#16834a':pct>=80?'#c69a16':'#c83232';parent.append(bar);}
 }
 function renderCapacity(value){
  const host=$('crew-capacity-families'),summary=$('crew-capacity-summary');if(!host||!summary)return;
  host.replaceChildren();const c=value.cabin;
  summary.textContent='Total employed pilots: '+value.forecast.pilotCount+' · Shared cabin pool: '+c.available+' available'+(c.required==null?' · minimum not calculated':' / '+c.required+' estimated minimum · '+c.shortage+' additional recommended')+'. '+(value.scheduleCompletenessVerified&&value.dutyHistoryIntegrated?'':'Preview only: complete schedule and actual duty history are not verified. ');
  if(value.reason==='no_dated_flights')summary.textContent+='Create routes to calculate weekly staffing needs.';
  if(value.reason==='unresolved_schedule_requirements')summary.textContent+='Schedule requires review before staffing can be estimated.';
  if(!value.families.length)host.append(node('p','No operating aircraft in this company.'));
  for(const f of value.families){
   const row=node('section');row.className='workspace-task-list';row.append(node('h3',f.label+' family · '+f.aircraftCount+' aircraft'),node('p',f.qualifiedPilotCount+' qualified pilots (shared qualifications may overlap between families).'));
   meter(row,'Pilot capacity',f.pilotPct,f.pilotRequired==null?'':f.pilotAvailable+' allocated / '+f.pilotRequired+' estimated minimum');
   meter(row,'Cabin capacity (shared)',f.cabinPct,'');
   meter(row,'Overall capacity',f.overallPct,labels[f.status]||'Not calculated');
   row.append(node('p',f.pilotShortage==null?'Staffing target not available until routes are scheduled.':f.pilotShortage+' additional pilots recommended. Cabin shortages are shown once above.'));
   host.append(row);
  }
 }
 function renderPolicy(value){
  policy=value;dirty=false;const host=$('management-responsibility-rows');if(!host)return;host.replaceChildren();
  for(const r of value.roles){
   const label=node('label');label.className='workspace-label';label.append(node('strong',r.label),node('span',managerLabels[r.managerRole]||r.managerRole));
   const select=node('select');select.dataset.responsibilityKey=r.key;
   for(const [v,t] of [['manual','Manual management'],['approval','Manager proposes – player approves'],['auto','Full operational autonomy']]){const opt=node('option',t);opt.value=v;select.append(opt);}
   select.value=r.mode;label.append(select,node('small',r.managerAppointed?'Manager appointed':'Manager appointment pending'));host.append(label);
  }
  status('Saved subsidiary policies loaded. Delegated hiring is not yet active.');control();
 }
 async function refresh(){
  const d=getData(),id=d.airline?.id||null;if(id!==airlineId)reset(id);
  if(!d.connected||!id||busy||!d.fleetClient)return;
  const ticket=++generation;busy=true;control();
  try{
   const [c,m]=await Promise.allSettled([d.fleetClient.crewCapacity(id),d.fleetClient.managementResponsibilities(id)]);
   if(ticket!==generation||getData().airline?.id!==id)return;
   if(c.status==='fulfilled'&&c.value.airlineId===id&&c.value.status==='fleet_crew_capacity')renderCapacity(c.value);else if($('crew-capacity-summary'))$('crew-capacity-summary').textContent='Verified capacity data unavailable.';
   if(!dirty){if(m.status==='fulfilled'&&m.value.airlineId===id&&m.value.status==='management_responsibilities')renderPolicy(m.value);else status('Could not load verified management policies.');}
  }finally{if(ticket===generation){busy=false;control();}}
 }
 async function externalPreview(){
  const d=getData(),id=d.airline?.id,host=$('external-crew-preview-rows'),info=$('external-crew-preview-status'),btn=$('external-crew-preview-refresh');
  if(!id||!d.connected||!host||!info||!btn||externalBusy||typeof d.fleetClient?.externalCrewPreview!=='function')return;
  const ticket=++externalGeneration;externalBusy=true;btn.disabled=true;host.replaceChildren();info.textContent='Calculating verified crew coverage…';
  try{
   const r=await d.fleetClient.externalCrewPreview(id);
   if(ticket!==externalGeneration||getData().airline?.id!==id)return;
   if(r.airlineId!==id||r.status!=='external_crew_plan_preview'){info.textContent='Crew plan unavailable: verified schedule or duty history requires review.';return;}
   if(!r.flightCount){info.textContent='No dated flights available. Create routes before checking external crew needs.';return;}
   const usd=v=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(v);
   info.textContent=r.internalOnlyFlights+' flights covered internally · '+r.contractFlights+' flights need contractors · '+r.unresolvedFlights+' unresolved. '+(r.contractingEnabled?'Contract authorization available to the private worker.':'External contracting is not released, or no contractors are needed.')+' Preview only.';
   const roles=r.externalRoles;
   host.append(node('p',roles.captains+' captain assignments · '+roles.firstOfficers+' first officer assignments · '+roles.cabinCrew+' cabin assignments (one flight each).'));
   host.append(node('p',r.estimatedCostUsd==null?'Estimated contractor costs unavailable.':'Estimated one-flight contract costs: '+usd(r.estimatedCostUsd)));
   for(const f of r.flights||[])host.append(node('p',f.origin+' · '+f.departureUtc+' UTC · '+f.captains+' captain / '+f.firstOfficers+' FO / '+f.cabinCrew+' cabin · '+usd(f.estimatedCostUsd)));
   if(r.detailsTruncated)host.append(node('p','Showing the first 50 contract estimates.'));
  }catch{if(ticket===externalGeneration&&getData().airline?.id===id)info.textContent='External crew preview unavailable.';}finally{if(ticket===externalGeneration){externalBusy=false;btn.disabled=false;}}
 }
 async function delayedRecovery(){
  const d=getData(),id=d.airline?.id,info=$('delayed-crew-recovery-status'),host=$('delayed-crew-recovery-rows'),btn=$('delayed-crew-recovery-refresh');
  if(!id||!d.connected||!info||!host||!btn||delayedBusy||typeof d.fleetClient?.delayedCrewRecoveryPreview!=='function')return;
  const ticket=++delayedGeneration;delayedBusy=true;btn.disabled=true;host.replaceChildren();info.textContent='Checking verified delayed flights…';
  try{
   const r=await d.fleetClient.delayedCrewRecoveryPreview(id);
   if(ticket!==delayedGeneration||getData().airline?.id!==id)return;
   if(r.airlineId!==id){info.textContent='Verified airline response unavailable.';return;}
   if(r.status==='no_verified_delayed_flights'){info.textContent='No pending verified delayed flights in the next seven game days.';return;}
   if(r.status!=='delayed_crew_recovery_preview'){info.textContent='Crew recovery is on hold: '+String(r.status||'verification required').replace(/_/g,' ')+'. No changes made.';return;}
   info.textContent=r.affectedFlights+' delayed flights · '+r.reassignedFlights+' proposed crew changes · '+r.unresolvedInternalShortages+' internal shortages · '+r.externalContractFlightsProposed+' contractor candidates. Preview only.';
   const c=r.externalCrewAssignments||{};
   host.append(node('p',(c.captains||0)+' external captains · '+(c.firstOfficers||0)+' first officers · '+(c.cabinCrew||0)+' cabin assignments proposed; contract prices and revised timings need verification.'));
   for(const f of r.assessedFlights||[])host.append(node('p','Revised departure '+f.effectiveDepartureUtc+' · '+f.replacementRequired+' original staff need review · '+String(f.action).replace(/_/g,' ')+(f.rosterValidation?' · '+String(f.rosterValidation).replace(/_/g,' '):'')+(f.estimatedExternalCostUsd==null?'':' · estimated cost '+new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(f.estimatedExternalCostUsd))));
   if(Number.isInteger(r.rosterValidationPassedFlights))host.append(node('p',r.rosterValidationPassedFlights+' / '+r.affectedFlights+' delayed rosters independently validated. No roster or contract has been authorized.'));
   if(r.deferredFlights)host.append(node('p',r.deferredFlights+' flights shifted beyond the review window and require another review.'));
  }catch{if(ticket===delayedGeneration&&getData().airline?.id===id)info.textContent='Could not verify delayed crew recovery.';}finally{if(ticket===delayedGeneration){delayedBusy=false;btn.disabled=false;}}
 }
 async function save(){
  if(busy||!policy||!dirty)return;const d=getData(),id=airlineId,ticket=++generation;
  const policies=Object.fromEntries([...$('management-responsibility-rows').querySelectorAll('select')].map(e=>[e.dataset.responsibilityKey,e.value]));
  busy=true;control();
  try{const r=await d.fleetClient.saveManagementResponsibilities({airlineId:id,version:policy.version,policies});if(ticket!==generation||getData().airline?.id!==id)return;if(r.status!=='management_responsibilities'||r.airlineId!==id)throw Error('Unverified response');renderPolicy(r);status('Responsibilities saved for this company.');}
  catch{if(ticket===generation)status('Could not save. Refresh after resolving any version conflict.');}finally{if(ticket===generation){busy=false;control();}}
 }
 const main=$('player-main');
 main?.addEventListener('change',e=>{if(e.target.dataset.responsibilityKey){dirty=true;control();}});
 main?.addEventListener('click',e=>{const id=e.target.closest('button')?.id;if(id==='crew-capacity-refresh')void refresh();if(id==='external-crew-preview-refresh')void externalPreview();if(id==='delayed-crew-recovery-refresh')void delayedRecovery();if(id==='management-responsibility-refresh'&&!busy){dirty=false;void refresh();}if(id==='management-responsibility-save')void save();});
 return {refresh,reset};
}
