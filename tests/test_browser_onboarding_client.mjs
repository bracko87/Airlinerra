import test from 'node:test';
import assert from 'node:assert/strict';
import { createOnboardingApiClient } from '../website/onboarding-api-client.mjs';
import { validatedDevelopmentAuthConfig, createBrowserAuthClient } from '../website/auth-client.mjs';

const ORIGIN='http://localhost:5187';
const DEV_HOST='https://devabcdefghij123456.supabase.co';
const PUBLISHABLE='sb_publishable_1234567890_abcdefghijklmnopqrstuvwxyz';
const USER={id:'11111111-1111-4111-8111-111111111111',
  email_confirmed_at:'2026-10-26T10:00:00Z',is_anonymous:false};
const SESSION={access_token:'mock.valid.token.for.local.tests.only',user:{id:USER.id}};
const LEGAL={termsVersion:'test-v1',privacyVersion:'test-v1',
  acceptTerms:true,acceptPrivacy:true};
const AIRLINE={worldId:1,airlineName:'Aurelia Airways',homeAirportKey:'OURAIRPORTS:101'};
function setup({enabled=true,user=USER,session=SESSION,status=201,reply={airlineId:USER,newlyCreated:true,cashUsd:'5000000.00'}}={}) {
  const calls=[];
  const supabase={auth:{
    getUser:async()=>{calls.push(['getUser']);return {data:{user},error:null};},
    getSession:async()=>{calls.push(['getSession']);return {data:{session},error:null};}
  }};
  const fetchImpl=async(url,options)=>{
    calls.push(['fetch',url,options]);
    return {status,json:async()=>reply};
  };
  return {calls,client:createOnboardingApiClient({
    supabase,origin:ORIGIN,enabled,fetchImpl
  })};
}
test('the airport research project URL is never an Auth development target',()=>{
  const data=validatedDevelopmentAuthConfig({
    supabaseUrl:DEV_HOST,publishableKey:PUBLISHABLE
  });
  assert.deepEqual(data,{supabaseUrl:DEV_HOST,publishableKey:PUBLISHABLE});
  assert.ok(Object.isFrozen(data));
  assert.throws(()=>validatedDevelopmentAuthConfig({
    supabaseUrl:'https://hwllkabgzaynalahvkpz.supabase.co',
    publishableKey:PUBLISHABLE
  }),/separate development/);
  for(const supabaseUrl of ['https://evil.example','http://devabcdefghij123456.supabase.co',
      DEV_HOST+'/auth/v1','https://a.example@devabcdefghij123456.supabase.co',
      DEV_HOST+'?x=1']) {
    assert.throws(()=>validatedDevelopmentAuthConfig({
      supabaseUrl,publishableKey:PUBLISHABLE
    }),/development/);
  }
  assert.throws(()=>validatedDevelopmentAuthConfig({
    supabaseUrl:DEV_HOST,publishableKey:'sb_secret_untrusted'
  }),/publishable/);
  assert.equal(validatedDevelopmentAuthConfig({
    supabaseUrl:'http://127.0.0.1:54321',publishableKey:PUBLISHABLE
  }).supabaseUrl,'http://127.0.0.1:54321');
});
test('hard-off Auth SDK never loads or contacts any Supabase project',async()=>{
  let loads=0;
  await assert.rejects(createBrowserAuthClient({
    origin:ORIGIN,enabled:true,supabaseUrl:DEV_HOST,publishableKey:PUBLISHABLE,
    loadSdk:async()=>{loads++;return {createClient:()=>({})};}
  }),/not yet open/);
  assert.equal(loads,0);
});
test('default onboarding bridge prevents any Auth or API traffic',async()=>{
  const {calls,client}=setup({enabled:false});
  await assert.rejects(client.createAirline(AIRLINE),/not yet open/);
  await assert.rejects(client.acceptLegal(LEGAL),/not yet open/);
  assert.equal(calls.length,0);
});
test('verified same-user session transmits bearer only to same-origin protected route',async()=>{
  const x=setup();
  const result=await x.client.createAirline(AIRLINE);
  assert.equal(result.cashUsd,'5000000.00');
  assert.deepEqual(x.calls.map(c=>c[0]),['getUser','getSession','fetch']);
  const [,url,req]=x.calls[2];
  assert.equal(url,ORIGIN+'/api/v1/airlines');
  assert.equal(req.method,'POST');
  assert.equal(req.credentials,'omit');
  assert.equal(req.mode,'same-origin');
  assert.equal(req.redirect,'error');
  assert.equal(req.cache,'no-store');
  assert.equal(req.headers.authorization,'Bearer '+SESSION.access_token);
  assert.deepEqual(JSON.parse(req.body),AIRLINE);
  assert.equal(Object.hasOwn(JSON.parse(req.body),'playerId'),false);
});
test('legal acceptance sends explicitly accepted current policy versions',async()=>{
  const x=setup({status:200,reply:{termsVersion:'test-v1',privacyVersion:'test-v1',
    acceptedAt:'2026-10-26T16:00:00Z'}});
  assert.equal((await x.client.acceptLegal(LEGAL)).termsVersion,'test-v1');
  assert.equal(x.calls[2][1],ORIGIN+'/api/v1/legal/consents');
  assert.deepEqual(JSON.parse(x.calls[2][2].body),LEGAL);
});
test('unverified or mismatched session never reaches private backend',async()=>{
  for(const bad of [
    {user:{...USER,email_confirmed_at:null},session:SESSION},
    {user:{...USER,is_anonymous:true},session:SESSION},
    {user:{...USER,deleted_at:'2026-10-26'},session:SESSION},
    {user:USER,session:{...SESSION,user:{id:'different-account'}}},
    {user:USER,session:null}
  ]) {
    const x=setup(bad);
    await assert.rejects(x.client.createAirline(AIRLINE),/verified account|login session/);
    assert.equal(x.calls.some(c=>c[0]==='fetch'),false);
  }
});
test('invalid airline keys and world IDs are rejected before Auth calls',async()=>{
  for(const data of [
    {...AIRLINE,worldId:4},
    {...AIRLINE,worldId:'1'},
    {...AIRLINE,homeAirportKey:'101'},
    {...AIRLINE,homeAirportKey:'OURAIRPORTS:0'},
    {...AIRLINE,homeAirportKey:'OURAIRPORTS:1;DROP TABLE'},
    {...AIRLINE,airlineName:'<script>'}
  ]) {
    const x=setup();
    assert.throws(()=>x.client.createAirline(data),/Select an eligible|invalid/);
    assert.equal(x.calls.length,0);
  }
});
test('fictional airport is accepted as identifier, but only server decides approval',async()=>{
  const x=setup();
  await x.client.createAirline({
    worldId:2,airlineName:'Aleksandrovo Air',
    homeAirportKey:'FICTIONAL:fictional:RS:LYAL'
  });
  assert.equal(JSON.parse(x.calls[2][2].body).homeAirportKey,'FICTIONAL:fictional:RS:LYAL');
});
test('legal acceptance must be explicit and versioned',async()=>{
  for(const input of [
    {...LEGAL,acceptTerms:false},
    {...LEGAL,acceptPrivacy:false},
    {...LEGAL,termsVersion:'draft with spaces'},
    {...LEGAL,privacyVersion:''}
  ]){
    const x=setup();
    assert.throws(()=>x.client.acceptLegal(input),/Review and explicitly accept/);
    assert.equal(x.calls.length,0);
  }
});
test('409 policy conflict and 401 rejected session return actionable safe errors',async()=>{
  const conflict=setup({status:409,reply:{error:'SECRET SQL INTERNALS'}});
  await assert.rejects(conflict.client.acceptLegal(LEGAL),/information has changed/);
  const invalid=setup({status:401});
  await assert.rejects(invalid.client.createAirline(AIRLINE),/sign in again/);
  const down=setup({status:503});
  await assert.rejects(down.client.createAirline(AIRLINE),/currently unavailable/);
});
test('network failures do not leak tokens, SQL errors or raw response details',async()=>{
  const x=createOnboardingApiClient({supabase:{auth:{
    getUser:async()=>({data:{user:USER},error:null}),
    getSession:async()=>({data:{session:SESSION},error:null})
  }},origin:ORIGIN,enabled:true,fetchImpl:async()=>{throw Error('SECRET_DATABASE_PASSWORD');}});
  await assert.rejects(x.createAirline(AIRLINE),/currently unavailable/);
  const mismatch=createOnboardingApiClient({supabase:{auth:{
    getUser:async()=>({data:{user:USER},error:null}),
    getSession:async()=>({data:{session:SESSION},error:null})
  }},origin:'https://attacker.example',enabled:true,fetchImpl:()=>{throw Error('should not run')}});
  await assert.rejects(mismatch.createAirline(AIRLINE),/origin is not authorized/);
});
