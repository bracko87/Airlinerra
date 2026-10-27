/**
 * Fresh server-side user verification against the pinned Supabase Auth service.
 * Uses the public API key (never a privileged service-role key); does NOT
 * interpret JWT claims locally or accept a client-supplied player ID.
 */
import {AIRLINERRA_AUTH_API} from './hosted-runtime-config.mjs';
const TOKEN = /^[A-Za-z0-9._~-]{16,8192}$/u;
const PUBLIC_KEY = /^sb_publishable_[A-Za-z0-9_-]{16,128}$/u;

export function createHostedAuthVerifier({
  authUrl=AIRLINERRA_AUTH_API,
  publishableKey,
  fetchImpl=globalThis.fetch
}={}) {
  if(authUrl !== AIRLINERRA_AUTH_API || !PUBLIC_KEY.test(publishableKey||'') ||
     typeof fetchImpl !== 'function') {
    throw new Error('Pinned Supabase Auth verifier configuration required.');
  }
  return async function verifyUserToken(token) {
    if(typeof token!=='string' || !TOKEN.test(token)) {
      return {user:null,error:{code:'invalid_token'}};
    }
    try {
      const response=await fetchImpl(authUrl+'/auth/v1/user',{
        method:'GET',
        headers:{
          apikey:publishableKey,
          authorization:'Bearer '+token,
          accept:'application/json'
        },
        cache:'no-store',
        redirect:'error',
        signal:AbortSignal.timeout(5000)
      });
      if(!response || response.ok!==true ||
         !String(response.headers?.get?.('content-type')||'').includes('application/json')) {
        return {user:null,error:{code:'unverified_user'}};
      }
      const data=await response.json();
      if(!data || typeof data!=='object' || Array.isArray(data) ||
          typeof data.id!=='string' || !data.email_confirmed_at ||
          data.is_anonymous===true || data.deleted_at) {
        return {user:null,error:{code:'unverified_user'}};
      }
      return {user:data,error:null};
    } catch {
      // Do not print bearer token, API key, response body, or network error.
      return {user:null,error:{code:'unavailable'}};
    }
  };
}
