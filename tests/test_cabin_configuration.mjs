import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {standardCabinPlan,evaluateCabinPlan,estimateCabinRefit,cabinClasses,cabinRowLayout,createCabinFloorplanModel,renderCabinFloorplan,validateCabinModelRows,
 passengerRatingView,createPassengerRatingGauge,updatePassengerRatingGauge,
 cheapestCabinSeat,seatQualityBonus,cabinSeatDisplayName,CABIN_SEAT_GAME_NAMES,appendRow}
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
  businessType:'business_standard',firstType:'first_standard',extraLegroomCm:0
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
 assert.equal(fail.valid,false);assert.match(fail.reason,/NO SPACE/);
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
  if(sql===FLEET_SQL.cabinModelDesigns)return {rowCount:0,rows:[]};
  if(sql===FLEET_SQL.cabinDirectory)return {rowCount:1,rows:[{continent:'Europe',airportCode:'LBSF'}]};
  if(sql===FLEET_SQL.cabinRefitSites)return {rowCount:1,rows:[{aircraftInventoryId:aircraft,airportCode:'LBSF'}]};
  if(sql===FLEET_SQL.cabinGeometry)return {rowCount:1,rows:[{
   configurationId:16,economyColumns:[3,3],premiumColumns:[3,3],
   businessColumns:[2,2],firstColumns:[1,1],reviewStatus:'operator_supported_pattern'
  }]};
  if(sql===FLEET_SQL.cabinStandards)return {rowCount:1,rows:[
   {configurationId:16,useType:'passenger',referenceUnits:'156',economy:156}]};
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
 assert.equal(data.standards[0].economy,156);
});
test('floorplan and navigation do not claim certified exit positions or live refits',async()=>{
 const [ui,workspace,html,overlay]=await Promise.all([
  readFile(new URL('../website/cabin-configuration-manager.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/airline-workspace.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8')
 ]);
 assert.match(ui,/exit positions and certification/);
 assert.match(ui,/renderCabinFloorplan/);
 assert.match(ui,/model_design_saved_not_installed/);
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
 assert.ok(floor.seats.every(s=>s.y>=55&&s.y+s.height<floor.height-45));
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
test('extra centimetres consume cabin space, render no-space placeholder, and preserve first-to-rear cabin order',()=>{
 const base=standardCabinPlan(156);
 const a=evaluateCabinPlan(base,seatTypes,156);
 const two=evaluateCabinPlan({...base,extraLegroomCm:2},seatTypes,156);
 const eight=evaluateCabinPlan({...base,extraLegroomCm:8},seatTypes,156);
 assert.equal(a.spacePct,100);
 assert.equal(two.valid,false);
 assert.ok(two.spacePct>100);
 assert.match(two.reason,/NO SPACE/);
 assert.equal(eight.valid,false);
 assert.equal(evaluateCabinPlan({...base,extraLegroomCm:-1},seatTypes,156).valid,false);
 const roomy=evaluateCabinPlan({...standardCabinPlan(120),extraLegroomCm:5},seatTypes,156);
 assert.equal(roomy.valid,true);
 assert.ok(roomy.spacePct>120/156*100);
 const mix=evaluateCabinPlan({...standardCabinPlan(60),premium:12,business:8,first:4},seatTypes,156);
 const g={economyColumns:[3,3],premiumColumns:[3,3],businessColumns:[2,2],firstColumns:[1,1]};
 const floor=createCabinFloorplanModel(mix,156,g);
 assert.deepEqual(floor.sections.map(x=>x.className),['first','business','premium','economy']);
 assert.deepEqual(floor.sections.map(x=>x.layout),[[1,1],[2,2],[3,3],[3,3]]);
 assert.ok(floor.sections.every((section,i,arr)=>i===0||section.firstSeatY>arr[i-1].lastSeatY));
 assert.ok(floor.seats.every(x=>x.y+x.height<floor.height-45));
 const tags=[],fakeSvg={replaceChildren(){tags.length=0},setAttribute(){},
  append(node){tags.push(node)}};
 const fakeDoc={createElementNS(_ns,type){return {type,attrs:{},setAttribute(k,v){this.attrs[k]=v},textContent:''}}};
 renderCabinFloorplan(fakeDoc,fakeSvg,base,two,156,g);
 assert.ok(tags.some(tag=>tag.textContent==='NO SPACE'));
 assert.ok(tags.some(tag=>tag.type==='rect'&&tag.attrs.rx==='0'));
 assert.equal(tags.filter(tag=>tag.type==='rect').length,3);
});
test('cabin quote combines equipment and removal/installation only once; booking effect stays small',()=>{
 const plan={...standardCabinPlan(100),premium:20,business:10,extraLegroomCm:1};
 const result=evaluateCabinPlan(plan,seatTypes,156);
 assert.equal(result.valid,true);
 assert.ok(result.comfortRating>=0&&result.comfortRating<=100);
 assert.ok(Math.abs(result.bookingPreferencePreviewPct)<=1.5);
 const q=estimateCabinRefit(result,156,1.1);
 const labor=Math.round((5000+130*150+156*75)*1.1);
 assert.equal(q.removalAndInstallationUsd,labor);
 assert.equal(q.seatEquipmentUsd,result.equipmentUsd);
 assert.equal(q.totalUsd,q.seatEquipmentUsd+q.removalAndInstallationUsd);
 assert.equal(q.chargeTriggered,false);
});
test('server persists legroom and rejects tampered high-pitch drafts without modifying live inventory',async()=>{
 const draft={action:'cabin-save-draft',airlineId:airline,aircraftInventoryId:aircraft,
  economy:120,premium:0,business:0,first:0,extraLegroomCm:3,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard'};
 assert.equal(validateFleetAcquisitionRequest(draft),true);
 for(const bad of [-1,20.1,50,'3',0.123])
  assert.equal(validateFleetAcquisitionRequest({...draft,extraLegroomCm:bad}),false);
 let writeArgs=null;
 const handler=makeHandler((sql,args)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{}]};
  if(sql===FLEET_SQL.cabinOwnerAircraft)return {rowCount:1,
   rows:[{referenceUnits:'156',useType:'passenger',installedSeatCount:156}]};
  if(sql===FLEET_SQL.cabinTypes)return {rowCount:seatTypes.length,rows:seatTypes};
  if(sql===FLEET_SQL.cabinSave){writeArgs=args;return {rowCount:1,rows:[{aircraftInventoryId:aircraft}]};}
  throw Error('Unexpected query');
 });
 const resp=await handler(makeRequest(draft));
 assert.equal(resp.status,200);const body=await resp.json();
 assert.equal(body.extraLegroomCm,3);
 assert.equal(writeArgs[10],3);
 assert.equal(body.cashDebited,false);assert.equal(body.chargedUsd,0);
 assert.equal(body.estimatedRefitTotalUsd,
  body.estimatedSeatEquipmentUsd+body.estimatedRemovalAndInstallationUsd);
 writeArgs=null;
 const over=await handler(makeRequest({...draft,economy:156}));
 assert.equal(over.status,409);assert.equal(writeArgs,null);
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

test('A319 named templates require full 3–3 / 3–3 / 2–2 / 1–1 rows',()=>{
 const geometry={economyColumns:[3,3],premiumColumns:[3,3],
  businessColumns:[2,2],firstColumns:[1,1]};
 const valid={...standardCabinPlan(132),premium:12,business:4,first:2};
 assert.equal(validateCabinModelRows(valid,geometry,156).valid,true);
 for(const [key,n,needed] of [
  ['economy',145,6],['premium',11,6],['business',3,4],['first',1,2]]){
  const checked=validateCabinModelRows({...valid,[key]:n},geometry,156);
  assert.equal(checked.valid,false);
  assert.match(checked.reason,new RegExp(String(needed)));
 }
 const near={...standardCabinPlan(138),premium:12};
 const quote=evaluateCabinPlan(near,seatTypes,156);
 assert.equal(quote.valid,true);
 assert.ok(quote.spacePct>98);
 const nearFloor=createCabinFloorplanModel(quote,156,geometry);
 const nearestRear=Math.max(...nearFloor.seats.map(x=>x.y+x.height));
 assert.ok(nearFloor.height-45-nearestRear<35,'near-full cabin has no oversized rear void');
 const sparse=evaluateCabinPlan(standardCabinPlan(72),seatTypes,156);
 const sparseFloor=createCabinFloorplanModel(sparse,156,geometry);
 const sparseRear=Math.max(...sparseFloor.seats.map(x=>x.y+x.height));
 assert.ok(sparseFloor.height-45-sparseRear>100,'unused space remains visible');
});

test('model designs are owner verified, named and saved independently of installed aircraft',async()=>{
 const req={action:'cabin-save-model-design',airlineId:airline,configurationId:16,
  name:'A319 Comfort 156',economy:120,premium:12,business:4,first:2,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard',extraLegroomCm:0};
 assert.equal(validateFleetAcquisitionRequest(req),true);
 assert.equal(validateFleetAcquisitionRequest({...req,name:' '}),false);
 assert.equal(validateFleetAcquisitionRequest({...req,name:'A'.repeat(81)}),false);
 assert.equal(validateFleetAcquisitionRequest({...req,paidUsd:999}),false);
 let writes=0;
 const handler=makeHandler((sql,args)=>{
  if(sql===FLEET_SQL.owner)return {rowCount:1,rows:[{}]};
  if(sql===FLEET_SQL.cabinModelOwner)return {rowCount:1,rows:[{
   referenceUnits:'156',useType:'passenger',
   economyColumns:[3,3],premiumColumns:[3,3],
   businessColumns:[2,2],firstColumns:[1,1]
  }]};
  if(sql===FLEET_SQL.cabinTypes)return {rowCount:seatTypes.length,rows:seatTypes};
  if(sql===FLEET_SQL.cabinModelSave){writes++;
   assert.equal(args[0],airline);assert.equal(args[1],16);
   assert.equal(args[2],'A319 Comfort 156');
   return {rowCount:1,rows:[{designId:'66666666-6666-4666-8666-666666666666',
    configurationId:16,name:req.name}]};}
  throw Error('Unexpected model-design SQL');
 });
 const out=await handler(makeRequest(req));
 assert.equal(out.status,200);
 const body=await out.json();
 assert.equal(body.status,'model_design_saved_not_installed');
 assert.equal(body.liveSeatsUnchanged,true);
 assert.equal(body.cashDebited,false);
 assert.equal(writes,1);
 assert.equal((await handler(makeRequest({...req,economy:133}))).status,409);
 assert.equal(writes,1,'partial Economy row cannot be persisted');
 const foreign=makeHandler(sql=>{
  if(sql===FLEET_SQL.owner)return {rowCount:0,rows:[]};
  throw Error('Owner gate bypassed');
 });
 assert.equal((await foreign(makeRequest(req))).status,403);
});

test('model editor displays a concise usage summary and a read-only 0–100 passenger rating',async()=>{
 const ui=await readFile(new URL('../website/cabin-configuration-manager.mjs',import.meta.url),'utf8');
 const css=await readFile(new URL('../website/player-app.css',import.meta.url),'utf8');
 const ownerUpdate=ui.split(' function updateLayout(){')[1].split(' async function reload(){')[0];
 assert.match(ownerUpdate,/% of available cabin space used/);
 assert.match(ownerUpdate,/% remaining/);
 assert.doesNotMatch(ownerUpdate,/describeCabinPatterns|bookingPreferencePreviewPct|game-design preview/i);
 assert.match(ownerUpdate,/updatePassengerRatingGauge\(ratingGauge,valid\?result:null\)/);
 assert.match(css,/\.cabin-passenger-rating-track/);
 assert.match(css,/\.cabin-passenger-rating-value/);
 const elements=[];
 const doc={createElement(tag){
  const item={tag,className:'',textContent:'',style:{},attrs:{},children:[],
   append(...children){this.children.push(...children)},
   setAttribute(name,value){this.attrs[name]=String(value)}};
  elements.push(item);return item;
 }};
 const gauge=createPassengerRatingGauge(doc);
 assert.equal(gauge.track.attrs.role,'meter');
 assert.equal(gauge.track.attrs['aria-valuemin'],'0');
 assert.equal(gauge.track.attrs['aria-valuemax'],'100');
 assert.equal(gauge.root.children.length,2);
 assert.equal(passengerRatingView({valid:true,comfortRating:52}).value,52);
 updatePassengerRatingGauge(gauge,{valid:true,comfortRating:52});
 assert.equal(gauge.value.textContent,'52 / 100');
 assert.equal(gauge.fill.style.width,'52%');
 assert.equal(gauge.thumb.style.left,'52%');
 assert.equal(gauge.track.attrs['aria-valuenow'],'52');
 assert.match(gauge.note.textContent,/game rating, not real feedback/);
 updatePassengerRatingGauge(gauge,{valid:true,comfortRating:101});
 assert.equal(gauge.fill.style.width,'100%','display is capped to 100');
 updatePassengerRatingGauge(gauge,{valid:true,comfortRating:-5});
 assert.equal(gauge.fill.style.width,'0%','display is never negative');
 updatePassengerRatingGauge(gauge,null);
 assert.equal(gauge.value.textContent,'— / 100');
 assert.match(gauge.root.className,/cabin-rating-unavailable/);
 assert.match(gauge.track.attrs['aria-valuetext'],/unavailable/);
});

test('all forty catalog seats have original fictional game brands and preserve stable IDs',()=>{
 assert.equal(Object.keys(CABIN_SEAT_GAME_NAMES).length,40);
 assert.equal(new Set(Object.values(CABIN_SEAT_GAME_NAMES)).size,40,
  'every seat type has a distinguishable fictional brand and model');
 for(const [code,name] of Object.entries(CABIN_SEAT_GAME_NAMES)){
  assert.ok(/^(Aervio|Veloran|Nuvella|Orvessa|Selyra|Aeressa) [EPBF][0-9]{3}$/.test(name),
   'seat '+code+' has a game-specific product name');
  assert.ok(!/Safran|Recaro|Collins|ZIM|ANA|Emirates|Lufthansa|Geven|Air France|Singapore/i.test(name));
 }
 assert.equal(cabinSeatDisplayName({code:'eco_safran_z300',label:'Safran Z300'}),'Veloran E180');
 assert.equal(cabinSeatDisplayName({code:'eco_standard',label:'Standard economy'}),'Aervio E100');
});
test('factory and new model designs choose the least expensive available seat per class',()=>{
 assert.equal(cheapestCabinSeat(seatTypes,'economy','eco_standard'),'eco_standard');
 assert.deepEqual(standardCabinPlan(156,seatTypes),standardCabinPlan(156));
 const changed=[...seatTypes,{
  code:'eco_trial_cheap',cabinClass:'economy',installUsd:300,
  spaceUnits:'1.00',pitchInches:'30',widthInches:'17.5'}];
 const cheapest=standardCabinPlan(156,changed);
 assert.equal(cheapest.economyType,'eco_trial_cheap');
 assert.equal(cheapest.premiumType,'premium_standard');
 assert.equal(cheapest.businessType,'business_standard');
 assert.equal(cheapest.firstType,'first_standard');
 assert.equal(evaluateCabinPlan(cheapest,changed,156).equipmentUsd,46800);
 assert.equal(standardCabinPlan(156).economyType,'eco_standard',
  'existing saved plans and fallback IDs stay compatible');
});
test('selecting a higher priced seat increases estimated quality slightly and increases seat costs',()=>{
 const cat=[...seatTypes,{code:'eco_safran_z300',cabinClass:'economy',
  spaceUnits:'1.12',installUsd:1050,pitchInches:'32',widthInches:'18.0'}];
 const cheap=evaluateCabinPlan(standardCabinPlan(120,cat),cat,156);
 const premium=evaluateCabinPlan({...standardCabinPlan(120,cat),
  economyType:'eco_safran_z300'},cat,156);
 assert.equal(cheap.valid,true);
 assert.equal(premium.valid,true);
 assert.ok(premium.equipmentUsd>cheap.equipmentUsd,'new seats change the total estimate');
 assert.ok(premium.comfortRating>cheap.comfortRating,
  'better tier makes passenger score visibly higher');
 assert.ok(premium.comfortRating-cheap.comfortRating<=7,
  'price upgrade provides a limited effect, not a huge bonus');
 assert.equal(seatQualityBonus(cat[0],cat),0);
 assert.equal(seatQualityBonus(cat[cat.length-1],cat),6);
 assert.equal(premium.classes[0].style,'Veloran E180');
 assert.equal(premium.classes[0].unitPriceUsd,1050);
});
test('cabin model and factory rows show seat price per unit and no product source links',async()=>{
 const source=await readFile(new URL('../website/cabin-configuration-manager.mjs',import.meta.url),'utf8');
 const css=await readFile(new URL('../website/player-app.css',import.meta.url),'utf8');
 assert.doesNotMatch(source,/Seat product source|sourceLink/);
 assert.match(source,/Price \/ seat/);
 assert.match(css,/\.cabin-seat-price/);
 const el=tag=>({tag,children:[],handlers:{},attrs:{},textContent:'',className:'',
  append(...children){this.children.push(...children)},
  setAttribute(k,v){this.attrs[k]=v},
  addEventListener(k,fn){this.handlers[k]=fn}
 });
 const doc={createElement:el};
 const host=el('div');
 const plan=standardCabinPlan(120,seatTypes);
 let updated=0;
 const row=appendRow(doc,host,cabinClasses[0],seatTypes,plan,()=>updated++);
 assert.equal(host.children.length,1);
 assert.equal(host.children[0].children.length,5,'new price is last column');
 assert.equal(row.unitPrice.textContent,'$450');
 assert.equal(row.select.children[0].textContent,'Aervio E100');
 assert.ok(row.select.children.every(o=>!o.textContent.includes('Standard economy')&&
  !o.textContent.includes('Extra legroom economy')));
 assert.ok(row.select.children.every(o=>!o.textContent.includes('Safran')));
 assert.ok(row.select.children.every(o=>!o.textContent.includes('$')),
  'pricing is in its own clear per-seat column, not hidden in seat labels');
 row.select.value='eco_extra';
 row.select.handlers.change();
 assert.equal(row.unitPrice.textContent,'$700');
 assert.equal(plan.economyType,'eco_extra');
 assert.equal(updated,1);
});


test('read-only catalog, factory and used seat profiles keep source-specific layouts and rating',async()=>{
 const {normalizeCabinPreview}=await import('../website/aircraft-cabin-preview.mjs');
 const catalog=normalizeCabinPreview({useType:'passenger',
  cabin:{economy:274,premium:0,business:0,first:0},referenceUnits:274,seatTypes});
 assert.equal(catalog.evaluation.valid,true);
 assert.equal(catalog.evaluation.count,274);
 assert.equal(catalog.evaluation.comfortRating,49);
 assert.equal(catalog.plan.business,0);
 const previousOwner=normalizeCabinPreview({useType:'combi',
  cabin:{economy:100,premium:20,business:10,first:0,
   economyType:'eco_standard',premiumType:'premium_standard',
   businessType:'business_standard',firstType:'first_standard',extraLegroomCm:0},
  referenceUnits:156,seatTypes});
 assert.equal(previousOwner.evaluation.valid,true);
 assert.equal(previousOwner.evaluation.count,130);
 assert.equal(previousOwner.evaluation.used,147);
 assert.equal(previousOwner.plan.premium,20);
 assert.equal(previousOwner.plan.business,10);
 assert.equal(normalizeCabinPreview({useType:'cargo',cabin:catalog.plan,referenceUnits:274}),null);
 assert.equal(normalizeCabinPreview({useType:'passenger',cabin:null,referenceUnits:274}),null);
 assert.equal(normalizeCabinPreview({useType:'passenger',
  cabin:{economy:100,premium:0,business:0,first:0,economyType:'invented'},
  referenceUnits:156,seatTypes}),null);
});

test('non-owner cabin viewing never provides refit, acquisition or cabin-save actions',async()=>{
 const [view,library,market,overlay,styles,html]=await Promise.all([
  readFile(new URL('../website/aircraft-cabin-preview.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/aircraft-library.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/airline-workspace.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/player-app.css',import.meta.url),'utf8'),
  readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8')
 ]);
 assert.match(view,/renderCabinFloorplan/);
 assert.match(view,/updatePassengerRatingGauge/);
 assert.match(view,/not passenger happiness or actual feedback/);
 assert.doesNotMatch(view,/\.innerHTML|post\(|bidUsed\(|acquire\(|saveCabinDraft\(/);
 assert.match(html,/id="library-profile-cabin-button" hidden>View cabin configuration/);
 assert.match(library,/cabinNavButton.hidden=/);
 assert.match(market,/View aircraft details/);
 assert.match(market,/new-aircraft-view-cabin/);
 assert.match(market,/fleet-view-cabin/);
 assert.match(market,/record\.cabinSnapshot/);
 assert.match(market,/airframe\.installedEconomy/);
 assert.match(overlay,/'aircraft-cabin-preview\.mjs'/);
 assert.match(styles,/\.airlinerra-cabin-readonly-grid/);
});

test('used-aircraft cabin snapshot is attached to the airframe not the seller label',async()=>{
 const migration=await readFile(new URL('../supabase/migrations/20261113230000_airlinerra_used_aircraft_cabin_snapshots_v1.sql',import.meta.url),'utf8');
 const followup=await readFile(new URL('../supabase/migrations/20261113230100_airlinerra_allow_previous_owner_installed_cabin_origin.sql',import.meta.url),'utf8');
 assert.match(migration,/NEW\.source_inventory_id/);
 assert.match(migration,/NEW\.cabin_snapshot=jsonb_build_object/);
 assert.match(migration,/IF NEW\.awarded_inventory_id IS NULL/);
 assert.match(migration,/AFTER UPDATE OF awarded_inventory_id/);
 assert.match(migration,/installed_source=CASE WHEN NEW\.cabin_origin='previous_owner'/);
 assert.match(followup,/used_aircraft_previous_owner_layout/);
 assert.doesNotMatch(migration,/release_state\s*=\s*'live'|state\s*=\s*'active'/);
});


test('factory v2 A330 model mixes four full rows and fills nearly all game cabin space',async()=>{
 const {normalizeCabinPreview}=await import('../website/aircraft-cabin-preview.mjs');
 const cabin={economy:328,premium:18,business:12,first:8,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard',extraLegroomCm:1.2};
 const layout={economyColumns:[2,4,2],premiumColumns:[2,2,2],
  businessColumns:[1,2,1],firstColumns:[1,2,1]};
 const evaluated=normalizeCabinPreview({
  useType:'passenger',cabin,referenceUnits:406,seatTypes
 });
 assert.equal(evaluated.evaluation.valid,true);
 assert.equal(evaluated.evaluation.count,366);
 assert.equal(validateCabinModelRows(cabin,layout,406).valid,true);
 assert.ok(evaluated.evaluation.spacePct>=99.8);
 assert.ok(evaluated.evaluation.spacePct<=100);
 const plan=createCabinFloorplanModel(evaluated.evaluation,406,layout);
 assert.equal(plan.totalSeats,366);
 assert.deepEqual(plan.sections.map(s=>s.className),['first','business','premium','economy']);
 assert.deepEqual(plan.sections.map(s=>s.seats),[8,12,18,328]);
 assert.ok(plan.height>650,'A widebody should grow vertically, not shrink to a fixed icon');
});

test('factory default migration contains complete row audit and preserves owned/customized cabin',async()=>{
 const migration=await readFile(new URL(
  '../supabase/migrations/20261113233000_airlinerra_factory_cabin_row_complete_defaults_v2.sql',import.meta.url),'utf8');
 const manager=await readFile(new URL('../website/cabin-configuration-manager.mjs',import.meta.url),'utf8');
 const service=await readFile(new URL('../server/fleet-acquisition-service.mjs',import.meta.url),'utf8');
 const library=await readFile(new URL('../server/aircraft-library-query.mjs',import.meta.url),'utf8');
 const css=await readFile(new URL('../website/player-app.css',import.meta.url),'utf8');
 assert.match(migration,/cabin_model_factory_layout_v2/);
 assert.match(migration,/factory_cabin_row_or_space_invalid/i);
 assert.match(migration,/installed_premium,installed_business,installed_first/);
 assert.match(migration,/source_inventory_id IS NULL AND lot\.cabin_origin='model_default'/);
 assert.match(migration,/initial_installed_cabin_v1/);
 assert.match(manager,/validateCabinModelRows\(factoryPlan,geometry,f\.referenceSeats\)/);
 assert.match(manager,/sameFactoryPlan\(f,factoryPlan\)/);
 assert.match(manager,/factoryPlan=factoryReferencePlan\(factory\)/);
 assert.match(service,/factoryExtraLegroomCm/);
 assert.match(library,/cabin_factory_economy/);
 assert.match(css,/max-height:none;min-height:0/);
});
