/** Independently authenticated game licence application API.
 * No review, approval, revocation, fee settlement or admin privileges
 * are exposed here. Same trusted Auth + private PostgreSQL as schedule API.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {createSection9PermissionPlayerHandler,GAME_PERMISSION_PLAYER_PATH}
 from './section9-permission-player-http.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings}
 from '../website/invited-tester-public-settings.mjs';

const ORIGIN='https://airlinerra.com';
const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const verify=createHostedAuthVerifier({
 publishableKey:settings.publishableKey
});
let pool:any=null;
const database={
 async connect(){
  if(!DB_URL)throw Error('SECTION9_PERMISSION_PRIVATE_DB_NOT_CONFIGURED');
  if(!pool)pool=new Pool({
   connectionString:DB_URL,ssl:{rejectUnauthorized:true},
   max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000
  });
  return pool.connect();
 }
};
const handler=createSection9PermissionPlayerHandler({
 database,verifyUserToken:verify,origin:ORIGIN
});
const fail=(status:number,error:string)=>Response.json({error},{status,
 headers:{'content-type':'application/json','cache-control':'no-store'}});
Deno.serve(async req=>{
 try{
  if(req.method!=='POST')return fail(405,'POST required');
  if(req.headers.get('x-airlinerra-route')!==GAME_PERMISSION_PLAYER_PATH||
      req.headers.get('origin')!==ORIGIN)
   return fail(403,'Forbidden');
  const body=await req.text();
  if(new TextEncoder().encode(body).byteLength>2048)
   return fail(413,'Request too large');
  const canonical=new Request(ORIGIN+GAME_PERMISSION_PLAYER_PATH,{
   method:'POST',headers:{
    'content-type':req.headers.get('content-type')||'',
    'x-airlinerra-route':GAME_PERMISSION_PLAYER_PATH,
    'authorization':req.headers.get('authorization')||'',
    'origin':ORIGIN
   },body
  });
  return await handler(canonical);
 }catch{return fail(503,'Permission API temporarily unavailable');}
});
