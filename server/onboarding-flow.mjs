/**
 * Pure, server-oriented Airlinerra onboarding progress classifier.
 * Display/readiness ONLY: never use this result as authorization, and never
 * skip create_airline_once's independent PostgreSQL checks.
 * No player accounts, worlds or airport admissions are created by this module.
 */
const OPEN_STATES = new Set(['registration_open', 'active']);
const PAYMENT_BLOCKS = new Set(['expired', 'suspended', 'past_due']);

function stage(next, extras={}) {
  return Object.freeze({next, ...extras});
}

export function onboardingNextStep({
  user = null,
  publishedPolicy = null,
  consent = null,
  entitlement = null,
  worlds = [],
  selectedWorldId = null,
  approvedAirportIds = [],
  selectedAirportId = null,
  existingAirline = null,
  evaluatedAt
} = {}) {
  if (!user?.id) return stage('sign_in');
  if (user.is_anonymous === true || user.deleted_at ||
      (user.banned_until && Date.parse(user.banned_until) > Date.parse(evaluatedAt))) {
    return stage('account_restricted');
  }
  if (!user.email_confirmed_at) return stage('verify_email');

  if (!publishedPolicy?.is_published || !publishedPolicy?.approved_at ||
      !publishedPolicy.terms_version || !publishedPolicy.privacy_version) {
    return stage('legal_unavailable');
  }
  if (consent?.terms_version !== publishedPolicy.terms_version ||
      consent?.privacy_version !== publishedPolicy.privacy_version) {
    return stage('accept_legal', {
      termsVersion: publishedPolicy.terms_version,
      privacyVersion: publishedPolicy.privacy_version
    });
  }

  if (PAYMENT_BLOCKS.has(entitlement?.membership_state)) {
    return stage('subscription_required');
  }
  if (entitlement?.membership_state === 'trial') {
    const expiry=Date.parse(entitlement.trial_ends_at);
    const now=Date.parse(evaluatedAt);
    if (!Number.isFinite(expiry) || !Number.isFinite(now) || now >= expiry) {
      return stage('subscription_required');
    }
  }
  if (existingAirline?.id) {
    return stage('airline_ready', {airlineId:existingAirline.id});
  }

  const openWorlds = Array.isArray(worlds) ?
    worlds.filter(w=>Number.isInteger(w?.id) && w.id >= 1 && w.id <= 3 &&
      OPEN_STATES.has(w.state)) : [];
  if (openWorlds.length === 0) return stage('worlds_unavailable');
  const ids = Object.freeze(openWorlds.map(w=>w.id).sort((a,b)=>a-b));
  if (selectedWorldId == null) {
    return stage('select_world', {openWorldIds:ids});
  }
  if (!ids.includes(selectedWorldId)) {
    return stage('world_unavailable', {openWorldIds:ids});
  }

  const options = Array.isArray(approvedAirportIds) ? approvedAirportIds : [];
  if (options.length === 0) return stage('airports_unavailable');
  if (!options.some(id=>String(id) === String(selectedAirportId))) {
    return stage('select_home_airport');
  }
  // The backend must re-check legal, airport, session, membership, world,
  // cash ledger and trial in the atomic create_airline_once transaction.
  return stage('ready_to_request_airline');
}
