/** Netlify's same-origin, secret-free bridge to the already deployed Supabase
 * game API. Supabase Edge Function owns private database connectivity.
 * No database credentials or paid Netlify environment variables are necessary.
 */
import {CANONICAL_GAME_API_PATHS} from './canonical-game-api.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';

export const PRODUCTION_ORIGIN='https://airlinerra.com';
export const EDGE_FUNCTION_URL='https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-game';
const TOKEN=/^Bearer [A-Za-z0-9._~-]{16,8192}$/u;
const HEADERS={'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
function fail(status,error){return new Response(JSON.stringify({error}),{status,headers:HEADERS});}
export function createProductionGameApi({origin=PRODUCTION_ORIGIN,fetchImpl=globalThis.fetch,airportOfficeDraftsEnabled=false}={}){
 if(origin!==PRODUCTION_ORIGIN||typeof fetchImpl!=='function')
  throw Error('Pinned Airlinerra production API required');
 return async function realGameApi(request){
  if(!(request instanceof Request))return fail(400,'Invalid request');
  const url=new URL(request.url);
  if(url.origin!==PRODUCTION_ORIGIN||url.search||url.hash)return fail(403,'Forbidden');
  if(!CANONICAL_GAME_API_PATHS.includes(url.pathname))return fail(404,'Not found');
  const isOfficeDraft=url.pathname==='/api/v1/player/airport-offices';
  // Independent release gate: an unprepared production Edge deployment must never
  // receive office writes merely because Netlify registers the URL.
  if(isOfficeDraft&&airportOfficeDraftsEnabled!==true)return fail(503,'Airport office drafts are not enabled');
  const isReadiness=url.pathname==='/api/v1/registration/readiness';
  if(request.method!==(isReadiness?'GET':'POST'))return fail(405,'Method not allowed');
  const userBearer=request.headers.get('authorization')||'';
  if(!isReadiness&&!TOKEN.test(userBearer))return fail(401,'Verified session required');
  if(!isReadiness&&request.headers.get('origin')!==null&&
     request.headers.get('origin')!==PRODUCTION_ORIGIN)return fail(403,'Invalid origin');
  let body;
  if(!isReadiness){
   try{
    body=await request.text();
    if(new TextEncoder().encode(body).byteLength>(isOfficeDraft?512:2048))return fail(413,'Request too large');
   }catch{return fail(400,'Invalid request body')}
  }
  try{
   const headers={
    apikey:settings.publishableKey,
    'x-airlinerra-route':url.pathname,
    origin:PRODUCTION_ORIGIN,
    'content-type':'application/json',
    authorization:isReadiness?'Bearer '+settings.publishableKey:userBearer
   };
   const upstream=await fetchImpl(EDGE_FUNCTION_URL,{
    method:request.method,headers,body,cache:'no-store',redirect:'error',
    signal:AbortSignal.timeout(20000)
   });
   const contentType=upstream.headers.get('content-type')||'';
   if(!contentType.includes('application/json'))return fail(503,'Game API returned an invalid response');
   const bytes=await upstream.arrayBuffer();
   if(bytes.byteLength>2_000_000)return fail(503,'Game API response limit reached');
   return new Response(bytes,{status:upstream.status,headers:HEADERS});
  }catch{
   return fail(503,'Secure game API is temporarily unavailable');
  }
 };
}
