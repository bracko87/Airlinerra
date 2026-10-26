import test from 'node:test';
import assert from 'node:assert/strict';
import { createLegalConsentHttpHandler, parseConsentRequest }
  from '../server/legal-consent-http-handler.mjs';

const ORIGIN='http://localhost:5187';
const TOKEN='synthetic-session-test-token-12345';
const legal = {
  termsVersion:'legal-v1',privacyVersion:'privacy-v1',
  acceptTerms:true,acceptPrivacy:true
};
const sample = () => ({
  path:'/api/v1/legal/consents',
  method:'POST',
  headers:{
    origin:ORIGIN,
    'content-type':'application/json',
    authorization:'Bearer '+TOKEN
  },
  body:JSON.stringify(legal)
});
function setup({enabled=false, error=null, receipt=null}={}) {
  const calls=[];
  const service={
    async acceptPublishedPolicy(payload) {
      calls.push(payload);
      if(error)throw error;
      return receipt || {
        termsVersion:'legal-v1',privacyVersion:'privacy-v1',
        acceptedAt:'2026-10-26T11:25:00Z'
      };
    }
  };
  return { calls, handle:createLegalConsentHttpHandler({
    consentService:service,enabled,allowedOrigins:[ORIGIN]
  })};
}

test('disabled handler does not call consent backend', async()=>{
  const {calls,handle}=setup();
  assert.equal((await handle(sample())).status,503);
  assert.equal(calls.length,0);
});

test('wrong path and methods are rejected without service calls', async()=>{
  const {handle,calls}=setup({enabled:true});
  assert.equal((await handle({...sample(),path:'/api/admin'})).status,404);
  assert.equal((await handle({...sample(),method:'GET'})).status,405);
  assert.equal(calls.length,0);
});

test('untrusted and absent origins are rejected', async()=>{
  const {handle,calls}=setup({enabled:true});
  for(const origin of ['null','https://attacker.invalid',undefined]) {
    const req=sample();
    if(origin)req.headers.origin=origin;
    else delete req.headers.origin;
    const resp=await handle(req);
    assert.equal(resp.status,403);
    assert.equal(resp.headers['access-control-allow-origin'],undefined);
  }
  assert.equal(calls.length,0);
});

test('content type and access token must both be present', async()=>{
  const {handle,calls}=setup({enabled:true});
  const badContent=sample();
  badContent.headers['content-type']='text/plain';
  assert.equal((await handle(badContent)).status,415);
  const noToken=sample();
  delete noToken.headers.authorization;
  noToken.headers.cookie='session=not-authorization';
  assert.equal((await handle(noToken)).status,401);
  const basic=sample();basic.headers.authorization='Basic something';
  assert.equal((await handle(basic)).status,401);
  assert.equal(calls.length,0);
});

test('strict input requires both explicit legal acceptances', async()=>{
  assert.deepEqual(parseConsentRequest(JSON.stringify(legal)),legal);
  const {handle,calls}=setup({enabled:true});
  for(const body of [
    '{}','[]','not valid JSON',
    JSON.stringify({...legal,acceptTerms:false}),
    JSON.stringify({...legal,acceptPrivacy:false}),
    JSON.stringify({...legal,playerId:'attacker'}),
    JSON.stringify({...legal,termsVersion:'<bad>'}),
    JSON.stringify({...legal,termsVersion:42}),
  ]) {
    assert.equal((await handle({...sample(),body})).status,400);
  }
  assert.equal(calls.length,0);
});

test('oversized UTF-8 body returns 413 without touching database', async()=>{
  const {handle,calls}=setup({enabled:true});
  assert.equal((await handle({...sample(),body:'🛫'.repeat(513)})).status,413);
  assert.equal(calls.length,0);
});

test('success returns only published receipt and no identity', async()=>{
  const {handle,calls}=setup({enabled:true});
  const response=await handle(sample());
  assert.equal(response.status,200);
  assert.equal(response.headers['cache-control'],'no-store');
  assert.equal(response.headers['x-content-type-options'],'nosniff');
  assert.deepEqual(JSON.parse(response.body),{
    termsVersion:legal.termsVersion,
    privacyVersion:legal.privacyVersion,
    acceptedAt:'2026-10-26T11:25:00Z'
  });
  assert.deepEqual(calls[0],{accessToken:TOKEN,acceptance:legal});
  assert.ok(!response.body.includes(TOKEN));
  assert.ok(!response.body.includes('playerId'));
});

test('repeat acceptance also returns HTTP 200, never a second creation receipt', async()=>{
  const {handle}=setup({enabled:true,
    receipt:{termsVersion:'legal-v1',privacyVersion:'privacy-v1',
      acceptedAt:'2026-10-25T11:25:00Z'}});
  assert.equal(JSON.parse((await handle(sample())).body).acceptedAt,
    '2026-10-25T11:25:00Z');
});

test('changed terms map to actionable 409 without database detail', async()=>{
  const {handle}=setup({enabled:true,
    error:new Error('The terms or privacy policy changed. Review the latest version.')});
  const response=await handle(sample());
  assert.equal(response.status,409);
  assert.ok(!response.body.includes('latest version.'));
});

test('expired Auth and unrelated SQL errors use safe response bodies', async()=>{
  const unauthorized=setup({enabled:true,
    error:new Error('Verified player authentication is required.')});
  assert.equal((await unauthorized.handle(sample())).status,401);
  const internal=setup({enabled:true,
    error:new Error('password=secret and private internal SQL table')});
  const response=await internal.handle(sample());
  assert.equal(response.status,503);
  assert.ok(!response.body.includes('secret'));
  assert.ok(!response.body.includes('SQL table'));
});

test('invalid handler configuration cannot open endpoints', ()=>{
  assert.throws(()=>createLegalConsentHttpHandler({}),/Trusted legal consent/);
  assert.throws(()=>createLegalConsentHttpHandler({
    consentService:{acceptPublishedPolicy:async()=>null},
    allowedOrigins:['https://airlinerra.invalid/path']
  }),/origin allowlist/);
});
