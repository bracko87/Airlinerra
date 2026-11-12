import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFlightScheduleHandler,validateFlightSchedulePayload,
 SCHEDULE_SQL,FLIGHT_SCHEDULE_API_ROUTE
} from '../server/flight-schedule-service.mjs';
import {SEVEN_DAY_WINDOW_SQL} from '../server/section9-seven-day-window.mjs';
import {summarizeSection9FlightReadiness} from '../website/section9-flight-readiness.mjs';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const USER='11111111-1111-4111-8111-111111111111';
const body={action:'booking-window-preview',airlineId:AIRLINE,scheduleId:SCHEDULE};
const req=value=>new Request('https://airlinerra.com/api/v1/player/flight-schedule-drafts',{
 method:'POST',
 headers:{origin:'https://airlinerra.com',
  'x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
  authorization:'Bearer '+'x'.repeat(40),
  'content-type':'application/json'},
 body:JSON.stringify(value)
});
const model=()=>({
 status:'seven_day_preview_only',worldId:1,scheduleId:SCHEDULE,
 readOnly:true,bookingEnabled:false,passengerBookingsCreated:false,
 ledgerPosted:false,gameDate:'2026-11-12',lastGameDate:'2026-11-18',
 windowDays:7,verifiedSeatCapacity:null,passengerCount:null,
 occurrences:[{flightLocalDate:'2026-11-13',
  departureLocal:'2026-11-13T09:00:00',
  status:'not_saleable',bookingEnabled:false,passengerBookings:null}]
});
const handlerFor=data=>{
 const calls=[];
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:{id:USER},error:null}),
  database:{connect:async()=>({query:async(sql,values)=>{
   calls.push({sql,values});
   assert.equal(sql,SCHEDULE_SQL.bookingWindowPreview);
   assert.deepEqual(values,[USER,AIRLINE,SCHEDULE]);
   return data;
  },release:()=>{}})}
 });
 return {handler,calls};
};
test('only owner-scoped schedule booking preview action is accepted',()=>{
 assert.equal(validateFlightSchedulePayload(body),true);
 for(const invalid of [{...body,scheduleId:USER.slice(1)},
  {...body,action:'booking-create'},
  {...body,passengerId:USER},{...body,bookings:1},
  {...body,airlineId:'other'}])
  assert.equal(validateFlightSchedulePayload(invalid),false);
 assert.equal(SEVEN_DAY_WINDOW_SQL,SCHEDULE_SQL.bookingWindowPreview);
 assert.match(SEVEN_DAY_WINDOW_SQL,/a\.owner_player_id=\$1::uuid/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/s\.airline_id=\$2::uuid/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/s\.id=\$3::uuid/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/holding_world_clock_v1/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/generate_series/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/pg_timezone_names/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/AMBIGUOUS_LOCAL_DEPARTURE/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/NONEXISTENT_LOCAL_DEPARTURE/);
 assert.match(SEVEN_DAY_WINDOW_SQL,/bookingEnabled',false/);
 assert.doesNotMatch(SEVEN_DAY_WINDOW_SQL,/\b(?:INSERT|UPDATE|DELETE|TRUNCATE)\b/i);
});
test('seven-day preview returns dated, non-saleable occurrences only',async()=>{
 const {handler,calls}=handlerFor({rowCount:1,rows:[{result:model()}]});
 const response=await handler(req(body));
 assert.equal(response.status,200);
 const reply=await response.json();
 assert.equal(reply.bookingEnabled,false);
 assert.equal(reply.passengerBookingsCreated,false);
 assert.equal(reply.occurrences.length,1);
 assert.equal(reply.occurrences[0].passengerBookings,null);
 assert.equal(calls.length,1);
});
test('foreign airline or missing authoritative date never exposes another route',async()=>{
 const {handler}=handlerFor({rowCount:0,rows:[]});
 const response=await handler(req(body));
 assert.equal(response.status,404);
 assert.equal((await response.json()).error,'OWNED_SCHEDULE_OR_GAME_CLOCK_NOT_AVAILABLE');
});
test('a preview that claims reservations or sales fails closed',async()=>{
 for(const unsafe of [
  {...model(),bookingEnabled:true},
  {...model(),passengerBookingsCreated:true},
  {...model(),ledgerPosted:true},
  {...model(),windowDays:8},
  {...model(),occurrences:[{status:'on_sale',bookingEnabled:true,passengerBookings:3}]}
 ]){
  const {handler}=handlerFor({rowCount:1,rows:[{result:unsafe}]});
  const response=await handler(req(body));
  assert.equal(response.status,503);
 }
});
test('Route Details renders seven days with booking closed until engine certification',async()=>{
 const [details,client]=await Promise.all([
  readFile(new URL('../website/section9-route-details.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/flight-schedule-client.mjs',import.meta.url),'utf8')
 ]);
 assert.match(details,/SEVEN-DAY WINDOW/);
 assert.match(details,/Not open for booking/);
 assert.match(details,/bookingWindowPreview/);
 assert.match(details,/if\(mySerial!==serial\)return/);
 assert.match(details,/data\?\.bookingEnabled!==false/);
 assert.match(client,/bookingWindowPreview:\(\{airlineId,scheduleId\}\)/);
 assert.doesNotMatch(details,/bookedPassengers\s*\|\|\s*0/);
});

test('private booking storage is strictly non-saleable and produces no upfront money',async()=>{
 const sql=await readFile(new URL('../supabase/migrations/20261112100704_section9_seven_day_booking_storage_gated_v1.sql',import.meta.url),'utf8');
 assert.match(sql,/CREATE TABLE IF NOT EXISTS airlinerra_game\.section9_dated_flight_occurrences_v1/);
 assert.match(sql,/CREATE TABLE IF NOT EXISTS airlinerra_game\.section9_passenger_reservation_batches_v1/);
 assert.match(sql,/CHECK\(booking_status='not_open'\)/);
 assert.match(sql,/CHECK\(booked_seats=0\)/);
 assert.match(sql,/CHECK\(reservation_status='unissued'\)/);
 assert.match(sql,/CHECK\(paid_upfront=false\)/);
 assert.match(sql,/CHECK\(recognized_revenue_usd=0\)/);
 assert.match(sql,/section9_dated_flight_occurrences_v1 ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/section9_passenger_reservation_batches_v1 ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/FROM PUBLIC, anon, authenticated, service_role/);
 assert.doesNotMatch(sql,/GRANT\s+(?:ALL|INSERT|UPDATE)/i);
});

test('saved planning route links only its matching server timetable and never enables tickets',async()=>{
 const sql=SCHEDULE_SQL.planList;
 assert.match(sql,/s\.id::text AS "serverScheduleId"/);
 assert.match(sql,/s\.status AS "serverScheduleStatus"/);
 assert.match(sql,/s\.operationally_verified AS "serverScheduleOperationallyVerified"/);
 assert.match(sql,/LEFT JOIN airlinerra_game\.airline_flight_schedule_drafts_v1 s/);
 for(const match of [
  's.airline_id=p.airline_id',
  's.flight_number=p.flight_number',
  's.aircraft_inventory_id=p.aircraft_inventory_id',
  's.origin_airport_key=p.origin_airport_key',
  's.destination_airport_key=p.destination_airport_key',
  's.weekly_schedule=p.weekly_schedule'
 ])assert.ok(sql.includes(match),match);
 const [operations,details]=await Promise.all([
  readFile(new URL('../website/airline-operations-center.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/section9-route-details.mjs',import.meta.url),'utf8')
 ]);
 assert.match(operations,/serverScheduleId:typeof plan\.serverScheduleId/);
 assert.match(operations,/plan\.serverScheduleStatus==='active'/);
 assert.match(operations,/plan\.serverScheduleOperationallyVerified===true/);
 assert.match(operations,/Active schedule · bookings closed/);
 assert.match(details,/route\.serverScheduleId\?/);
 assert.match(details,/Active schedule · flight movements not yet confirmed/);
 assert.match(details,/Booking is not yet enabled/);
});

test('My Routes uses authenticated records to explain the first operational blocker',async()=>{
 const basic={activationAvailable:false,fleet:[{id:'owned-1',fleetStatus:'in_service'}],
  plans:[],drafts:[]};
 const empty=summarizeSection9FlightReadiness(basic);
 assert.equal(empty.verified,true);
 assert.equal(empty.stage,'needs-route');
 assert.match(empty.text,/1 in-service aircraft, 0 planning routes, 0 registered schedules/);
 assert.match(empty.text,/create a route and save it to the airline database/);
 assert.match(empty.text,/Ticket sales remain disabled/);

 const planned=summarizeSection9FlightReadiness({
  ...basic,plans:[{planId:'plan-1',status:'planning'}]});
 assert.equal(planned.stage,'needs-schedule');
 assert.match(planned.text,/Operational Schedule Checks/);

 const registered=summarizeSection9FlightReadiness({
  ...basic,drafts:[{id:'draft-1',status:'draft',slotsReserved:true}]});
 assert.equal(registered.stage,'needs-certification');
 assert.equal(registered.slotDrafts,1);
 assert.match(registered.text,/crew duties, game licences, traffic rights/);
 assert.doesNotMatch(registered.text,/Tickets? (?:are |is )?on sale/);

 const active=summarizeSection9FlightReadiness({
  ...basic,drafts:[{id:'active-1',status:'active',slotsReserved:true}]});
 assert.equal(active.stage,'needs-execution-proof');
 assert.match(active.text,/not proof a flight operated/);

 for(const unsafe of [null,{}, {...basic,activationAvailable:true},
  {...basic,plans:'unverified'}, {...basic,drafts:null}])
  assert.equal(summarizeSection9FlightReadiness(unsafe).verified,false);

 const ui=await readFile(new URL('../website/airline-operations-center.mjs',
  import.meta.url),'utf8');
 assert.match(ui,/id="operations-flight-readiness"/);
 assert.match(ui,/summarizeSection9FlightReadiness\(reply\)\.text/);
});


test('unsaved custom cabin package is diagnosed without creating the PA400 planning route',async()=>{
 const action={
  action:'plan-save',airlineId:AIRLINE,aircraftInventoryId:'33333333-3333-4333-8333-333333333333',
  flightNumber:'PA400',originAirportKey:'OURAIRPORTS:4610',
  destinationAirportKey:'OURAIRPORTS:4615',
  weeklySchedule:[{day:0,time:'06:00'}],
  departureStand:'terminal',arrivalStand:'terminal',turnaroundMinutes:45,
  fares:{economy:78,premium:null,business:null,first:null},
  service:{onboard:'basic',baggage:'hand-only',cargo:'none',cabinPackageId:'pkg-1'},
  launchDelayDays:3,referenceDepartureUtc:null,referenceArrivalUtc:null
 };
 assert.equal(validateFlightSchedulePayload(action),true);
 const calls=[];
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:{id:USER},error:null}),
  database:{connect:async()=>({query:async(sql,args)=>{
   calls.push({sql,args});
   if(sql===SCHEDULE_SQL.planSave)return {rowCount:0,rows:[]};
   if(sql===SCHEDULE_SQL.savedCabinPackage){
    assert.deepEqual(args,[USER,AIRLINE,'pkg-1']);
    return {rowCount:1,rows:[{savedPackageExists:false}]};
   }
   throw Error('Unexpected SQL operation');
  },release:()=>{}})}
 });
 const response=await handler(req(action));
 assert.equal(response.status,409);
 const reply=await response.json();
 assert.equal(reply.reason,'CABIN_PACKAGE_NOT_SAVED');
 assert.match(reply.message,/Flight Services/);
 assert.equal(calls.length,2);
 assert.match(SCHEDULE_SQL.savedCabinPackage,/a\.owner_player_id=\$1::uuid/);
 assert.match(SCHEDULE_SQL.savedCabinPackage,/a\.id=\$2::uuid/);
 assert.match(SCHEDULE_SQL.savedCabinPackage,/item->>'id'=\$3::text/);
 assert.doesNotMatch(SCHEDULE_SQL.savedCabinPackage,/\b(?:INSERT|UPDATE|DELETE|TRUNCATE)\b/i);
 const planner=await readFile(new URL('../website/route-planner.mjs',import.meta.url),'utf8');
 assert.match(planner,/reason\.includes\('CABIN_PACKAGE_NOT_SAVED'\)/);
 assert.match(planner,/Open Flight Services, save the package/);
});

test('existing custom package does not hide a separate route eligibility rejection',async()=>{
 const action={action:'plan-save',airlineId:AIRLINE,
  aircraftInventoryId:'33333333-3333-4333-8333-333333333333',
  flightNumber:'PA400',originAirportKey:'OURAIRPORTS:4610',
  destinationAirportKey:'OURAIRPORTS:4615',
  weeklySchedule:[{day:0,time:'06:00'}],departureStand:'terminal',
  arrivalStand:'terminal',turnaroundMinutes:45,
  fares:{economy:78,premium:null,business:null,first:null},
  service:{onboard:'basic',baggage:'hand-only',cargo:'none',cabinPackageId:'pkg-1'},
  referenceDepartureUtc:null,referenceArrivalUtc:null
 };
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:{id:USER},error:null}),
  database:{connect:async()=>({query:async(sql)=>{
   if(sql===SCHEDULE_SQL.planSave)return {rowCount:0,rows:[]};
   if(sql===SCHEDULE_SQL.savedCabinPackage)
    return {rowCount:1,rows:[{savedPackageExists:true}]};
   throw Error('Unexpected SQL');
  },release:()=>{}})}
 });
 const response=await handler(req(action));
 assert.equal(response.status,409);
 assert.equal((await response.json()).reason,
  'AIRLINE_AIRCRAFT_AIRPORT_OR_FLIGHT_NUMBER_NOT_ELIGIBLE');
});
