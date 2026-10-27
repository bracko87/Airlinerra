/**
 * SOURCE-ONLY factory for operator-invited test identities on the existing
 * https://airlinerra.com domain. It is deliberately NOT part of the public
 * website's dist/ allowlist until an approved hosted access flow exists.
 *
 * The Supabase publishable key is NOT authorization. Actual registration
 * prevention requires provider-wide disable_signup=true, independently
 * verified by the canonical backend. This module offers no signUp method.
 */
import {createAuthService} from './auth-service.mjs';
import {parseAuthCallback} from './auth-service.mjs';

const PROJECT='hwllkabgzaynalahvkpz';
const AUTH_ORIGIN='https://airlinerra.com';
const AUTH_URL='https://'+PROJECT+'.supabase.co';
const KEY=/^sb_publishable_[A-Za-z0-9_-]{16,128}$/u;
export const INVITED_TESTER_SDK_VERSION='2.118.0';
export const INVITED_TESTER_SDK_IMPORT='https://esm.sh/@supabase/supabase-js@2.118.0?bundle';

export function validatedInvitedTesterConfig({origin,supabaseUrl,publishableKey}={}){
  if(origin!==AUTH_ORIGIN||supabaseUrl!==AUTH_URL||!KEY.test(publishableKey||'')){
    throw new Error('Pinned Airlinerra invited-tester Auth configuration is required.');
  }
  return Object.freeze({origin:AUTH_ORIGIN,supabaseUrl:AUTH_URL,publishableKey});
}

export async function createInvitedTesterAuth({
  origin,supabaseUrl,publishableKey,
  loadSdk=()=>import(INVITED_TESTER_SDK_IMPORT)
}={}){
  // No SDK load, session persistence or network until the trusted caller
  // passes the official site, pinned Auth project and publishable key.
  const conf=validatedInvitedTesterConfig({origin,supabaseUrl,publishableKey});
  if(typeof loadSdk!=='function')throw new Error('Supabase Auth SDK loader required.');
  const sdk=await loadSdk();
  if(typeof sdk?.createClient!=='function')throw new Error('Supabase Auth SDK unavailable.');
  const client=sdk.createClient(conf.supabaseUrl,conf.publishableKey,{
    auth:{
      flowType:'pkce',
      detectSessionInUrl:false,
      persistSession:true,
      autoRefreshToken:true,
      storageKey:'airlinerra-invited-tester-v1'
    }
  });
  const service=createAuthService({supabase:client,origin:AUTH_ORIGIN,enabled:true});
  // Invite-only: never expose .register() to the official-domain test UI.
  return Object.freeze({
    signIn:service.signIn,
    signOut:service.signOut,
    getUser:service.getUser,
    requestPasswordReset:service.requestPasswordReset,
    completeCallback:service.completeCallback,
    updatePassword:service.updatePassword,
    parseAuthCallback
  });
}
