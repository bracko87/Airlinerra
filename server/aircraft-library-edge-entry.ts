/** Read-only aircraft library edge endpoint for the private Airlinerra manager.
 * Own function to avoid modifying the existing live game/registration functions.
 * Auth is checked against Supabase /auth/v1/user on EVERY request.
 */
import {Pool} from 'npm:pg@8.16.3';
import {AIRCRAFT_LIBRARY_SQL,serializeAircraftLibrary} from './aircraft-library-query.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';

const ORIGIN='https://airlinerra.com';
const SUPABASE='https://hwllkabgzaynalahvkpz.supabase.co';
const TOKEN=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const dbUrl=Deno.env.get('SUPABASE_DB_URL');
const reply=(status:number,data:unknown)=>Response.json(data,{status,headers:{
  'cache-control':'no-store','x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer'
}});
let pool:any=null;
async function verified(token:string){
 try {
  const response=await fetch(SUPABASE+'/auth/v1/user',{
   method:'GET',headers:{
    apikey:settings.publishableKey,
    authorization:'Bearer '+token,
    accept:'application/json'
   },redirect:'error',cache:'no-store',signal:AbortSignal.timeout(5000)
  });
  if(!response.ok||!String(response.headers.get('content-type')||'').includes('application/json'))
   return false;
  const user=await response.json();
  return Boolean(user&&typeof user.id==='string'&&user.email_confirmed_at&&
    user.is_anonymous!==true&&!user.deleted_at);
 }catch{return false;}
}
Deno.serve(async(request:Request)=>{
 if(request.method!=='POST')return reply(405,{error:'Method not allowed'});
 if(request.headers.get('origin')!==ORIGIN ||
    request.headers.get('x-airlinerra-route')!=='/api/v1/player/aircraft-library')
   return reply(403,{error:'Invalid origin or route'});
 if(request.headers.get('content-type')!=='application/json')return reply(415,{error:'JSON only'});
 const token=TOKEN.exec(request.headers.get('authorization')||'')?.[1];
 if(!token)return reply(401,{error:'Verified session required'});
 let body='';
 try{
  body=await request.text();
  const parsed=JSON.parse(body);
  if(new TextEncoder().encode(body).byteLength>32 || !parsed || typeof parsed!=='object' ||
     Array.isArray(parsed) || Object.keys(parsed).length!==0)
   return reply(400,{error:'Invalid library request'});
 }catch{return reply(400,{error:'Invalid library request'});}
 if(!await verified(token))return reply(401,{error:'Verified session required'});
 if(!dbUrl)return reply(503,{error:'Aircraft library is not configured'});
 let client:any;
 try{
  if(!pool)pool=new Pool({connectionString:dbUrl,ssl:{rejectUnauthorized:true},
   max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
  client=await pool.connect();
  const result=await client.query(AIRCRAFT_LIBRARY_SQL);
  const data=serializeAircraftLibrary(result.rows);
  return reply(200,data);
 }catch(error){
  const code=typeof (error as {code?:string})?.code==='string'&&/^[A-Z0-9]{5}$/.test((error as {code:string}).code)
   ?(error as {code:string}).code:'NONE';
  console.error('Airlinerra aircraft library read unavailable SQLSTATE',code);
  return reply(503,{error:'Aircraft library temporarily unavailable'});
 }finally{try{client?.release()}catch{/* no private logs */}}
});
