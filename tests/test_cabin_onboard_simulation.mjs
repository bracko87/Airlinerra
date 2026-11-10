import test from 'node:test';
import assert from 'node:assert/strict';
import {createBasicCabinPackage,forecastCabinServiceFlight}
 from '../website/cabin-services-manager.mjs';
import {simulateCabinOnboardPurchases} from '../server/cabin-onboard-demand-engine.mjs';
const setup=()=>{
 const pkg=structuredClone(createBasicCabinPackage());
 pkg.id='pkg-1';pkg.locked=false;pkg.name='Stocked Sales';
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
test('hot meals cost the airline for every loaded unit, never more sales than stocked',()=>{
 const result=simulateCabinOnboardPurchases(setup(),{
  flightEventKey:'PA101:2026-11-10:departure-1',passengers:200,
  durationMinutes:300,reputationScore:50
 });
 const meal=result.rows.find(r=>r.id==='hotmeal');
 assert.equal(meal.loadedUnits,20);
 assert.equal(meal.airlineCostCents,20*950);
 assert.ok(meal.actualSales<=20);
 assert.equal(meal.onboardRevenueCents,meal.actualSales*1900);
 assert.equal(meal.unsoldUnits,20-meal.actualSales);
});
test('no physical stock means no purchase and no paid-service score boost',()=>{
 const pkg=setup();pkg.items.hotmeal.stockPer100=0;
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
test('digital services can be bought with no physically loaded units; usage is charged',()=>{
 const out=simulateCabinOnboardPurchases(setup(),{
  flightEventKey:'PA101:2026-11-10:departure-3',passengers:400,
  durationMinutes:300,reputationScore:75
 });
 const wifi=out.rows.find(r=>r.id==='wifi');
 assert.equal(wifi.loadedUnits,0);
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
