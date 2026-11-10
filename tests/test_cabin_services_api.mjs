import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {initialCabinState} from '../website/cabin-services-manager.mjs';
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
  sent={url,options};return Response.json({state,version:0,source:'supabase',operational:false});
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
   return Response.json({state,version:0,source:'supabase',operational:false});
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
