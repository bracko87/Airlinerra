/** Active Netlify server-side adapter for the canonical Airlinerra game account API.
 * Never deployed except through the owner's existing manual Netlify release.
 * Private DB URL is read only at invocation, never published to browsers.
 */
import {createCanonicalGameApi,CANONICAL_GAME_API_PATHS} from './canonical-game-api.mjs';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';

const REF='hwllkabgzaynalahvkpz';
export const PRODUCTION_ORIGIN='https://airlinerra.com';
const HEADERS={'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'};
const fail=(status,message)=>new Response(JSON.stringify({error:message}),{status,headers:HEADERS});

export function validProductionDatabaseUrl(value) {
 try{
  if(typeof value!=='string')return false;
  const u=new URL(value);
  if(!['postgres:','postgresql:'].includes(u.protocol)||!u.password||
     u.pathname!=='/postgres'||u.search||u.hash)return false;
  if(u.hostname==='db.'+REF+'.supabase.co')return u.username==='postgres';
  return u.hostname.endsWith('.pooler.supabase.com')&&u.username.endsWith('.'+REF);
 }catch{return false}
}

export function createProductionGameApi({
 env=process.env,loadPg=()=>import('pg'),fetchImpl=globalThis.fetch,
 origin=PRODUCTION_ORIGIN
}={}){
 if(origin!==PRODUCTION_ORIGIN)throw Error('Untrusted game API origin');
 let cached=null;
 return async function productionGameApi(request){
  if(!(request instanceof Request))return fail(400,'Invalid request');
  const url=new URL(request.url);
  if(url.origin!==PRODUCTION_ORIGIN||url.search||url.hash)
   return fail(403,'Forbidden');
  if(!CANONICAL_GAME_API_PATHS.includes(url.pathname))
   return fail(404,'Not found');
  if(env?.AIRLINERRA_PRODUCTION_API_ENABLED!=='true'||
     !validProductionDatabaseUrl(env?.AIRLINERRA_DATABASE_URL))
   return fail(503,'Game account database is not configured');
  if(!cached){
   cached=(async()=>{
    const driver=await loadPg();
    const Pool=driver.Pool||driver.default?.Pool;
    if(typeof Pool!=='function')throw Error('PostgreSQL driver not available');
    const db=new Pool({
      connectionString:env.AIRLINERRA_DATABASE_URL,
      ssl:{rejectUnauthorized:true},
      max:2,connectionTimeoutMillis:5000,idleTimeoutMillis:10000
    });
    const verified=createHostedAuthVerifier({
      publishableKey:env.AIRLINERRA_PUBLIC_SUPABASE_KEY,
      fetchImpl
    });
    return createCanonicalGameApi({
      enabled:true,origin:PRODUCTION_ORIGIN,
      verifyUserToken:verified,database:db,
      documentPaths:{terms:'/terms.html',privacy:'/privacy.html'}
    });
   })().catch(error=>{cached=null;throw error});
  }
  try{return await(await cached)(request)}
  catch{return fail(503,'Game account API temporarily unavailable')}
 };
}
