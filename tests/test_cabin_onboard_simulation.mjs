import test from 'node:test';
import assert from 'node:assert/strict';
import {createBasicCabinPackage,forecastCabinServiceFlight}
 from '../website/cabin-services-manager.mjs';
import {simulateCabinOnboardPurchases} from '../server/cabin-onboard-demand-engine.mjs';
const setup=()=>{
 const pkg=structuredClone(createBasicCabinPackage());
 pkg.id='pkg-1';pkg.locked=false;pkg.name='Consumption Sales';
 pkg.items.hotmeal={mode:'onboard',freeQty:0,stockPer100:10,onlineCents:1900,onboardCents:1900};
 pkg.items.wifi={mode:'onboard',freeQty:0,stockPer100:0,onlineCents:800,onboardCents:800};
 return pkg;
};
test('one event key always produces the same quantities, costs and money-free output',()=>{
 const ctx={flightEventKey:'PA101:2026-11-10:departure-1',passengers:200,
  durationMinutes:300,reputationScore:50};
 const a=simulateCabinOnboardPurchases(setup(),ctx);
 const b=simulateCabinOnboardPurchases(setup(),ctx);
 assert.deepEqual(a,b);
 assert.equal(a.simulated,true);
 assert.equal(a.transactionPosted,false);
 assert.equal(a.inventoryWritten,false);
 assert.equal(a.passengerBookingsCreated,false);
 assert.equal(a.netCostCents,a.totalCostCents-a.onboardRevenueCents);
});
test('paid meals cost the airline only for units consumed',()=>{
 const result=simulateCabinOnboardPurchases(setup(),{
  flightEventKey:'PA101:2026-11-10:departure-1',passengers:200,
  durationMinutes:300,reputationScore:50
 });
 const meal=result.rows.find(r=>r.id==='hotmeal');
 assert.equal(meal.airlineCostCents,meal.actualSales*950);
 assert.ok(meal.actualSales<=200);
 assert.equal(meal.onboardRevenueCents,meal.actualSales*1900);
 assert.equal(meal.consumedUnits,meal.actualSales);
 assert.equal('loadedUnits' in meal,false);
 assert.equal('unsoldUnits' in meal,false);
});
test('disabled items incur no cost or purchase, regardless of legacy stock',()=>{
 const pkg=setup();pkg.items.hotmeal.mode='off';
 pkg.items.wifi.mode='off';
 const out=simulateCabinOnboardPurchases(pkg,{
  flightEventKey:'PA101:2026-11-10:departure-2',passengers:200,
  durationMinutes:300,reputationScore:50
 });
 const meal=out.rows.find(r=>r.id==='hotmeal');
 assert.equal(meal.actualSales,0);
 assert.equal(meal.airlineCostCents,0);
 assert.equal(out.paidBonus,0);
});
test('digital services use the same consumption-based cost calculation',()=>{
 const out=simulateCabinOnboardPurchases(setup(),{
  flightEventKey:'PA101:2026-11-10:departure-3',passengers:400,
  durationMinutes:300,reputationScore:75
 });
 const wifi=out.rows.find(r=>r.id==='wifi');
 assert.equal(wifi.consumedUnits,wifi.actualSales);
 assert.ok(wifi.actualSales>0);
 assert.equal(wifi.airlineCostCents,wifi.actualSales*225);
 assert.equal(wifi.onboardRevenueCents,wifi.actualSales*800);
});
test('longer duration increases meal purchase chances, while planning and sim remain separate',()=>{
 const pkg=setup();
 const short=forecastCabinServiceFlight(pkg,{passengers:300,durationMinutes:60,reputationScore:50});
 const long=forecastCabinServiceFlight(pkg,{passengers:300,durationMinutes:300,reputationScore:50});
 assert.ok(short.rows.find(r=>r.id==='hotmeal').purchaseRate<
  long.rows.find(r=>r.id==='hotmeal').purchaseRate);
 assert.throws(()=>simulateCabinOnboardPurchases(pkg,{flightEventKey:'x',
  passengers:100,durationMinutes:300,reputationScore:50}),/flight event key/);
});

test('complimentary items have independent stable 60 to 80 percent uptake',()=>{
 const pkg=setup();pkg.items.alcohol.mode='included';
 for(let i=0;i<100;i++){
  const ctx={flightEventKey:'FREE-TEST:'+i,passengers:100,durationMinutes:180,reputationScore:70};
  const out=simulateCabinOnboardPurchases(pkg,ctx);
  for(const row of out.rows.filter(r=>r.mode==='included')){
   assert.ok(row.includedUnits>=60&&row.includedUnits<=80);
   assert.equal(row.airlineCostCents,row.includedUnits*row.unitCostCents);
   assert.equal(row.onboardRevenueCents,0);
  }
 }
});
