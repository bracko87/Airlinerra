/**
 * Hosted *composition only*: inject a trusted Auth verifier and PostgreSQL
 * pool from an approved, secret-bearing server runtime. This module does not
 * create connections, read env vars, register Netlify routes or deploy code.
 * Public registration remains closed by default.
 */
import {createAirlineActivationService} from './airline-activation.mjs';
import {createAirlineHttpHandler} from './airline-http-handler.mjs';
import {createLegalConsentService} from './legal-consent-service.mjs';
import {createLegalConsentHttpHandler} from './legal-consent-http-handler.mjs';
import {createOnboardingContextService} from './onboarding-context-service.mjs';
import {createOnboardingContextHttpHandler} from './onboarding-context-http-handler.mjs';
import {createHostedAccountRouter} from './hosted-account-router.mjs';

export function createHostedAccountStack({
  enabled=false, publicOrigin=null, verifyUserToken,
  database, termsPath, privacyPath
}={}) {
  // Closed deployments must never construct services or touch a database.
  if(!enabled)return createHostedAccountRouter();
  if(typeof verifyUserToken!=='function' || typeof database?.connect!=='function') {
    throw new Error('Trusted hosted Auth and server-only PostgreSQL required.');
  }
  const documents={
    terms:termsPath,
    privacy:privacyPath
  };
  const airlineService=createAirlineActivationService({
    verifyUserToken,database,enabled:true
  });
  const legalService=createLegalConsentService({
    verifyUserToken,database,enabled:true
  });
  const contextService=createOnboardingContextService({
    verifyUserToken,database,documentPaths:documents,enabled:true
  });
  const handlers=Object.freeze({
    '/api/v1/airlines':createAirlineHttpHandler({
      activationService:airlineService,allowedOrigins:[publicOrigin],enabled:true
    }),
    '/api/v1/legal/consents':createLegalConsentHttpHandler({
      consentService:legalService,allowedOrigins:[publicOrigin],enabled:true
    }),
    '/api/v1/onboarding/context':createOnboardingContextHttpHandler({
      contextService,allowedOrigins:[publicOrigin],enabled:true
    })
  });
  return createHostedAccountRouter({
    enabled:true,publicOrigin,handlers
  });
}
