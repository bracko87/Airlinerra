import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createOnboardingContextService,ONBOARDING_CONTEXT_SQL
} from '../server/onboarding-context-service.mjs';
import {createOnboardingContextHttpHandler} from '../server/onboarding-context-http-handler.mjs';

const USER='11111111-1111-4111-8111-111111111111';
const TOKEN='synthetic-user-bearer-token';
const origin='http://localhost:5187';
function fixture({enabled=true,open=true,documents=true,user=true}={}) {
  const state={verified:0,queries:[],connect:0,releases:0};
  const database={
    async connect(){
      state.connect++;
      return{
        async query(sql){
          state.queries.push(sql);
          if(sql===ONBOARDING_CONTEXT_SQL.ready) return {rows:[{
            enabled:open,terms_version:'ci-v1',privacy_version:'ci-v1'
          }]};
          if(sql===ONBOARDING_CONTEXT_SQL.worlds) return {rows:[
            {id:1,name:'Founding World'},{id:2,name:'Expansion World'}]};
          if(sql===ONBOARDING_CONTEXT_SQL.airports)return {rows:[
            {world_id:1,airport_key:'OURAIRPORTS:101'},
            {world_id:2,airport_key:'FICTIONAL:fictional:RS:LYAL'},
            {world_id:3,airport_key:'OURAIRPORTS:303'},
            {world_id:1,airport_key:'unsafe/invalid-key'}
          ]};
          throw Error('Unexpected SQL in test');
        },
        release(){state.releases++;}
      };
    }
  };
  const verifyUserToken=async token=>{
    assert.equal(token,TOKEN);state.verified++;
    return {user:user?{id:USER,email_confirmed_at:'2026-10-26T00:00:00Z',
      is_anonymous:false}:null,error:user?null:{code:'unauthorized'}};
  };
  const service=createOnboardingContextService({
    verifyUserToken,database,enabled,
    documentPaths:documents?{terms:'/.airlinerra-ci-terms.html',
      privacy:'/.airlinerra-ci-privacy.html'}:undefined
  });
  return {state,service};
}
test('private context lists only operator-added keys in open worlds',async()=>{
  const {service,state}=fixture();
  const result=await service.getContext({accessToken:TOKEN});
  assert.equal(result.policy.termsVersion,'ci-v1');
  assert.equal(result.worlds.length,2);
  assert.deepEqual(result.worlds[0].airports,[{
    key:'OURAIRPORTS:101',label:'OURAIRPORTS:101'}]);
  assert.deepEqual(result.worlds[1].airports,[{
    key:'FICTIONAL:fictional:RS:LYAL',
    label:'FICTIONAL:fictional:RS:LYAL'}]);
  assert.equal(state.connect,1);
  assert.equal(state.releases,1);
  assert.equal(state.verified,1);
  assert.equal(state.queries.length,3);
  assert.ok(!JSON.stringify(result).includes('OURAIRPORTS:303'));
  assert.ok(!JSON.stringify(result).includes('unsafe/invalid'));
});
test('default-disabled or missing published document paths makes no database call',async()=>{
  for(const options of [{enabled:false},{documents:false}]){
    const {service,state}=fixture(options);
    await assert.rejects(service.getContext({accessToken:TOKEN}),/not available/);
    assert.equal(state.verified,0);
    assert.equal(state.connect,0);
  }
});
test('closed platform and unverified user deny all context',async()=>{
  const closed=fixture({open:false});
  await assert.rejects(closed.service.getContext({accessToken:TOKEN}),/release approval/);
  assert.equal(closed.state.releases,1);
  const bad=fixture({user:false});
  await assert.rejects(bad.service.getContext({accessToken:TOKEN}));
  assert.equal(bad.state.connect,0);
});
test('HTTP handler checks origin, bearer and empty body before touching database',async()=>{
  const {service,state}=fixture();
  const handler=createOnboardingContextHttpHandler({
    contextService:service,allowedOrigins:[origin],enabled:true
  });
  const req={method:'POST',path:'/api/v1/onboarding/context',body:'{}',headers:{
    origin,'content-type':'application/json',authorization:'Bearer '+TOKEN
  }};
  assert.equal((await handler(req)).status,200);
  assert.equal((await handler({...req,headers:{...req.headers,origin:'https://evil.invalid'}})).status,403);
  assert.equal((await handler({...req,body:'{"worldId":1}'})).status,400);
  assert.equal((await handler({...req,headers:{...req.headers,authorization:'Bearer x'}})).status,401);
  assert.equal((await handler({...req,method:'GET'})).status,405);
  assert.equal(state.connect,1);
  assert.equal(state.verified,1);
});
test('context is never a grant or research approval mutation',()=>{
  for(const sql of Object.values(ONBOARDING_CONTEXT_SQL)){
    assert.match(sql,/airlinerra_game|airlinerra_game_worlds/);
    assert.doesNotMatch(sql,/\b(insert|update|delete|grant|create)\b/i);
    assert.doesNotMatch(sql,/\bairlinerra\./i);
  }
});
