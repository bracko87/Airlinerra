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
function closedResponse(){
  return new Response(
    JSON.stringify({error:'Airlinerra account service unavailable.'}),
    {status:503,headers:CLOSED_HEADERS}
  );
}

/**
 * The app instance is cached for a warm function container so a single
 * bounded PostgreSQL pool serves repeated invocations. A failed startup
 * never produces credentials in the response and can retry next request.
 */
export function createStagedNetlifyAccountHandler({
  getEnvironment=()=>process.env,
  buildApp=buildPrivatePreviewAccountApp
}={}){
  if(typeof getEnvironment!=='function'||typeof buildApp!=='function'){
    throw new Error('Explicit server-only hosting dependencies are required.');
  }
  let pending=null;
  return async function stagedAccountHandler(request){
    try{
      const env=getEnvironment();
      if(!env || env.AIRLINERRA_HOSTED_BACKEND_ENABLED!=='true' ||
         env.AIRLINERRA_PRIVATE_PREVIEW_APPROVED!=='true' ||
         !['deploy-preview','branch-deploy'].includes(env.CONTEXT)){
        // Recheck context even for a warm cached app; production is forbidden.
        return closedResponse();
      }
      if(!(request instanceof Request)) return closedResponse();

      if(!pending){
        pending=Promise.resolve().then(()=>buildApp({env}));
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
      return await app.handler(request);
    }catch{
      return closedResponse();
    }
  };
}

// DO NOT move this default export into a live functions directory without
// explicit Netlify preview access controls, rate limits and owner approval.
export default createStagedNetlifyAccountHandler();
