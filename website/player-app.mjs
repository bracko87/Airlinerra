/** Real, verified manager dashboard and backend-gated onboarding.
 * Gameplay flight operations remain separately disabled.
 */
import {inspectInvitedTesterProvider,TESTER_ORIGIN} from './invited-tester-entry.mjs';
import {createInvitedTesterAuth,LOCAL_REAL_AUTH_ORIGIN} from './invited-tester-auth.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from './tester-dashboard-state.mjs';
import {createPlayerReadClient,PLAYER_READ_API_ENABLED} from './player-read-client.mjs';
import {createRealOnboardingClient} from './real-onboarding-client.mjs';
import {createLocalCatalogClient} from './local-catalog-client.mjs';
import {saveLocalDraft,readLocalDraft,clearLocalDraft} from './local-onboarding-draft.mjs';
import {isLocalDemoOrigin,hasLocalDemo,endLocalDemo,getLocalTestProfile,LOCAL_DEMO_MANAGER,LOCAL_DEMO_LOGIN_PATH} from './local-demo-session.mjs';
import {
  PLAYER_APP_PATH,PLAYER_LOGIN_PATH,PLAYER_VIEWS,WORLD_LABELS,
  safePlayerView,playerViewUrl,verifiedManagerIdentity,onboardingReadiness
} from './player-app-model.mjs';

const doc=window.document;
const loading=doc.getElementById('player-loading');
const denied=doc.getElementById('player-denied');
const app=doc.getElementById('player-app');
const signOut=doc.getElementById('player-sign-out');
let auth=null;
let preview=false;
function visible(view){
  loading.hidden=view!=='loading';
  denied.hidden=view!=='denied';
  app.hidden=view!=='app';
}
function navigateTo(view){
  const name=safePlayerView('#'+view);
  for(const section of doc.querySelectorAll('[data-player-view]')){
    section.hidden=section.dataset.playerView!==name;
  }
  for(const link of doc.querySelectorAll('[data-view-link]')){
    if(link.dataset.viewLink===name)link.setAttribute('aria-current','page');
    else link.removeAttribute('aria-current');
  }
  doc.title='Airlinerra — '+name[0].toUpperCase()+name.slice(1)+' · Private prelaunch';
  // Close dropdowns when changing pages, preserving keyboard navigation.
  for(const group of doc.querySelectorAll('.nav-group[open]'))group.open=false;
}
function drawWorldDirectory(){
  const root=doc.getElementById('world-directory');
  root.replaceChildren();
  for(const world of WORLD_LABELS){
    const card=doc.createElement('article');
    card.className='world-card';
    const eyebrow=doc.createElement('span');eyebrow.className='world-number';eyebrow.textContent='AIRLINERRA · WORLD '+String(world.id).padStart(2,'0');
    const name=doc.createElement('h2');name.textContent=world.name;
    const description=doc.createElement('p');description.textContent='Independent airline economy · 1 real day = 1 game day.';
    const status=doc.createElement('span');status.className='pill';status.textContent=world.status+' · Not selectable';
    card.append(eyebrow,name,description,status);
    root.append(card);
  }
}
function setManager(user){
  const manager=verifiedManagerIdentity(user);
  if(!manager)throw new PrivateTesterAccessDenied();
  doc.getElementById('manager-name').textContent=manager.name;
  doc.getElementById('manager-email').textContent=manager.email;
  doc.getElementById('manager-joined').textContent=manager.joined||'Not provided';
  doc.getElementById('setup-email').textContent=manager.email;
  doc.getElementById('top-email').textContent=manager.email;
}
let playerData=null;
let onboarding=null;
let onboardingContext=null;
let hasRealAirline=false;
let nextAirportOffset=null;
function fillCountries(countries){
  for(const id of ['setup-country','airports-country']){
    const select=doc.getElementById(id);
    select.replaceChildren(new Option('Select a country',''));
    for(const c of countries){
      if(typeof c.countryIso==='string'&&/^[A-Z]{2}$/.test(c.countryIso)&&Number.isInteger(c.airportCount)){
        const countryName=typeof Intl.DisplayNames==='function'
          ?new Intl.DisplayNames(['en'],{type:'region'}).of(c.countryIso)
          :c.countryIso;
        select.append(new Option((countryName||c.countryIso)+' ('+c.airportCount+' airports)',c.countryIso));
      }
    }
    select.disabled=false;
  }
  doc.getElementById('setup-airport').disabled=false;
  doc.getElementById('setup-airport-search').disabled=false;
  doc.getElementById('airports-query').disabled=false;
  doc.getElementById('airports-search').disabled=false;
  // No browser-only creation. The server releases the real wizard only after
  // verifying the current legal policy and a registration-open world.
}
function drawRealWorlds(worlds){
  const root=doc.getElementById('world-directory');
  root.replaceChildren();
  const options=doc.getElementById('setup-world');
  options.replaceChildren(new Option('Select a world',''));
  for(const world of worlds){
    const name='World '+String(world.id).padStart(2,'0');
    const card=doc.createElement('article');card.className='world-card';
    const header=doc.createElement('span');header.className='world-number';header.textContent='DATABASE · WORLD '+String(world.id).padStart(2,'0');
    const title=doc.createElement('h2');title.textContent=world.name;
    const status=doc.createElement('span');status.className='pill';status.textContent=world.state+' · '+(world.state==='planned'?'Registration closed':'Awaiting game release');
    card.append(header,title,status);root.append(card);
    options.append(new Option(name+' — '+world.state,String(world.id)));
  }
  // Read-only choices can be inspected, but create-airline stays disabled.
  options.disabled=false;
}
async function airportSearch({setup=false,offset=0}={}){
  if(!playerData)return;
  const select=doc.getElementById(setup?'setup-country':'airports-country');
  const search=doc.getElementById(setup?'setup-airport':'airports-query').value.trim();
  const countryIso=select.value;
  const output=doc.getElementById(setup?'setup-airport-results':'airport-results');
  if(!/^[A-Z]{2}$/.test(countryIso))return;
  try{
    const result=await playerData.airports({countryIso,search,offset});
    if(!Array.isArray(result.airports))throw Error('Invalid directory');
    if(setup){
      output.replaceChildren(new Option('Choose a home airport',''));
      for(const airport of result.airports)output.append(new Option(
        airport.name+' ('+airport.code+')',airport.key));
      output.disabled=result.airports.length===0;
    }else{
      if(offset===0)output.replaceChildren();
      for(const airport of result.airports){
        const row=doc.createElement('div');row.className='airport-result';
        const name=doc.createElement('strong');name.textContent=airport.name+' ('+airport.code+')';
        const place=doc.createElement('span');place.textContent=airport.countryIso+(airport.municipality?' · '+airport.municipality:'');
        row.append(name,place);output.append(row);
      }
      if(!output.children.length)output.textContent='No matching airports in this search.';
      nextAirportOffset=Number.isInteger(result.nextOffset)?result.nextOffset:null;
      const more=doc.getElementById('airports-more');
      more.hidden=nextAirportOffset===null;more.disabled=more.hidden;
    }
  }catch{
    if(setup){output.replaceChildren(new Option('Airport service not available',''));output.disabled=true;}
    else output.textContent='The airport service is unavailable. Try again after the private API is enabled.';
  }
}
async function loadPlayerReadData({local=false}={}){
  if(!auth)return; // The same protected API is used on localhost and the published site.
  try{
    playerData=createPlayerReadClient({auth,origin:window.location.origin,enabled:true,local});
    const data=await playerData.overview();
    if(!Array.isArray(data.worlds)||!Array.isArray(data.countries)||!Array.isArray(data.airlines))throw Error('Invalid data');
    drawRealWorlds(data.worlds);
    fillCountries(data.countries);
    const first=data.airlines[0];
    hasRealAirline=Boolean(first?.name);
    if(first?.name){
      doc.getElementById('top-world').textContent='WORLD '+String(first.worldId).padStart(2,'0')+' · PRELAUNCH';
      doc.getElementById('top-airline-state').textContent=first.name+
        (first.premiumUnlimited===true?' · Premium Unlimited':' · Registered airline');
      doc.getElementById('player-airline-name').textContent=first.name;
      doc.getElementById('player-cash').textContent=first.cashUsd+' USD';
    }else{
      doc.getElementById('top-airline-state').textContent='No airline created · Complete airline setup';
      doc.getElementById('top-world').textContent='WORLD 01 · REGISTRATION';
    }
    doc.getElementById('player-data-status').textContent=local
      ?'LIVE SUPABASE · Verified account · Read-only player data'
      :'Live private database · Read only';
    doc.getElementById('airport-heading').textContent='Approved airport directory';
    doc.getElementById('airport-description').textContent=data.airportsTotal+' approved simulation airports available for read-only lookup.';
    // Actual airline setup must be saved by the protected backend.
    await loadRealOnboarding();
    if(!hasRealAirline && safePlayerView(window.location.hash)==='overview'){
      window.history.replaceState({},'',playerViewUrl('onboarding'));
      navigateTo('onboarding');
    }
  }catch{
    playerData=null;
    doc.getElementById('player-data-status').textContent=local
      ?'Live read-only API unavailable; configure local trusted database backend'
      :'Private game database not connected';
  }
}
function renderSavedDraft(draft){
 const output=doc.getElementById('setup-draft-review');
 output.replaceChildren();
 for(const [key,value] of [
  ['World','World '+String(draft.worldId).padStart(2,'0')],
  ['Country',draft.countryIso],['Approved airport',draft.airportKey],
  ['Airline name',draft.airlineName]
 ]){
  const p=doc.createElement('p'),b=doc.createElement('strong');
  b.textContent=key+': ';p.append(b,doc.createTextNode(value));output.append(p);
 }
 doc.getElementById('setup-draft-summary').hidden=false;
 doc.getElementById('setup-draft-feedback').textContent='Saved in this browser tab only. No airline or legal acceptance was created.';
}
async function restoreSetupDraft(){
 if(!preview||!playerData)return;
 const saved=readLocalDraft(window.sessionStorage,window.location);
 if(!saved)return;
 doc.getElementById('setup-world').value=String(saved.worldId);
 doc.getElementById('setup-country').value=saved.countryIso;
 doc.getElementById('setup-airline-name').value=saved.airlineName;
 try{
  const data=await playerData.airports({countryIso:saved.countryIso,airportKey:saved.airportKey});
  const select=doc.getElementById('setup-airport-results');
  select.replaceChildren(new Option('Choose a home airport',''));
  for(const a of data.airports)select.append(new Option(a.name+' ('+a.code+')',a.key));
  select.disabled=data.airports.length===0;
  if(data.airports.some(x=>x.key===saved.airportKey))select.value=saved.airportKey;
 }catch{/* Saved draft still shown, cannot confirm airport in this page */}
 renderSavedDraft(saved);
}

async function loadRealOnboarding(){
 if(!auth)return;
 const status=doc.getElementById('setup-draft-feedback');
 if(hasRealAirline){
   onboardingContext=null;
   doc.getElementById('setup-create-airline').disabled=true;
   status.textContent='Your real airline already exists. It is saved in Supabase and visible on the Overview page.';
   return;
 }
 onboarding=createRealOnboardingClient({auth,origin:window.location.origin});
 try{
  const ctx=await onboarding.context();
  if(!ctx?.policy||!Array.isArray(ctx.worlds)||ctx.worlds.length===0)
   throw Error('No eligible worlds for this manager');
  onboardingContext=ctx;
  const options=doc.getElementById('setup-world');
  options.replaceChildren(new Option('Choose a world',''));
  for(const world of ctx.worlds)options.append(new Option(world.name,String(world.worldId)));
  options.disabled=false;
  const info=doc.getElementById('setup-legal-approval');
  info.replaceChildren();
  for(const [name,url] of [['Terms',ctx.policy.termsUrl],['Privacy',ctx.policy.privacyUrl]]){
   const link=doc.createElement('a');link.href=url;link.target='_blank';
   link.rel='noopener noreferrer';link.textContent=name+' · Review full document';
   info.append(link,doc.createTextNode('  '));
  }
  doc.getElementById('setup-terms-version').textContent=ctx.privatePilot?'private pilot':ctx.policy.termsVersion;
  doc.getElementById('setup-terms-description').textContent=ctx.privatePilot
    ?' I acknowledge the Terms review draft ':' I accept the published Terms ';
  doc.getElementById('setup-privacy-version').textContent=ctx.privatePilot?'review draft':ctx.policy.privacyVersion;
  doc.getElementById('setup-privacy-description').textContent=ctx.privatePilot
    ?' I acknowledge the Privacy review draft ':' I acknowledge the Privacy Policy ';
  for(const id of ['setup-airline-name','setup-accept-terms','setup-accept-privacy','setup-create-airline'])
   doc.getElementById(id).disabled=false;
  status.textContent=ctx.privatePilot
    ?'Invitation-only owner pilot: review drafts are not published Terms or Privacy. Unlimited premium, no expiry and no billing.'
    :'Official documents and eligible worlds loaded from the protected database.';
 }catch{
  onboardingContext=null;
  status.textContent='Registration is not open yet. The official legal policy and World 1 must be approved before real airline creation.';
 }
}
doc.getElementById('setup-create-airline').addEventListener('click',async()=>{
 const status=doc.getElementById('setup-draft-feedback');
 if(!onboardingContext||!onboarding)return;
 const btn=doc.getElementById('setup-create-airline');
 btn.disabled=true;
 try{
  const worldId=Number(doc.getElementById('setup-world').value);
  const country=doc.getElementById('setup-country').value;
  const home=doc.getElementById('setup-airport-results').value;
  const airlineName=doc.getElementById('setup-airline-name').value.trim();
  const allowedWorld=onboardingContext.worlds.find(w=>w.worldId===worldId);
  if(!allowedWorld?.airports.some(a=>a.key===home))throw Error('Select an approved home airport for an open world.');
  if(!/^[A-Z]{2}$/.test(country))throw Error('Select a country');
  if(!doc.getElementById('setup-accept-terms').checked||
     !doc.getElementById('setup-accept-privacy').checked)
   throw Error('Read and accept both official policy documents');
  await onboarding.acceptLegal({
   termsVersion:onboardingContext.policy.termsVersion,
   privacyVersion:onboardingContext.policy.privacyVersion
  });
  const record=await onboarding.createAirline({worldId,homeAirportKey:home,airlineName});
  if(!record?.airlineId)throw Error('Airline ID not returned');
  status.textContent='Airline created and saved to Supabase. Your dashboard is ready.';
  doc.getElementById('player-airline-name').textContent=airlineName;
  doc.getElementById('player-cash').textContent=String(record.cashUsd)+' USD';
  await loadPlayerReadData({local:window.location.origin==='http://localhost:5188'});
  window.history.replaceState({},'','/player.html#overview');navigateTo('overview');
 }catch(error){
  status.textContent=error?.message||'Airline creation failed. No money was credited.';
 }finally{btn.disabled=false;}
});
doc.getElementById('setup-save-draft').addEventListener('click',()=>{
 if(!preview||!playerData)return;
 const airport=doc.getElementById('setup-airport-results');
 if(airport.disabled||!airport.value){
  doc.getElementById('setup-draft-feedback').textContent='Search and select an approved home airport first.';
  return;
 }
 try{
  const data=saveLocalDraft(window.sessionStorage,window.location,{
   worldId:Number(doc.getElementById('setup-world').value),
   countryIso:doc.getElementById('setup-country').value,
   airportKey:airport.value,
   airlineName:doc.getElementById('setup-airline-name').value
  });
  renderSavedDraft(data);
 }catch{
  doc.getElementById('setup-draft-feedback').textContent='Choose world, country, home airport and airline name (3–60 characters).';
 }
});
doc.getElementById('setup-clear-draft').addEventListener('click',()=>{
 if(!preview)return;
 clearLocalDraft(window.sessionStorage,window.location);
 for(const id of ['setup-world','setup-country'])doc.getElementById(id).selectedIndex=0;
 for(const id of ['setup-airport','setup-airline-name'])doc.getElementById(id).value='';
 doc.getElementById('setup-airport-results').replaceChildren(new Option('No results loaded',''));
 doc.getElementById('setup-airport-results').disabled=true;
 doc.getElementById('setup-draft-summary').hidden=true;
 doc.getElementById('setup-draft-feedback').textContent='Local draft cleared. No airline was created.';
});
doc.getElementById('settings-save').addEventListener('click',()=>{
 if(!preview)return;
 const units=doc.getElementById('settings-units').value,time=doc.getElementById('settings-time').value;
 if(!['km','mi'].includes(units)||!['12','24'].includes(time))return;
 window.sessionStorage.setItem('airlinerra-local-demo-preferences',JSON.stringify({units,time}));
 doc.getElementById('settings-feedback').textContent='Saved in this browser tab only.';
});
function prepareDemoSettings(){
 if(!preview)return;
 for(const id of ['settings-units','settings-time','settings-save'])doc.getElementById(id).disabled=false;
 try{
  const d=JSON.parse(window.sessionStorage.getItem('airlinerra-local-demo-preferences')||'null');
  if(d&&['km','mi'].includes(d.units))doc.getElementById('settings-units').value=d.units;
  if(d&&['12','24'].includes(d.time))doc.getElementById('settings-time').value=d.time;
 }catch{/* no persisted settings */}
}
doc.getElementById('setup-country').addEventListener('change',()=>{
 const select=doc.getElementById('setup-airport-results');
 select.replaceChildren(new Option('Search and select an airport',''));
 select.disabled=true;
 doc.getElementById('setup-draft-feedback').textContent='Search for a home airport in the selected country.';
});
doc.getElementById('setup-airport-search').addEventListener('click',()=>{void airportSearch({setup:true});});
doc.getElementById('airports-search').addEventListener('click',()=>{nextAirportOffset=null;void airportSearch();});
doc.getElementById('airports-more').addEventListener('click',()=>{if(nextAirportOffset!==null)void airportSearch({offset:nextAirportOffset});});
function showPreview(){
  preview=true;
  doc.getElementById('local-preview-note').hidden=false;
  doc.getElementById('local-preview-note').textContent='LOCAL DEMO ONLY — no real identity, database connection or airline activation.';
  const localTest=getLocalTestProfile(window.sessionStorage,window.location);
  const profile=localTest||LOCAL_DEMO_MANAGER;
  doc.getElementById('manager-name').textContent=profile.name;
  for(const id of ['manager-email','setup-email'])doc.getElementById(id).textContent=profile.email;
  doc.getElementById('top-email').textContent=localTest?'LOCAL TEST ACCOUNT · Not Supabase':'LOCAL DEMO · Not signed in';
  doc.getElementById('manager-joined').textContent='Demo session';
  // Do not claim a verified Supabase account in an unauthenticated preview.
  doc.getElementById('manager-verified').textContent=localTest?'Email confirmed in local simulation · Not Supabase':'Demo only · Not verified';
  doc.getElementById('setup-account-state').textContent=localTest?'Local test complete':'Demo';
  doc.getElementById('setup-account-state').classList.remove('step-good');
  doc.getElementById('setup-email').closest('.step').querySelector('p').firstChild.textContent='Simulated manager; no invitation verified. ';
  doc.getElementById('player-data-status').textContent='Simulated navigation; protected game API is not connected';
  signOut.disabled=false;
  doc.title='Airlinerra — LOCAL DEMO · Player dashboard';
  visible('app');
}
async function initialize(){
  drawWorldDirectory();
  // A static preview never checks the live user's credentials.
  const isLocal=isLocalDemoOrigin(window.location);
  const selected=safePlayerView(window.location.hash);
  window.history.replaceState({},'',playerViewUrl(selected));
  navigateTo(selected);
  const readiness=onboardingReadiness();
  if(readiness.canCreate)throw Error('Prelaunch creation gate unexpectedly enabled.');
  if(isLocal){
    const conf=window.__AIRLINERRA_INVITED_TESTER_CONFIG__;
    try{
      if(conf?.operatorPrelaunchApproved!==true||
         conf.supabaseUrl!=='https://hwllkabgzaynalahvkpz.supabase.co'||
         typeof conf.publishableKey!=='string')throw Error('Invalid provider');
      await inspectInvitedTesterProvider({publishableKey:conf.publishableKey});
      auth=await createInvitedTesterAuth({
        origin:LOCAL_REAL_AUTH_ORIGIN,supabaseUrl:conf.supabaseUrl,
        publishableKey:conf.publishableKey
      });
      setManager(await auth.getUser());
      doc.getElementById('local-preview-note').hidden=false;
      doc.getElementById('local-preview-note').textContent='Verified live Supabase identity · Production game gates enforced';
      visible('app');
      await loadPlayerReadData({local:true});
    }catch{
      window.location.replace(LOCAL_DEMO_LOGIN_PATH);
    }
    return;
  }
  if(window.location.origin!==TESTER_ORIGIN||window.location.pathname!==PLAYER_APP_PATH){
    visible('denied');return;
  }
  try{
    const session=await openPrivateTesterDashboard({
      origin:window.location.origin,pathname:window.location.pathname,
      config:window.__AIRLINERRA_INVITED_TESTER_CONFIG__,
      inspectProvider:inspectInvitedTesterProvider,createAuth:createInvitedTesterAuth
    });
    auth=session.auth;
    setManager(session.user);
    visible('app');
    await loadPlayerReadData();
  }catch(err){
    if(err instanceof PrivateTesterAccessDenied){
      window.location.replace(PLAYER_LOGIN_PATH);return;
    }
    visible('denied');
  }
}
doc.querySelectorAll('.nav-group').forEach(group=>group.addEventListener('toggle',()=>{
  if(!group.open)return;
  for(const other of doc.querySelectorAll('.nav-group[open]'))if(other!==group)other.open=false;
}));
doc.addEventListener('click',event=>{
  if(event.target.closest('.app-navigation'))return;
  for(const group of doc.querySelectorAll('.nav-group[open]'))group.open=false;
});
doc.addEventListener('keydown',event=>{
  if(event.key!=='Escape')return;
  for(const group of doc.querySelectorAll('.nav-group[open]')){
    group.open=false;
    group.querySelector('summary')?.focus();
  }
});
doc.querySelectorAll('[data-view-link]').forEach(link=>link.addEventListener('click',e=>{
  e.preventDefault();
  window.history.replaceState({},'',playerViewUrl(link.dataset.viewLink));
  navigateTo(link.dataset.viewLink);
}));
doc.querySelectorAll('[data-go-view]').forEach(button=>button.addEventListener('click',()=>{
  const view=button.dataset.goView;
  window.history.replaceState({},'',playerViewUrl(view));
  navigateTo(view);
}));
window.addEventListener('hashchange',()=>navigateTo(safePlayerView(window.location.hash)));
signOut.addEventListener('click',async()=>{
  if(!auth)return;
  signOut.disabled=true;
  try{
    await auth.signOut();window.location.replace(PLAYER_LOGIN_PATH);
  }catch{signOut.disabled=false;window.alert('Sign out could not be completed. Please retry.');}
});
visible('loading');
void initialize().catch(()=>visible('denied'));
