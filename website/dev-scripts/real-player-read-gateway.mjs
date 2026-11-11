/** Localhost-only Airlinerra bridge. Normal built-site preview uses the same
 * authenticated Supabase game API as production, but ONLY for allowed reads and limited owner-checked edits.
 * A direct PostgreSQL adapter requires an explicit developer opt-in and private
 * credentials in the server environment; never expose either to the browser.
 */
import {createCanonicalGameApi,CANONICAL_GAME_API_PATHS} from '../../server/canonical-game-api.mjs';
import {validateFlightSchedulePayload} from '../../server/flight-schedule-service.mjs';
import {validateFleetAcquisitionRequest} from '../../server/fleet-acquisition-service.mjs';
import {parseOfficeRequest,AIRPORT_OFFICE_API_PATH} from '../../server/airport-office-http-handler.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS} from '../invited-tester-public-settings.mjs';
export const REAL_PLAYER_PATHS=CANONICAL_GAME_API_PATHS;
const REF='hwllkabgzaynalahvkpz';
const ORIGIN='http://localhost:5188';
const AUTH_URL='https://'+REF+'.supabase.co';
const AIRLINE_ID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FLEET_READ_PATH='/api/v1/player/fleet-acquisition';
const SCHEDULE_READ_PATH='/api/v1/player/flight-schedule-drafts';
const GROUP2_LOCATION_PATH='/api/v1/player/group2-location-plans';
// The HTTP server must route these dedicated read-only proxy endpoints before
// it tries the static dist/ directory. Canonical game API paths alone do not
// contain the two dedicated Edge APIs.
export const LOCAL_PLAYER_API_PATHS=Object.freeze([
 ...CANONICAL_GAME_API_PATHS,FLEET_READ_PATH,SCHEDULE_READ_PATH
]);
/** The local gateway never forwards payment, schedule reservation,
 * delivery update, payments or operational state-changing command.
 */
export function allowedLocalOwnerRead(pathname,payload){
 if(pathname!==FLEET_READ_PATH&&pathname!==SCHEDULE_READ_PATH)return false;
 if(!payload||typeof payload!=='object'||Array.isArray(payload)||
    typeof payload.action!=='string'||!AIRLINE_ID.test(payload.airlineId||''))return false;
 if(payload.action==='list')
  return Object.keys(payload).length===2 &&
   Object.keys(payload).every(x=>x==='action'||x==='airlineId');
 // New and used marketplace discovery is read-only.
 if(pathname===FLEET_READ_PATH&&payload.action==='list-used')
  return validateFleetAcquisitionRequest(payload);
 // Cabin layouts are owner-only reads, saved planning drafts or non-binding
 // refit quotes; none can install seats, book maintenance or debit funds.
 if(pathname===FLEET_READ_PATH&&['cabin-overview','cabin-save-draft','cabin-save-model-design',
  'cabin-prepare-quote','cabin-quote-status'].includes(payload.action))
  return validateFleetAcquisitionRequest(payload);
 // Maintenance preview is read-only. Never accept a client-selected cost or site.
 if(pathname===FLEET_READ_PATH&&payload.action==='maintenance-preview')
  return validateFleetAcquisitionRequest(payload);
 // Nickname edits are harmless owner-verified metadata updates; never allow
 // purchase, delivery, schedule activation or any other fleet write here.
 if(pathname===FLEET_READ_PATH&&payload.action==='update-nickname')
  return validateFleetAcquisitionRequest(payload);
 // Explicitly allow ONLY an authenticated, owner-checked, pre-operational
 // planning-draft save. The deployed Edge function revalidates everything.
 // Slot reservations, normal schedule writes and commercial operations
 // remain forbidden through localhost.
 if(pathname===SCHEDULE_READ_PATH&&payload.action==='plan-save')
  return validateFlightSchedulePayload(payload);
 if(pathname===SCHEDULE_READ_PATH&&payload.action==='slot-check'){
  // Server input is validated again. The only non-list action allowed here
  // uses a STABLE, read-only database preflight function.
  const names=['action','airlineId','aircraftInventoryId','originAirportKey',
   'destinationAirportKey','referenceDepartureUtc','referenceArrivalUtc',
   'weeklySchedule','departureStand','arrivalStand','existingId'];
  return Object.keys(payload).every(k=>names.includes(k)) &&
   AIRLINE_ID.test(payload.aircraftInventoryId||'') &&
   Array.isArray(payload.weeklySchedule) && payload.weeklySchedule.length<=7 &&
   typeof payload.originAirportKey==='string' &&
   typeof payload.destinationAirportKey==='string' &&
   typeof payload.referenceDepartureUtc==='string' &&
   typeof payload.referenceArrivalUtc==='string';
 }
 return false;
}
/** Validate private, owner-resolved Group 2 planned location requests, never active offices. */
export function validGroup2LocationPlanRequest(payload){
 if(!payload||typeof payload!=='object'||Array.isArray(payload)||
    payload.worldId!==1||!['list','save','remove'].includes(payload.action))
  return false;
 const keys=Object.keys(payload);
 if(payload.action==='list')return keys.length===2 &&
  keys.every(k=>k==='action'||k==='worldId');
 const airport=typeof payload.airportKey==='string'&&
  /^OURAIRPORTS:[1-9][0-9]{0,18}$/.test(payload.airportKey);
 if(!airport)return false;
 if(payload.action==='remove')return keys.length===3 &&
  keys.every(k=>['action','worldId','airportKey'].includes(k));
 return keys.length===4 && keys.every(k=>['action','worldId','airportKey','type'].includes(k))&&
  ['future_hq','hub','station'].includes(payload.type);
}
export function validLocalAirportOfficeRequest(payload){
 try{
  if(!payload||typeof payload!=='object'||Array.isArray(payload))return false;
  const value=parseOfficeRequest(JSON.stringify(payload));
  return value.worldId===1&&Object.keys(value).length===Object.keys(payload).length;
 }catch{return false;}
}
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
// Opt-in localhost-only proxy to authenticated Edge readers and planning drafts.
// No DB password, fake catalog, payment or operational activation.
export function createLiveReadOnlyPreviewHandler({fetchImpl=globalThis.fetch}={}){
 const allowed=new Set([
  '/api/v1/player/overview',
  '/api/v1/player/airports',
  '/api/v1/player/prepared-airports',
  GROUP2_LOCATION_PATH,
  AIRPORT_OFFICE_API_PATH,
  '/api/v1/player/airport-profile',
  '/api/v1/player/aircraft-library',
  '/api/v1/player/noise-curfew-check',
  '/api/v1/player/licenses',
  '/api/v1/player/holding-status',
  FLEET_READ_PATH,
  SCHEDULE_READ_PATH,
  '/api/v1/onboarding/context'
 ]);
 const error=(status,why)=>{
  console.warn('Airlinerra local protected gateway:',status,why);
  return new Response(JSON.stringify({error:why}),{
   status,headers:{'content-type':'application/json','cache-control':'no-store'}
  });
 };
 return async request=>{
  if(!(request instanceof Request))return error(400,'Invalid request');
  const url=new URL(request.url);
  if(url.origin!==ORIGIN||request.headers.get('origin')!==ORIGIN)
   return error(403,'Local browser required');
  if(!allowed.has(url.pathname)||url.search||request.method!=='POST')
   return error(403,'Local preview operation not allowed');
  const token=request.headers.get('authorization')||'';
  if(!/^Bearer [A-Za-z0-9._~-]{16,8192}$/.test(token))
   return error(401,'Verified session required');
  if(request.headers.get('content-type')!=='application/json')
   return error(415,'JSON only');
  let body;
  try{
   body=await request.text();
   if(new TextEncoder().encode(body).length>2048)return error(413,'Request too large');
  }catch{return error(400,'Invalid body')}
  if(url.pathname===FLEET_READ_PATH||url.pathname===SCHEDULE_READ_PATH||url.pathname===GROUP2_LOCATION_PATH||url.pathname===AIRPORT_OFFICE_API_PATH){
   let payload;
   try{payload=JSON.parse(body);}catch{return error(400,'Invalid JSON body')}
   if(!(url.pathname===GROUP2_LOCATION_PATH?validGroup2LocationPlanRequest(payload):
     url.pathname===AIRPORT_OFFICE_API_PATH?validLocalAirportOfficeRequest(payload):
     allowedLocalOwnerRead(url.pathname,payload)))
    return error(403,'Local preview only allows verified reads and pre-operational planning drafts');
   body=JSON.stringify(payload);
  }
  try{
   const edge=url.pathname==='/api/v1/player/airport-profile'?'airlinerra-airport-profile':
     url.pathname==='/api/v1/player/aircraft-library'?'airlinerra-aircraft-library':
     url.pathname==='/api/v1/player/noise-curfew-check'?'airlinerra-noise-curfew-check':
     url.pathname===FLEET_READ_PATH?'airlinerra-fleet-acquisition':
     url.pathname===SCHEDULE_READ_PATH?'airlinerra-flight-schedule-drafts':'airlinerra-game';
   const response=await fetchImpl(AUTH_URL+'/functions/v1/'+edge,{
    method:'POST',headers:{
     apikey:AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS.publishableKey,
     authorization:token,'x-airlinerra-route':url.pathname,
     origin:'https://airlinerra.com','content-type':'application/json'
    },body,redirect:'error',cache:'no-store',signal:AbortSignal.timeout(20000)
   });
   if(!response.ok)console.warn('Airlinerra shared game API:',url.pathname,'HTTP',response.status);
   const type=response.headers.get('content-type')||'';
   if(!type.includes('application/json'))return error(503,'Invalid game response');
   const bytes=await response.arrayBuffer();
   if(bytes.byteLength>2000000)return error(503,'Game response too large');
   return new Response(bytes,{status:response.status,headers:{
    'content-type':'application/json','cache-control':'no-store'
   }});
  }catch{return error(503,'Unable to load real airport data')}
 };
}
export async function makeRealLocalPlayerHandler({
  env=process.env,loadPg=()=>import('pg'),
  fetchImpl=globalThis.fetch
}={}){
 // Read-only Edge proxy is the default, including ordinary npm run preview.
 // Database mode is opt-in and never selected merely because credentials exist.
 if(env.AIRLINERRA_LOCAL_USE_DATABASE!=='1')
  return createLiveReadOnlyPreviewHandler({fetchImpl});
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
 return createCanonicalGameApi({
  enabled:true,airportOfficeDraftsEnabled:true,origin:ORIGIN,verifyUserToken,database,
  documentPaths:{terms:'/terms.html',privacy:'/privacy.html'}
 });
}
