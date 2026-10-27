import test from 'node:test';
import assert from 'node:assert/strict';
import {inspectCanonicalTesterAuthReadiness} from '../server/hosted-auth-readiness.mjs';
import {buildPrivatePreviewAccountApp} from '../server/preview-account-app.mjs';
import {AIRLINERRA_AUTH_API} from '../server/hosted-runtime-config.mjs';

const KEY='sb_publishable_'+('A'.repeat(32));
const safe={
  disable_signup:true,mailer_autoconfirm:false,
  external:{email:true,anonymous_users:false}
};
const env={
  AIRLINERRA_HOSTED_RUNTIME_MODE:'canonical-prelaunch-test',
  AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
  AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED:'true',
  AIRLINERRA_CANONICAL_TEST_ORIGIN:'https://airlinerra.com',
  CONTEXT:'production',
  AIRLINERRA_SUPABASE_URL:AIRLINERRA_AUTH_API,
  AIRLINERRA_SUPABASE_PUBLISHABLE_KEY:KEY,
  AIRLINERRA_PRIVATE_DATABASE_URL:
    'postgresql://postgres.hwllkabgzaynalahvkpz:synthetic-ci@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require',
  AIRLINERRA_TERMS_PATH:'/legal/terms-v1.html',
  AIRLINERRA_PRIVACY_PATH:'/legal/privacy-v1.html'
};
function response(body,status=200,contentType='application/json'){
  return new Response(JSON.stringify(body),{status,headers:{'content-type':contentType}});
}

test('auth settings check uses pinned project and public publishable key only',async()=>{
  let count=0;
  const verdict=await inspectCanonicalTesterAuthReadiness({
    publishableKey:KEY,
    fetchImpl:async(url,options)=>{
      count++;
      assert.equal(url,AIRLINERRA_AUTH_API+'/auth/v1/settings');
      assert.equal(options.method,'GET');
      assert.equal(options.headers.apikey,KEY);
      assert.equal(options.cache,'no-store');
      assert.equal(options.redirect,'error');
      assert.ok(options.signal);
      assert.equal(options.headers.authorization,undefined);
      return response(safe);
    }
  });
  assert.equal(count,1);
  assert.deepEqual(verdict,{inviteOnly:true,
    emailConfirmationRequired:true,anonymousSignupDisabled:true});
});

test('public signup, autoconfirm, disabled email, and anonymous accounts all deny prelaunch readiness',async()=>{
  for(const patch of [
    {disable_signup:false},
    {disable_signup:null},
    {mailer_autoconfirm:true},
    {mailer_autoconfirm:null},
    {external:{email:false,anonymous_users:false}},
    {external:{email:true,anonymous_users:true}},
    {external:null}
  ]){
    await assert.rejects(inspectCanonicalTesterAuthReadiness({
      publishableKey:KEY,fetchImpl:async()=>response({...safe,...patch})
    }),/must block public signup/);
  }
  await assert.rejects(inspectCanonicalTesterAuthReadiness({
    publishableKey:KEY,fetchImpl:async()=>response(safe,401)
  }),/Cannot verify/);
  await assert.rejects(inspectCanonicalTesterAuthReadiness({
    publishableKey:KEY,fetchImpl:async()=>{throw Error('private network failure');}
  }),/Cannot verify/);
  await assert.rejects(inspectCanonicalTesterAuthReadiness({
    publishableKey:'sb_secret_anything',fetchImpl:async()=>response(safe)
  }),/pinned public key/);
  await assert.rejects(inspectCanonicalTesterAuthReadiness({
    authUrl:'https://evil.example',publishableKey:KEY,fetchImpl:async()=>response(safe)
  }),/pinned public key/);
});

test('unsafe Supabase Auth settings prevent any PostgreSQL driver loading or connection',async()=>{
  let pgLoads=0;
  let settingsReads=0;
  await assert.rejects(buildPrivatePreviewAccountApp({
    env,
    loadPg:async()=>{pgLoads++;throw Error('MUST NEVER TOUCH POSTGRES');},
    fetchImpl:async(url)=>{
      settingsReads++;
      assert.equal(url,AIRLINERRA_AUTH_API+'/auth/v1/settings');
      return response({...safe,disable_signup:false});
    }
  }),/must block public signup/);
  assert.equal(settingsReads,1);
  assert.equal(pgLoads,0);
});

test('disabled server configuration does not call Auth settings or instantiate pg',async()=>{
  let calls=0;
  const app=await buildPrivatePreviewAccountApp({
    env:{...env,AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED:'false'},
    loadPg:async()=>{calls++;throw Error('not allowed');},
    fetchImpl:async()=>{calls++;throw Error('not allowed');}
  });
  assert.equal(app.enabled,false);
  assert.equal(calls,0);
  await app.close();
});
