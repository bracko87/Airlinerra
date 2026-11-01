import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRCRAFT_LIBRARY_SQL,serializeAircraftLibrary,AIRCRAFT_LIBRARY_PATH} from '../server/aircraft-library-query.mjs';
import {safePlayerView} from '../website/player-app-model.mjs';
import {CANONICAL_GAME_API_PATHS} from '../server/canonical-game-api.mjs';
import {createPlayerReadHandler} from '../server/player-read-service.mjs';
import {createProductionGameApi,AIRCRAFT_LIBRARY_EDGE_URL} from '../server/production-game-api.mjs';
import {createPlayerReadClient} from '../website/player-read-client.mjs';

const sample={id:140,manufacturer:'De Havilland Canada',family:'DHC-6',
  model:'DHC-6-100',configuration:'PASSENGER-BASE',use_type:'passenger',
  seats:16,max_seats:19,cargo_kg:null,
  production_start:1966,factual_production_end:1968,planning_production_end:1968,
  game_production_status:'discontinued',service_status:'active',mtow_kg:'5262',
  mlw_kg:'5262',fuel_kg:'900',range_km:'1500',speed_kmh:'260',
  takeoff_m:null,landing_m:null,wingspan_m:'19.81',length_m:'15.77',height_m:'5.9',
  technical_review_status:'research',game_estimation_type:'FICTIONAL_GAME_ONLY',
  conditional_takeoff_m:700,conditional_landing_m:650,
  required_equipment:'AMPHIBIOUS_FLOATS_WITH_WHEELS',
  readiness_gate:'HOLD_PAVED_RUNWAY_UNVERIFIED',
  hold_reason:'PAVED_SURFACE_GEAR_CONFIGURATION_UNVERIFIED'};

test('catalog query is fixed read-only and includes manufacturer, modes and estimates',()=>{
 assert.match(AIRCRAFT_LIBRARY_SQL,/^\s*select\s/iu);
 assert.doesNotMatch(AIRCRAFT_LIBRARY_SQL,/\b(?:insert|update|delete|alter|drop|grant|truncate)\b/iu);
 assert.match(AIRCRAFT_LIBRARY_SQL,/airlinerra\.aircraft_game_data_coverage_v1/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/airlinerra\.aircraft_configuration_game_readiness_v1/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/t\.maximum_fuel_capacity_kg/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/other\.configuration_id=c\.id/);
 assert.equal(AIRCRAFT_LIBRARY_PATH,'/api/v1/player/aircraft-library');
 assert.ok(CANONICAL_GAME_API_PATHS.includes(AIRCRAFT_LIBRARY_PATH));
 assert.equal(safePlayerView('#aircraft-library'),'aircraft-library');
});

test('conditional Twin Otter values never replace original paved runway fields',()=>{
 const data=serializeAircraftLibrary([sample]);
 assert.equal(data.total,1);
 assert.equal(data.readOnly,true);
 const [a]=data.aircraft;
 assert.equal(a.takeoffM,null);
 assert.equal(a.landingM,null);
 assert.equal(a.conditionalTakeoffM,700);
 assert.equal(a.conditionalLandingM,650);
 assert.equal(a.requiredEquipment,'AMPHIBIOUS_FLOATS_WITH_WHEELS');
 assert.equal(a.readinessGate,'HOLD_PAVED_RUNWAY_UNVERIFIED');
 assert.equal(a.fuelKg,900);
 assert.equal(a.technicalReview,'research');
 assert.equal(a.gameEstimate,true);
});
test('catalog serializer rejects duplicate IDs, malformed types or excessive records',()=>{
 assert.throws(()=>serializeAircraftLibrary([]),/Invalid aircraft catalog size/);
 assert.throws(()=>serializeAircraftLibrary([sample,{...sample}]),/Invalid aircraft catalog record/);
 assert.throws(()=>serializeAircraftLibrary([{...sample,use_type:'fighter'}]),/Invalid aircraft catalog record/);
 assert.throws(()=>serializeAircraftLibrary(new Array(201).fill(sample)),/Invalid aircraft catalog size/);
});
const token='a'.repeat(32);
const id='550e8400-e29b-41d4-a716-446655440000';
const base='http://localhost:5188';
const req=(body={},origin=base)=>new Request(base+AIRCRAFT_LIBRARY_PATH,{
 method:'POST',headers:{origin,'content-type':'application/json',authorization:'Bearer '+token},
 body:JSON.stringify(body)
});
test('private player database reader authenticates before querying aircraft catalog',async()=>{
 let queried=0,connections=0,releases=0;
 const service=createPlayerReadHandler({enabled:true,origin:base,
  verifyUserToken:async()=>({user:{id,email_confirmed_at:'2026-11-01T10:00:00Z'}}),
  database:{async connect(){connections++;return {
   query:async sql=>{queried++;assert.equal(sql,AIRCRAFT_LIBRARY_SQL);return {rows:[sample]}},
   release(){releases++}
  }}}
 });
 assert.equal((await service(req({x:'bad'}))).status,400);
 assert.equal((await service(req({},'https://evil.example'))).status,403);
 assert.equal(connections,0);
 const response=await service(req());
 assert.equal(response.status,200);
 assert.equal((await response.json()).aircraft[0].model,sample.model);
 assert.equal(queried,1);
 assert.equal(connections,1);
 assert.equal(releases,1);
});
test('browser client accesses only same-origin authenticated read endpoint',async()=>{
 let requests=0;
 const client=createPlayerReadClient({
  auth:{getAccessToken:async()=>token},origin:base,local:true,enabled:true,
  fetchImpl:async(url,options)=>{
   requests++;assert.equal(url,base+AIRCRAFT_LIBRARY_PATH);
   assert.equal(options.method,'POST');
   assert.equal(options.headers.authorization,'Bearer '+token);
   assert.equal(options.body,'{}');
   return new Response(JSON.stringify({aircraft:[{id:140,model:'DHC-6-100',manufacturer:'De Havilland'}],total:1,readOnly:true}),
    {status:200,headers:{'content-type':'application/json'}});
  }
 });
 assert.equal((await client.aircraftLibrary()).total,1);
 assert.equal(requests,1);
});
test('Netlify proxy forwards read path to dedicated Edge function, not the game mutation API',async()=>{
 assert.match(AIRCRAFT_LIBRARY_EDGE_URL,/airlinerra-aircraft-library$/);
 let calls=0;
 const proxy=createProductionGameApi({fetchImpl:async(url,opts)=>{
  calls++;assert.equal(url,AIRCRAFT_LIBRARY_EDGE_URL);
  assert.equal(opts.headers['x-airlinerra-route'],AIRCRAFT_LIBRARY_PATH);
  assert.equal(opts.headers.authorization,'Bearer '+token);
  return new Response(JSON.stringify({aircraft:[],readOnly:true,total:0}),{
   status:200,headers:{'content-type':'application/json'}});
 }});
 const request=new Request('https://airlinerra.com'+AIRCRAFT_LIBRARY_PATH,{
  method:'POST',headers:{'content-type':'application/json','authorization':'Bearer '+token,
   origin:'https://airlinerra.com'},body:'{}'
 });
 assert.equal((await proxy(request)).status,200);
 assert.equal(calls,1);
});
test('the deployable private player UI contains Settings link, section, and no aircraft-buy action',async()=>{
 const page=await readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8');
 const overlay=await readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8');
 const client=await readFile(new URL('../website/aircraft-library.mjs',import.meta.url),'utf8');
 assert.match(page,/<a href="#airports" data-view-link="airports">Airports<\/a>\s*<a href="#aircraft-library"/);
 assert.match(page,/data-player-view="aircraft-library" hidden/);
 assert.match(page,/id="aircraft-library-results"/);
 assert.match(overlay,/'aircraft-library\.mjs','aircraft-library\.css'/);
 assert.match(client,/\.textContent=/);
 assert.doesNotMatch(client,/\.innerHTML/);
 assert.doesNotMatch(client,/purchaseAircraft|buyAircraft|dispatchFlight/);
});
