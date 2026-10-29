/** Localhost-only Airlinerra bridge. Normal built-site preview uses the same
 * authenticated Supabase game API as production, but ONLY for allowed reads.
 * A direct PostgreSQL adapter requires an explicit developer opt-in and private
 * credentials in the server environment; never expose either to the browser.
 */
import {createCanonicalGameApi,CANONICAL_GAME_API_PATHS} from '../../server/canonical-game-api.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS} from '../invited-tester-public-settings.mjs';
export const REAL_PLAYER_PATHS=CANONICAL_GAME_API_PATHS;
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
// Opt-in localhost-only, read-only proxy to the existing authenticated
// Supabase Edge game service. No DB password, local fake catalog, or writes.
export function createLiveReadOnlyPreviewHandler({fetchImpl=globalThis.fetch}={}){
 const allowed=new Set([
  '/api/v1/player/overview',
  '/api/v1/player/airports',
  '/api/v1/player/airport-profile',
  '/api/v1/onboarding/context'
 ]);
 const error=(status,why)=>{
  console.warn('Airlinerra local read-only gateway:',status,why);
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
   return error(403,'Local preview is read-only');
  const token=request.headers.get('authorization')||'';
  if(!/^Bearer [A-Za-z0-9._~-]{16,8192}$/.test(token))
   return error(401,'Verified session required');
  if(request.headers.get('content-type')!=='application/json')
   return error(415,'JSON only');
  let body;
  try{body=await request.text();if(new TextEncoder().encode(body).length>2048)
   return error(413,'Request too large');}catch{return error(400,'Invalid body')}
  try{
   const edge=url.pathname==='/api/v1/player/airport-profile'?'airlinerra-airport-profile':'airlinerra-game';
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
  enabled:true,origin:ORIGIN,verifyUserToken,database,
  documentPaths:{terms:'/terms.html',privacy:'/privacy.html'}
 });
}
