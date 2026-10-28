/** Edge runtime entrypoint for the canonical Airlinerra game API.
 * This source is deployed to the existing Supabase project under the
 * "airlinerra-game" function. It relies on Supabase's built-in, private
 * SUPABASE_DB_URL and does not need any Netlify environment variables.
 * Deployment must include this file together with its relative imports.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createCanonicalGameApi,CANONICAL_GAME_API_PATHS} from './canonical-game-api.mjs';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';

const ORIGIN='https://airlinerra.com';
const dbUrl=Deno.env.get('SUPABASE_DB_URL');
const fail=(status:number,error:string)=>Response.json({error},{status,
 headers:{'cache-control':'no-store','x-content-type-options':'nosniff'}});
let api:Promise<(request:Request)=>Promise<Response>>|null=null;
async function gameApi(){
 if(!dbUrl)throw Error('Missing built-in project database connection');
 if(!api)api=Promise.resolve().then(()=>{
  const database=new Pool({connectionString:dbUrl,ssl:{rejectUnauthorized:true},
   max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
  return createCanonicalGameApi({enabled:true,origin:ORIGIN,database,
   verifyUserToken:createHostedAuthVerifier({publishableKey:settings.publishableKey}),
   documentPaths:{terms:'/terms.html',privacy:'/privacy.html'}});
 }).catch(error=>{api=null;throw error});
 return api;
}
Deno.serve(async request=>{
 try{
  if(!['GET','POST'].includes(request.method))return fail(405,'Method not allowed');
  const route=request.headers.get('x-airlinerra-route')||
   (request.method==='GET'?'/api/v1/registration/readiness':'');
  if(!CANONICAL_GAME_API_PATHS.includes(route))return fail(404,'Not found');
  if(request.method==='POST'&&request.headers.get('origin')!==ORIGIN)
   return fail(403,'Invalid origin');
  const body=request.method==='POST'?await request.text():undefined;
  if(typeof body==='string'&&new TextEncoder().encode(body).byteLength>2048)
   return fail(413,'Request body too large');
  const internal=new Request(ORIGIN+route,{method:request.method,headers:{
   'content-type':request.headers.get('content-type')||'application/json',
   'authorization':request.headers.get('authorization')||'',
   'origin':ORIGIN
  },body});
  return await (await gameApi())(internal);
 }catch{return fail(503,'Airlinerra game database temporarily unavailable')}
});
