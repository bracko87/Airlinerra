import test from 'node:test';
import assert from 'node:assert/strict';
import {MAINTENANCE_CHECKS,MAINTENANCE_COST_GROUPS,maintenanceGroupForModel,
 airframeAge,quoteAircraftCheck,maintenanceDue,maintenanceLocationEligibility}
 from '../server/airlinerra-maintenance-policy.mjs';

test('six game checks have requested downtime and no pre-flight check',()=>{
 assert.deepEqual(Object.fromEntries(Object.entries(MAINTENANCE_CHECKS)
  .map(([code,r])=>[code,r.durationHours])),
  {daily:1,weekly:3,a:6,b:24,c:168,d:504});
 assert.equal('preflight' in MAINTENANCE_CHECKS,false);
 assert.equal(MAINTENANCE_CHECKS.a.flightHours,500);
 assert.equal(MAINTENANCE_CHECKS.b.flightHours,750);
 assert.equal(MAINTENANCE_CHECKS.c.calendarMonths,24);
 assert.equal(MAINTENANCE_CHECKS.d.calendarMonths,96);
});
test('eight maintenance cost groups and manufacturer model age separate',()=>{
 assert.equal(MAINTENANCE_COST_GROUPS.length,8);
 assert.equal(maintenanceGroupForModel({mtowKg:75000,model:'A319-100'}),5);
 assert.equal(maintenanceGroupForModel({mtowKg:78000,model:'A320-200'}),6);
 assert.equal(maintenanceGroupForModel({mtowKg:24000,model:'ATR 72'}),3);
 assert.equal(maintenanceGroupForModel({mtowKg:350000,model:'777-300ER'}),8);
 assert.equal(airframeAge(null,'2026-11-10T00:00:00Z'),null);
 const quote=quoteAircraftCheck({check:'c',groupId:5,buildYear:2012,gameDate:'2026-11-10T00:00:00Z'});
 assert.equal(quote.status,'game_estimate');assert.equal(quote.estimatedUsd,250000);
 assert.equal(quote.durationHours,168);
 assert.equal(quoteAircraftCheck({check:'c',groupId:5,gameDate:'2026-11-10T00:00:00Z'}).estimatedUsd,null);
});
test('check counters never silently assume an unknown aircraft has completed checks',()=>{
 assert.equal(maintenanceDue({check:'a',asOfUtc:'2026-11-10T13:00:00Z'}).status,
 'unverified_flight_hour_baseline');
 assert.equal(maintenanceDue({check:'daily',asOfUtc:'2026-11-10T13:00:00Z'}).status,
 'unverified_check_history');
 const due=maintenanceDue({check:'a',asOfUtc:'2026-11-10T13:00:00Z',
  trackingStartedUtc:'2026-01-01T00:00:00Z',trackedFlightHours:1250,
  lastCompletedUtc:'2026-09-01T00:00:00Z',lastCompletedAtFlightHours:750});
 assert.equal(due.status,'due');assert.equal(due.remainingFlightHours,0);
 const notDue=maintenanceDue({...{
  check:'a',asOfUtc:'2026-11-10T13:00:00Z',
  trackingStartedUtc:'2026-01-01T00:00:00Z',
  lastCompletedUtc:'2026-09-01T00:00:00Z',lastCompletedAtFlightHours:750},
  trackedFlightHours:950});
 assert.equal(notDue.status,'not_due');
 assert.equal(maintenanceDue({check:'daily',asOfUtc:'2026-11-10T15:00:00Z',
  lastCompletedUtc:'2026-11-09T14:00:00Z'}).status,'due');
});
test('daily/weekly everywhere, heavy checks need precise approved aircraft MRO and verified position',()=>{
 const location={approvedAirport:true,verifiedGroundAirportKey:'WSSS',targetAirportKey:'WSSS'};
 assert.equal(maintenanceLocationEligibility({check:'daily',...location}).allowed,true);
 assert.equal(maintenanceLocationEligibility({check:'weekly',...location}).allowed,true);
 assert.equal(maintenanceLocationEligibility({check:'c',...location}).reason,
  'no_aircraft_type_approved_mro_at_airport');
 assert.equal(maintenanceLocationEligibility({check:'c',...location,
  capability:{approvalStatus:'game_approved',check:'c',airportKey:'WSSS'}}).allowed,true);
 assert.equal(maintenanceLocationEligibility({check:'c',...location,
  verifiedGroundAirportKey:'EDDH',
  capability:{approvalStatus:'game_approved',check:'c',airportKey:'WSSS'}}).allowed,false);
});
