import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9ExecutionFinanceEvidenceSigner}
 from '../server/section9-execution-finance-evidence-signer.mjs';
import {createSection9SignedCertificationIngress}
 from '../server/section9-signed-certification-ingress.mjs';
import {SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL}
 from '../server/section9-execution-finance-snapshot-reader.mjs';

const AIRLINE='11111111-1111-4111-8111-111111111111';
const OUT='44444444-4444-4444-8444-444444444444';
const BACK='55555555-5555-4555-8555-555555555555';
const DAY='2026-11-20';
const TYPES=['trusted_flight_execution','commercial_finance'];
const KEYS={
 trusted_flight_execution:'very-private-independent-execution-source-key-0123456789-111',
 commercial_finance:'very-private-independent-finance-source-key-0123456789-222'
};
const req=(scheduleId=OUT)=>({airlineId:AIRLINE,scheduleId,
 scheduleVersion:1,gameDate:DAY});
const proof=(type,scheduleId=OUT,alter={})=>{
 const hash=type==='trusted_flight_execution'?'a'.repeat(32):'b'.repeat(32);
 return {
  status:'source_snapshot_candidate_not_authorized',
  worldId:1,airlineId:AIRLINE,scheduleId,scheduleVersion:1,gameDate:DAY,
  clearanceType:type,snapshotVersion:'SECTION9_INDEPENDENT_SOURCE_SNAPSHOT_CANDIDATE_V1',
  candidateReady:true,sourceFingerprint:hash,
  sourceReference:'candidate-execution-finance-v1-'+hash,blockers:[],
  readOnly:true,verified:false,certificateIssued:false,sourceAuthorityReleased:false,
  flightActivated:false,movementRecorded:false,bookingsCreated:false,
  ledgerPosted:false,...alter
 };
};
function build(type,{scheduleId=OUT,source=proof(type,scheduleId),
 key=KEYS[type],ingressKey=key,sinkReject=false}={}){
 const sqlCalls=[],writes=[];let releases=0;
 const sourceDb={async connect(){return{
  async query(sql,args){sqlCalls.push({sql,args});
   if(source instanceof Error)throw source;
   return {rowCount:1,rows:[{result:source}]};},
  release(){releases++;}
 }}};
 const ingestDb={async connect(){return{
  async query(sql,args){
   if(sinkReject)throw Error('SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION');
   writes.push({sql,args});
   return {rowCount:1,rows:[{result:{
    status:'certification_event_recorded',eventId:args[5],
    scheduleId:args[1],scheduleVersion:args[2],
    clearanceType:args[3],reviewStatus:'certified',
    replayed:false,certificateChanged:true,
    activationPreparationInvalidated:true,
    flightActivated:false,movementRecorded:false,
    bookingsCreated:false,ledgerPosted:false
   }}]};
  },release(){}
 }}};
 const ingress=createSection9SignedCertificationIngress({
  database:ingestDb,clearanceType:type,verifierSecret:ingressKey
 });
 const issuer=createSection9ExecutionFinanceEvidenceSigner({
  database:sourceDb,clearanceType:type,authoritySecret:key,
  certificationIngress:ingress
 });
 return {issuer,sqlCalls,writes,releases:()=>releases};
}
test('both independent keys sign real canonical payloads through HMAC-validating ingress',async()=>{
 for(const type of TYPES){
  for(const scheduleId of [OUT,BACK]){
   const b=build(type,{scheduleId});
   const result=await b.issuer.verifyAndCertify(req(scheduleId));
   assert.equal(result.status,'certification_event_recorded');
   assert.equal(result.certificateIssued,true);
   assert.equal(result.flightActivated,false);
   assert.equal(result.ledgerPosted,false);
   assert.equal(b.writes.length,1);
   assert.equal(b.writes[0].args[3],type);
   assert.equal(b.writes[0].args[1],scheduleId);
   assert.equal(b.writes[0].args[10].length,64);
   assert.deepEqual(b.sqlCalls,[{sql:SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL,
    args:[AIRLINE,scheduleId,1,DAY,type]}]);
   assert.equal(b.releases(),1);
  }
 }
});
test('one authority signing key cannot be accepted by the other ingress key',async()=>{
 const b=build('trusted_flight_execution',{ingressKey:KEYS.commercial_finance});
 await assert.rejects(b.issuer.verifyAndCertify(req()),/UNTRUSTED_CERTIFICATION_SIGNATURE/);
 assert.equal(b.writes.length,0);
 assert.equal(b.releases(),1);
});
test('production-style explicit SQL rejection cannot be promoted to issued status',async()=>{
 for(const type of TYPES){
  const b=build(type,{sinkReject:true});
  await assert.rejects(b.issuer.verifyAndCertify(req()),
   /UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION/);
  assert.equal(b.writes.length,0);
 }
});
test('blocked source snapshot cannot be signed, even with its own independent key',async()=>{
 for(const type of TYPES){
  const b=build(type,{source:proof(type,OUT,{
   status:'blocked_unreleased_execution_finance_source_snapshot',
   candidateReady:false,sourceFingerprint:null,sourceReference:null,
   blockers:['TRUSTED_EXECUTION_NOT_RELEASED']
  })});
  const r=await b.issuer.verifyAndCertify(req());
  assert.equal(r.certificateIssued,false);
  assert.equal(b.writes.length,0);
 }
});
test('forged or stale JSON source fingerprints are rejected BEFORE HMAC ingress',async()=>{
 for(const type of TYPES){
  for(const alter of [
   {scheduleId:BACK},{gameDate:'2026-11-21'},{scheduleVersion:2},
   {clearanceType:type===TYPES[0]?TYPES[1]:TYPES[0]},
   {candidateReady:false},{certificateIssued:true},{verified:true},
   {sourceAuthorityReleased:true},{ledgerPosted:true},
   {sourceFingerprint:'invalid'},{sourceReference:'tampered'},
   {status:'source_snapshot_candidate_not_authorized',blockers:['DENY']}
  ]){
   const b=build(type,{source:proof(type,OUT,alter)});
   await assert.rejects(b.issuer.verifyAndCertify(req()),
    /EVIDENCE_SIGNER_UNTRUSTED_SOURCE/);
   assert.equal(b.writes.length,0);
  }
 }
});
test('malformed request and unavailable source fail closed without signatures',async()=>{
 const b=build(TYPES[0]);
 await assert.rejects(b.issuer.verifyAndCertify({...req(),gameDate:'2026-02-30'}),
  /EVIDENCE_SIGNER_INVALID_REQUEST/);
 assert.equal(b.sqlCalls.length,0);
 const offline=build(TYPES[0],{source:new Error('DB_DOWN')});
 await assert.rejects(offline.issuer.verifyAndCertify(req()),/DB_DOWN/);
 assert.equal(offline.writes.length,0);
 assert.equal(offline.releases(),1);
});
