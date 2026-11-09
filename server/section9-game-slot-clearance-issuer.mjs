/**
 * Section 9 independent GAME airport-slot clearance issuer.
 *
 * Not a player endpoint, not a legal airport clearance, and not an
 * administrator-operated flight-activation switch. This is one source
 * of six separate operational certification authorities.
 *
 * It reads an independently verified private PostgreSQL slot proof,
 * checks the exact schedule, game day, and capacity fingerprint, and
 * signs ONLY that verified proof using the slot authority's own key.
 *
 * The separate certification ingress verifies the HMAC AGAIN; PostgreSQL
 * repeats the live slot proof check atomically while recording the event.
 * No game clock, reservations, flight status, movement or money is changed.
 */
import {createHmac} from 'node:crypto';
import {section9CertificationPayload}
 from './section9-signed-certification-ingress.mjs';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const HEX=/^[a-f0-9]{32}$/;
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-01';
const plus28=s=>new Date(Date.parse(s+'T00:00:00Z')+
 28*86400000).toISOString().slice(0,10);
export const SECTION9_SLOT_AUTHORITY_SQL=Object.freeze({
 evidence:'SELECT airlinerra_game.section9_verify_slot_clearance_source_v1('+
 '$1::uuid,$2::uuid,$3::integer,$4::date) AS result'
});
function checkedProof(proof,request){
 if(!proof||proof.status!=='verified_game_airport_slots'||
    proof.readOnly!==true||proof.verified!==true||
    proof.worldId!==1||proof.airlineId!==request.airlineId||
    proof.scheduleId!==request.scheduleId||
    proof.scheduleVersion!==request.scheduleVersion||
    proof.gameDate!==request.gameDate||
    proof.validThroughGameDate!==plus28(request.gameDate)||
    proof.clearanceType!=='airport_slot_capacity'||
    proof.sourceKind!=='verified_airport_slot_engine'||
    !HEX.test(proof.proofFingerprint||'')||
    proof.sourceReference!=='game-slot-capacity-v1-'+proof.proofFingerprint||
    proof.reviewerReference!=='independent-game-slot-authority-v1'||
    !Number.isInteger(proof.proposedSlots)||proof.proposedSlots<1||
    proof.reservedSlots!==proof.proposedSlots||
    proof.flightActivated!==false||proof.movementRecorded!==false||
    proof.bookingsCreated!==false||proof.ledgerPosted!==false)
  throw Error('SECTION9_UNTRUSTED_GAME_SLOT_SOURCE_PROOF');
}
export function createSection9GameSlotClearanceIssuer({
 database,slotAuthoritySecret,certificationIngress
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_SLOT_AUTHORITY_DATABASE_REQUIRED');
 if(typeof slotAuthoritySecret!=='string'||slotAuthoritySecret.length<32)
  throw Error('SECTION9_GAME_SLOT_SIGNING_SECRET_REQUIRED');
 if(certificationIngress?.clearanceType!=='airport_slot_capacity'||
    typeof certificationIngress?.acceptSignedDecision!=='function')
  throw Error('SECTION9_MATCHING_SLOT_CERTIFICATION_INGRESS_REQUIRED');
 const secret=Buffer.from(slotAuthoritySecret,'utf8');
 return Object.freeze({
  async certifyCurrentSlotReservation({
   airlineId,scheduleId,scheduleVersion,gameDate
  }={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
      !Number.isInteger(scheduleVersion)||scheduleVersion<1||
      !validDay(gameDate))
    throw Error('SECTION9_INVALID_SLOT_CERTIFICATION_REQUEST');
   const client=await database.connect();
   let proof;
   try{
    const r=await client.query(SECTION9_SLOT_AUTHORITY_SQL.evidence,
     [airlineId,scheduleId,scheduleVersion,gameDate]);
    if(r.rowCount!==1||!r.rows?.[0]?.result)
     throw Error('SECTION9_SLOT_SOURCE_RESULT_MISSING');
    proof=r.rows[0].result;
   }finally{client.release();}
   if(proof.status==='blocked_unverified_world_or_game_day'||
      proof.status==='blocked_stale_or_non_draft_schedule'||
      proof.status==='blocked_slot_clearance_evidence'){
    if(proof.verified!==false||proof.readOnly!==true||
       proof.flightActivated!==false||proof.movementRecorded!==false||
       proof.bookingsCreated!==false||proof.ledgerPosted!==false)
     throw Error('SECTION9_UNSAFE_BLOCKED_SLOT_SOURCE_RESULT');
    return {status:proof.status,slotCertificateIssued:false,
     flightActivated:false,bookingsCreated:false,ledgerPosted:false,
     reasons:Array.isArray(proof.blockers)?proof.blockers:[]};
   }
   checkedProof(proof,{airlineId,scheduleId,scheduleVersion,gameDate});
   const eventId=[
    'slot-clearance-v1',scheduleId.replaceAll('-',''),
    String(scheduleVersion),gameDate.replaceAll('-',''),
    proof.proofFingerprint.slice(0,12)
   ].join('.');
   const event={
    worldId:1,airlineId,scheduleId,scheduleVersion,
    clearanceType:'airport_slot_capacity',
    sourceKind:'verified_airport_slot_engine',
    action:'certify',eventId,
    sourceReference:proof.sourceReference,
    reviewerReference:proof.reviewerReference,
    validFromGameDate:gameDate,
    validToGameDate:proof.validThroughGameDate
   };
   event.signature=createHmac('sha256',secret)
    .update(section9CertificationPayload(event),'utf8').digest('hex');
   const result=await certificationIngress.acceptSignedDecision(
    Object.freeze({...event}));
   if(!result||!['certification_event_recorded',
     'certification_event_replayed'].includes(result.status)||
     result.scheduleId!==scheduleId||
     result.eventId!==eventId||
     result.flightActivated!==false||
     result.movementRecorded!==false||
     result.bookingsCreated!==false||
     result.ledgerPosted!==false)
    throw Error('SECTION9_SLOT_CERTIFICATE_NOT_CONFIRMED');
   return {status:result.status,
    slotCertificateIssued:result.status==='certification_event_recorded',
    replayed:result.status==='certification_event_replayed',
    scheduleId,sourceFingerprint:proof.proofFingerprint,
    flightActivated:false,bookingsCreated:false,ledgerPosted:false};
  }
 });
}
