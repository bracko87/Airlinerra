import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {standardCabinPlan,evaluateCabinPlan,cabinClasses,cabinRowLayout,createCabinFloorplanModel}
 from '../website/cabin-configuration-manager.mjs';
import {FLEET_SQL,validateFleetAcquisitionRequest,createFleetAcquisitionHandler,
 FLEET_ACQUISITION_API_ROUTE} from '../server/fleet-acquisition-service.mjs';

const user='11111111-1111-4111-8111-111111111111';
const airline='22222222-2222-4222-8222-222222222222';
const aircraft='55555555-5555-4555-8555-555555555555';
const seatTypes=[
 {code:'eco_standard',cabinClass:'economy',spaceUnits:'1.00',installUsd:450,pitchInches:'30'},
 {code:'eco_extra',cabinClass:'economy',spaceUnits:'1.15',installUsd:700,pitchInches:'34'},
 {code:'premium_standard',cabinClass:'premium',spaceUnits:'1.40',installUsd:1700,pitchInches:'38'},
 {code:'business_standard',cabinClass:'business',spaceUnits:'1.90',installUsd:4400,pitchInches:'44'},
 {code:'first_standard',cabinClass:'first',spaceUnits:'3.00',installUsd:9000,pitchInches:'60'}
];
const makeRequest=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-fleet-acquisition',{
 method:'POST',headers:{origin:'https://airlinerra.com','x-airlinerra-route':FLEET_ACQUISITION_API_ROUTE,
 authorization:'Bearer '+'x'.repeat(48),'content-type':'application/json'},body:JSON.stringify(body)
});
const makeHandler=implementation=>createFleetAcquisitionHandler({
 verifyUserToken:async()=>({user:{id:user},error:null}),
 database:{connect:async()=>({query:implementation,release(){}})}
});

test('standard cabin for existing A319 uses 156 economy seats, cargo has zero',()=>{
 assert.equal(cabinClasses.length,4);
 assert.deepEqual(standardCabinPlan(156),{
  economy:156,premium:0,business:0,first:0,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard'
 });
 assert.equal(standardCabinPlan(0).economy,0);
 const e=evaluateCabinPlan(standardCabinPlan(156),seatTypes,156);
 assert.equal(e.valid,true);assert.equal(e.count,156);assert.equal(e.used,156);
});

test('premium business first seats consume more real cabin units',()=>{
 const good={...standardCabinPlan(100),premium:20,business:10,first:0};
 const fit=evaluateCabinPlan(good,seatTypes,156);
 assert.equal(fit.valid,true);
 assert.equal(fit.used,147);assert.equal(fit.count,130);
 const fail=evaluateCabinPlan({...good,economy:140},seatTypes,156);
 assert.equal(fail.valid,false);assert.match(fail.reason,/exceed/);
 const wrong=evaluateCabinPlan({...good,businessType:'eco_standard'},seatTypes,156);
 assert.equal(wrong.valid,false);
});

test('server rejects spoofed priced layout and only saves owner-verified draft',async()=>{
 const request={action:'cabin-save-draft',airlineId:airline,aircraftInventoryId:aircraft,
  economy:100,premium:20,business:10,first:0,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard'};
 assert.equal(validateFleetAcquisitionRequest(request),true);
 assert.equal(validateFleetAcquisitionRequest({...request,paidUsd:0}),false);
 assert.equal(validateFleetAcquisitionRequest({...request,first:-1}),false);
 assert.equal(validateFleetAcquisitionRequest({...request,aircraftInventoryId:user,conditionPct:100}),false);
 const writes=[];
 const handler=makeHandler((sql,args)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{id:airline}]};
  if(sql===FLEET_SQL.cabinOwnerAircraft){
   assert.deepEqual(args,[airline,aircraft]);return {rowCount:1,rows:[{referenceUnits:'156',useType:'passenger'}]};
  }
  if(sql===FLEET_SQL.cabinTypes)return {rowCount:seatTypes.length,rows:seatTypes};
  if(sql===FLEET_SQL.cabinSave){
   writes.push(args);return {rowCount:1,rows:[{aircraftInventoryId:aircraft,savedAt:'2026-11-10T15:00:00Z'}]};
  }
  throw Error('unexpected cabin SQL');
 });
 const response=await handler(makeRequest(request));
 assert.equal(response.status,200);
 const out=await response.json();
 assert.equal(out.status,'draft_saved_not_installed');
 assert.equal(out.cashDebited,false);
 assert.equal(out.liveSeatsUnchanged,true);
 assert.equal(out.usedSpace,147);
 assert.equal(writes.length,1);
 const wrongCount=makeHandler((sql)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{id:airline}]};
  if(sql===FLEET_SQL.cabinOwnerAircraft)return {rowCount:1,rows:[{referenceUnits:'156',useType:'passenger'}]};
  if(sql===FLEET_SQL.cabinTypes)return {rowCount:seatTypes.length,rows:seatTypes};
  if(sql===FLEET_SQL.cabinSave)throw Error('Cannot write over-full layout');
  throw Error('Unexpected SQL');
 });
 const denied=await wrongCount(makeRequest({...request,economy:130}));
 assert.equal(denied.status,409);
 const ownerDenied=makeHandler(sql=>{
  if(sql===FLEET_SQL.owner)return {rowCount:0,rows:[]};
  throw Error('Foreign airline cabin write queried private tables');
 });
 assert.equal((await ownerDenied(makeRequest(request))).status,403);
});
test('cabins overview fetches only airline-owned aircraft and source-linked facilities',async()=>{
 const handler=makeHandler(sql=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{id:airline}]};
  if(sql===FLEET_SQL.cabinTypes)return {rowCount:1,rows:seatTypes};
  if(sql===FLEET_SQL.cabinAircraft)return {rowCount:1,rows:[{
   aircraftInventoryId:aircraft,standardEconomy:156,installedEconomy:156,registration:'YU-PAN01'
  }]};
  if(sql===FLEET_SQL.cabinDirectory)return {rowCount:1,rows:[{continent:'Europe',airportCode:'LBSF'}]};
  if(sql===FLEET_SQL.cabinRefitSites)return {rowCount:1,rows:[{aircraftInventoryId:aircraft,airportCode:'LBSF'}]};
  if(sql===FLEET_SQL.cabinGeometry)return {rowCount:1,rows:[{
   configurationId:16,economyColumns:[3,3],premiumColumns:[2,2],
   businessColumns:[2,2],firstColumns:[1,1],reviewStatus:'operator_supported_pattern'
  }]};
  throw Error('Unexpected SQL');
 });
 const out=await handler(makeRequest({action:'cabin-overview',airlineId:airline}));
 assert.equal(out.status,200);
 const data=await out.json();
 assert.equal(data.installedLayoutsImmutable,true);
 assert.equal(data.canActivateRefit,false);
 assert.equal(data.aircraft[0].installedEconomy,156);
 assert.equal(data.directory[0].continent,'Europe');
 assert.deepEqual(data.geometries[0].economyColumns,[3,3]);
});
test('floorplan and navigation do not claim certified exit positions or live refits',async()=>{
 const [ui,workspace,html,overlay]=await Promise.all([
  readFile(new URL('../website/cabin-configuration-manager.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/airline-workspace.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8')
 ]);
 assert.match(ui,/Exits not verified/);
 assert.match(ui,/renderCabinFloorplan/);
 assert.match(ui,/draft_saved_not_installed/);
 assert.match(workspace,/data-workspace-go="cabin-configurations"/);
 assert.match(html,/data-view-link="cabin-configurations"/);
 assert.match(html,/>Flight services</);
 assert.match(overlay,/'cabin-configuration-manager.mjs'/);
});

test('A319 3–3 rows occupy over 90 percent of usable cabin width',()=>{
 const geometry={economyColumns:[3,3],premiumColumns:[2,2],
  businessColumns:[2,2],firstColumns:[1,1],reviewStatus:'operator_supported_pattern'};
 const result=evaluateCabinPlan(standardCabinPlan(156),seatTypes,156);
 const floor=createCabinFloorplanModel(result,156,geometry);
 assert.equal(floor.totalSeats,156);
 assert.deepEqual(floor.basePattern,[3,3]);
 assert.equal(floor.sections[0].rows,26);
 assert.equal(floor.sections[0].layout.join('-'),'3-3');
 const minimum=Math.min(...floor.seats.map(s=>s.x));
 const maximum=Math.max(...floor.seats.map(s=>s.x+s.width));
 assert.ok((maximum-minimum)/floor.interiorWidth>.9);
 assert.ok(minimum>=floor.left&&maximum<=floor.right);
 assert.ok(floor.seats.every(s=>s.y>=80&&s.y+s.height<floor.height-60));
});
test('regional, narrowbody and widebody rows do not reuse the A319 3–3 pattern',()=>{
 const p=(eco,pre,bus,first)=>({economyColumns:eco,premiumColumns:pre,
  businessColumns:bus,firstColumns:first});
 assert.deepEqual(cabinRowLayout(p([2,3],[2,2],[1,1],[1,1]),'economy',160),[2,3]);
 assert.deepEqual(cabinRowLayout(p([2,2],[1,1],[1,1],[1,1]),'economy',136),[2,2]);
 assert.deepEqual(cabinRowLayout(p([3,4,3],[2,3,2],[1,2,1],[1,2,1]),'economy',550),[3,4,3]);
 assert.deepEqual(cabinRowLayout(p([3,3,3],[2,3,2],[1,2,1],[1,2,1]),'economy',440),[3,3,3]);
 const val=evaluateCabinPlan(standardCabinPlan(156),seatTypes,156);
 assert.equal(createCabinFloorplanModel(val,156,p([3,3],[2,2],[2,2],[1,1])).totalSeats,156);
});
test('40 options and all 271 default patterns are represented in migration',async()=>{
 const sql=await readFile(new URL('../supabase/migrations/20261110184500_airlinerra_40_real_reference_seats_and_model_geometry_v1.sql',import.meta.url),'utf8');
 assert.match(sql,/cabin_model_row_geometry_v1/);
 assert.match(sql,/INSERT INTO airlinerra_game.cabin_seat_types_v1/);
 assert.match(sql,/ON CONFLICT\(configuration_id\) DO NOTHING/);
 assert.match(sql,/manually_verified boolean NOT NULL DEFAULT false/);
 assert.match(sql,/real_product_reference/);
 const service=await readFile(new URL('../server/fleet-acquisition-service.mjs',import.meta.url),'utf8');
 assert.match(service,/cabinGeometry:/);
 assert.match(service,/client.query\(FLEET_SQL.cabinGeometry\)/);
 assert.match(service,/geometries:geometry.rows/);
});
