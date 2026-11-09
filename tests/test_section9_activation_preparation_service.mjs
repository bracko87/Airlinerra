import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createSection9ActivationPreparationService,SECTION9_ACTIVATION_PREP_SQL
} from '../server/section9-activation-preparation-service.mjs';

const PLAYER='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const DATE='2000-11-09';
const base={airlineId:AIRLINE,scheduleId:SCHEDULE,
 expectedVersion:3,gameDate:DATE,days:28};
const permitted=req=>({
 authorized:true,source:'independent_operational_release_authority',
 ownerPlayerId:PLAYER,airlineId:req.airlineId,scheduleId:req.scheduleId,
 expectedVersion:req.expectedVersion,gameDate:req.gameDate
});
const blocked={
 status:'blocked_activation_preparation',scheduleId:SCHEDULE,
 scheduleVersion:3,blockers:['WORLD_NOT_OPEN','SIX_INDEPENDENT_OPERATIONAL_CERTIFICATIONS_MISSING'],
 acceptedCertifications:0,requiredCertifications:6,
 prepared:false,flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false
};
const prepared={
 status:'prepared_for_future_activation_commit',scheduleId:SCHEDULE,
 scheduleVersion:3,prepared:true,fingerprint:'f'.repeat(32),
 flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false
};
const create=(reply=blocked,authority=permitted)=>{
 const calls=[];let connected=0,released=0,authCalls=0;
 const database={connect:async()=>{connected++;return {
  release(){released++},
  async query(sql,args){calls.push({sql,args});return {
   rowCount:1,rows:[{result:reply}]
  };}
 }}};
 const independentReleaseAuthority={async authorizePreparation(request){
  authCalls++;return authority(request);
 }};
 return {service:createSection9ActivationPreparationService({
  database,independentReleaseAuthority
 }),calls,counts:()=>({connected,released,authCalls})};
};
test('preparation adapter requires private DB and independent authority',()=>{
 assert.throws(()=>createSection9ActivationPreparationService(),/PRIVATE_DATABASE_REQUIRED/);
 assert.throws(()=>createSection9ActivationPreparationService({
  database:{connect:async()=>{}}
 }),/INDEPENDENT_ACTIVATION_AUTHORITY_REQUIRED/);
});
test('cannot request release with malformed IDs, date, version, or horizon',async()=>{
 const m=create();for(const invalid of [
  {...base,airlineId:'invalid'}, {...base,scheduleId:'wrong'},
  {...base,expectedVersion:0},{...base,gameDate:'2000-02-30'},
  {...base,days:99},{...base,ownerPlayerId:PLAYER},
  {...base,gameDate:'2200-01-01'}
 ]){
  if('ownerPlayerId' in invalid)continue; // extra caller metadata is never used.
  await assert.rejects(m.service.prepare(invalid),/INVALID_ACTIVATION_PREPARATION_REQUEST/);
 }
 assert.deepEqual(m.counts(),{connected:0,released:0,authCalls:0});
});
test('authority must confirm exact identity before any SQL query',async()=>{
 for(const bad of [
  null,{authorized:false},
  {...permitted(base),source:'player_request'},
  {...permitted(base),ownerPlayerId:'fake'},
  {...permitted(base),scheduleId:PLAYER},
  {...permitted(base),expectedVersion:4},
  {...permitted(base),gameDate:'2000-11-10'}
 ]){
  const m=create(blocked,()=>bad);
  await assert.rejects(m.service.prepare(base),/ACTIVATION_PREPARATION_NOT_AUTHORIZED/);
  assert.deepEqual(m.counts(),{connected:0,released:0,authCalls:1});
 }
});
test('blocked independent preflight returns actionable reasons and no flight writes',async()=>{
 const m=create();
 const x=await m.service.prepare({...base,ownerPlayerId:'caller-can-not-inject'});
 assert.deepEqual(x,blocked);
 assert.equal(m.calls.length,1);
 assert.equal(m.calls[0].sql,SECTION9_ACTIVATION_PREP_SQL.prepare);
 assert.deepEqual(m.calls[0].args,[PLAYER,AIRLINE,SCHEDULE,3,DATE,28]);
 assert.deepEqual(m.counts(),{connected:1,released:1,authCalls:1});
});
test('future prepared checkpoint is NOT interpreted as actual activated flight',async()=>{
 const m=create(prepared);
 const x=await m.service.prepare(base);
 assert.equal(x.prepared,true);
 assert.equal(x.flightActivated,false);
 assert.equal(x.movementRecorded,false);
 assert.equal(x.bookingsCreated,false);
 assert.equal(x.ledgerPosted,false);
});
test('fails closed if DB claims activation, money, or invalid preparation flags',async()=>{
 for(const fake of [
  {...prepared,flightActivated:true},
  {...blocked,movementRecorded:true},
  {...blocked,bookingsCreated:true},
  {...blocked,ledgerPosted:true},
  {...prepared,status:'schedule_activated'},
  {...blocked,prepared:true},
  {...prepared,prepared:false},
  {...blocked,scheduleId:PLAYER},
  null
 ]){
  const m=create(fake);
  await assert.rejects(m.service.prepare(base),/UNSAFE_ACTIVATION_PREPARATION_RESPONSE/);
  assert.equal(m.counts().released,1);
 }
});
test('private SQL contains six gates and does not change flight status checks',async()=>{
 const sql=await readFile(new URL(
  '../supabase/migrations/20261109184500_section9_activation_certification_preparation.sql',
  import.meta.url),'utf8');
 assert.match(sql,/SIX_INDEPENDENT_OPERATIONAL_CERTIFICATIONS_MISSING/);
 assert.match(sql,/COMMERCIAL_ACTIVATION_ADMIN_RELEASE_MISSING/);
 assert.match(sql,/FOR UPDATE OF s, f/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/fingerprint_md5/);
 assert.doesNotMatch(sql,/DROP CONSTRAINT|UPDATE airlinerra_game\.airline_flight_schedule_drafts_v1\s+SET\s+status/);
 const src=await readFile(new URL(
  '../server/section9-activation-preparation-service.mjs',
  import.meta.url),'utf8');
 assert.doesNotMatch(src,/createServer\(|fetch\(|/);
});
