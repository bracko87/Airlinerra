/** Actual hosted Supabase registration for Airlinerra.
 * Only hosted email confirmation and database-backed accounts are supported.
 * Standard real signUp with email confirmation. Private pilot accounts follow
 * the SAME form but acknowledge review-only legal documents instead of
 * claiming that unapproved drafts are published Terms.
 */
import {normalizedEmail,validatedPassword,validatedDisplayName,passwordStrength} from './auth-rules.mjs';
import {inspectInvitedTesterProvider,TESTER_AUTH_URL} from './invited-tester-entry.mjs';
import {SUPABASE_SDK_IMPORT} from './auth-client.mjs';
import {evaluateRegistrationAccess} from './registration-access.mjs';
const allowed=new Set(['http://localhost:5188','https://airlinerra.com']);
const form=document.getElementById('real-registration-form');
const status=document.getElementById('registration-readiness');
const feedback=document.getElementById('registration-feedback');
const button=document.getElementById('real-register-submit');
const origin=window.location.origin;
let sdkClient=null;
const passwordInput=document.getElementById('new-manager-password');
const confirmInput=document.getElementById('new-manager-password-confirm');
const strengthMeter=document.getElementById('password-strength-meter');
const strengthLabel=document.getElementById('password-strength-label');
function updatePasswords(){
 const strength=passwordStrength(passwordInput.value);
 strengthMeter.value=strength.score;
 strengthLabel.textContent='Password strength: '+strength.label;
 confirmInput.setCustomValidity(confirmInput.value!==''&&confirmInput.value!==passwordInput.value?'Passwords do not match.':'');
}
passwordInput.addEventListener('input',updatePasswords);
confirmInput.addEventListener('input',updatePasswords);
function blocked(message){
 form.hidden=true;button.disabled=true;
 status.dataset.status='blocked';
 status.textContent=message;
}

async function officialDocument(path){
 const res=await fetch(path,{method:'GET',cache:'no-store',credentials:'omit',redirect:'error'});
 if(!res.ok||!String(res.headers.get('content-type')||'').includes('text/html'))return 'missing';
 const html=await res.text();
 if(html.includes('data-airlinerra-legal-approved="true"'))return 'approved';
 if(html.includes('REVIEW DRAFT')&&html.includes('NOT YET EFFECTIVE'))return 'draft';
 return 'missing';
}
async function initialize(){
 if(!allowed.has(origin)){blocked('Registration is not available on this domain.');return}
 const conf=window.__AIRLINERRA_INVITED_TESTER_CONFIG__;
 if(conf?.operatorPrelaunchApproved!==true||conf?.supabaseUrl!==TESTER_AUTH_URL||
   !/^sb_publishable_[A-Za-z0-9_-]{16,128}$/.test(conf?.publishableKey||'')){
  blocked('Registration requires the trusted production Auth configuration.');return;
 }
 try{
  const [provider,terms,privacy,readinessResponse]=await Promise.all([
   inspectInvitedTesterProvider({publishableKey:conf.publishableKey}),
   officialDocument('/terms.html'),officialDocument('/privacy.html'),
   fetch('/api/v1/registration/readiness',{method:'GET',
     credentials:'omit',cache:'no-store',redirect:'error'})
  ]);
  if(!readinessResponse.ok){
    if(readinessResponse.status===503){
      const body=await readinessResponse.json().catch(()=>null);
      const detail=body?.error==='Game account database is not configured'
        ?'The Netlify game API is missing its server settings. Check AIRLINERRA_PRODUCTION_API_ENABLED and AIRLINERRA_DATABASE_URL in Netlify Environment variables.'
        :'The Netlify game API cannot reach or query the live Supabase database. Check Netlify Function logs and its database connection.';
      blocked('Registration is temporarily unavailable. '+detail);return;
    }
    blocked('Registration API error HTTP '+readinessResponse.status+'. Check the Netlify game Function deployment.');return;
  }
  const readiness=await readinessResponse.json().catch(()=>null);
  if(!readiness||typeof readiness!=='object'){
    blocked('The game API did not return a valid registration status.');return;
  }
  if(provider.signupEnabled!==true){
    blocked('Email registration is disabled in Supabase Authentication. Enable signups after activating the approved owner-only Before User Created hook.');return;
  }
  const access=evaluateRegistrationAccess({provider,readiness,terms,privacy});
  if(access.mode==='closed'){
   blocked('Account registration is not yet authorized. Check the approved early-access backend and legal documents.');
   return;
  }
  const consent=document.getElementById('registration-consent-description');
  if(access.mode==='owner-pilot'){
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
  status.dataset.status='ready';
  status.textContent='Registration ready. Enter your details to receive a real confirmation email.';
 }catch{
  blocked('Registration could not be verified. Check the Netlify game API and Supabase email signup settings.');
 }
}
form.addEventListener('submit',async event=>{
 event.preventDefault();
 updatePasswords();
 if(!sdkClient||!form.reportValidity())return;
 button.disabled=true;
 feedback.textContent='Submitting registration…';
 try{
  if(!document.getElementById('new-manager-consent').checked)throw Error('Review both legal documents');
  const email=normalizedEmail(document.getElementById('new-manager-email').value);
  const password=validatedPassword(passwordInput.value);
  if(password!==confirmInput.value)throw Error('Passwords do not match.');
  const displayName=validatedDisplayName(document.getElementById('new-manager-name').value);
  const {error}=await sdkClient.auth.signUp({
   email,password,options:{
    data:{display_name:displayName},
    emailRedirectTo:origin+'/account.html?screen=verify'
   }
  });
  if(error)throw error;
  feedback.textContent='If registration was accepted, check your inbox for the Airlinerra confirmation email. Confirm it to proceed to airline setup.';
  passwordInput.value='';confirmInput.value='';updatePasswords();
 }catch{
  feedback.textContent='Registration was not completed. Check your details or contact support.';
 }finally{button.disabled=false;}
});
void initialize();
