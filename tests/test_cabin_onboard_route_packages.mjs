import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {CABIN_MODE_OPTIONS,CABIN_SERVICE_CATALOG,createBasicCabinPackage,cleanCabinState,
 cleanCabinPackage,cabinPackageEstimate} from '../website/cabin-services-manager.mjs';
import {validateFlightDraftOptions,routePlannerMarkup} from '../website/route-planner.mjs';
import {validateFlightSchedulePayload,SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const UUID='11111111-1111-4111-8111-111111111111';
const basic=createBasicCabinPackage();
test('onboard only: no online selector, passenger price is separate from airline unit cost',async()=>{
 const ui=await read('website/cabin-services-manager.mjs');
 assert.deepEqual(CABIN_MODE_OPTIONS.map(x=>x[0]),['off','included','onboard','hybrid']);
 assert.ok(!ui.includes('Paid online before flight'));
 assert.ok(!ui.includes("data-cabin-field='onlineCents'"));
 assert.ok(ui.includes("onboard.dataset.cabinField='onboardCents'"));
 assert.ok(ui.includes('Estimated airline cost / passenger'));
 assert.ok(ui.includes('cabin-package-remove'));
 assert.equal(basic.items.water.mode,'included');
 assert.equal(cabinPackageEstimate(basic).totalCostCents,15);
 const old={...basic,id:'pkg-1',locked:false,name:'Simple Drink',items:structuredClone(basic.items)};
 old.items.coffee={mode:'online',onlineCents:300,onboardCents:200,freeQty:0};
 const normalized=cleanCabinPackage(old);
 assert.equal(normalized.items.coffee.mode,'onboard');
 assert.equal(normalized.items.coffee.onboardCents,200);
 assert.equal(normalized.items.coffee.onlineCents,200);
 assert.equal(cleanCabinState({version:1,packages:[old],assignments:{economy:'pkg-1'}}).packages.length,2);
});
test('all rows sum to explicit airline cost, sales and net cost per assumed passenger',()=>{
 const pkg=structuredClone(basic);
 pkg.items.coffee={mode:'included',freeQty:1,onboardCents:200,onlineCents:200};
 pkg.items.softdrink={mode:'onboard',freeQty:0,onboardCents:300,onlineCents:300};
 const x=cabinPackageEstimate(pkg);
 const water=x.rows.find(r=>r.id==='water');
 const coffee=x.rows.find(r=>r.id==='coffee');
 const drink=x.rows.find(r=>r.id==='softdrink');
 assert.equal(water.costCents,15);
 assert.equal(coffee.costCents,19);
 assert.equal(drink.costCents,12);
 assert.equal(drink.paidRevenueCents,60);
 assert.equal(x.totalCostCents,46);
 assert.equal(x.paidRevenueCents,60);
 assert.equal(x.netCostCents,-14);
 assert.equal(x.totalCostCents,x.rows.reduce((n,r)=>n+r.costCents,0));
});
test('new route planning lists owner packages, no service and projected cost only',async()=>{
 const ui=routePlannerMarkup(),source=await read('website/route-planner.mjs');
 for(const name of ['route-cabin-package','route-cabin-service-note','route-cabin-passengers'])
  assert.ok(ui.includes(name),name);
 assert.ok(!ui.includes('route-onboard-service'));
 assert.ok(ui.includes('No onboard service'));
 assert.ok(source.includes('cabinPackageId'));
 assert.ok(source.includes('getCabinState'));
 assert.ok(source.includes('airlinerra:cabin-packages-updated'));
 const option={departureStand:'terminal',arrivalStand:'terminal',turnaroundMinutes:60,
  fares:{economy:100,premium:null,business:null,first:null},
  onboard:'basic',baggage:'standard',cargo:'none',cabinPackageId:'pkg-2'};
 assert.equal(validateFlightDraftOptions(option)?.service.cabinPackageId,'pkg-2');
 assert.equal(validateFlightDraftOptions({...option,cabinPackageId:'none'})?.service.cabinPackageId,'none');
 assert.equal(validateFlightDraftOptions({...option,cabinPackageId:'foreign'}) ,null);
});
test('server rejects unknown packages or foreign airline package IDs, atomically in route insert',()=>{
 const base={action:'plan-save',airlineId:UUID,aircraftInventoryId:UUID,
  flightNumber:'PA101',originAirportKey:'OURAIRPORTS:1',destinationAirportKey:'OURAIRPORTS:2',
  weeklySchedule:[{day:0,time:'09:00'}],departureStand:'terminal',
  arrivalStand:'terminal',turnaroundMinutes:60,referenceDepartureUtc:null,referenceArrivalUtc:null,
  fares:{economy:100,premium:null,business:null,first:null},
  service:{onboard:'basic',baggage:'standard',cargo:'none',cabinPackageId:'pkg-2'}};
 assert.equal(validateFlightSchedulePayload(base),true);
 assert.equal(validateFlightSchedulePayload({...base,service:{...base.service,cabinPackageId:'other-airline-secret'}}),false);
 assert.equal(validateFlightSchedulePayload({...base,service:{...base.service,cabinPackageId:'none'}}),true);
 assert.match(SCHEDULE_SQL.planSave,/jsonb_array_elements\(c.state->'packages'\)/);
 assert.match(SCHEDULE_SQL.planSave,/WHERE c.airline_id=a.id/);
 assert.match(SCHEDULE_SQL.planSave,/AND package->>'id'/);
 assert.doesNotMatch(SCHEDULE_SQL.planSave,/airline_ledger|charge|cash_usd|passenger_bookings/i);
});
test('custom packages can be deleted from sidebar while protected Basic remains',async()=>{
 const source=await read('website/cabin-services-manager.mjs');
 assert.match(source,/if\(pkg.id!=='basic'\)/);
 assert.match(source,/remove.dataset.cabinAction='delete'/);
 assert.match(source,/deleteId==='basic'/);
 assert.match(source,/state.packages=state.packages.filter\(p=>p.id!==deleteId\)/);
 assert.match(source,/state.assignments\[key\]='basic'/);
 const css=await read('website/player-app.css');
 assert.match(css,/\.cabin-package-remove/);
 assert.match(css,/\.route-cabin-cost-preview/);
});
