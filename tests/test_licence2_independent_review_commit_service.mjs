import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createLicence2TrustedReviewCommitService,licence2IndependentReviewPayload} from '../server/licence2-independent-review-commit-service.mjs';
const applicationId='11111111-1111-4111-8111-111111111111';
const airlineId='22222222-2222-4222-8222-222222222222';
const secret='fixture-only-licence2-review-key-not-production';
const args={applicationId,airlineId,requestedLevel:1,reviewedGameDay:'2026-11-19'};
const base={worldId:1,...args,marketCode:'L2-EU',
 decision:'approve',reviewEventId:'independent-review-event-0001',
 reviewReference:'independent-review-decision-0001',
 producerEventId:'independent-review-source-0001',
 evidenceSource:'independent_game_licence_review_v1'};
const signature=proof=>createHmac('sha256',secret)
 .update(licence2IndependentReviewPayload(proof),'utf8').digest('hex');
const signed={...base,signature:signature(base)};
const make=(record,result={status:'LICENCE2_APPROVAL_NOT_RELEASED',
 chargedNow:false,permitIssuedNow:false,flightActivated:false})=>{
 const calls=[];
 const service=createLicence2TrustedReviewCommitService({
  evidenceReader:{readSignedReview:async(scope)=>{calls.push({scope});return record;}},
  verificationSecret:secret,
  database:{connect:async()=>({query:async(sql,params)=>{
   calls.push({sql,params});return {rowCount:1,rows:[{result}]};
  },release(){calls.push({released:true});}})}
 });
 return {service,calls};
};
test('unreleased approval requires valid independent signature and cannot issue or charge',async()=>{
 const {service,calls}=make(signed);
 const result=await service.approve(args);
 assert.equal(result.status,'LICENCE2_APPROVAL_NOT_RELEASED');
 assert.equal(result.approvalCommitted,false);
 assert.equal(result.chargedNow,false);
 assert.equal(result.permitIssuedNow,false);
 assert.deepEqual(calls[0].scope,{worldId:1,applicationId,airlineId});
 assert.deepEqual(calls[1].params,[applicationId,base.reviewEventId,base.reviewReference]);
 assert.match(calls[1].sql,/licence2_approve_application_atomic_v1/);
 assert.deepEqual(calls[2],{released:true});
});
test('forged, cross-company, cross-application, wrong level and fake producer never reach database',async()=>{
 for(const modified of [
  null,{...signed,signature:'f'.repeat(64)},
  {...signed,airlineId:'33333333-3333-4333-8333-333333333333'},
  {...signed,applicationId:'33333333-3333-4333-8333-333333333333'},
  {...signed,requestedLevel:2},
  {...signed,marketCode:'L2-US'},
  {...signed,decision:'reject'},
  {...signed,evidenceSource:'player_input'},
  {...signed,reviewedGameDay:'2026-11-18'},
  {...signed,reviewReference:'x'}
 ]){
  const {service,calls}=make(modified);
  const result=await service.approve(args);
  assert.equal(result.approvalCommitted,false);
  assert.equal(calls.some(x=>'sql' in x),false);
 }
});
test('rejects invalid review scope and forged DB approval outcome',async()=>{
 const {service,calls}=make(signed);
 assert.equal((await service.approve({...args,reviewedGameDay:'2026-02-30'})).reason,'INVALID_REVIEW_SCOPE');
 assert.equal(calls.length,0);
 const bad=make(signed,{status:'APPROVED_AND_CHARGED_ONCE',chargedNow:true,
  permitIssuedNow:true,chargedUsd:25000,reviewEventId:'wrong',
  applicationId,flightActivated:false});
 await assert.rejects(bad.service.approve(args),/LICENCE2_UNSAFE_REVIEW_WRITER_RESULT/);
 assert.deepEqual(bad.calls.at(-1),{released:true});
});
test('positive DB approval requires independently signed exact reviewed event and reconciled result',async()=>{
 const {service}=make(signed,{status:'APPROVED_AND_CHARGED_ONCE',
  chargedNow:true,permitIssuedNow:true,chargedUsd:25000,
  applicationId,reviewEventId:base.reviewEventId,flightActivated:false});
 const result=await service.approve(args);
 assert.equal(result.approvalCommitted,true);
 assert.equal(result.chargedUsd,25000);
 assert.equal(result.flightActivated,false);
});
