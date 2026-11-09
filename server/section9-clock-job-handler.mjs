/**
 * Private scheduled game-day worker HTTP gate for Supabase Cron.
 *
 * NOT a player endpoint. POST with x-airlinerra-clock-job-token only.
 * No user-supplied game date, starting date, world ID or tick count.
 * Requires a separate independently stored secret from the engine HMAC.
 */
import {createHash,timingSafeEqual} from 'node:crypto';

const AUTH='x-airlinerra-clock-job-token';
const noStore={'Cache-Control':'no-store','Content-Type':'application/json'};
const reply=(status,data)=>new Response(JSON.stringify(data),
 {status,headers:noStore});
const allowed=new Set([
 'blocked_world_not_open','not_configured','paused','opening_anchor_changed',
 'clock_state_invalid','clock_outside_release','clock_date_limit','caught_up',
 'catchup_more_due','concurrent_tick_already_applied'
]);
function validToken(expected,received){
 if(typeof received!=='string'||received.length<32||received.length>1024)
  return false;
 const a=createHash('sha256').update(expected,'utf8').digest(),
  b=createHash('sha256').update(received,'utf8').digest();
 return timingSafeEqual(a,b);
}
export function createSection9ClockJobHandler({producer,jobToken}={}){
 if(typeof producer?.runBounded!=='function')
  throw Error('SECTION9_CLOCK_PRODUCER_REQUIRED');
 if(typeof jobToken!=='string'||jobToken.length<32)
  throw Error('SECTION9_CLOCK_JOB_TOKEN_NOT_CONFIGURED');
 return async request=>{
  if(request.method!=='POST')return reply(405,{error:'Method not allowed'});
  if(!validToken(jobToken,request.headers.get(AUTH)))
   return reply(401,{error:'Unauthorized'});
  // Explicitly reject player-selected fields or accidental cron payload
  // templates that include dates, world ID, authorization or finances.
  try{
   const body=await request.text();
   if(body.length>2||body && body!=='{}')
    return reply(400,{error:'Clock job accepts no parameters'});
  }catch{return reply(400,{error:'Invalid request'});}
  try{
   const r=await producer.runBounded({maxDays:3});
   if(r.worldId!==1||!allowed.has(r.status)||
      !Number.isInteger(r.ticksAccepted)||r.ticksAccepted<0||
      r.ticksAccepted>3||!Array.isArray(r.acceptedGameDates)||
      r.acceptedGameDates.length!==r.ticksAccepted||
      r.payrollPosted!==false||r.bookingsCreated!==false)
    return reply(503,{error:'Unverified clock producer result'});
   return reply(200,r);
  }catch{
   // Do not expose database details, secret values, engine proof or private
   // stack traces through the Cron HTTP response.
   return reply(503,{error:'Game clock worker failed closed'});
  }
 };
}
