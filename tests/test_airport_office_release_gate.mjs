import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createProductionGameApi,PRODUCTION_ORIGIN,EDGE_FUNCTION_URL} from '../server/production-game-api.mjs';
const ROUTE='/api/v1/player/airport-offices',TOKEN='Bearer verified-user-token-123456789';
const build=(body,opts={})=>new Request(PRODUCTION_ORIGIN+ROUTE,{
 method:opts.method||'POST',
 headers:{origin:opts.origin??PRODUCTION_ORIGIN,authorization:opts.authorization??TOKEN},
 body:opts.method==='GET'?undefined:body
});
test('production bridge always rejects office operations with gate disabled, without contacting Edge',async()=>{
 let calls=0;
 const app=createProductionGameApi({fetchImpl:async()=>{calls++;throw Error('must not reach Edge')}});
 const r=await app(build(JSON.stringify({operation:'save',worldId:1,airportKey:'OURAIRPORTS:4344',type:'hub'})));
 assert.equal(r.status,503);
 assert.deepEqual(await r.json(),{error:'Airport office drafts are not enabled'});
 assert.equal(calls,0);
});
test('explicit opt-in forwards only same-origin verified bearer to expected Edge route',async()=>{
 const calls=[];
 const app=createProductionGameApi({airportOfficeDraftsEnabled:true,fetchImpl:async(url,opts)=>{
  calls.push({url,opts});
  return new Response(JSON.stringify({office:{key:'OURAIRPORTS:4344',type:'hub',status:'draft',newlyCreated:true}}),{
   status:201,headers:{'content-type':'application/json'}
  });
 }});
 const body=JSON.stringify({operation:'save',worldId:1,airportKey:'OURAIRPORTS:4344',type:'hub'});
 const r=await app(build(body));
 assert.equal(r.status,201);
 assert.equal((await r.json()).office.status,'draft');
 assert.equal(calls.length,1);
 assert.equal(calls[0].url,EDGE_FUNCTION_URL);
 assert.equal(calls[0].opts.headers['x-airlinerra-route'],ROUTE);
 assert.equal(calls[0].opts.headers.authorization,TOKEN);
 assert.equal(calls[0].opts.body,body);
 assert.equal(calls[0].opts.cache,'no-store');
});
test('Netlify route enforces origin, token, method, payload limit and rejects wrong endpoints',async()=>{
 let calls=0;
 const app=createProductionGameApi({airportOfficeDraftsEnabled:true,fetchImpl:async()=>{calls++;return Response.json({ok:true})}});
 const invalid=[
  build('{}',{origin:'https://evil.example'}),
  build('{}',{authorization:'Bearer invalid'}),
  build(' '.repeat(513)),
  build(undefined,{method:'GET'}),
  new Request(PRODUCTION_ORIGIN+'/api/v1/player/airport-offices?operation=list',{method:'POST',headers:{origin:PRODUCTION_ORIGIN,authorization:TOKEN}})
 ];
 for(const item of invalid){
  const response=await app(item);
  assert.ok(response.status>=400,JSON.stringify({status:response.status}));
 }
 assert.equal(calls,0);
});
test('hosted route is explicitly registered but gated off at both Netlify and Edge',async()=>{
 const [netlify,edge,source]=await Promise.all([
  readFile(new URL('../website/netlify/functions/airlinerra-game.mjs',import.meta.url),'utf8'),
  readFile(new URL('../server/supabase-game-edge-entry.ts',import.meta.url),'utf8'),
  readFile(new URL('../server/production-game-api.mjs',import.meta.url),'utf8')
 ]);
 assert.match(netlify,/'\/api\/v1\/player\/airport-offices'/);
 assert.match(edge,/airportOfficeDraftsEnabled:false/);
 assert.match(source,/airportOfficeDraftsEnabled=false/);
 assert.match(source,/return fail\(503,'Airport office drafts are not enabled'\)/);
});
