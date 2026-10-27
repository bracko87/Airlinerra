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
  method:'POST'
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
  return async function stagedAccountHandler(request,netlifyContext){
    try{
      // Netlify's build-time CONTEXT is NOT a read-only Functions runtime
      // variable. Deployment identity must come from the platform-provided
      // (request, context) Function API, never a manually set env.CONTEXT.
      // Reject published/production deployments BEFORE reading any secrets.
      const deploy=netlifyContext?.deploy;
      const verifiedContext=deploy?.context;
      if(!['deploy-preview','branch-deploy'].includes(verifiedContext) ||
         deploy.published!==false ||
         netlifyContext?.site?.name!=='airlinerra' ||
         netlifyContext?.site?.url!=='https://airlinerra.com'){
        return closedResponse();
      }
      const env=getEnvironment();
      if(!env || env.AIRLINERRA_HOSTED_BACKEND_ENABLED!=='true' ||
         env.AIRLINERRA_PRIVATE_PREVIEW_APPROVED!=='true'){
        return closedResponse();
      }
      if(!(request instanceof Request)) return closedResponse();
      // Set the trusted deploy context for the downstream existing guards.
      // Explicitly override any forged or stale CONTEXT environment value.
      const verifiedEnv={...env,CONTEXT:verifiedContext};
      // Origin, exact path, access secret and warm-instance budget are
      // checked BEFORE loading the DB driver or contacting Supabase Auth.
      const admission=previewGate.acquire(verifiedEnv,request);
      if(!admission.allowed)return closedResponse(admission.status);
      try{
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
