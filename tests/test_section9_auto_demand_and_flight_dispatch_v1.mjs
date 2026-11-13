import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const demand='supabase/migrations/20261113230000_section9_automatic_game_market_passenger_demand_v1.sql';
const maintenance='supabase/migrations/20261113231000_section9_hourly_game_maintenance_dispatch_clearance_v1.sql';
const dispatch='supabase/migrations/20261113232000_section9_private_signed_operated_flight_dispatch_v1.sql';

test('demand uses existing market and makes its assumptions explicit',async()=>{
 const s=await read(demand);
 assert.match(s,/section9_route_market_preview_v1/);
 assert.match(s,/GAME_ONLY_PASSENGER_CAPTURE_V1/);
 assert.match(s,/SECTION7_GAME_ESTIMATE_NOT_REAL_WORLD_BOOKINGS/);
 assert.match(s,/capture_rate numeric:=0\.35/);
 assert.match(s,/reference_fare:=greatest/);
 assert.match(s,/fullWindowTargetSeats/);
 assert.match(s,/actualAirlineCompetitionModeled',false/);
 assert.match(s,/realWorldDemandVerified',false/);
});
test('automated bookings share inventory with connecting holds and never double-book',async()=>{
 const s=await read(demand);
 assert.match(s,/progress_target-inv\.passengers_held/);
 assert.match(s,/inv\.passenger_capacity-inv\.passengers_held/);
 assert.match(s,/passengers_held<occ\.booked_seats/);
 assert.match(s,/section9_verified_saleable_departure_window_v1/);
 assert.match(s,/FOR UPDATE/);
 assert.match(s,/section9_reserve_verified_game_passenger_seats_v1/);
 assert.match(s,/pg_try_advisory_xact_lock\(583729,10031\)/);
 assert.match(s,/return jsonb_build_object\('status','blocked_flight_operation_release'/i);
 assert.match(s,/'ledgerPosted',false/);
 assert.doesNotMatch(s,/INSERT INTO airlinerra_game\.airline_ledger/i);
});
test('automated booking runs idempotently in private cron without browser privileges',async()=>{
 const s=await read(demand);
 assert.match(s,/book_key:='auto\.demand\.v1\.'/);
 assert.match(s,/EXISTS\(SELECT 1[\s\S]*section9_passenger_reservation_batches_v1/);
 assert.match(s,/WHERE jobname='airlinerra-game-route-passenger-demand-v1'/);
 assert.match(s,/'\*\/5 \* \* \* \*'/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});
test('game dispatch maintenance blocks due daily checks and projected hour threshold crossing',async()=>{
 const s=await read(maintenance);
 assert.match(s,/section9_owned_game_maintenance_due_v1/);
 assert.match(s,/MAINTENANCE_CHECK_DUE_/);
 assert.match(s,/MAINTENANCE_HOUR_LIMIT_BEFORE_ARRIVAL_/);
 assert.match(s,/tracked_flight_hours\+flight_hours/);
 assert.match(s,/MAINTENANCE_JOB_OVERLAP_OR_UNPAID/);
 assert.match(s,/gameMaintenanceClear',cardinality\(blocked\)=0/);
 assert.match(s,/realWorldAirworthinessVerified',false/);
 assert.match(s,/dispatchApproved',false/);
});
test('event signer verifies a real canonical HMAC before operating releases',async()=>{
 const s=await read(dispatch);
 assert.match(s,/vault\.create_secret/);
 assert.match(s,/extensions\.gen_random_bytes\(48\)/);
 assert.match(s,/vault\.decrypted_secrets/);
 assert.match(s,/SECTION9_MOVEMENT_EVENT_SIGNATURE_INVALID/);
 assert.match(s,/v_expected_sig IS DISTINCT FROM p_verified_hmac/);
 assert.match(s,/airlinerra-operated-game-event-v1/);
 const signatureIndex=s.indexOf('SECTION9_MOVEMENT_EVENT_SIGNATURE_INVALID');
 const releaseIndex=s.indexOf('blocked_unreleased_movement_engine');
 assert.ok(signatureIndex>=0&&releaseIndex>signatureIndex);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
});
test('dispatcher requires certification, issued game permits, slots, maintenance and arrival proof',async()=>{
 const s=await read(dispatch);
 assert.match(s,/section9_schedule_activation_preparations_v1/);
 assert.match(s,/certification_count<5/);
 assert.match(s,/AIRPORT_SLOTS_NOT_RESERVED/);
 assert.match(s,/ISSUED_OPERATOR_GAME_LICENCE_MISSING/);
 assert.match(s,/ISSUED_ROUTE_GAME_RIGHTS_MISSING/);
 assert.match(s,/section9_verified_game_maintenance_dispatch_window_v1/);
 assert.match(s,/ARRIVAL_WITHOUT_VERIFIED_DEPARTURE/);
 assert.match(s,/section9_operated_day_candidates_for_aircraft_v1/);
 assert.match(s,/section9_record_signed_operated_flight_movement_v1/);
});
test('real departure closes passenger sales in the same transaction',async()=>{
 const s=await read(dispatch);
 assert.match(s,/UPDATE airlinerra_game\.section9_dated_flight_occurrences_v1/);
 assert.match(s,/SET booking_status='closed'/);
 assert.match(s,/SECTION9_DEPARTURE_BOOKING_CLOSE_UNCONFIRMED_ROLLBACK/);
 assert.match(s,/SECTION9_AUTOMATIC_DISPATCH_MOVEMENT_NOT_CONFIRMED_ROLLBACK/);
 assert.match(s,/pg_try_advisory_xact_lock\(583729,10041\)/);
 assert.match(s,/WHERE jobname='airlinerra-game-operated-flight-dispatch-v1'/);
 assert.match(s,/'\* \* \* \* \*'/);
 assert.match(s,/'ticketRevenueRecognized',false,'ledgerPosted',false/);
 assert.doesNotMatch(s,/INSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});
