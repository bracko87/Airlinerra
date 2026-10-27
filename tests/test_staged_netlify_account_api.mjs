import test from 'node:test';
import assert from 'node:assert/strict';
import {
  config,
  createStagedNetlifyAccountHandler
} from '../server/netlify-preview-template/airlinerra-accounts.mjs';
import {buildPrivatePreviewAccountApp} from '../server/preview-account-app.mjs';

const ORIGIN='https://deploy-preview-19--airlinerra.netlify.app';
const request=()=>new Request(ORIGIN+'/api/v1/onboarding/context',{
  method:'POST',
  headers:{origin:ORIGIN,'content-type':'application/json',
    authorization:'Bearer synthetic-test-token-long-enough'},
  body:'{}'
});
const env=()=>({
  AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
  AIRLINERRA_PRIVATE_PREVIEW_APPROVED:'true',
  CONTEXT:'deploy-preview'
});

test('staged Netlify URL config covers exactly three POST API routes',()=>{
  assert.deepEqual(config,{
    path:['/api/v1/onboarding/context','/api/v1/legal/consents','/api/v1/airlines'],
    method:'POST'
  });
});

test('default staging handler fails closed and never reads secrets or builds app',async()=>{
  let builds=0;
  const environment={
    AIRLINERRA_HOSTED_BACKEND_ENABLED:'false',
    AIRLINERRA_PRIVATE_PREVIEW_APPROVED:'false'
  };
  Object.defineProperty(environment,'AIRLINERRA_PRIVATE_DATABASE_URL',{get(){
    throw Error('Secret must not be read when disabled');
  }});
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:()=>environment,
    buildApp:()=>{builds++;throw Error('Should never start');}
  });
  for(let i=0;i<3;i++){
    const response=await handler(request());
    assert.equal(response.status,503);
    assert.equal(response.headers.get('cache-control'),'no-store');
    assert.equal(response.headers.get('content-security-policy'),"default-src 'none'");
    assert.equal(response.headers.get('access-control-allow-origin'),null);
    assert.ok(!(await response.text()).includes('Secret'));
  }
  assert.equal(builds,0);
});

test('two independent enable flags are required on every invocation',async()=>{
  let builds=0;
  const e=env();
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:()=>e,
    buildApp:async()=>{builds++;return {enabled:true,handler:async()=>new Response('{}',{status:200})};}
  });
  e.AIRLINERRA_HOSTED_BACKEND_ENABLED='false';
  assert.equal((await handler(request())).status,503);
  e.AIRLINERRA_HOSTED_BACKEND_ENABLED='true';
  e.AIRLINERRA_PRIVATE_PREVIEW_APPROVED='false';
  assert.equal((await handler(request())).status,503);
  assert.equal(builds,0);
  e.AIRLINERRA_PRIVATE_PREVIEW_APPROVED='true';
  assert.equal((await handler(request())).status,200);
  assert.equal(builds,1);
  e.AIRLINERRA_PRIVATE_PREVIEW_APPROVED='false';
  assert.equal((await handler(request())).status,503);
  assert.equal(builds,1);
});

test('warm staging function reuses one app/pool for concurrent invocations',async()=>{
  let builds=0,calls=0;
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:env,
    buildApp:async()=>{
      builds++;
      await Promise.resolve();
      return {enabled:true,handler:async()=>{calls++;return new Response('{"ok":true}',{
        status:200,headers:{'content-type':'application/json'}
      });}};
    }
  });
  const responses=await Promise.all(Array.from({length:9},()=>handler(request())));
  assert.ok(responses.every(r=>r.status===200));
  assert.equal(builds,1);
  assert.equal(calls,9);
});

test('staging function redacts internal startup and handler failures',async()=>{
  let attempts=0;
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:env,
    buildApp:async()=>{
      attempts++;
      if(attempts===1)throw Error('postgresql://postgres:supersecret@db.example');
      return {enabled:true,handler:async()=>{throw Error('db private token');}};
    }
  });
  const first=await handler(request());
  const second=await handler(request());
  assert.equal(first.status,503);
  assert.equal(second.status,503);
  const bodies=[await first.text(),await second.text()];
  assert.ok(bodies.every(x=>!x.includes('postgresql:')&&!x.includes('token')&&!x.includes('supersecret')));
  assert.equal(attempts,2);
});

test('production context cannot create an app even with both flags enabled',async()=>{
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:()=>({...env(),CONTEXT:'production'}),
    buildApp:options=>buildPrivatePreviewAccountApp({
      env:options.env,
      loadPg:async()=>{throw Error('Driver must not be loaded in production');}
    })
  });
  const response=await handler(request());
  assert.equal(response.status,503);
  assert.equal(response.headers.get('cache-control'),'no-store');
});

test('pinned public airlinerra.com is forbidden as a private-preview origin',async()=>{
  const runtime=(await import('../server/hosted-runtime-config.mjs')).parseHostedRuntimeConfig;
  const base={
    CONTEXT:'deploy-preview',
    AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
    AIRLINERRA_PRIVATE_PREVIEW_APPROVED:'true'
  };
  for(const hostname of ['airlinerra.com','www.airlinerra.com','airlinerra.netlify.app']){
    assert.throws(()=>runtime({...base,AIRLINERRA_PREVIEW_ORIGIN:'https://'+hostname}),
      /production origin/);
  }
});
