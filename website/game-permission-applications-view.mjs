/** Player Licences & Permits: actual server-owned game application status.
 * Uses the same compact white panels and form spacing as other game pages.
 * No DOM markup from untrusted data, no invented fees or client-side grants.
 */
const node=(doc,tag,cls='',value='')=>{
 const e=doc.createElement(tag);
 if(cls)e.className=cls;
 e.textContent=value;
 return e;
};
const MONEY=new Intl.NumberFormat('en-US',{
 style:'currency',currency:'USD',maximumFractionDigits:2
});
const LABELS={
 submitted:'Awaiting review',
 issued:'Issued',
 rejected:'Rejected',
 revoked:'Revoked',
 expired:'Expired'
};
export function createGamePermissionApplicationsView({
 doc,root,getAirline,getClient,newRequestKey=()=>globalThis.crypto.randomUUID()
}={}){
 if(!doc?.createElement||!root?.replaceChildren||
    typeof getAirline!=='function'||typeof getClient!=='function')
  throw Error('Game licence view dependencies are missing');
 let loadedAirline=null,version=0,current=null,busy=false,pendingKey=null;
 const section=node(doc,'article','panel workspace-panel game-licence-panel');
 section.append(node(doc,'span','panel-kicker','YOUR GAME PERMISSIONS'),
  node(doc,'h2','','Licence applications and approval status'),
  node(doc,'p','hint','See applications for your verified airline. Fees are taken only when an approved permission is issued, never when you apply.'));
 const note=node(doc,'p','game-licence-state','Select your airline to check the game licence status.');
 note.setAttribute('role','status');note.setAttribute('aria-live','polite');
 section.append(note);
 const metrics=node(doc,'div','game-licence-metrics');
 const fields=[];
 for(const name of ['Current game date','Pending review','Issued permissions']){
  const cell=node(doc,'div','game-licence-metric');
  cell.append(node(doc,'span','',name));
  const value=node(doc,'strong','','—');cell.append(value);fields.push(value);
  metrics.append(cell);
 }
 section.append(metrics);
 const list=node(doc,'div','game-licence-applications');
 section.append(node(doc,'h3','','My applications'),list);
 const form=node(doc,'form','game-licence-form');
 form.noValidate=true;
 const heading=node(doc,'h3','','Request a game permission');
 form.append(heading);
 const expl=node(doc,'p','hint','Only permissions released by the game will become available to request. Proposals in the planner below are not active fees.');
 form.append(expl);
 const controls=node(doc,'div','game-licence-fields');
 const label=(title,field)=>{
  const l=node(doc,'label','game-licence-field');
  l.append(node(doc,'span','',title),field);return l;
 };
 const type=node(doc,'select','game-licence-input');
 type.setAttribute('aria-label','Game permission to request');
 controls.append(label('Permission',type));
 const service=node(doc,'select','game-licence-input');
 for(const [v,t] of [['passenger','Passenger'],['cargo','Cargo']]){
  const option=node(doc,'option','',t);option.value=v;service.append(option);
 }
 const origin=node(doc,'input','game-licence-input');
 origin.placeholder='OURAIRPORTS:1234';origin.autocomplete='off';
 origin.maxLength=80;origin.setAttribute('aria-label','Origin game airport ID');
 const dest=node(doc,'input','game-licence-input');
 dest.placeholder='OURAIRPORTS:5678';dest.autocomplete='off';
 dest.maxLength=80;dest.setAttribute('aria-label','Destination game airport ID');
 const routeFields=node(doc,'div','game-licence-route-fields');
 routeFields.append(label('Origin airport ID',origin),label('Destination airport ID',dest),
  label('Service type',service));
 const routeHelp=node(doc,'p','hint','Route permissions use the exact airport IDs from your saved flight schedule. They are directional and specific to passenger or cargo service.');
 routeFields.append(routeHelp);
 controls.append(routeFields);
 form.append(controls);
 const actions=node(doc,'div','workspace-actions game-licence-actions');
 const submit=node(doc,'button','primary','Applications not open');
 submit.type='submit';submit.disabled=true;
 const feedback=node(doc,'span','hint game-licence-feedback',
  'No applications can be submitted until the game enables the permission.');
 feedback.setAttribute('role','status');feedback.setAttribute('aria-live','polite');
 actions.append(submit,feedback);form.append(actions);
 section.append(form);root.replaceChildren(section);
 const selected=()=>current?.policies?.find(p=>p.code===type.value)||null;
 const updateForm=()=>{
  const route=type.value!=='AIR_OPERATOR_CERTIFICATE';
  routeFields.hidden=!route;
  const p=selected();
  const allowed=Boolean(p?.canApply)&&current?.canApply===true&&
   !busy&&getAirline()?.id===loadedAirline;
  submit.disabled=!allowed;
  submit.textContent=busy?'Submitting…':
    allowed?'Submit game application':'Applications not open';
  feedback.textContent=allowed
   ?'No fee on submission. '+MONEY.format(p.feeUsd)+
     ' is charged only if approved after '+p.processingGameDays+' game day(s).'
   :'Application unavailable. No payment or licence will be created.';
 };
 type.addEventListener('change',()=>{pendingKey=null;updateForm();});
 const render=()=>{
  type.replaceChildren();
  const rows=current?.policies??[];
  for(const policy of rows){
   const option=node(doc,'option','',policy.title+
    (policy.canApply?'':' · Not open'));
   option.value=policy.code;type.append(option);
  }
  const today=current?.gameDay;
  fields[0].textContent=today||'Not running';
  const apps=current?.applications??[];
  fields[1].textContent=String(apps.filter(a=>a.status==='submitted').length);
  fields[2].textContent=String(apps.filter(a=>a.status==='issued').length);
  list.replaceChildren();
  if(apps.length===0){
   list.append(node(doc,'p','hint',
    'No applications recorded for this airline.')); 
  }else{
   for(const item of apps.slice(0,80)){
    const row=node(doc,'div','game-licence-application');
    const left=node(doc,'div','game-licence-application-text');
    const p=rows.find(v=>v.code===item.permissionCode);
    left.append(node(doc,'strong','',p?.title||item.permissionCode),
      node(doc,'small','',
       item.scope+' · Applied '+item.appliedGameDate+
       (item.status==='submitted'?' · Due '+item.dueGameDate:
        item.validUntilGameDate?' · Valid until '+item.validUntilGameDate:'')));
    const right=node(doc,'div','game-licence-application-balance');
    right.append(node(doc,'b','',LABELS[item.status]||item.status),
      node(doc,'small','',item.feeCharged
       ?'Fee charged: '+MONEY.format(Number(item.feeUsd)||0)
       :'No fee charged'));
    row.append(left,right);list.append(row);
   }
  }
  note.textContent=current?.canApply
   ?'Game applications are enabled for eligible permissions. Issuance still requires independent review.'
   :'Applications are not open. You may review requirements and your application history; no money will be deducted.';
  updateForm();
 };
 form.addEventListener('submit',async event=>{
  event.preventDefault();
  if(busy||!current?.canApply||!selected()?.canApply||
    getAirline()?.id!==loadedAirline)return;
  const client=getClient();
  if(!client)return;
  busy=true;updateForm();
  try{
   if(!pendingKey)pendingKey=newRequestKey();
   const request={airlineId:loadedAirline,
    requestKey:pendingKey,permissionCode:type.value};
   if(type.value!=='AIR_OPERATOR_CERTIFICATE'){
    Object.assign(request,{
     originAirportKey:origin.value.trim(),
     destinationAirportKey:dest.value.trim(),
     serviceType:service.value
    });
   }
   const outcome=await client.apply(request);
   feedback.textContent=outcome.status==='permission_application_submitted'
    ?'Application submitted. Review starts after the recorded game-day deadline.'
    :outcome.status==='permission_application_replayed'
     ?'This application was already recorded. No duplicate fee.'
     :'Application not accepted: '+outcome.status.replaceAll('_',' ')+'.';
   pendingKey=null;
   await load({refresh:true});
  }catch{
   feedback.textContent='Could not confirm submission. Retry with the same request to avoid duplicates.';
  }finally{busy=false;updateForm();}
 });
 async function load({refresh=false}={}){
  const airline=getAirline();
  const client=getClient();
  const id=airline?.id;
  const requestVersion=++version;
  loadedAirline=id??null;current=null;submit.disabled=true;
  if(!id||!client){
   note.textContent='Select a verified airline to view your game licence applications.';
   fields.forEach(v=>{v.textContent='—';});
   list.replaceChildren(node(doc,'p','hint','No verified application data is available.'));
   type.replaceChildren();updateForm();return;
  }
  note.textContent='Checking current game permissions…';
  try{
   const result=await client.status(id);
   if(requestVersion!==version||getAirline()?.id!==id)return;
   current=result;render();
  }catch{
   if(requestVersion!==version)return;
   note.textContent='Permission status is temporarily unavailable. No licence or fee can be assumed.';
   fields.forEach(v=>{v.textContent='—';});
   list.replaceChildren(node(doc,'p','hint','The protected permission API could not be reached.'));
   type.replaceChildren();updateForm();
  }
 }
 return Object.freeze({load,updateForm});
}
