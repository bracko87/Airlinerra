import test from 'node:test';
import assert from 'node:assert/strict';
import {AOC_RULES,aocDayNumber,aocAddDays,aocEligibleBusinessKind,
 aocIssueEligibility,aocSafetySnapshot,aocCorrectionCompleted,
 aocRenewalDecision} from '../server/section9-aoc-policy.mjs';

const P='11111111-1111-4111-8111-111111111111';
const C='22222222-2222-4222-8222-222222222222';
const D='2026-11-17';
const base=(airlineId=P,kind='passenger')=>({
 airlineId,companyKind:kind,companySource:'original',
 certificate:{airlineId,status:'active',issuedGameDay:D,
  expiresGameDay:'2027-11-17',remindedForExpiry:null},
 gameDay:D,safety:{airlineId,gameDay:D,rating:100},
 verifiedGameClock:true,releaseEnabled:true
});
const event=(eventId,airlineId=P,severity='serious')=>({
 eventId,airlineId,severity,verified:true,gameDay:D,
 status:'unresolved'
});
const fix=incidentEventId=>({
 status:'completed',verifiedCompletion:true,incidentEventId,
 completionReceiptId:'maintenance-finished-0001',
 paidLedgerEntryId:'123',costUsd:1800,paidUsd:1800
});

test('only airline businesses get their OWN AOC, never holding, academy or MRO',()=>{
 assert.deepEqual(AOC_RULES.eligibleKinds,['passenger','regional','low_cost','cargo','charter','vip']);
 for(const kind of ['passenger','cargo','charter','vip','regional','low_cost']){
  assert.equal(aocEligibleBusinessKind(kind),true);
  assert.equal(aocIssueEligibility({kind,companySource:'original',
   verifiedOriginal:true,releaseEnabled:true}).feeUsd,0);
  assert.deepEqual(aocIssueEligibility({kind,companySource:'subsidiary',
   verifiedSubsidiary:true,releaseEnabled:true}),
   {status:'apply_subsidiary',eligible:true,feeUsd:10000,processingGameDays:3});
 }
 for(const kind of ['holding','academy','maintenance','mro','training',null]){
  assert.equal(aocEligibleBusinessKind(kind),false);
  assert.equal(aocIssueEligibility({kind,companySource:'original',
   verifiedOriginal:true,releaseEnabled:true}).status,'not_applicable');
 }
 assert.equal(aocIssueEligibility({kind:'cargo',companySource:'subsidiary',
  verifiedSubsidiary:true}).status,'not_released');
 assert.equal(aocIssueEligibility({kind:'passenger',companySource:'original',
  releaseEnabled:true}).eligible,false);
});

test('game dates are strict, timezone-independent, exact 365-day validity',()=>{
 assert.equal(aocAddDays('2026-11-17',365),'2027-11-17');
 assert.equal(aocAddDays('2026-11-17',275),'2027-08-19');
 assert.equal(aocAddDays('2028-02-28',1),'2028-02-29');
 assert.equal(aocDayNumber('2028-03-01')-aocDayNumber('2028-02-28'),2);
 for(const bad of ['2026-02-29','2026-13-01','2026-00-01','2026-11-31','11/17/2026',null]){
  assert.throws(()=>aocDayNumber(bad),/AOC_INVALID_GAME_DATE/);
 }
});

test('zero outstanding incidents ALWAYS produces Safety Rating 100',()=>{
 const empty=aocSafetySnapshot({airlineId:P,incidents:[],gameDay:D});
 assert.equal(empty.rating,100);
 assert.equal(empty.unresolved,0);
 assert.equal(empty.initialBaseline,true);
 const resolved={...event('incident-paid-001'),status:'resolved',
  correction:fix('incident-paid-001')};
 const clean=aocSafetySnapshot({airlineId:P,incidents:[resolved],gameDay:D});
 assert.equal(clean.rating,100);
 assert.equal(clean.unresolved,0);
 assert.equal(clean.lifetime,1,'history persists even when corrected');
 assert.equal(clean.initialBaseline,false);
});

test('safety rating counts ONLY unresolved verified events from SAME company',()=>{
 const incidents=[
  event('incident-airline-01',P,'minor'),
  event('incident-airline-02',P,'serious'),
  event('incident-airline-03',P,'major'),
  event('incident-other-04',C,'major')
 ];
 const s=aocSafetySnapshot({airlineId:P,incidents,gameDay:D});
 assert.equal(s.rating,45);
 assert.equal(s.unresolved,3);
 assert.equal(s.lifetime,3);
 assert.equal(s.last365GameDays,3);
 const other=aocSafetySnapshot({airlineId:C,incidents,gameDay:D});
 assert.equal(other.rating,70);
 assert.equal(other.unresolved,1);
 assert.equal(other.lifetime,1);
});

test('paying without independent completion does NOT restore any safety rating',()=>{
 const initial=[event('incident-serious-01'),event('incident-serious-02')];
 assert.equal(aocSafetySnapshot({airlineId:P,incidents:initial,gameDay:D}).rating,60);
 const paidOnly={...fix('incident-serious-01'),status:'paid',verifiedCompletion:false};
 assert.equal(aocCorrectionCompleted(paidOnly),false);
 let partial=aocSafetySnapshot({airlineId:P,gameDay:D,incidents:[
  {...initial[0],status:'resolved',correction:paidOnly},initial[1]
 ]});
 assert.equal(partial.rating,60);
 partial=aocSafetySnapshot({airlineId:P,gameDay:D,incidents:[
  {...initial[0],status:'resolved',correction:fix('incident-serious-01')},
  initial[1]
 ]});
 assert.equal(partial.rating,80);
 assert.equal(partial.unresolved,1);
 let all=aocSafetySnapshot({airlineId:P,gameDay:D,incidents:initial.map(e=>({
  ...e,status:'resolved',correction:fix(e.eventId)
 }))});
 assert.equal(all.rating,100);
 assert.equal(all.lifetime,2);
});

test('unpaid, free or mismatched corrective work cannot clear an incident',()=>{
 const good=fix('incident-serious-01');
 for(const bad of [
  {...good,costUsd:0,paidUsd:0},{...good,paidUsd:0},
  {...good,paidLedgerEntryId:null},{...good,completionReceiptId:null},
  {...good,verifiedCompletion:false},{...good,status:'booked'},
  {...good,incidentEventId:'wrong-event-12345'},
 ]){
  const s=aocSafetySnapshot({airlineId:P,gameDay:D,incidents:[
   {...event('incident-serious-01'),status:'resolved',correction:bad}
  ]});
  assert.equal(s.rating,20===AOC_RULES.incidentPenalties.serious?80:0);
 }
 assert.equal(aocCorrectionCompleted(good),true);
});

test('reject forged evidence, bad dates and duplicate incident identity',()=>{
 assert.throws(()=>aocSafetySnapshot({airlineId:P,gameDay:D,incidents:[
  {...event('incident-serious-01'),verified:false}
 ]}),/AOC_UNVERIFIED_INCIDENT/);
 assert.throws(()=>aocSafetySnapshot({airlineId:P,gameDay:D,incidents:[
  event('incident-serious-01'),event('incident-serious-01')
 ]}),/AOC_DUPLICATE_INCIDENT_EVENT/);
 assert.throws(()=>aocSafetySnapshot({airlineId:P,gameDay:D,incidents:[
  {...event('incident-serious-01'),gameDay:'2027-01-01'}
 ]}),/AOC_INCIDENT_FUTURE_DAY/);
});

test('reminder is 90 days before expiry exactly once',()=>{
 const a=base();
 assert.equal(aocRenewalDecision({...a,gameDay:'2027-08-18',
  safety:{airlineId:P,gameDay:'2027-08-18',rating:100}}).status,'active');
 const due=aocRenewalDecision({...a,gameDay:'2027-08-19',
  safety:{airlineId:P,gameDay:'2027-08-19',rating:100}});
 assert.equal(due.status,'reminder_due');
 assert.equal(due.change,true);
 const repeat=aocRenewalDecision({...a,gameDay:'2027-08-19',
  certificate:{...a.certificate,remindedForExpiry:'2027-11-17'},
  safety:{airlineId:P,gameDay:'2027-08-19',rating:100}});
 assert.equal(repeat.status,'active');
 assert.equal(repeat.change,false);
});

test('automatic renewal passes at 70, fails at 69; no flight requirement',()=>{
 const day='2027-11-17';
 const a=base();
 const eligible=aocRenewalDecision({...a,gameDay:day,
  safety:{airlineId:P,gameDay:day,rating:70}});
 assert.equal(eligible.status,'renew');
 assert.equal(eligible.feeUsd,0);
 assert.equal(eligible.expiresGameDay,'2028-11-16');
 const failed=aocRenewalDecision({...a,gameDay:day,
  safety:{airlineId:P,gameDay:day,rating:69}});
 assert.equal(failed.status,'expire');
 assert.equal(failed.retainAssetsAndRoutes,true);
});

test('expired cargo can reinstate without flights, sister passenger stays valid',()=>{
 const day='2027-11-18',cargo=base(C,'cargo');
 const expired={...cargo,gameDay:day,certificate:{
  ...cargo.certificate,status:'expired'},
  safety:{airlineId:C,gameDay:day,rating:60}};
 assert.equal(aocRenewalDecision(expired).status,'expired_waiting_for_paid_corrections');
 const corrected=aocRenewalDecision({...expired,
  safety:{airlineId:C,gameDay:day,rating:80}});
 assert.equal(corrected.status,'reinstate');
 assert.equal(corrected.feeUsd,0);
 assert.equal(corrected.expiresGameDay,'2028-11-17');
 const sister=base(P,'passenger');
 const active=aocRenewalDecision(sister);
 assert.equal(active.status,'active');
 assert.equal(active.change,false);
});

test('clock / release / ownership mismatch can never issue, renew, or change money',()=>{
 const a=base();
 assert.equal(aocRenewalDecision({...a,releaseEnabled:false}).status,'not_released');
 assert.equal(aocRenewalDecision({...a,verifiedGameClock:false}).status,'blocked_unverified_game_clock');
 assert.equal(aocRenewalDecision({...a,companyKind:'academy'}).status,'not_applicable');
 assert.equal(aocRenewalDecision({...a,certificate:{...a.certificate,airlineId:C}}).status,
  'blocked_missing_company_certificate');
 assert.equal(aocRenewalDecision({...a,safety:{...a.safety,airlineId:C}}).status,
  'blocked_unverified_safety_score');
 assert.equal(aocRenewalDecision({...a,companySource:'holding'}).status,
  'blocked_unverified_company_kind');
});
