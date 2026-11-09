/**
 * Private game-operator licence and route-rights verifier issuers.
 *
 * These DO NOT issue player licences, collect fees, approve applications,
 * or create legal traffic rights. They only issue one of six signed
 * operational-clearance events once a separate in-game grant exists,
 * its reference catalogue entry is enabled, and all DB checks pass.
 *
 * Each issuer is bound to ONE independent secret and its matching signed
 * certification ingress; do not mount as a player-facing HTTP endpoint.
 */
import {createHmac} from 'node:crypto';
import {section9CertificationPayload}
 from './section9-signed-certification-ingress.mjs';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const HASH=/^[a-f0-9]{32}$/;
const plus28=s=>new Date(Date.parse(s+'T00:00:00Z')+28*86400000)
 .toISOString().slice(0,10);
const validDay=s=>typeof s==='string'&&DAY.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-01';

const RULES=Object.freeze({
 operator_licence:Object.freeze({
  sql:'SELECT airlinerra_game.section9_verify_game_operator_licence_v1('+
   '$1::uuid,$2::uuid,$3::integer,$4::date) AS result',
  status:'verified_game_operator_licence',
  sourceKind:'verified_game_licence_engine',
  sourcePrefix:'game-operator-licence-v1-',
  reviewer:'independent-game-licence-authority-v1',
  eventPrefix:'game-licence-cert-v1',
  gameOnlyFlag:'gameLicenceOnly',
  blocked:Object.freeze([
   'blocked_unverified_world_or_game_day',
   'blocked_stale_or_non_draft_schedule',
   'blocked_game_operator_licence'
  ])
 }),
 route_traffic_rights:Object.freeze({
  sql:'SELECT airlinerra_game.section9_verify_game_route_traffic_rights_v1('+
   '$1::uuid,$2::uuid,$3::integer,$4::date) AS result',
  status:'verified_game_route_traffic_rights',
  sourceKind:'verified_game_traffic_rights_engine',
  sourcePrefix:'game-route-rights-v1-',
  reviewer:'independent-game-traffic-rights-v1',
  eventPrefix:'game-route-rights-cert-v1',
  gameOnlyFlag:'gameRightsOnly',
  blocked:Object.freeze([
   'blocked_stale_or_non_draft_schedule',
   'blocked_game_route_operator_not_licensed',
   'blocked_game_route_country_unknown',
   'blocked_game_route_traffic_rights'
  ])
 })
});

export const SECTION9_GAME_PERMISSION_AUTHORITY_SQL=Object.freeze({
 operator_licence:RULES.operator_licence.sql,
 route_traffic_rights:RULES.route_traffic_rights.sql
});
function validatePositive(result,request,type,config){
 if(!result||result.status!==config.status||
   result.verified!==true||result.readOnly!==true||
   result.worldId!==1||result.airlineId!==request.airlineId||
   result.scheduleId!==request.scheduleId||
   result.scheduleVersion!==request.scheduleVersion||
   result.gameDate!==request.gameDate||
   result.validThroughGameDate!==plus28(request.gameDate)||
   result.clearanceType!==type||result.sourceKind!==config.sourceKind||
   result.reviewerReference!==config.reviewer||
   result[config.gameOnlyFlag]!==true||
   !HASH.test(result.proofFingerprint||'')||
   result.sourceReference!==config.sourcePrefix+result.proofFingerprint||
   result.flightActivated!==false||result.movementRecorded!==false||
   result.bookingsCreated!==false||result.ledgerPosted!==false||
   (type==='operator_licence'&&!/^[A-Z]{2}$/.test(result.jurisdictionIso2||''))||
   (type==='route_traffic_rights'&&
    (!Array.isArray(result.requiredServiceTypes)||
     result.requiredServiceTypes.length<1||
     !Number.isInteger(result.verifiedServiceTypes)||
     result.verifiedServiceTypes!==result.requiredServiceTypes.length||
     result.requiredServiceTypes.some(role=>!['passenger','cargo'].includes(role))||
     new Set(result.requiredServiceTypes).size!==result.requiredServiceTypes.length)))
  throw Error('SECTION9_UNTRUSTED_GAME_PERMISSION_SOURCE_PROOF');
}
export function createSection9GamePermissionVerifierIssuer({
 database,clearanceType,verifierSecret,certificationIngress
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_GAME_PERMISSION_DATABASE_REQUIRED');
 if(!Object.hasOwn(RULES,clearanceType||''))
  throw Error('SECTION9_UNKNOWN_GAME_PERMISSION_AUTHORITY');
 if(typeof verifierSecret!=='string'||verifierSecret.length<32)
  throw Error('SECTION9_GAME_PERMISSION_SIGNING_SECRET_REQUIRED');
 if(certificationIngress?.clearanceType!==clearanceType||
    typeof certificationIngress?.acceptSignedDecision!=='function')
  throw Error('SECTION9_MATCHING_GAME_PERMISSION_INGRESS_REQUIRED');
 const config=RULES[clearanceType];
 const secret=Buffer.from(verifierSecret,'utf8');
 return Object.freeze({
  clearanceType,
  async verifyAndCertify({airlineId,scheduleId,scheduleVersion,gameDate}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
      !Number.isInteger(scheduleVersion)||scheduleVersion<1||
      !validDay(gameDate))
    throw Error('SECTION9_INVALID_GAME_PERMISSION_CERTIFICATION_REQUEST');
   const client=await database.connect();
   let proof;
   try{
    const r=await client.query(config.sql,[
     airlineId,scheduleId,scheduleVersion,gameDate
    ]);
    if(r.rowCount!==1||!r.rows?.[0]?.result)
     throw Error('SECTION9_GAME_PERMISSION_SOURCE_UNAVAILABLE');
    proof=r.rows[0].result;
   }finally{client.release();}
   if(config.blocked.includes(proof.status)){
    if(proof.verified!==false||proof.readOnly!==true||
      proof.flightActivated!==false||proof.movementRecorded!==false||
      proof.bookingsCreated!==false||proof.ledgerPosted!==false)
     throw Error('SECTION9_UNSAFE_BLOCKED_GAME_PERMISSION_RESULT');
    return {
     status:proof.status,clearanceType,
     certificateIssued:false,
     blockers:Array.isArray(proof.blockers)?proof.blockers:[],
     flightActivated:false,movementRecorded:false,
     bookingsCreated:false,ledgerPosted:false
    };
   }
   validatePositive(proof,{airlineId,scheduleId,scheduleVersion,gameDate},
    clearanceType,config);
   const eventId=[
    config.eventPrefix,scheduleId.replaceAll('-',''),String(scheduleVersion),
    gameDate.replaceAll('-',''),proof.proofFingerprint.slice(0,12)
   ].join('.');
   const event={
    worldId:1,airlineId,scheduleId,scheduleVersion,
    clearanceType,sourceKind:config.sourceKind,
    action:'certify',eventId,
    sourceReference:proof.sourceReference,
    reviewerReference:proof.reviewerReference,
    validFromGameDate:gameDate,
    validToGameDate:proof.validThroughGameDate
   };
   event.signature=createHmac('sha256',secret)
    .update(section9CertificationPayload(event),'utf8').digest('hex');
   const receipt=await certificationIngress.acceptSignedDecision(
    Object.freeze({...event}));
   if(!receipt||!['certification_event_recorded',
     'certification_event_replayed'].includes(receipt.status)||
     receipt.eventId!==eventId||receipt.scheduleId!==scheduleId||
     receipt.flightActivated!==false||receipt.movementRecorded!==false||
     receipt.bookingsCreated!==false||receipt.ledgerPosted!==false)
    throw Error('SECTION9_GAME_PERMISSION_CERTIFICATE_NOT_CONFIRMED');
   return {
    status:receipt.status,clearanceType,
    certificateIssued:receipt.status==='certification_event_recorded',
    replayed:receipt.status==='certification_event_replayed',
    scheduleId,sourceFingerprint:proof.proofFingerprint,
    flightActivated:false,movementRecorded:false,
    bookingsCreated:false,ledgerPosted:false
   };
  }
 });
}
