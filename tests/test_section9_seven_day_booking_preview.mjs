import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFlightScheduleHandler,validateFlightSchedulePayload,
 SCHEDULE_SQL,FLIGHT_SCHEDULE_API_ROUTE
} from '../server/flight-schedule-service.mjs';
import {SEVEN_DAY_WINDOW_SQL} from '../server/section9-seven-day-window.mjs';
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
