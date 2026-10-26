/**
 * One-use password recovery intent. A generic PKCE code exchange proves a
 * session, not that the code was issued for recovery. Recovery is authorized
 * ONLY after a Supabase verifyOtp({type:'recovery'}) response and must still
 * be bound to the currently server-verified Auth user before updateUser.
 *
 * This gate is deliberately per-service instance, held only in memory.
 */
export function createRecoveryIntentGate() {
  let recoveredUserId = null;
  return Object.freeze({
    clear() { recoveredUserId = null; },
    async markAfterVerifiedOtp(auth, verifiedSession) {
      recoveredUserId = null;
      if (!verifiedSession?.user?.id) {
        throw new Error('Recovery session identity is missing.');
      }
      const { data, error } = await auth.getUser();
      if (error || typeof data?.user?.id !== 'string' ||
          data.user.id !== verifiedSession.user.id) {
        throw new Error('Recovery identity could not be verified.');
      }
      recoveredUserId = data.user.id;
    },
    async consumeForPasswordUpdate(auth) {
      if (!recoveredUserId) {
        throw new Error('A verified password recovery link is required.');
      }
      const claimedId = recoveredUserId;
      recoveredUserId = null; // single use even if later updateUser fails
      const { data, error } = await auth.getUser();
      if (error || data?.user?.id !== claimedId) {
        throw new Error('Recovery identity changed. Request a new link.');
      }
      return claimedId;
    }
  });
}
