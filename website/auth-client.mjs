/**
 * Supabase JS browser client adapter — release-gated.
 * The official SDK version is pinned for local integration evaluation.
 * Before a PUBLIC launch, replace external ESM delivery with a build-time
 * audited dependency and committed package lock + CSP policy.
 */
import { PUBLIC_AUTH_ENABLED, ALLOWED_AUTH_ORIGINS } from './auth-rules.mjs';

export const SUPABASE_SDK_VERSION = '2.118.0';
export const SUPABASE_SDK_IMPORT = 'https://esm.sh/@supabase/supabase-js@2.118.0?bundle';
const SUPABASE_URL = 'https://hwllkabgzaynalahvkpz.supabase.co';
// Supabase publishable keys are public; never use a service-role/secret key here.
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_XznHs5hhAddw-wbYtKodRg_C5RtM5vg';

export async function createBrowserAuthClient({
  origin,
  enabled = PUBLIC_AUTH_ENABLED,
  loadSdk = () => import(SUPABASE_SDK_IMPORT)
} = {}) {
  // The first condition is intentionally immutable at runtime until release.
  if (!PUBLIC_AUTH_ENABLED || !enabled) {
    throw new Error('Airlinerra account registration and sign-in are not yet open.');
  }
  if (!ALLOWED_AUTH_ORIGINS.includes(origin)) {
    throw new Error('This origin is not authorized for account authentication.');
  }
  const { createClient } = await loadSdk();
  if (typeof createClient !== 'function') throw new Error('Supabase SDK unavailable.');
  return createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
    auth: {
      flowType: 'pkce',
      detectSessionInUrl: false, // callback code exchange is explicit.
      persistSession: true,
      autoRefreshToken: true,
      storageKey: 'airlinerra-auth-v1'
    }
  });
}
