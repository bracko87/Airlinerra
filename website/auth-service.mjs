/**
 * Browser-agnostic Supabase Auth contract. Supply an official Supabase client
 * only after installing and pinning @supabase/supabase-js with a lockfile.
 * This module does not instantiate a client, store tokens, or enable public signup.
 */
import {
  PUBLIC_AUTH_ENABLED,
  normalizedEmail,
  validatedPassword,
  validatedDisplayName,
  authRedirect
} from './auth-rules.mjs';

const FORGOT_REPLY = 'If an account exists for this address, a recovery email will be sent.';

export function createAuthService({ supabase, origin, enabled = PUBLIC_AUTH_ENABLED }) {
  if (!supabase || !supabase.auth) throw new Error('Supabase Auth client required.');

  function requireEnabled() {
    if (!enabled || !PUBLIC_AUTH_ENABLED) {
      throw new Error('Airlinerra account registration and sign-in are not yet open.');
    }
  }

  return {
    async register({ email, password, displayName, termsAccepted }) {
      requireEnabled();
      if (termsAccepted !== true) throw new Error('Accept the current terms and privacy notice.');
      const cleanEmail = normalizedEmail(email);
      const cleanPassword = validatedPassword(password);
      const cleanName = validatedDisplayName(displayName);
      const { error } = await supabase.auth.signUp({
        email: cleanEmail,
        password: cleanPassword,
        options: {
          data: { display_name: cleanName },
          emailRedirectTo: authRedirect(origin, 'verify')
        }
      });
      if (error) throw error;
      // No airline/world or money created here. Entitlement is server-side.
      return { message: 'If registration succeeds, check your email for a confirmation link.' };
    },

    async signIn({ email, password }) {
      requireEnabled();
      const cleanEmail = normalizedEmail(email);
      if (!password || typeof password !== 'string') throw new Error('Enter your password.');
      const { data, error } = await supabase.auth.signInWithPassword({ email: cleanEmail, password });
      if (error) throw error;
      return data;
    },

    async requestPasswordReset(email) {
      requireEnabled();
      const cleanEmail = normalizedEmail(email);
      // Never allow a failed delivery or nonexistent account to expose account existence.
      try {
        await supabase.auth.resetPasswordForEmail(cleanEmail, {
          redirectTo: authRedirect(origin, 'reset')
        });
      } catch {
        // Admin-side monitoring is a separate protected implementation.
      }
      return { message: FORGOT_REPLY };
    },

    async completeCallback(code) {
      requireEnabled();
      if (typeof code !== 'string' || !/^[A-Za-z0-9._~-]{3,2048}$/.test(code)) {
        throw new Error('Invalid or expired confirmation link.');
      }
      const { data, error } = await supabase.auth.exchangeCodeForSession(code);
      if (error) throw error;
      return data;
    },

    async updatePassword(password) {
      requireEnabled();
      const cleanPassword = validatedPassword(password);
      const { error } = await supabase.auth.updateUser({ password: cleanPassword });
      if (error) throw error;
      return { message: 'Password updated.' };
    },

    async getUser() {
      requireEnabled();
      const { data, error } = await supabase.auth.getUser();
      if (error) throw error;
      return data?.user ?? null;
    },

    async signOut() {
      requireEnabled();
      const { error } = await supabase.auth.signOut({ scope: 'global' });
      if (error) throw error;
    }
  };
}
