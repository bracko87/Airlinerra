/**
 * Non-deploying, private Auth-provider readiness check for the official
 * Airlinerra prelaunch tester mode.
 *
 * Supabase browser SDK flags are NOT access control. Before an operator-only
 * account API opens on airlinerra.com, the actual pinned Supabase Auth
 * service must report that PUBLIC SIGNUP IS DISABLED, email confirmation is
 * required, and anonymous signup is disabled. Admin-invited test users may
 * still sign in. This never creates a user or changes provider configuration.
 */
import {AIRLINERRA_AUTH_API} from './hosted-runtime-config.mjs';

const PUBLIC_KEY=/^sb_publishable_[A-Za-z0-9_-]{16,128}$/u;
const SECURITY_TIMEOUT_MS=5000;

export async function inspectCanonicalTesterAuthReadiness({
  authUrl=AIRLINERRA_AUTH_API,
  publishableKey,
  fetchImpl=globalThis.fetch
}={}){
  if(authUrl!==AIRLINERRA_AUTH_API ||
     !PUBLIC_KEY.test(publishableKey||'') ||
     typeof fetchImpl!=='function'){
    throw new Error('Official Airlinerra Auth readiness requires a pinned public key.');
  }
  let response, settings;
  try{
    response=await fetchImpl(authUrl+'/auth/v1/settings',{
      method:'GET',
      headers:{apikey:publishableKey,accept:'application/json'},
      redirect:'error',
      cache:'no-store',
      signal:AbortSignal.timeout(SECURITY_TIMEOUT_MS)
    });
    if(response?.ok!==true ||
       !String(response.headers?.get?.('content-type')||'').includes('application/json')){
      throw new Error('Settings request unavailable.');
    }
    settings=await response.json();
  }catch{
    throw new Error('Cannot verify invite-only Supabase Auth settings.');
  }
  if(!settings || typeof settings!=='object' || Array.isArray(settings) ||
     settings.disable_signup!==true ||
     settings.mailer_autoconfirm!==false ||
     settings.external?.email!==true ||
     settings.external?.anonymous_users!==false){
    throw new Error('Supabase Auth must block public signup and require confirmed email.');
  }
  return Object.freeze({
    inviteOnly:true,
    emailConfirmationRequired:true,
    anonymousSignupDisabled:true
  });
}
