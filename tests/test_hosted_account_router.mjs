import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createHostedAccountRouter,
  HOSTED_ACCOUNT_PATHS
} from '../server/hosted-account-router.mjs';
import {createHostedAccountStack} from '../server/hosted-account-stack.mjs';

const ORIGIN='https://airlinerra.example';
const userToken='synthetic-test-token-without-any-real-credentials';
const json=(path,body='{}',options={})=>
  new Request(ORIGIN+path,{
    method:options.method||'POST',
    headers:{
      origin:options.origin||ORIGIN,
      'content-type':options.contentType||'application/json',
      authorization:'Bearer '+userToken,
      ...(options.headers||{})
    },
    ...(options.method==='GET'?{}:{body})
  });

function mockHandlers() {
  const calls=[];
  const handlers=Object.fromEntries(HOSTED_ACCOUNT_PATHS.map(path=>
    [path,async request=>{
      calls.push(request);
      return {status:200,body:JSON.stringify({path:request.path,accepted:true})};
    }]
  ));
  return {calls,handlers};
}

test('default hosted router rejects without network, handlers or credentials',async()=>{
  const router=createHostedAccountRouter();
  const response=await router(json('/api/v1/airlines'));
  assert.equal(response.status,503);
  assert.equal(response.headers.get('cache-control'),'no-store');
  assert.equal(response.headers.get('access-control-allow-origin'),null);
  assert.match(await response.text(),/not available/);
});

test('enabled hosted router requires explicit HTTPS origin and all three private handlers',()=>{
  const {handlers}=mockHandlers();
  assert.throws(()=>createHostedAccountRouter({
    enabled:true,publicOrigin:'http://airlinerra.example',handlers
  }),/HTTPS/);
  assert.throws(()=>createHostedAccountRouter({
    enabled:true,publicOrigin:'https://localhost:5187',handlers
  }),/Public HTTPS/);
  assert.throws(()=>createHostedAccountRouter({
    enabled:true,publicOrigin:ORIGIN,handlers:{}
  }),/three trusted/);
});

test('three hosted requests delegate to injected private handlers, never elevate gates',async()=>{
  const {handlers,calls}=mockHandlers();
  const router=createHostedAccountRouter({enabled:true,publicOrigin:ORIGIN,handlers});
  for(const path of HOSTED_ACCOUNT_PATHS) {
    const response=await router(json(path,'{}'));
    assert.equal(response.status,200);
    assert.deepEqual(await response.json(),{path,accepted:true});
    assert.equal(response.headers.get('access-control-allow-origin'),null);
    assert.equal(response.headers.get('x-content-type-options'),'nosniff');
  }
  assert.deepEqual(calls.map(x=>x.path),HOSTED_ACCOUNT_PATHS);
  assert.ok(calls.every(x=>x.headers.authorization==='Bearer '+userToken));
});

test('cross-origin, redirect-like URLs and unsupported methods never reach backend',async()=>{
  const {handlers,calls}=mockHandlers();
  const router=createHostedAccountRouter({enabled:true,publicOrigin:ORIGIN,handlers});
  assert.equal((await router(json('/api/v1/airlines','{}',{
    origin:'https://untrusted.example'
  }))).status,403);
  assert.equal((await router(new Request('https://untrusted.example/api/v1/airlines',{
    method:'POST',headers:{origin:ORIGIN,'content-type':'application/json'},body:'{}'
  }))).status,403);
  assert.equal((await router(json('/api/v1/airlines?next=https://other.example'))).status,404);
  assert.equal((await router(json('/api/v1/nonexistent'))).status,404);
  assert.equal((await router(json('/api/v1/airlines','{}',{method:'GET'}))).status,405);
  assert.equal((await router(json('/api/v1/airlines','{}',{contentType:'text/plain'}))).status,415);
  assert.equal(calls.length,0);
});

test('oversized bodies and untrusted handler errors fail without leaking internals',async()=>{
  const {handlers,calls}=mockHandlers();
  const router=createHostedAccountRouter({enabled:true,publicOrigin:ORIGIN,handlers});
  const tooLarge=await router(json('/api/v1/airlines','x'.repeat(3000)));
  assert.equal(tooLarge.status,413);
  assert.equal(calls.length,0);
  handlers['/api/v1/airlines']=async()=>{
    throw new Error('private database password must never leak');
  };
  const next=createHostedAccountRouter({enabled:true,publicOrigin:ORIGIN,handlers});
  const response=await next(json('/api/v1/airlines'));
  assert.equal(response.status,503);
  assert.doesNotMatch(await response.text(),/password|database/i);
});

test('private handler status is preserved but CORS response headers are never trusted',async()=>{
  const {handlers}=mockHandlers();
  handlers['/api/v1/onboarding/context']=async()=>({
    status:401,
    headers:{'access-control-allow-origin':'*','set-cookie':'secret=x'},
    body:'{"error":"Verified account required."}'
  });
  const router=createHostedAccountRouter({enabled:true,publicOrigin:ORIGIN,handlers});
  const response=await router(json('/api/v1/onboarding/context'));
  assert.equal(response.status,401);
  assert.equal(response.headers.get('access-control-allow-origin'),null);
  assert.equal(response.headers.get('set-cookie'),null);
});

test('hosted account stack remains closed by default and requires private dependencies',async()=>{
  const closed=createHostedAccountStack();
  assert.equal((await closed(json('/api/v1/airlines'))).status,503);
  assert.throws(()=>createHostedAccountStack({
    enabled:true,publicOrigin:ORIGIN
  }),/Trusted hosted Auth/);
});
test('enabled hosted stack composes independent private handlers without granting airport access',async()=>{
  const state={dbCalls:0,verificationCalls:0};
  const database={
    async connect(){
      state.dbCalls++;
      return {
        async query(sql){
          if(sql.includes('platform_release_gate')) {
            return {rows:[{enabled:false,terms_version:null,privacy_version:null}]};
          }
          throw new Error('Private backend may not run unapproved SQL');
        },
        release(){}
      };
    }
  };
  const router=createHostedAccountStack({
    enabled:true,publicOrigin:ORIGIN,
    verifyUserToken:async()=>{
      state.verificationCalls++;
      return {user:{
        id:'11111111-1111-4111-8111-111111111111',
        email_confirmed_at:'2026-10-26T00:00:00Z',is_anonymous:false
      }};
    },
    database,termsPath:'/terms-v1.html',privacyPath:'/privacy-v1.html'
  });
  const noOrigin=await router(json('/api/v1/onboarding/context','{}',{origin:'https://bad.example'}));
  assert.equal(noOrigin.status,403);
  assert.equal(state.verificationCalls,0);
  assert.equal(state.dbCalls,0);
  const held=await router(json('/api/v1/onboarding/context'));
  assert.equal(held.status,503,'disabled operator release prevents context');
  assert.equal(state.verificationCalls,1);
  assert.equal(state.dbCalls,1);
});
