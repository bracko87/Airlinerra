import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {
 createSection9GameSlotClearanceIssuer,SECTION9_SLOT_AUTHORITY_SQL
} from '../server/section9-game-slot-clearance-issuer.mjs';
import {section9CertificationPayload}
 from '../server/section9-signed-certification-ingress.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const SECRET='private-game-slot-evidence-verifier-key-000000001';
const request={airlineId:AIRLINE,scheduleId:SCHEDULE,
 scheduleVersion:3,gameDate:'2000-11-09'};
const proof=()=>({
 status:'verified_game_airport_slots',verified:true,readOnly:true,
 worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,scheduleVersion:3,
 gameDate:'2000-11-09',validThroughGameDate:'2000-12-07',
 clearanceType:'airport_slot_capacity',
 sourceKind:'verified_airport_slot_engine',
 sourceReference:'game-slot-capacity-v1-'+'a'.repeat(32),
 proofFingerprint:'a'.repeat(32),
 reviewerReference:'independent-game-slot-authority-v1',
 proposedSlots:10,reservedSlots:10,
 flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false
});
const denied=()=>({
 status:'blocked_unverified_world_or_game_day',verified:false,readOnly:true,
 flightActivated:false,movementRecorded:false,bookingsCreated:false,
 ledgerPosted:false
});
function build({evidence=proof(),accepted=null,signatureSecret=SECRET}={}){
 const calls=[],certs=[];
 let connections=0,releases=0;
 const database={async connect(){connections++;return{
  async query(sql,args){
   calls.push({sql,args});
   if(evidence instanceof Error)throw evidence;
   return {rowCount:1,rows:[{result:evidence}]};
  },release(){releases++}
 }}};
 const certificationIngress={
  clearanceType:'airport_slot_capacity',
  async acceptSignedDecision(event){
   certs.push(event);
   const expected=createHmac('sha256',signatureSecret)
    .update(section9CertificationPayload(event),'utf8').digest('hex');
   assert.equal(event.signature,expected);
   return accepted??{
    status:'certification_event_recorded',
    scheduleId:SCHEDULE,eventId:event.eventId,
    flightActivated:false,movementRecorded:false,
    bookingsCreated:false,ledgerPosted:false
   };
  }
 };
 const issuer=createSection9GameSlotClearanceIssuer({
  database,slotAuthoritySecret:SECRET,certificationIngress
 });
 return {issuer,calls,certs,counts:()=>({connections,releases})};
}
test('requires private database, isolated slot secret and matching signed ingress',()=>{
 assert.throws(()=>createSection9GameSlotClearanceIssuer(),/PRIVATE_SLOT_AUTHORITY_DATABASE_REQUIRED/);
 assert.throws(()=>createSection9GameSlotClearanceIssuer({
  database:{connect:async()=>{}},slotAuthoritySecret:'short'
 }),/GAME_SLOT_SIGNING_SECRET_REQUIRED/);
 assert.throws(()=>createSection9GameSlotClearanceIssuer({
  database:{connect:async()=>{}},slotAuthoritySecret:SECRET,
  certificationIngress:{clearanceType:'crew_duty',acceptSignedDecision(){}}
 }),/MATCHING_SLOT_CERTIFICATION_INGRESS_REQUIRED/);
});
test('world not open never signs certificates, even if a schedule exists',async()=>{
 const m=build({evidence:denied()});
 const r=await m.issuer.certifyCurrentSlotReservation(request);
 assert.equal(r.status,'blocked_unverified_world_or_game_day');
 assert.equal(r.slotCertificateIssued,false);
 assert.equal(m.certs.length,0);
 assert.deepEqual(m.calls[0],{
  sql:SECTION9_SLOT_AUTHORITY_SQL.evidence,
  args:[AIRLINE,SCHEDULE,3,'2000-11-09']
 });
 assert.deepEqual(m.counts(),{connections:1,releases:1});
});
test('positive verified slot source signs the exact proof once',async()=>{
 const m=build();
 const r=await m.issuer.certifyCurrentSlotReservation(request);
 assert.equal(r.status,'certification_event_recorded');
 assert.equal(r.slotCertificateIssued,true);
 assert.equal(r.flightActivated,false);
 assert.equal(r.ledgerPosted,false);
 assert.equal(m.certs.length,1);
 const signed=m.certs[0];
 assert.equal(signed.clearanceType,'airport_slot_capacity');
 assert.equal(signed.sourceKind,'verified_airport_slot_engine');
 assert.equal(signed.validFromGameDate,'2000-11-09');
 assert.equal(signed.validToGameDate,'2000-12-07');
 assert.match(signed.eventId,/^slot-clearance-v1\./);
 assert.equal(signed.scheduleId,SCHEDULE);
 assert.equal(m.counts().releases,1);
});
test('exact repeat is treated as replay not new certification',async()=>{
 const e=proof();
 const eventId=['slot-clearance-v1',SCHEDULE.replaceAll('-',''),
 '3','20001109',e.proofFingerprint.slice(0,12)].join('.');
 const m=build({accepted:{
  status:'certification_event_replayed',scheduleId:SCHEDULE,
  eventId,flightActivated:false,movementRecorded:false,
  bookingsCreated:false,ledgerPosted:false
 }});
 const r=await m.issuer.certifyCurrentSlotReservation(request);
 assert.equal(r.replayed,true);
 assert.equal(r.slotCertificateIssued,false);
});
test('bad game slot source evidence is rejected before signing',async()=>{
 for(const bad of [
  {...proof(),verified:false},
  {...proof(),airlineId:'11111111-1111-4111-8111-111111111111'},
  {...proof(),scheduleVersion:4},
  {...proof(),validThroughGameDate:'2000-12-08'},
  {...proof(),proposedSlots:0},
  {...proof(),reservedSlots:9},
  {...proof(),sourceReference:'manual-approval-not-a-proof'},
  {...proof(),flightActivated:true},
  {...proof(),ledgerPosted:true},
  {...proof(),readOnly:false},
  {...proof(),status:'certification_event_recorded'}
 ]){
  const m=build({evidence:bad});
  await assert.rejects(m.issuer.certifyCurrentSlotReservation(request),
   /SECTION9_UNTRUSTED_GAME_SLOT_SOURCE_PROOF/);
  assert.equal(m.certs.length,0);
  assert.equal(m.counts().releases,1);
 }
});
test('denied reservations are returned as blockers without generating certificates',async()=>{
 const m=build({evidence:{
  ...denied(),status:'blocked_slot_clearance_evidence',
  blockers:['RECURRING_SLOT_RESERVATIONS_MISMATCH']
 }});
 const r=await m.issuer.certifyCurrentSlotReservation(request);
 assert.deepEqual(r.reasons,['RECURRING_SLOT_RESERVATIONS_MISMATCH']);
 assert.equal(m.certs.length,0);
});
test('refuse forged input before reading database',async()=>{
 const m=build();
 for(const bad of [
  {...request,airlineId:'invalid'},
  {...request,scheduleId:'invalid'},
  {...request,scheduleVersion:0},
  {...request,gameDate:'2000-02-30'}
 ]){
  await assert.rejects(m.issuer.certifyCurrentSlotReservation(bad),
   /SECTION9_INVALID_SLOT_CERTIFICATION_REQUEST/);
 }
 assert.equal(m.calls.length,0);
});
test('database source unavailable releases connection and refuses certification',async()=>{
 const m=build({evidence:new Error('PRIVATE_DB_UNAVAILABLE')});
 await assert.rejects(m.issuer.certifyCurrentSlotReservation(request),
  /PRIVATE_DB_UNAVAILABLE/);
 assert.equal(m.certs.length,0);
 assert.deepEqual(m.counts(),{connections:1,releases:1});
});
test('cannot accept a database result that pretends to activate or credit cash',async()=>{
 const m=build({accepted:{
  status:'certification_event_recorded',scheduleId:SCHEDULE,
  eventId:'not-the-requested-event-id',flightActivated:true,
  movementRecorded:false,bookingsCreated:false,ledgerPosted:true
 }});
 await assert.rejects(m.issuer.certifyCurrentSlotReservation(request),
  /SECTION9_SLOT_CERTIFICATE_NOT_CONFIRMED/);
});
test('slot verifier SQL is private; signed DB sink rechecks source proof',async()=>{
 const sql=await readFile(new URL(
  '../supabase/migrations/20261109192500_section9_game_slot_authority_verification.sql',
  import.meta.url),'utf8');
 const sink=await readFile(new URL(
  '../supabase/migrations/20261109193000_section9_slot_certification_freshness_gate.sql',
  import.meta.url),'utf8');
 assert.match(sql,/FOR SHARE OF s,f/);
 assert.match(sql,/slot_check/);
 assert.match(sql,/section9_verified_game_tick_receipts_v1/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sink,/fresh_slot_proof/);
 assert.match(sink,/sourceReference'=p_source_reference/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.section9_schedule_operational_certifications_v1/);
});
