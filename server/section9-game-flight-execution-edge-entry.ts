/**
 * Strictly private World 1 GAME flight execution job, never a player API.
 *
 * Deployment is fail-closed unless independently approved and all private
 * credentials are configured. The database separately requires a signed
 * game clock, six operational approvals, a certified ACTIVE schedule and
 * explicit private flight-execution release. Finance remains disabled.
 * This function intentionally uses a strong private job token instead of
 * exposing a public JWT/player call surface.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createHash,timingSafeEqual} from 'node:crypto';
import {createSection9LiveGameFlightRunner}
 from './section9-live-game-flight-runner.mjs';
import {createSection9IndependentGamePhaseAttestor}
 from './section9-independent-game-phase-attestor.mjs';
import {createSection9IndependentOperationEvidenceReader}
 from './section9-independent-operation-evidence-reader.mjs';
import {createSection9IndependentOperationAuthorizer}
 from './section9-independent-flight-operation-authorizer.mjs';
import {createSection9OperatedFlightMovementIngress}
 from './section9-operated-flight-movement-ingress.mjs';

const dbUrl=Deno.env.get('SUPABASE_DB_URL');
const jobToken=Deno.env.get('AIRLINERRA_FLIGHT_EXECUTION_JOB_TOKEN');
const independentSecret=Deno.env.get('AIRLINERRA_INDEPENDENT_FLIGHT_ATTESTATION_SECRET');
const movementSecret=Deno.env.get('AIRLINERRA_OPERATED_FLIGHT_ENGINE_SECRET');
const deploymentApproved=Deno.env.get('AIRLINERRA_FLIGHT_EXECUTION_DEPLOYMENT_APPROVED')==='true';

const ready=deploymentApproved&&!!dbUrl&&
 typeof jobToken==='string'&&jobToken.length>=32&&
 typeof independentSecret==='string'&&independentSecret.length>=32&&
 typeof movementSecret==='string'&&movementSecret.length>=32&&
 independentSecret!==movementSecret&&jobToken!==movementSecret&&
 jobToken!==independentSecret;
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
const respond=(status:number,obj:Record<string,unknown>)=>
 new Response(JSON.stringify(obj),{status,headers});
const equalToken=(actual:string|null)=>{
 if(!jobToken||!actual||actual.length<32||actual.length>1024)return false;
 const expected=createHash('sha256').update(jobToken).digest();
 const received=createHash('sha256').update(actual).digest();
 return timingSafeEqual(expected,received);
};
if(!ready){
 Deno.serve(()=>respond(503,{status:'private_flight_execution_not_configured',
  movementsRecorded:0,ledgerPosted:false}));
}else{
 let pool:any=null;
 const database={
  async connect(){
   if(!pool)pool=new Pool({
     connectionString:dbUrl,ssl:{rejectUnauthorized:true},max:5,
     idleTimeoutMillis:10000,connectionTimeoutMillis:5000
   });
   return pool.connect();
  }
 };
 const attestor=createSection9IndependentGamePhaseAttestor({
  database,independentAttestationSecret:independentSecret
 });
 const reader=createSection9IndependentOperationEvidenceReader({database});
 const authorizer=createSection9IndependentOperationAuthorizer({
  evidenceSource:reader,operationAttestationSecret:independentSecret
 });
 const ingress=createSection9OperatedFlightMovementIngress({
  database,operatedFlightEngineSecret:movementSecret
 });
 const runner=createSection9LiveGameFlightRunner({
  database,attestor,operationAuthorizer:authorizer,
  movementIngress:ingress,movementSecret
 });
 Deno.serve(async(request:Request)=>{
  if(request.method!=='POST')return respond(405,{error:'Method not allowed'});
  if(!equalToken(request.headers.get('x-airlinerra-flight-execution-token')))
   return respond(401,{error:'Unauthorized'});
  let body:string;
  try{body=await request.text();}
  catch{return respond(400,{error:'Invalid request'});}
  if(body.trim()&&body.trim()!=='{}')
   return respond(400,{error:'No parameters accepted'});
  try{
   const result=await runner.runOnce({maxAircraft:200,maxEvents:50});
   if(result?.status==='flight_execution_not_ready')
    return respond(423,result);
   if(result?.status==='flight_execution_already_running')
    return respond(409,result);
   if(!['flight_execution_batch_complete',
    'flight_execution_more_due_events_pending'].includes(result?.status))
    throw Error('SECTION9_UNEXPECTED_EXECUTION_RESULT');
   return respond(200,result);
  }catch{
   // Never put sensitive SQL, environment variables, identities or stack
   // traces in a caller-visible response.
   return respond(503,{status:'private_flight_execution_unavailable',
    movementsRecorded:0,ledgerPosted:false});
  }
 });
}
