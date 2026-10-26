/**
 * Local-only prelaunch assembly of the actual account HTTP handlers and
 * private service adapters. All release switches remain false unless a
 * trusted test explicitly opts in. Never used to mount a production API.
 *
 * Inject fake/throwaway PostgreSQL and Auth verification in tests only.
 * No Supabase secrets, real registrations or airport approvals live here.
 */
import { startLocalAccountGateway } from './local-account-gateway.mjs';
import { createAirlineActivationService } from './airline-activation.mjs';
import { createAirlineHttpHandler } from './airline-http-handler.mjs';
import { createLegalConsentService } from './legal-consent-service.mjs';
import { createLegalConsentHttpHandler } from './legal-consent-http-handler.mjs';

export async function startLocalAccountStack({
  verifyUserToken,
  database,
  enabled = false,
  port = 0
} = {}) {
  if (typeof verifyUserToken !== 'function' ||
      !database || typeof database.connect !== 'function') {
    throw new Error('Trusted test Auth verifier and database pool are required.');
  }
  const airlineService = createAirlineActivationService({
    verifyUserToken, database, enabled
  });
  const legalService = createLegalConsentService({
    verifyUserToken, database, enabled
  });
  return startLocalAccountGateway({
    enabled,
    port,
    createHandlers: origin => Object.freeze({
      airlineHandler: createAirlineHttpHandler({
        activationService: airlineService, allowedOrigins: [origin], enabled
      }),
      legalHandler: createLegalConsentHttpHandler({
        consentService: legalService, allowedOrigins: [origin], enabled
      })
    })
  });
}
