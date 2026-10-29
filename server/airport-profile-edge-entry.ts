/** Dedicated authenticated READ-ONLY airport profile endpoint.
 * Deployed separately from existing airlinerra-game to avoid replacing newer
 * production airline-office logic. No writes, public Data API tables, or account records.
 */
import {Pool} from 'npm:pg@8.16.3';
import {AIRPORT_PROFILE_SQL,serializeAirportProfile,validAirportKey} from './airport-profile-service.mjs';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';
const AUTH_ORIGIN='https://airlinerra.com';
const PATH='/api/v1/player/airport-profile';
const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const auth=createHostedAuthVerifier({publishableKey:settings.publishableKey});
const headers={'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
const respond=(status,body)=>new Response(JSON.stringify(body),{status,headers});
const TOKEN=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
let pool=null;
async function queryProfile(key){
 if(!DB_URL)throw Error('Project database unavailable');
 if(!pool)pool=new Pool({connectionString:DB_URL,ssl:{rejectUnauthorized:true},
  max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
 const client=await pool.connect();
 try{
  const result=await client.query(AIRPORT_PROFILE_SQL,[key]);
  if(!Array.isArray(result.rows)||result.rows.length>1)throw Error('Invalid airport record');
  return result.rows[0]||null;
 }finally{client.release();}
}
Deno.serve(async request=>{
 if(request.method!=='POST')return respond(405,{error:'Method not allowed'});
 if(request.headers.get('origin')!==AUTH_ORIGIN||
    request.headers.get('x-airlinerra-route')!==PATH)return respond(403,{error:'Forbidden'});
 if(request.headers.get('content-type')!=='application/json')return respond(415,{error:'JSON required'});
 const token=TOKEN.exec(request.headers.get('authorization')||'')?.[1];
 if(!token)return respond(401,{error:'Verified session required'});
 let body;
 try{
  const bytes=await request.arrayBuffer();
  if(bytes.byteLength>512)return respond(413,{error:'Request too large'});
  body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
 }catch{return respond(400,{error:'Invalid JSON body'});}
 if(!body||typeof body!=='object'||Array.isArray(body)||
   Object.keys(body).length!==1||!validAirportKey(body.airportKey))
   return respond(400,{error:'Invalid airport key'});
 const verified=await auth(token);
 if(verified?.error||!verified?.user?.id)return respond(401,{error:'Verified session required'});
 try{
  const row=await queryProfile(body.airportKey);
  if(!row)return respond(404,{error:'Airport is not in approved World 1'});
  return respond(200,{airport:serializeAirportProfile(row)});
 }catch{return respond(503,{error:'Airport profile temporarily unavailable'});}
});
