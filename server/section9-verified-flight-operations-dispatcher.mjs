/**
 * Private, source-only operational movement dispatcher.
 *
 * READ-ONLY scheduled candidates are NOT evidence that a flight operated.
 * The independent trusted game flight-operations engine must first return
 * a confirmed departure/arrival decision. Only then does this module sign
 * the event with the dedicated movement HMAC secret and pass it to the
 * existing private, database-validated movement ingress.
 *
 * Not a browser/Netlify endpoint; no cron deployment; no activation,
 * bookings, revenue, expenses or automatic game-clock advancement.
 *
 * Production dispatch requires a durable per-aircraft work lease and stored,
 * stable operations decisions before enabling concurrent workers. That
 * infrastructure is deliberately NOT claimed here.
 */
import {createHmac} from 'node:crypto';
import {section9MovementSignaturePayload}
 from './section9-operated-flight-movement-ingress.mjs';

// Use the canonical UUID matcher; do not accept arbitrary IDs as identities.
const IDENT=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const token=/^[A-Za-z0-9._:-]{12,128}$/;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-31';
const validUtc=s=>typeof s==='string'&&UTC.test(s)&&
 Number.isFinite(Date.parse(s))&&new Date(s).toISOString()===s.replace('Z','.000Z')&&
 s.slice(0,10)>='2000-01-01'&&s.slice(0,10)<='2199-12-31';

export const SECTION9_OPERATIONS_DISPATCH_SQL=Object.freeze({
 candidates:`SELECT airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
  $1::uuid,$2::uuid,$3::date) AS result`
});
const expectedEventId=c=>
 'operate-v1.'+c.scheduleId.replaceAll('-','').toLowerCase()+'.'+
 c.flightLocalDate.replaceAll('-','')+'.'+c.weeklyEntry+'.'+c.phase;
const orderKey=c=>[
 c.scheduledEventUtc,c.scheduleId,c.flightLocalDate,
 String(c.weeklyEntry).padStart(2,'0'),c.phase
].join('|');
function validateCandidate(c,{airlineId,aircraftId,gameDate}){
 if(!c||typeof c!=='object'||Array.isArray(c)||
  c.worldId!==1||c.airlineId!==airlineId||
  c.aircraftInventoryId!==aircraftId||!IDENT.test(c.scheduleId||'')||
  !Number.isSafeInteger(c.scheduleVersion)||c.scheduleVersion<1||
  !validDay(c.flightLocalDate)||
  !Number.isInteger(c.weeklyEntry)||c.weeklyEntry<1||c.weeklyEntry>7||
  !['departed','arrived'].includes(c.phase)||
  !validUtc(c.scheduledEventUtc)||
  c.scheduledEventUtc.slice(0,10)!==gameDate||
  c.activatedAndCapacityVerified!==true||
  c.eventId!==expectedEventId(c)||
  c.flightOccurrenceId!==c.scheduleId+':'+c.flightLocalDate+':'+c.weeklyEntry||
  typeof c.originAirportKey!=='string'||c.originAirportKey.length<4||
  typeof c.destinationAirportKey!=='string'||c.destinationAirportKey.length<4||
  c.originAirportKey===c.destinationAirportKey)
  throw Error('SECTION9_INVALID_VERIFIED_OPERATION_CANDIDATE');
}
function verifyCandidates(r,identity){
 if(!r||r.worldId!==1||r.readOnly!==true||
    r.requiresTrustedOperationDecision!==true||
    r.flightActivated!==false||r.movementRecorded!==false||
    !Array.isArray(r.candidates))
  throw Error('SECTION9_UNSAFE_OPERATION_CANDIDATE_SOURCE');
 if(r.status!=='verified_operational_candidates_only'){
  if(!['blocked_world_not_open','blocked_unverified_game_day',
    'blocked_aircraft_not_in_service','no_verified_activated_schedules',
    'blocked_aircraft_schedule_sharding_required',
    'blocked_unverified_activated_capacity',
    'blocked_unverified_aircraft_delivery',
    'blocked_unverified_origin_timezone',
    'blocked_invalid_weekly_timetable',
    'blocked_ambiguous_or_missing_local_time',
    'blocked_day_event_limit_requires_sharding'].includes(r.status)||
    r.candidates.length!==0)
    throw Error('SECTION9_UNKNOWN_OPERATION_CANDIDATE_STATUS');
  return false;
 }
 if(r.airlineId!==identity.airlineId||
    r.aircraftInventoryId!==identity.aircraftId||
    r.gameDate!==identity.gameDate||
    r.eventCount!==r.candidates.length||r.candidates.length>500)
  throw Error('SECTION9_OPERATION_CANDIDATE_IDENTITY_MISMATCH');
 let previous=null;
 const seen=new Set();
 for(const candidate of r.candidates){
  validateCandidate(candidate,identity);
  const key=orderKey(candidate);
  if(previous!==null&&key<=previous)
   throw Error('SECTION9_UNORDERED_OR_DUPLICATE_OPERATION_CANDIDATES');
  if(seen.has(candidate.eventId))
   throw Error('SECTION9_DUPLICATE_OPERATION_CANDIDATE');
  seen.add(candidate.eventId);
  previous=key;
 }
 return true;
}
export function createSection9VerifiedFlightOperationsDispatcher({
 database,operationsAuthorizer,movementIngress,operatedFlightEngineSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_OPERATIONS_PRIVATE_DATABASE_REQUIRED');
 if(typeof operationsAuthorizer?.confirmActualOperation!=='function')
  throw Error('SECTION9_TRUSTED_OPERATION_AUTHORIZER_REQUIRED');
 if(typeof movementIngress?.acceptSignedFlightEvent!=='function')
  throw Error('SECTION9_PRIVATE_MOVEMENT_INGRESS_REQUIRED');
 if(typeof operatedFlightEngineSecret!=='string'||
    operatedFlightEngineSecret.length<32)
  throw Error('SECTION9_MOVEMENT_ENGINE_SECRET_REQUIRED');
 const secret=Buffer.from(operatedFlightEngineSecret,'utf8');
 async function readCandidates({airlineId,aircraftId,gameDate}={}){
  if(!IDENT.test(airlineId||'')||!IDENT.test(aircraftId||'')||
     !validDay(gameDate))
   throw Error('SECTION9_INVALID_OPERATION_DISPATCH_REQUEST');
  const client=await database.connect();
  try{
   const result=await client.query(SECTION9_OPERATIONS_DISPATCH_SQL.candidates,[
    airlineId,aircraftId,gameDate
   ]);
   const body=result.rows?.[0]?.result;
   if(result.rowCount!==1)throw Error('SECTION9_OPERATION_CANDIDATES_UNAVAILABLE');
   verifyCandidates(body,{airlineId,aircraftId,gameDate});
   return body;
  }finally{client.release();}
 }
 return Object.freeze({
  readCandidates,
  async dispatchAircraftDay({airlineId,aircraftId,gameDate}={}){
   const plan=await readCandidates({airlineId,aircraftId,gameDate});
   if(plan.status!=='verified_operational_candidates_only')
    return {status:plan.status,gameDate,processed:0,movementRecorded:false,
     requiresTrustedOperationDecision:true};
   let processed=0,replayed=0,previousActualUtc=null;
   for(const c of plan.candidates){
    // An unverified operation HALTS this physical aircraft's sequence.
    // Never skip a missing departure and process an arrival or next flight.
    const decision=await operationsAuthorizer.confirmActualOperation(
      Object.freeze({...c}));
    if(!decision||decision.decision!=='verified_operated'||
       decision.worldId!==1||decision.eventId!==c.eventId||
       decision.flightOccurrenceId!==c.flightOccurrenceId||
       !token.test(decision.operationReference||'')||
       !validUtc(decision.actualEventUtc)||
       decision.actualEventUtc.slice(0,10)!==gameDate||
       (previousActualUtc!==null&&
        decision.actualEventUtc<=previousActualUtc))
      return {status:'blocked_unverified_actual_operation',gameDate,
       processed,replayed,movementRecorded:processed>replayed,
       requiresTrustedOperationDecision:true};
    const signed={
     worldId:1,airlineId:c.airlineId,scheduleId:c.scheduleId,
     scheduleVersion:c.scheduleVersion,flightLocalDate:c.flightLocalDate,
     weeklyEntry:c.weeklyEntry,phase:c.phase,
     actualEventUtc:decision.actualEventUtc,eventId:c.eventId
    };
    signed.signature=createHmac('sha256',secret)
      .update(section9MovementSignaturePayload(signed),'utf8').digest('hex');
    const result=await movementIngress.acceptSignedFlightEvent(signed);
    if(result?.status==='operated_movement_replayed'&&
       result.replayed===true&&result.movementRecorded===false){
      processed++;replayed++;
    }else if((result?.status==='operated_flight_departure_recorded'&&c.phase==='departed'
      ||result?.status==='operated_flight_arrival_recorded'&&c.phase==='arrived')&&
       result.movementRecorded===true&&result.replayed===false){
      processed++;
    }else{
      return {status:'blocked_movement_ingress',gameDate,processed,replayed,
       movementRecorded:processed>replayed,
       requiresTrustedOperationDecision:true};
    }
    previousActualUtc=decision.actualEventUtc;
   }
   return {status:'aircraft_day_movement_events_accepted',gameDate,
    processed,replayed,movementRecorded:processed>replayed,
    requiresTrustedOperationDecision:true,
    bookingsCreated:false,ledgerPosted:false,flightActivated:false};
  }
 });
}
