/**
 * Private World 1 flight operations job endpoint, fail closed.
 *
 * This handler DOES NOT generate flight evidence. It runs only an already
 * queued certified aircraft-day job, and ONLY when the separately approved
 * release gate proves trusted execution and official clock are active.
 * No browser, no player-selected time/aircraft, no ability to enqueue jobs.
 */
import {createHash,timingSafeEqual} from 'node:crypto';
const HEADER='x-airlinerra-operations-job-token';
const REPLY_HEADERS={'Cache-Control':'no-store','Content-Type':'application/json'};
const reply=(code,body)=>new Response(JSON.stringify(body),{status:code,headers:REPLY_HEADERS});
const validToken=(expected,actual)=>{
 if(typeof actual!=='string'||actual.length<32||actual.length>1024)return false;
 const a=createHash('sha256').update(expected).digest();
 const b=createHash('sha256').update(actual).digest();
 return timingSafeEqual(a,b);
};
export const flightOperationsReleaseIsReady=r=>
 r?.world_id===1&&r?.world_state==='active'&&
 r?.authoritative_clock_connected===true&&
 r?.clock_producer_configured===true&&
 r?.clock_producer_enabled===true&&
 Number.isInteger(Number(r.active_flight_schedules))&&
 Number(r.active_flight_schedules)>0&&
 Number.isInteger(Number(r.operational_certification_records))&&
 Number(r.operational_certification_records)>0&&
 r?.trusted_flight_execution_release==='RELEASED'&&
 r?.automatic_flight_and_fuel_settlement_enabled===false &&
 r?.fuel_transaction_release==='NOT_ACTIVATED';
export const SECTION9_WORKER_RELEASE_SQL=Object.freeze({
 readiness:'SELECT * FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1'
});
/** Build a private handler. The worker is injected to prove release is
 * checked before even claiming a job. Does NOT enqueue new jobs.
 */
export function createSection9AircraftOperationsJobHandler({
 worker,database,jobToken
}={}){
 if(typeof worker?.runBatch!=='function')throw Error('SECTION9_PRIVATE_WORKER_REQUIRED');
 if(typeof database?.connect!=='function')throw Error('SECTION9_PRIVATE_READINESS_DATABASE_REQUIRED');
 if(typeof jobToken!=='string'||jobToken.length<32)
  throw Error('SECTION9_PRIVATE_OPERATIONS_TOKEN_REQUIRED');
 const readiness=async()=>{
  const client=await database.connect();
  try{
   const result=await client.query(SECTION9_WORKER_RELEASE_SQL.readiness);
   if(result.rowCount!==1||!result.rows?.[0])return false;
   return flightOperationsReleaseIsReady(result.rows[0]);
  }finally{client.release();}
 };
 return async request=>{
  if(request.method!=='POST')return reply(405,{error:'Method not allowed'});
  if(!validToken(jobToken,request.headers.get(HEADER)))
   return reply(401,{error:'Unauthorized'});
  try{
   const body=await request.text();
   if(body && body!=='{}')return reply(400,{error:'No parameters accepted'});
  }catch{return reply(400,{error:'Invalid request'});}
  try{
   if(!await readiness())
    return reply(423,{status:'flight_operations_release_blocked',
     movementRecorded:false,ledgerPosted:false,flightActivated:false});
   const result=await worker.runBatch({maxJobs:20});
   if(result?.status!=='bounded_batch_completed'||
      result.flightActivated!==false||
      !Number.isInteger(result.jobsClaimed)||result.jobsClaimed<0||
      result.jobsClaimed>20||
      !['completed','failed','queued'].every(key=>
        Number.isInteger(result[key])&&result[key]>=0)&&
      result.completed+result.failed+result.queued!==result.jobsClaimed)
    throw Error('SECTION9_PRIVATE_OPERATIONS_UNSAFE_WORKER_RESULT');
   return reply(200,{...result,ledgerPosted:false,bookingsCreated:false});
  }catch{
   return reply(503,{error:'Flight operations worker unavailable'});
  }
 };
}
