/** Actual hosted Supabase registration for Airlinerra.
 * Only hosted email confirmation and database-backed accounts are supported.
 * Standard real signUp with email confirmation. Private pilot accounts follow
 * the SAME form but acknowledge review-only legal documents instead of
 * claiming that unapproved drafts are published Terms.
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
 if(!res.ok||!String(res.headers.get('content-type')||'').includes('text/html'))return 'missing';
 const html=await res.text();
 if(html.includes('data-airlinerra-legal-approved="true"'))return 'approved';
 if(html.includes('REVIEW DRAFT')&&html.includes('NOT YET EFFECTIVE'))return 'draft';
 return 'missing';
}
async function initialize(){
 if(!allowed.has(origin)){status.textContent='Registration is not available on this domain.';return}
 const conf=window.__AIRLINERRA_INVITED_TESTER_CONFIG__;
 if(conf?.operatorPrelaunchApproved!==true||conf?.supabaseUrl!==TESTER_AUTH_URL||
   !/^sb_publishable_[A-Za-z0-9_-]{16,128}$/.test(conf?.publishableKey||'')){
  status.textContent='Registration requires the trusted production Auth configuration.';return;
 }
 try{
  const [provider,terms,privacy,readinessResponse]=await Promise.all([
   inspectInvitedTesterProvider({publishableKey:conf.publishableKey}),
   officialDocument('/terms.html'),officialDocument('/privacy.html'),
   fetch('/api/v1/registration/readiness',{method:'GET',
     credentials:'omit',cache:'no-store',redirect:'error'})
  ]);
  const readiness=readinessResponse.ok?await readinessResponse.json():null;
  const normal=readiness?.registrationReady===true &&
    terms==='approved'&&privacy==='approved';
  const ownerPilot=readiness?.privateOwnerPilotAvailable===true &&
    terms==='draft'&&privacy==='draft';
  if(provider.signupEnabled!==true||(!normal&&!ownerPilot)){
   status.textContent='Account registration is not enabled yet. The real email service and protected game database must be ready.';
   return;
  }
  const consent=document.getElementById('registration-consent-description');
  if(ownerPilot){
   consent.textContent='I have reviewed the Terms and Privacy review drafts and understand that early game access is limited. These are not yet the final published policies.';
   document.getElementById('registration-mode').textContent='Early-access registration · Real email confirmation';
  }else{
   consent.textContent='I have read and accept the published Terms of Service and acknowledge the Privacy Policy.';
   document.getElementById('registration-mode').textContent='Register · Seven-day trial (no payment details)';
  }
  const sdk=await import(SUPABASE_SDK_IMPORT);
  sdkClient=sdk.createClient(conf.supabaseUrl,conf.publishableKey,{auth:{
   flowType:'pkce',detectSessionInUrl:false,persistSession:true,
   autoRefreshToken:true,storageKey:'airlinerra-invited-tester-v1'
  }});
  form.hidden=false;button.disabled=false;
  status.textContent='Register with your own email and password. Airlinerra sends a real confirmation email, then you sign in and set up your airline.';
 }catch{
  status.textContent='Registration could not be verified. Check that Supabase signup, the game API, and email confirmation are enabled.';
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
