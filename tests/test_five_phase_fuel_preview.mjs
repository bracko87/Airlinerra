import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {estimateFivePhaseFuel,PHASE_SETTINGS,
 DEFAULT_FUEL_GAME_PRICE_USD_PER_KG,FUEL_PHASE_MODEL_VERSION}
 from '../website/flight-fuel-phase-engine.mjs';
import {FLEET_SQL} from '../server/fleet-acquisition-service.mjs';
import {previewAirportFuelPrice,BENCHMARK_SPOT,AIRPORT_TIER_FACTORS} from '../website/airport-fuel-price-preview.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const A319={cruiseSpeedKmh:840,emptyFuelKgPer100Km:266.6,
 halfFuelKgPer100Km:288.3,fullFuelKgPer100Km:310,
 fuelTankCapacityKg:24152,payloadFraction:1};
const phases=['taxiOut','climb','cruise','descent','taxiIn'];
test('all flights have 5 distinct phases, with taxi out 15 and taxi in 10 minutes',()=>{
 const result=estimateFivePhaseFuel({...A319,distanceKm:1000});
 assert.deepEqual(result.phases.map(x=>x.key),phases);
 assert.equal(result.phases[0].minutes,15);
 assert.equal(result.phases.at(-1).minutes,10);
 assert.equal(PHASE_SETTINGS.climb.minutes,20);
 assert.equal(PHASE_SETTINGS.descent.minutes,20);
 assert.equal(result.modelVersion,FUEL_PHASE_MODEL_VERSION);
 assert.equal(result.previewOnly,true);
 assert.equal(result.dispatchApproved,false);
 assert.equal(result.ledgerPosted,false);
});
test('whole-mission legacy fuel estimate is redistributed, NOT counted twice',()=>{
 const reference=estimateFivePhaseFuel({...A319,distanceKm:1000});
 assert.equal(reference.source,'CALIBRATED_PROVISIONAL_MISSION_DISTANCE_RATE');
 assert.ok(Math.abs(reference.tripFuelKg-3100)<.01);
 assert.equal(reference.estimatedBurnCostUsd,2945);
 assert.equal(reference.fuelPriceUsdPerKg,DEFAULT_FUEL_GAME_PRICE_USD_PER_KG);
 assert.ok(Math.abs(reference.phases.reduce((sum,p)=>sum+p.distanceKm,0)-1000)<.1);
 assert.ok(Math.abs(reference.phases.reduce((sum,p)=>sum+p.fuelKg,0)-3100)<.06);
});
test('short routes compress climb and descent; cruise never becomes negative',()=>{
 const short=estimateFivePhaseFuel({...A319,distanceKm:100});
 const long=estimateFivePhaseFuel({...A319,distanceKm:2200});
 assert.equal(short.phases[2].minutes,0);
 assert.ok(short.phases[1].minutes<20);
 assert.ok(short.phases[3].minutes<20);
 assert.ok(short.totalMinutes>25&&short.totalMinutes<long.totalMinutes);
 assert.ok(long.phases[2].minutes>0);
 assert.ok(long.phases.every(p=>p.fuelKg>=0&&p.minutes>=0));
});
test('lighter aircraft consume less fuel at the same distance',()=>{
 const empty=estimateFivePhaseFuel({...A319,distanceKm:1000,payloadFraction:0});
 const half=estimateFivePhaseFuel({...A319,distanceKm:1000,payloadFraction:.5});
 const full=estimateFivePhaseFuel({...A319,distanceKm:1000,payloadFraction:1});
 assert.ok(empty.tripFuelKg<half.tripFuelKg&&half.tripFuelKg<full.tripFuelKg);
 assert.ok(Math.abs(empty.tripFuelKg-2666)<.01);
 assert.ok(Math.abs(half.tripFuelKg-2883)<.01);
});
test('hourly aircraft without distance rate still use explicit phase model',()=>{
 const hourly=estimateFivePhaseFuel({
  distanceKm:700,cruiseSpeedKmh:500,cruiseFuelKgPerHour:650,payloadFraction:.5,
  fuelTankCapacityKg:4000
 });
 assert.equal(hourly.source,'CATALOG_HOURLY_REFERENCE_WITH_LOAD_ESTIMATE');
 assert.ok(hourly.estimatedCruiseKgPerHour>0);
 assert.ok(hourly.tripFuelKg>0);
});
test('missing or zero burn never receives invented fuel costs',()=>{
 for(const data of [{...A319,distanceKm:1000,emptyFuelKgPer100Km:null,
  halfFuelKgPer100Km:null,fullFuelKgPer100Km:null},
  {...A319,distanceKm:0},{...A319,distanceKm:-10},
  {...A319,distanceKm:1000,cruiseSpeedKmh:null},
  {...A319,distanceKm:1000,payloadFraction:1.5}]){
  const output=estimateFivePhaseFuel(data);
  assert.equal(output.status,'UNAVAILABLE');
  assert.equal(output.dispatchApproved,false);
  assert.equal(output.ledgerPosted,false);
  assert.equal(output.estimatedBurnCostUsd,undefined);
 }
});
test('screening reserve is separate from burned fuel and never charged automatically',()=>{
 const result=estimateFivePhaseFuel({...A319,distanceKm:1000});
 assert.ok(result.screeningFuelLoadKg>result.tripFuelKg);
 assert.ok(result.screeningReserveFuelKg>0);
 assert.equal(result.referenceTankScreen,'WITHIN_REFERENCE_TANK');
 assert.equal(estimateFivePhaseFuel({...A319,fuelTankCapacityKg:200,distanceKm:1000})
  .referenceTankScreen,'EXCEEDS_REFERENCE_TANK');
 assert.equal(estimateFivePhaseFuel({...A319,fuelTankCapacityKg:null,distanceKm:1000})
  .referenceTankScreen,'UNKNOWN');
 assert.equal(result.estimatedBurnCostUsd,Math.round(result.tripFuelKg*.95*100)/100);
});
test('only existing owner-verified fleet SQL provides reference data; preview does not mutate accounts',async()=>{
 const query=FLEET_SQL.fleet;
 for(const field of ['emptyFuelKgPer100Km','halfFuelKgPer100Km','fullFuelKgPer100Km',
  'cruiseFuelKgPerHour','fuelTankCapacityKg','fuelRateStatus'])
  assert.ok(query.includes(field),field);
 assert.match(query,/WHERE i.airline_id=\$1::uuid/);
 assert.match(query,/aircraft_fuel_planning_profiles_v1/);
 assert.match(query,/aircraft_game_fuel_family_v1/);
 assert.match(query,/historicalModelFuelFamily/);
 assert.match(query,/fuelFamilyEvidence/);
 assert.match(query,/aircraft_catalog_fuel_capacity_game_v1/);
 assert.match(query,/fuelConfidenceClass/);
 assert.match(query,/fuelPeerModel/);
 assert.doesNotMatch(query,/UPDATE |DELETE |INSERT INTO /);
 const app=await read('website/airline-workspace.mjs');
 assert.match(app,/getFuelAircraft:aircraftId=>data.connected/);
 assert.match(app,/marketSnapshot\?\.airlineId===data.airline\?\.id/);
 assert.match(app,/fleet-detail-fuel-burn/);
 assert.match(app,/fleet-detail-fuel-tank/);
});
test('route planner shows all phases, no dispatch or ledger activation',async()=>{
 const markup=routePlannerMarkup();
 assert.match(markup,/route-fuel-summary/);
 assert.match(markup,/route-fuel-phases/);
 const src=await read('website/route-planner.mjs');
 assert.match(src,/estimateFivePhaseFuel\(/);
 assert.match(src,/routeDistanceKm\(from,to\)/);
 assert.match(src,/airlinerra:fleet-fuel-updated/);
 assert.match(src,/getFuelAircraft\(owned.id\)/);
 assert.match(src,/Fuel profile incomplete/);
 assert.doesNotMatch(src,/postFuelCharge|activateFuelPayment|settleFuelFlight/);
});

test('airport price is a category-balanced game assumption, never supplier or fuel payment',()=>{
 const mega=previewAirportFuelPrice({key:'OURAIRPORTS:1',category:'Mega Hub',categoryStatus:'approved'},
  {fuelFamily:'TURBINE_KEROSENE_ASSUMED'});
 const local=previewAirportFuelPrice({key:'OURAIRPORTS:2',category:'Local',categoryStatus:'approved'},
  {fuelFamily:'TURBINE_KEROSENE_ASSUMED'});
 const missing=previewAirportFuelPrice({key:'OURAIRPORTS:3',category:'Unknown'},
  {fuelFamily:'TURBINE_KEROSENE_ASSUMED'});
 assert.equal(mega.categoryApproved,true);
 assert.ok(mega.usdPerKg<local.usdPerKg);
 assert.equal(mega.fromCurrentSupplier,false);
 assert.equal(local.currentAirportQuote,false);
 assert.equal(local.accountingEnabled,false);
 assert.equal(missing.gameCategory,null);
 assert.equal(missing.usdPerKg,.95);
 assert.equal(missing.status,'GENERIC_GAME_BASE');
 assert.equal(BENCHMARK_SPOT.observedDate,'2026-11-03');
 assert.ok(BENCHMARK_SPOT.usdPerKg>1);
 assert.equal(Object.keys(AIRPORT_TIER_FACTORS).length,6);
});
test('route fuel uses owner airport price estimate but hides raw internal model provenance',async()=>{
 const code=await read('website/route-planner.mjs');
 assert.match(code,/previewAirportFuelPrice\(originProfile,\{fuelFamily:aircraft.fuelFamily\}\)/);
 assert.match(code,/priceUsdPerKg:price\.usdPerKg/);
 assert.match(code,/NOT the complete flight cost/);
 assert.match(code,/originAirportCategory:originProfile/);
 assert.doesNotMatch(code,/fuelPeerModel\?\s*\(/);
 assert.match(code,/The fuel line is a forecast only, not the total or a charge/);
});

test('unverified engine and piston AVGAS never receive a kerosene game price',()=>{
 for(const family of ['UNKNOWN_ENGINE','AVGAS_PISTON',undefined]){
  const price=previewAirportFuelPrice({key:'OURAIRPORTS:131',category:'Large',
   categoryStatus:'approved'}, {fuelFamily:family});
  assert.equal(price.usdPerKg,null);
  assert.equal(price.status,'UNPRICED_FUEL_FAMILY');
  assert.equal(price.accountingEnabled,false);
 }
});
test('full five-phase fuel quantities survive unavailable fuel price, without fake $0',()=>{
 const result=estimateFivePhaseFuel({...A319,distanceKm:1000,priceUsdPerKg:null});
 assert.equal(result.status,'PLANNING_ESTIMATE');
 assert.ok(result.tripFuelKg>3000);
 assert.equal(result.estimatedBurnCostUsd,null);
 assert.equal(result.fuelPriceUsdPerKg,null);
 assert.equal(result.phases.length,5);
 assert.equal(result.phases[0].fuelUsd,null);
 assert.equal(result.priceEvidence,'UNKNOWN_OR_UNSUPPORTED_FUEL_FAMILY');
 assert.equal(result.ledgerPosted,false);
});

test('model family evidence never means installed engine, certified fuel or game cash approval',async()=>{
 const service=await read('server/fleet-acquisition-service.mjs');
 assert.match(service,/fuelModelWithoutEngine/);
 assert.match(service,/fuelFamilySourceUrl/);
 assert.match(service,/fuelFamilyEvidence/);
 const migration=await read('supabase/migrations/20261110235900_source_linked_aircraft_fuel_family_models_v2.sql');
 assert.match(migration,/security_invoker = true/);
 assert.match(migration,/refueling|refuelling/i);
 assert.match(migration,/b\.refuelling_approved/);
 assert.match(migration,/b\.fuel_financial_settlement_approved/);
 assert.match(migration,/revoke all on airlinerra_game\.aircraft_fuel_family_reference_v2/);
 const profile=await read('website/airline-workspace.mjs');
 assert.match(profile,/Turbine\/kerosene — model-level game assumption/);
 assert.doesNotMatch(profile,/Aviation gasoline \(piston model/);
});

test('all catalog aircraft use a single turbine/kerosene GAME fuel family without rewriting real-world evidence',async()=>{
 const sql=await read('supabase/migrations/20261110235930_universal_kerosene_game_fuel_family_v1.sql');
 const query=FLEET_SQL.fleet;
 assert.match(sql,/aircraft_game_fuel_family_v1/);
 assert.match(sql,/TURBINE_KEROSENE_ASSUMED/);
 assert.match(sql,/UNIVERSAL_GAMEPLAY_ASSUMPTION/);
 assert.match(sql,/research\.fuel_family as research_fuel_family/);
 assert.match(sql,/aircraft_fuel_family_reference_v2 research/);
 assert.match(sql,/research\.refuelling_approved|false::boolean as refuelling_approved/);
 assert.match(sql,/false::boolean as fuel_financial_settlement_approved/);
 assert.match(sql,/security_invoker = true/);
 assert.match(sql,/revoke all on airlinerra_game\.aircraft_game_fuel_family_v1/);
 assert.match(query,/aircraft_game_fuel_family_v1 fueltype/);
 assert.match(query,/historicalModelFuelFamily/);
 const profile=await read('website/airline-workspace.mjs');
 assert.match(profile,/Turbine\/kerosene — model-level game assumption/);
});
test('all GAME aircraft can use the single kerosene tier pricing model, historical source remains separate',()=>{
 for(const category of ['Local','Regional','Medium','Large','Major Hub','Mega Hub']){
  const quote=previewAirportFuelPrice({key:'OURAIRPORTS:1',category},
    {fuelFamily:'TURBINE_KEROSENE_ASSUMED'});
  assert.ok(quote.usdPerKg>0);
  assert.equal(quote.fuelType,'TURBINE_KEROSENE_ASSUMED');
  assert.equal(quote.accountingEnabled,false);
  assert.equal(quote.fromCurrentSupplier,false);
 }
});
