import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {CABIN_MODE_OPTIONS,CABIN_SERVICE_CATALOG,createBasicCabinPackage,cleanCabinState,
 cleanCabinPackage,cabinPackageEstimate,forecastCabinServiceFlight} from '../website/cabin-services-manager.mjs';
import {validateFlightDraftOptions,routePlannerMarkup} from '../website/route-planner.mjs';
import {validateFlightSchedulePayload,SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const UUID='11111111-1111-4111-8111-111111111111';
const basic=createBasicCabinPackage();
const custom=()=>({...structuredClone(basic),id:'pkg-1',locked:false,name:'Catering Test'});
const money=r=>r.airlineCostCents;
test('only three options; old online and hybrid are migrated without promising hidden free items',async()=>{
 const ui=await read('website/cabin-services-manager.mjs');
 assert.deepEqual(CABIN_MODE_OPTIONS.map(x=>x[0]),['off','included','onboard']);
 assert.ok(!ui.includes('Free allowance + paid onboard extras'));
 assert.ok(!ui.includes('Paid online before flight'));
 assert.ok(ui.includes("onboard.dataset.cabinField='onboardCents'"));
 // Package setup controls only product policy; real passenger counts and sales
 // are evaluated later with the verified flight, not here.
 assert.ok(ui.includes('Passenger price (USD)'));
 assert.ok(ui.includes('Airline unit cost (USD)'));
 assert.ok(ui.includes('cabinPackageUnitEconomics(working)'));
 assert.ok(ui.includes("const ratingValue=cabinServiceAttractiveness(working)"));
 assert.ok(!ui.includes('cabin-preview-passengers'));
 assert.ok(!ui.includes('cabin-preview-hours'));
 assert.ok(!ui.includes('Units loaded / 100 passengers'));
 assert.ok(!ui.includes('cabin-item-inventory'));
 assert.ok(!ui.includes('cabin-item-unit-cost'));
 assert.ok(!ui.includes("id='cabin-cost'"));
 assert.ok(!ui.includes("id='cabin-sales'"));
 assert.equal(basic.items.water.mode,'included');
 const old=custom();
 old.items.coffee={mode:'online',onlineCents:600,onboardCents:400,freeQty:0};
 old.items.snack={mode:'hybrid',onlineCents:500,onboardCents:700,freeQty:2};
 const normalized=cleanCabinPackage(old);
 assert.equal(normalized.items.coffee.mode,'onboard');
 assert.equal(normalized.items.coffee.onboardCents,400);
 assert.equal(normalized.items.coffee.onlineCents,400);
 assert.equal(normalized.items.snack.mode,'included');
 assert.equal(normalized.items.snack.freeQty,1);
 assert.equal(normalized.items.snack.stockPer100,100);
 assert.equal(cleanCabinState({version:1,packages:[old],assignments:{economy:'pkg-1'}}).packages.length,2);
});
test('one clear unit cost: free hot meals are budgeted in full, not diluted by 55% take-up',()=>{
 const pkg=custom();pkg.items.hotmeal.mode='included';
 const hot=CABIN_SERVICE_CATALOG.find(x=>x.id==='hotmeal');
 assert.equal(hot.costCents,950);
 const forecast=forecastCabinServiceFlight(pkg,{passengers:100,durationMinutes:300,reputationScore:50});
 const meal=forecast.rows.find(x=>x.id==='hotmeal');
 assert.equal(meal.loadedUnits,100);
 assert.equal(meal.expectedSales,0);
 assert.equal(money(meal),95000);
 assert.equal(meal.passengerPriceCents,0);
 assert.equal(forecast.totalCostCents>=95000,true);
});
test('paid hot meals: physical stocked items cost money even when nobody buys',()=>{
 const pkg=custom();
 pkg.items.hotmeal={mode:'onboard',freeQty:0,stockPer100:10,
  onlineCents:2000,onboardCents:2000};
 const hour=forecastCabinServiceFlight(pkg,{passengers:100,durationMinutes:60,reputationScore:50});
 const fiveHours=forecastCabinServiceFlight(pkg,{passengers:100,durationMinutes:300,reputationScore:50});
 const a=hour.rows.find(x=>x.id==='hotmeal'),b=fiveHours.rows.find(x=>x.id==='hotmeal');
 assert.equal(a.loadedUnits,10);
 assert.equal(a.airlineCostCents,9500);
 assert.equal(a.expectedSales,0);
 assert.equal(a.onboardRevenueCents,0);
 assert.ok(b.expectedSales>0);
 assert.ok(b.expectedSales<=b.loadedUnits);
 assert.equal(b.airlineCostCents,9500);
 assert.equal(b.onboardRevenueCents,b.expectedSales*2000);
 assert.equal(hour.attractiveness,25); // no bonus for no demand
 assert.ok(fiveHours.attractiveness<=27);
 assert.equal(fiveHours.forecastOnly,true);
 assert.equal(fiveHours.ledgerPosted,false);
});
test('reputation, route duration, onboard price and loaded stock all affect forecast',()=>{
 const pkg=custom();
 pkg.items.snack={mode:'onboard',freeQty:0,stockPer100:40,
  onlineCents:550,onboardCents:550};
 const f=(reputationScore,durationMinutes,price,stock)=> {
  pkg.items.snack.onboardCents=price;pkg.items.snack.stockPer100=stock;
  return forecastCabinServiceFlight(pkg,{passengers:100,durationMinutes,reputationScore})
   .rows.find(x=>x.id==='snack');
 };
 const low=f(10,60,550,40),high=f(90,300,550,40);
 assert.ok(low.expectedSales<high.expectedSales);
 const cheap=f(50,300,550,40),expensive=f(50,300,2000,40);
 assert.ok(expensive.expectedSales<cheap.expectedSales);
 const understocked=f(50,300,550,2);
 assert.ok(understocked.expectedSales<=2);
 assert.equal(understocked.airlineCostCents,450); // pay for 2 loaded snacks
});
test('paid availability yields at most two rating points, free products cost more but score higher',()=>{
 const paid=custom(),free=custom();
 for(const item of CABIN_SERVICE_CATALOG){
  paid.items[item.id]={mode:'onboard',freeQty:0,stockPer100:item.digital?0:100,
    onboardCents:item.referencePrice,onlineCents:item.referencePrice};
  free.items[item.id]={mode:'included',freeQty:1,stockPer100:100,
    onboardCents:item.referencePrice,onlineCents:item.referencePrice};
 }
 const option=forecastCabinServiceFlight(paid,{passengers:100,durationMinutes:300,reputationScore:50});
 const allFree=forecastCabinServiceFlight(free,{passengers:100,durationMinutes:300,reputationScore:50});
 assert.ok(option.attractiveness<=27);
 assert.ok(option.paidBonus<=2);
 assert.ok(allFree.attractiveness>option.attractiveness);
 assert.ok(allFree.totalCostCents>option.totalCostCents);
 const empty=custom();empty.items.hotmeal={mode:'onboard',stockPer100:0,onboardCents:2000};
 assert.equal(forecastCabinServiceFlight(empty).paidBonus,0);
});
test('digital services incur use cost without fictitious physical stocking',()=>{
 const pkg=custom();
 pkg.items.wifi={mode:'onboard',stockPer100:0,onboardCents:800,onlineCents:800};
 const out=forecastCabinServiceFlight(pkg,{passengers:100,durationMinutes:300,reputationScore:50});
 const wifi=out.rows.find(x=>x.id==='wifi');
 assert.equal(wifi.loadedUnits,0);
 assert.ok(wifi.expectedSales>0);
 assert.equal(wifi.airlineCostCents,wifi.expectedSales*225);
});
test('route plan stores selected package and has separate projected duration, not real settlement',async()=>{
 const ui=routePlannerMarkup(),source=await read('website/route-planner.mjs');
 assert.ok(ui.includes('route-cabin-package'));
 for(const removed of ['route-cabin-service-note','route-cabin-passengers','route-cabin-hours','Estimated passengers (preview only)'])
  assert.ok(!ui.includes(removed),removed);
 assert.ok(!ui.includes('route-onboard-service'));
 assert.ok(ui.includes('No onboard service'));
 assert.ok(source.includes('cabinPackageId'));
 assert.ok(source.includes('getCabinState'));
 assert.ok(source.includes('airlinerra:cabin-packages-updated'));
 assert.ok(!source.includes('forecastCabinServiceFlight'));
 assert.ok(source.includes('cabinPackageId'));
 assert.ok(source.includes('const payload=.5;'));
 const options={departureStand:'terminal',arrivalStand:'terminal',turnaroundMinutes:60,
  fares:{economy:100,premium:null,business:null,first:null},
  onboard:'basic',baggage:'standard',cargo:'none',cabinPackageId:'pkg-2'};
 assert.equal(validateFlightDraftOptions(options)?.service.cabinPackageId,'pkg-2');
 assert.equal(validateFlightDraftOptions({...options,cabinPackageId:'none'})?.service.cabinPackageId,'none');
 assert.equal(validateFlightDraftOptions({...options,cabinPackageId:'not-owned'}),null);
});
test('protected route insert enforces owner-specific package and cannot charge money',()=>{
 const body={action:'plan-save',airlineId:UUID,aircraftInventoryId:UUID,
  flightNumber:'PA101',originAirportKey:'OURAIRPORTS:1',destinationAirportKey:'OURAIRPORTS:2',
  weeklySchedule:[{day:0,time:'09:00'}],departureStand:'terminal',
  arrivalStand:'terminal',turnaroundMinutes:60,referenceDepartureUtc:null,referenceArrivalUtc:null,
  fares:{economy:100,premium:null,business:null,first:null},
  service:{onboard:'basic',baggage:'standard',cargo:'none',cabinPackageId:'pkg-2'}};
 assert.equal(validateFlightSchedulePayload(body),true);
 assert.equal(validateFlightSchedulePayload({...body,service:{...body.service,cabinPackageId:'other-airline-secret'}}),false);
 assert.match(SCHEDULE_SQL.planSave,/jsonb_array_elements\(c.state->'packages'\)/);
 assert.match(SCHEDULE_SQL.planSave,/WHERE c.airline_id=a.id/);
 assert.doesNotMatch(SCHEDULE_SQL.planSave,/airline_ledger|charge|cash_usd|passenger_bookings/i);
});
test('custom packages can be deleted but protected Basic cannot',async()=>{
 const ui=await read('website/cabin-services-manager.mjs');
 assert.match(ui,/if\(pkg.id!=='basic'\)/);
 assert.match(ui,/remove.dataset.cabinAction='delete'/);
 assert.match(ui,/deleteId==='basic'/);
 assert.match(ui,/state.packages=state.packages.filter\(p=>p.id!==deleteId\)/);
 const css=await read('website/player-app.css');
 assert.match(css,/\.cabin-package-remove/);
 assert.doesNotMatch(css,/\.route-cabin-cost-preview/);
 assert.match(css,/\.cabin-package-saved-toast/);
});
