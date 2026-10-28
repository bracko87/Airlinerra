/** Actual hosted Supabase registration for Airlinerra.
 * Only hosted email confirmation and database-backed accounts are supported.
 * Provider signup and real published legal pages are prerequisites.
 */
import {normalizedEmail,validatedPassword,validatedDisplayName} from './auth-rules.mjs';
import {inspectInvitedTesterProvider,TESTER_AUTH_URL} from './invited-tester-entry.mjs';
import {SUPABASE_SDK_IMPORT} from './auth-client.mjs';
const allowed=new Set(['http://localhost:5188','https://airlinerra.com']);
const form=document.getElementById('real-registration-form');
const status=document.getElementById('registration-readiness');
const feedback=document.getElementById('registration-feedback');
const button=document.getElementById('real-register-submit');
const origin=window.location.origin;
let sdkClient=null;
async function officialDocument(path){
 const res=await fetch(path,{method:'GET',cache:'no-store',credentials:'omit',redirect:'error'});
 if(!res.ok||!String(res.headers.get('content-type')||'').includes('text/html'))return false;
 const text=await res.text();
 // A missing legal address or unfinished draft does not authorize signup.
 return text.includes('data-airlinerra-legal-approved="true"');
}
async function initialize(){
 if(!allowed.has(origin)){status.textContent='Registration is not available on this domain.';return}
 const conf=window.__AIRLINERRA_INVITED_TESTER_CONFIG__;
 if(conf?.operatorPrelaunchApproved!==true||conf?.supabaseUrl!==TESTER_AUTH_URL||
   !/^sb_publishable_[A-Za-z0-9_-]{16,128}$/.test(conf?.publishableKey||'')){
  status.textContent='Registration requires the trusted production Auth configuration.';return;
 }
 try{
  const [provider,terms,privacy]=await Promise.all([
   inspectInvitedTesterProvider({publishableKey:conf.publishableKey}),
   officialDocument('/terms.html'),officialDocument('/privacy.html')
  ]);
  if(provider.signupEnabled!==true||!terms||!privacy){
   status.textContent='Registration is not open yet. The real Supabase signup setting and approved legal documents must be ready first.';
   return;
  }
  const sdk=await import(SUPABASE_SDK_IMPORT);
  sdkClient=sdk.createClient(conf.supabaseUrl,conf.publishableKey,{auth:{
   flowType:'pkce',detectSessionInUrl:false,persistSession:true,
   autoRefreshToken:true,storageKey:'airlinerra-invited-tester-v1'
  }});
  form.hidden=false;button.disabled=false;
  status.textContent='Registration is open. Your confirmation email will be sent by Airlinerra.';
 }catch{
  status.textContent='Registration is unavailable. Verify the hosted Auth provider and published legal documents.';
 }
}
form.addEventListener('submit',async event=>{
 event.preventDefault();
 if(!sdkClient||!form.reportValidity())return;
 button.disabled=true;
 feedback.textContent='Submitting registration…';
 try{
  if(!document.getElementById('new-manager-consent').checked)throw Error('Review both legal documents');
  const email=normalizedEmail(document.getElementById('new-manager-email').value);
  const password=validatedPassword(document.getElementById('new-manager-password').value);
  const displayName=validatedDisplayName(document.getElementById('new-manager-name').value);
  const {error}=await sdkClient.auth.signUp({
   email,password,options:{
    data:{display_name:displayName},
    emailRedirectTo:origin+'/account.html?screen=verify'
   }
  });
  if(error)throw error;
  feedback.textContent='If registration was accepted, check your inbox for the Airlinerra confirmation email. Confirm it to proceed to airline setup.';
  document.getElementById('new-manager-password').value='';
 }catch{
  feedback.textContent='Registration was not completed. Check your details or contact support.';
 }finally{button.disabled=false;}
});
void initialize();
