import test from 'node:test';
import assert from 'node:assert/strict';
import {planSection9FivePhaseFlight,inspectSection9FlightProjection}
 from '../server/section9-flight-phase-timeline.mjs';
const airlineId='11111111-1111-4111-8111-111111111111',
 aircraftInventoryId='22222222-2222-4222-8222-222222222222',
 scheduleId='33333333-3333-4333-8333-333333333333';
const initial=()=>({
 airlineId,aircraftInventoryId,scheduleId,flightLocalDate:'2026-11-11',
 weeklyEntry:3,scheduledDepartureUtc:'2026-11-11T22:30:00Z',
 originAirportKey:'OURAIRPORTS:1',destinationAirportKey:'OURAIRPORTS:2',
 distanceKm:1000,
 aircraft:{id:aircraftInventoryId,airlineId,configurationId:16,
  fuelFamily:'TURBINE_KEROSENE_ASSUMED',cruiseSpeedKmh:840,
  emptyFuelKgPer100Km:266.6,halfFuelKgPer100Km:288.3,
  fullFuelKgPer100Km:310,fuelTankCapacityKg:24152},
 payloadFraction:.75,fuelPriceUsdPerKg:.95
});
const valid=()=>planSection9FivePhaseFlight(initial());
test('flight simulation has five distinct sequential phases, with no activation or cash',()=>{
 const a=valid(),b=valid();
 assert.equal(a.status,'FLIGHT_PHASE_DRY_RUN_PLAN');
 assert.deepEqual(a,b);
 assert.deepEqual(a.phases.map(p=>p.key),
  ['taxiOut','climb','cruise','descent','taxiIn']);
 assert.equal(a.phases[0].durationSeconds,900);
 assert.equal(a.phases[1].durationSeconds,1200);
 assert.equal(a.phases[3].durationSeconds,1200);
 assert.equal(a.phases[4].durationSeconds,600);
 assert.ok(a.phases[2].durationSeconds>0);
 assert.equal(a.fuel.phases.length,5);
 assert.equal(a.fuel.ledgerPosted,false);
 assert.equal(a.dispatchAuthorized,false);
 assert.equal(a.movementRecorded,false);
 assert.equal(a.ledgerPosted,false);
 for(let i=1;i<5;i++)
  assert.equal(a.phases[i-1].scheduledEndUtc,a.phases[i].scheduledStartUtc);
 assert.equal(a.plannedCompletionUtc,a.phases[4].scheduledEndUtc);
 assert.ok(a.phases.every(x=>x.forecastId.startsWith('flight-phase-preview:')));
});
test('short flights compress climb/descent and have zero negative cruise',()=>{
 const a=initial();a.distanceKm=100;
 const plan=planSection9FivePhaseFlight(a);
 assert.equal(plan.status,'FLIGHT_PHASE_DRY_RUN_PLAN');
 assert.equal(plan.phases[2].durationSeconds,0);
 assert.ok(plan.phases[1].durationSeconds<1200);
 assert.ok(plan.phases[3].durationSeconds<1200);
 assert.ok(plan.fuel.tripFuelKg>0);
});
test('projection is deterministic for planned, taxi, climb, cruise, descent and completion',()=>{
 const plan=valid();
 const before=inspectSection9FlightProjection(plan,'2026-11-11T22:29:00Z');
 assert.equal(before.state,'scheduled');
 assert.equal(before.projectedFuelBurnKg,0);
 const taxi=inspectSection9FlightProjection(plan,'2026-11-11T22:35:00Z');
 assert.equal(taxi.phase,'taxiOut');
 assert.ok(taxi.projectedFuelBurnKg>0);
 const climbing=inspectSection9FlightProjection(plan,'2026-11-11T22:50:00Z');
 assert.equal(climbing.phase,'climb');
 assert.ok(climbing.projectedFuelBurnKg>taxi.projectedFuelBurnKg);
 const completed=inspectSection9FlightProjection(plan,plan.plannedCompletionUtc);
 assert.equal(completed.state,'forecast_complete');
 assert.equal(completed.phase,null);
 assert.equal(completed.projectedFuelBurnKg,plan.fuel.tripFuelKg);
 assert.equal(completed.actualArrivalVerified,false);
 assert.equal(completed.ledgerPosted,false);
 assert.ok(completed.projectedFuelRemainingFromScreeningLoadKg>=0);
});
test('midnight UTC rollover is handled by ISO instants without dates from browser clock',()=>{
 const params=initial();params.distanceKm=2400;
 const timeline=planSection9FivePhaseFlight(params);
 assert.match(timeline.plannedCompletionUtc,/^2026-11-12/);
 const prog=inspectSection9FlightProjection(timeline,'2026-11-12T00:00:00Z');
 assert.equal(prog.status,'FLIGHT_PHASE_PROJECTION');
 assert.notEqual(prog.state,'scheduled');
 assert.equal(prog.actualDepartureVerified,false);
});
test('unverified identity, non-kerosene game type or missing consumption are blocked',()=>{
 const mutations=[
  p=>{p.aircraft.airlineId='44444444-4444-4444-8444-444444444444'},
  p=>{p.aircraft.id='44444444-4444-4444-8444-444444444444'},
  p=>{p.aircraft.fuelFamily='AVGAS_PISTON'},
  p=>{p.scheduledDepartureUtc='invalid'},
  p=>{p.originAirportKey=p.destinationAirportKey},
  p=>{p.weeklyEntry=8},
  p=>{p.aircraft.fullFuelKgPer100Km=null;p.aircraft.halfFuelKgPer100Km=null;p.aircraft.emptyFuelKgPer100Km=null}
 ];
 for(const mutate of mutations){
  const p=initial();mutate(p);
  const plan=planSection9FivePhaseFlight(p);
  assert.equal(plan.status,'FLIGHT_PHASE_PLAN_BLOCKED');
  assert.equal(plan.dispatchAuthorized,false);
 }
});
test('the projection never produces an actual flight departure or arrival proof',()=>{
 const plan=valid();
 const projection=inspectSection9FlightProjection(plan,plan.plannedCompletionUtc);
 for(const value of [plan,projection]){
  assert.equal(value.movementRecorded,false);
  assert.equal(value.ledgerPosted,false);
  assert.equal(value.simulatedOnly,true);
 }
 assert.equal(projection.actualArrivalVerified,false);
});
