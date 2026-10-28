import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {handleLocalCatalogRequest,loadLocalCatalog} from '../website/dev-scripts/local-preview-catalog.mjs';
import {createLocalCatalogClient} from '../website/local-catalog-client.mjs';
const origin='http://localhost:5188';
const send=(path,payload={},opts={})=>new Request(origin+path,{
  method:'POST',
  headers:{'content-type':'application/json',origin:opts.origin||origin},
  body:JSON.stringify(payload)
});
test('local snapshot is exactly 3140 approved World 1 airports in 229 countries',async()=>{
 const data=await loadLocalCatalog();
 assert.equal(data.airports.length,3140);
 assert.equal(new Set(data.airports.map(x=>x.airport_key)).size,3140);
 assert.equal(new Set(data.airports.map(x=>x.country_iso)).size,229);
 assert.equal(data.worlds.length,3);
 assert.equal(data.readOnly,true);
 assert.equal(data.releaseGate,'closed');
});
test('local overview is source-derived, never a fabricated airline',async()=>{
 const r=await handleLocalCatalogRequest(send('/__local_player__/overview'));
 assert.equal(r.status,200);
 const data=await r.json();
 assert.equal(data.airportsTotal,3140);
 assert.equal(data.countries.length,229);
 assert.deepEqual(data.airlines,[]);
 assert.equal(data.gameplayAvailable,false);
 assert.equal(data.readOnly,true);
 assert.equal(data.snapshotDate,'2026-10-28');
});
test('country filter, name lookup, pagination and invalid requests',async()=>{
 const route='/__local_player__/airports';
 const r=await handleLocalCatalogRequest(send(route,{countryIso:'DE',search:'Berlin'}));
 assert.equal(r.status,200);
 const out=await r.json();
 assert.ok(out.airports.some(x=>x.name==='Berlin Brandenburg Airport'));
 assert.ok(out.airports.every(x=>x.countryIso==='DE'));
 for(const bad of [{countryIso:'D'},{countryIso:'DE',offset:-1},
  {countryIso:'DE',search:'%_%'},{countryIso:'DE',playerId:'other'}]){
  assert.equal((await handleLocalCatalogRequest(send(route,bad))).status,400);
 }
 assert.equal((await handleLocalCatalogRequest(send(route,{countryIso:'DE'},{origin:'https://evil.test'}))).status,403);
});
test('snapshot and local route are not included in production dist',async()=>{
 const [build,overlay]=await Promise.all([
  readFile(new URL('../website/dev-scripts/build.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8')
 ]);
 assert.doesNotMatch(build,/dev-data|local-preview-catalog/);
 assert.doesNotMatch(overlay,/dev-data|local-preview-catalog/);
});
test('local browser adapter never works on production origin',async()=>{
 assert.throws(()=>createLocalCatalogClient({location:new URL('https://airlinerra.com')}),/loopback/);
 const calls=[];
 const local=createLocalCatalogClient({location:new URL('http://localhost:5188/player.html'),fetchImpl:async(url,args)=>{
  calls.push({url,args});
  return new Response(JSON.stringify({readOnly:true,mode:'local-approved-airport-snapshot',airports:[]}),{status:200});
 }});
 await local.airports({countryIso:'DE',search:'Berlin'});
 assert.equal(calls[0].url,origin+'/__local_player__/airports');
 assert.equal(calls[0].args.credentials,'omit');
});

test('local draft restores airport by exact approved key, even beyond the first page',async()=>{
 const route='/__local_player__/airports';
 const ok=await handleLocalCatalogRequest(send(route,{countryIso:'DE',airportKey:'OURAIRPORTS:301881'}));
 assert.equal(ok.status,200);
 assert.equal((await ok.json()).airports[0].name,'Berlin Brandenburg Airport');
 const cross=await handleLocalCatalogRequest(send(route,{countryIso:'FR',airportKey:'OURAIRPORTS:301881'}));
 assert.deepEqual((await cross.json()).airports,[]);
 const invalid=await handleLocalCatalogRequest(send(route,{countryIso:'DE',airportKey:'bad'}));
 assert.equal(invalid.status,400);
});
