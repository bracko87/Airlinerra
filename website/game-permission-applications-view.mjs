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
 let cargoStatus=null,cargoRequestKey=null,charterStatus=null,charterRequestKey=null;
 const section=node(doc,'article','panel workspace-panel game-licence-panel');
 section.append(node(doc,'span','panel-kicker','YOUR GAME PERMISSIONS'),
  node(doc,'h2','','Licence applications and approval status'),
  node(doc,'p','hint','See applications for your verified airline. Fees are taken only when an approved permission is issued, never when you apply.'));
 const note=node(doc,'p','game-licence-state','Select your airline to check the game licence status.');
 note.setAttribute('role','status');note.setAttribute('aria-live','polite');
 section.append(note);
 const aocPanel=node(doc,'div','game-aoc-status');
 const aocTitle=node(doc,'h3','','Air Operator Certificate (AOC)');
 const aocState=node(doc,'p','game-aoc-status-text',
  'Checking the selected airline’s AOC record…');
 const aocDetail=node(doc,'p','hint',
  'AOC status is company-specific. The holding, academies and maintenance companies do not share an airline AOC.');
 aocPanel.append(aocTitle,aocState,aocDetail);
 section.append(aocPanel);
 const l2Panel=node(doc,'div','game-aoc-status game-licence-l2');
 l2Panel.append(node(doc,'h3','','Licence 2 — Foreign network expansion'),
  node(doc,'p','hint','Licence 1 covers normal flights to and from your home market. Licence 2 is for additional foreign-network routes. Each direction counts separately; repeat flights on the same directed route use one slot.'));
 const l2State=node(doc,'p','hint','Checking foreign-market licence limits…');
 const l2Markets=node(doc,'div','game-licence-applications');
 l2Panel.append(l2State,l2Markets);
 section.append(l2Panel);
 const l3Panel=node(doc,'div','game-aoc-status game-licence-l3');
 const l3State=node(doc,'p','game-licence-status','Cargo licence status not yet checked.');
 const l3Apply=node(doc,'button','secondary','Apply for Cargo Licence 3');
 l3Apply.type='button';l3Apply.disabled=true;
 l3Panel.append(
  node(doc,'h3','','Licence 3 — Cargo Operations Approval'),
  l3State,
  node(doc,'p','hint','For a separately registered cargo airline subsidiary: own active AOC, at least one in-service cargo or combi aircraft in the same company, and $50,000 company funds. Apply for free; processing takes 3 verified game days. The fee is charged only if approval is issued.'),
  node(doc,'p','hint','Once issued, this company may offer ordinary cargo services worldwide, but actual flights still require separate market, route, airport, slot and safety permissions. Dangerous goods are not included.'),
  l3Apply
 );
 section.append(l3Panel);
 const l4Panel=node(doc,'div','game-aoc-status game-licence-l4');
 const l4State=node(doc,'p','game-licence-status','Charter/VIP licence status not yet checked.');
 const l4Apply=node(doc,'button','secondary','Apply for Charter/VIP Licence 4');
 l4Apply.type='button';l4Apply.disabled=true;
 l4Panel.append(
  node(doc,'h3','','Licence 4 — Charter / VIP Operating Approval'),
  l4State,
  node(doc,'p','hint','For a separately registered charter airline subsidiary: own active AOC, at least one in-service passenger or combi aircraft in the same company, and $40,000 company funds. Apply for free; processing takes 3 verified game days. The fee is charged only if approval is issued.'),
  node(doc,'p','hint','Once issued, this company may offer commercial charter or VIP passenger services, subject to route rights, but actual flights still require separate market, route, airport, slot and safety permissions. No automatic foreign route rights or airport permissions are granted.'),
  l4Apply
 );
 section.append(l4Panel);
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
  l3Apply.disabled=!cargoStatus?.canApply;
  if(cargoStatus?.issued===true){
   l3State.textContent='Cargo operations approval issued for this company';
   l3Apply.disabled=true;
  }else if(cargoStatus?.applicationStatus==='submitted'){
   l3State.textContent='Cargo approval awaiting review'+(cargoStatus.dueGameDay?' · Due '+cargoStatus.dueGameDay:'');
   l3Apply.disabled=true;
  }else if(cargoStatus){
   l3State.textContent=cargoStatus.canApply?'Cargo licence application available':
    'Cargo licence not available · '+cargoStatus.issues.slice(0,4).map(x=>x.replaceAll('_',' ').toLowerCase()).join('; ');
   l3Apply.disabled=!cargoStatus.canApply||busy;
  }else{
   l3State.textContent='Cargo licence status not connected to the current server.';
   l3Apply.disabled=true;
  }
  l4Apply.disabled=!charterStatus?.canApply;
  if(charterStatus?.issued===true){
   l4State.textContent='Charter/VIP operations approval issued for this company';
   l4Apply.disabled=true;
  }else if(charterStatus?.applicationStatus==='submitted'){
   l4State.textContent='Charter/VIP approval awaiting review'+(charterStatus.dueGameDay?' · Due '+charterStatus.dueGameDay:'');
   l4Apply.disabled=true;
  }else if(charterStatus){
   l4State.textContent=charterStatus.canApply?'Charter/VIP licence application available':
    'Charter/VIP licence not available · '+charterStatus.issues.slice(0,4).map(x=>x.replaceAll('_',' ').toLowerCase()).join('; ');
   l4Apply.disabled=!charterStatus.canApply||busy;
  }else{
   l4State.textContent='Charter/VIP licence status not connected to the current server.';
   l4Apply.disabled=true;
  }
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
  const aoc=current?.aocStatus;
  if(!aoc){
   aocState.textContent='AOC record not connected to this server version.';
   aocDetail.textContent='No issued AOC can be assumed. The detailed status requires an updated game connection.';
  }else if(aoc.status==='planned_not_released'){
   aocState.textContent='AOC system planned — not yet enabled';
   aocDetail.textContent='Original airline: free automatic AOC when the feature launches. Separately incorporated airline subsidiaries: $10,000 and 3 game days after application. No certificate has been issued by this system.';
  }else if(aoc.status==='not_issued'){
   aocState.textContent='No AOC issued to this airline';
   aocDetail.textContent='Applications and issuance depend on the type of airline company and current game release permissions.';
  }else{
   aocState.textContent=aoc.status==='active'?'AOC active for this airline':'AOC expired for this airline';
   const rating=Number.isInteger(aoc.safetyRating?.rating)
     ?' · Safety Rating '+aoc.safetyRating.rating+'/100':'';
   aocDetail.textContent='Issued '+aoc.issuedGameDay+
     ' · Valid until '+aoc.expiresGameDay+rating+
     ' · Renewal is automatic after 365 game days when safety requirements are met.';
  }
  l2Markets.replaceChildren();
  const licence2=current?.licence2;
  if(licence2?.readOnly===true&&Array.isArray(licence2.marketLevels)){
   l2State.textContent='EU fees and processing times are owner-approved game rules. An upgrade costs the full price of the new level. Drafts can be saved, but submission, payment, licence issuance and flights are not enabled.';
   for(const market of ['L2-EU','L2-US','L2-UK','L2-JP']){
    const levels=licence2.marketLevels.filter(row=>row.marketCode===market);
    if(!levels.length)continue;
    const row=node(doc,'div','game-licence-application');
    const left=node(doc,'div','game-licence-application-text');
    left.append(node(doc,'strong','',levels[0].marketName));
    const capabilities=levels.map(level=>{
      if(!level.quotaApproved)return 'Level '+level.level+': requirements pending';
      const fee=Number.isFinite(level.approvedInitialFeeUsd)
       ?' · '+MONEY.format(level.approvedInitialFeeUsd)+
        ' initial or full-price upgrade · '+level.approvedProcessingGameDays+' game days'
       :' · Fee not approved';
      return 'Level '+level.level+': '+(level.directedRouteLimit===null?'Unlimited':String(level.directedRouteLimit))+
        ' directed routes · up to '+level.maxAirportCategory+fee;
    });
    left.append(node(doc,'small','',capabilities.join(' · ')));
    const right=node(doc,'div','game-licence-application-balance');
    const issued=levels[0].permitStatus==='approved';
    right.append(node(doc,'b','',issued?'Approved · Level '+levels[0].permitLevel:'Not issued'),
      node(doc,'small','',issued
       ?'Directed routes allocated: '+levels[0].directedRoutesUsed
       :'Applications unavailable · No fee charged'));
    const permittedLevels=levels.filter(x=>x.quotaApproved);
    if(!issued&&levels[0].applicationStatus===null&&permittedLevels.length){
     const draftActions=node(doc,'div','workspace-actions game-licence-actions');
     const levelSelect=node(doc,'select','game-licence-input');
     levelSelect.setAttribute('aria-label','Licence 2 level for '+levels[0].marketName);
     for(const tier of permittedLevels){
      const option=node(doc,'option','','Level '+tier.level);
      option.value=String(tier.level);levelSelect.append(option);
     }
     const draftButton=node(doc,'button','secondary','Save application draft');
     draftButton.type='button';draftButton.disabled=busy;
     const draftFeedback=node(doc,'span','hint','No payment or submission. Eligibility is checked at final submission.');
     draftFeedback.setAttribute('role','status');
     draftButton.addEventListener('click',async()=>{
      if(busy||getAirline()?.id!==loadedAirline)return;
      const api=getClient();
      if(typeof api?.saveLicence2Draft!=='function'){
       draftFeedback.textContent='Draft service unavailable.';return;
      }
      const expectedId=loadedAirline;
      busy=true;draftButton.disabled=true;
      draftFeedback.textContent='Saving draft…';
      try{
       const result=await api.saveLicence2Draft({
        airlineId:expectedId,marketCode:market,level:Number(levelSelect.value)});
       if(getAirline()?.id!==expectedId)return;
       draftFeedback.textContent=result.created
        ?'Draft saved. No application submitted and no money charged.'
        :result.status==='EXISTING_APPLICATION_ALREADY_OPEN'
          ?'An application draft or submission already exists for this market.'
          :'Unable to create draft: '+result.status.replaceAll('_',' ').toLowerCase()+'.';
       if(result.created)await load({refresh:true});
      }catch{
       draftFeedback.textContent='Could not confirm the draft. Please refresh before trying again.';
      }finally{busy=false;draftButton.disabled=false;}
     });
     draftActions.append(levelSelect,draftButton,draftFeedback);
     left.append(draftActions);
    }
    if(!issued&&levels[0].applicationStatus!==null){
     const application=levels[0];
     const statusText=application.applicationStatus==='draft'
      ?'Saved draft · Level '+application.requestedLevel+' · Not submitted'
      :'Application '+application.applicationStatus+' · Level '+application.requestedLevel;
     left.append(node(doc,'p','hint',statusText));
     if(application.draftIssues?.length){
      const detail=node(doc,'p','hint','Last checked requirements: '+
       application.draftIssues.slice(0,12).map(s=>s.replaceAll('_',' ').toLowerCase()).join('; ')+
       '. Requirements are checked again before submission.');
      left.append(detail);
     }
     if(application.applicationStatus==='draft'&&application.draftApplicationId){
      const tools=node(doc,'div','workspace-actions game-licence-actions');
      const refresh=node(doc,'button','secondary','Refresh requirements');
      refresh.type='button';refresh.disabled=busy;
      const withdraw=node(doc,'button','secondary','Withdraw draft');
      withdraw.type='button';
      const info=node(doc,'span','hint','Removes this unfinished application. No payment.');
      info.setAttribute('role','status');
      refresh.addEventListener('click',async()=>{
       if(busy||getAirline()?.id!==loadedAirline)return;
       const api=getClient();
       if(typeof api?.refreshLicence2Draft!=='function'){
        info.textContent='Requirements refresh service unavailable.';return;
       }
       const expectedId=loadedAirline;
       busy=true;refresh.disabled=true;withdraw.disabled=true;
       info.textContent='Checking current requirements…';
       try{
        const result=await api.refreshLicence2Draft({
         airlineId:expectedId,applicationId:application.draftApplicationId});
        if(getAirline()?.id!==expectedId)return;
        info.textContent=result.refreshed
          ?'Requirements updated. No payment or submission.'
          :'Requirements could not be refreshed: '+result.status.replaceAll('_',' ').toLowerCase()+'.';
        if(result.refreshed)await load({refresh:true});
       }catch{info.textContent='Requirements could not be checked. Please retry.';}
       finally{busy=false;refresh.disabled=false;withdraw.disabled=false;}
      });
      withdraw.addEventListener('click',async()=>{
       if(busy||getAirline()?.id!==loadedAirline)return;
       const api=getClient();
       if(typeof api?.withdrawLicence2Draft!=='function'){
        info.textContent='Withdrawal service unavailable.';return;
       }
       busy=true;withdraw.disabled=true;info.textContent='Withdrawing draft…';
       const expectedId=loadedAirline;
       try{
        const result=await api.withdrawLicence2Draft({
         airlineId:expectedId,applicationId:application.draftApplicationId});
        if(getAirline()?.id!==expectedId)return;
        info.textContent=result.withdrawn?'Draft withdrawn. No fee charged.':
         'Draft could not be withdrawn: '+result.status.replaceAll('_',' ').toLowerCase()+'.';
        if(result.withdrawn)await load({refresh:true});
       }catch{info.textContent='Could not confirm withdrawal. Refresh to check status.';}
       finally{busy=false;withdraw.disabled=false;}
      });
      tools.append(refresh,withdraw,info);left.append(tools);
     }
    }
    row.append(left,right);l2Markets.append(row);
   }
  }else{
   l2State.textContent='Foreign-network licence status is not connected to this server version. No Licence 2 is assumed.';
  }
  note.textContent=current?.canApply
   ?'Game applications are enabled for eligible permissions. Issuance still requires independent review.'
   :'Applications are not open. You may review requirements and your application history; no money will be deducted.';
  updateForm();
 };
 l3Apply.addEventListener('click',async()=>{
  if(busy||cargoStatus?.canApply!==true||getAirline()?.id!==loadedAirline)return;
  const api=getClient();
  if(typeof api?.submitCargoLicence3!=='function')return;
  const id=loadedAirline;
  if(!cargoRequestKey)cargoRequestKey=newRequestKey();
  busy=true;l3Apply.disabled=true;l3State.textContent='Submitting cargo application…';
  try{
   const result=await api.submitCargoLicence3({airlineId:id,requestKey:cargoRequestKey});
   if(getAirline()?.id!==id)return;
   if(result.submitted)cargoRequestKey=null;
   l3State.textContent=result.submitted?'Cargo application recorded. No fee charged.':
    'Cargo application unavailable: '+result.status.replaceAll('_',' ').toLowerCase();
   await load({refresh:true});
  }catch{l3State.textContent='Cargo submission could not be confirmed. Please retry.';}
  finally{busy=false;l3Apply.disabled=!cargoStatus?.canApply;}
 });
 l4Apply.addEventListener('click',async()=>{
  if(busy||charterStatus?.canApply!==true||getAirline()?.id!==loadedAirline)return;
  const api=getClient();
  if(typeof api?.submitCharterLicence4!=='function')return;
  const id=loadedAirline;
  if(!charterRequestKey)charterRequestKey=newRequestKey();
  busy=true;l4Apply.disabled=true;l4State.textContent='Submitting charter application…';
  try{
   const result=await api.submitCharterLicence4({airlineId:id,requestKey:charterRequestKey});
   if(getAirline()?.id!==id)return;
   if(result.submitted)charterRequestKey=null;
   l4State.textContent=result.submitted?'Charter/VIP application recorded. No fee charged.':
    'Charter/VIP application unavailable: '+result.status.replaceAll('_',' ').toLowerCase();
   await load({refresh:true});
  }catch{l4State.textContent='Charter/VIP submission could not be confirmed. Please retry.';}
  finally{busy=false;l4Apply.disabled=!charterStatus?.canApply;}
 });
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
  loadedAirline=id??null;current=null;cargoStatus=null;charterStatus=null;submit.disabled=true;l3Apply.disabled=true;l4Apply.disabled=true;
  if(!id||!client){
   note.textContent='Select a verified airline to view your game licence applications.';
   aocState.textContent='AOC details unavailable for the selected airline.';
   l2Markets.replaceChildren();
   l2State.textContent='Select a verified airline to view Licence 2 market status.';
   aocDetail.textContent='No company licence is inferred without verified server data.';
   fields.forEach(v=>{v.textContent='—';});
   list.replaceChildren(node(doc,'p','hint','No verified application data is available.'));
   type.replaceChildren();updateForm();return;
  }
  note.textContent='Checking current game permissions…';
  try{
   const result=await client.status(id);
   if(requestVersion!==version||getAirline()?.id!==id)return;
   current=result;
   if(typeof client.cargoLicence3Status==='function'){
    try{cargoStatus=await client.cargoLicence3Status(id);}
    catch{cargoStatus=null;}
   }
   if(typeof client.charterLicence4Status==='function'){
    try{charterStatus=await client.charterLicence4Status(id);}
    catch{charterStatus=null;}
   }
   if(requestVersion!==version||getAirline()?.id!==id)return;
   render();
  }catch{
   if(requestVersion!==version)return;
   note.textContent='Permission status is temporarily unavailable. No licence or fee can be assumed.';
   aocState.textContent='AOC status temporarily unavailable.';
   l2Markets.replaceChildren();
   l2State.textContent='Licence 2 status unavailable. No permit or fee is assumed.';
   aocDetail.textContent='No active AOC is assumed while the owner-verified status cannot be read.';
   fields.forEach(v=>{v.textContent='—';});
   list.replaceChildren(node(doc,'p','hint','The protected permission API could not be reached.'));
   type.replaceChildren();updateForm();
  }
 }
 return Object.freeze({load,updateForm});
}
