/**
 * Browser bridge to the private same-origin onboarding API.
 * Requires freshly verified Auth identity, and transmits only the access
 * token to the trusted backend (which RE-verifies it and all DB release gates).
 * Never queries, approves or modifies airport research directly.
 */
import { PUBLIC_AUTH_ENABLED, ALLOWED_AUTH_ORIGINS } from './auth-rules.mjs';

const AIRPORT_KEY = /^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const POLICY = /^[A-Za-z0-9][A-Za-z0-9._-]{0,49}$/u;

function cleanAirlineRequest(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      !Number.isInteger(data.worldId) || data.worldId < 1 || data.worldId > 3 ||
      typeof data.airlineName !== 'string' || typeof data.homeAirportKey !== 'string') {
    throw new Error('Select an eligible world, airline name and approved home airport.');
  }
  const name = data.airlineName.trim().normalize('NFKC').replace(/\s+/gu,' ');
  if (name.length < 3 || name.length > 80 || /[\x00-\x1f\x7f<>]/u.test(name) ||
      !AIRPORT_KEY.test(data.homeAirportKey)) {
    throw new Error('Airline or home airport details are invalid.');
  }
  return Object.freeze({ worldId:data.worldId, airlineName:name,
    homeAirportKey:data.homeAirportKey });
}
function cleanLegalRequest(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data) ||
      data.acceptTerms !== true || data.acceptPrivacy !== true ||
      typeof data.termsVersion !== 'string' || !POLICY.test(data.termsVersion) ||
      typeof data.privacyVersion !== 'string' || !POLICY.test(data.privacyVersion)) {
    throw new Error('Review and explicitly accept the published Terms and Privacy Policy.');
  }
  return Object.freeze({
    termsVersion:data.termsVersion, privacyVersion:data.privacyVersion,
    acceptTerms:true, acceptPrivacy:true
  });
}

export function createOnboardingApiClient({
  supabase, origin, enabled = PUBLIC_AUTH_ENABLED,
  fetchImpl = (...args) => fetch(...args)
} = {}) {
  if (!supabase?.auth || typeof supabase.auth.getUser !== 'function' ||
      typeof supabase.auth.getSession !== 'function' ||
      typeof fetchImpl !== 'function') {
    throw new Error('A trusted development Auth client and fetch adapter are required.');
  }
  const allowOrigin = ALLOWED_AUTH_ORIGINS.includes(origin);
  async function post(path, payload) {
    if (!enabled) {
      throw new Error('Airlinerra player onboarding is not yet open.');
    }
    if (!allowOrigin) throw new Error('Account API origin is not authorized.');
    // getUser() contacts Supabase Auth; getSession() is token retrieval ONLY.
    // The server independently verifies the forwarded bearer token again.
    const verified = await supabase.auth.getUser();
    const user = verified?.data?.user;
    if (verified.error || typeof user?.id !== 'string' ||
        !user.email_confirmed_at || user.is_anonymous === true ||
        user.deleted_at) {
      throw new Error('Sign in with a verified account before continuing.');
    }
    const sessionResponse = await supabase.auth.getSession();
    const session = sessionResponse?.data?.session;
    if (sessionResponse?.error || !session?.access_token ||
        session.user?.id !== user.id) {
      throw new Error('Your login session changed. Please sign in again.');
    }
    const json = JSON.stringify(payload);
    if (new TextEncoder().encode(json).length > 2048) {
      throw new Error('Onboarding details exceed the request limit.');
    }
    let response;
    try {
      response = await fetchImpl(origin + path, {
        method:'POST',
        headers: {
          'content-type':'application/json',
          authorization:'Bearer ' + session.access_token
        },
        body:json, mode:'same-origin', credentials:'omit',
        cache:'no-store', redirect:'error', referrerPolicy:'no-referrer'
      });
    } catch {
      throw new Error('The account service is currently unavailable.');
    }
    if (response.status === 401) throw new Error('Please sign in again.');
    if (response.status === 403) throw new Error('Account request was not authorized.');
    if (response.status === 409) throw new Error('Your information has changed. Review the current requirements.');
    if (response.status !== 200 && response.status !== 201) {
      throw new Error('The account service is currently unavailable.');
    }
    let data;
    try { data = await response.json(); }
    catch { throw new Error('Invalid response from the account service.'); }
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      throw new Error('Invalid response from the account service.');
    }
    return Object.freeze(data);
  }
  return Object.freeze({
    loadContext: () => post('/api/v1/onboarding/context',{}),
    acceptLegal: data => post('/api/v1/legal/consents',cleanLegalRequest(data)),
    createAirline: data => post('/api/v1/airlines',cleanAirlineRequest(data))
  });
}
