import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createPreviewRequestGate, PREVIEW_ACCESS_HEADER
} from '../server/preview-access-guard.mjs';
import {createStagedNetlifyAccountHandler} from '../server/netlify-preview-template/airlinerra-accounts.mjs';

const ORIGIN='https://deploy-preview-19--airlinerra.netlify.app';
const PLATFORM=()=>({deploy:{context:'deploy-preview',published:false},site:{name:'airlinerra',url:'https://airlinerra.com'}});
const SECRET='Z'.repeat(43); // Synthetic, cannot open any actual preview.
const env=()=>({
  CONTEXT:'deploy-preview',
  AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
  AIRLINERRA_PRIVATE_PREVIEW_APPROVED:'true',
  AIRLINERRA_PREVIEW_ORIGIN:ORIGIN,
  AIRLINERRA_PREVIEW_ACCESS_SECRET:SECRET
});
function request(path='/api/v1/onboarding/context',{
  origin=ORIGIN, secret=SECRET, method='POST',contentType='application/json'
}={}){
  return new Request(ORIGIN+path,{
    method,
    headers:{
      origin,
      'content-type':contentType,
      [PREVIEW_ACCESS_HEADER]:secret,
      authorization:'Bearer synthetic-user-jwt-for-security-tests'
    },
    ...(method==='GET'?{}:{body:'{}'})
  });
}

test('preview access rejects missing, malformed or wrong credentials before backend',()=>{
  let now=1000;
  const gate=createPreviewRequestGate({now:()=>now});
  for(const secret of ['', 'bad', 'A'.repeat(43), 'A'.repeat(129), SECRET+'!']){
    const r=gate.acquire(env(),request(undefined,{secret}));
    assert.equal(r.allowed,false);
    assert.equal(r.status,503);
  }
  // Valid request remains accepted: rejected attempts never use the budget.
  const approved=gate.acquire(env(),request());
  assert.equal(approved.allowed,true);
  approved.release();
});

test('request origin, route, query, method and content type are enforced',()=>{
  const gate=createPreviewRequestGate();
  const sample=[
    request(undefined,{origin:'https://evil.example'}),
    request('/api/v1/airlines?anything=true'),
    request('/api/v1/not-allowed'),
    request(undefined,{method:'GET'}),
    request(undefined,{contentType:'text/plain'})
  ];
  for(const attempt of sample){
    assert.equal(gate.acquire(env(),attempt).allowed,false);
  }
  const badHost={...env(),AIRLINERRA_PREVIEW_ORIGIN:'https://airlinerra.com'};
  assert.equal(gate.acquire(badHost,request()).allowed,false);
  assert.equal(gate.acquire({...env(),CONTEXT:'production'},request()).allowed,false);
});

test('preview credential is stripped before trusted account services',()=>{
  const gate=createPreviewRequestGate();
  const candidate=gate.acquire(env(),request());
  assert.equal(candidate.allowed,true);
  assert.equal(candidate.request.headers.get(PREVIEW_ACCESS_HEADER),null);
  assert.equal(candidate.request.headers.get('authorization'),
    'Bearer synthetic-user-jwt-for-security-tests');
  assert.equal(candidate.request.headers.get('origin'),ORIGIN);
  candidate.release();
  candidate.release(); // idempotent cleanup
});

test('only exact pinned Netlify nonproduction host shapes may be used',()=>{
  const gate=createPreviewRequestGate();
  const e=env();
  for(const host of [
    'https://airlinerra.com','https://airlinerra.netlify.app',
    'https://deploy-preview-19--other.netlify.app',
    'https://deploy-preview-19--airlinerra.netlify.app.evil.com'
  ]){
    e.AIRLINERRA_PREVIEW_ORIGIN=host;
    assert.equal(gate.acquire(e,request()).allowed,false);
  }
  const branch='https://qa--airlinerra.netlify.app';
  const permittedBranch={
    ...env(),CONTEXT:'branch-deploy',AIRLINERRA_PREVIEW_ORIGIN:branch
  };
  const branchRequest=new Request(branch+'/api/v1/airlines',{
    method:'POST',
    headers:{
      origin:branch,'content-type':'application/json',
      [PREVIEW_ACCESS_HEADER]:SECRET
    },
    body:'{}'
  });
  const granted=gate.acquire(permittedBranch,branchRequest);
  assert.equal(granted.allowed,true);
  granted.release();
  assert.equal(gate.acquire({...permittedBranch,CONTEXT:'production'},branchRequest).allowed,false);
});

test('warm instance concurrency budget is enforced and recovers after releases',()=>{
  const gate=createPreviewRequestGate();
  const tickets=Array.from({length:4},()=>gate.acquire(env(),request()));
  assert.ok(tickets.every(t=>t.allowed));
  const overflow=gate.acquire(env(),request());
  assert.equal(overflow.allowed,false);
  assert.equal(overflow.status,429);
  tickets[0].release();
  const next=gate.acquire(env(),request());
  assert.equal(next.allowed,true);
  for(const ticket of tickets)ticket.release();
  next.release();
});

test('per-minute budget applies across calls and resets on window rotation',()=>{
  let time=100_000;
  const gate=createPreviewRequestGate({now:()=>time});
  for(let i=0;i<30;i++){
    const ticket=gate.acquire(env(),request());
    assert.equal(ticket.allowed,true,'within 30 requests in the same window');
    ticket.release();
  }
  const stopped=gate.acquire(env(),request());
  assert.equal(stopped.allowed,false);
  assert.equal(stopped.status,429);
  time+=60_001;
  const fresh=gate.acquire(env(),request());
  assert.equal(fresh.allowed,true);
  fresh.release();
});

test('staged handler refuses untrusted preview requests without starting an app',async()=>{
  let builds=0;
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:env,
    buildApp:async()=>{
      builds++;
      return {enabled:true,handler:async()=>new Response('{}',{status:200})};
    }
  });
  const rejected=await handler(request(undefined,{secret:'B'.repeat(43)}),PLATFORM());
  assert.equal(rejected.status,503);
  assert.equal(builds,0);
  assert.equal((await handler(request(),PLATFORM())).status,200);
  assert.equal(builds,1);
});

test('guarded in-flight request always releases capacity even on handler failure',async()=>{
  let enter;
  const entered=new Promise(resolve=>{enter=resolve;});
  let finish;
  const held=new Promise(resolve=>{finish=resolve;});
  let calls=0;
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:env,
    buildApp:async()=>({enabled:true,handler:async()=>{
      calls++;
      if(calls<=4){enter();await held;throw Error('private database error');}
      return new Response('{}',{status:200});
    }})
  });
  const active=Array.from({length:4},()=>handler(request(),PLATFORM()));
  await entered;
  const over=await handler(request(),PLATFORM());
  assert.equal(over.status,429);
  finish();
  const finished=await Promise.all(active);
  assert.ok(finished.every(x=>x.status===503));
  const recovered=await handler(request(),PLATFORM());
  assert.equal(recovered.status,200);
});
