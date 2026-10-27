/**
 * Airlinerra account lifecycle. This module never instantiates a Supabase client.
 * Caller MUST use the independent server-side Auth signup disable / release gate.
 * A test may inject enabled:true; the public runtime always uses the false
 * PUBLIC_AUTH_ENABLED switch until an explicitly authorized launch.
 */
import {
  PUBLIC_AUTH_ENABLED, normalizedEmail, validatedPassword,
  validatedDisplayName, authRedirect
} from './auth-rules.mjs';
import { createRecoveryIntentGate } from './recovery-intent.mjs';

export const FORGOT_REPLY = 'If an account exists for this address, a recovery email will be sent.';
export const REGISTER_REPLY = 'If registration succeeds, check your email for a confirmation link.';

export function parseAuthCallback(rawSearch, screen) {
  const params = new URLSearchParams(rawSearch || '');
  const code = params.get('code');
  const hash = params.get('token_hash');
  const type = params.get('type');
  // Never accept both forms or token-bearing redirects to arbitrary screens.
  if ((code && hash) || (code && type) || (hash && !type) || (type && !hash)) {
    throw new Error('Invalid account confirmation link.');
  }
  if (screen !== 'verify' && screen !== 'reset') return null;
  if (code) {
    if (!/^[A-Za-z0-9._~-]{3,2048}$/.test(code)) throw new Error('Invalid account confirmation link.');
    // PKCE code exchange alone does not reveal whether this was a recovery
    // link. A spoofed reset screen must NEVER authorize updateUser().
    // Until a recovery-specific PKCE proof is integrated, only OTP links
    // verified with type=recovery may enable the reset screen.
    if (screen === 'reset') throw new Error('Recovery-specific verification is required.');
    return { kind: 'pkce', code, purpose: screen };
  }
  if (hash) {
    if (!/^[A-Za-z0-9_-]{10,4096}$/.test(hash)) throw new Error('Invalid account confirmation link.');
    // Signup confirmation generally uses type=email; recovery uses type=recovery.
    if (screen === 'reset' && type !== 'recovery') throw new Error('Unexpected recovery link type.');
    if (screen === 'verify' && !['email', 'signup', 'invite'].includes(type)) throw new Error('Unexpected verification link type.');
    return { kind: 'otp', token_hash: hash, type, purpose: screen };
  }
  return null;
}

export function createAuthService({ supabase, origin, enabled = PUBLIC_AUTH_ENABLED }) {
  if (!supabase || !supabase.auth) throw new Error('Supabase Auth client required.');
  const recoveryIntent = createRecoveryIntentGate();
  const requireEnabled = () => {
    if (!enabled) throw new Error('Airlinerra account registration and sign-in are not yet open.');
  };

  return {
    async register({ email, password, displayName, termsAccepted }) {
      requireEnabled();
      recoveryIntent.clear();
      if (termsAccepted !== true) throw new Error('Accept the current terms and privacy notice.');
      const { error } = await supabase.auth.signUp({
        email: normalizedEmail(email),
        password: validatedPassword(password),
        options: {
          data: { display_name: validatedDisplayName(displayName) },
          emailRedirectTo: authRedirect(origin, 'verify')
        }
      });
      if (error) throw error;
      // Server must check terms version and create a profile separately;
      // NEVER create an airline, trial, funds, or world on sign-up.
      return { message: REGISTER_REPLY };
    },

    async signIn({ email, password }) {
      requireEnabled();
      recoveryIntent.clear();
      if (typeof password !== 'string' || !password) throw new Error('Enter your password.');
      const { data, error } = await supabase.auth.signInWithPassword({
        email: normalizedEmail(email), password
      });
      if (error) throw error;
      return data;
    },

    async requestPasswordReset(email) {
      requireEnabled();
      recoveryIntent.clear();
      const cleanEmail = normalizedEmail(email);
      try {
        // Intentionally return identical messaging for unknown user, rate limit
        // and delivery failures. Operational telemetry is a separate backend task.
        await supabase.auth.resetPasswordForEmail(cleanEmail, {
          redirectTo: authRedirect(origin, 'reset')
        });
      } catch {
        // Deliberately no identifying information in response.
      }
      return { message: FORGOT_REPLY };
    },

    async completeCallback(callback) {
      requireEnabled();
      recoveryIntent.clear();
      if (!callback || !['verify', 'reset'].includes(callback.purpose)) {
        throw new Error('Invalid account confirmation link.');
      }
      let result;
      if (callback.kind === 'pkce') {
        if (callback.purpose === 'reset') {
          throw new Error('Recovery-specific verification is required.');
        }
        if (typeof callback.code !== 'string' || !/^[A-Za-z0-9._~-]{3,2048}$/.test(callback.code)) {
          throw new Error('Invalid account confirmation link.');
        }
        result = await supabase.auth.exchangeCodeForSession(callback.code);
      } else if (callback.kind === 'otp') {
        // Only expected confirmation types; forbid arbitrary/invite/magiclink.
        if (callback.purpose === 'reset' && callback.type !== 'recovery') throw new Error('Invalid recovery link.');
        if (callback.purpose === 'verify' && !['email','signup','invite'].includes(callback.type)) {
          throw new Error('Invalid verification link.');
        }
        if (!/^[A-Za-z0-9_-]{10,4096}$/.test(callback.token_hash)) throw new Error('Invalid account confirmation link.');
        result = await supabase.auth.verifyOtp({ token_hash: callback.token_hash, type: callback.type });
      } else {
        throw new Error('Invalid account confirmation link.');
      }
      if (result.error) throw result.error;
      if (!result.data?.session) throw new Error('Session verification could not be completed.');
      if (callback.purpose === 'reset' ||
          (callback.kind === 'otp' && callback.type === 'invite' &&
           callback.purpose === 'verify')) {
        // Password setup follows ONLY a confirmed recovery or invitation
        // OTP. A generic signup confirmation/PKCE session must not grant it.
        // The one-use intent is bound to the freshly verified Auth user.
        await recoveryIntent.markAfterVerifiedOtp(supabase.auth, result.data.session);
      }
      return {
        purpose:callback.kind === 'otp' && callback.type === 'invite'
          ? 'invite' : callback.purpose,
        sessionEstablished:true
      };
    },

    async updatePassword(password) {
      requireEnabled();
      const cleanPassword = validatedPassword(password);
      await recoveryIntent.consumeForPasswordUpdate(supabase.auth);
      const { error } = await supabase.auth.updateUser({ password: cleanPassword });
      if (error) throw error;
      // Sign out all sessions after the credential change. JWTs remain
      // valid until expiry; server-side sensitive actions must verify session.
      const outcome = await supabase.auth.signOut({ scope: 'global' });
      if (outcome.error) throw outcome.error;
      return { message: 'Password updated. Please sign in again.' };
    },

    async getUser() {
      requireEnabled();
      const { data, error } = await supabase.auth.getUser();
      if (error) throw error;
      return data?.user ?? null;
    },

    async signOut() {
      requireEnabled();
      recoveryIntent.clear();
      const { error } = await supabase.auth.signOut({ scope: 'local' });
      if (error) throw error;
    }
  };
}
