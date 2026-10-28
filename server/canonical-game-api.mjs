/** Shared REAL game account API, used by localhost and the future hosted adapter.
 * This module registers no public listener, Netlify function or Supabase Edge Function.
 * API authorization is always fresh hosted Auth + private PostgreSQL.
 */
import {createPlayerReadHandler} from './player-read-service.mjs';
import {createOnboardingContextService} from './onboarding-context-service.mjs';
import {createOnboardingContextHttpHandler} from './onboarding-context-http-handler.mjs';
import {createLegalConsentService} from './legal-consent-service.mjs';
import {createLegalConsentHttpHandler} from './legal-consent-http-handler.mjs';
import {createAirlineActivationService} from './airline-activation.mjs';
import {createAirlineHttpHandler} from './airline-http-handler.mjs';
import {createRegistrationReadinessHandler,REGISTRATION_READINESS_PATH} from './registration-readiness.mjs';

export const CANONICAL_GAME_API_PATHS=Object.freeze([
 '/api/v1/player/overview','/api/v1/player/airports',
 '/api/v1/onboarding/context','/api/v1/legal/consents','/api/v1/airlines',
 REGISTRATION_READINESS_PATH
]);
const ORIGINS=new Set(['http://localhost:5188','https://airlinerra.com']);
function respond(status,error){return new Response(JSON.stringify({error}),{
 status,headers:{'content-type':'application/json; charset=utf-8',
 'cache-control':'no-store','x-content-type-options':'nosniff'}
});}

export function createCanonicalGameApi({
 enabled=false,origin,verifyUserToken,database,
 documentPaths={terms:'/terms.html',privacy:'/privacy.html'}
}={}){
 if(!enabled)return async()=>respond(503,'Game account API is not enabled');
 if(!ORIGINS.has(origin)||typeof verifyUserToken!=='function'||
   typeof database?.connect!=='function')throw Error('Trusted game API config required');
 const read=createPlayerReadHandler({
  enabled:true,verifyUserToken,database,origin
 });
 const readiness=createRegistrationReadinessHandler({database,origin});
 const context=createOnboardingContextHttpHandler({
  contextService:createOnboardingContextService({
   enabled:true,verifyUserToken,database,documentPaths
  }),allowedOrigins:[origin],enabled:true
 });
 const legal=createLegalConsentHttpHandler({
  consentService:createLegalConsentService({enabled:true,verifyUserToken,database}),
  allowedOrigins:[origin],enabled:true
 });
 const createAirline=createAirlineHttpHandler({
  activationService:createAirlineActivationService({
   enabled:true,verifyUserToken,database
  }),allowedOrigins:[origin],enabled:true
 });
 const handlers={
  '/api/v1/onboarding/context':context,
  '/api/v1/legal/consents':legal,
  '/api/v1/airlines':createAirline
 };
 return async function gameApi(request){
  if(!(request instanceof Request))return respond(400,'Invalid request');
  const url=new URL(request.url);
  if(url.origin!==origin||url.search||url.hash)return respond(403,'Forbidden');
  if(!CANONICAL_GAME_API_PATHS.includes(url.pathname))return respond(404,'Not found');
  if(url.pathname===REGISTRATION_READINESS_PATH)return readiness(request);
  if(url.pathname.startsWith('/api/v1/player/'))return read(request);
  if(request.method!=='POST')return respond(405,'Method not allowed');
  const body=await request.text();
  if(Buffer.byteLength(body,'utf8')>2048)return respond(413,'Request body too large');
  try{
   const result=await handlers[url.pathname]({
    path:url.pathname,method:request.method,
    headers:Object.fromEntries(request.headers.entries()),body
   });
   return new Response(result.body,{status:result.status,headers:result.headers});
  }catch{return respond(503,'Game account API temporarily unavailable');}
 };
}
