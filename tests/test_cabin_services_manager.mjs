import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 CABIN_SERVICE_CATALOG,CABIN_MODE_OPTIONS,CABIN_CLASSES,
 createBasicCabinPackage,initialCabinState,cleanCabinState,
 cleanCabinPackage,cabinPackageEstimate
} from '../website/cabin-services-manager.mjs';

test('each airline automatically has a protected Basic package and all four classes',()=>{
 const state=initialCabinState(),basic=state.packages[0];
 assert.deepEqual(state.assignments,{
  economy:'basic',premium:'basic',business:'basic',first:'basic'
 });
 assert.equal(basic.locked,true);
 assert.equal(basic.id,'basic');
 assert.equal(basic.items.water.mode,'included');
 assert.equal(basic.items.water.freeQty,1);
 assert.equal(basic.items.hotmeal.mode,'off');
 assert.equal(basic.items.wifi.mode,'off');
 assert.ok(CABIN_SERVICE_CATALOG.length>=12);
 const estimate=cabinPackageEstimate(basic);
 assert.equal(estimate.attractiveness,25);
 assert.equal(estimate.relativeToBasic,0);
 assert.equal(estimate.includedCents,65);
 assert.equal(estimate.indicativeMarginCents,0);
});
test('complimentary and paid product levels affect preview rating and cost differently',()=>{
 const basic=createBasicCabinPackage();
 const pkg={...basic,id:'pkg-1',name:'Comfort Service',locked:false,
  items:structuredClone(basic.items)};
 pkg.items.coffee={mode:'included',freeQty:1,onlineCents:200,onboardCents:300};
 pkg.items.snack={mode:'included',freeQty:1,stockPer100:100,onlineCents:500,onboardCents:500};
 pkg.items.wifi={mode:'onboard',freeQty:0,stockPer100:0,onlineCents:800,onboardCents:800};
 const result=cabinPackageEstimate(pkg);
 assert.ok(result.attractiveness>25);
 assert.ok(result.includedCents>15);
 assert.ok(result.indicativeMarginCents>0);
 const paid=structuredClone(pkg);
 paid.items.coffee.mode='onboard';
 assert.ok(cabinPackageEstimate(paid).attractiveness<result.attractiveness);
 assert.ok(cabinPackageEstimate(paid).includedCents<result.includedCents);
});
test('all offered services have valid mode and prices; arbitrary names and amounts are rejected',()=>{
 const valid=createBasicCabinPackage();
 const custom={...valid,id:'pkg-7',locked:false,name:'Premium Cabin',items:structuredClone(valid.items)};
 custom.items.hotmeal={mode:'online',freeQty:0,onlineCents:1200,onboardCents:1500};
 custom.items.alcohol={mode:'onboard',freeQty:0,onlineCents:600,onboardCents:800};
 const result=cleanCabinPackage(custom);
 assert.equal(result.items.hotmeal.onlineCents,1500); // v1 compatibility mirrors onboard
 assert.equal(result.items.alcohol.mode,'onboard');
 assert.equal(result.items.hotmeal.mode,'onboard'); // legacy online offer converted
 assert.equal(cleanCabinPackage({...custom,name:'<script>'}),null);
 assert.equal(cleanCabinPackage({...custom,id:'bad-id'}),null);
 assert.equal(cleanCabinPackage({...custom,name:'a'}),null);
 assert.equal(CABIN_MODE_OPTIONS.length,3);
 assert.equal(CABIN_CLASSES.length,4);
});
test('saved state restores only valid packages and does not accept forged default package',()=>{
 const basic=createBasicCabinPackage();
 const comfort={...basic,id:'pkg-2',name:'Business Comfort',locked:false};
 const forged={...basic,name:'Free full meals',items:{
  ...basic.items,hotmeal:{mode:'included',freeQty:3,onlineCents:0,onboardCents:0}
 }};
 const input={version:1,packages:[forged,comfort,comfort,{id:'delete-db',name:'Bad'}],
  assignments:{economy:'basic',premium:'pkg-2',business:'pkg-2',first:'missing'}};
 const saved=cleanCabinState(input);
 assert.deepEqual(saved.packages.map(x=>x.id),['basic','pkg-2']);
 assert.equal(saved.packages[0].name,'Basic Flight Services');
 assert.equal(saved.packages[0].items.hotmeal.mode,'off');
 assert.deepEqual(saved.assignments,{
  economy:'basic',premium:'pkg-2',business:'pkg-2',first:'basic'
 });
 assert.deepEqual(cleanCabinState({version:999,packages:[]}),initialCabinState());
});
test('flight services UI is wired into real Operations page and protected website build',async()=>{
 const read=name=>readFile(new URL('../website/'+name,import.meta.url),'utf8');
 const [workspace,html,bundle,css,manager]=await Promise.all([
  read('airline-workspace.mjs'),read('private-player-app.html'),
  read('dev-scripts/invited-overlay.mjs'),read('player-app.css'),
  read('cabin-services-manager.mjs')
 ]);
 assert.match(html,/<h1>Flight services<\/h1>/);
 assert.match(html,/data-view-link="service">Flight services/);
 assert.match(workspace,/id="cabin-services-manager"/);
 assert.match(workspace,/createCabinServiceManager/);
 assert.match(workspace,/cabinManager\?\.updateData\(data\)/);
 assert.match(workspace,/cabin-configuration-manager/);
 assert.match(workspace,/cabinConfigurationManager/);
 assert.match(bundle,/'cabin-services-manager\.mjs'/);
 assert.match(css,/\.cabin-product-layout/);
 assert.match(css,/\.cabin-product-policy-summary/);
 assert.match(css,/\.cabin-assignment-grid/);
 assert.match(manager,/getPackages:/);
 assert.match(manager,/getAssignments:/);
 assert.match(manager,/airlinerra\.cabin\.services\.v1\./);
 assert.match(manager,/No flight was modified/);
 assert.doesNotMatch(manager,/\.auth\.signUp|service_role|sb_secret_|fetch\(|airline_cash|INSERT INTO/i);
});

test('Flight Services follows My routes page layout with one shared white panel and readable mobile fields',async()=>{
 const readWeb=name=>readFile(new URL('../website/'+name,import.meta.url),'utf8');
 const [workspace,operations,manager,css]=await Promise.all([
  readWeb('airline-workspace.mjs'),readWeb('airline-operations-center.mjs'),
  readWeb('cabin-services-manager.mjs'),readWeb('player-app.css')
 ]);
 assert.match(workspace,/const card=\(title,content,kicker='WORKSPACE'\)=>'<article class="panel workspace-panel">/);
 assert.match(operations,/const card=\(title,body,kicker='OPERATIONS PLANNING'\)=>'<article class="panel workspace-panel">/);
 assert.match(workspace,/'service':\(\)=>card\('Flight services'/);
 assert.match(operations,/card\('My routes'/);
 assert.match(workspace,/'FLIGHT SERVICES'/);
 assert.doesNotMatch(manager,/element\(doc,'h2','', 'Cabin Services Management'\)/);
 assert.match(manager,/className='cabin-product-cell'|element\(doc,'label','cabin-product-cell'\)/);
 assert.match(manager,/cabin-mobile-label/);
 assert.match(css,/\.cabin-product-sidebar,\.cabin-product-editor,\.cabin-assignment-panel\{/);
 assert.match(css,/\.cabin-product-table-head\{\s*background:#f1f6fc/);
 assert.match(css,/\.cabin-mobile-label\{display:none\}/);
 assert.match(css,/\.cabin-mobile-label\{display:block/);
 assert.match(css,/:root\[data-ui-theme="dark"\] \.cabin-product-item-name strong/);
});
