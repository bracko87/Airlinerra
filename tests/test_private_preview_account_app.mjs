import test from 'node:test';
import assert from 'node:assert/strict';
import {parseHostedRuntimeConfig,AIRLINERRA_AUTH_API} from '../server/hosted-runtime-config.mjs';
import {createHostedAuthVerifier} from '../server/hosted-auth-verifier.mjs';
import {buildPrivatePreviewAccountApp} from '../server/preview-account-app.mjs';

const TOKEN='synthetic-fully-formed-session-token-for-tests';
const KEY='sb_publishable_'+('A'.repeat(32));
const PROJECT='hwllkabgzaynalahvkpz';
const ORIGIN='https://airlinerra-preview.example';
const USER='11111111-1111-4111-8111-111111111111';
const goodEnv=()=>({
  CONTEXT:'deploy-preview',
  AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
  AIRLINERRA_PRIVATE_PREVIEW_APPROVED:'true',
  AIRLINERRA_PREVIEW_ORIGIN:ORIGIN,
  AIRLINERRA_SUPABASE_URL:AIRLINERRA_AUTH_API,
  AIRLINERRA_SUPABASE_PUBLISHABLE_KEY:KEY,
  AIRLINERRA_PRIVATE_DATABASE_URL:
    'postgresql://postgres.'+PROJECT+':synthetic-not-real@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require',
  AIRLINERRA_TERMS_PATH:'/legal/terms-v1.html',
  AIRLINERRA_PRIVACY_PATH:'/legal/privacy-v1.html'
});
const request=(path,body='{}',origin=ORIGIN)=>new Request(ORIGIN+path,{
  method:'POST',
  headers:{origin,'content-type':'application/json',
    authorization:'Bearer '+TOKEN},
  body
});

test('disabled preview is truly inert and does not inspect any secret field',async()=>{
  const env={AIRLINERRA_HOSTED_BACKEND_ENABLED:'false',CONTEXT:'production'};
  Object.defineProperty(env,'AIRLINERRA_PRIVATE_DATABASE_URL',{get(){
    throw Error('PRIVATE DATABASE URL MUST NEVER BE READ');
  }});
  const parsed=parseHostedRuntimeConfig(env);
  assert.deepEqual(parsed,{enabled:false});
  const app=await buildPrivatePreviewAccountApp({
    env,
    loadPg:async()=>{throw Error('MUST NOT LOAD DRIVER');},
    fetchImpl:async()=>{throw Error('MUST NOT FETCH AUTH');}
  });
  assert.equal(app.enabled,false);
  assert.equal((await app.handler(request('/api/v1/airlines'))).status,503);
  await app.close();
});

test('both operator toggles and a nonproduction context are mandatory',()=>{
  const env=goodEnv();
  for(const key of ['AIRLINERRA_HOSTED_BACKEND_ENABLED','AIRLINERRA_PRIVATE_PREVIEW_APPROVED']){
    const modified={...env,[key]:'false'};
    assert.deepEqual(parseHostedRuntimeConfig(modified),{enabled:false});
  }
  for(const context of ['production','dev','']) {
    assert.throws(()=>parseHostedRuntimeConfig({...env,CONTEXT:context}),/forbidden/);
  }
  assert.equal(parseHostedRuntimeConfig(env).enabled,true);
});

test('pinned Auth URL, HTTPS origin, public key and legal files fail closed',()=>{
  const base=goodEnv();
  for(const fields of [
    {AIRLINERRA_PREVIEW_ORIGIN:'http://airlinerra-preview.example'},
    {AIRLINERRA_SUPABASE_URL:'https://some-other-project.supabase.co'},
    {AIRLINERRA_SUPABASE_PUBLISHABLE_KEY:'service-secret'},
    {AIRLINERRA_TERMS_PATH:'/ci-test-terms.html'},
    {AIRLINERRA_PRIVACY_PATH:'/legal/terms-v1.html',
      AIRLINERRA_TERMS_PATH:'/legal/terms-v1.html'}
  ]) {
    assert.throws(()=>parseHostedRuntimeConfig({...base,...fields}));
  }
});

test('PostgreSQL must belong to this project, require credentials/TLS and pin port',()=>{
  const base=goodEnv();
  assert.throws(()=>parseHostedRuntimeConfig({
    ...base,AIRLINERRA_PRIVATE_DATABASE_URL:
      'postgresql://postgres:pass@db.some-other.supabase.co:5432/postgres'
  }),/Airlinerra project/);
  assert.throws(()=>parseHostedRuntimeConfig({
    ...base,AIRLINERRA_PRIVATE_DATABASE_URL:
      'postgresql://postgres.'+PROJECT+':pass@aws-0-eu-central-1.pooler.supabase.com:7777/postgres'
  }),/port/);
  assert.throws(()=>parseHostedRuntimeConfig({
    ...base,AIRLINERRA_PRIVATE_DATABASE_URL:
      'postgresql://postgres.'+PROJECT+'@aws-0-eu-central-1.pooler.supabase.com:6543/postgres'
  }),/PostgreSQL/);
  assert.ok(parseHostedRuntimeConfig(base).dbUrl.includes('synthetic-not-real'));
});

test('fresh hosted Auth verification rejects revoked, unconfirmed and anonymous users',async()=>{
  const calls=[];
  let active={
    id:USER,email_confirmed_at:'2026-10-27T00:00:00Z',is_anonymous:false
  };
  const fetchImpl=async (url,options)=>{
    calls.push({url,method:options.method,key:options.headers.apikey,
      bearer:options.headers.authorization,redirect:options.redirect,
      cache:options.cache});
    return new Response(JSON.stringify(active),{
      status:active?200:401,
      headers:{'content-type':'application/json'}
    });
  };
  const verify=createHostedAuthVerifier({publishableKey:KEY,fetchImpl});
  const ok=await verify(TOKEN);
  assert.equal(ok.user.id,USER);
  assert.equal(ok.error,null);
  assert.deepEqual(calls[0],{
    url:AIRLINERRA_AUTH_API+'/auth/v1/user',
    method:'GET',key:KEY,bearer:'Bearer '+TOKEN,
    redirect:'error',cache:'no-store'
  });
  active={id:USER,email_confirmed_at:null,is_anonymous:false};
  assert.equal((await verify(TOKEN)).user,null);
  active={id:USER,email_confirmed_at:'2026-10-27T00:00:00Z',is_anonymous:true};
  assert.equal((await verify(TOKEN)).user,null);
  active=null;
  assert.equal((await verify(TOKEN)).user,null);
  assert.equal((await verify('short')).user,null);
});

test('hosted Auth upstream exceptions do not expose JWTs or underlying errors',async()=>{
  const verify=createHostedAuthVerifier({
    publishableKey:KEY,
    fetchImpl:async()=>{throw Error('secret-token-'+TOKEN);}
  });
  const result=await verify(TOKEN);
  assert.equal(result.user,null);
  assert.equal(result.error.code,'unavailable');
  assert.ok(!JSON.stringify(result).includes(TOKEN));
});

test('enabled private preview builds a bounded TLS pool and still honors closed DB release',async()=>{
  let dbConnections=0,dbQueries=0,finished=0,authFetches=0;
  class Pool {
    constructor(config) {
      assert.equal(config.max,2);
      assert.equal(config.ssl.rejectUnauthorized,true);
      assert.equal(config.statement_timeout,8000);
      assert.equal(config.query_timeout,10000);
      assert.ok(config.connectionString.includes(PROJECT));
    }
    async connect(){
      dbConnections++;
      return {
        async query(sql){
          dbQueries++;
          if(String(sql).includes('platform_release_gate'))return {rows:[{
            enabled:false,terms_version:null,privacy_version:null
          }]};
          throw Error('MUST NOT read closed-world airport catalog');
        },
        release(){}
      };
    }
    async end(){finished++;}
  }
  const app=await buildPrivatePreviewAccountApp({
    env:goodEnv(),
    loadPg:async()=>({Pool}),
    fetchImpl:async()=>{
      authFetches++;
      return new Response(JSON.stringify({
        id:USER,email_confirmed_at:'2026-10-27T00:00:00Z',is_anonymous:false
      }),{status:200,headers:{'content-type':'application/json'}});
    }
  });
  assert.equal(app.enabled,true);
  const crossOrigin=await app.handler(request('/api/v1/onboarding/context','{}','https://other.example'));
  assert.equal(crossOrigin.status,403);
  assert.equal(dbConnections,0);
  assert.equal(authFetches,0);
  const closed=await app.handler(request('/api/v1/onboarding/context'));
  assert.equal(closed.status,503);
  assert.equal(dbConnections,1);
  assert.equal(dbQueries,1);
  assert.equal(authFetches,1);
  assert.equal((await app.handler(request('/api/v1/airlines','{}'))).status,400);
  await app.close();
  assert.equal(finished,1);
});
