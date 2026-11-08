import test from 'node:test';
import assert from 'node:assert/strict';
import {section9ReconcileAdjacentForecasts}
 from '../server/section9-settlement-preflight.mjs';

const targetDate='2026-11-09';
const scheduleId='11111111-1111-4111-8111-111111111111';
const airlineId='22222222-2222-4222-8222-222222222222';
const occurrence=(fields={})=>({
 flightId:scheduleId+':'+targetDate+':2',
 scheduleId,weeklyEntry:2,scheduleVersion:1,commercialPlanVersion:1,
 capacitySource:'verified_activated_schedule',
 verificationSource:'simultaneous-config',
 departureUtc:'2026-11-09T10:00:00Z',arrivalUtc:'2026-11-09T12:00:00Z',
 airlineId,marketDate:targetDate,passengerSeats:100,
 passengers:70,directPassengers:45,connectingPassengers:25,
 cargoTonnes:0.6,cargoCapacityTonnes:1.5,
 ticketRevenueUsd:700,cargoRevenueUsd:60,...fields
});
const snapshots=(first=[],middle=[],last=[])=>[
 {gameDate:'2026-11-08',status:'completed',readOnly:true,flights:first},
 {gameDate:targetDate,status:'completed',readOnly:true,flights:middle},
 {gameDate:'2026-11-10',status:'completed',readOnly:true,flights:last}
];

test('Cross-date shared flight reconciles capacity once and makes stable preview intents',()=>{
 const a=occurrence();
 const b=occurrence({
  passengers:20,directPassengers:0,connectingPassengers:20,
  cargoTonnes:0.4,ticketRevenueUsd:200,cargoRevenueUsd:40
 });
 const result=section9ReconcileAdjacentForecasts({
  targetDate,snapshots:snapshots([a],[b])});
 assert.equal(result.status,'preview_reconciled');
 assert.equal(result.capacityReconciled,true);
 assert.equal(result.uniqueFlightOccurrences,1);
 assert.equal(result.overlappingFlightOccurrences,1);
 assert.equal(result.totalFlightRowsChecked,2);
 assert.equal(result.futureLedgerIntents.length,2);
 assert.equal(result.futureLedgerIntents.find(x=>x.kind==='PASSENGER_REVENUE').amountUsd,900);
 assert.equal(result.futureLedgerIntents.find(x=>x.kind==='CARGO_REVENUE').amountUsd,100);
 assert.equal(new Set(result.futureLedgerIntents.map(x=>x.idempotencyKey)).size,2);
 assert.equal(result.ledgerPostingAllowed,false);
 assert.ok(result.futureLedgerIntents.every(x=>x.readOnly===true));
});

test('Two day forecasts cannot jointly occupy more seats than the actual flight offers',()=>{
 const result=section9ReconcileAdjacentForecasts({
  targetDate,snapshots:snapshots(
   [occurrence()],
   [occurrence({passengers:40,directPassengers:20,connectingPassengers:20,
    cargoTonnes:0,ticketRevenueUsd:400,cargoRevenueUsd:0})])});
 assert.equal(result.status,'blocked_conflicting_flight_usage');
 assert.equal(result.overbookedFlights,1);
 assert.equal(result.futureLedgerIntents.length,0);
 assert.equal(result.conflicts[0].passengers,110);
});

test('Cargo across adjacent daily jobs cannot exceed shared aircraft hold',()=>{
 const result=section9ReconcileAdjacentForecasts({
  targetDate,snapshots:snapshots(
   [occurrence({cargoTonnes:1})],
   [occurrence({passengers:0,directPassengers:0,connectingPassengers:0,
    cargoTonnes:0.9,ticketRevenueUsd:0,cargoRevenueUsd:90})])});
 assert.equal(result.capacityReconciled,false);
 assert.equal(result.overbookedFlights,1);
 assert.equal(result.futureLedgerIntents.length,0);
});

test('Changed aircraft capacities or fare versions fail pre-settlement',()=>{
 for(const field of [
  {scheduleVersion:2},{commercialPlanVersion:3},{passengerSeats:150},
  {departureUtc:'2026-11-09T11:00:00Z'}
 ]){
  const result=section9ReconcileAdjacentForecasts({
   targetDate,snapshots:snapshots(
    [occurrence({passengers:0,directPassengers:0,connectingPassengers:0,
     ticketRevenueUsd:0,cargoTonnes:0,cargoRevenueUsd:0})],
    [occurrence(field)]
   )});
  assert.equal(result.capacityReconciled,false);
  assert.equal(result.futureLedgerIntents.length,0);
 }
});

test('Missing or unfinished neighboring day blocks ledger-intent generation',()=>{
 const result=section9ReconcileAdjacentForecasts({
  targetDate,snapshots:snapshots([],[]).slice(0,2)});
 assert.equal(result.status,'blocked_incomplete_neighboring_forecasts');
 assert.equal(result.ledgerPostingAllowed,false);
 assert.deepEqual(result.missingCompletedDates,['2026-11-10']);
});

test('Spoofed schedule identity or unverified source fails closed',()=>{
 const f=occurrence();
 for(const bad of [
  {...f,flightId:'f1'},
  {...f,capacitySource:'browser-input'},
  {...f,passengers:101},
  {...f,ticketRevenueUsd:-1},
  {...f,passengers:70,directPassengers:90,connectingPassengers:20},
  {...f,verificationSource:''}
 ]){
  assert.throws(()=>section9ReconcileAdjacentForecasts({
   targetDate,snapshots:snapshots([],[bad])}),
   /SECTION9_UNVERIFIED_OR_INVALID_SETTLEMENT_SOURCE/);
 }
});

test('Duplicated flight row inside one daily forecast is rejected',()=>{
 assert.throws(()=>section9ReconcileAdjacentForecasts({
  targetDate,snapshots:snapshots([],[occurrence(),occurrence()])}),
  /SECTION9_DUPLICATE_FLIGHT_WITHIN_FORECAST/);
});

test('Read-only reference keys are stable across identical retries',()=>{
 const input={targetDate,snapshots:snapshots([],[occurrence()])};
 const one=section9ReconcileAdjacentForecasts(input);
 const two=section9ReconcileAdjacentForecasts(input);
 assert.deepEqual(one.futureLedgerIntents,two.futureLedgerIntents);
 assert.equal(one.ledgerPostingAllowed,false);
});
