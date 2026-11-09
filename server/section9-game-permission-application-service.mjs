/**
 * Server-only World 1 game permission applications and independent reviews.
 *
 * Browser identity is never trusted from JSON. A verified private identity
 * source provides player ownership; the DB also checks airline ownership.
 * A completely separate HMAC key authenticates review/issuance decisions.
 *
 * This module does not configure licence policies, launch the world, sign
 * reviewer decisions, expose HTTP endpoints or activate aircraft/flights.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';
const REAL_UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const EVENT=/^[A-Za-z0-9._:-]{16,128}$/;
const HASH=/^[a-f0-9]{64}$/;
const DAY_VALID=d=>typeof d==='string'&&DAY.test(d)&&
 Number.isFinite(Date.parse(d+'T00:00:00Z'))&&
 new Date(d+'T00:00:00Z').toISOString().slice(0,10)===d&&
 d>='2000-01-01'&&d<='2199-12-01';
const appFields=new Set([
 'airlineId','requestKey','permissionCode',
 'originAirportKey','destinationAirportKey','serviceType'
]);
const reviewFields=new Set([
 'worldId','applicationId','eventId','decision','gameDate',
 'reviewerReference','signature'
]);
const permissions=new Set([
 'AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC','INTEGRATED_MARKET',
 'THIRD_FOURTH_FREEDOM','FIFTH_FREEDOM','SEVENTH_FREEDOM','CABOTAGE'
]);
export const SECTION9_GAME_PERMISSION_SQL=Object.freeze({
 submit:'SELECT airlinerra_game.section9_submit_game_permission_application_v1('+
  '$1::uuid,$2::uuid,$3::uuid,$4::text,$5::text,$6::text,$7::text) AS result',
 list:'SELECT airlinerra_game.section9_owned_game_permission_applications_v1('+
  '$1::uuid,$2::uuid) AS result',
 decide:'SELECT airlinerra_game.section9_decide_game_permission_application_v1('+
  '$1::uuid,$2::text,$3::text,$4::text,$5::text,$6::date) AS result',
 expire:'SELECT airlinerra_game.section9_expire_game_permissions_batch_v1('+
  '$1::integer) AS result'
});
async function sqlOne(database,sql,args){
 const client=await database.connect();
 try{
  const result=await client.query(sql,args);
  if(result.rowCount!==1||!result.rows?.[0]||
    !Object.hasOwn(result.rows[0],'result'))
   throw Error('SECTION9_GAME_PERMISSION_DATABASE_RESPONSE_MISSING');
  return result.rows[0].result;
 }finally{client.release();}
}
function validRequest(request){
 if(!request||typeof request!=='object'||Array.isArray(request)||
  Object.keys(request).some(k=>!appFields.has(k))||
  !REAL_UUID.test(request.airlineId||'')||
  !REAL_UUID.test(request.requestKey||'')||
  !permissions.has(request.permissionCode))return false;
 if(request.permissionCode==='AIR_OPERATOR_CERTIFICATE')
  return request.originAirportKey===undefined&&
    request.destinationAirportKey===undefined&&
    request.serviceType===undefined;
 return typeof request.originAirportKey==='string'&&
  /^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/.test(request.originAirportKey)&&
  typeof request.destinationAirportKey==='string'&&
  /^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/.test(request.destinationAirportKey)&&
  request.originAirportKey!==request.destinationAirportKey&&
  ['passenger','cargo'].includes(request.serviceType);
}
function acceptedResult(result,request){
 if(!result||result.flightActivated!==false||result.ledgerPosted!==false||
   result.charged!==false||result.licenceIssued!==false)return false;
 if(result.status==='permission_application_submitted')
  return result.submitted===true&&REAL_UUID.test(result.applicationId||'')&&
   typeof result.feeAtIssuanceUsd==='number'&&result.feeAtIssuanceUsd>0&&
   DAY_VALID(result.dueGameDate);
 if(result.status==='permission_application_replayed')
  return REAL_UUID.test(result.applicationId||'')&&result.replayed===true&&
   typeof result.applicationStatus==='string';
 return [
  'blocked_unverified_world_or_game_day',
  'blocked_game_permission_issuance_disabled',
  'blocked_operator_licence_required',
  'blocked_game_permission_already_valid',
  'blocked_game_permission_application_pending'
 ].includes(result.status)&&result.submitted===false;
}
export function createSection9GamePermissionApplicationService({database,identityAuthority}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_GAME_PERMISSION_DATABASE_REQUIRED');
 if(typeof identityAuthority?.authorizeApplication!=='function'||
    typeof identityAuthority?.authorizeList!=='function')
  throw Error('SECTION9_VERIFIED_GAME_PLAYER_IDENTITY_REQUIRED');
 async function identity(kind,request){
  const result=await identityAuthority[kind](Object.freeze({...request}));
  if(result?.authorized!==true||
    result.source!=='verified_game_player_session'||
    !REAL_UUID.test(result.ownerPlayerId||'')||
    result.airlineId!==request.airlineId)
   throw Error('SECTION9_UNVERIFIED_PERMISSION_OWNER');
  return result.ownerPlayerId;
 }
 return Object.freeze({
  async submitApplication(request){
   if(!validRequest(request))throw Error('SECTION9_INVALID_PERMISSION_APPLICATION_REQUEST');
   const owner=await identity('authorizeApplication',request);
   const result=await sqlOne(database,SECTION9_GAME_PERMISSION_SQL.submit,[
    owner,request.airlineId,request.requestKey,request.permissionCode,
    request.originAirportKey??null,request.destinationAirportKey??null,
    request.serviceType??null
   ]);
   if(!acceptedResult(result,request))
    throw Error('SECTION9_UNSAFE_PERMISSION_SUBMISSION_RESULT');
   return result;
  },
  async listApplications({airlineId}={}){
   if(!REAL_UUID.test(airlineId||''))
    throw Error('SECTION9_INVALID_PERMISSION_LIST_REQUEST');
   const owner=await identity('authorizeList',{airlineId});
   const result=await sqlOne(database,SECTION9_GAME_PERMISSION_SQL.list,[owner,airlineId]);
   if(result?.worldId!==1||result.airlineId!==airlineId||
      result.readOnly!==true||!Array.isArray(result.applications)||
      result.applications.length>2000)
    throw Error('SECTION9_UNSAFE_PERMISSION_LIST_RESULT');
   return result;
  }
 });
}
export function section9PermissionReviewPayload(event){
 return [
  'airlinerra-game-permission-review-v1','1',String(event.worldId),
  event.applicationId,event.eventId,event.decision,event.gameDate,
  event.reviewerReference
 ].join('\n');
}
export function createSection9GamePermissionReviewIngress({
 database,independentReviewSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_GAME_PERMISSION_DATABASE_REQUIRED');
 if(typeof independentReviewSecret!=='string'||independentReviewSecret.length<32)
  throw Error('SECTION9_INDEPENDENT_GAME_PERMISSION_REVIEW_SECRET_REQUIRED');
 const secret=Buffer.from(independentReviewSecret,'utf8');
 return Object.freeze({
  async acceptSignedReview(event){
   if(!event||typeof event!=='object'||Array.isArray(event)||
    Object.keys(event).some(k=>!reviewFields.has(k))||
    reviewFields.size!==Object.keys(event).length||
    event.worldId!==1||!REAL_UUID.test(event.applicationId||'')||
    !EVENT.test(event.eventId||'')||
    !['approve','reject','revoke'].includes(event.decision)||
    !DAY_VALID(event.gameDate)||
    typeof event.reviewerReference!=='string'||
    event.reviewerReference.length<12||event.reviewerReference.length>160||
    !HASH.test(event.signature||''))
    throw Error('SECTION9_INVALID_SIGNED_GAME_PERMISSION_REVIEW');
   const expected=createHmac('sha256',secret)
    .update(section9PermissionReviewPayload(event),'utf8').digest();
   const supplied=Buffer.from(event.signature,'hex');
   if(supplied.length!==32||!timingSafeEqual(expected,supplied))
    throw Error('SECTION9_UNTRUSTED_GAME_PERMISSION_REVIEW_SIGNATURE');
   const result=await sqlOne(database,SECTION9_GAME_PERMISSION_SQL.decide,[
    event.applicationId,event.eventId,event.decision,
    event.reviewerReference,event.signature,event.gameDate
   ]);
   if(!result||result.applicationId!==event.applicationId||
    result.flightActivated!==false||result.chargedNow===undefined||
    result.licenceIssuedNow===undefined||
    result.ledgerPostedNow===undefined)return Promise.reject(
     Error('SECTION9_UNSAFE_GAME_PERMISSION_REVIEW_RESULT'));
   const state=result.status;
   if(state==='game_permission_decision_replayed')
    {if(result.replayed!==true||result.chargedNow!==false||
       result.ledgerPostedNow!==false||result.licenceIssuedNow!==false)
      throw Error('SECTION9_UNSAFE_GAME_PERMISSION_REPLAY');
     return result;}
   if(state==='game_permission_issued'){
    if(event.decision!=='approve'||result.chargedNow!==true||
      result.licenceIssuedNow!==true||result.ledgerPostedNow!==true||
      result.replayed!==false||
      result.applicationStatus!=='issued'||
      !DAY_VALID(result.validUntilGameDate)||
      !Number.isFinite(Number(result.feeChargedUsd))||
      Number(result.feeChargedUsd)<=0||
      !Number.isSafeInteger(Number(result.ledgerEntryId))||
      Number(result.ledgerEntryId)<=0||result.eventId!==event.eventId)
     throw Error('SECTION9_UNSAFE_GAME_PERMISSION_ISSUANCE_RESULT');
    return result;
   }
   if(state==='game_permission_rejected'||state==='game_permission_revoked'){
    if(event.decision!==(state==='game_permission_rejected'?'reject':'revoke')||
      result.chargedNow!==false||result.licenceIssuedNow!==false||
      result.ledgerPostedNow!==false||
      result.eventId!==event.eventId)
     throw Error('SECTION9_UNSAFE_GAME_PERMISSION_REVIEW_RESULT');
    return result;
   }
   if([
    'blocked_unverified_world_or_game_day',
    'blocked_application_not_due_or_processed',
    'blocked_application_not_issued',
    'blocked_permission_policy_changed_or_disabled',
    'blocked_game_traffic_rights_policy_changed',
    'blocked_operator_licence_expired_or_revoked',
    'blocked_permission_already_valid',
    'blocked_insufficient_airline_cash'
   ].includes(state)&&result.chargedNow===false&&
      result.licenceIssuedNow===false&&result.ledgerPostedNow===false)
    return result;
   throw Error('SECTION9_UNSAFE_GAME_PERMISSION_REVIEW_RESULT');
  }
 });
}
export function createSection9GamePermissionExpiryWorker({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_GAME_PERMISSION_DATABASE_REQUIRED');
 return Object.freeze({
  async expireBatch({limit=100}={}){
   if(!Number.isInteger(limit)||limit<1||limit>200)
    throw Error('SECTION9_INVALID_GAME_PERMISSION_EXPIRY_BUDGET');
   const result=await sqlOne(database,SECTION9_GAME_PERMISSION_SQL.expire,[limit]);
   if(!result||!['blocked_unverified_world_or_game_day',
      'game_permission_expiry_batch_completed'].includes(result.status)||
      result.ledgerPosted!==false||result.flightActivated!==false||
      !Number.isInteger(result.expired)||result.expired<0||
      result.expired>limit)
    throw Error('SECTION9_UNSAFE_GAME_PERMISSION_EXPIRY_RESULT');
   return result;
  }
 });
}
