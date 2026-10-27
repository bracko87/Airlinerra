/**
 * STAGED Netlify Functions entrypoint: SOURCE TEMPLATE ONLY.
 *
 * IMPORTANT: This file deliberately lives OUTSIDE website/netlify/functions/
 * and every configured Netlify functions directory. Nothing under server/
 * is published by the current static build. Moving/copying this file into
 * Netlify's active directory is a separate, owner-approved deployment step.
 *
 * Netlify's Web Request/Response and export config conventions:
 * https://docs.netlify.com/build/functions/configuration/
 */
import {buildPrivatePreviewAccountApp} from '../preview-account-app.mjs';
import {createPreviewRequestGate} from '../preview-access-guard.mjs';

export const config = Object.freeze({
  path:[
    '/api/v1/onboarding/context',
    '/api/v1/legal/consents',
    '/api/v1/airlines'
  ],
  method:'POST',
  // Netlify's provider-side code-based rate limiting is available on Free.
  // Unlike the per-warm-instance guard, this rejects excess traffic at
  // Netlify before starting the Function or contacting the database.
  rateLimit:Object.freeze({
    action:'rate_limit',
    aggregateBy:'ip',
    windowSize:60,
    windowLimit:30
  })
});

const CLOSED_HEADERS = Object.freeze({
  'content-type':'application/json; charset=utf-8',
  'cache-control':'no-store',
  'content-security-policy':"default-src 'none'",
  'x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer',
  'x-frame-options':'DENY'
});
function closedResponse(status=503){
  return new Response(
    JSON.stringify({error:'Airlinerra account service unavailable.'}),
    {status,headers:CLOSED_HEADERS}
  );
}

/**
 * The app instance is cached for a warm function container so a single
 * bounded PostgreSQL pool serves repeated invocations. A failed startup
 * never produces credentials in the response and can retry next request.
 */
export function createStagedNetlifyAccountHandler({
  getEnvironment=()=>process.env,
  buildApp=buildPrivatePreviewAccountApp,
  previewGate=createPreviewRequestGate()
}={}){
  if(typeof getEnvironment!=='function'||typeof buildApp!=='function'||
     typeof previewGate?.acquire!=='function'){
    throw new Error('Explicit server-only hosting dependencies are required.');
  }
  let pending=null;
  let activeMode=null;
  return async function stagedAccountHandler(request,netlifyContext){
    try{
      // Netlify's build-time CONTEXT is NOT a read-only Functions runtime
      // variable. Deployment identity must come from the platform-provided
      // (request, context) Function API, never a manually set env.CONTEXT.
      // Netlify production deployment is permitted ONLY for an explicit
      // operator-controlled *prelaunch test*, not for public account launch.
      // Deployment type, published status and site are platform-owned.
      const deploy=netlifyContext?.deploy;
      const verifiedContext=deploy?.context;
      const canonical=verifiedContext==='production' && deploy.published===true;
      const privatePreview=['deploy-preview','branch-deploy'].includes(verifiedContext) &&
        deploy.published===false;
      if((!canonical && !privatePreview) ||
         netlifyContext?.site?.name!=='airlinerra' ||
         netlifyContext?.site?.url!=='https://airlinerra.com'){
        return closedResponse();
      }
      const env=getEnvironment();
      if(!env || env.AIRLINERRA_HOSTED_BACKEND_ENABLED!=='true'){
        return closedResponse();
      }
      const verifiedMode=canonical?'canonical-prelaunch-test':'private-preview';
      if(canonical
        ? env.AIRLINERRA_HOSTED_RUNTIME_MODE!=='canonical-prelaunch-test' ||
          env.AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED!=='true'
        : (env.AIRLINERRA_HOSTED_RUNTIME_MODE!==undefined &&
           env.AIRLINERRA_HOSTED_RUNTIME_MODE!=='private-preview') ||
          env.AIRLINERRA_PRIVATE_PREVIEW_APPROVED!=='true'){
        return closedResponse();
      }
      if(!(request instanceof Request)) return closedResponse();
      // Read ONLY the mode-specific operator gate fields first. Do not
      // spread env (or read DB credentials) before the operator is admitted.
      const accessEnv=canonical ? {
        CONTEXT:verifiedContext,
        AIRLINERRA_HOSTED_RUNTIME_MODE:verifiedMode,
        AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED:
          env.AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED,
        AIRLINERRA_CANONICAL_TEST_ORIGIN:env.AIRLINERRA_CANONICAL_TEST_ORIGIN,
        AIRLINERRA_CANONICAL_TEST_ACCESS_SECRET:env.AIRLINERRA_CANONICAL_TEST_ACCESS_SECRET
      } : {
        CONTEXT:verifiedContext,
        AIRLINERRA_HOSTED_RUNTIME_MODE:verifiedMode,
        AIRLINERRA_PREVIEW_ORIGIN:env.AIRLINERRA_PREVIEW_ORIGIN,
        AIRLINERRA_PREVIEW_ACCESS_SECRET:env.AIRLINERRA_PREVIEW_ACCESS_SECRET
      };
      // Origin, exact path, access secret and request budget are checked
      // BEFORE touching database credentials, loading pg or checking Auth.
      const admission=previewGate.acquire(accessEnv,request);
      if(!admission.allowed)return closedResponse(admission.status);
      try{
        // Only an admitted request may read the remaining runtime secrets.
        // The platform-owned deploy CONTEXT overrides mutable build metadata.
        const verifiedEnv={...env,CONTEXT:verifiedContext,
          AIRLINERRA_HOSTED_RUNTIME_MODE:verifiedMode};
        // A warm test instance must never reuse a backend configured for a
        // different mode. Normally mode is immutable for a Netlify deploy.
        if(activeMode!==verifiedMode){
          pending=null;
          activeMode=verifiedMode;
        }
        if(!pending){
          pending=Promise.resolve().then(()=>buildApp({env:verifiedEnv}));
        }
        let app;
        try{app=await pending;}
        catch {
          pending=null; // Recover only on a future request; never return raw errors.
          return closedResponse();
        }
        if(!app?.enabled || typeof app.handler!=='function'){
          return closedResponse();
        }
        return await app.handler(admission.request);
      }finally{
        admission.release();
      }
    }catch{
      return closedResponse();
    }
  };
}

// DO NOT move this default export into a live functions directory without
// explicit Netlify preview access controls, rate limits and owner approval.
export default createStagedNetlifyAccountHandler();
