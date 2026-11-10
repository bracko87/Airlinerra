import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createFleetAcquisitionHandler,validateFleetAcquisitionRequest,
 FLEET_SQL,FLEET_ACQUISITION_API_ROUTE
} from '../server/fleet-acquisition-service.mjs';
import {createFleetAcquisitionClient} from '../website/fleet-acquisition-client.mjs';
import {createProductionGameApi,FLEET_EDGE_URL,FLEET_ROUTE} from '../server/production-game-api.mjs';

const user='11111111-1111-4111-8111-111111111111';
const airline='22222222-2222-4222-8222-222222222222';
const offer='33333333-3333-4333-8333-333333333333';
const requestId='44444444-4444-4444-8444-444444444444';
const aircraft='55555555-5555-4555-8555-555555555555';
const TOKEN='v'.repeat(48);
const base={action:'acquire',airlineId:airline,offerId:offer,
 registration:'D-ABCD',requestId};
const request=(body,headers={})=>new Request(
 'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-fleet-acquisition',{
 method:'POST',headers:{
  origin:'https://airlinerra.com','x-airlinerra-route':FLEET_ACQUISITION_API_ROUTE,
  authorization:'Bearer '+TOKEN,'content-type':'application/json',...headers
 },body:JSON.stringify(body)
});
function setup(query,verify=async()=>({user:{id:user},error:null})){
 const statements=[];let releases=0;
 const database={connect:async()=>({
  query:async(sql,args)=>{statements.push({sql,args});return query(sql,args)},
  release(){releases++}
 })};
 return {handler:createFleetAcquisitionHandler({verifyUserToken:verify,database}),
  statements,releases:()=>releases};
}
const receipt={orderId:requestId,aircraftInventoryId:aircraft,
 registration:'D-ABCD',transactionType:'purchase',paidUpfrontUsd:'250000.00',
 remainingCashUsd:'4750000.00',deliveryStatus:'awaiting_delivery',
 fleetStatus:'stored',canScheduleFlight:false,canActivateFlight:false};

test('fleet request validator accepts exact payloads; rejects spoofed identities and client-supplied prices',()=>{
 assert.equal(validateFleetAcquisitionRequest(base),true);
 assert.equal(validateFleetAcquisitionRequest({action:'list',airlineId:airline}),true);
 assert.equal(validateFleetAcquisitionRequest({...base,priceUsd:0}),false);
 assert.equal(validateFleetAcquisitionRequest({...base,playerId:user}),false);
 assert.equal(validateFleetAcquisitionRequest({...base,requestId:'not-a-uuid'}),false);
 assert.equal(validateFleetAcquisitionRequest({...base,registration:'X!'}),false);
 assert.equal(validateFleetAcquisitionRequest({...base,offerId:'aircraft-catalog:3'}),false);
 assert.equal(validateFleetAcquisitionRequest({...base,action:'deliver'}),false);
 assert.equal(validateFleetAcquisitionRequest({...base,action:'activate'}),false);
});
test('only valid owner-scoped nickname changes are accepted',async()=>{
 const rename={action:'update-nickname',airlineId:airline,aircraftInventoryId:aircraft,nickname:'Cloud Rider'};
 assert.equal(validateFleetAcquisitionRequest(rename),true);
 assert.equal(validateFleetAcquisitionRequest({...rename,nickname:''}),true);
 assert.equal(validateFleetAcquisitionRequest({...rename,nickname:'X'.repeat(41)}),false);
 assert.equal(validateFleetAcquisitionRequest({...rename,nickname:'Bad\nName'}),false);
 assert.equal(validateFleetAcquisitionRequest({...rename,playerId:user}),false);
 const queryCalls=[];
 const owned=setup((sql,args)=>{
  queryCalls.push({sql,args});
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{id:airline}]};
  if(sql===FLEET_SQL.nickname)return {rowCount:1,rows:[{id:aircraft,nickname:'Cloud Rider'}]};
  throw Error('Unexpected nickname query');
 });
 const response=await owned.handler(request(rename));
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),{id:aircraft,nickname:'Cloud Rider'});
 assert.deepEqual(queryCalls[1].args,[airline,aircraft,'Cloud Rider']);
 const denied=setup((sql)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:0,rows:[]};
  throw Error('Foreign nickname write must not execute');
 });
 assert.equal((await denied.handler(request(rename))).status,403);
});
test('maintenance preview is a read-only owner-verified six-check profile with type-specific MROs',async()=>{
 const body={action:'maintenance-preview',airlineId:airline,aircraftInventoryId:aircraft};
 assert.equal(validateFleetAcquisitionRequest(body),true);
 for(const extra of [{priceUsd:0},{approved:true},{targetAirportKey:'OURAIRPORTS:1'},
  {conditionPct:100},{aircraftInventoryId:'invalid'}])
  assert.equal(validateFleetAcquisitionRequest({...body,...extra}),false);
 const checks=['daily','weekly','a','b','c','d'].map(checkCode=>({
  checkCode,durationHours:checkCode==='a'?6:1,groupName:'Small narrowbody',
  manufactureYear:null,conditionPct:null,lastCompletedUtc:null
 }));
 const site={checkCode:'c',airportKey:'OURAIRPORTS:26887',
  airportCode:'WSSS',airportName:'Singapore Changi Airport',provider:'SIA Engineering'};
 const scoped=setup((sql,args)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{id:airline}]};
  if(sql===FLEET_SQL.maintenance){
   assert.deepEqual(args,[airline,aircraft]);return {rowCount:6,rows:checks};
  }
  if(sql===FLEET_SQL.maintenanceSites){
   assert.deepEqual(args,[airline,aircraft]);return {rowCount:1,rows:[site]};
  }
  throw Error('Unapproved maintenance SQL');
 });
 const response=await scoped.handler(request(body));
 assert.equal(response.status,200);
 const payload=await response.json();
 assert.equal(payload.previewOnly,true);
 assert.equal(payload.canScheduleMaintenance,false);
 assert.equal(payload.canBookFerryFlight,false);
 assert.equal(payload.checks.length,6);
 assert.equal(payload.maintenanceSites[0].airportCode,'WSSS');
 const foreign=setup(sql=>{
  if(sql===FLEET_SQL.owner)return {rowCount:0,rows:[]};
  throw Error('Foreign airframe maintenance read must be blocked');
 });
 assert.equal((await foreign.handler(request(body))).status,403);
});
test('auth, same-origin route, and safe payload validation run before opening a database connection',async()=>{
 let used=false;
 const {handler}=setup(()=>{used=true;throw Error('Unexpected query')},
  async()=>({user:{id:user},error:null}));
 assert.equal((await handler(request(base,{authorization:''}))).status,401);
 assert.equal((await handler(request(base,{origin:'https://evil.example'}))).status,403);
 assert.equal((await handler(request({...base,priceUsd:1}))).status,400);
 assert.equal((await handler(request({action:'activate',airlineId:airline}))).status,400);
 assert.equal(used,false);
});
test('fleet Edge accepts Supabase-internal URL rewrites, while origin, route and user ownership stay enforced',async()=>{
 const {handler}=setup((sql,args)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{id:airline,cashUsd:'5000000.00'}]};
  if(sql===FLEET_SQL.offers)return {rowCount:0,rows:[]};
  if(sql===FLEET_SQL.fleet)return {rowCount:1,rows:[{
   id:aircraft,registration:'YU-PAN01',ownershipType:'owned',fleetStatus:'in_service'
  }]};
  throw Error('Unexpected read');
 });
 const makeInternal=(headers={})=>new Request('http://internal-edge-runtime/airlinerra-fleet-acquisition',{
  method:'POST',headers:{
   origin:'https://airlinerra.com',
   'x-airlinerra-route':FLEET_ACQUISITION_API_ROUTE,
   authorization:'Bearer '+TOKEN,'content-type':'application/json',...headers
  },body:JSON.stringify({action:'list',airlineId:airline})
 });
 const ok=await handler(makeInternal());
 assert.equal(ok.status,200);
 assert.equal((await ok.json()).fleet[0].registration,'YU-PAN01');
 const wrongRoute=makeInternal({'x-airlinerra-route':'/api/v1/player/overview'});
 assert.equal((await handler(wrongRoute)).status,403);
 const wrongOrigin=makeInternal({origin:'https://attacker.example'});
 assert.equal((await handler(wrongOrigin)).status,403);
 const other=setup((sql,args)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:0,rows:[]};
  throw Error('No foreign fleet access');
 });
 assert.equal((await other.handler(makeInternal())).status,403);
});
test('list is scoped to verified airline owner and returns only approved offers and real inventory',async()=>{
 const {handler,statements,releases}=setup((sql,args)=>{
  if(sql===FLEET_SQL.owner){
   assert.deepEqual(args,[airline,user]);
   return {rowCount:1,rows:[{id:airline,cashUsd:'5000000.00'}]};
  }
  if(sql===FLEET_SQL.offers)return {rowCount:1,rows:[{
   offerId:offer,configurationId:3,transactionType:'purchase',
   upfrontPriceUsd:'250000.00',model:'A320-200'}]};
  if(sql===FLEET_SQL.fleet){
   assert.deepEqual(args,[airline]);
   return {rowCount:1,rows:[{id:aircraft,registration:'D-ABCD',
    fleetStatus:'stored',ownershipType:'owned',deliveryStatus:'awaiting_delivery'}]};
  }
  throw Error('Unexpected SQL');
 });
 const response=await handler(request({action:'list',airlineId:airline}));
 const payload=await response.json();
 assert.equal(response.status,200);
 assert.equal(payload.liveFlightActivation,false);
 assert.equal(payload.offers.length,1);
 assert.equal(payload.fleet[0].fleetStatus,'stored');
 assert.equal(payload.cashUsd,'5000000.00');
 assert.equal(statements.length,3);
 assert.equal(releases(),1);
});
test('foreign account cannot even list market data',async()=>{
 const {handler,statements}=setup(sql=>{
  assert.equal(sql,FLEET_SQL.owner);return {rowCount:0,rows:[]};
 });
 assert.equal((await handler(request({action:'list',airlineId:airline}))).status,403);
 assert.equal(statements.length,1);
});
test('acquire injects fresh server identity; browser never supplies a price or fleet status',async()=>{
 const {handler,statements}=setup((sql,args)=>{
  assert.equal(sql,FLEET_SQL.acquire);
  assert.deepEqual(args,[user,airline,offer,'D-ABCD',requestId]);
  return {rowCount:1,rows:[{result:receipt}]};
 });
 const result=await handler(request({...base,registration:'d-abcd'}));
 assert.equal(result.status,200);
 assert.deepEqual(await result.json(),receipt);
 assert.equal(statements.length,1);
});
test('insufficient cash or retired offers return conflicts; no purchase can activate flights',async()=>{
 for(const code of ['INSUFFICIENT_AIRLINE_CASH','AIRCRAFT_OFFER_NOT_AVAILABLE',
  'ACQUISITION_IDEMPOTENCY_KEY_REUSED']){
  const {handler}=setup(()=>{throw Object.assign(Error(code),{code:'P0001'});});
  const res=await handler(request(base));
  assert.equal(res.status,409);
  assert.equal((await res.json()).reason,code);
 }
 assert.equal(validateFleetAcquisitionRequest({...base,action:'activate'}),false);
});
test('player browser talks to pinned same-origin fleet route with access token only',async()=>{
 const calls=[];
 const client=createFleetAcquisitionClient({auth:{getAccessToken:async()=>TOKEN},
  origin:'https://airlinerra.com',fetchImpl:async(url,options)=>{
   calls.push({url,options});return Response.json(receipt);
  }});
 const result=await client.acquire({...base});
 assert.equal(result.canScheduleFlight,false);
 assert.equal(calls.length,1);
 assert.equal(calls[0].url,'https://airlinerra.com'+FLEET_ACQUISITION_API_ROUTE);
 assert.equal(calls[0].options.credentials,'omit');
 assert.equal(calls[0].options.headers.authorization,'Bearer '+TOKEN);
 assert.equal(JSON.parse(calls[0].options.body).playerId,undefined);
 assert.equal(JSON.parse(calls[0].options.body).priceUsd,undefined);
 assert.equal(JSON.parse(calls[0].options.body).requestId,requestId);
});
test('Netlify proxy forwards fleet requests only to the dedicated pinned Supabase Edge function',async()=>{
 const hits=[];const app=createProductionGameApi({fetchImpl:async(url,options)=>{
  hits.push({url,options});return Response.json({fleet:[],offers:[]});
 }});
 const res=await app(new Request('https://airlinerra.com'+FLEET_ROUTE,{
  method:'POST',headers:{authorization:'Bearer '+TOKEN,origin:'https://airlinerra.com'},
  body:JSON.stringify({action:'list',airlineId:airline})
 }));
 assert.equal(res.status,200);
 assert.equal(hits.length,1);
 assert.equal(hits[0].url,FLEET_EDGE_URL);
 assert.equal(hits[0].options.headers['x-airlinerra-route'],FLEET_ROUTE);
});
test('market and owned fleet pages use authenticated data without fabricated prices',async()=>{
 const read=p=>readFile(new URL(p,import.meta.url),'utf8');
 const [workspace,app,overlay]=await Promise.all([
  read('../website/airline-workspace.mjs'),
  read('../website/player-app.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs')
 ]);
 for(const id of ['fleet-owned-aircraft','fleet-owned-count','fleet-leased-count',
  'market-offers','market-offer-select','market-aircraft-registration','market-acquire'])
  assert.ok(workspace.includes(id),'Missing fleet or market control: '+id);
 assert.match(workspace,/data\.fleetClient\.acquire\(/);
 assert.match(workspace,/client\.list\(airlineId\)/);
 assert.match(app,/createFleetAcquisitionClient/);
 assert.match(overlay,/'fleet-acquisition-client.mjs'/);
 assert.doesNotMatch(workspace,/sb_secret_|service_role/);
});


test('delivery requests require exact owner-scoped IDs and cannot claim inspection approvals',()=>{
 assert.equal(validateFleetAcquisitionRequest({
  action:'check-delivery',airlineId:airline,orderId:requestId}),true);
 assert.equal(validateFleetAcquisitionRequest({
  action:'check-delivery',airlineId:airline,orderId:requestId,approved:true}),false);
 assert.equal(validateFleetAcquisitionRequest({
  action:'check-delivery',airlineId:airline,orderId:'not-an-id'}),false);
 assert.equal(validateFleetAcquisitionRequest({
  action:'inspect',airlineId:airline,orderId:requestId}),false);
});
test('delivery uses database owner-verified transition, not browser-supplied state or time',async()=>{
 const expected={orderId:requestId,aircraftInventoryId:aircraft,
  deliveryStatus:'delivered_pending_inspection',
  inspectionStatus:'pending_inspection',fleetStatus:'stored',
  canScheduleFlight:false,canActivateFlight:false};
 const {handler,statements,releases}=setup((sql,args)=>{
  assert.equal(sql,FLEET_SQL.delivery);
  assert.deepEqual(args,[user,airline,requestId]);
  return {rowCount:1,rows:[{result:expected}]};
 });
 const res=await handler(request({
  action:'check-delivery',airlineId:airline,orderId:requestId}));
 assert.equal(res.status,200);
 assert.deepEqual(await res.json(),expected);
 assert.equal(statements.length,1);
 assert.equal(releases(),1);
});
test('browser delivery lookup passes just order ID, never approval or game-time values',async()=>{
 const calls=[];
 const client=createFleetAcquisitionClient({
  auth:{getAccessToken:async()=>TOKEN},
  origin:'https://airlinerra.com',
  fetchImpl:async(url,options)=>{
   calls.push({url,options});
   return Response.json({orderId:requestId,deliveryStatus:'awaiting_delivery',
     fleetStatus:'stored',canActivateFlight:false});
  }
 });
 const data=await client.checkDelivery({airlineId:airline,orderId:requestId});
 assert.equal(data.canActivateFlight,false);
 assert.equal(calls.length,1);
 assert.deepEqual(JSON.parse(calls[0].options.body),
  {action:'check-delivery',airlineId:airline,orderId:requestId});
});
test('fleet page exposes owner delivery check while leaving actual flight release locked',async()=>{
 const workspace=await readFile(new URL('../website/airline-workspace.mjs',import.meta.url),'utf8');
 assert.match(workspace,/data\.fleetClient\.checkDelivery\(/);
 assert.match(workspace,/data-aircraft-delivery/);
 assert.match(workspace,/inspection is required before it can be scheduled/i);
 assert.match(workspace,/fleet-delivery-feedback/);
});
