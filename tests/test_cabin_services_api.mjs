import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initialCabinState,createBasicCabinPackage,cleanCabinPackage,cleanCabinState,CABIN_DATA_SCHEMA_ID} from '../website/cabin-services-manager.mjs';
import {createCabinServicesHandler,validCabinRequest,validCabinState,CABIN_SQL}
 from '../server/cabin-services-service.mjs';
import {createCabinServicesClient} from '../website/cabin-services-client.mjs';
import {createProductionGameApi,CABIN_ROUTE,CABIN_EDGE_URL} from '../server/production-game-api.mjs';
const airlineId='11111111-1111-4111-8111-111111111111',playerId='22222222-2222-4222-8222-222222222222';
const state=initialCabinState();
const req=body=>new Request('https://airlinerra.com'+CABIN_ROUTE,{
 method:'POST',headers:{authorization:'Bearer '+('a'.repeat(50)),origin:'https://airlinerra.com',
  'content-type':'application/json','x-airlinerra-route':CABIN_ROUTE},
 body:JSON.stringify(body)});
test('reject bad packages and forged protected Basic package',()=>{
 assert.equal(validCabinState(state),true);
 assert.equal(validCabinRequest({action:'read',airlineId}),true);
 assert.equal(validCabinRequest({action:'save',airlineId,state,expectedVersion:0}),true);
 assert.equal(validCabinRequest({action:'save',airlineId,state,expectedVersion:-1}),false);
 const bad=structuredClone(state);bad.packages[0].items.water.onlineCents=-1;
 assert.equal(validCabinState(bad),false);
 const forged=structuredClone(state);forged.packages[0].name='Unlimited gourmet food';
 assert.equal(validCabinState(forged),false);
 const extra=structuredClone(state);extra.extra='forbidden';
 assert.equal(validCabinState(extra),false);
 assert.match(CABIN_SQL.save,/ON CONFLICT \(airline_id\) DO UPDATE/);
 assert.match(CABIN_SQL.save,/WHERE c.version=\$4::integer/);
 assert.doesNotMatch(CABIN_SQL.save,/airline_ledger|flight_schedule|cash_usd/i);
});
test('authenticated owner can read defaults, foreign airline is denied',async()=>{
 let allowed=true,queryCount=0;
 const handler=createCabinServicesHandler({
  verifyUserToken:async()=>({user:{id:playerId}}),
  database:{connect:async()=>({query:async sql=>{
   queryCount++;
   if(sql===CABIN_SQL.owner)return {rowCount:allowed?1:0,rows:allowed?[{}]:[]};
   return {rowCount:0,rows:[]};
  },release(){}})}
 });
 const response=await handler(req({action:'read',airlineId}));
 assert.equal(response.status,200);assert.equal((await response.json()).version,0);
 assert.equal(queryCount,2);
 allowed=false;
 assert.equal((await handler(req({action:'read',airlineId}))).status,403);
 assert.equal((await handler(req({action:'save',airlineId,state,expectedVersion:0}))).status,403);
});
test('stale writes conflict, save never claims live financial effects',async()=>{
 let mode='conflict';
 const handler=createCabinServicesHandler({
  verifyUserToken:async()=>({user:{id:playerId}}),
  database:{connect:async()=>({query:async sql=>{
   if(sql===CABIN_SQL.owner)return {rowCount:1,rows:[{}]};
   if(mode==='conflict')return {rowCount:0,rows:[]};
   return {rowCount:1,rows:[{state,version:1,updatedAt:null}]};
  },release(){}})}
 });
 const payload={action:'save',airlineId,state,expectedVersion:0};
 const conflict=await handler(req(payload));assert.equal(conflict.status,409);
 mode='success';
 const success=await handler(req(payload)),result=await success.json();
 assert.equal(success.status,200);assert.equal(result.source,'supabase');
 assert.equal(result.ledgerPosted,false);assert.equal(result.flightsChanged,false);
});
test('production proxy and browser client use the isolated secure endpoint',async()=>{
 let sent=null;
 const api=createProductionGameApi({fetchImpl:async(url,options)=>{
  sent={url,options};return Response.json({state,version:0,source:'supabase',schemaId:CABIN_DATA_SCHEMA_ID,operational:false});
 }});
 const incoming=new Request('https://airlinerra.com'+CABIN_ROUTE,{
  method:'POST',headers:{authorization:'Bearer '+('a'.repeat(50)),
   origin:'https://airlinerra.com','content-type':'application/json'},
  body:JSON.stringify({action:'read',airlineId})
 });
 assert.equal((await api(incoming)).status,200);
 assert.equal(sent.url,CABIN_EDGE_URL);
 assert.equal(sent.options.headers['x-airlinerra-route'],CABIN_ROUTE);
 const client=createCabinServicesClient({auth:{getAccessToken:async()=>('a'.repeat(50))},
  origin:'https://airlinerra.com',fetchImpl:async(url,options)=>{
   assert.equal(url,'https://airlinerra.com'+CABIN_ROUTE);
   assert.equal(JSON.parse(options.body).airlineId,airlineId);
   return Response.json({state,version:0,source:'supabase',schemaId:CABIN_DATA_SCHEMA_ID,operational:false});
  }});
 assert.equal((await client.read(airlineId)).version,0);
});
test('protected build includes the cabin service module and no direct secret SQL',async()=>{
 const get=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
 const [overlay,netlify,player,manager,migration]=await Promise.all([
  get('website/dev-scripts/invited-overlay.mjs'),get('website/netlify/functions/airlinerra-game.mjs'),
  get('website/player-app.mjs'),get('website/cabin-services-manager.mjs'),
  get('supabase/migrations/20261110174000_airlinerra_cabin_services_owner_settings_v1.sql')
 ]);
 assert.match(overlay,/'cabin-services-client\.mjs'/);
 assert.match(netlify,/\/api\/v1\/player\/cabin-services/);
 assert.match(player,/createCabinServicesClient/);
 assert.match(manager,/remote\.read\(id\)/);
 assert.match(manager,/await persist\(\)/);
 assert.match(migration,/ENABLE ROW LEVEL SECURITY/);
 assert.match(migration,/REVOKE ALL/);
 assert.doesNotMatch(manager,/service_role|sb_secret_|\.auth\.signUp/);
});

test('localhost cabin client authenticates and posts only through its same-origin protected proxy',async()=>{
 const token='v'.repeat(48),calls=[];
 const client=createCabinServicesClient({
  auth:{getAccessToken:async()=>token},origin:'http://localhost:5188',
  fetchImpl:async(url,options)=>{
   calls.push({url,options});
   return Response.json({state,version:0,source:'supabase',schemaId:CABIN_DATA_SCHEMA_ID,operational:false});
  }
 });
 const read=await client.read(airlineId);
 assert.equal(read.version,0);
 assert.equal(calls.length,1);
 assert.equal(calls[0].url,'http://localhost:5188'+CABIN_ROUTE);
 assert.equal(calls[0].options.headers.authorization,'Bearer '+token);
 assert.equal(calls[0].options.mode,'same-origin');
 assert.equal(calls[0].options.credentials,'omit');
 assert.throws(()=>createCabinServicesClient({
  auth:{getAccessToken:async()=>token},origin:'http://127.0.0.1:5188'
 }),/trusted-origin cabin client/);
 assert.throws(()=>createCabinServicesClient({
  auth:{getAccessToken:async()=>token},origin:'https://attacker.example'
 }),/trusted-origin cabin client/);
});

test('current Basic Flight Services and a newly created custom package are valid in owner API',async()=>{
 const state=initialCabinState();
 assert.equal(state.packages[0].name,'Basic Flight Services');
 const newPackage=structuredClone(createBasicCabinPackage());
 newPackage.id='pkg-1';
 newPackage.name='New flight package';
 newPackage.locked=false;
 newPackage.items.coffee.mode='included';
 state.packages.push(cleanCabinPackage(newPackage));
 const request={action:'save',airlineId,state,expectedVersion:0};
 assert.deepEqual(cleanCabinState(state),state);
 assert.equal(validCabinRequest(request),true,
  'A package created by the live editor must pass the backend validation');
 const calls=[];
 const handle=createCabinServicesHandler({
  verifyUserToken:async()=>({user:{id:playerId}}),
  database:{connect:async()=>({query:async(sql,args)=>{
   calls.push(sql);
   if(sql===CABIN_SQL.owner)return {rowCount:1,rows:[{}]};
   if(sql===CABIN_SQL.save)return {rowCount:1,rows:[{state,version:1,updatedAt:null}]};
   throw Error('unexpected query');
  },release(){}})}
 });
 const response=await handle(req(request));
 assert.equal(response.status,200);
 const body=await response.json();
 assert.deepEqual(body.state.packages.map(p=>p.name),['Basic Flight Services','New flight package']);
 assert.equal(body.ledgerPosted,false);
 assert.equal(calls.length,2);
});

test('browser rejects an older deployed cabin service model and explains why new package is unavailable',async()=>{
 const basic=initialCabinState();
 const client=createCabinServicesClient({
  auth:{getAccessToken:async()=>('z'.repeat(48))},
  origin:'https://airlinerra.com',
  fetchImpl:async()=>Response.json({
   state:basic,version:0,source:'supabase',
   schemaId:'old-basic-cabin-service',operational:false
  })
 });
 await assert.rejects(()=>client.read(airlineId),/CABIN_SCHEMA_MISMATCH/);
 const manager=await readFile(new URL('../website/cabin-services-manager.mjs',import.meta.url),'utf8');
 assert.match(manager,/if\(remote&&!ready&&!loading\)/);
 assert.match(manager,/data\.cabinAction='retry'/);
 assert.match(manager,/updateData\(lastData,\{force:true\}\)/);
 assert.match(manager,/Saving is unavailable until Supabase confirms/);
 assert.match(manager,/NOT SAVED — Supabase rejected the package/);
});
