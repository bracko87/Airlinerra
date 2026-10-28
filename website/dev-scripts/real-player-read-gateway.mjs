/** Production-equivalent authenticated read service, bound to localhost only.
 * Requires explicit private DB credentials in process environment (never in dist).
 */
import {createPlayerReadHandler} from '../../server/player-read-service.mjs';
import {createOnboardingContextService} from '../../server/onboarding-context-service.mjs';
import {createOnboardingContextHttpHandler} from '../../server/onboarding-context-http-handler.mjs';
import {createLegalConsentService} from '../../server/legal-consent-service.mjs';
import {createLegalConsentHttpHandler} from '../../server/legal-consent-http-handler.mjs';
import {createAirlineActivationService} from '../../server/airline-activation.mjs';
import {createAirlineHttpHandler} from '../../server/airline-http-handler.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS} from '../invited-tester-public-settings.mjs';
export const REAL_PLAYER_PATHS=Object.freeze([
 '/api/v1/player/overview','/api/v1/player/airports',
 '/api/v1/onboarding/context','/api/v1/legal/consents','/api/v1/airlines'
]);
const REF='hwllkabgzaynalahvkpz';
const ORIGIN='http://localhost:5188';
const AUTH_URL='https://'+REF+'.supabase.co';
export function validConnectionUrl(value){
 try{
  const u=new URL(value);
  if(!['postgres:','postgresql:'].includes(u.protocol)||!u.password||
     u.pathname!=='/postgres')return false;
  if(u.hostname==='db.'+REF+'.supabase.co')return u.username==='postgres';
  return u.hostname.endsWith('.pooler.supabase.com')&&
     u.username.endsWith('.'+REF);
 }catch{return false;}
}
export async function makeRealLocalPlayerHandler({
  env=process.env,loadPg=()=>import('pg'),
  fetchImpl=globalThis.fetch
}={}){
 const url=env.AIRLINERRA_LOCAL_DATABASE_URL;
 if(!validConnectionUrl(url))return async()=>new Response(JSON.stringify({
  error:'Authenticated game-data service needs private PostgreSQL configuration.'
 }),{status:503,headers:{'content-type':'application/json','cache-control':'no-store'}});
 const sdk=await loadPg();
 const Pool=sdk.Pool||sdk.default?.Pool;
 if(typeof Pool!=='function')throw Error('PostgreSQL driver unavailable');
 const database=new Pool({
  connectionString:url,ssl:{rejectUnauthorized:true},
  max:2,connectionTimeoutMillis:5000,idleTimeoutMillis:10000
 });
 const verifyUserToken=async token=>{
  const response=await fetchImpl(AUTH_URL+'/auth/v1/user',{
   method:'GET',headers:{
    apikey:AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS.publishableKey,
    authorization:'Bearer '+token,accept:'application/json'
   },cache:'no-store',redirect:'error',signal:AbortSignal.timeout(5000)
  });
  if(!response.ok)throw Error('Hosted identity not verified');
  const user=await response.json();
  return {user,error:null};
 };
 const readHandler=createPlayerReadHandler({
  enabled:true,verifyUserToken,database,origin:ORIGIN
 });
 const contextHandler=createOnboardingContextHttpHandler({
  contextService:createOnboardingContextService({
   enabled:true,verifyUserToken,database,
   documentPaths:{terms:'/terms.html',privacy:'/privacy.html'}
  }),allowedOrigins:[ORIGIN],enabled:true
 });
 const legalHandler=createLegalConsentHttpHandler({
  consentService:createLegalConsentService({
   enabled:true,verifyUserToken,database
  }),allowedOrigins:[ORIGIN],enabled:true
 });
 const airlineHandler=createAirlineHttpHandler({
  activationService:createAirlineActivationService({
   enabled:true,verifyUserToken,database
  }),allowedOrigins:[ORIGIN],enabled:true
 });
 return async function protectedGameHandler(request){
   const path=new URL(request.url).pathname;
   if(path.startsWith('/api/v1/player/'))return readHandler(request);
   if(!REAL_PLAYER_PATHS.includes(path))return new Response('Not found',{status:404});
   const body=await request.text();
   if(Buffer.byteLength(body,'utf8')>2048)
     return new Response(JSON.stringify({error:'Request too large'}),{status:413,headers:{'content-type':'application/json'}});
   const {pathname}=new URL(request.url);
   const handler=pathname==='/api/v1/onboarding/context'?contextHandler:
      pathname==='/api/v1/legal/consents'?legalHandler:airlineHandler;
   const answer=await handler({
      path:pathname,method:request.method,
      headers:Object.fromEntries(request.headers.entries()),body
   });
   return new Response(answer.body,{status:answer.status,headers:answer.headers});
 };

}
