/**
 * Section 9 independently signed operational-certification ingress.
 * BACKEND-ONLY; not a player API, not an HTTP route, not a signer.
 *
 * One instance is pinned to ONE verifier type and that verifier's
 * independent private signing secret. No secrets are stored in Supabase
 * or source control, and none are accepted from a player request.
 *
 * It authenticates the verified-source event before a single atomic
 * private SQL call. The database rechecks the schedule version and game
 * facts, writes an append-only event, and invalidates stale preparations.
 *
 * This adapter CANNOT produce evidence. Six actual trusted verifier
 * producers must still be implemented and connected before activation.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const EVENT=/^[A-Za-z0-9._:-]{16,128}$/;
const SIGNATURE=/^[a-f0-9]{64}$/;
const TYPES=Object.freeze({
 crew_duty:'verified_crew_duty_engine',
 operator_licence:'verified_game_licence_engine',
 route_traffic_rights:'verified_game_traffic_rights_engine',
 airport_slot_capacity:'verified_airport_slot_engine',
 trusted_flight_execution:'trusted_flight_operations_engine',
 commercial_finance:'verified_commercial_settlement_engine'
});
const validDay=x=>typeof x==='string'&&DAY.test(x)&&
 Number.isFinite(Date.parse(x+'T00:00:00Z'))&&
 new Date(x+'T00:00:00Z').toISOString().slice(0,10)===x&&
 x>='2000-01-01'&&x<='2199-12-31';
const boundedString=(x,min,max)=>typeof x==='string'&&
 x.length>=min&&x.length<=max;
const order=[
 'worldId','airlineId','scheduleId','scheduleVersion',
 'clearanceType','sourceKind','action','eventId','sourceReference',
 'reviewerReference','validFromGameDate','validToGameDate','signature'
];
export const SECTION9_CERTIFICATION_SQL=Object.freeze({
 ingest:'SELECT airlinerra_game.section9_record_verified_certification_event_v1('+
 '$1::uuid,$2::uuid,$3::integer,$4::text,$5::text,$6::text,'+
 '$7::text,$8::text,$9::date,$10::date,$11::text) AS result'
});
export const SECTION9_CLEARANCE_SOURCES=TYPES;
export function section9CertificationPayload(e){
 return [
  'airlinerra-verified-operations-certification-v1',
  '1',String(e.worldId),e.airlineId,e.scheduleId,
  String(e.scheduleVersion),e.clearanceType,e.sourceKind,
  e.action,e.eventId,e.sourceReference,e.reviewerReference,
  e.validFromGameDate,e.validToGameDate
 ].join('\n');
}
function validate(e,clearanceType){
 if(!e||typeof e!=='object'||Array.isArray(e)||
    Object.keys(e).some(k=>!order.includes(k))||
    order.some(k=>!Object.hasOwn(e,k))||
    e.worldId!==1||!UUID.test(e.airlineId||'')||
    !UUID.test(e.scheduleId||'')||
    !Number.isInteger(e.scheduleVersion)||e.scheduleVersion<1||
    e.clearanceType!==clearanceType||
    e.sourceKind!==TYPES[clearanceType]||
    !['certify','revoke'].includes(e.action)||
    !EVENT.test(e.eventId||'')||
    !boundedString(e.sourceReference,16,160)||
    !boundedString(e.reviewerReference,12,160)||
    !validDay(e.validFromGameDate)||!validDay(e.validToGameDate)||
    !SIGNATURE.test(e.signature||'')){
  throw Error('SECTION9_INVALID_SIGNED_CERTIFICATION_EVENT');
 }
 const from=Date.parse(e.validFromGameDate+'T00:00:00Z'),
  until=Date.parse(e.validToGameDate+'T00:00:00Z');
 if(until<from||until-from>365*86400000)
  throw Error('SECTION9_INVALID_SIGNED_CERTIFICATION_INTERVAL');
}
function safeResponse(value,event){
 if(!value||value.eventId!==event.eventId||
   value.scheduleId!==event.scheduleId||
   value.flightActivated!==false||
   value.movementRecorded!==false||
   value.bookingsCreated!==false||
   value.ledgerPosted!==false)
  return false;
 if(value.status==='certification_event_replayed')
  return value.replayed===true&&value.certificateChanged===false;
 if(event.action==='certify')
  return value.status==='certification_event_recorded'&&
   value.replayed===false&&value.certificateChanged===true&&
   value.reviewStatus==='certified'&&
   value.scheduleVersion===event.scheduleVersion&&
   value.clearanceType===event.clearanceType&&
   value.activationPreparationInvalidated===true;
 return value.status==='certification_revoked'&&
   value.replayed===false&&value.certificateChanged===true&&
   value.reviewStatus==='revoked'&&
   value.scheduleVersion===event.scheduleVersion&&
   value.clearanceType===event.clearanceType&&
   value.activationPreparationInvalidated===true;
}
export function createSection9SignedCertificationIngress({
 database,clearanceType,verifierSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_CERTIFICATION_DATABASE_REQUIRED');
 if(!Object.hasOwn(TYPES,clearanceType||''))
  throw Error('SECTION9_UNKNOWN_CERTIFICATION_AUTHORITY');
 if(typeof verifierSecret!=='string'||verifierSecret.length<32)
  throw Error('SECTION9_INDEPENDENT_CERTIFICATION_SECRET_REQUIRED');
 const secret=Buffer.from(verifierSecret,'utf8');
 return Object.freeze({
  clearanceType,
  async acceptSignedDecision(event){
   validate(event,clearanceType);
   const expected=createHmac('sha256',secret)
    .update(section9CertificationPayload(event),'utf8').digest();
   const received=Buffer.from(event.signature,'hex');
   if(received.length!==32||!timingSafeEqual(expected,received))
    throw Error('SECTION9_UNTRUSTED_CERTIFICATION_SIGNATURE');
   const client=await database.connect();
   try{
    const sql=await client.query(SECTION9_CERTIFICATION_SQL.ingest,[
     event.airlineId,event.scheduleId,event.scheduleVersion,
     event.clearanceType,event.action,event.eventId,
     event.sourceReference,event.reviewerReference,
     event.validFromGameDate,event.validToGameDate,event.signature
    ]);
    const result=sql.rows?.[0]?.result;
    if(sql.rowCount!==1||!safeResponse(result,event))
     throw Error('SECTION9_UNSAFE_CERTIFICATION_DB_RESPONSE');
    return result;
   }finally{
    client.release();
   }
  }
 });
}
