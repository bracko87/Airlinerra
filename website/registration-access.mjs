/**
 * Fail-closed browser-side readiness for Airlinerra registration.
 * This only controls form visibility, NOT Supabase signup authorization.
 * The server-side Before User Created hook must restrict registration to
 * airlinerra_game.owner_premium_email_reservations before provider signup
 * can safely be enabled. Never grant access on the basis of this module.
 */
export function evaluateRegistrationAccess({provider,readiness,terms,privacy}={}) {
  if(provider?.signupEnabled!==true ||
     provider?.emailConfirmedRequired!==true ||
     provider?.anonymousDisabled!==true ||
     !readiness || typeof readiness!=='object') {
    return Object.freeze({mode:'closed'});
  }
  if(readiness.registrationReady===true &&
     terms==='approved' && privacy==='approved') {
    return Object.freeze({mode:'public'});
  }
  if(readiness.privateOwnerPilotAvailable===true &&
     terms==='draft' && privacy==='draft') {
    return Object.freeze({mode:'owner-pilot'});
  }
  return Object.freeze({mode:'closed'});
}
