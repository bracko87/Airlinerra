import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import http from 'node:http';
import { startLocalAuthPreview } from '../website/dev-scripts/dev-local-auth.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const KEY='sb_publishable_1234567890abcdefghijklmnopqrstuvwxyz';
const ENV={AIRLINERRA_LOCAL_AUTH_TEST:'1',AIRLINERRA_LOCAL_PUBLISHABLE_KEY:KEY};
function call(server,route='/account.html',{method='GET',host}={}){
  return new Promise((resolve,reject)=>{
    const req=http.request({
      hostname:'127.0.0.1',port:server.port,path:route,method,
      headers:{host:host??'localhost:'+server.port}
    },res=>{
      const chunks=[];
      res.on('data',chunk=>chunks.push(chunk));
      res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,
        body:Buffer.concat(chunks).toString('utf8')}));
    });
    req.on('error',reject);req.end();
  });
}
test('preview requires explicit opt-in and a local publishable key',async()=>{
  await assert.rejects(startLocalAuthPreview({port:0,env:{}}),/explicit opt-in/);
  await assert.rejects(startLocalAuthPreview({port:0,env:{
    AIRLINERRA_LOCAL_AUTH_TEST:'1'
  }}),/separate development Auth project/);
  await assert.rejects(startLocalAuthPreview({port:0,env:{
    ...ENV,AIRLINERRA_LOCAL_SUPABASE_URL:'https://devabcdefghij123456.supabase.co'
  }}),/Only the local Supabase Auth stack/);
  await assert.rejects(startLocalAuthPreview({port:0,env:{
    ...ENV,AIRLINERRA_LOCAL_SUPABASE_URL:'https://hwllkabgzaynalahvkpz.supabase.co'
  }}),/separate development Supabase project/);
  await assert.rejects(startLocalAuthPreview({port:-1,env:ENV}),/Invalid localhost/);
});
test('real localhost HTTP preview provides virtual enabled flags but leaves source disabled',async t=>{
  const server=await startLocalAuthPreview({port:0,env:ENV});
  t.after(()=>server.close());
  assert.ok(server.origin.startsWith('http://localhost:'));
  const html=await call(server);
  const flags=await call(server,'/auth-rules.mjs');
  const conf=await call(server,'/__airlinerra_local_auth_config__.js');
  assert.equal(html.status,200);
  assert.match(html.body,/__airlinerra_local_auth_config__\.js/);
  assert.match(html.body,/id="player-profile-form"/);
  assert.match(flags.body,/PUBLIC_AUTH_ENABLED = true;/);
  assert.match(flags.body,new RegExp('http://localhost:'+server.port));
  assert.doesNotMatch(flags.body,/hwllkabgzaynalahvkpz/);
  assert.match(conf.body,/http:\/\/127\.0\.0\.1:54321/);
  assert.match(conf.body,/sb_publishable_/);
  assert.doesNotMatch(conf.body,/hwllkabgzaynalahvkpz|service_role|sb_secret_/);
  const source=await readFile(path.join(root,'website/auth-rules.mjs'),'utf8');
  assert.match(source,/PUBLIC_AUTH_ENABLED = false;/);
  const original=await readFile(path.join(root,'website/account.html'),'utf8');
  assert.doesNotMatch(original,/__airlinerra_local_auth_config__\.js/);
});
test('loopback server rejects host-header attacks and unsafe methods',async t=>{
  const server=await startLocalAuthPreview({port:0,env:ENV});
  t.after(()=>server.close());
  const bad=await call(server,'/account.html',{host:'attacker.invalid'});
  assert.equal(bad.status,421);
  const post=await call(server,'/account.html',{method:'POST'});
  assert.equal(post.status,405);
  assert.equal((await call(server,'/../outside')).status,404);
  assert.equal((await call(server,'/__missing_file__')).status,404);
});
test('local preview uses protective headers and never exposes private API routes',async t=>{
  const server=await startLocalAuthPreview({port:0,env:ENV});
  t.after(()=>server.close());
  const response=await call(server);
  assert.equal(response.headers['x-frame-options'],'DENY');
  assert.equal(response.headers['cache-control'],'no-store');
  assert.equal(response.headers['referrer-policy'],'no-referrer');
  assert.match(response.headers['content-security-policy'],/frame-ancestors 'none'/);
  assert.equal((await call(server,'/api/v1/airlines')).status,404);
  assert.equal((await call(server,'/api/v1/legal/consents')).status,404);
});
