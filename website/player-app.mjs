/** Real, verified manager dashboard and backend-gated onboarding.
 * Gameplay flight operations remain separately disabled.
 */
import {inspectInvitedTesterProvider,TESTER_ORIGIN} from './invited-tester-entry.mjs';
import {createInvitedTesterAuth,LOCAL_REAL_AUTH_ORIGIN} from './invited-tester-auth.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from './tester-dashboard-state.mjs';
import {createPlayerReadClient,PLAYER_READ_API_ENABLED} from './player-read-client.mjs';
import {createFlightScheduleClient} from './flight-schedule-client.mjs';
import {createFleetAcquisitionClient} from './fleet-acquisition-client.mjs';
import {createAircraftLibrary} from './aircraft-library.mjs';
import {createRealOnboardingClient} from './real-onboarding-client.mjs';
import {createDownwardMenu} from './setup-choice-menu.mjs';

import {createAirlineWorkspace} from './airline-workspace.mjs';
import {createOperationsCenter} from './airline-operations-center.mjs';
import {renderAirlineDashboard,worldDisplayName} from './airline-dashboard.mjs';
import {createLocalCatalogClient} from './local-catalog-client.mjs';
import {saveLocalDraft,readLocalDraft,clearLocalDraft} from './local-onboarding-draft.mjs';
import {isLocalDemoOrigin,hasLocalDemo,endLocalDemo,getLocalTestProfile,LOCAL_DEMO_MANAGER,LOCAL_DEMO_LOGIN_PATH} from './local-demo-session.mjs';
import {
  PLAYER_APP_PATH,PLAYER_LOGIN_PATH,PLAYER_VIEWS,WORLD_LABELS,
  safePlayerView,playerViewUrl,verifiedManagerIdentity,onboardingReadiness,managerLandingView,formatWholeUsd
} from './player-app-model.mjs';

const doc=window.document;
const loading=doc.getElementById('player-loading');
const denied=doc.getElementById('player-denied');
const app=doc.getElementById('player-app');
const signOut=doc.getElementById('player-sign-out');
let auth=null;
let preview=false;
let aircraftLibraryController=null;
function enablePublicAircraftImageCache(){
 // Cache only public aircraft artwork; never Auth, game data, private pages or API responses.
 if(!window.isSecureContext||!('serviceWorker' in navigator))return;
 void navigator.serviceWorker.register('/aircraft-image-cache-sw.js',{
  scope:'/player.html',updateViaCache:'none'
 }).catch(()=>{/* Browsers may disable persistent storage; normal image loading still works. */});
}
function visible(view){
  loading.hidden=view!=='loading';
  denied.hidden=view!=='denied';
  app.hidden=view!=='app';
}
function navigateTo(view){
  const returningFromAircraftProfile=doc.querySelector('[data-player-view="aircraft-profile"]')?.hidden===false;
  const selected=safePlayerView('#'+view);
  const name=selected==='onboarding'&&hasRealAirline?'overview':selected;
  if(name!==selected)window.history.replaceState({},'',playerViewUrl(name));
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
  if(name==='aircraft-library'&&aircraftLibraryController){
    void aircraftLibraryController.load().then(()=>{
      // Wait for the library section to become visible before centering the chosen row.
      if(returningFromAircraftProfile)window.requestAnimationFrame(
       ()=>aircraftLibraryController.restoreLastSelection());
    }).catch(()=>{});
  }
  if(name==='airline'&&currentAirline?.id)void loadManageAirlineLogo();
  if(name==='licenses')void loadLicenseReference();
}
// This is a read-only reference catalogue, not an authority/entitlement check.
// Keep the renderer inside the player bundle: no additional module required at startup.
let licenseDirectoryLoaded=false;
let licenseDirectoryLoading=false;
function createLicenseText(tag,text,cls=''){
 const node=doc.createElement(tag);
 if(cls)node.className=cls;
 node.textContent=String(text);
 return node;
}
async function loadLicenseReference(){
 const status=doc.getElementById('licenses-catalog-status');
 const list=doc.getElementById('licenses-catalog-groups');
 if(!status||!list||licenseDirectoryLoaded||licenseDirectoryLoading)return;
 if(!playerData?.licenses){
  status.textContent='Waiting for a verified game connection. No licence or traffic right has been granted.';
  return;
 }
 licenseDirectoryLoading=true;
 status.textContent='Loading licence reference data…';
 try{
  const data=await playerData.licenses();
  if(data?.referenceOnly!==true||data.applicationsAvailable!==false||
   data.companyApprovalsAvailable!==false||data.trafficRightsVerified!==false||
   !Array.isArray(data.licenses)||data.licenses.length<1||data.licenses.length>60||
   data.licenses.some(x=>x?.enabledInGame!==false))throw Error('Unverified catalogue');
  const wrapper=doc.createDocumentFragment();
  for(const [code,heading] of [
   ['company','Company registration and holdings'],
   ['airline','Airline operating permissions'],
   ['maintenance','Maintenance approvals'],
   ['traffic_rights','Traffic rights and foreign bases']
  ]){
   const entries=data.licenses.filter(x=>x.category===code);
   if(!entries.length)continue;
   const group=createLicenseText('section','','license-catalog-group');
   group.append(createLicenseText('h2',heading));
   const grid=createLicenseText('div','','license-card-grid');
   for(const item of entries){
    const card=createLicenseText('article','','license-reference-card');
    const type=item.referenceBasis==='eu_reference'?'EU regulatory reference':
     item.referenceBasis==='game_proposal'?'Proposed game rule':'Jurisdiction / route verification required';
    card.append(createLicenseText('h3',item.title),
     createLicenseText('span',type,'license-reference-basis'),
     createLicenseText('p',item.purpose));
    for(const [heading,text] of [['Requirements',item.requirements],['How to obtain',item.howToObtain]]){
     const field=createLicenseText('div','','license-reference-field');
     field.append(createLicenseText('strong',heading),createLicenseText('p',text));
     card.append(field);
    }
    if(typeof item.sourceUrl==='string'&&/^https:\/\//.test(item.sourceUrl)){
     const link=createLicenseText('a','Official reference','license-reference-link');
     link.href=item.sourceUrl;
     link.target='_blank';
     link.rel='noopener noreferrer';
     card.append(link);
    }
    grid.append(card);
   }
   group.append(grid);
   wrapper.append(group);
  }
  if(!wrapper.childNodes.length)throw Error('Empty categories');
  list.replaceChildren(wrapper);
  doc.getElementById('licenses-type-count').textContent=String(data.licenses.length);
  doc.getElementById('licenses-verified-count').textContent=String(
   data.licenses.filter(x=>x.referenceBasis==='eu_reference').length);
  status.textContent='Reference only — no applications, licences or international route rights are active.';
  licenseDirectoryLoaded=true;
 }catch{
  list.replaceChildren();
  status.textContent='Licence reference register unavailable. No permissions can be assumed. Reload the page to retry.';
 }finally{licenseDirectoryLoading=false;}
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
  doc.getElementById('manager-name').value=manager.name;
  doc.getElementById('manager-hometown').value=typeof user.user_metadata?.hometown==='string'?user.user_metadata.hometown:'';
  doc.getElementById('manager-country').value=typeof user.user_metadata?.country==='string'?user.user_metadata.country:'';
  doc.getElementById('manager-email').textContent=manager.email;
  doc.getElementById('manager-joined').textContent=manager.joined||'Not provided';
  doc.getElementById('setup-email').textContent=manager.email;
  doc.getElementById('top-email').textContent=manager.email;
  if(!workspaceController){
   workspaceController=createAirlineWorkspace({
    doc,identity:user.id,
    storage:(()=>{try{return window.localStorage}catch{return null}})(),
    session:(()=>{try{return window.sessionStorage}catch{return null}})(),
    goTo:view=>{
     window.history.replaceState({},'',playerViewUrl(view));
     navigateTo(view);
    }
   });
  }
  if(!operationsController){
    operationsController=createOperationsCenter({
      doc,identity:user.id,
      getAirlineLogoUrl:airlineId=>auth?.getAirlineLogoUrl?.(airlineId)??Promise.resolve(null),
      session:(()=>{try{return window.sessionStorage}catch{return null}})(),
      goTo:view=>{window.history.replaceState({},'',playerViewUrl(view));navigateTo(view);}
    });
  }
}
function renderOverviewState(hasAirline){
 doc.getElementById('player-airline-note').textContent=hasAirline?'':'Awaiting onboarding';
 doc.querySelectorAll('[data-setup-only]').forEach(element=>{element.hidden=hasAirline;});
 doc.getElementById('overview-subtitle').textContent=hasAirline
  ?'Your airline and business activity at a glance.'
  :'Create your first airline to begin managing routes and aircraft.';
 doc.getElementById('player-cash-note').textContent=hasAirline?'Available airline funds':'No airline ledger yet';

}
let playerData=null;
aircraftLibraryController=createAircraftLibrary({doc,getReader:()=>playerData});
let onboarding=null;
let onboardingContext=null;
let hasRealAirline=false;
let workspaceController=null;
let operationsController=null;
let currentAirline=null,manageLogoBlob=null,manageLogoPreviewUrl=null,manageLogoRequest=0;
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
 put('airport-details-runway',Number.isFinite(airport.runwayLengthM)?airport.runwayLengthM.toLocaleString('en')+' m':null);
 const rawSurface=String(airport.runwaySurface||'').trim();
 const material=rawSurface.toUpperCase();
 const surfaces={ASP:'Asphalt',ASPH:'Asphalt',CON:'Concrete',CONC:'Concrete',ASPHALT:'Asphalt',CONCRETE:'Concrete'};
 put('airport-details-surface',surfaces[material]||rawSurface||null);
 demandScale('passenger',airport.passengerDemandPct);
 demandScale('cargo',airport.cargoDemandPct);
}
function summarize(){
 const world=doc.getElementById('setup-world'),country=doc.getElementById('setup-country');
 const airport=doc.getElementById('setup-airport-results');
 const name=doc.getElementById('setup-airline-name').value.trim();
 doc.getElementById('summary-airline-name').textContent=name||'Not entered';
 doc.getElementById('summary-airline-icao').textContent=doc.getElementById('setup-airline-icao').value||'Not entered';
 doc.getElementById('summary-airline-iata').textContent=doc.getElementById('setup-airline-iata').value||'Not entered';
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
    header.textContent='AIRLINERRA - WORLD '+String(world.id).padStart(2,'0');
    const title=doc.createElement('h2');title.textContent=world.name;
    const status=doc.createElement('span');status.className='pill';
    status.textContent=world.id===1?'First world - private testing':'Future world - not open';
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
        const open=doc.createElement('button');open.type='button';open.className='secondary airport-profile-link';
        open.textContent='Airport profile';open.addEventListener('click',()=>{
          operationsController?.openAirport(airport);
        });
        row.append(name,place,open);output.append(row);
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
 let readStage='api';
 // Read failures and UI errors must be distinguished. Both otherwise looked
 // like "no airline" and concealed their actual cause.
 try{
  playerData=createPlayerReadClient({auth,origin:window.location.origin,enabled:true,local});
  const scheduler=!local&&window.location.origin==='https://airlinerra.com'?
   createFlightScheduleClient({auth,origin:window.location.origin}):null;
  const fleetClient=!local&&window.location.origin==='https://airlinerra.com'?
   createFleetAcquisitionClient({auth,origin:window.location.origin}):null;
  const data=await playerData.overview();
  readStage='display';
  if(!Array.isArray(data.worlds)||!Array.isArray(data.countries)||!Array.isArray(data.airlines))
   throw Error('Invalid game directory');
  const first=data.airlines[0];
  currentAirline=first||null;
  hasRealAirline=Boolean(first?.name);
  renderOverviewState(hasRealAirline);
  // Airline identity and cash must not disappear if an unrelated airport
  // directory widget or planning panel fails to render.
  renderAirlineDashboard(doc,{airline:first||null,worlds:data.worlds,ledgerEntries:data.ledgerEntries});
  try{drawRealWorlds(data.worlds);fillCountries(data.countries);}
  catch{console.warn('Airlinerra secondary directory failed to display');}
  try{
    workspaceController?.updateData({connected:true,airline:first||null,worlds:data.worlds,
     countries:data.countries,reader:playerData,scheduler,fleetClient});
    operationsController?.updateData({connected:true,airline:first||null,worlds:data.worlds,countries:data.countries,reader:playerData,scheduler});
  }
  catch{console.warn('Airlinerra secondary workspace failed to display');}
  if(first?.id)void loadManageAirlineLogo();
  doc.getElementById('player-data-status').hidden=true;
  doc.getElementById('player-data-retry').hidden=true;
  if(first?.name){
   doc.getElementById('top-world').textContent=worldDisplayName(first.worldId,data.worlds);
   doc.getElementById('top-airline-state').textContent=first.name+
    (first.premiumUnlimited===true?' - Premium Unlimited':' - Registered airline');
   doc.getElementById('player-airline-name').textContent=first.name;
   doc.getElementById('player-cash').textContent=formatWholeUsd(first.cashUsd);
   if(first.id&&auth?.getAirlineLogoUrl){
    auth.getAirlineLogoUrl(first.id).then(url=>{
     const img=doc.getElementById('player-existing-logo');
     if(img&&url){img.src=url;img.hidden=false;}
    }).catch(()=>{});
   }
  }else{
   doc.getElementById('top-airline-state').textContent='Create your airline';
   doc.getElementById('top-world').textContent=worldDisplayName(1,data.worlds);
  }
  doc.getElementById('airport-heading').textContent='Airport directory';
  doc.getElementById('airport-description').textContent=
   data.airportsTotal+' approved airports in the game.';
  readSucceeded=true;
  if(safePlayerView(window.location.hash)==='aircraft-library')void aircraftLibraryController.load();
  if(safePlayerView(window.location.hash)==='licenses')void loadLicenseReference();
 }catch(error){
  // Only safe diagnostic labels are shown: never print bearer tokens,
  // request bodies or private database errors.
  const code=/^GAME_API_HTTP_[1-5][0-9]{2}$/.test(String(error?.message||''))
   ?String(error.message).replace('GAME_API_HTTP_','HTTP '):
   (readStage==='api'?'Request failed':'Display failed');
  console.warn('Airlinerra player overview',readStage,code);
  playerData=null;
  hasRealAirline=false; // Unknown because the protected read failed - NOT proof no airline exists.
  workspaceController?.updateData({connected:false,airline:null,reader:null,scheduler:null,fleetClient:null});
  operationsController?.updateData({connected:false,airline:null,reader:null});
  currentAirline=null;
  renderAirlineDashboard(doc,{airline:null,ledgerEntries:null});
  doc.getElementById('top-airline-state').textContent='Airline data unavailable';
  doc.getElementById('player-airline-name').textContent='Unable to load';
  doc.getElementById('player-airline-note').textContent='Connection unavailable';
  doc.getElementById('player-cash').textContent='-';
  doc.getElementById('player-cash-note').textContent='Balance not loaded';
  const box=doc.getElementById('player-data-status');
  doc.getElementById('player-data-message').textContent=
   (readStage==='api'
    ?'Airline data request failed ('+code+').'
    :'Airline data was received but the page could not display it ('+code+').')+
   ' No new registration is needed. Please retry the connection.';
  box.hidden=false;
  doc.getElementById('player-data-retry').hidden=false;
  doc.getElementById('setup-create-airline').disabled=true;
  doc.getElementById('setup-draft-feedback').textContent=
   'Existing airline status cannot be verified. Retry the database connection instead of creating another airline.';
 }
 // Confirm existing company ownership before enabling airline creation.
 // The protected setup endpoint is never used as evidence that an airline is missing.
 if(readSucceeded)await loadRealOnboarding();
 const canSetup=Boolean(onboardingContext);
 const needsRetry=!readSucceeded||(!hasRealAirline&&!canSetup);
 doc.getElementById('setup-retry-loading').hidden=!needsRetry;
 if(readSucceeded&&initialManagerLanding){
  const destination=managerLandingView({requestedView:'onboarding',hasAirline:hasRealAirline});
  const landing=hasRealAirline?(workspaceController?.getLandingView()||destination):destination;
  window.history.replaceState({},'',playerViewUrl(landing));
  navigateTo(landing);
  initialManagerLanding=false;
 }
 if(!readSucceeded&&initialManagerLanding){
  window.history.replaceState({},'',playerViewUrl('overview'));
  navigateTo('overview');
  initialManagerLanding=false;
 }
}
doc.addEventListener('airlinerra:fleet-updated',()=>{
 if(auth&&currentAirline?.id)void loadPlayerReadData();
});
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
  for(const id of ['setup-airline-name','setup-airline-icao','setup-airline-iata','setup-accept-terms','setup-accept-privacy','setup-create-airline'])
   doc.getElementById(id).disabled=false;
  status.textContent='Choose your country, home airport and airline name.';
  doc.getElementById('setup-airline-logo').disabled=false;
  if(window.location.origin==='http://localhost:5188'){
   // Local readonly real-data test: never write to the production airline DB.
   doc.getElementById('setup-create-airline').disabled=true;
   status.textContent='Local test - choose airports, enter a name and preview a logo. Airline creation is disabled here.';
  }
 }catch{
  onboardingContext=null;
  const world=doc.getElementById('setup-world');
  world.replaceChildren(new Option('Select a world',''));
  world.disabled=true;refreshMenu('setup-world');
  fillSetupCountries();
  for(const id of ['setup-airline-name','setup-airline-icao','setup-airline-iata','setup-airline-logo','setup-accept-terms','setup-accept-privacy','setup-create-airline'])
   doc.getElementById(id).disabled=true;
  status.textContent='Unable to load World 1 airline setup. Please select Retry.';
 }
}
async function loadManageAirlineLogo(){
 const image=doc.getElementById('manage-airline-logo-preview');
 const placeholder=doc.getElementById('manage-airline-logo-placeholder');
 if(!image||!placeholder)return;
 const id=currentAirline?.id,serial=++manageLogoRequest;
 if(!id||!auth?.getAirlineLogoUrl){
  image.hidden=true;image.removeAttribute('src');placeholder.hidden=false;
  placeholder.textContent='No registered airline logo available';return;
 }
 try{
  const url=await auth.getAirlineLogoUrl(id);
  if(serial!==manageLogoRequest||currentAirline?.id!==id||manageLogoBlob)return;
  if(url){image.src=url;image.hidden=false;placeholder.hidden=true;}
  else{image.hidden=true;image.removeAttribute('src');placeholder.hidden=false;placeholder.textContent='No logo uploaded';}
 }catch{
  if(serial===manageLogoRequest){image.hidden=true;placeholder.hidden=false;placeholder.textContent='Logo preview unavailable';}
 }
}
function clearManageLogoSelection(){
 if(manageLogoPreviewUrl){URL.revokeObjectURL(manageLogoPreviewUrl);manageLogoPreviewUrl=null;}
 manageLogoBlob=null;
 const field=doc.getElementById('manage-airline-logo-file');
 if(field)field.value='';
 const button=doc.getElementById('manage-airline-logo-save');
 if(button)button.disabled=true;
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
doc.getElementById('manager-profile-form').addEventListener('submit',async event=>{
 event.preventDefault();
 const status=doc.getElementById('manager-profile-status'),button=doc.getElementById('manager-save');
 if(!auth?.updateManagerProfile){status.textContent='Sign in to update account details.';return;}
 button.disabled=true;status.textContent='Saving account details...';
 try{
  const user=await auth.updateManagerProfile({
   displayName:doc.getElementById('manager-name').value,
   hometown:doc.getElementById('manager-hometown').value,
   country:doc.getElementById('manager-country').value
  });
  setManager(user);
  status.textContent='Account details saved.';
 }catch(error){
  const message=String(error?.message||'');
  status.textContent=/Display name|Hometown|Country/.test(message)?
   message:'Unable to save account details. Please retry.';
 }finally{button.disabled=false;}
});
doc.getElementById('manager-change-password').addEventListener('click',async()=>{
 const button=doc.getElementById('manager-change-password');
 const status=doc.getElementById('manager-password-status');
 if(!auth?.requestPasswordReset){status.textContent='Sign in to change your password.';return;}
 button.disabled=true;
 try{
  const user=await auth.getUser();
  if(!user?.email||!user.email_confirmed_at)throw Error('Verified account required.');
  await auth.requestPasswordReset(user.email);
  status.textContent='If your account is eligible, a password-change email will be sent. Check your inbox.';
 }catch{
  status.textContent='Unable to request a password change. Use the account recovery page.';
 }finally{button.disabled=false;}
});
// Manage airline is inserted after Auth; delegated controls remain bound across renders.
doc.getElementById('player-main').addEventListener('change',async event=>{
 if(event.target?.id!=='manage-airline-logo-file')return;
 const selected=event.target.files?.[0];
 const status=doc.getElementById('manage-airline-logo-status');
 clearManageLogoSelection();
 if(!selected){status.textContent='';return;}
 try{
  if(!currentAirline?.id||!auth?.uploadAirlineLogo)
   throw Error('A verified airline is required to change its logo.');
  const logo=await prepareLogo(selected);
  manageLogoBlob=logo;
  manageLogoPreviewUrl=URL.createObjectURL(logo);
  const image=doc.getElementById('manage-airline-logo-preview');
  image.src=manageLogoPreviewUrl;image.hidden=false;
  doc.getElementById('manage-airline-logo-placeholder').hidden=true;
  doc.getElementById('manage-airline-logo-save').disabled=false;
  status.textContent='Preview ready. Click Save new logo to replace the previous logo.';
 }catch(error){status.textContent=error?.message||'Unable to read logo file.';}
});
doc.getElementById('player-main').addEventListener('click',async event=>{
 if(event.target?.id!=='manage-airline-logo-save')return;
 const button=doc.getElementById('manage-airline-logo-save');
 const status=doc.getElementById('manage-airline-logo-status');
 if(!auth?.uploadAirlineLogo||!currentAirline?.id||!manageLogoBlob){
  status.textContent='Choose a valid logo for your registered airline.';return;
 }
 const id=currentAirline.id;
 button.disabled=true;status.textContent='Replacing airline logo...';
 let completed=false;
 try{
  await auth.uploadAirlineLogo({airlineId:id,blob:manageLogoBlob});
  completed=true;
  clearManageLogoSelection();
  if(currentAirline?.id!==id)throw Error('The selected airline changed.');
  ++manageLogoRequest;
  const signed=await auth.getAirlineLogoUrl(id).catch(()=>null);
  if(signed){
   const fresh=signed+(signed.includes('?')?'&':'?')+'image_version='+Date.now();
   const image=doc.getElementById('manage-airline-logo-preview');
   image.src=fresh;image.hidden=false;
   doc.getElementById('manage-airline-logo-placeholder').hidden=true;
   const overview=doc.getElementById('player-existing-logo');
   if(overview){overview.src=fresh;overview.hidden=false;}
  }else{
   void loadManageAirlineLogo();
  }
  operationsController?.refreshAirlineLogo?.();
  status.textContent='New logo saved. The previous logo was replaced at the same storage path.';
 }catch{
  status.textContent=completed?'Logo saved, but preview refresh failed. Reopen Manage airline to check.':
   'Logo upload failed. The previous logo remains unchanged.';
  button.disabled=!manageLogoBlob;
 }
});
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
 const icaoCode=doc.getElementById('setup-airline-icao').value.trim().toUpperCase();
 const iataCode=doc.getElementById('setup-airline-iata').value.trim().toUpperCase();
 const eligible=onboardingContext?.worlds.find(w=>w.worldId===worldId);
 if(!eligible||!country||!airport||!eligible.airports.some(a=>a.key===airport)){
  status.textContent='Choose a world, country and approved home airport.';return;
 }
 if(name.length<3||name.length>60){
  status.textContent='Enter an airline name containing 3-60 characters.';return;
 }
 if(!/^[A-Z]{3}$/.test(icaoCode)){
  status.textContent='Your ICAO code must contain exactly three letters.';return;
 }
 if(!/^[A-Z0-9]{2}$/.test(iataCode)||!/[A-Z]/.test(iataCode)){
  status.textContent='Your IATA code must contain two letters or a letter and number.';return;
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
  const icaoCode=doc.getElementById('setup-airline-icao').value.trim().toUpperCase();
  const iataCode=doc.getElementById('setup-airline-iata').value.trim().toUpperCase();
  if(!/^[A-Z]{3}$/.test(icaoCode)||!/^[A-Z0-9]{2}$/.test(iataCode)||!/[A-Z]/.test(iataCode))throw Error('Enter valid ICAO and IATA codes.');
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
  const record=await onboarding.createAirline({worldId,homeAirportKey:home,airlineName,icaoCode,iataCode});
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
  doc.getElementById('player-cash').textContent=formatWholeUsd(record.cashUsd);
  workspaceController?.updateData({airline:{id:record.airlineId,worldId,name:airlineName,homeAirportKey:home,cashUsd:record.cashUsd}});
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
doc.getElementById('setup-country').addEventListener('change',()=>{loadSetupAirports();});
doc.getElementById('setup-world').addEventListener('change',fillSetupCountries);
doc.getElementById('setup-airport-results').addEventListener('change',summarize);
doc.getElementById('setup-airline-name').addEventListener('input',summarize);
for(const id of ['setup-airline-icao','setup-airline-iata']){
 doc.getElementById(id).addEventListener('input',event=>{
  const input=event.currentTarget;
  input.value=input.value.toUpperCase().replace(id.endsWith('icao')?/[^A-Z]/g:/[^A-Z0-9]/g,'').slice(0,id.endsWith('icao')?3:2);
  summarize();
 });
}
doc.getElementById('setup-airport-search').addEventListener('click',()=>{void airportSearch({setup:true});});
doc.getElementById('airports-search').addEventListener('click',()=>{nextAirportOffset=null;void airportSearch();});
doc.getElementById('airports-more').addEventListener('click',()=>{if(nextAirportOffset!==null)void airportSearch({offset:nextAirportOffset});});
doc.getElementById('player-data-retry').addEventListener('click',async()=>{
 const button=doc.getElementById('player-data-retry');
 button.disabled=true;
 doc.getElementById('player-data-message').textContent='Reconnecting to the World 1 game database...';
 try{await loadPlayerReadData({local:window.location.origin==='http://localhost:5188'});}
 finally{button.disabled=false;}
});
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
  doc.getElementById('manager-name').value=profile.name;
  for(const id of ['manager-email','setup-email'])doc.getElementById(id).textContent=profile.email;
  doc.getElementById('top-email').textContent=localTest?'LOCAL TEST ACCOUNT · Not Supabase':'LOCAL DEMO · Not signed in';
  doc.getElementById('manager-joined').textContent='Demo session';
  // Do not claim a verified Supabase account in an unauthenticated preview.
  doc.getElementById('manager-verified').textContent=localTest?'Email confirmed in local simulation · Not Supabase':'Demo only · Not verified';
  doc.getElementById('setup-account-state').textContent=localTest?'Local test complete':'Demo';
  doc.getElementById('setup-account-state').classList.remove('step-good');
  doc.getElementById('setup-email').closest('.step').querySelector('p').firstChild.textContent='Simulated manager; no invitation verified. ';
  doc.getElementById('player-data-message').textContent='Simulated navigation - protected game API is not connected';
  doc.getElementById('player-data-status').hidden=false;
  signOut.disabled=false;
  doc.title='Airlinerra - LOCAL DEMO - Player dashboard';
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
      enablePublicAircraftImageCache();
      if(['overview','onboarding'].includes(selected)){
        initialManagerLanding=true;
        window.history.replaceState({},'',playerViewUrl('onboarding'));
        navigateTo('onboarding');
      }
      doc.getElementById('local-preview-note').hidden=true;
      visible('app');
      await loadPlayerReadData({local:true});
    }catch(error){
      // Do not send a signed-in manager back to the account page on every
      // startup failure: account.html immediately redirects verified users here.
      // Keep the failure visible and log the cause for local troubleshooting.
      console.error('Airlinerra local startup failed:',error);
      visible('denied');
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
    enablePublicAircraftImageCache();
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
// Align Settings to its right edge on laptops. If the navigation wraps on a
// smaller screen, shift only that dropdown back inside the viewport.
// Keep this small positioning helper in the existing player application file.
// Loading an optional layout module must never prevent account initialization.
function dropdownViewportShift(rect,viewportWidth,gutter=12){
  const {left,right}=rect||{};
  if(![left,right,viewportWidth,gutter].every(Number.isFinite)||viewportWidth<=0)return 0;
  const safeGutter=Math.max(0,gutter);
  if(left<safeGutter)return Math.ceil(safeGutter-left);
  if(right>viewportWidth-safeGutter)return Math.floor(viewportWidth-safeGutter-right);
  return 0;
}
const settingsNavGroup=doc.querySelector('.nav-group[data-nav-group="settings"]');
const settingsNavLinks=settingsNavGroup?.querySelector('.nav-links');
function fitSettingsDropdown(){
  if(!settingsNavGroup?.open||!settingsNavLinks)return;
  settingsNavLinks.style.transform='';
  const shift=dropdownViewportShift(
    settingsNavLinks.getBoundingClientRect(),doc.documentElement.clientWidth,12);
  if(shift!==0)settingsNavLinks.style.transform=`translateX(${shift}px)`;
}
doc.querySelectorAll('.nav-group').forEach(group=>group.addEventListener('toggle',()=>{
  if(!group.open)return;
  for(const other of doc.querySelectorAll('.nav-group[open]'))if(other!==group)other.open=false;
  if(group===settingsNavGroup)fitSettingsDropdown();
}));
window.addEventListener('resize',fitSettingsDropdown);
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
