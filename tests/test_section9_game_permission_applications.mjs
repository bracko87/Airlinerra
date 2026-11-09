import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {
 createSection9GamePermissionApplicationService,
 createSection9GamePermissionReviewIngress,
 createSection9GamePermissionExpiryWorker,
 SECTION9_GAME_PERMISSION_SQL,section9PermissionReviewPayload
} from '../server/section9-game-permission-application-service.mjs';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const PLAYER='11111111-1111-4111-8111-111111111111';
const REQUEST='33333333-3333-4333-8333-333333333333';
const APP='44444444-4444-4444-8444-444444444444';
const SECRET='private-independent-game-licence-review-secret-for-tests';
const day='2000-11-09';
const operator={airlineId:AIRLINE,requestKey:REQUEST,
 permissionCode:'AIR_OPERATOR_CERTIFICATE'};
const route={...operator,permissionCode:'THIRD_FOURTH_FREEDOM',
 originAirportKey:'OURAIRPORTS:4610',
 destinationAirportKey:'OURAIRPORTS:2212',serviceType:'passenger'};
const event=(decision='approve')=>({
 worldId:1,applicationId:APP,eventId:'licence-review-verified-event-001',
 decision,gameDate:day,reviewerReference:'independent-game-review-00001'
});
const signed=e=>({...e,signature:createHmac('sha256',SECRET)
 .update(section9PermissionReviewPayload(e),'utf8').digest('hex')});
const blockedRequest={
 status:'blocked_game_permission_issuance_disabled',submitted:false,
 charged:false,licenceIssued:false,flightActivated:false,ledgerPosted:false
};
const approved=e=>({
 status:'game_permission_issued',applicationId:e.applicationId,
 eventId:e.eventId,applicationStatus:'issued',
 validUntilGameDate:'2001-11-09',feeChargedUsd:250,ledgerEntryId:10,
 replayed:false,chargedNow:true,licenceIssuedNow:true,
 flightActivated:false,ledgerPostedNow:true,
 bookingsCreated:false,movementRecorded:false
});
function db(reply){
 let connections=0,releases=0;const queries=[];
 return {
  database:{async connect(){connections++;return{
   async query(sql,args){
    queries.push({sql,args});
    if(reply instanceof Error)throw reply;
    const value=typeof reply==='function'?reply(sql,args):reply;
    return {rowCount:1,rows:[{result:value}]};
   },release(){releases++}
  };}},
  queries,counts:()=>({connections,releases})
 };
}
const auth={
 async authorizeApplication(request){return {
  authorized:true,source:'verified_game_player_session',
  ownerPlayerId:PLAYER,airlineId:request.airlineId
 }},
 async authorizeList(request){return{
  authorized:true,source:'verified_game_player_session',
  ownerPlayerId:PLAYER,airlineId:request.airlineId
 }}
};
test('private application service requires database and trusted verified identity',()=>{
 assert.throws(()=>createSection9GamePermissionApplicationService(),
  /PRIVATE_GAME_PERMISSION_DATABASE_REQUIRED/);
 assert.throws(()=>createSection9GamePermissionApplicationService({
  database:{connect(){}}
 }),/VERIFIED_GAME_PLAYER_IDENTITY_REQUIRED/);
 assert.throws(()=>createSection9GamePermissionReviewIngress({
  database:{connect(){}},independentReviewSecret:'short'
 }),/INDEPENDENT_GAME_PERMISSION_REVIEW_SECRET_REQUIRED/);
});
test('no game catalogue release: application blocked without charging airline',async()=>{
 const d=db(blockedRequest);
 const service=createSection9GamePermissionApplicationService({
  database:d.database,identityAuthority:auth});
 const r=await service.submitApplication(operator);
 assert.equal(r.status,'blocked_game_permission_issuance_disabled');
 assert.equal(r.charged,false);
 assert.equal(d.queries[0].sql,SECTION9_GAME_PERMISSION_SQL.submit);
 assert.deepEqual(d.queries[0].args,[
  PLAYER,AIRLINE,REQUEST,'AIR_OPERATOR_CERTIFICATE',null,null,null
 ]);
 assert.deepEqual(d.counts(),{connections:1,releases:1});
});
test('successful submission stores an application but does not charge or issue',async()=>{
 const submitted={
  status:'permission_application_submitted',applicationId:APP,
  dueGameDate:'2000-11-12',feeAtIssuanceUsd:250,
  submitted:true,charged:false,licenceIssued:false,
  flightActivated:false,ledgerPosted:false
 };
 const d=db(submitted);
 const service=createSection9GamePermissionApplicationService({
  database:d.database,identityAuthority:auth});
 assert.deepEqual(await service.submitApplication(route),submitted);
 assert.deepEqual(d.queries[0].args,[
  PLAYER,AIRLINE,REQUEST,'THIRD_FOURTH_FREEDOM',
  'OURAIRPORTS:4610','OURAIRPORTS:2212','passenger'
 ]);
});
test('duplicated request is reported as replay rather than new payment',async()=>{
 const d=db({status:'permission_application_replayed',applicationId:APP,
  applicationStatus:'submitted',replayed:true,charged:false,
  licenceIssued:false,flightActivated:false,ledgerPosted:false});
 const s=createSection9GamePermissionApplicationService({
  database:d.database,identityAuthority:auth});
 const r=await s.submitApplication(operator);
 assert.equal(r.replayed,true);
 assert.equal(r.charged,false);
});
test('user-controlled owner ID never reaches PostgreSQL; spoofed identity refused',async()=>{
 const d=db(blockedRequest);
 const service=createSection9GamePermissionApplicationService({
  database:d.database,identityAuthority:{
   async authorizeApplication(r){
    return {...await auth.authorizeApplication(r),source:'player-supplied'};
   },authorizeList:auth.authorizeList
  }});
 await assert.rejects(service.submitApplication({
  ...operator,ownerPlayerId:'55555555-5555-4555-8555-555555555555'
 }),/INVALID_PERMISSION_APPLICATION_REQUEST/);
 await assert.rejects(service.submitApplication(operator),
  /SECTION9_UNVERIFIED_PERMISSION_OWNER/);
 assert.equal(d.queries.length,0);
});
test('invalid scope, unsupported code and malformed applicant request are rejected',async()=>{
 const d=db(blockedRequest);
 const s=createSection9GamePermissionApplicationService({
  database:d.database,identityAuthority:auth});
 for(const bad of [
  {...operator,airlineId:'invalid'},
  {...operator,requestKey:'invalid'},
  {...operator,permissionCode:'EXTREMELY_PRIVILEGED_ADMIN'},
  {...operator,serviceType:'cargo'},
  {...route,serviceType:'vip'},
  {...route,destinationAirportKey:route.originAirportKey},
  {...route,originAirportKey:'MISSING'}
 ]){
  await assert.rejects(s.submitApplication(bad),/INVALID_PERMISSION_APPLICATION_REQUEST/);
 }
 assert.equal(d.queries.length,0);
});
test('owned application list only uses trusted owner and private DB',async()=>{
 const result={worldId:1,airlineId:AIRLINE,readOnly:true,
  applications:[{applicationId:APP,permissionCode:'AIR_OPERATOR_CERTIFICATE',
   status:'submitted',feeCharged:false}]};
 const d=db(result);
 const s=createSection9GamePermissionApplicationService({
  database:d.database,identityAuthority:auth});
 assert.deepEqual(await s.listApplications({airlineId:AIRLINE}),result);
 assert.equal(d.queries[0].sql,SECTION9_GAME_PERMISSION_SQL.list);
 assert.deepEqual(d.queries[0].args,[PLAYER,AIRLINE]);
});
test('review HMAC accepts correctly signed approval and checks ledger receipt',async()=>{
 const e=signed(event('approve'));const d=db(approved(e));
 const ingress=createSection9GamePermissionReviewIngress({
  database:d.database,independentReviewSecret:SECRET});
 const r=await ingress.acceptSignedReview(e);
 assert.equal(r.status,'game_permission_issued');
 assert.equal(r.chargedNow,true);
 assert.equal(r.ledgerPostedNow,true);
 assert.deepEqual(d.queries[0],{
  sql:SECTION9_GAME_PERMISSION_SQL.decide,
  args:[APP,e.eventId,'approve',e.reviewerReference,e.signature,day]
 });
 assert.deepEqual(d.counts(),{connections:1,releases:1});
});
test('rejection never charges and never issues any license',async()=>{
 const e=signed(event('reject'));
 const result={status:'game_permission_rejected',applicationId:APP,
  eventId:e.eventId,applicationStatus:'rejected',replayed:false,
  chargedNow:false,licenceIssuedNow:false,flightActivated:false,
  ledgerPostedNow:false,bookingsCreated:false,movementRecorded:false};
 const d=db(result);
 const ingress=createSection9GamePermissionReviewIngress({
  database:d.database,independentReviewSecret:SECRET});
 assert.equal((await ingress.acceptSignedReview(e)).status,'game_permission_rejected');
});
test('revocation removes licence entitlement without returning an issuance fee',async()=>{
 const e=signed(event('revoke'));
 const d=db({status:'game_permission_revoked',applicationId:APP,
  eventId:e.eventId,applicationStatus:'revoked',
  chargedNow:false,licenceIssuedNow:false,flightActivated:false,
  ledgerPostedNow:false});
 const s=createSection9GamePermissionReviewIngress({
  database:d.database,independentReviewSecret:SECRET});
 assert.equal((await s.acceptSignedReview(e)).status,'game_permission_revoked');
});
test('event replay is a no-op even if the existing application was issued',async()=>{
 const e=signed(event());
 const d=db({status:'game_permission_decision_replayed',
  applicationId:APP,eventId:e.eventId,replayed:true,
  applicationStatus:'issued',chargedNow:false,
  licenceIssuedNow:false,flightActivated:false,ledgerPostedNow:false});
 const s=createSection9GamePermissionReviewIngress({
  database:d.database,independentReviewSecret:SECRET});
 const r=await s.acceptSignedReview(e);
 assert.equal(r.replayed,true);
 assert.equal(r.ledgerPostedNow,false);
});
test('review rejects tampering, forged signature and invalid date before query',async()=>{
 const e=signed(event());
 const d=db(approved(e));
 const s=createSection9GamePermissionReviewIngress({
  database:d.database,independentReviewSecret:SECRET});
 for(const bad of [
  {...e,decision:'reject'},
  {...e,gameDate:'2000-11-10'},
  {...e,reviewerReference:'fake-uncertified-reviewer'},
  {...e,applicationId:'66666666-6666-4666-8666-666666666666'},
  {...e,worldId:2},
  {...e,signature:'0'.repeat(64)},
  {...e,signature:'bad'},
  {...e,gameDate:'2000-02-30'},
  {...e,isPlayerReview:true}
 ]){
  await assert.rejects(s.acceptSignedReview(bad),
   /INVALID_SIGNED_GAME_PERMISSION_REVIEW|UNTRUSTED_GAME_PERMISSION_REVIEW_SIGNATURE/);
 }
 assert.equal(d.queries.length,0);
});
test('review rejects approval if database claims money but fails actual issue',async()=>{
 const e=signed(event());
 for(const incorrect of [
  {...approved(e),ledgerPostedNow:false},
  {...approved(e),licenceIssuedNow:false},
  {...approved(e),chargedNow:false},
  {...approved(e),ledgerEntryId:null},
  {...approved(e),feeChargedUsd:0},
  {...approved(e),applicationId:'77777777-7777-4777-8777-777777777777'},
  {...approved(e),flightActivated:true},
  {...approved(e),eventId:'wrong-event'}
 ]){
  const d=db(incorrect);
  const s=createSection9GamePermissionReviewIngress({
   database:d.database,independentReviewSecret:SECRET});
  await assert.rejects(s.acceptSignedReview(e),
   /UNSAFE_GAME_PERMISSION_(ISSUANCE|REVIEW)_RESULT/);
  assert.equal(d.counts().releases,1);
 }
});
test('a denied approval cannot be reported as money spent',async()=>{
 const e=signed(event());
 const d=db({
  status:'blocked_permission_policy_changed_or_disabled',
  applicationId:APP,chargedNow:false,licenceIssuedNow:false,
  ledgerPostedNow:false,flightActivated:false
 });
 const s=createSection9GamePermissionReviewIngress({
  database:d.database,independentReviewSecret:SECRET});
 const r=await s.acceptSignedReview(e);
 assert.equal(r.status,'blocked_permission_policy_changed_or_disabled');
});
test('expiry worker is bounded and never manipulates money',async()=>{
 const d=db({status:'game_permission_expiry_batch_completed',
  expired:4,ledgerPosted:false,flightActivated:false});
 const w=createSection9GamePermissionExpiryWorker({database:d.database});
 const r=await w.expireBatch({limit:10});
 assert.equal(r.expired,4);
 assert.deepEqual(d.queries[0].args,[10]);
 await assert.rejects(w.expireBatch({limit:300}),/INVALID_GAME_PERMISSION_EXPIRY_BUDGET/);
});
test('private permission lifecycle preserves hard disabled catalog and draft constraints',async()=>{
 const init=await readFile(new URL(
  '../supabase/migrations/20261109202500_section9_game_permission_application_foundation.sql',
  import.meta.url),'utf8');
 const settle=await readFile(new URL(
  '../supabase/migrations/20261109203000_section9_game_permission_settlement_and_expiry.sql',
  import.meta.url),'utf8');
 const proof=await readFile(new URL(
  '../supabase/migrations/20261109203500_section9_game_permission_evidence_provenance.sql',
  import.meta.url),'utf8');
 assert.match(init,/section9_one_pending_game_permission_scope_idx/);
 assert.match(init,/business_permission_catalog_v1/);
 assert.match(settle,/airline_ledger/);
 assert.match(settle,/FOR UPDATE/);
 assert.match(settle,/game_permission_decision_replayed/);
 assert.match(proof,/issued_application_id/);
 for(const text of [init,settle,proof])
  assert.doesNotMatch(text,/DROP CONSTRAINT|UPDATE airlinerra_game\.business_permission_catalog_v1|UPDATE airlinerra_game\.airline_flight_schedule_drafts_v1/);
});
