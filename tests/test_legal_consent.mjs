import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createLegalConsentService, validatedPolicyAcceptance,
  READ_PUBLISHED_POLICY_SQL, INSERT_CONSENT_SQL, EXISTING_CONSENT_SQL
} from '../server/legal-consent-service.mjs';

const USER = '11111111-1111-4111-8111-111111111111';
const BEARER = 'synthetic-authenticated-token-123456789';
const ACCEPTANCE = Object.freeze({
  termsVersion: '2026-10-26',
  privacyVersion: '2026-10-26',
  acceptTerms: true,
  acceptPrivacy: true
});

function testDriver({ policy = true, created = true, existing = true,
  failAt = null, authenticated = true } = {}) {
  const operations = [];
  const connection = {
    async query(sql, params) {
      operations.push({ sql, params });
      if (sql === failAt) throw new Error('provider secret must never escape');
      if (sql === READ_PUBLISHED_POLICY_SQL) return { rows: policy ?
        [{terms_version:ACCEPTANCE.termsVersion,
          privacy_version:ACCEPTANCE.privacyVersion}] : [] };
      if (sql === INSERT_CONSENT_SQL) return { rows: created ?
        [{accepted_at:'2026-10-26T11:00:00.000Z'}] : [] };
      if (sql === EXISTING_CONSENT_SQL) return { rows: existing ?
        [{accepted_at:'2026-10-26T10:00:00.000Z'}] : [] };
      return {rows:[]};
    },
    release() { operations.push({sql:'RELEASE'}); }
  };
  let connects = 0, verifies = 0;
  const svc = createLegalConsentService({
    enabled: true,
    database: { connect: async () => { connects++; return connection; }},
    verifyUserToken: async token => {
      verifies++;
      assert.equal(token, BEARER);
      return {user: authenticated ?
        {id:USER,email_confirmed_at:'2026-10-26T08:00:00.000Z',
          is_anonymous:false} : null,error:null};
    }
  });
  return {svc,operations,get connects(){return connects;},
    get verifies(){return verifies;}};
}

test('disabled consent cannot perform an Auth or SQL operation', async () => {
  let calls=0;
  const service=createLegalConsentService({
    database:{connect:async()=>{calls++;throw Error('not reached');}},
    verifyUserToken:async()=>{calls++;return {};}
  });
  await assert.rejects(service.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:ACCEPTANCE
  }),/not yet enabled/);
  assert.equal(calls,0);
});

test('acceptance requires explicit positive consent to both current documents', () => {
  assert.deepEqual(validatedPolicyAcceptance(ACCEPTANCE),{
    termsVersion:'2026-10-26',privacyVersion:'2026-10-26'
  });
  for(const value of [
    null,{},[],{...ACCEPTANCE,acceptTerms:false},
    {...ACCEPTANCE,acceptPrivacy:false},
    {...ACCEPTANCE,playerId:'spoofed'},
    {...ACCEPTANCE,privacyVersion:'<script>'}
  ]) assert.throws(()=>validatedPolicyAcceptance(value));
});

test('records only Auth-verified owner and published versions, in one transaction', async()=>{
  const f=testDriver();
  const result=await f.svc.acceptPublishedPolicy({
    accessToken:BEARER,
    acceptance:{...ACCEPTANCE,playerId:'spoofed'}
  }).catch(e=>e);
  // Strict payload guard must reject unexpected player identity.
  assert.match(String(result),/Unexpected legal acceptance fields/);
  assert.equal(f.connects,0);
  const value=await f.svc.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:ACCEPTANCE
  });
  assert.equal(value.acceptedAt,'2026-10-26T11:00:00.000Z');
  assert.deepEqual(f.operations.map(v=>v.sql),
    ['BEGIN',READ_PUBLISHED_POLICY_SQL,INSERT_CONSENT_SQL,'COMMIT','RELEASE']);
  assert.deepEqual(f.operations[2].params,[USER,'2026-10-26','2026-10-26']);
});

test('identical replay returns original consent timestamp without rewriting it', async()=>{
  const f=testDriver({created:false,existing:true});
  const v=await f.svc.acceptPublishedPolicy({accessToken:BEARER,acceptance:ACCEPTANCE});
  assert.equal(v.acceptedAt,'2026-10-26T10:00:00.000Z');
  assert.deepEqual(f.operations.map(v=>v.sql),[
    'BEGIN',READ_PUBLISHED_POLICY_SQL,INSERT_CONSENT_SQL,EXISTING_CONSENT_SQL,
    'COMMIT','RELEASE'
  ]);
});

test('unpublished legal documents fail closed with full rollback', async()=>{
  const f=testDriver({policy:false});
  await assert.rejects(f.svc.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:ACCEPTANCE
  }),/not available/);
  assert.deepEqual(f.operations.map(v=>v.sql),
    ['BEGIN',READ_PUBLISHED_POLICY_SQL,'ROLLBACK','RELEASE']);
});

test('mismatched or stale legal versions fail without a consent insert', async()=>{
  const f=testDriver();
  await assert.rejects(f.svc.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:{...ACCEPTANCE,termsVersion:'2026-01-01'}
  }),/changed/);
  assert.equal(f.operations.some(v=>v.sql===INSERT_CONSENT_SQL),false);
  assert.equal(f.operations.some(v=>v.sql==='ROLLBACK'),true);
});

test('an invalidated Auth token fails before connecting to PostgreSQL', async()=>{
  const f=testDriver({authenticated:false});
  await assert.rejects(f.svc.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:ACCEPTANCE
  }),/Verified player/);
  assert.equal(f.connects,0);
});

test('banned, deleted or unverified users cannot replay a prior consent', async()=>{
  assert.match(INSERT_CONSENT_SQL,/u\.banned_until/);
  assert.match(INSERT_CONSENT_SQL,/u\.deleted_at is null/);
  assert.match(EXISTING_CONSENT_SQL,/u\.banned_until/);
  assert.match(EXISTING_CONSENT_SQL,/u\.deleted_at is null/);
  const f=testDriver({created:false,existing:false});
  await assert.rejects(f.svc.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:ACCEPTANCE
  }),/could not be verified/);
  assert.ok(f.operations.some(v=>v.sql==='ROLLBACK'));
});

test('provider errors roll back and never get mistaken for success', async()=>{
  const f=testDriver({failAt:INSERT_CONSENT_SQL});
  await assert.rejects(f.svc.acceptPublishedPolicy({
    accessToken:BEARER,acceptance:ACCEPTANCE
  }),/provider secret/);
  assert.equal(f.operations.at(-2).sql,'ROLLBACK');
  assert.equal(f.operations.at(-1).sql,'RELEASE');
});

test('only parameterized private SQL receives trusted user identity',()=>{
  assert.match(INSERT_CONSENT_SQL,/\$1::uuid/);
  assert.match(INSERT_CONSENT_SQL,/\$2::text/);
  assert.match(INSERT_CONSENT_SQL,/\$3::text/);
  assert.match(READ_PUBLISHED_POLICY_SQL,/for share/);
  assert.ok(!INSERT_CONSENT_SQL.includes(BEARER));
});
