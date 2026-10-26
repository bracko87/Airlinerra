import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { startLocalAccountGateway } from '../server/local-account-gateway.mjs';

const TOKEN = 'a-synthetic-bearer-token-for-tests';
const SENT = JSON.stringify({worldId:1,airlineName:'Aurelia Airways',homeAirportKey:'OURAIRPORTS:101'});
const JSON_REPLY = ({status=200,body={ok:true},headers={}}={}) => ({
  status, headers, body:JSON.stringify(body)
});
function gateway({enabled=false, behavior=null}={}) {
  const calls=[];
  return {
    calls,
    start:()=>startLocalAccountGateway({enabled,createHandlers:()=>({
      airlineHandler:async request=>{calls.push(['airline',request]);return behavior?.(request)??JSON_REPLY({status:201,body:{newlyCreated:true}});},
      legalHandler:async request=>{calls.push(['legal',request]);return behavior?.(request)??JSON_REPLY({body:{acceptedAt:'2026-10-26T00:00:00Z'}});}
    })})
  };
}
async function request(server,route='/api/v1/airlines',options={}) {
  return fetch(server.origin + route, {
    method:'POST', headers:{origin:server.origin,'content-type':'application/json',authorization:`Bearer ${TOKEN}`,...options.headers},
    body:SENT,...options
  });
}
test('transport binds to local loopback, defaults disabled, no handler invoked',async t=>{
  const x=gateway();const server=await x.start();t.after(()=>server.close());
  assert.ok(server.origin.startsWith('http://127.0.0.1:'));
  const r=await request(server);assert.equal(r.status,503);
  assert.equal(r.headers.get('cache-control'),'no-store');
  assert.equal(x.calls.length,0);
});
test('real HTTP POST routes preserve JSON body and bearer headers',async t=>{
  const x=gateway({enabled:true});const server=await x.start();t.after(()=>server.close());
  const a=await request(server);const b=await request(server,'/api/v1/legal/consents');
  assert.equal(a.status,201);assert.equal(b.status,200);
  assert.deepEqual(JSON.parse(x.calls[0][1].body),JSON.parse(SENT));
  assert.equal(x.calls[0][1].headers.authorization,`Bearer ${TOKEN}`);
  assert.equal(x.calls[1][0],'legal');
  assert.equal(a.headers.get('access-control-allow-origin'),null);
});
test('unknown routes and GET requests are not forwarded',async t=>{
  const x=gateway({enabled:true});const server=await x.start();t.after(()=>server.close());
  assert.equal((await request(server,'/api/v1/admin')).status,404);
  const response=await fetch(server.origin+'/api/v1/airlines',{method:'GET'});
  assert.equal(response.status,405);assert.equal(response.headers.get('allow'),'POST');
  assert.equal(x.calls.length,0);
});
test('cross-origin requests fail before sensitive handlers execute',async t=>{
  const x=gateway({enabled:true});const server=await x.start();t.after(()=>server.close());
  for(const origin of ['https://attacker.example','null']) {
    const r=await request(server,undefined,{headers:{origin}});
    assert.equal(r.status,403);
  }
  assert.equal(x.calls.length,0);
});
test('oversize content length is rejected before handler',async t=>{
  const x=gateway({enabled:true});const server=await x.start();t.after(()=>server.close());
  const resp=await request(server,undefined,{body:'x'.repeat(2049)});
  assert.equal(resp.status,413);assert.equal(x.calls.length,0);
});
test('body at the 2048 byte boundary is accepted by transport',async t=>{
  const x=gateway({enabled:true});const server=await x.start();t.after(()=>server.close());
  const resp=await request(server,undefined,{body:'a'.repeat(2048)});
  assert.equal(resp.status,201);assert.equal(x.calls[0][1].body.length,2048);
});
test('unhandled private handler failures return no internals',async t=>{
  const x=gateway({enabled:true,behavior:()=>{throw Error('supersecret DATABASE_PASSWORD');}});
  const server=await x.start();t.after(()=>server.close());
  const resp=await request(server);assert.equal(resp.status,503);
  assert.ok(!(await resp.text()).includes('supersecret'));
});
test('missing factory or invalid port fails before opening listener',async()=>{
  await assert.rejects(startLocalAccountGateway({}),/Trusted account handler/);
  await assert.rejects(startLocalAccountGateway({createHandlers:()=>({}),port:-1}),/Invalid local port/);
});
test('oversized chunked request never reaches account handler',async t=>{
  let calls=0;
  const server=await startLocalAccountGateway({enabled:true,createHandlers:()=>({
    airlineHandler:async()=>{calls++;return {status:200,body:'{}'};},
    legalHandler:async()=>({status:200,body:'{}'})
  })});
  t.after(()=>server.close());
  const response=await new Promise((resolve,reject)=>{
    const request=http.request(server.origin+'/api/v1/airlines',{
      method:'POST',headers:{origin:server.origin,
        'transfer-encoding':'chunked','content-type':'application/json'}
    },res=>{
      let body='';res.on('data',chunk=>body+=chunk);
      res.on('end',()=>resolve({status:res.statusCode,body}));
    });
    request.on('error',reject);
    request.write('a'.repeat(1024));
    request.write('b'.repeat(1100));
    request.end();
  });
  assert.equal(response.status,413);
  assert.equal(calls,0);
});
