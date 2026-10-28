/**
 * Internal, pure trial calculations for trusted server use and deterministic QA.
 * NOT a payment gateway, account creation endpoint, world-join API, or a
 * frontend entitlement decision. DB uniqueness + trusted transaction enforce
 * one trial per account; this module cannot grant gameplay access.
 */
export const TRIAL_DAYS = 7;
export const TRIAL_DURATION_MS = 7 * 24 * 60 * 60 * 1000;
export const STARTING_CAPITAL_USD = 5_000_000;
export const STARTING_AIRCRAFT_COUNT = 0;

// Owner-approved 28 Oct 2026: registration and the seven-day trial require
// NO payment details, NEVER auto-convert, and incur NO automatic charge.
// Paid membership must be a separate, explicit player choice after the trial.
export const TRIAL_PAYMENT_METHOD_REQUIRED = false;
export const TRIAL_AUTO_CONVERTS_TO_PAID = false;
export const TRIAL_AUTO_CHARGE_ENABLED = false;
export const PAID_MEMBERSHIP_REQUIRES_EXPLICIT_OPT_IN = true;
export const TRIAL_START_EVENT = 'successful_airline_activation';
export const TRIAL_EXPIRY_ACTION = 'await_explicit_membership_choice';

function timestamp(value, label) {
  const d = value instanceof Date ? value : new Date(value);
  if (!Number.isFinite(d.getTime())) throw new Error('Invalid '+label+' timestamp.');
  return d.getTime();
}

export function plannedTrialFromActivation(confirmedActivationAt) {
  // Only call after an idempotent, authorized airline-creation transaction.
  // The DATABASE is the authoritative source of time and trial eligibility.
  const started = timestamp(confirmedActivationAt, 'activation');
  const expires = started + TRIAL_DURATION_MS;
  if (!Number.isFinite(expires)) throw new Error('Trial timestamp exceeds range.');
  return Object.freeze({
    trial_started_at: new Date(started).toISOString(),
    trial_ends_at: new Date(expires).toISOString()
  });
}

export function previewEntitlement(entitlement, evaluatedAt) {
  // Informational state display only; server authorization must re-check.
  const now = timestamp(evaluatedAt, 'evaluation');
  if (!entitlement || entitlement.membership_state === 'none') {
    return Object.freeze({ state: 'not_started', trialEndsAt: null, millisecondsRemaining: 0 });
  }
  const state = entitlement.membership_state;
  if (state === 'active') {
    return Object.freeze({ state: 'paid', trialEndsAt: entitlement.trial_ends_at ?? null, millisecondsRemaining: 0 });
  }
  if (state === 'suspended' || state === 'past_due') {
    return Object.freeze({ state: state, trialEndsAt: entitlement.trial_ends_at ?? null, millisecondsRemaining: 0 });
  }
  if (!['trial','expired'].includes(state)) throw new Error('Unknown membership state.');
  if (!entitlement.trial_started_at || !entitlement.trial_ends_at) {
    throw new Error('Trial timestamps are missing.');
  }
  const start = timestamp(entitlement.trial_started_at, 'start');
  const end = timestamp(entitlement.trial_ends_at, 'end');
  if (end - start !== TRIAL_DURATION_MS) {
    throw new Error('Invalid seven-day trial duration.');
  }
  if (now < start) throw new Error('Trial cannot begin before activation.');
  const remaining = Math.max(0, end - now);
  return Object.freeze({
    state: state === 'expired' || remaining === 0 ? 'expired' : 'trial',
    trialEndsAt: new Date(end).toISOString(),
    millisecondsRemaining: state === 'expired' ? 0 : remaining
  });
}
