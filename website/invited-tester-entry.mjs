/**
 * SOURCE-ONLY, not included in the public Airlinerra build.
 * Controlled prelaunch callback transport for administrator-invited users.
 * NEVER enable general signup or initialize Auth for an unknown origin.
 */
import {parseAuthCallback} from './auth-service.mjs';

export const TESTER_ORIGIN='https://airlinerra.com';
export const TESTER_AUTH_URL='https://hwllkabgzaynalahvkpz.supabase.co';
const KEY=/^sb_publishable_[A-Za-z0-9_-]{16,128}$/u;
const ALLOWED_SCREENS=new Set(['sign-in','forgot','reset','verify']);

/**
 * Synchronously destroy emailed OTPs/PKCE codes from the address bar BEFORE
 * any network request, SDK download, or other asynchronous work.
 */
export function consumeInvitedTesterEntry({href,replaceState}={}){
  if(typeof href!=='string'||typeof replaceState!=='function'){
    throw new Error('A trusted browser location and history are required.');
  }
  const url=new URL(href);
  if(url.origin!==TESTER_ORIGIN||url.pathname!=='/account.html'){
    throw new Error('Private tester callbacks require the official domain.');
  }
  const requested=url.searchParams.get('screen');
  const screen=ALLOWED_SCREENS.has(requested)?requested:'sign-in';
  const rawSearch=url.search;
  const hasFragment=!!url.hash;
  replaceState({},'',url.pathname+'?screen='+screen);
  if(hasFragment)throw new Error('Unsupported private tester callback.');
  const callback=parseAuthCallback(rawSearch,screen);
  if(screen==='reset'&&!callback){
    return Object.freeze({screen:'forgot',callback:null,needsRecoveryLink:true});
  }
  return Object.freeze({screen,callback,needsRecoveryLink:false});
}

/**
 * Browser-side safety check complements (never replaces) Supabase's hosted
 * provider controls and the canonical private server readiness check.
 * Public publishable keys authorize NOTHING by themselves.
 */
export async function inspectInvitedTesterProvider({
  supabaseUrl=TESTER_AUTH_URL,publishableKey,fetchImpl=globalThis.fetch
}={}){
  if(supabaseUrl!==TESTER_AUTH_URL||!KEY.test(publishableKey||'')||
    typeof fetchImpl!=='function'){
    throw new Error('Pinned invite-only Auth configuration is required.');
  }
  let settings;
  try{
    const response=await fetchImpl(TESTER_AUTH_URL+'/auth/v1/settings',{
      method:'GET',
      headers:{apikey:publishableKey,accept:'application/json'},
      cache:'no-store',
      redirect:'error',
      signal:AbortSignal.timeout(5000)
    });
    if(response?.ok!==true ||
      !String(response.headers?.get?.('content-type')||'').includes('application/json')){
      throw new Error('Unavailable.');
    }
    settings=await response.json();
  }catch{
    throw new Error('Cannot verify private tester access.');
  }
  if(!settings||Array.isArray(settings)||
    settings.disable_signup!==true||settings.mailer_autoconfirm!==false||
    settings.external?.email!==true||settings.external?.anonymous_users!==false){
    throw new Error('Private tester access is not authorized by the identity provider.');
  }
  return Object.freeze({inviteOnly:true,emailConfirmedRequired:true,anonymousDisabled:true});
}

/**
 * No Auth client or third-party SDK can be loaded before operator origin and
 * hosted Auth invite-only state are verified.
 */
export async function openInvitedTesterEntry({
  href,replaceState,publishableKey,
  fetchImpl=globalThis.fetch,createAuth
}={}){
  const entry=consumeInvitedTesterEntry({href,replaceState});
  if(typeof createAuth!=='function')throw new Error('Invited tester Auth factory required.');
  await inspectInvitedTesterProvider({publishableKey,fetchImpl});
  const auth=await createAuth({
    origin:TESTER_ORIGIN,supabaseUrl:TESTER_AUTH_URL,publishableKey
  });
  if(auth?.signIn===undefined||auth?.register!==undefined||auth?.signUp!==undefined||
    auth?.completeCallback===undefined||auth?.updatePassword===undefined){
    throw new Error('Invalid invited-tester Auth surface.');
  }
  if(!entry.callback){
    return Object.freeze({screen:entry.screen,auth,message:entry.needsRecoveryLink?
      'Request a new password recovery email.':''});
  }
  const outcome=await auth.completeCallback(entry.callback);
  if(outcome?.purpose==='invite'||outcome?.purpose==='reset'){
    return Object.freeze({screen:'set-password',auth,message:outcome.purpose==='invite'?
      'Invitation verified. Choose your account password.':
      'Recovery verified. Choose a new password.'});
  }
  if(outcome?.purpose==='verify'){
    return Object.freeze({screen:'sign-in',auth,message:'Email verified. You can sign in.'});
  }
  throw new Error('Unexpected account verification result.');
}
