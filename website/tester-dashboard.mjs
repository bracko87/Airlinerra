/** Airlinerra invited-only tester home. No game actions or database reads. */
import {inspectInvitedTesterProvider,TESTER_ORIGIN} from './invited-tester-entry.mjs';
import {createInvitedTesterAuth} from './invited-tester-auth.mjs';
import {
  PRIVATE_TESTER_DASHBOARD_PATH,PRIVATE_TESTER_LOGIN_PATH,
  PrivateTesterAccessDenied,openPrivateTesterDashboard
} from './tester-dashboard-state.mjs';

const doc=window.document;
const loading=doc.getElementById('dashboard-loading');
const dashboard=doc.getElementById('tester-dashboard');
const unavailable=doc.getElementById('dashboard-unavailable');
const signOutButton=doc.getElementById('dashboard-sign-out');
const feedback=doc.getElementById('dashboard-feedback');
let activeAuth=null;
function show(view){
  loading.hidden=view!=='loading';
  dashboard.hidden=view!=='dashboard';
  unavailable.hidden=view!=='unavailable';
}
async function initialize(){
  // The production-build localhost route is a visual-only sample. Never
  // initialize a hosted Auth client or send credentials from localhost.
  if(['localhost','127.0.0.1'].includes(window.location.hostname)){
    doc.getElementById('account-email').textContent='Not connected (local preview)';
    doc.getElementById('preview-indicator').hidden=false;
    signOutButton.disabled=true;
    show('dashboard');
    return;
  }
  // Dashboard links never carry OTPs: clear any accidental query or fragment
  // before network requests or SDK loading.
  window.history.replaceState({},'',PRIVATE_TESTER_DASHBOARD_PATH);
  if(window.location.origin!==TESTER_ORIGIN){
    show('unavailable');
    return;
  }
  try{
    const result=await openPrivateTesterDashboard({
      origin:window.location.origin,
      pathname:window.location.pathname,
      config:window.__AIRLINERRA_INVITED_TESTER_CONFIG__,
      inspectProvider:inspectInvitedTesterProvider,
      createAuth:createInvitedTesterAuth
    });
    activeAuth=result.auth;
    doc.getElementById('account-email').textContent=result.user.email;
    show('dashboard');
  }catch(error){
    if(error instanceof PrivateTesterAccessDenied){
      window.location.replace(PRIVATE_TESTER_LOGIN_PATH);
      return;
    }
    // Failed Auth/provider checks never reveal account details or game data.
    show('unavailable');
  }
}
signOutButton.addEventListener('click',async()=>{
  if(!activeAuth)return;
  signOutButton.disabled=true;
  feedback.textContent='Signing out…';
  try{
    await activeAuth.signOut();
    window.location.replace(PRIVATE_TESTER_LOGIN_PATH);
  }catch{
    feedback.textContent='Could not sign out. Please retry.';
    signOutButton.disabled=false;
  }
});
show('loading');
void initialize();
