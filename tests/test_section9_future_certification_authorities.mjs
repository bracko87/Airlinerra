import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9FutureCertificationAuthority,
 SECTION9_FUTURE_CERTIFICATION_TYPES,
 SECTION9_FUTURE_CERTIFICATION_SOURCE_SQL}
 from '../server/section9-future-certification-authorities.mjs';

const AIRLINE='11111111-1111-4111-8111-111111111111';
const OUT='44444444-4444-4444-8444-444444444444';
const BACK='55555555-5555-4555-8555-555555555555';
const DAY='2026-11-20';
const TYPES=['trusted_flight_execution','commercial_finance'];
const KEYS={
 trusted_flight_execution:'private-independent-operation-key-for-tests-100001',
 commercial_finance:'different-independent-finance-key-for-tests-200002'
};
const base=(type,scheduleId,updates={})=>({
 status:'blocked_unreleased_execution_finance_source',
 worldId:1,airlineId:AIRLINE,scheduleId,scheduleVersion:1,
 gameDate:DAY,clearanceType:type,
 readOnly:true,verified:false,certificateIssued:false,
 sourceAuthorityReleased:false,flightActivated:false,movementRecorded:false,
 bookingsCreated:false,ledgerPosted:false,
 blockers:['COMMERCIAL_ACTIVATION_NOT_RELEASED'],
 ...updates
});
function make(type,{scheduleId=OUT,proof=base(type,scheduleId),
 secret=KEYS[type],ingressType=type}={}){
 const logs=[];let releases=0,ingestCalls=0;
 const database={async connect(){return{
  async query(sql,args){logs.push({sql,args});
   if(proof instanceof Error)throw proof;
   return {rowCount:1,rows:[{result:proof}]};
  },
  release(){releases++;}
 }}};
 const certificationIngress={clearanceType:ingressType,
  async acceptSignedDecision(){ingestCalls++;throw Error('SHOULD_NEVER_ISSUE');}};
 const service=createSection9FutureCertificationAuthority({
  database,clearanceType:type,authoritySecret:secret,certificationIngress
 });
 return {service,logs,releases:()=>releases,ingestCalls:()=>ingestCalls};
}
test('two distinct authority classes have fixed private types',()=>{
 assert.deepEqual(SECTION9_FUTURE_CERTIFICATION_TYPES,TYPES);
 assert.throws(()=>createSection9FutureCertificationAuthority(),
  /PRIVATE_DB_REQUIRED/);
 assert.throws(()=>createSection9FutureCertificationAuthority({
  database:{connect(){}},clearanceType:'route_traffic_rights'}),
  /UNSUPPORTED_TYPE/);
 assert.throws(()=>createSection9FutureCertificationAuthority({
  database:{connect(){}},clearanceType:TYPES[0],authoritySecret:'too-short'}),
  /INDEPENDENT_KEY_REQUIRED/);
 assert.throws(()=>createSection9FutureCertificationAuthority({
  database:{connect(){}},clearanceType:TYPES[0],
  authoritySecret:KEYS[TYPES[0]],certificationIngress:{
   clearanceType:TYPES[1],acceptSignedDecision(){}
  }}),/MATCHING_INGRESS_REQUIRED/);
});
test('both authority holders inspect each direction and never sign paused source results',async()=>{
 for(const type of TYPES){
  for(const scheduleId of [OUT,BACK]){
   const b=make(type,{scheduleId});
   const r=await b.service.inspectForCertification({
    airlineId:AIRLINE,scheduleId,scheduleVersion:1,gameDate:DAY
   });
   assert.equal(r.status,'blocked_unreleased_execution_finance_source');
   assert.equal(r.certificateIssued,false);
   assert.equal(r.sourceAuthorityReleased,false);
   assert.equal(r.flightActivated,false);
   assert.equal(r.ledgerPosted,false);
   assert.deepEqual(r.blockers,['COMMERCIAL_ACTIVATION_NOT_RELEASED']);
   assert.equal(b.ingestCalls(),0);
   assert.equal(b.releases(),1);
   assert.deepEqual(b.logs,[{
    sql:SECTION9_FUTURE_CERTIFICATION_SOURCE_SQL.preflight,
    args:[AIRLINE,scheduleId,1,DAY,type]
   }]);
  }
 }
});
test('even a fully satisfied preflight is still never certifiable',async()=>{
 const b=make(TYPES[0],{proof:base(TYPES[0],OUT,{
  status:'source_preflight_complete_not_certifiable',blockers:[]
 })});
 const r=await b.service.inspectForCertification({
  airlineId:AIRLINE,scheduleId:OUT,scheduleVersion:1,gameDate:DAY
 });
 assert.equal(r.certificateIssued,false);
 assert.equal(b.ingestCalls(),0);
});
test('forged positive proof, false identity, or ledger side effect is rejected before signing',async()=>{
 for(const type of TYPES){
  for(const wrong of [
   {status:'verified_independent_trusted_flight_execution_source',verified:true},
   {certificateIssued:true},{sourceAuthorityReleased:true},
   {ledgerPosted:true},{bookingsCreated:true},{movementRecorded:true},
   {scheduleId:BACK},{clearanceType: type===TYPES[0]?TYPES[1]:TYPES[0]},
   {blockers:null},{readOnly:false}
  ]){
   const b=make(type,{proof:base(type,OUT,wrong)});
   await assert.rejects(b.service.inspectForCertification({
    airlineId:AIRLINE,scheduleId:OUT,scheduleVersion:1,gameDate:DAY
   }),/SOURCE_NOT_INDEPENDENTLY_RELEASED/);
   assert.equal(b.ingestCalls(),0);
   assert.equal(b.releases(),1);
  }
 }
});
test('invalid date or schedule never queries, database failures release connection',async()=>{
 const b=make(TYPES[0]);
 await assert.rejects(b.service.inspectForCertification({
  airlineId:AIRLINE,scheduleId:OUT,scheduleVersion:1,gameDate:'2026-02-30'
 }),/INVALID_REQUEST/);
 await assert.rejects(b.service.inspectForCertification({
  airlineId:AIRLINE,scheduleId:OUT,scheduleVersion:0,gameDate:DAY
 }),/INVALID_REQUEST/);
 assert.equal(b.logs.length,0);
 const c=make(TYPES[0],{proof:new Error('PRIVATE_DATABASE_FAILURE')});
 await assert.rejects(c.service.inspectForCertification({
  airlineId:AIRLINE,scheduleId:OUT,scheduleVersion:1,gameDate:DAY
 }),/PRIVATE_DATABASE_FAILURE/);
 assert.equal(c.releases(),1);
});
test('the live certification database sink keeps both future types blocked',async()=>{
 const sql=await readFile(new URL(
  '../supabase/migrations/20261120211500_section9_unreleased_execution_finance_certification_fail_closed.sql',
  import.meta.url),'utf8');
 assert.match(sql,/SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION/);
 const source=await readFile(new URL(
  '../server/section9-future-certification-authorities.mjs',import.meta.url),
  'utf8');
 assert.doesNotMatch(source,/createHmac|section9CertificationPayload|acceptSignedDecision\s*\(/);
});
