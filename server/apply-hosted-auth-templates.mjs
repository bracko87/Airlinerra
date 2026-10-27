/**
 * One-purpose Supabase Management API writer, manually dispatched in CI.
 * Not imported by the public website and never shipped with the Netlify site.
 * Updates exactly the three owner-reviewed Airlinerra Auth email templates.
 */
import {readFile} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';

const PROJECT='hwllkabgzaynalahvkpz';
const MANAGEMENT_URL='https://api.supabase.com/v1/projects/'+PROJECT+'/config/auth';
const FILE_ROOT=new URL('../supabase/templates/',import.meta.url);
const CONFIG=Object.freeze([
  {code:'invite',subject:"You're invited to test Airlinerra",screen:'verify',kind:'invite'},
  {code:'confirmation',subject:'Confirm your Airlinerra email',screen:'verify',kind:'email'},
  {code:'recovery',subject:'Reset your Airlinerra password',screen:'reset',kind:'recovery'}
]);

function assertTemplate(code,html,screen,kind){
  if(typeof html!=='string'||html.length<100||html.length>15000||
    !html.includes('{{ .TokenHash }}')||
    !html.includes('{{ .SiteURL }}')||
    !html.includes('/account.html?screen='+screen)||
    !html.includes('type='+kind)||
    html.includes('{{ .ConfirmationURL }}')||
    !/<a href="/.test(html)){
    throw new Error('Refusing invalid reviewed '+code+' Auth template.');
  }
}
export async function readTemplates(read=readFile){
  const patch={};
  for(const item of CONFIG){
    const html=await read(new URL(item.code==='invite'?'invite.html':item.code+'.html',FILE_ROOT),'utf8');
    assertTemplate(item.code,html,item.screen,item.kind);
    patch['mailer_subjects_'+item.code]=item.subject;
    patch['mailer_templates_'+item.code+'_content']=html;
  }
  return Object.freeze(patch);
}
function assertSafeExistingAuth(state){
  if(!state||Array.isArray(state)||state.disable_signup!==true||
    state.external_anonymous_users_enabled!==false||
    state.mailer_autoconfirm!==false||
    state.external_email_enabled!==true||
    state.smtp_host!=='smtp.resend.com'||
    state.smtp_admin_email!=='noreply@nextqueststudio.net'){
    throw new Error('Refusing template update: hosted Auth or SMTP safety gate is not verified.');
  }
}
async function request(fetchImpl,token,method,body){
  let response;
  try{
    response=await fetchImpl(MANAGEMENT_URL,{
      method,redirect:'error',
      headers:{
        'authorization':'Bearer '+token,
        'accept':'application/json',
        ...(body?{'content-type':'application/json'}:{})
      },
      ...(body?{body:JSON.stringify(body)}:{}),
      signal:AbortSignal.timeout(12000)
    });
  }catch{
    throw new Error('Supabase Management API connection unavailable.');
  }
  if(!response||!response.ok){
    // NEVER echo response bodies, header values, tokens, or provider secrets.
    throw new Error('Supabase Auth '+method+' failed: status '+(response?.status||'unknown')+'.');
  }
  try{
    return await response.json();
  }catch{
    throw new Error('Supabase Auth response is not valid JSON.');
  }
}
export async function applyAirlinerraTemplates({
  token,fetchImpl=globalThis.fetch,read=readFile,apply=false
}={}){
  if(typeof token!=='string'||token.length<20||typeof fetchImpl!=='function'){
    throw new Error('A secure dedicated Supabase Management API credential is required.');
  }
  const patch=await readTemplates(read);
  const prior=await request(fetchImpl,token,'GET');
  assertSafeExistingAuth(prior);
  if(!apply)return Object.freeze({mode:'dry-run',safeAuth:true,templates:CONFIG.map(c=>c.code)});
  await request(fetchImpl,token,'PATCH',patch);
  const after=await request(fetchImpl,token,'GET');
  assertSafeExistingAuth(after);
  for(const [name,value] of Object.entries(patch)){
    if(after[name]!==value){
      throw new Error('Supabase did not persist reviewed field '+name+'.');
    }
  }
  return Object.freeze({mode:'applied',safeAuth:true,verified:true,templates:CONFIG.map(c=>c.code)});
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  if(process.argv.slice(2).join(' ')!=='--apply'){
    process.stderr.write('Manual workflow only: pass --apply after authorization.\n');
    process.exitCode=2;
  }else{
    try{
      const outcome=await applyAirlinerraTemplates({
        token:process.env.AIRLINERRA_SUPABASE_AUTH_TEMPLATES_TOKEN,
        apply:true
      });
      process.stdout.write('Airlinerra hosted Auth '+outcome.mode+
        ': invite, confirmation and recovery verified; invite-only protections preserved.\n');
    }catch(error){
      // Only our fixed messages; no HTTP response content is logged.
      process.stderr.write(String(error.message).slice(0,250)+'\n');
      process.exitCode=1;
    }
  }
}
