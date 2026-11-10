/** Airlinerra private flight operations queue worker, dormant by default.
 *
 * NOT A PLAYER API. The endpoint has three independent gates:
 * 1. Supabase platform JWT verification (verify_jwt=true on deploy)
 * 2. a private scheduled-worker token plus an explicit enable flag
 * 3. DB-verified World1 clock, certified active schedules and official release
 *
 * Does not create trusted operation attestations. Only an independently
 * signed, durable actual-operation receipt can move an aircraft. No fuel
 * or airline financial settlement is connected.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createSection9IndependentOperationEvidenceReader}
 from './section9-independent-operation-evidence-reader.mjs';
import {createSection9IndependentOperationAuthorizer}
 from './section9-independent-flight-operation-authorizer.mjs';
import {createSection9OperatedFlightMovementIngress}
 from './section9-operated-flight-movement-ingress.mjs';
import {createSection9VerifiedFlightOperationsDispatcher}
 from './section9-verified-flight-operations-dispatcher.mjs';
import {createSection9AircraftOperationsWorker}
 from './section9-aircraft-operations-worker.mjs';
import {createSection9AircraftOperationsJobHandler}
 from './section9-aircraft-operations-job-handler.mjs';

const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const JOB_TOKEN=Deno.env.get('AIRLINERRA_FLIGHT_OPERATIONS_JOB_TOKEN');
const INDEPENDENT_SECRET=Deno.env.get('AIRLINERRA_INDEPENDENT_FLIGHT_ATTESTATION_SECRET');
const MOVEMENT_SECRET=Deno.env.get('AIRLINERRA_OPERATED_FLIGHT_ENGINE_SECRET');
const ENABLED=Deno.env.get('AIRLINERRA_FLIGHT_OPERATIONS_DEPLOYMENT_APPROVED')==='true';
const ready=ENABLED&&DB_URL&&JOB_TOKEN?.length>=32&&
 INDEPENDENT_SECRET?.length>=32&&MOVEMENT_SECRET?.length>=32&&
 INDEPENDENT_SECRET!==MOVEMENT_SECRET;

if(!ready){
 // This is deliberately a deployed but INACTIVE worker until independent
 // runtime credentials, clock and official release actually exist.
 Deno.serve(()=>Response.json({status:'flight_operations_not_released'},
  {status:503,headers:{'Cache-Control':'no-store'}}));
}else{
 let pool:any=null;
 const database={
  async connect(){
   if(!pool)pool=new Pool({
    connectionString:DB_URL,ssl:{rejectUnauthorized:true},
    max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000
   });
   return pool.connect();
  }
 };
 const reader=createSection9IndependentOperationEvidenceReader({database});
 const authorizer=createSection9IndependentOperationAuthorizer({
  evidenceSource:reader,operationAttestationSecret:INDEPENDENT_SECRET
 });
 const ingress=createSection9OperatedFlightMovementIngress({
  database,operatedFlightEngineSecret:MOVEMENT_SECRET
 });
 const dispatcher=createSection9VerifiedFlightOperationsDispatcher({
  database,operationsAuthorizer:authorizer,movementIngress:ingress,
  operatedFlightEngineSecret:MOVEMENT_SECRET
 });
 const worker=createSection9AircraftOperationsWorker({database,dispatcher});
 const handler=createSection9AircraftOperationsJobHandler({
  worker,database,jobToken:JOB_TOKEN
 });
 Deno.serve(request=>handler(request));
}
