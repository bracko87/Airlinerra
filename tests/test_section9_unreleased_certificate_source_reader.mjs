import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9UnreleasedCertificateSourceReader,
 SECTION9_UNRELEASED_SOURCE_SQL} from '../server/section9-unreleased-certificate-source-reader.mjs';

const REQUEST={airlineId:'11111111-1111-4111-8111-111111111111',
 scheduleId:'44444444-4444-4444-8444-444444444444',scheduleVersion:1,
 gameDate:'2026-11-20',clearanceType:'trusted_flight_execution'};
const proof=(overrides={})=>({
 worldId:1,airlineId:REQUEST.airlineId,scheduleId:REQUEST.scheduleId,
 scheduleVersion:1,gameDate:REQUEST.gameDate,
 clearanceType:REQUEST.clearanceType,
 status:'blocked_unreleased_execution_finance_source',
 blockers:['TRUSTED_EXECUTION_NOT_RELEASED'],
 readOnly:true,verified:false,certificateIssued:false,
 sourceAuthorityReleased:false,flightActivated:false,
 movementRecorded:false,bookingsCreated:false,ledgerPosted:false,
 ...overrides
});
const setup=(reply=proof())=>{
 const calls=[];let released=0;
 const database={async connect(){return {async query(sql,args){
  calls.push({sql,args});if(reply instanceof Error)throw reply;
  return {rowCount:1,rows:[{result:reply}]};
 },release(){released++}}}};
 return {reader:createSection9UnreleasedCertificateSourceReader({database}),
  calls,released:()=>released};
};
test('production SQL preflight checks real policy and source facts but never issues a certificate',async()=>{
 const s=await readFile(new URL(
 '../supabase/migrations/20261120215500_section9_execution_finance_source_preflight_readonly.sql',
 import.meta.url),'utf8');
 assert.match(s,/LANGUAGE plpgsql STABLE SECURITY INVOKER/);
 for(const name of [
  'section9_activation_release_policy_v1',
  'section9_trusted_execution_release_policy_v1',
  'section9_flight_finance_posting_release_v1',
  'section9_flight_engine_readiness_audit_v1',
  'section9_verified_berlin_game_hour_v1',
  'airline_flight_schedule_drafts_v1',
  'airline_aircraft_inventory',
  'section9_game_fuel_model_snapshot_v1',
  'section9_schedule_operational_certifications_v1',
  'section9_operational_certification_events_v1'
 ])assert.ok(s.includes(name),name);
 assert.match(s,/'verified',false/);
 assert.match(s,/'certificateIssued',false/);
 assert.match(s,/'sourceAuthorityReleased',false/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/\b(?:INSERT INTO|UPDATE airlinerra_game|DELETE FROM|TRUNCATE)\b/i);
});
test('both unreleased sources return actionable diagnostics, never signing authority',async()=>{
 for(const type of ['trusted_flight_execution','commercial_finance']){
  const b=setup(proof({clearanceType:type}));
  const result=await b.reader.inspect({...REQUEST,clearanceType:type});
  assert.equal(result.sourceAuthorityReleased,false);
  assert.equal(result.certificateIssued,false);
  assert.equal(result.certificationComplete,false);
  assert.equal(result.ledgerPosted,false);
  assert.deepEqual(b.calls,[{sql:SECTION9_UNRELEASED_SOURCE_SQL,
   args:[REQUEST.airlineId,REQUEST.scheduleId,1,REQUEST.gameDate,type]}]);
  assert.equal(b.released(),1);
 }
});
test('even a ready preflight cannot be promoted to a certificate',async()=>{
 const b=setup(proof({status:'source_preflight_complete_not_certifiable',blockers:[]}));
 const r=await b.reader.inspect(REQUEST);
 assert.equal(r.certificateIssued,false);
 assert.equal(r.sourceAuthorityReleased,false);
 assert.equal(r.certificationComplete,false);
});
test('source responses that claim approval or unauthorized effects fail closed',async()=>{
 for(const overrides of [
  {verified:true},{certificateIssued:true},{sourceAuthorityReleased:true},
  {ledgerPosted:true},{bookingsCreated:true},{flightActivated:true},
  {scheduleId:'55555555-5555-4555-8555-555555555555'},
  {status:'verified_flight_execution'},{blockers:'none'}
 ]){
  const b=setup(proof(overrides));
  await assert.rejects(b.reader.inspect(REQUEST),
   /UNTRUSTED_UNRELEASED_SOURCE_RESPONSE/);
  assert.equal(b.released(),1);
 }
});
test('invalid identity or date never queries, connection is released after DB error',async()=>{
 const b=setup();
 await assert.rejects(b.reader.inspect({...REQUEST,gameDate:'2026-02-30'}),
  /INVALID_UNRELEASED_CERTIFICATE_SOURCE_REQUEST/);
 await assert.rejects(b.reader.inspect({...REQUEST,clearanceType:'airport_slot_capacity'}),
  /INVALID_UNRELEASED_CERTIFICATE_SOURCE_REQUEST/);
 assert.equal(b.calls.length,0);
 const c=setup(new Error('PRIVATE_DB_DOWN'));
 await assert.rejects(c.reader.inspect(REQUEST),/PRIVATE_DB_DOWN/);
 assert.equal(c.released(),1);
});
