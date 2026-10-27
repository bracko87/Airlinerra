/**
 * SOURCE ONLY: browser UI for the invited-account pilot.
 * This script and prelaunch-invited-account.html are deliberately excluded
 * from the public website build. They are not a player signup launch.
 */
import {createInvitedTesterAuth} from './invited-tester-auth.mjs';
import {
  consumeInvitedTesterEntry,openInvitedTesterEntry,
  TESTER_ORIGIN,TESTER_AUTH_URL
} from './invited-tester-entry.mjs';

const doc=window.document;
const feedback=doc.querySelector('#page-feedback');
const heading=doc.querySelector('#page-heading');
let activeAuth=null;
let otpAuthorizesPassword=false;
let currentPanel='';

function feedbackMessage(message,error=false){
  feedback.textContent=message;
  feedback.dataset.error=error?'true':'false';
}
function showPanel(panel,message=''){
  currentPanel=panel;
  for(const view of doc.querySelectorAll('[data-private-panel]')){
    view.hidden=view.dataset.privatePanel!==panel;
  }
  const title={
    'sign-in':'Sign in to your invitation',
    'forgot':'Recover your account',
    'set-password':'Choose your password',
    'signed-in':'Your account is verified'
  };
  heading.textContent=title[panel]||'Private account access unavailable';
  feedbackMessage(message);
}
function getInput(id){return doc.getElementById(id).value;}
async function submitOnce(form,job){
  const button=form.querySelector('button[type="submit"]');
  button.disabled=true;
  try{await job();}
  catch{
    feedbackMessage('This request could not be completed. Check your details or request a new link.',true);
  }finally{
    button.disabled=false;
    for(const input of form.querySelectorAll('input[type="password"]'))input.value='';
  }
}
async function showAuthenticatedUser(){
  const user=await activeAuth.getUser();
  if(!user?.email_confirmed_at||user.is_anonymous===true||user.deleted_at){
    await activeAuth.signOut().catch(()=>{});
    throw new Error('Invitation identity is not verified.');
  }
  otpAuthorizesPassword=false;
  showPanel('signed-in','Signed in as an invited manager. Airline creation remains closed.');
}

doc.getElementById('sign-in').addEventListener('submit',e=>{
  e.preventDefault();
  if(!activeAuth)return;
  void submitOnce(e.currentTarget,async()=>{
    await activeAuth.signIn({
      email:getInput('sign-in-email'),
      password:getInput('sign-in-password')
    });
    await showAuthenticatedUser();
  });
});
doc.getElementById('forgot').addEventListener('submit',e=>{
  e.preventDefault();
  if(!activeAuth)return;
  void submitOnce(e.currentTarget,async()=>{
    await activeAuth.requestPasswordReset(getInput('forgot-email'));
    // Avoid account enumeration regardless of whether an identity exists.
    feedbackMessage('If the address belongs to an invited account, a recovery email will be sent.');
  });
});
doc.getElementById('set-password').addEventListener('submit',e=>{
  e.preventDefault();
  if(!activeAuth||!otpAuthorizesPassword)return;
  void submitOnce(e.currentTarget,async()=>{
    const password=getInput('new-password');
    if(password!==getInput('confirm-password')||password.length<12||password.length>128){
      feedbackMessage('Choose matching passwords containing 12 to 128 characters.',true);
      return;
    }
    await activeAuth.updatePassword(password);
    otpAuthorizesPassword=false;
    showPanel('sign-in','Password updated. Sign in with your new password.');
  });
});
doc.getElementById('forgot-link').addEventListener('click',()=>{
  otpAuthorizesPassword=false;showPanel('forgot');
});
doc.getElementById('back-to-login').addEventListener('click',()=>{
  otpAuthorizesPassword=false;showPanel('sign-in');
});
doc.getElementById('sign-out').addEventListener('click',()=>{
  if(!activeAuth)return;
  void activeAuth.signOut().then(()=>showPanel('sign-in','Signed out.')).catch(()=>{
    feedbackMessage('Sign out could not be completed.',true);
  });
});

async function initialize(){
  // Scrub OTP/hash from browser history before network, SDK, config or awaits.
  const originalHref=window.location.href;
  let entry;
  try{
    entry=consumeInvitedTesterEntry({
      href:originalHref,
      replaceState:(...args)=>window.history.replaceState(...args)
    });
  }catch{
    heading.textContent='Invalid or expired account link';
    feedbackMessage('Request a new invitation or password reset link.',true);
    return;
  }
  const config=window.__AIRLINERRA_INVITED_TESTER_CONFIG__;
  if(window.location.origin!==TESTER_ORIGIN||
    config?.operatorPrelaunchApproved!==true||
    config?.supabaseUrl!==TESTER_AUTH_URL||
    typeof config?.publishableKey!=='string'){
    heading.textContent='Private accounts are not available yet';
    feedbackMessage('The invited-account pilot is not open on this site.');
    return;
  }
  try{
    const opened=await openInvitedTesterEntry({
      href:originalHref,
      // Already synchronously scrubbed; do not restore the old auth URL.
      replaceState:()=>{},
      publishableKey:config.publishableKey,
      createAuth:createInvitedTesterAuth
    });
    activeAuth=opened.auth;
    otpAuthorizesPassword=opened.screen==='set-password';
    if(otpAuthorizesPassword){
      showPanel('set-password',opened.message);
    }else if(entry.screen==='verify'&&!entry.callback){
      showPanel('sign-in','Use the link in your invitation email.');
    }else if(opened.screen==='forgot'){
      showPanel('forgot',opened.message);
    }else{
      try{
        await showAuthenticatedUser();
      }catch{
        showPanel('sign-in',opened.message||'Sign in with your invited email address.');
      }
    }
  }catch{
    heading.textContent='Private account access unavailable';
    feedbackMessage('The invitation-only identity service could not be verified.',true);
  }
}
void initialize();
