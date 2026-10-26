import test from 'node:test';
import assert from 'node:assert/strict';
import { startLocalAccountStack } from '../server/local-account-stack.mjs';
import { AIRLINE_ACTIVATION_SQL } from '../server/airline-activation.mjs';
import {
  READ_PUBLISHED_POLICY_SQL, INSERT_CONSENT_SQL, EXISTING_CONSENT_SQL
} from '../server/legal-consent-service.mjs';

const PLAYER = '11111111-1111-4111-8111-111111111111';
const AIRLINE = '22222222-2222-4222-8222-222222222222';
const TOKEN = 'mock-valid-server-verified-token';
const VALID_USER = { user: {
  id: PLAYER, email_confirmed_at: '2026-10-26T00:00:00.000Z',
  is_anonymous: false
}, error: null };
const legal = () => JSON.stringify({
  termsVersion:'test-v1', privacyVersion:'test-v1',
  acceptTerms:true, acceptPrivacy:true
});
const airline = (worldId=1,homeAirportKey='OURAIRPORTS:101') => JSON.stringify({
  worldId, airlineName: worldId === 1 ? 'Aurelia Airways' : 'Atlantic Routes',
  homeAirportKey
});

function fakeDependencies({verified=VALID_USER}={}) {
  const state = {
    queries:[], authCalls:0, connects:0, releases:0, commits:0,
    rollbacks:0, consents:0, credits:0, airlines:new Map(),
    trialEndsAt:'2026-11-02T00:00:00.000Z', policyVersion:'test-v1',
    failActivation:false, failConnect:false
  };
  const verifyUserToken = async token => {
    state.authCalls++;
    assert.equal(token,TOKEN);
    return verified;
  };
  const database = {
    async connect() {
      state.connects++;
      if (state.failConnect) throw Error('SECRET_DB_CONNECTION_URI');
      return {
        async query(sql,params) {
          state.queries.push({sql,params});
          if (sql === 'BEGIN') return {rows:[]};
          if (sql === 'COMMIT') {state.commits++;return {rows:[]};}
          if (sql === 'ROLLBACK') {state.rollbacks++;return {rows:[]};}
          if (sql === READ_PUBLISHED_POLICY_SQL) return {rows:[{
            terms_version:state.policyVersion,
            privacy_version:'test-v1'
          }]};
          if (sql === INSERT_CONSENT_SQL) {
            state.consents++;
            return {rows:[{accepted_at:'2026-10-26T00:00:00Z'}]};
          }
          if (sql === EXISTING_CONSENT_SQL) return {rows:[]};
          if (sql === AIRLINE_ACTIVATION_SQL) {
            if (state.failActivation) {
              const error = Error('SECRET_DB_AIRPORT_INTERNALS');
              error.code = '23514';
              throw error;
            }
            const [,world,name,key] = params;
            if (!state.consents || (world === 1 && key !== 'OURAIRPORTS:101') ||
                (world === 2 && key !== 'FICTIONAL:fictional:RS:LYAL') ||
                world > 2) {
              const error=Error('SECRET unapproved airport');
              error.code='23514';
              throw error;
            }
            const id=world+'-'+PLAYER;
            if (state.airlines.has(id)) return {rows:[{
              airline_id:state.airlines.get(id).id,
              newly_created:false,starting_balance_usd:'5000000.00',
              trial_ends_at:state.trialEndsAt
            }]};
            state.airlines.set(id,{id:AIRLINE,name,key});
            state.credits++;
            return {rows:[{
              airline_id:AIRLINE,newly_created:true,
              starting_balance_usd:'5000000.00',
              trial_ends_at:state.trialEndsAt
            }]};
          }
          throw Error('Unexpected SQL: '+sql);
        },
        release() {state.releases++;}
      };
    }
  };
  return {state,verifyUserToken,database};
}
async function call(server,path,body,{token=TOKEN,origin=server.origin,headers={}}={}) {
  return fetch(server.origin+path,{
    method:'POST',
    headers:{origin,'content-type':'application/json',authorization:'Bearer '+token,...headers},
    body
  });
}
async function setup(t,opts={},enabled=true) {
  const fixture=fakeDependencies(opts);
  const server=await startLocalAccountStack({...fixture,enabled});
  t.after(()=>server.close());
  return {...fixture,server};
}

test('all gates default off; neither Auth nor PostgreSQL is touched',async t=>{
  const x=await setup(t,{},false);
  const a=await call(x.server,'/api/v1/airlines',airline());
  const b=await call(x.server,'/api/v1/legal/consents',legal());
  assert.equal(a.status,503);assert.equal(b.status,503);
  assert.equal(x.state.authCalls,0);assert.equal(x.state.connects,0);
  assert.ok(x.server.origin.startsWith('http://127.0.0.1:'));
});

test('real legal endpoint verifies token and commits accepted versions',async t=>{
  const x=await setup(t);
  const response=await call(x.server,'/api/v1/legal/consents',legal());
  assert.equal(response.status,200);
  assert.equal((await response.json()).termsVersion,'test-v1');
  assert.equal(x.state.consents,1);
  assert.equal(x.state.commits,1);
  assert.equal(x.state.releases,1);
  assert.deepEqual(x.state.queries.filter(q=>q.sql===INSERT_CONSENT_SQL)[0].params,
    [PLAYER,'test-v1','test-v1']);
});

test('real airline HTTP and service create one synthetic $5m airline, then safe replay',async t=>{
  const x=await setup(t);
  assert.equal((await call(x.server,'/api/v1/legal/consents',legal())).status,200);
  const first=await call(x.server,'/api/v1/airlines',airline());
  const saved=await first.json();
  assert.equal(first.status,201);
  assert.equal(saved.cashUsd,'5000000.00');
  assert.equal(saved.newlyCreated,true);
  assert.equal(saved.trialEndsAt,x.state.trialEndsAt);
  const again=await call(x.server,'/api/v1/airlines',airline());
  assert.equal(again.status,200);
  assert.equal((await again.json()).newlyCreated,false);
  assert.equal(x.state.credits,1);
  assert.equal(x.state.airlines.size,1);
  assert.equal(x.state.rollbacks,0);
  assert.equal(x.state.connects,x.state.releases);
  assert.deepEqual(x.state.queries.filter(q=>q.sql===AIRLINE_ACTIVATION_SQL)[0].params,
    [PLAYER,1,'Aurelia Airways','OURAIRPORTS:101']);
});

test('fictional LYAL remains a valid stable key in another world without a second trial',async t=>{
  const x=await setup(t);
  await call(x.server,'/api/v1/legal/consents',legal());
  await call(x.server,'/api/v1/airlines',airline());
  const resp=await call(x.server,'/api/v1/airlines',
    airline(2,'FICTIONAL:fictional:RS:LYAL'));
  assert.equal(resp.status,201);
  assert.equal((await resp.json()).trialEndsAt,x.state.trialEndsAt);
  assert.equal(x.state.credits,2);
  assert.equal(x.state.airlines.size,2);
});

test('outdated legal versions fail 409 and roll back without storing consent',async t=>{
  const x=await setup(t);
  x.state.policyVersion='test-v2';
  const resp=await call(x.server,'/api/v1/legal/consents',legal());
  assert.equal(resp.status,409);
  assert.equal(x.state.rollbacks,1);
  assert.equal(x.state.consents,0);
  assert.equal(x.state.credits,0);
});

test('unverified Auth session fails 401 before connecting to PostgreSQL',async t=>{
  const x=await setup(t,{verified:{user:{id:PLAYER,email_confirmed_at:null},error:null}});
  const resp=await call(x.server,'/api/v1/airlines',airline());
  assert.equal(resp.status,401);
  assert.equal(x.state.connects,0);
});

test('unexpected player ID, old numeric airport ID and malformed legal consent fail 400',async t=>{
  const x=await setup(t);
  const bad=await call(x.server,'/api/v1/airlines',JSON.stringify({
    worldId:1,airlineName:'Aurelia Airways',homeAirportSourceId:101,playerId:PLAYER
  }));
  const legalBad=await call(x.server,'/api/v1/legal/consents',
    JSON.stringify({termsVersion:'test-v1',privacyVersion:'test-v1',acceptTerms:false,acceptPrivacy:true}));
  assert.equal(bad.status,400);assert.equal(legalBad.status,400);
  assert.equal(x.state.connects,0);
});

test('unapproved airport database failure rolls back and hides private SQL details',async t=>{
  const x=await setup(t);
  await call(x.server,'/api/v1/legal/consents',legal());
  x.state.failActivation=true;
  const resp=await call(x.server,'/api/v1/airlines',airline());
  assert.equal(resp.status,503);
  assert.ok(!(await resp.text()).includes('SECRET'));
  assert.equal(x.state.rollbacks,1);
  assert.equal(x.state.credits,0);
  assert.equal(x.state.connects,x.state.releases);
});

test('wrong origin and missing bearer never reach verified service',async t=>{
  const x=await setup(t);
  const denied=await call(x.server,'/api/v1/airlines',airline(),{
    origin:'https://attacker.invalid'
  });
  assert.equal(denied.status,403);
  const missing=await call(x.server,'/api/v1/airlines',airline(),{
    token:'invalid'
  });
  assert.equal(missing.status,401);
  assert.equal(x.state.authCalls,0);
  assert.equal(x.state.connects,0);
});

test('database connect failure returns generic 503 and leaks no secret',async t=>{
  const x=await setup(t);
  x.state.failConnect=true;
  const result=await call(x.server,'/api/v1/airlines',airline());
  assert.equal(result.status,503);
  assert.ok(!(await result.text()).includes('SECRET'));
  assert.equal(x.state.credits,0);
});

test('without injected Auth verifier or database no listening socket is opened',async()=>{
  await assert.rejects(startLocalAccountStack(),/Trusted test Auth verifier/);
  await assert.rejects(startLocalAccountStack({
    verifyUserToken:async()=>VALID_USER,database:{}
  }),/Trusted test Auth verifier/);
});
