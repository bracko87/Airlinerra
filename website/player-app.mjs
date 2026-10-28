/** Prelaunch player application: route navigation and verified identity only.
 * Gameplay and database-backed onboarding stay disabled pending hosted API release.
 */
import {inspectInvitedTesterProvider,TESTER_ORIGIN} from './invited-tester-entry.mjs';
import {createInvitedTesterAuth} from './invited-tester-auth.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from './tester-dashboard-state.mjs';
import {createPlayerReadClient,PLAYER_READ_API_ENABLED} from './player-read-client.mjs';
import {isLocalDemoOrigin,hasLocalDemo,endLocalDemo,LOCAL_DEMO_MANAGER,LOCAL_DEMO_LOGIN_PATH} from './local-demo-session.mjs';
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
let nextAirportOffset=null;
function fillCountries(countries){
  for(const id of ['setup-country','airports-country']){
    const select=doc.getElementById(id);
    select.replaceChildren(new Option('Select a country',''));
    for(const c of countries){
      if(typeof c.countryIso==='string'&&/^[A-Z]{2}$/.test(c.countryIso)&&Number.isInteger(c.airportCount)){
        select.append(new Option(c.countryIso+' ('+c.airportCount+' airports)',c.countryIso));
      }
    }
    select.disabled=false;
  }
  doc.getElementById('setup-airport').disabled=false;
  doc.getElementById('setup-airport-search').disabled=false;
  doc.getElementById('airports-query').disabled=false;
  doc.getElementById('airports-search').disabled=false;
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
async function loadPlayerReadData(){
  if(!auth||!PLAYER_READ_API_ENABLED)return;
  try{
    playerData=createPlayerReadClient({auth,origin:window.location.origin,enabled:true});
    const data=await playerData.overview();
    if(!Array.isArray(data.worlds)||!Array.isArray(data.countries)||!Array.isArray(data.airlines))throw Error('Invalid data');
    drawRealWorlds(data.worlds);
    fillCountries(data.countries);
    const first=data.airlines[0];
    if(first?.name){
      doc.getElementById('player-airline-name').textContent=first.name;
      doc.getElementById('player-cash').textContent=first.cashUsd+' USD';
    }
    doc.getElementById('player-data-status').textContent='Live private database · Read only';
    doc.getElementById('airport-heading').textContent='Approved airport directory';
    doc.getElementById('airport-description').textContent=data.airportsTotal+' approved simulation airports available for read-only lookup.';
  }catch{
    playerData=null;
    doc.getElementById('player-data-status').textContent='Private game database not connected';
  }
}
doc.getElementById('setup-airport-search').addEventListener('click',()=>{void airportSearch({setup:true});});
doc.getElementById('airports-search').addEventListener('click',()=>{nextAirportOffset=null;void airportSearch();});
doc.getElementById('airports-more').addEventListener('click',()=>{if(nextAirportOffset!==null)void airportSearch({offset:nextAirportOffset});});
function showPreview(){
  preview=true;
  doc.getElementById('local-preview-note').hidden=false;
  doc.getElementById('local-preview-note').textContent='LOCAL DEMO ONLY — no real identity, database connection or airline activation.';
  doc.getElementById('manager-name').textContent=LOCAL_DEMO_MANAGER.name;
  for(const id of ['manager-email','setup-email','top-email'])
    doc.getElementById(id).textContent=LOCAL_DEMO_MANAGER.email;
  doc.getElementById('manager-joined').textContent='Demo session';
  // Do not claim a verified Supabase account in an unauthenticated preview.
  doc.getElementById('manager-verified').textContent='Demo only · Not verified';
  doc.getElementById('setup-account-state').textContent='Demo';
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
    if(!hasLocalDemo(window.sessionStorage,window.location)){
      window.location.replace(LOCAL_DEMO_LOGIN_PATH);
      return;
    }
    showPreview();return;
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
  if(preview){
    endLocalDemo(window.sessionStorage,window.location);
    window.location.replace(LOCAL_DEMO_LOGIN_PATH);
    return;
  }
  if(!auth)return;
  signOut.disabled=true;
  try{
    await auth.signOut();window.location.replace(PLAYER_LOGIN_PATH);
  }catch{signOut.disabled=false;window.alert('Sign out could not be completed. Please retry.');}
});
visible('loading');
void initialize().catch(()=>visible('denied'));
