/**
 * Private signed ACTUALLY OPERATED flight movement ingress.
 *
 * The user website, schedule drafts, demand previews and ordinary game
 * clock cannot certify an aircraft departure or arrival. A separately
 * protected trusted flight-operations engine must sign every event using
 * its own dedicated secret. The database revalidates the matching ACTIVE,
 * operationally-verified schedule, capacity, signed game-clock receipt,
 * aircraft delivery anchor and physical airport/flight chronology.
 *
 * No browser endpoint, flight activation or financial writes.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE=/^\d{4}-\d{2}-\d{2}$/;
const EVENT=/^[A-Za-z0-9._:-]{12,128}$/;
const HEX=/^[a-f0-9]{64}$/;
const UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const validDay=s=>typeof s==='string'&&DATE.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-31';
const validTime=s=>typeof s==='string'&&UTC.test(s)&&
 Number.isFinite(Date.parse(s))&&
 new Date(s).toISOString().slice(0,19)+'Z'===s&&
 s.slice(0,10)>='2000-01-01'&&s.slice(0,10)<='2199-12-31';

export const SECTION9_MOVEMENT_SQL=Object.freeze({
 ingest:`SELECT airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 $1::uuid,$2::uuid,$3::integer,$4::date,$5::integer,
 $6::text,$7::timestamptz,$8::text,$9::text) AS result`
});
export const section9MovementSignaturePayload=event=>
 [
  'airlinerra-operated-flight-movement-v1',
  '1',
  event.airlineId,event.scheduleId,String(event.scheduleVersion),
  event.flightLocalDate,String(event.weeklyEntry),
  event.phase,event.actualEventUtc,event.eventId
 ].join('\n');
function validEvent(e){
 return e&&typeof e==='object'&&!Array.isArray(e)&&
  e.worldId===1&&UUID.test(e.airlineId||'')&&UUID.test(e.scheduleId||'')&&
  Number.isInteger(e.scheduleVersion)&&e.scheduleVersion>=1&&
  Number.isInteger(e.weeklyEntry)&&e.weeklyEntry>=1&&e.weeklyEntry<=7&&
  validDay(e.flightLocalDate)&&['departed','arrived'].includes(e.phase)&&
  validTime(e.actualEventUtc)&&EVENT.test(e.eventId||'')&&
  HEX.test(e.signature||'')&&
  Object.keys(e).every(k=>[
   'worldId','airlineId','scheduleId','scheduleVersion',
   'flightLocalDate','weeklyEntry','phase','actualEventUtc',
   'eventId','signature'
  ].includes(k));
}
function safeResult(r,e){
 if(!r||r.bookingsCreated!==false||r.ledgerPosted!==false||
  r.flightActivated!==false)return false;
 const expected=e.scheduleId+':'+e.flightLocalDate+':'+e.weeklyEntry;
 if(r.status==='blocked_world_not_open'||
    r.status==='blocked_unverified_game_clock'||
    r.status==='blocked_schedule_not_operational')
  return r.movementRecorded===false;
 if(r.status==='operated_movement_replayed')
  return r.movementRecorded===false&&r.replayed===true&&
   r.flightOccurrenceId===expected&&r.phase===e.phase;
 if(r.status==='operated_flight_departure_recorded')
  return e.phase==='departed'&&r.movementRecorded===true&&
   r.replayed===false&&r.flightOccurrenceId===expected&&
   r.phase==='departed'&&r.locationStatus==='in_flight'&&
   r.lastVerifiedAirport===null&&r.canActivateNormalFlight===false;
 if(r.status==='operated_flight_arrival_recorded')
  return e.phase==='arrived'&&r.movementRecorded===true&&
   r.replayed===false&&r.flightOccurrenceId===expected&&
   r.phase==='arrived'&&r.locationStatus==='grounded'&&
   typeof r.lastVerifiedAirport==='string'&&
   r.lastVerifiedAirport.length>3&&r.canActivateNormalFlight===false;
 return false;
}
export function createSection9OperatedFlightMovementIngress({
 database,operatedFlightEngineSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_FLIGHT_MOVEMENT_DB_REQUIRED');
 if(typeof operatedFlightEngineSecret!=='string'||
  operatedFlightEngineSecret.length<32)
  throw Error('SECTION9_PRIVATE_FLIGHT_ENGINE_SECRET_REQUIRED');
 const secret=Buffer.from(operatedFlightEngineSecret,'utf8');
 return Object.freeze({
  async acceptSignedFlightEvent(event){
   if(!validEvent(event))
    throw Error('SECTION9_INVALID_OPERATED_FLIGHT_EVENT');
   const expected=createHmac('sha256',secret)
    .update(section9MovementSignaturePayload(event),'utf8').digest();
   const received=Buffer.from(event.signature,'hex');
   if(received.length!==32||!timingSafeEqual(expected,received))
    throw Error('SECTION9_UNTRUSTED_OPERATED_FLIGHT_SIGNATURE');
   const client=await database.connect();
   try{
    const result=await client.query(SECTION9_MOVEMENT_SQL.ingest,[
     event.airlineId,event.scheduleId,event.scheduleVersion,
     event.flightLocalDate,event.weeklyEntry,event.phase,
     event.actualEventUtc,event.eventId,event.signature
    ]);
    const state=result.rows?.[0]?.result;
    if(result.rowCount!==1||!safeResult(state,event))
     throw Error('SECTION9_UNSAFE_FLIGHT_MOVEMENT_DB_RESPONSE');
    return state;
   }finally{client.release();}
  }
 });
}
