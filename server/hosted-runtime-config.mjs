/**
 * Non-deploying, server-only prelaunch configuration.
 * Secrets come from a host's function-scoped runtime environment, NEVER
 * Netlify TOML or browser JS. Nothing is read if the runtime is disabled.
 */
export const AIRLINERRA_PROJECT_REF = 'hwllkabgzaynalahvkpz';
export const AIRLINERRA_AUTH_API = `https://${AIRLINERRA_PROJECT_REF}.supabase.co`;
const ALLOWED_PREVIEW_CONTEXTS = new Set(['deploy-preview', 'branch-deploy']);
const HTTPS_ORIGIN = /^https:\/\/[a-z0-9-]+(?:\.[a-z0-9-]+)+(?::[0-9]{2,5})?$/u;
const PUBLISHABLE_KEY = /^sb_publishable_[A-Za-z0-9_-]{16,128}$/u;
const DOC_PATH = /^\/[A-Za-z0-9._/-]{1,160}\.html$/u;

export function parseHostedRuntimeConfig(env = {}) {
  // Checking the two deliberate gates first means disabled deployments do
  // not even inspect connection strings, keys or URLs.
  if (env.AIRLINERRA_HOSTED_BACKEND_ENABLED !== 'true' ||
      env.AIRLINERRA_PRIVATE_PREVIEW_APPROVED !== 'true') {
    return Object.freeze({enabled:false});
  }
  if (!ALLOWED_PREVIEW_CONTEXTS.has(env.CONTEXT)) {
    throw new Error('Hosted accounts are forbidden in production context.');
  }
  const origin = env.AIRLINERRA_PREVIEW_ORIGIN;
  if (typeof origin !== 'string' || !HTTPS_ORIGIN.test(origin)) {
    throw new Error('A pinned HTTPS preview origin is required.');
  }
  const parsedOrigin = new URL(origin);
  if (parsedOrigin.username || parsedOrigin.password ||
      parsedOrigin.pathname !== '/' || parsedOrigin.search || parsedOrigin.hash ||
      ['localhost','127.0.0.1'].includes(parsedOrigin.hostname)) {
    throw new Error('A valid HTTPS preview origin is required.');
  }
  if (env.AIRLINERRA_SUPABASE_URL !== AIRLINERRA_AUTH_API) {
    throw new Error('Unrecognized account Auth project.');
  }
  const key = env.AIRLINERRA_SUPABASE_PUBLISHABLE_KEY;
  if (typeof key !== 'string' || !PUBLISHABLE_KEY.test(key)) {
    throw new Error('Only a publishable Supabase Auth key is permitted.');
  }
  const termsPath = env.AIRLINERRA_TERMS_PATH;
  const privacyPath = env.AIRLINERRA_PRIVACY_PATH;
  if (!DOC_PATH.test(termsPath || '') || !DOC_PATH.test(privacyPath || '') ||
      termsPath === privacyPath || /(?:^|\/)(?:ci|test|synthetic)[-_.]/i.test(termsPath+privacyPath)) {
    throw new Error('Reviewed versioned legal document paths are required.');
  }

  const raw = env.AIRLINERRA_PRIVATE_DATABASE_URL;
  // DB connection credentials must never be included in exceptions/logs.
  let db;
  try { db = new URL(raw); } catch {
    throw new Error('A trusted private database URL is required.');
  }
  if (!['postgresql:','postgres:'].includes(db.protocol) ||
      !db.username || !db.password || db.pathname !== '/postgres' ||
      db.hash || db.searchParams.size > 1 ||
      (db.searchParams.size === 1 && db.searchParams.get('sslmode') !== 'require')) {
    throw new Error('Invalid private PostgreSQL connection configuration.');
  }
  const directHost = `db.${AIRLINERRA_PROJECT_REF}.supabase.co`;
  const isDirect = db.hostname === directHost && db.username === 'postgres';
  const isPooler = /^[a-z0-9-]+\.pooler\.supabase\.com$/u.test(db.hostname) &&
    decodeURIComponent(db.username) === `postgres.${AIRLINERRA_PROJECT_REF}`;
  if (!(isDirect || isPooler)) {
    throw new Error('Private PostgreSQL must belong to the Airlinerra project.');
  }
  if (!db.port || !['5432','6543'].includes(db.port)) {
    throw new Error('Explicit, supported PostgreSQL port required.');
  }
  return Object.freeze({
    enabled:true,
    context:env.CONTEXT,
    publicOrigin:parsedOrigin.origin,
    supabaseUrl:AIRLINERRA_AUTH_API,
    publishableKey:key,
    dbUrl:raw,
    termsPath,
    privacyPath
  });
}
