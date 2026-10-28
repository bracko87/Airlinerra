/** Prelaunch player application: route navigation and verified identity only.
 * Gameplay and database-backed onboarding stay disabled pending hosted API release.
 */
import {inspectInvitedTesterProvider,TESTER_ORIGIN} from './invited-tester-entry.mjs';
import {createInvitedTesterAuth} from './invited-tester-auth.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from './tester-dashboard-state.mjs';
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
function showPreview(){
  preview=true;
  doc.getElementById('local-preview-note').hidden=false;
  for(const id of ['manager-name','manager-email','setup-email','top-email']){
    doc.getElementById(id).textContent='Local visual preview — not connected';
  }
  doc.getElementById('manager-joined').textContent='—';
  signOut.disabled=true;
  visible('app');
}
async function initialize(){
  drawWorldDirectory();
  // A static preview never checks the live user's credentials.
  const isLocal=['localhost','127.0.0.1'].includes(window.location.hostname);
  const selected=safePlayerView(window.location.hash);
  window.history.replaceState({},'',playerViewUrl(selected));
  navigateTo(selected);
  const readiness=onboardingReadiness();
  if(readiness.canCreate)throw Error('Prelaunch creation gate unexpectedly enabled.');
  if(isLocal){showPreview();return;}
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
  if(preview||!auth)return;
  signOut.disabled=true;
  try{
    await auth.signOut();window.location.replace(PLAYER_LOGIN_PATH);
  }catch{signOut.disabled=false;window.alert('Sign out could not be completed. Please retry.');}
});
visible('loading');
void initialize().catch(()=>visible('denied'));
