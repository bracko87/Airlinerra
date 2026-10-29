import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createProductionGameApi,EDGE_FUNCTION_URL,AIRPORT_PROFILE_EDGE_URL,PRODUCTION_ORIGIN} from '../server/production-game-api.mjs';
import {CANONICAL_GAME_API_PATHS} from '../server/canonical-game-api.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';

const token='Bearer '+('a'.repeat(32));
const origin=PRODUCTION_ORIGIN;
test('production game API no longer requires Netlify DB credentials or secret environment flags',async()=>{
 let requests=[];
 const app=createProductionGameApi({fetchImpl:async(url,opts)=>{
  requests.push({url,opts});
  return Response.json({registrationReady:false,privateOwnerPilotAvailable:true});
 }});
 const response=await app(new Request(origin+'/api/v1/registration/readiness'));
 assert.equal(response.status,200);
 assert.equal((await response.json()).privateOwnerPilotAvailable,true);
 assert.equal(requests.length,1);
 assert.equal(requests[0].url,EDGE_FUNCTION_URL);
 assert.equal(requests[0].opts.headers['x-airlinerra-route'],'/api/v1/registration/readiness');
 assert.equal(requests[0].opts.headers.apikey,settings.publishableKey);
 assert.equal((await app(new Request('https://malicious.example/api/v1/registration/readiness'))).status,403);
 assert.equal((await app(new Request(origin+'/api/v1/registration/readiness?x=1'))).status,403);
 assert.equal((await app(new Request(origin+'/api/v1/unknown'))).status,404);
 assert.equal(requests.length,1);
});
test('all private routes forward only real bearer tokens and bounded JSON to pinned Supabase API',async()=>{
 let seen=[];
 const app=createProductionGameApi({fetchImpl:async(url,options)=>{
  seen.push({url,options});
  return Response.json({ok:true});
 }});
 assert.equal((await app(new Request(origin+'/api/v1/airlines',{method:'POST',body:'{}'}))).status,401);
 assert.equal(seen.length,0);
 for(const path of CANONICAL_GAME_API_PATHS.filter(x=>!x.endsWith('/readiness'))){
  const res=await app(new Request(origin+path,{
   method:'POST',headers:{authorization:token,origin,'content-type':'application/json'},
   body:'{}'
  }));
  assert.equal(res.status,200,path);
 }
 assert.equal(seen.length,6);
 assert.ok(seen.every(x=>
   x.url===(x.options.headers['x-airlinerra-route']==='/api/v1/player/airport-profile'
      ?AIRPORT_PROFILE_EDGE_URL:EDGE_FUNCTION_URL) &&
   x.options.headers.authorization===token &&
   x.options.headers.apikey===settings.publishableKey));
 assert.equal((await app(new Request(origin+'/api/v1/airlines',{
  method:'POST',headers:{authorization:token,origin:'https://malicious.example'},body:'{}'
 }))).status,403);
 assert.equal((await app(new Request(origin+'/api/v1/airlines',{
  method:'POST',headers:{authorization:token,origin},body:'a'.repeat(2049)
 }))).status,413);
});
test('network and unexpected upstream errors fail closed and never expose credentials',async()=>{
 const fail=createProductionGameApi({fetchImpl:async()=>{throw Error('secret connection failed')}});
 const response=await fail(new Request(origin+'/api/v1/registration/readiness'));
 assert.equal(response.status,503);
 assert.doesNotMatch(await response.text(),/secret connection/);
 const bad=createProductionGameApi({fetchImpl:async()=>new Response('<html/>',{status:200,
  headers:{'content-type':'text/html'}})});
 assert.equal((await bad(new Request(origin+'/api/v1/registration/readiness'))).status,503);
});
test('manual Netlify build deploys the complete secured backend proxy',async()=>{
 const root=new URL('../',import.meta.url);
 const [toml,fn,build,server]=await Promise.all([
  readFile(new URL('netlify.toml',root),'utf8'),
  readFile(new URL('website/netlify/functions/airlinerra-game.mjs',root),'utf8'),
  readFile(new URL('website/dev-scripts/build.mjs',root),'utf8'),
  readFile(new URL('server/production-game-api.mjs',root),'utf8')
 ]);
 assert.match(toml,/directory = "netlify\/functions"/);
 assert.match(toml,/node_bundler = "esbuild"/);
 assert.match(fn,/createProductionGameApi\(\)/);
 for(const path of CANONICAL_GAME_API_PATHS)assert.ok(fn.includes(path),path);
 assert.match(server,/EDGE_FUNCTION_URL/);
 assert.doesNotMatch(server,/AIRLINERRA_DATABASE_URL|process\.env|loadPg/);
 assert.doesNotMatch(build,/server\/production-game-api|service_role/);
});
