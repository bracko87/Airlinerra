import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {inspectVerifiedArrivalForFuel} from '../server/section9-verified-flight-fuel-bridge.mjs';
import {SECTION9_MOVEMENT_SQL} from '../server/section9-operated-flight-movement-ingress.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const airlineId='11111111-1111-4111-8111-111111111111';
const aircraftId='22222222-2222-4222-8222-222222222222';
const scheduleId='33333333-3333-4333-8333-333333333333';
const day='2026-11-11',weeklyEntry=3,origin='OURAIRPORTS:1',destination='OURAIRPORTS:2';
const occurrence=scheduleId+':'+day+':'+weeklyEntry;
const eventId='operate-v1.'+scheduleId.replaceAll('-','')+'.20261111.3.arrived';
const sample=()=>({
 movementEvent:{worldId:1,airlineId,scheduleId,flightLocalDate:day,
  weeklyEntry,phase:'arrived',eventId},
 movementReceipt:{status:'operated_flight_arrival_recorded',phase:'arrived',
  flightOccurrenceId:occurrence,movementRecorded:true,replayed:false,
  locationStatus:'grounded',lastVerifiedAirport:destination,
  flightActivated:false,ledgerPosted:false,bookingsCreated:false,
  canActivateNormalFlight:false},
 aircraft:{id:aircraftId,airlineId,configurationId:16,
  fuelFamily:'TURBINE_KEROSENE_ASSUMED',cruiseSpeedKmh:840,
  fullFuelKgPer100Km:310,halfFuelKgPer100Km:288.3,
  emptyFuelKgPer100Km:266.6,fuelTankCapacityKg:24152},
 route:{airlineId,scheduleId,aircraftInventoryId:aircraftId,
  originAirportKey:origin,destinationAirportKey:destination,distanceKm:1000},
 departureAirport:{key:origin,category:'Major Hub',categoryStatus:'approved'},
 payloadFraction:.7
});
test('existing movement ingress exposes the signed operated arrival path',()=>{
 assert.match(SECTION9_MOVEMENT_SQL.ingest,/section9_record_signed_operated_flight_movement_v1/);
 assert.match(SECTION9_MOVEMENT_SQL.leased,/section9_record_leased_operated_flight_movement_v1/);
});
test('verified arrival connects to fuel phases without any money or stock writes',()=>{
 const a=inspectVerifiedArrivalForFuel(sample());
 const b=inspectVerifiedArrivalForFuel(sample());
 assert.deepEqual(a,b);
 assert.equal(a.status,'ARRIVAL_FUEL_DRY_RUN_READY');
 assert.equal(a.flightOccurrenceId,occurrence);
 assert.equal(a.idempotencyCandidate,'fuel:'+occurrence);
 assert.equal(a.fuel.status,'PLANNING_ESTIMATE');
 assert.equal(a.fuel.phases.length,5);
 assert.ok(a.fuel.tripFuelKg>0);
 assert.ok(a.fuel.estimatedBurnCostUsd>0);
 assert.equal(a.fuel.dispatchApproved,false);
 assert.equal(a.financialSettlementAuthorized,false);
 assert.equal(a.ledgerPosted,false);
 assert.equal(a.refuellingPosted,false);
 assert.equal(a.flightFuelWritten,false);
});
test('departure, replay and unconfirmed movement results fail closed',()=>{
 const variants=[
  p=>{p.movementEvent.phase='departed'},
  p=>{p.movementEvent.eventId='random-event-identity-123'},
  p=>{p.movementReceipt.status='operated_flight_departure_recorded'},
  p=>{p.movementReceipt.replayed=true},
  p=>{p.movementReceipt.movementRecorded=false},
  p=>{p.movementReceipt.flightOccurrenceId='different'},
  p=>{p.movementReceipt.locationStatus='in_flight'},
  p=>{p.movementReceipt.canActivateNormalFlight=true},
  p=>{p.movementReceipt.ledgerPosted=true},
  p=>{p.movementReceipt.lastVerifiedAirport=origin},
  p=>{p.movementReceipt=null}
 ];
 for(const fn of variants){
  const q=sample();fn(q);
  const r=inspectVerifiedArrivalForFuel(q);
  assert.equal(r.status,'FUEL_BRIDGE_BLOCKED',JSON.stringify(q));
  assert.equal(r.ledgerPosted,false);
 }
});
test('cross-company aircraft, schedule or airport cannot connect',()=>{
 const variants=[
  p=>{p.aircraft.airlineId='44444444-4444-4444-8444-444444444444'},
  p=>{p.route.airlineId='44444444-4444-4444-8444-444444444444'},
  p=>{p.route.scheduleId='55555555-5555-4555-8555-555555555555'},
  p=>{p.route.aircraftInventoryId='66666666-6666-4666-8666-666666666666'},
  p=>{p.departureAirport.key=destination},
  p=>{p.route.originAirportKey=destination}
 ];
 for(const fn of variants){
  const q=sample();fn(q);
  assert.equal(inspectVerifiedArrivalForFuel(q).status,'FUEL_BRIDGE_BLOCKED');
 }
});
test('missing fuel consumption fails closed without fabricated charges',()=>{
 const q=sample();
 q.aircraft.fullFuelKgPer100Km=null;q.aircraft.halfFuelKgPer100Km=null;
 q.aircraft.emptyFuelKgPer100Km=null;
 const r=inspectVerifiedArrivalForFuel(q);
 assert.equal(r.status,'FUEL_BRIDGE_BLOCKED');
 assert.equal(r.reason,'AIRCRAFT_FUEL_REFERENCE_INCOMPLETE');
 assert.equal(r.ledgerPosted,false);
});
test('dry run never accesses or updates the database',async()=>{
 const source=await read('server/section9-verified-flight-fuel-bridge.mjs');
 assert.doesNotMatch(source,/database\.connect\(|client\.query\(|fetch\(|\bINSERT\b|\bUPDATE\b|\bDELETE\b/);
 const worker=await read('server/section9-aircraft-operations-worker.mjs');
 const dispatcher=await read('server/section9-verified-flight-operations-dispatcher.mjs');
 assert.match(worker,/dispatchAircraftDay/);
 assert.match(dispatcher,/confirmActualOperation/);
 assert.match(dispatcher,/acceptSignedLeasedFlightEvent/);
});
