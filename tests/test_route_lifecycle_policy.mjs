import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {routeLaunchDelay,ROUTE_LAUNCH_DELAY_GAME_DAYS,
 ROUTE_BOOKING_WINDOW_GAME_DAYS,passengerProtectionStatus,
 gameFlightBookingWindow,previewRouteCancellation
} from '../website/route-lifecycle-rules.mjs';
import {validateFlightSchedulePayload,SCHEDULE_SQL}
 from '../server/flight-schedule-service.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
const A='22222222-2222-4222-8222-222222222222';
const P='33333333-3333-4333-8333-333333333333';
const sample=()=>({
 action:'plan-save',airlineId:A,aircraftInventoryId:P,
 flightNumber:'PA444',originAirportKey:'OURAIRPORTS:2220',
 destinationAirportKey:'OURAIRPORTS:4001',
 weeklySchedule:[{day:0,time:'09:00'}],
 departureStand:'terminal',arrivalStand:'terminal',
 turnaroundMinutes:45,
 fares:{economy:80,premium:null,business:null,first:null},
 service:{onboard:'basic',baggage:'standard',cargo:'none'},
 referenceDepartureUtc:null,referenceArrivalUtc:null
});
test('route start preference accepts 0/3/7 game days and is persisted only as planning metadata',async()=>{
 assert.deepEqual(ROUTE_LAUNCH_DELAY_GAME_DAYS,[0,3,7]);
 for(const delay of [0,3,7]){
  assert.equal(routeLaunchDelay(delay),delay);
  assert.equal(validateFlightSchedulePayload({...sample(),launchDelayDays:delay}),true);
 }
 for(const delay of [-1,2,8,'7',null,1.5]){
  assert.equal(routeLaunchDelay(delay),null);
  assert.equal(validateFlightSchedulePayload({...sample(),launchDelayDays:delay}),false);
 }
 assert.equal(validateFlightSchedulePayload(sample()),true);
 assert.match(SCHEDULE_SQL.planSave,/planning_options/);
 assert.match(SCHEDULE_SQL.planList,/launchDelayDays/);
 const html=routePlannerMarkup();
 assert.match(html,/id="route-launch-delay"/);
 assert.match(html,/After 3 game days/);
 assert.match(html,/After 7 game days/);
 const client=await read('../website/flight-schedule-client.mjs');
 const backend=await read('../server/flight-schedule-service.mjs');
 assert.match(client,/launchDelayDays=0/);
 assert.match(backend,/launchDelayDays:body\.launchDelayDays\?\?0/);
 assert.doesNotMatch(backend,/passengerBookingsCreated:true/);
});
test('seven-day sale policy protects all passengers; 48h is a higher-urgency threshold',()=>{
 assert.equal(ROUTE_BOOKING_WINDOW_GAME_DAYS,7);
 assert.deepEqual(gameFlightBookingWindow(40),{opensGameDay:40,latestDepartureGameDay:47});
 assert.deepEqual(passengerProtectionStatus({hasBooking:true,hoursUntilDeparture:120}),
  {protected:true,urgent:false});
 assert.deepEqual(passengerProtectionStatus({hasBooking:true,hoursUntilDeparture:48}),
  {protected:true,urgent:true});
 assert.deepEqual(passengerProtectionStatus({hasBooking:true,hoursUntilDeparture:1}),
  {protected:true,urgent:true});
 assert.deepEqual(passengerProtectionStatus({hasBooking:false,hoursUntilDeparture:1}),
  {protected:false,urgent:false});
});
test('cancellation planning leaves actual booking, ledger and slot changes disabled',()=>{
 const departures=[
  {id:'past',gameDay:39,status:'completed',bookingCount:100},
  {id:'today',gameDay:40,status:'booked',bookingCount:16},
  {id:'tomorrow',gameDay:41,status:'booked',bookingCount:25},
  {id:'week',gameDay:47,status:'on_sale',bookingCount:8},
  {id:'later',gameDay:48,status:'planned',bookingCount:0}
 ];
 const one=previewRouteCancellation({gameDay:40,mode:'single-occurrence',
  occurrences:departures,selectedOccurrenceId:'tomorrow'});
 assert.deepEqual(one.affectedFlightIds,['tomorrow']);
 assert.equal(one.protectedPassengers,25);
 assert.equal(one.safeToExecute,false);
 const immediate=previewRouteCancellation({gameDay:40,
  mode:'all-upcoming',occurrences:departures});
 assert.deepEqual(immediate.affectedFlightIds,['today','tomorrow','week','later']);
 assert.equal(immediate.protectedPassengers,49);
 assert.equal(immediate.requiresPassengerReaccommodation,true);
 const grace=previewRouteCancellation({gameDay:40,
  mode:'finish-seven-day-window',occurrences:departures});
 assert.deepEqual(grace.affectedFlightIds,['later']);
 assert.equal(grace.protectedPassengers,0);
 assert.equal(grace.safeToExecute,false);
 assert.deepEqual(departures.map(x=>x.status),
  ['completed','booked','booked','on_sale','planned'],'preview never mutates flights');
});
test('local route cancellation requires confirmation and blocks protected server routes',async()=>{
 const ops=await read('../website/airline-operations-center.mjs');
 const schedule=await read('../website/airline-workspace.mjs');
 const renderer=await read('../website/aircraft-weekly-schedule-board.mjs');
 assert.match(ops,/id="operations-route-cancel-open"/);
 assert.match(ops,/id="operations-route-cancel-confirm-button"/);
 assert.match(ops,/id="operations-route-cancel-dismiss"/);
 assert.match(ops,/if\(route\.serverScheduleId\)/);
 assert.match(ops,/server\.scheduler\.planDelete/);
 assert.match(ops,/if\(!await persist\('routes','route'\)\)/);
 assert.match(ops,/airlinerra:route-draft-cancelled/);
 assert.match(schedule,/airlinerra:route-draft-cancelled/);
 assert.doesNotMatch(ops,/scheduler\.delete\(\{airlineId.*serverPlanningId/);
 assert.match(renderer,/flightNumber\+route,/);
 assert.doesNotMatch(renderer,/flightNumber\+route\+\(isBooked\?'':' · Planned'\)/);
});

test('owner-scoped inactive planning route cancellation rejects unauthorized or active schedule writes',async()=>{
 const planId='55555555-5555-4555-8555-555555555555';
 assert.equal(validateFlightSchedulePayload({action:'plan-delete',airlineId:A,planId}),true);
 assert.equal(validateFlightSchedulePayload({action:'plan-delete',airlineId:A,planId:'not-uuid'}),false);
 assert.equal(validateFlightSchedulePayload({action:'plan-delete',airlineId:A,planId,
  releaseSlots:true}),false);
 assert.match(SCHEDULE_SQL.planDelete,/a\.owner_player_id=\$1::uuid/);
 assert.match(SCHEDULE_SQL.planDelete,/p\.slots_reserved=false AND p\.activated=false/);
 assert.match(SCHEDULE_SQL.planDelete,/NOT EXISTS/);
 assert.match(SCHEDULE_SQL.planDelete,/airline_flight_schedule_drafts_v1/);
 const client=await read('../website/flight-schedule-client.mjs');
 const api=await read('../server/flight-schedule-service.mjs');
 assert.match(client,/planDelete:\(\{airlineId,planId\}\)/);
 assert.match(api,/passengerBookingsChanged:false,airportSlotsChanged:false,ledgerPosted:false/);
});
