import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9ExecutionFinanceSnapshotReader,
 SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL}
 from '../server/section9-execution-finance-snapshot-reader.mjs';

const AIRLINE='11111111-1111-4111-8111-111111111111';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const REQUEST={
 airlineId:AIRLINE,scheduleId:SCHEDULE,scheduleVersion:1,
 gameDate:'2026-11-20',clearanceType:'trusted_flight_execution'
};
const BLOCKED={
 status:'blocked_unreleased_execution_finance_source_snapshot',
 worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,scheduleVersion:1,
 gameDate:'2026-11-20',clearanceType:'trusted_flight_execution',
 snapshotVersion:'SECTION9_INDEPENDENT_SOURCE_SNAPSHOT_CANDIDATE_V1',
 candidateReady:false,sourceReference:null,sourceFingerprint:null,
 blockers:['COMMERCIAL_ACTIVATION_NOT_RELEASED'],readOnly:true,
 verified:false,certificateIssued:false,sourceAuthorityReleased:false,
 flightActivated:false,movementRecorded:false,bookingsCreated:false,
 ledgerPosted:false
};
function make(proof=BLOCKED){
 const queries=[];let releases=0;
 const database={async connect(){return {async query(sql,args){
  queries.push({sql,args});
  if(proof instanceof Error)throw proof;
  return {rowCount:1,rows:[{result:proof}]};
 },release(){releases++}}}};
 return {reader:createSection9ExecutionFinanceSnapshotReader({database}),
  queries,releases:()=>releases};
}
test('uses the actual private PostgreSQL snapshot and never exposes signing, writes, or release controls',async()=>{
 const sql=await readFile(new URL(
  '../supabase/migrations/20261120224500_section9_execution_finance_source_snapshot_candidates.sql',
  import.meta.url),'utf8');
 assert.match(sql,/LANGUAGE plpgsql STABLE SECURITY INVOKER/);
 assert.match(sql,/section9_execution_finance_certificate_source_preflight_v1/);
 assert.match(sql,/section9_fuel_and_settlement_release_policy_v1/);
 assert.match(sql,/section9_flight_engine_readiness_audit_v1/);
 assert.match(sql,/section9_operational_certification_events_v1|section9_execution_finance_certificate_source_preflight_v1/);
 assert.match(sql,/fingerprint:=md5\(concat_ws/);
 assert.match(sql,/'certificateIssued',false/);
 assert.match(sql,/'sourceAuthorityReleased',false/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.doesNotMatch(sql,/\bINSERT INTO\b|\bDELETE FROM\b|\bUPDATE airlinerra_game\./i);
});
test('reads blocked execution and finance source with exact request identity',async()=>{
 for(const clearanceType of ['trusted_flight_execution','commercial_finance']){
  const m=make({...BLOCKED,clearanceType});
  const r=await m.reader.inspect({...REQUEST,clearanceType});
  assert.equal(r.candidateReady,false);
  assert.equal(r.verified,false);
  assert.equal(r.certificateIssued,false);
  assert.equal(r.sourceAuthorityReleased,false);
  assert.equal(r.sourceFingerprint,null);
  assert.deepEqual(m.queries,[{sql:SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL,
   args:[AIRLINE,SCHEDULE,1,'2026-11-20',clearanceType]}]);
  assert.equal(m.releases(),1);
 }
});
test('valid future source snapshot is still NOT a certificate',async()=>{
 const hash='f'.repeat(32);
 const m=make({...BLOCKED,status:'source_snapshot_candidate_not_authorized',
  candidateReady:true,sourceFingerprint:hash,
  sourceReference:'candidate-execution-finance-v1-'+hash,blockers:[]});
 const r=await m.reader.inspect(REQUEST);
 assert.equal(r.candidateReady,true);
 assert.equal(r.sourceFingerprint,hash);
 assert.equal(r.verified,false);
 assert.equal(r.certificateIssued,false);
 assert.equal(r.sourceAuthorityReleased,false);
});
test('reject forged ready source, invalid fingerprints, wrong identity, and invented money changes',async()=>{
 for(const replacement of [
  {verified:true},{certificateIssued:true},{sourceAuthorityReleased:true},
  {flightActivated:true},{bookingsCreated:true},{ledgerPosted:true},
  {scheduleId:'55555555-5555-4555-8555-555555555555'},
  {candidateReady:true,sourceFingerprint:null},
  {candidateReady:true,sourceFingerprint:'b'.repeat(32),
   sourceReference:'untrusted-reference',blockers:[]},
  {candidateReady:false,sourceFingerprint:'b'.repeat(32)}
 ]){
  const m=make({...BLOCKED,...replacement});
  await assert.rejects(m.reader.inspect(REQUEST),/UNTRUSTED_SOURCE_SNAPSHOT/);
  assert.equal(m.releases(),1);
 }
});
test('fail closed on invalid dates before database access and always close failed connections',async()=>{
 const m=make();
 await assert.rejects(m.reader.inspect({...REQUEST,gameDate:'2026-02-30'}),
  /INVALID_SOURCE_SNAPSHOT_REQUEST/);
 assert.equal(m.queries.length,0);
 const f=make(new Error('DB_DOWN'));
 await assert.rejects(f.reader.inspect(REQUEST),/DB_DOWN/);
 assert.equal(f.releases(),1);
});
