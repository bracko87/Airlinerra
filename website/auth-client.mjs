/**
 * Supabase JS browser Auth client, strictly disabled at public prelaunch.
 * The existing Airlinerra airport research project is never an Auth target.
 *
 * Development credentials must be explicitly injected from a SEPARATE,
 * operator-approved disposable/dev Supabase project. Publishable keys are
 * not secrets; NEVER supply a service-role/secret key to this browser module.
 */
import { PUBLIC_AUTH_ENABLED, ALLOWED_AUTH_ORIGINS } from './auth-rules.mjs';

export const SUPABASE_SDK_VERSION = '2.118.0';
export const SUPABASE_SDK_IMPORT = 'https://esm.sh/@supabase/supabase-js@2.118.0?bundle';

const RESEARCH_PROJECT_ID = 'hwllkabgzaynalahvkpz';
const LOCAL_SUPABASE_HOSTS = new Set(['localhost:54321', '127.0.0.1:54321']);

/** Pure config check. Cannot contact either development or production Auth. */
export function validatedDevelopmentAuthConfig({ supabaseUrl, publishableKey } = {}) {
  if (typeof supabaseUrl !== 'string' || typeof publishableKey !== 'string') {
    throw new Error('A separate development Auth project has not been configured.');
  }
  let url;
  try { url = new URL(supabaseUrl); }
  catch { throw new Error('Invalid development Auth URL.'); }
  const local = url.protocol === 'http:' && LOCAL_SUPABASE_HOSTS.has(url.host);
  const hosted = url.protocol === 'https:' &&
    /^[a-z0-9-]{15,32}\.supabase\.co$/u.test(url.hostname);
  if ((!local && !hosted) || url.username || url.password ||
      url.pathname !== '/' || url.search || url.hash ||
      url.hostname === RESEARCH_PROJECT_ID + '.supabase.co') {
    throw new Error('A separate development Supabase project is required.');
  }
  // For this development adapter, use modern public publishable keys only.
  // Do not accept service-role JWTs or Supabase secret keys here.
  if (!/^sb_publishable_[A-Za-z0-9_-]{16,128}$/u.test(publishableKey)) {
    throw new Error('A development publishable key is required.');
  }
  return Object.freeze({ supabaseUrl: url.origin, publishableKey });
}

export async function createBrowserAuthClient({
  origin,
  enabled = PUBLIC_AUTH_ENABLED,
  supabaseUrl,
  publishableKey,
  loadSdk = () => import(SUPABASE_SDK_IMPORT)
} = {}) {
  // Immutable public launch hard-stop: no URL parsing, network or SDK load.
  if (!PUBLIC_AUTH_ENABLED || !enabled) {
    throw new Error('Airlinerra account registration and sign-in are not yet open.');
  }
  if (!ALLOWED_AUTH_ORIGINS.includes(origin)) {
    throw new Error('This origin is not authorized for account authentication.');
  }
  const config = validatedDevelopmentAuthConfig({ supabaseUrl, publishableKey });
  const { createClient } = await loadSdk();
  if (typeof createClient !== 'function') throw new Error('Supabase SDK unavailable.');
  return createClient(config.supabaseUrl, config.publishableKey, {
    auth: {
      flowType: 'pkce',
      detectSessionInUrl: false,
      persistSession: true,
      autoRefreshToken: true,
      storageKey: 'airlinerra-auth-dev-v1'
    }
  });
}
