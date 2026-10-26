import test from 'node:test';
import assert from 'node:assert/strict';
import { onboardingNextStep } from '../server/onboarding-flow.mjs';

const user={id:'11111111-1111-4111-8111-111111111111',
  email_confirmed_at:'2026-10-26T10:00:00Z',is_anonymous:false};
const publishedPolicy={is_published:true,approved_at:'2026-10-26T09:00:00Z',
  terms_version:'terms-v1',privacy_version:'privacy-v1'};
const consent={terms_version:'terms-v1',privacy_version:'privacy-v1'};
const worlds=[
  {id:1,state:'registration_open'},
  {id:2,state:'planned'},
  {id:3,state:'planned'}
];
const valid=()=>({
  user,publishedPolicy,consent,worlds,
  selectedWorldId:1,approvedAirportIds:[101],
  selectedAirportId:101,evaluatedAt:'2026-10-26T12:00:00Z'
});

test('signed-out and unverified users cannot reach onboarding',()=>{
  assert.equal(onboardingNextStep().next,'sign_in');
  assert.equal(onboardingNextStep({...valid(),user:{...user,email_confirmed_at:null}}).next,
    'verify_email');
  assert.equal(onboardingNextStep({...valid(),user:{...user,is_anonymous:true}}).next,
    'account_restricted');
  assert.equal(onboardingNextStep({...valid(),user:{...user,deleted_at:'2026-10-25'}}).next,
    'account_restricted');
  assert.equal(onboardingNextStep({...valid(),user:{...user,banned_until:'2026-10-27'}}).next,
    'account_restricted');
});

test('legal policy must be published and current before onboarding',()=>{
  assert.equal(onboardingNextStep({...valid(),publishedPolicy:null}).next,
    'legal_unavailable');
  assert.equal(onboardingNextStep({...valid(),consent:null}).next,'accept_legal');
  const changed=onboardingNextStep({...valid(),
    publishedPolicy:{...publishedPolicy,terms_version:'terms-v2'}});
  assert.equal(changed.next,'accept_legal');
  assert.equal(changed.termsVersion,'terms-v2');
  assert.equal(changed.privacyVersion,'privacy-v1');
});

test('expired trial, suspended or past-due state blocks further world creation',()=>{
  for(const state of ['expired','past_due','suspended']){
    assert.equal(onboardingNextStep({...valid(),entitlement:{membership_state:state}}).next,
      'subscription_required');
  }
  assert.equal(onboardingNextStep({...valid(),entitlement:{
    membership_state:'trial',trial_ends_at:'2026-10-26T12:00:00Z'
  }}).next,'subscription_required');
  assert.equal(onboardingNextStep({...valid(),entitlement:{
    membership_state:'trial',trial_ends_at:'2026-10-26T12:01:00Z'
  }}).next,'ready_to_request_airline');
});

test('planned worlds cannot be joined and selection requires open world',()=>{
  assert.equal(onboardingNextStep({...valid(),worlds:[
    {id:1,state:'planned'},{id:2,state:'planned'},{id:3,state:'planned'}
  ]}).next,'worlds_unavailable');
  assert.deepEqual(onboardingNextStep({...valid(),selectedWorldId:null}),{
    next:'select_world',openWorldIds:[1]
  });
  assert.equal(onboardingNextStep({...valid(),selectedWorldId:2}).next,
    'world_unavailable');
  assert.equal(onboardingNextStep({...valid(),selectedWorldId:4}).next,
    'world_unavailable');
});

test('airport must be on the explicitly approved world roster',()=>{
  assert.equal(onboardingNextStep({...valid(),approvedAirportIds:[]}).next,
    'airports_unavailable');
  assert.equal(onboardingNextStep({...valid(),selectedAirportId:999}).next,
    'select_home_airport');
  assert.equal(onboardingNextStep(valid()).next,'ready_to_request_airline');
});

test('existing airline shows progress, never reissues money or starts trial',()=>{
  assert.deepEqual(onboardingNextStep({...valid(),existingAirline:{id:'airline-id'}}),{
    next:'airline_ready',airlineId:'airline-id'
  });
  assert.equal(onboardingNextStep({...valid(),existingAirline:{id:'airline-id'},
    entitlement:{membership_state:'past_due'}}).next,'subscription_required');
});

test('returns immutable display decisions, not backend privilege claims',()=>{
  const state=onboardingNextStep({...valid(),selectedWorldId:null});
  assert.ok(Object.isFrozen(state));
  assert.ok(Object.isFrozen(state.openWorldIds));
  assert.equal(state.canPlay,undefined);
  assert.equal(state.mayCreateAirline,undefined);
});
