/** Public read-only World 1 current time, sourced from PostgreSQL.
 * No player/flight permissions, dates or monetary operations are exposed.
 * Supabase service credentials are NOT present in browser code. */
import {Pool} from 'npm:pg@8.16.3';

const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const ORIGINS=new Set(['https://airlinerra.com','http://localhost:5188']);
const JSON_HEADERS={'Content-Type':'application/json; charset=utf-8',
 'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',
 'Referrer-Policy':'no-referrer'};
let pool:any=null;
Deno.serve(async(request:Request)=>{
 const origin=request.headers.get('origin');
 const headers={...JSON_HEADERS,...(ORIGINS.has(origin||'')?
  {'Access-Control-Allow-Origin':origin!,'Vary':'Origin'}:{})};
 if(origin&&!ORIGINS.has(origin))
  return Response.json({error:'Origin not allowed'},{status:403,headers:JSON_HEADERS});
 if(request.method==='OPTIONS')
  return new Response(null,{status:204,headers:{
   ...headers,'Access-Control-Allow-Methods':'GET,OPTIONS',
   'Access-Control-Allow-Headers':'Content-Type',
   'Access-Control-Max-Age':'300'}});
 if(request.method!=='GET')
  return Response.json({error:'Method not allowed'},{status:405,headers});
 const url=new URL(request.url);
 if(url.search||url.hash)
  return Response.json({error:'Invalid query'},{status:400,headers});
 if(!DB_URL)return Response.json({error:'Clock unavailable'},
  {status:503,headers});
 let client:any=null;
 try{
  if(!pool)pool=new Pool({connectionString:DB_URL,
   ssl:{rejectUnauthorized:true},max:2,
   idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
  client=await pool.connect();
  const data=await client.query(
   'SELECT airlinerra_game.section9_live_berlin_clock_v1(1::smallint) AS result');
  const value=data.rows?.[0]?.result;
  if(data.rowCount!==1||value?.worldId!==1||
   value?.timeZone!=='Europe/Berlin'||value?.speed!=='1:1'||
   value?.readOnly!==true||
   !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value?.utcNow||''))
   throw Error('Invalid authoritative time');
  return Response.json(value,{headers});
 }catch{
  return Response.json({error:'Server time unavailable'},
   {status:503,headers});
 }finally{client?.release();}
});
