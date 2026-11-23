import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {summarizeOwnedBookingWindow} from '../website/section9-booking-window-evidence.mjs';

const scheduleId='11111111-1111-4111-8111-111111111111';
const flight=(overrides={})=>({
 flightDate:'2026-11-24',departureUtc:'2026-11-24T08:00:00.000Z',
 arrivalUtc:'2026-11-24T09:30:00.000Z',bookingStatus:'open',
 capacity:110,bookedSeats:32,reservedTicketRevenueUsd:3200,...overrides
});
const response=(rows=[flight()])=>({
 status:'operating_booking_window',readOnly:true,scheduleId,occurrences:rows
});
const inspect=x=>summarizeOwnedBookingWindow(x,{scheduleId});

test('verified seven-day booking window counts booked and unbooked seats and reserved not settled fares',()=>{
 const result=inspect(response([flight(),flight({
  flightDate:'2026-11-25',departureUtc:'2026-11-25T08:00:00Z',
  arrivalUtc:'2026-11-25T09:30:00Z',bookedSeats:10,reservedTicketRevenueUsd:500
 })]));
 assert.equal(result.rows.length,2);
 assert.equal(result.rows[0].unbookedSeats,78);
 assert.equal(result.totalBooked,42);
 assert.equal(result.totalCapacity,220);
 assert.equal(result.totalReservedRevenueUsd,3700);
 assert.equal(result.rows[0].departureUtc,'2026-11-24T08:00:00.000Z');
 assert.equal(result.readOnly,true);
});
test('empty verified booking window displays no invented reservations',()=>{
 assert.deepEqual(inspect(response([])).rows,[]);
});
test('booking evidence fails closed on untrusted counts money time and schedule identity',()=>{
 const bad=[
  response([flight({bookedSeats:111})]),
  response([flight({bookedSeats:-1})]),
  response([flight({capacity:0})]),
  response([flight({capacity:NaN})]),
  response([flight({reservedTicketRevenueUsd:-100})]),
  response([flight({reservedTicketRevenueUsd:'3200'})]),
  response([flight({departureUtc:'bad date'})]),
  response([flight({arrivalUtc:'2026-11-24T07:00:00Z'})]),
  response([flight({bookingStatus:'<script>'})]),
  response([flight(),flight()]),
  response(Array.from({length:8},(_,i)=>flight({flightDate:'2026-11-24',
   departureUtc:new Date(Date.UTC(2026,10,24,8+i)).toISOString(),
   arrivalUtc:new Date(Date.UTC(2026,10,24,9+i)).toISOString()}))),
  {...response(),readOnly:false},
  {...response(),scheduleId:'22222222-2222-4222-8222-222222222222'},
  {...response(),status:'seven_day_preview_only'},
  {...response(),occurrences:null}
 ];
 for(const sample of bad)assert.equal(inspect(sample),null);
});
test('Route Details displays verified booking evidence and the built player contains it',async()=>{
 const read=path=>readFile(new URL(path,import.meta.url),'utf8');
 const [details,overlay,build]=await Promise.all([
  read('../website/section9-route-details.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),
  read('../website/dev-scripts/verify-built-player-modules.mjs')]);
 assert.match(details,/summarizeOwnedBookingWindow\(reply/);
 assert.match(details,/unbookedSeats/);
 assert.match(details,/reserved fares \(not settled revenue\)/);
 assert.match(overlay,/'section9-booking-window-evidence\.mjs'/);
 assert.match(build,/'section9-booking-window-evidence\.mjs'/);
});
