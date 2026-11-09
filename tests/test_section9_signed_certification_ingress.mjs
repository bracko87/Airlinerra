import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {
 createSection9SignedCertificationIngress,SECTION9_CERTIFICATION_SQL,
 SECTION9_CLEARANCE_SOURCES,section9CertificationPayload
} from '../server/section9-signed-certification-ingress.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const SECRET='independent-private-game-verifier-key-00001-for-only-one-source';
const OTHER_SECRET='another-independent-private-game-source-key-00000002';
const base=(type='crew_duty',action='certify')=>({
 worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,scheduleVersion:3,
 clearanceType:type,sourceKind:SECTION9_CLEARANCE_SOURCES[type],
 action,eventId:'trusted-source-event-00000000001',
 sourceReference:'verified-source-reference-00001',
 reviewerReference:'independent-reviewer-000001',
 validFromGameDate:'2000-11-09',validToGameDate:'2000-12-10'
});
const sign=(e,secret=SECRET)=>{
 const item={...e};
 item.signature=createHmac('sha256',secret)
  .update(section9CertificationPayload(item),'utf8').digest('hex');
 return item;
};
function build({clearanceType='crew_duty',secret=SECRET,
 response,throwOnQuery=false}={}){
 let connections=0,releases=0;
 const calls=[];
 const database={async connect(){
  connections++;
  return {release(){releases++},async query(sql,args){
   calls.push({sql,args});
   if(throwOnQuery)throw Error('PRIVATE_DB_ERROR');
   return {rowCount:1,rows:[{result:response}]};
  }};
 }};
 const ingress=createSection9SignedCertificationIngress({
  database,clearanceType,verifierSecret:secret
 });
 return {ingress,calls,counters:()=>({connections,releases})};
}
const accepted=e=>({
 status:e.action==='certify'?'certification_event_recorded':'certification_revoked',
 eventId:e.eventId,scheduleId:SCHEDULE,scheduleVersion:3,
 clearanceType:e.clearanceType,
 reviewStatus:e.action==='certify'?'certified':'revoked',
 certificateChanged:true,replayed:false,
 activationPreparationInvalidated:true,
 flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false
});
const replay=e=>({
 status:'certification_event_replayed',
 eventId:e.eventId,scheduleId:SCHEDULE,replayed:true,
 certificateChanged:false,flightActivated:false,
 movementRecorded:false,bookingsCreated:false,ledgerPosted:false
});

test('must bind a distinct server-only verifier type and secret',()=>{
 assert.throws(()=>createSection9SignedCertificationIngress({}),
  /PRIVATE_CERTIFICATION_DATABASE_REQUIRED/);
 assert.throws(()=>createSection9SignedCertificationIngress({
  database:{connect:async()=>{}},clearanceType:'invalid',verifierSecret:SECRET
 }),/UNKNOWN_CERTIFICATION_AUTHORITY/);
 assert.throws(()=>createSection9SignedCertificationIngress({
  database:{connect:async()=>{}},clearanceType:'crew_duty',verifierSecret:'short'
 }),/INDEPENDENT_CERTIFICATION_SECRET_REQUIRED/);
 assert.deepEqual(Object.keys(SECTION9_CLEARANCE_SOURCES).sort(),[
  'airport_slot_capacity','commercial_finance','crew_duty',
  'operator_licence','route_traffic_rights','trusted_flight_execution'
 ]);
});
test('each of six verifier types has its own authenticated payload and database mapping',async()=>{
 for(const type of Object.keys(SECTION9_CLEARANCE_SOURCES)){
  const event=sign(base(type));
  const m=build({clearanceType:type,response:accepted(event)});
  assert.deepEqual(await m.ingress.acceptSignedDecision(event),accepted(event));
  assert.equal(m.calls.length,1);
  assert.equal(m.calls[0].sql,SECTION9_CERTIFICATION_SQL.ingest);
  assert.deepEqual(m.calls[0].args,[
   AIRLINE,SCHEDULE,3,type,'certify',event.eventId,
   event.sourceReference,event.reviewerReference,
   event.validFromGameDate,event.validToGameDate,event.signature
  ]);
  assert.deepEqual(m.counters(),{connections:1,releases:1});
 }
});
test('signed revocation uses identical per-source verification and never activates',async()=>{
 const event=sign({...base('route_traffic_rights','revoke'),
  eventId:'trusted-source-revocation-00000000001'});
 const m=build({clearanceType:'route_traffic_rights',
  response:accepted(event)});
 const result=await m.ingress.acceptSignedDecision(event);
 assert.equal(result.status,'certification_revoked');
 assert.equal(result.activationPreparationInvalidated,true);
 assert.equal(result.flightActivated,false);
 assert.equal(result.ledgerPosted,false);
});
test('cross-service signatures, tampering, event fields, and expired intervals are refused before DB',async()=>{
 const event=sign(base());
 const m=build({response:accepted(event)});
 const otherType='operator_licence';
 const bad=[
  sign({...base(otherType)}),
  {...event,sourceKind:SECTION9_CLEARANCE_SOURCES[otherType]},
  {...event,action:'revoke'},
  {...event,scheduleVersion:4},
  {...event,airlineId:'11111111-1111-4111-8111-111111111111'},
  {...event,sourceReference:'tampered-source-reference-0001'},
  {...event,validToGameDate:'2000-12-11'},
  {...event,worldId:2},
  {...event,signature:'0'.repeat(64)},
  {...event,signature:'bad'},
  {...event,eventId:'short'},
  {...event,validFromGameDate:'2000-02-30'},
  sign({...base(),validToGameDate:'2002-01-01'}),
  sign({...base(),validToGameDate:'2000-11-01'}),
  {...event,grantApprovedByBrowser:true}
 ];
 for(const candidate of bad){
  await assert.rejects(m.ingress.acceptSignedDecision(candidate),
   /SECTION9_INVALID_SIGNED_CERTIFICATION|SECTION9_UNTRUSTED_CERTIFICATION_SIGNATURE/);
 }
 assert.deepEqual(m.counters(),{connections:0,releases:0});
 assert.equal(m.calls.length,0);
});
test('a different verifier signing secret cannot issue the same certificate',async()=>{
 const event=sign(base(),OTHER_SECRET);
 const m=build({response:accepted(event)});
 await assert.rejects(m.ingress.acceptSignedDecision(event),
  /UNTRUSTED_CERTIFICATION_SIGNATURE/);
 assert.equal(m.calls.length,0);
});
test('identical authenticated event replay is treated as no-op, not reissued',async()=>{
 const e=sign(base());
 const m=build({response:replay(e)});
 const result=await m.ingress.acceptSignedDecision(e);
 assert.equal(result.status,'certification_event_replayed');
 assert.equal(result.certificateChanged,false);
 assert.equal(result.replayed,true);
});
test('fail-closed if database pretends to activate flights or modify money',async()=>{
 const e=sign(base());
 for(const unsafe of [
  {...accepted(e),flightActivated:true},
  {...accepted(e),movementRecorded:true},
  {...accepted(e),ledgerPosted:true},
  {...accepted(e),bookingsCreated:true},
  {...accepted(e),reviewStatus:'revoked'},
  {...accepted(e),scheduleId:'11111111-1111-4111-8111-111111111111'},
  {...accepted(e),activationPreparationInvalidated:false},
  {...accepted(e),status:'schedule_activated'},
  {...replay(e),certificateChanged:true},
  null
 ]){
  const m=build({response:unsafe});
  await assert.rejects(m.ingress.acceptSignedDecision(e),
   /UNSAFE_CERTIFICATION_DB_RESPONSE/);
  assert.deepEqual(m.counters(),{connections:1,releases:1});
 }
});
test('DB errors release connections; never invent a successful certification',async()=>{
 const e=sign(base());
 const m=build({response:accepted(e),throwOnQuery:true});
 await assert.rejects(m.ingress.acceptSignedDecision(e),/PRIVATE_DB_ERROR/);
 assert.deepEqual(m.counters(),{connections:1,releases:1});
});
test('private SQL proof requires append-only signed events and does not activate schedules',async()=>{
 const sql=await readFile(new URL(
  '../supabase/migrations/20261109190500_section9_signed_certification_events.sql',
  import.meta.url),'utf8');
 const gate=await readFile(new URL(
  '../supabase/migrations/20261109191000_section9_activation_requires_signed_proof.sql',
  import.meta.url),'utf8');
 const ingress=await readFile(new URL(
  '../server/section9-signed-certification-ingress.mjs',
  import.meta.url),'utf8');
 assert.match(sql,/last_verified_event_id/);
 assert.match(sql,/section9_certification_event_immutable/);
 assert.match(sql,/activationPreparationInvalidated/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(gate,/e\.event_id=c\.last_verified_event_id/);
 assert.match(gate,/e\.action='certify'/);
 assert.doesNotMatch(sql,/DROP CONSTRAINT|UPDATE airlinerra_game\.airline_flight_schedule_drafts_v1 SET status/);
 assert.doesNotMatch(ingress,/createServer\(|fetch\(/);
});
