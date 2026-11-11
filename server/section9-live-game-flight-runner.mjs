/**
 * Private World 1 real-time GAME flight runner.
 *
 * Processes due departures/arrivals (not forecasts) using:
 * 1. server-owned current UTC game-clock instant + certified game-day receipt,
 * 2. private active schedules, six signed operational clearances and
 *    independently checked physical aircraft state,
 * 3. signed independent phase evidence then separately signed movement ingress.
 *
 * Financial settlements, fuel tank deductions and bookings are NOT connected.
 * A global Postgres advisory lock prevents concurrent executions of this runner.
 * This is never a player-callable endpoint.
 */
import {createHmac} from 'node:crypto';
import {section9MovementSignaturePayload}
 from './section9-operated-flight-movement-ingress.mjs';

const KEY='SECTION9_GAME_FLIGHT_EXECUTION';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const validDay=x=>/^\d{4}-\d{2}-\d{2}$/.test(x||'')&&
 !Number.isNaN(Date.parse(x+'T00:00:00Z'));
export const SECTION9_GAME_FLIGHT_RUN_SQL=Object.freeze({
 lock:'SELECT pg_try_advisory_lock(9427,91) AS acquired',
 unlock:'SELECT pg_advisory_unlock(9427,91) AS released',
 readiness:'SELECT * FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1',
 now:`SELECT to_char(clock_timestamp() AT TIME ZONE 'UTC',
 'YYYY-MM-DD') AS utc_date`,
 fleet:`WITH active AS MATERIALIZED(
 SELECT DISTINCT airline_id::text AS "airlineId",
 aircraft_inventory_id::text AS "aircraftId"
 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE world_id=1 AND status='active' AND operationally_verified=true
 ), total AS(SELECT count(*)::int AS n FROM active),
 page AS(SELECT CASE WHEN n=0 THEN 0
 ELSE (floor(extract(epoch from clock_timestamp())/60)::bigint
  % greatest(1,ceil(n::numeric/$1::int)::bigint))*$1::int
 END AS row_offset,n FROM total)
 SELECT a."airlineId",a."aircraftId",p.n AS "totalAircraft"
 FROM active a CROSS JOIN page p
 ORDER BY a."aircraftId"
 LIMIT $1::int OFFSET (SELECT row_offset FROM page)`,
 due:`SELECT airlinerra_game.section9_due_operation_candidates_v1(
  $1::uuid,$2::uuid,$3::date) AS result`
});
const blocked=reason=>Object.freeze({
 status:reason,readOnly:false,eventsAttested:0,movementsRecorded:0,
 bookingsCreated:false,ledgerPosted:false,flightActivated:false
});
const safeReady=r=>r?.world_id===1&&r.world_state==='active'&&
 r.authoritative_clock_connected===true&&
 r.trusted_flight_execution_release==='RELEASED'&&
 Number(r.active_flight_schedules)>0&&
 Number(r.operational_certification_records)>0&&
 r.automatic_flight_and_fuel_settlement_enabled===false&&
 r.fuel_transaction_release==='NOT_ACTIVATED';
const validCandidate=(c,airline,aircraft,day)=>
 c?.worldId===1&&c.airlineId===airline&&c.aircraftInventoryId===aircraft&&
 uuid.test(c.scheduleId||'')&&Number.isInteger(c.scheduleVersion)&&
 c.scheduleVersion>0&&c.activatedAndCapacityVerified===true&&
 c.scheduledEventUtc?.slice(0,10)===day&&
 ['departed','arrived'].includes(c.phase)&&
 typeof c.eventId==='string'&&
 c.eventId==='operate-v1.'+c.scheduleId.replaceAll('-','')+'.'+
 c.flightLocalDate.replaceAll('-','')+'.'+c.weeklyEntry+'.'+c.phase;

export function createSection9LiveGameFlightRunner({
 database,attestor,operationAuthorizer,movementIngress,movementSecret
}={}){
 if(typeof database?.connect!=='function'||
 typeof attestor?.attestDuePhase!=='function'||
 typeof operationAuthorizer?.confirmActualOperation!=='function'||
 typeof movementIngress?.acceptSignedFlightEvent!=='function'||
 typeof movementSecret!=='string'||movementSecret.length<32)
  throw Error('SECTION9_PRIVATE_FLIGHT_RUNNER_DEPENDENCIES_REQUIRED');
 const secret=Buffer.from(movementSecret,'utf8');
 return Object.freeze({
  async runOnce({maxAircraft=200,maxEvents=50}={}){
   if(!Number.isInteger(maxAircraft)||maxAircraft<1||maxAircraft>200||
      !Number.isInteger(maxEvents)||maxEvents<1||maxEvents>200)
    throw Error('SECTION9_INVALID_GAME_FLIGHT_BATCH_LIMITS');
   const client=await database.connect();let hasLock=false;
   try{
    const lock=await client.query(SECTION9_GAME_FLIGHT_RUN_SQL.lock);
    if(lock.rowCount!==1||lock.rows?.[0]?.acquired!==true)
     return blocked('flight_execution_already_running');
    hasLock=true;
    const readiness=await client.query(SECTION9_GAME_FLIGHT_RUN_SQL.readiness);
    if(readiness.rowCount!==1||!safeReady(readiness.rows?.[0]))
     return blocked('flight_execution_not_ready');
    const current=await client.query(SECTION9_GAME_FLIGHT_RUN_SQL.now);
    const utcDate=current.rows?.[0]?.utc_date;
    if(current.rowCount!==1||!validDay(utcDate))
     throw Error('SECTION9_AUTHORITATIVE_SERVER_DATE_UNAVAILABLE');
    const previous=new Date(Date.parse(utcDate+'T00:00:00Z')-86400000)
      .toISOString().slice(0,10);
    const fleet=await client.query(SECTION9_GAME_FLIGHT_RUN_SQL.fleet,
     [maxAircraft]);
    if(!Array.isArray(fleet.rows)||fleet.rows.length>maxAircraft)
     throw Error('SECTION9_UNBOUNDED_FLIGHT_FLEET');
    const summary={status:'flight_execution_batch_complete',
      aircraftScanned:0,dueEventsSeen:0,eventsAttested:0,
      movementsRecorded:0,alreadyOperated:0,blockedEvents:0,
      fleetSize:Number(fleet.rows?.[0]?.totalAircraft||0),
      bookingsCreated:false,ledgerPosted:false,flightActivated:false,
      automaticFinancialSettlementEnabled:false};

    for(const aircraft of fleet.rows){
     if(!uuid.test(aircraft.airlineId||'')||!uuid.test(aircraft.aircraftId||''))
      throw Error('SECTION9_INVALID_PRIVATE_FLEET_IDENTITY');
     summary.aircraftScanned++;
     const events=[];
     for(const day of [previous,utcDate]){
      const r=await client.query(SECTION9_GAME_FLIGHT_RUN_SQL.due,
       [aircraft.airlineId,aircraft.aircraftId,day]);
      const src=r.rows?.[0]?.result;
      if(r.rowCount!==1||!src||
        src.readOnly!==true||src.movementRecorded!==false||
        src.ledgerPosted!==false||src.requiresTrustedOperationDecision!==true)
       throw Error('SECTION9_UNTRUSTED_DUE_GAME_FLIGHT_SOURCE');
      if(src.status==='verified_due_operation_candidates_only'){
       if(!Array.isArray(src.dueEvents)||src.dueEvents.length>500)
        throw Error('SECTION9_UNBOUNDED_DUE_GAME_FLIGHTS');
       for(const e of src.dueEvents){
        if(!validCandidate(e,aircraft.airlineId,aircraft.aircraftId,day))
         throw Error('SECTION9_INVALID_PRIVATE_DUE_FLIGHT_EVENT');
        events.push(e);
       }
      }else if(!Array.isArray(src.dueEvents)||src.dueEvents.length!==0)
       throw Error('SECTION9_UNSAFE_BLOCKED_DUE_FLIGHT_EVENT');
     }
     events.sort((a,b)=>
      a.scheduledEventUtc.localeCompare(b.scheduledEventUtc)||
      a.eventId.localeCompare(b.eventId));
     for(const event of events){
      if(summary.dueEventsSeen>=maxEvents){
       summary.status='flight_execution_more_due_events_pending';
       return summary;
      }
      summary.dueEventsSeen++;
      const attested=await attestor.attestDuePhase({
       airlineId:aircraft.airlineId,aircraftId:aircraft.aircraftId,
       gameDate:event.scheduledEventUtc.slice(0,10),eventId:event.eventId
      });
      if(!['independent_phase_attestation_recorded',
        'independent_phase_attestation_replayed'].includes(attested?.status)){
       summary.blockedEvents++;
       // A missing departure stops the same aircraft's subsequent events.
       break;
      }
      if(attested.status==='independent_phase_attestation_recorded')
       summary.eventsAttested++;
      const decision=await operationAuthorizer.confirmActualOperation(event);
      if(decision?.decision!=='verified_operated'||
         decision.eventId!==event.eventId||
         decision.flightOccurrenceId!==event.flightOccurrenceId||
         decision.worldId!==1||
         !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(
           decision.actualEventUtc||'')){
       summary.blockedEvents++;break;
      }
      const signed={worldId:1,airlineId:aircraft.airlineId,
       scheduleId:event.scheduleId,scheduleVersion:event.scheduleVersion,
       flightLocalDate:event.flightLocalDate,weeklyEntry:event.weeklyEntry,
       phase:event.phase,actualEventUtc:decision.actualEventUtc,
       eventId:event.eventId};
      signed.signature=createHmac('sha256',secret)
       .update(section9MovementSignaturePayload(signed),'utf8').digest('hex');
      const movement=await movementIngress.acceptSignedFlightEvent(signed);
      if(movement?.status==='operated_movement_replayed'&&
         movement.replayed===true&&movement.movementRecorded===false){
        summary.alreadyOperated++;
      }else if(movement?.status===('operated_flight_'+
         (event.phase==='departed'?'departure':'arrival')+'_recorded')&&
         movement.movementRecorded===true&&movement.replayed===false){
        summary.movementsRecorded++;
      }else{summary.blockedEvents++;break;}
     }
    }
    return summary;
   }finally{
    if(hasLock)try{await client.query(SECTION9_GAME_FLIGHT_RUN_SQL.unlock);}
     catch{throw Error('SECTION9_GAME_FLIGHT_LOCK_RELEASE_FAILED');}
    client.release();
   }
  }
 });
}
