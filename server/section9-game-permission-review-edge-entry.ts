/**
 * Private, independently signed GAME permission decisions.
 * Not called by the browser: the player-facing permission endpoint only
 * supports status/application. Missing private credentials fail closed.
 * No game catalogue or release policy is changed by deploying this adapter.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createSection9GamePermissionReviewIngress}
 from './section9-game-permission-application-service.mjs';

const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const REVIEW_SECRET=Deno.env.get('AIRLINERRA_GAME_PERMISSION_REVIEW_HMAC_SECRET');
const configured=typeof DB_URL==='string'&&DB_URL.length>24&&
 typeof REVIEW_SECRET==='string'&&REVIEW_SECRET.length>=32;
let pool:any=null;
const database={
 async connect(){
  if(!configured||!DB_URL)
   throw Error('SECTION9_INDEPENDENT_PERMISSION_REVIEW_NOT_CONFIGURED');
  if(!pool)pool=new Pool({
   connectionString:DB_URL,
   ssl:{rejectUnauthorized:true},
   max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000
  });
  return pool.connect();
 }
};
const ingress=configured?createSection9GamePermissionReviewIngress({
 database,independentReviewSecret:REVIEW_SECRET
}):null;
const fail=(status:number,error:string)=>Response.json({error},{
 status,headers:{'cache-control':'no-store','content-type':'application/json',
 'x-content-type-options':'nosniff'}
});
Deno.serve(async req=>{
 if(!ingress)return fail(503,'Independent permission review not configured');
 if(req.method!=='POST')return fail(405,'POST required');
 if(req.headers.get('content-type')!=='application/json')
  return fail(415,'JSON required');
 if(req.headers.get('origin'))
  return fail(403,'Browser requests not permitted');
 if(req.headers.get('x-airlinerra-review-protocol')!=='game-permission-review-v1')
  return fail(403,'Signed review protocol required');
 const contentLength=req.headers.get('content-length');
 if(contentLength!==null&&(!/^\d+$/.test(contentLength)||
     Number(contentLength)>4096))return fail(413,'Request too large');
 try{
  const raw=await req.text();
  if(new TextEncoder().encode(raw).byteLength>4096)
   return fail(413,'Request too large');
  const event=JSON.parse(raw);
  const result=await ingress.acceptSignedReview(event);
  return Response.json(result,{status:200,headers:{
   'cache-control':'no-store',
   'content-type':'application/json',
   'x-content-type-options':'nosniff'
  }});
 }catch(error){
  const message=String(error?.message||'');
  if(/INVALID_SIGNED_GAME_PERMISSION_REVIEW|UNTRUSTED_GAME_PERMISSION_REVIEW_SIGNATURE/.test(message))
   return fail(403,'Signed review rejected');
  return fail(503,'Independent permission review unavailable');
 }
});
