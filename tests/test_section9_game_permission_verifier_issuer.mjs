import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {
 createSection9GamePermissionVerifierIssuer,
 SECTION9_GAME_PERMISSION_AUTHORITY_SQL
} from '../server/section9-game-permission-verifier-issuer.mjs';
import {section9CertificationPayload}
 from '../server/section9-signed-certification-ingress.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const SECRET1='private-operator-licence-signing-secret-00000001';
const SECRET2='private-route-traffic-rights-signing-secret-0002';
const DATE='2000-11-09';
const request=()=>({airlineId:AIRLINE,scheduleId:SCHEDULE,
 scheduleVersion:3,gameDate:DATE});
const config={
 operator_licence:{
  status:'verified_game_operator_licence',
  sourceKind:'verified_game_licence_engine',
  sourceReference:'game-operator-licence-v1-'+'a'.repeat(32),
  proofFingerprint:'a'.repeat(32),
  reviewerReference:'independent-game-licence-authority-v1',
  gameLicenceOnly:true,jurisdictionIso2:'RS'
 },
 route_traffic_rights:{
  status:'verified_game_route_traffic_rights',
  sourceKind:'verified_game_traffic_rights_engine',
  sourceReference:'game-route-rights-v1-'+'b'.repeat(32),
  proofFingerprint:'b'.repeat(32),
  reviewerReference:'independent-game-traffic-rights-v1',
  gameRightsOnly:true,
  requiredServiceTypes:['passenger','cargo'],
  verifiedServiceTypes:2
 }
};
const proof=(type='operator_licence')=>({
 worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,scheduleVersion:3,
 gameDate:DATE,validThroughGameDate:'2000-12-07',
 clearanceType:type,readOnly:true,verified:true,
 flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false,
 ...config[type]
});
const blocked=(status='blocked_game_operator_licence')=>({
 status,worldId:1,verified:false,readOnly:true,
 flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false,
 blockers:['GAME_OPERATOR_LICENCE_ISSUANCE_DISABLED']
});
const receipt=(event)=>({
 status:'certification_event_recorded',
 scheduleId:event.scheduleId,eventId:event.eventId,
 flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false
});
function make(type,{
 evidence=proof(type),secret=type==='operator_licence'?SECRET1:SECRET2,
 expectedSecret=secret,overrideResponse=null,dbFailure=false
}={}){
 const signed=[],queries=[];let connects=0,releases=0;
 const database={async connect(){
  connects++;return{
   async query(sql,args){
    queries.push({sql,args});
    if(dbFailure)throw Error('INTERNAL_DATABASE_UNAVAILABLE');
    return {rowCount:1,rows:[{result:evidence}]};
   },release(){releases++}
  };
 }};
 const certificationIngress={
  clearanceType:type,
  async acceptSignedDecision(event){
   const expected=createHmac('sha256',expectedSecret)
    .update(section9CertificationPayload(event),'utf8').digest('hex');
   assert.equal(event.signature,expected);
   signed.push(event);
   return overrideResponse??receipt(event);
  }
 };
 const issuer=createSection9GamePermissionVerifierIssuer({
  database,clearanceType:type,verifierSecret:secret,certificationIngress
 });
 return {issuer,signed,queries,counters:()=>({connects,releases})};
}
test('only exact independent game-licence or route-rights issuer can be constructed',()=>{
 assert.throws(()=>createSection9GamePermissionVerifierIssuer(),
  /PRIVATE_GAME_PERMISSION_DATABASE_REQUIRED/);
 assert.throws(()=>createSection9GamePermissionVerifierIssuer({
  database:{connect(){}},clearanceType:'commercial_finance'
 }),/UNKNOWN_GAME_PERMISSION_AUTHORITY/);
 assert.throws(()=>createSection9GamePermissionVerifierIssuer({
  database:{connect(){}},clearanceType:'operator_licence',
  verifierSecret:'short'
 }),/GAME_PERMISSION_SIGNING_SECRET_REQUIRED/);
 assert.throws(()=>createSection9GamePermissionVerifierIssuer({
  database:{connect(){}},clearanceType:'operator_licence',
  verifierSecret:SECRET1,
  certificationIngress:{clearanceType:'route_traffic_rights',
   acceptSignedDecision(){}}
 }),/MATCHING_GAME_PERMISSION_INGRESS_REQUIRED/);
});
test('a globally disabled licence returns blockers without signing',async()=>{
 const m=make('operator_licence',{evidence:blocked()});
 const result=await m.issuer.verifyAndCertify(request());
 assert.equal(result.certificateIssued,false);
 assert.equal(result.status,'blocked_game_operator_licence');
 assert.deepEqual(result.blockers,['GAME_OPERATOR_LICENCE_ISSUANCE_DISABLED']);
 assert.equal(m.signed.length,0);
 assert.deepEqual(m.queries,[{
  sql:SECTION9_GAME_PERMISSION_AUTHORITY_SQL.operator_licence,
  args:[AIRLINE,SCHEDULE,3,DATE]
 }]);
 assert.deepEqual(m.counters(),{connects:1,releases:1});
});
test('a route grant is refused if operator game licence has not been issued',async()=>{
 const m=make('route_traffic_rights',{evidence:
  blocked('blocked_game_route_operator_not_licensed')});
 const r=await m.issuer.verifyAndCertify(request());
 assert.equal(r.certificateIssued,false);
 assert.equal(m.signed.length,0);
});
test('both independent issuers sign only their exact verified source and 28-day horizon',async()=>{
 for(const type of ['operator_licence','route_traffic_rights']){
  const m=make(type);
  const r=await m.issuer.verifyAndCertify(request());
  assert.equal(r.status,'certification_event_recorded');
  assert.equal(r.certificateIssued,true);
  assert.equal(r.flightActivated,false);
  assert.equal(r.ledgerPosted,false);
  assert.equal(m.signed.length,1);
  assert.equal(m.signed[0].clearanceType,type);
  assert.equal(m.signed[0].sourceKind,config[type].sourceKind);
  assert.equal(m.signed[0].validFromGameDate,DATE);
  assert.equal(m.signed[0].validToGameDate,'2000-12-07');
  assert.equal(m.signed[0].action,'certify');
  assert.equal(m.signed[0].sourceReference,config[type].sourceReference);
  assert.equal(m.signed[0].scheduleVersion,3);
  assert.equal(m.counters().releases,1);
 }
});
test('operator and route authorities use different secrets',async()=>{
 const m=make('route_traffic_rights',{
  secret:SECRET2,expectedSecret:SECRET1
 });
 await assert.rejects(m.issuer.verifyAndCertify(request()));
 assert.equal(m.signed.length,0);
});
test('a verified route needs all passenger and cargo service types, not just one',async()=>{
 for(const bad of [
  {...proof('route_traffic_rights'),verifiedServiceTypes:1},
  {...proof('route_traffic_rights'),requiredServiceTypes:[]},
  {...proof('route_traffic_rights'),requiredServiceTypes:['passenger','passenger']},
  {...proof('route_traffic_rights'),requiredServiceTypes:['private']},
  {...proof('route_traffic_rights'),gameRightsOnly:false}
 ]){
  const m=make('route_traffic_rights',{evidence:bad});
  await assert.rejects(m.issuer.verifyAndCertify(request()),
   /UNTRUSTED_GAME_PERMISSION_SOURCE_PROOF/);
  assert.equal(m.signed.length,0);
 }
});
test('wrong source version, date, airline or fingerprint fails before signature',async()=>{
 const type='operator_licence';
 for(const bad of [
  {...proof(type),verified:false},
  {...proof(type),sourceReference:'manually-approved'},
  {...proof(type),proofFingerprint:'x'.repeat(32)},
  {...proof(type),scheduleId:'11111111-1111-4111-8111-111111111111'},
  {...proof(type),airlineId:'11111111-1111-4111-8111-111111111111'},
  {...proof(type),scheduleVersion:4},
  {...proof(type),gameDate:'2000-11-10'},
  {...proof(type),validThroughGameDate:'2000-12-08'},
  {...proof(type),reviewerReference:'untrusted-reviewer'},
  {...proof(type),gameLicenceOnly:false},
  {...proof(type),jurisdictionIso2:'FAKE'},
  {...proof(type),flightActivated:true},
  {...proof(type),ledgerPosted:true},
  {...proof(type),readOnly:false}
 ]){
  const m=make(type,{evidence:bad});
  await assert.rejects(m.issuer.verifyAndCertify(request()),
   /UNTRUSTED_GAME_PERMISSION_SOURCE_PROOF/);
  assert.equal(m.signed.length,0);
  assert.equal(m.counters().releases,1);
 }
});
test('malformed request is rejected without opening a DB connection',async()=>{
 const m=make('operator_licence');
 for(const bad of [
  {...request(),airlineId:'invalid'},
  {...request(),scheduleId:'invalid'},
  {...request(),scheduleVersion:0},
  {...request(),gameDate:'2000-02-30'},
  {...request(),gameDate:'2200-01-01'}
 ]){
  await assert.rejects(m.issuer.verifyAndCertify(bad),
   /INVALID_GAME_PERMISSION_CERTIFICATION_REQUEST/);
 }
 assert.deepEqual(m.counters(),{connects:0,releases:0});
});
test('replay outcome is not treated as a fresh game grant',async()=>{
 let e;
 const m=make('operator_licence',{
  overrideResponse:{
   status:'certification_event_replayed',
   get eventId(){return e?.eventId},scheduleId:SCHEDULE,
   flightActivated:false,movementRecorded:false,
   bookingsCreated:false,ledgerPosted:false
  }
 });
 // Use a deterministic ID derived from known proof/request.
 e={eventId:['game-licence-cert-v1',SCHEDULE.replaceAll('-',''),
 '3','20001109','a'.repeat(12)].join('.')};
 const r=await m.issuer.verifyAndCertify(request());
 assert.equal(r.certificateIssued,false);
 assert.equal(r.replayed,true);
});
test('malicious or failed cert sink cannot be reported as a successful issue',async()=>{
 const m=make('operator_licence',{
  overrideResponse:{status:'certification_event_recorded',
   scheduleId:SCHEDULE,eventId:'wrong-event-id',
   flightActivated:true,bookingsCreated:false,
   movementRecorded:false,ledgerPosted:true}
 });
 await assert.rejects(m.issuer.verifyAndCertify(request()),
  /GAME_PERMISSION_CERTIFICATE_NOT_CONFIRMED/);
});
test('DB failure releases private connection and does not issue a grant',async()=>{
 const m=make('operator_licence',{dbFailure:true});
 await assert.rejects(m.issuer.verifyAndCertify(request()),
  /INTERNAL_DATABASE_UNAVAILABLE/);
 assert.equal(m.signed.length,0);
 assert.deepEqual(m.counters(),{connects:1,releases:1});
});
test('source and fresh certification SQL are private and cannot self-activate',async()=>{
 const source=await readFile(new URL(
  '../supabase/migrations/20261109195000_section9_game_licence_traffic_rights_sources.sql',
  import.meta.url),'utf8');
 const sink=await readFile(new URL(
  '../supabase/migrations/20261109195500_section9_game_licence_certification_freshness.sql',
  import.meta.url),'utf8');
 const prepare=await readFile(new URL(
  '../supabase/migrations/20261109200000_section9_activation_game_permissions_recheck.sql',
  import.meta.url),'utf8');
 assert.match(source,/GAME_OPERATOR_LICENCE_ISSUANCE_DISABLED/);
 assert.match(source,/GAME_RIGHTS_GRANTS_DISABLED/);
 assert.match(source,/section9_verified_game_tick_receipts_v1/);
 assert.match(source,/REVOKE ALL ON FUNCTION/);
 assert.match(sink,/fresh_operator_proof/);
 assert.match(sink,/fresh_route_proof/);
 assert.match(prepare,/OPERATOR_GAME_LICENCE_SIGNED_PROOF_STALE/);
 assert.match(prepare,/ROUTE_GAME_RIGHTS_SIGNED_PROOF_STALE/);
 assert.doesNotMatch(source,/DROP CONSTRAINT|ALTER TABLE.*enabled_in_game|UPDATE airlinerra_game\.airline_flight_schedule_drafts_v1/);
});
