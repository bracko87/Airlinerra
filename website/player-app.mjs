/** Real, verified manager dashboard and backend-gated onboarding.
 * Gameplay flight operations remain separately disabled.
 */
import {inspectInvitedTesterProvider,TESTER_ORIGIN} from './invited-tester-entry.mjs';
import {createInvitedTesterAuth,LOCAL_REAL_AUTH_ORIGIN} from './invited-tester-auth.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from './tester-dashboard-state.mjs';
import {createPlayerReadClient,PLAYER_READ_API_ENABLED} from './player-read-client.mjs';
import {createRealOnboardingClient} from './real-onboarding-client.mjs';
import {createDownwardMenu} from './setup-choice-menu.mjs';
import {createLocalCatalogClient} from './local-catalog-client.mjs';
import {saveLocalDraft,readLocalDraft,clearLocalDraft} from './local-onboarding-draft.mjs';
import {isLocalDemoOrigin,hasLocalDemo,endLocalDemo,getLocalTestProfile,LOCAL_DEMO_MANAGER,LOCAL_DEMO_LOGIN_PATH} from './local-demo-session.mjs';
import {
  PLAYER_APP_PATH,PLAYER_LOGIN_PATH,PLAYER_VIEWS,WORLD_LABELS,
  safePlayerView,playerViewUrl,verifiedManagerIdentity,onboardingReadiness,managerLandingView
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
  doc.title='Airlinerra - '+name[0].toUpperCase()+name.slice(1);
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
// Initial verified login is redirected; explicit later navigation is respected.
let initialManagerLanding=false;
let nextAirportOffset=null;
let setupAirportRequest=0,logoBlob=null,logoObjectUrl=null;
const countryNameOf=code=>typeof Intl.DisplayNames==='function'
 ?new Intl.DisplayNames(['en'],{type:'region'}).of(code):code;
const collator=new Intl.Collator('en',{sensitivity:'base'});
const menus=Object.fromEntries([['setup-world',false],['setup-country',true],['setup-airport-results',false],['airports-country',true]]
 .map(([id,flags])=>[id,createDownwardMenu(doc.getElementById(id),{flags})]));
function refreshMenu(id){menus[id]?.refresh();}
const SIX_CATEGORIES=new Set(['Local','Regional','Medium','Large','Major Hub','Mega Hub']);
function selectedAirport(){
 const worldId=Number(doc.getElementById('setup-world').value);
 const key=doc.getElementById('setup-airport-results').value;
 return onboardingContext?.worlds.find(w=>w.worldId===worldId)?.airports.find(a=>a.key===key)||null;
}
function demandScale(label,value){
 const output=doc.getElementById('airport-'+label+'-demand');
 const scale=doc.getElementById('airport-'+label+'-scale');
 const valid=typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=100;
 output.textContent=valid?Math.round(value)+'%':'Data pending';
 scale.replaceChildren();
 if(valid){
  const fill=doc.createElement('span');fill.className='demand-bar-fill';
  fill.style.width=value+'%';scale.append(fill);
 }
 scale.setAttribute('aria-label',valid
  ?label+' demand '+Math.round(value)+' percent'
  :label+' demand has not yet been calculated');
}
function updateAirportDetails(){
 const airport=selectedAirport();
 doc.getElementById('airport-details-empty').hidden=Boolean(airport);
 doc.getElementById('airport-details-content').hidden=!airport;
 if(!airport)return;
 const put=(id,value)=>{doc.getElementById(id).textContent=value||'Not available';};
 put('airport-details-name',airport.name);
 put('airport-details-code',airport.code);
 put('airport-details-location',[airport.municipality,countryNameOf(airport.countryIso)].filter(Boolean).join(', '));
 put('airport-details-category',SIX_CATEGORIES.has(airport.category)?airport.category:'Not classified');
 put('airport-details-category-note',airport.categoryFinalized?'Category finalized': 'Category provisional');
 put('airport-details-runway',Number.isFinite(airport.runwayLengthM)?airport.runwayLengthM.toLocaleString('en')+' m':null);
 put('airport-details-surface',airport.runwaySurface);
 const coords=Number.isFinite(airport.latitude)&&Number.isFinite(airport.longitude)
  ?airport.latitude.toFixed(4)+', '+airport.longitude.toFixed(4):null;
 put('airport-details-coordinates',coords);
 put('airport-details-type',airport.key.startsWith('FICTIONAL:')?'Fictional game airport':'Real-world airport');
 demandScale('passenger',airport.passengerDemandPct);
 demandScale('cargo',airport.cargoDemandPct);
}
function summarize(){
 const world=doc.getElementById('setup-world'),country=doc.getElementById('setup-country');
 const airport=doc.getElementById('setup-airport-results');
 const name=doc.getElementById('setup-airline-name').value.trim();
 doc.getElementById('summary-airline-name').textContent=name||'Not entered';
 doc.getElementById('summary-world').textContent=world.value?(world.selectedOptions[0]?.textContent||'World 01'):'Not selected';
 doc.getElementById('summary-country').textContent=country.value?countryNameOf(country.value):'Not selected';
 doc.getElementById('summary-airport').textContent=airport.value?(airport.selectedOptions[0]?.textContent||'Not selected'):'Not selected';
 updateAirportDetails();
}
function fillCountries(countries){
 const normalized=countries.filter(c=>typeof c.countryIso==='string'&&
  /^[A-Z]{2}$/.test(c.countryIso)&&Number.isInteger(c.airportCount)&&c.airportCount>0)
  .sort((a,b)=>collator.compare(countryNameOf(a.countryIso),countryNameOf(b.countryIso)));
 for(const id of ['airports-country']){
  const select=doc.getElementById(id);
  select.replaceChildren(new Option('Select a country',''));
  for(const c of normalized)select.append(new Option(countryNameOf(c.countryIso)+' ('+c.airportCount+' airports)',c.countryIso));
  select.disabled=false;refreshMenu(id);
 }
 doc.getElementById('airports-query').disabled=false;
 doc.getElementById('airports-search').disabled=false;
 summarize();
}
function fillSetupCountries(){
 const worldId=Number(doc.getElementById('setup-world').value);
 const world=onboardingContext?.worlds.find(w=>w.worldId===worldId);
 const countries=doc.getElementById('setup-country');
 const counts=new Map();
 for(const a of world?.airports||[]){
  if(!/^[A-Z]{2}$/.test(a.countryIso||''))continue;
  counts.set(a.countryIso,(counts.get(a.countryIso)||0)+1);
 }
 const sorted=[...counts].sort((a,b)=>collator.compare(countryNameOf(a[0]),countryNameOf(b[0])));
 countries.replaceChildren(new Option('Select a country',''));
 for(const [code,count] of sorted)countries.append(
  new Option(countryNameOf(code)+' ('+count+' airports)',code));
 countries.disabled=sorted.length===0;
 const airports=doc.getElementById('setup-airport-results');
 airports.replaceChildren(new Option('Select a country first',''));airports.disabled=true;
 refreshMenu('setup-country');refreshMenu('setup-airport-results');summarize();
}
function loadSetupAirports({initialKey=''}={}){
 const worldId=Number(doc.getElementById('setup-world').value);
 const country=doc.getElementById('setup-country').value;
 const output=doc.getElementById('setup-airport-results');
 const world=onboardingContext?.worlds.find(w=>w.worldId===worldId);
 // Only the protected, freshly verified backend context may supply choices.
 const airports=(world?.airports||[]).filter(a=>
  a.countryIso===country&&typeof a.name==='string'&&typeof a.key==='string');
 airports.sort((a,b)=>collator.compare(a.name,b.name)||collator.compare(a.code||'',b.code||''));
 output.replaceChildren(new Option(!country?'Select a country first':
  airports.length?'Select a home airport':'No approved airports',''));
 for(const a of airports){
  const option=new Option(a.name+' ('+(a.code||'-')+')',a.key);
  if(SIX_CATEGORIES.has(a.category))option.dataset.category=a.category;
  output.append(option);
 }
 output.disabled=airports.length===0;
 if(initialKey&&airports.some(a=>a.key===initialKey))output.value=initialKey;
 refreshMenu('setup-airport-results');summarize();
}

function drawRealWorlds(worlds){
  const root=doc.getElementById('world-directory');
  root.replaceChildren();
  // Read-only directory. Never overwrite the protected airline setup choices.
  for(const world of worlds){
    const card=doc.createElement('article');card.className='world-card';
    const header=doc.createElement('span');header.className='world-number';
    header.textContent='WORLD '+String(world.id).padStart(2,'0');
    const title=doc.createElement('h2');title.textContent=world.name;
    const status=doc.createElement('span');status.className='pill';
    status.textContent=world.id===1?'World 1 - Founding World':'Not available';
    card.append(header,title,status);root.append(card);
  }
}
async function airportSearch({setup=false,offset=0}={}){
  if(!playerData)return;
  const select=doc.getElementById(setup?'setup-country':'airports-country');
  if(setup)return loadSetupAirports();
  const search=doc.getElementById('airports-query').value.trim();
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
 if(!auth)return;
 let readSucceeded=false;
 // A failing general Overview API must never block the separately
 // authenticated and owner-approved airline setup endpoint.
 try{
  playerData=createPlayerReadClient({auth,origin:window.location.origin,enabled:true,local});
  const data=await playerData.overview();
  if(!Array.isArray(data.worlds)||!Array.isArray(data.countries)||!Array.isArray(data.airlines))
   throw Error('Invalid game directory');
  drawRealWorlds(data.worlds);
  fillCountries(data.countries);
  const first=data.airlines[0];
  hasRealAirline=Boolean(first?.name);
  if(first?.name){
   doc.getElementById('top-world').textContent='WORLD '+String(first.worldId).padStart(2,'0');
   doc.getElementById('top-airline-state').textContent=first.name+
    (first.premiumUnlimited===true?' - Premium Unlimited':' - Registered airline');
   doc.getElementById('player-airline-name').textContent=first.name;
   doc.getElementById('player-cash').textContent=first.cashUsd+' USD';
   if(first.id&&auth?.getAirlineLogoUrl){
    auth.getAirlineLogoUrl(first.id).then(url=>{
     const img=doc.getElementById('player-existing-logo');
     if(img&&url){img.src=url;img.hidden=false;}
    }).catch(()=>{});
   }
  }else{
   doc.getElementById('top-airline-state').textContent='Create your airline';
   doc.getElementById('top-world').textContent='WORLD 01';
  }
  doc.getElementById('airport-heading').textContent='Airport directory';
  doc.getElementById('airport-description').textContent=
   data.airportsTotal+' approved airports in the game.';
  readSucceeded=true;
 }catch{
  playerData=null;
  doc.getElementById('player-data-status').textContent='Game overview is currently unavailable.';
 }
 // This is independent of the general read API and controls all setup
 // options. All airports come from verified protected server context.
 await loadRealOnboarding();
 const canSetup=Boolean(onboardingContext);
 const needsRetry=(!readSucceeded&&!canSetup)||(!hasRealAirline&&!canSetup);
 doc.getElementById('setup-retry-loading').hidden=!needsRetry;
 if(readSucceeded&&initialManagerLanding){
  const destination=managerLandingView({requestedView:'onboarding',hasAirline:hasRealAirline});
  window.history.replaceState({},'',playerViewUrl(destination));
  navigateTo(destination);
  initialManagerLanding=false;
 }
 if(!readSucceeded&&canSetup){
  // Stay on the authorized setup page. Its choices and activation remain
  // protected by the backend, even when overview data is unavailable.
  doc.getElementById('top-airline-state').textContent='Create your airline';
  if(initialManagerLanding){
   window.history.replaceState({},'',playerViewUrl('onboarding'));
   navigateTo('onboarding');
   initialManagerLanding=false;
  }
 }else if(!readSucceeded&&!canSetup){
  doc.getElementById('setup-draft-feedback').textContent=
   'Unable to load airline setup. Please select Retry.';
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
  options.replaceChildren(new Option('Select a world',''));
  for(const world of ctx.worlds){
   if(Number(world.worldId)!==1||!Array.isArray(world.airports)||!world.airports.length)continue;
   options.append(new Option('World 1 - '+world.name,String(world.worldId)));
  }
  options.disabled=options.options.length<=1;
  if(!options.disabled)options.value='1';
  refreshMenu('setup-world');
  fillSetupCountries();
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
  status.textContent='Choose your country, home airport and airline name.';
  doc.getElementById('setup-airline-logo').disabled=false;
 }catch{
  onboardingContext=null;
  const world=doc.getElementById('setup-world');
  world.replaceChildren(new Option('Select a world',''));
  world.disabled=true;refreshMenu('setup-world');
  fillSetupCountries();
  for(const id of ['setup-airline-name','setup-airline-logo','setup-accept-terms','setup-accept-privacy','setup-create-airline'])
   doc.getElementById(id).disabled=true;
  status.textContent='Unable to load World 1 airline setup. Please select Retry.';
 }
}
async function prepareLogo(file){
 if(!['image/png','image/jpeg','image/webp'].includes(file?.type)||file.size>6_000_000)
  throw Error('Choose a PNG, JPG or WebP image smaller than 6 MB.');
 const source=URL.createObjectURL(file);
 try{
  const image=new Image();
  await new Promise((resolve,reject)=>{
   image.onload=resolve;image.onerror=()=>reject(Error('Unable to read image.'));
   image.src=source;
  });
  if(image.width<1||image.height<1||image.width>10000||image.height>10000)
   throw Error('Invalid logo dimensions.');
  const scale=Math.min(1,500/Math.max(image.width,image.height));
  const canvas=doc.createElement('canvas');
  canvas.width=Math.max(1,Math.round(image.width*scale));
  canvas.height=Math.max(1,Math.round(image.height*scale));
  canvas.getContext('2d').drawImage(image,0,0,canvas.width,canvas.height);
  const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',0.84));
  if(!blob||blob.type!=='image/webp'||blob.size>1048576)
   throw Error('Logo is too large. Choose a simpler image.');
  return blob;
 }finally{URL.revokeObjectURL(source);}
}
doc.getElementById('setup-airline-logo').addEventListener('change',async(event)=>{
 const input=event.currentTarget,status=doc.getElementById('setup-logo-feedback');
 logoBlob=null;
 if(logoObjectUrl){URL.revokeObjectURL(logoObjectUrl);logoObjectUrl=null;}
 const image=doc.getElementById('summary-airline-logo');
 image.hidden=true;image.removeAttribute('src');
 doc.getElementById('summary-logo-placeholder').hidden=false;
 if(!input.files?.[0]){status.textContent='';return;}
 try{
  logoBlob=await prepareLogo(input.files[0]);
  logoObjectUrl=URL.createObjectURL(logoBlob);
  image.src=logoObjectUrl;image.hidden=false;
  doc.getElementById('summary-logo-placeholder').hidden=true;
  status.textContent='Logo ready to save with your airline.';
 }catch(error){status.textContent=error.message;input.value='';}
});
doc.getElementById('setup-cancel-create').addEventListener('click',()=>{
 doc.getElementById('setup-confirm-dialog').close();
});
doc.getElementById('setup-create-airline').addEventListener('click',()=>{
 const status=doc.getElementById('setup-draft-feedback');
 const worldId=Number(doc.getElementById('setup-world').value);
 const country=doc.getElementById('setup-country').value;
 const airport=doc.getElementById('setup-airport-results').value;
 const name=doc.getElementById('setup-airline-name').value.trim();
 const eligible=onboardingContext?.worlds.find(w=>w.worldId===worldId);
 if(!eligible||!country||!airport||!eligible.airports.some(a=>a.key===airport)){
  status.textContent='Choose a world, country and approved home airport.';return;
 }
 if(name.length<3||name.length>60){
  status.textContent='Enter an airline name containing 3-60 characters.';return;
 }
 if(doc.getElementById('setup-airline-logo').files?.length&&!logoBlob){
  status.textContent='Select a valid airline logo or remove the invalid file.';return;
 }
 summarize();
 doc.getElementById('setup-confirm-dialog').showModal();
});
doc.getElementById('setup-final-create').addEventListener('click',async()=>{
 const status=doc.getElementById('setup-draft-feedback');
 if(!onboardingContext||!onboarding)return;
 const btn=doc.getElementById('setup-final-create');
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
  doc.getElementById('setup-confirm-dialog').close();
  if(logoBlob){try{await auth.uploadAirlineLogo({airlineId:record.airlineId,blob:logoBlob});}
   catch{
    status.textContent='Your airline was created, but its logo could not be saved.';
    const warning=doc.getElementById('player-logo-warning');
    warning.textContent='Your airline was created successfully, but the logo upload failed.';
    warning.hidden=false;
   }}
  if(!doc.getElementById('player-logo-warning').hidden)status.textContent='Airline created; logo upload needs attention.';
  else status.textContent='Airline created successfully.';
  doc.getElementById('player-airline-name').textContent=airlineName;
  doc.getElementById('player-cash').textContent=String(record.cashUsd)+' USD';
  await loadPlayerReadData({local:window.location.origin==='http://localhost:5188'});
  window.history.replaceState({},'','/player.html#overview');navigateTo('overview');
 }catch(error){
  status.textContent=error?.message||'Unable to create your airline.';
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
  doc.getElementById('setup-draft-feedback').textContent='Choose world, country, home airport and airline name (3-60 characters).';
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
doc.getElementById('setup-country').addEventListener('change',()=>{loadSetupAirports();});
doc.getElementById('setup-world').addEventListener('change',fillSetupCountries);
doc.getElementById('setup-airport-results').addEventListener('change',summarize);
doc.getElementById('setup-airline-name').addEventListener('input',summarize);
doc.getElementById('setup-airport-search').addEventListener('click',()=>{void airportSearch({setup:true});});
doc.getElementById('airports-search').addEventListener('click',()=>{nextAirportOffset=null;void airportSearch();});
doc.getElementById('airports-more').addEventListener('click',()=>{if(nextAirportOffset!==null)void airportSearch({offset:nextAirportOffset});});
doc.getElementById('setup-retry-loading').addEventListener('click',()=>{
 const button=doc.getElementById('setup-retry-loading');button.hidden=true;
 doc.getElementById('setup-draft-feedback').textContent='Loading your airline setup…';
 void loadPlayerReadData({local:window.location.origin==='http://localhost:5188'});
});
function showPreview(){
  preview=true;
  doc.getElementById('local-preview-note').hidden=false;
  doc.getElementById('local-preview-note').textContent='LOCAL DEMO ONLY - no real identity, database connection or airline activation.';
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
  doc.title='Airlinerra - LOCAL DEMO · Player dashboard';
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
      if(['overview','onboarding'].includes(selected)){
        initialManagerLanding=true;
        window.history.replaceState({},'',playerViewUrl('onboarding'));
        navigateTo('onboarding');
      }
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
    if(['overview','onboarding'].includes(selected)){
      initialManagerLanding=true;
      window.history.replaceState({},'',playerViewUrl('onboarding'));
      navigateTo('onboarding');
    }
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
  initialManagerLanding=false;
  window.history.replaceState({},'',playerViewUrl(link.dataset.viewLink));
  navigateTo(link.dataset.viewLink);
}));
doc.querySelectorAll('[data-go-view]').forEach(button=>button.addEventListener('click',()=>{
  initialManagerLanding=false;
  const view=button.dataset.goView;
  window.history.replaceState({},'',playerViewUrl(view));
  navigateTo(view);
}));
window.addEventListener('hashchange',()=>{initialManagerLanding=false;navigateTo(safePlayerView(window.location.hash));});
signOut.addEventListener('click',async()=>{
  if(!auth)return;
  signOut.disabled=true;
  try{
    await auth.signOut();window.location.replace(PLAYER_LOGIN_PATH);
  }catch{signOut.disabled=false;window.alert('Sign out could not be completed. Please retry.');}
});
visible('loading');
void initialize().catch(()=>visible('denied'));
