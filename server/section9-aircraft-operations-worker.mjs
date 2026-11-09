/**
 * PRIVATE World 1 aircraft-day operation queue worker.
 *
 * The real flight-operations decision engine is NOT connected or deployed.
 * This worker must never be exposed to browser callers. Jobs only exist
 * after certified game-day receipts and active verified schedules.
 *
 * One job per aircraft/day; PostgreSQL enforces one RUNNING job per aircraft,
 * chronological processing, bounded retries, lease heartbeat, and lease
 * FENCING within the signed movement transaction. No payments/bookings.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-31';
export const SECTION9_AIRCRAFT_WORK_SQL=Object.freeze({
 enqueue:`SELECT airlinerra_game.section9_enqueue_aircraft_operations_batch_v1(
   $1::date,$2::uuid,$3::integer) AS result`,
 claim:`SELECT airlinerra_game.section9_claim_aircraft_operations_v1() AS result`,
 heartbeat:`SELECT airlinerra_game.section9_heartbeat_aircraft_operations_v1(
   $1::uuid,$2::uuid) AS result`,
 complete:`SELECT airlinerra_game.section9_complete_aircraft_operations_v1(
   $1::uuid,$2::uuid,$3::integer,$4::integer) AS result`,
 fail:`SELECT airlinerra_game.section9_fail_aircraft_operations_v1(
   $1::uuid,$2::uuid,$3::text) AS result`
});
const failures=Object.freeze({
 blocked_unverified_actual_operation:'OPERATION_DECISION_MISSING',
 blocked_movement_ingress:'MOVEMENT_INGEST_BLOCKED',
 blocked_unverified_game_day:'CLOCK_NOT_VERIFIED'
});
export function createSection9AircraftOperationsWorker({database,dispatcher}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_AIRCRAFT_WORKER_PRIVATE_DB_REQUIRED');
 if(typeof dispatcher?.dispatchAircraftDay!=='function')
  throw Error('SECTION9_AIRCRAFT_WORKER_VERIFIED_DISPATCHER_REQUIRED');
 async function query(sql,args=[]){
  const client=await database.connect();
  try{
   const r=await client.query(sql,args);
   if(r.rowCount!==1||!r.rows||!r.rows[0]||
       !Object.hasOwn(r.rows[0],'result'))
    throw Error('SECTION9_AIRCRAFT_WORKER_INVALID_DATABASE_RESPONSE');
   return r.rows[0].result;
  }finally{client.release();}
 }
 async function enqueueGameDay({gameDate,afterAircraftId=null,pageSize=200,
  maxPages=150}={}){
  if(!validDay(gameDate)||(afterAircraftId!==null&&!UUID.test(afterAircraftId))||
    !Number.isInteger(pageSize)||pageSize<1||pageSize>200||
    !Number.isInteger(maxPages)||maxPages<1||maxPages>200)
   throw Error('SECTION9_INVALID_AIRCRAFT_ENQUEUE_REQUEST');
  let cursor=afterAircraftId,total=0,scanned=0;
  for(let i=0;i<maxPages;i++){
   const result=await query(SECTION9_AIRCRAFT_WORK_SQL.enqueue,
    [gameDate,cursor,pageSize]);
   if(result?.status==='blocked_unverified_world_or_game_day'&&
       result.jobsEnqueued===0&&result.flightActivated===false&&
       result.movementRecorded===false)
    return {status:result.status,gameDate,jobsEnqueued:0,
      aircraftScanned:0,hasMore:false,flightActivated:false};
   if(result?.status!=='aircraft_operation_jobs_enqueued'||
      result.worldId!==1||result.gameDate!==gameDate||
      !Number.isInteger(result.jobsEnqueued)||result.jobsEnqueued<0||
      result.jobsEnqueued>pageSize||
      !Number.isInteger(result.aircraftScanned)||
      result.aircraftScanned<0||result.aircraftScanned>pageSize||
      result.jobsEnqueued>result.aircraftScanned||
      typeof result.hasMore!=='boolean'||
      result.flightActivated!==false||
      result.movementRecorded!==false||
      result.ledgerPosted!==false)
    throw Error('SECTION9_UNSAFE_AIRCRAFT_ENQUEUE_RESULT');
   total+=result.jobsEnqueued;scanned+=result.aircraftScanned;
   if(!result.hasMore)
    return {status:'enqueue_page_complete',gameDate,
      jobsEnqueued:total,aircraftScanned:scanned,
      hasMore:false,afterAircraftId:result.afterAircraftId,
      flightActivated:false};
   if(!UUID.test(result.afterAircraftId||'')||
      (cursor!==null&&result.afterAircraftId<=cursor)||
      result.aircraftScanned===0)
    throw Error('SECTION9_NON_MONOTONIC_AIRCRAFT_ENQUEUE_CURSOR');
   cursor=result.afterAircraftId;
  }
  return {status:'enqueue_more_pages_required',gameDate,
   jobsEnqueued:total,aircraftScanned:scanned,
   afterAircraftId:cursor,hasMore:true,flightActivated:false};
 }
 async function runOnce(){
  const claim=await query(SECTION9_AIRCRAFT_WORK_SQL.claim);
  if(claim===null)return {status:'no_claimable_aircraft_jobs',
    processed:0,flightActivated:false};
  if(claim.status!=='claimed'||claim.worldId!==1||
     !UUID.test(claim.jobId||'')||!UUID.test(claim.leaseToken||'')||
     !UUID.test(claim.airlineId||'')||!UUID.test(claim.aircraftId||'')||
     !validDay(claim.gameDate)||claim.flightActivated!==false||
     claim.leaseSeconds!==180||
     !Number.isInteger(claim.attempt)||claim.attempt<1||claim.attempt>5)
   throw Error('SECTION9_INVALID_AIRCRAFT_JOB_CLAIM');
  const {jobId,leaseToken,airlineId,aircraftId,gameDate}=claim;
  const heartbeat=async()=>{
   const ok=await query(SECTION9_AIRCRAFT_WORK_SQL.heartbeat,[jobId,leaseToken]);
   if(ok!==true)throw Error('SECTION9_EXPIRED_AIRCRAFT_JOB_LEASE');
  };
  let outcome;
  try{
   await heartbeat();
   outcome=await dispatcher.dispatchAircraftDay({
    airlineId,aircraftId,gameDate,lease:{jobId,leaseToken,heartbeat}
   });
   if(outcome?.status==='aircraft_day_movement_events_accepted'&&
     Number.isInteger(outcome.processed)&&outcome.processed>=0&&
     outcome.processed<=500&&Number.isInteger(outcome.replayed)&&
     outcome.replayed>=0&&outcome.replayed<=outcome.processed&&
     outcome.bookingsCreated===false&&
     outcome.ledgerPosted===false&&
     outcome.flightActivated===false){
    await heartbeat();
    const complete=await query(SECTION9_AIRCRAFT_WORK_SQL.complete,
     [jobId,leaseToken,outcome.processed,outcome.replayed]);
    if(complete?.status!=='completed'||complete.jobId!==jobId||
      complete.processed!==outcome.processed||
      complete.replayed!==outcome.replayed||
      complete.movementEventsConfirmed!==true||
      complete.flightActivated!==false||
      complete.ledgerPosted!==false||complete.bookingsCreated!==false)
     throw Error('SECTION9_AIRCRAFT_WORKER_UNSAFE_COMPLETION');
    return {status:'completed',jobId,gameDate,
     processed:outcome.processed,replayed:outcome.replayed,
     flightActivated:false};
   }
   if(!outcome||typeof outcome.status!=='string'||
     outcome.flightActivated===true||outcome.ledgerPosted===true||
     outcome.bookingsCreated===true)
    throw Error('SECTION9_AIRCRAFT_WORKER_UNSAFE_DISPATCH_RESULT');
  }catch(error){
   // Do not log the exception, private auth material or customer data.
   // If lease was stolen/expired, DB rejects this transition; next worker
   // reclaims it, and SQL movement fencing rejects the stale worker.
   try{
    const failed=await query(SECTION9_AIRCRAFT_WORK_SQL.fail,
      [jobId,leaseToken,'ENGINE_EXCEPTION']);
    if(!['queued','failed'].includes(failed?.status)||
      failed.jobId!==jobId)
     throw Error('SECTION9_AIRCRAFT_WORKER_INVALID_FAILURE_RESPONSE');
    return {status:failed.status,jobId,gameDate,
     failureCode:'ENGINE_EXCEPTION',flightActivated:false};
   }catch{
    throw Error('SECTION9_AIRCRAFT_WORKER_LEASE_LOST_OR_FAILED_TO_RECORD_ERROR');
   }
  }
  const reason=failures[outcome.status]??'READINESS_UNVERIFIED';
  const failed=await query(SECTION9_AIRCRAFT_WORK_SQL.fail,[jobId,leaseToken,reason]);
  if(!['queued','failed'].includes(failed?.status)||
    failed.jobId!==jobId||failed.failureCode!==reason||
    failed.flightActivated!==false)
   throw Error('SECTION9_AIRCRAFT_WORKER_INVALID_FAILURE_RESPONSE');
  return {status:failed.status,jobId,gameDate,
   failureCode:reason,flightActivated:false};
 }
 async function runBatch({maxJobs=50}={}){
  if(!Number.isInteger(maxJobs)||maxJobs<1||maxJobs>200)
   throw Error('SECTION9_INVALID_AIRCRAFT_JOB_BUDGET');
  const summary={status:'bounded_batch_completed',jobsClaimed:0,
    completed:0,queued:0,failed:0,flightActivated:false};
  for(let i=0;i<maxJobs;i++){
   const r=await runOnce();
   if(r.status==='no_claimable_aircraft_jobs')break;
   if(!['completed','queued','failed'].includes(r.status))
    throw Error('SECTION9_UNEXPECTED_AIRCRAFT_BATCH_STATE');
   summary.jobsClaimed++;
   summary[r.status]++;
  }
  return summary;
 }
 return Object.freeze({enqueueGameDay,runOnce,runBatch});
}
