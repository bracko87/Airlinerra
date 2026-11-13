import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const path='supabase/migrations/20261113220000_section9_verified_game_passenger_ticket_bookings_v1.sql';

test('existing non-saleable rows stay non-saleable; booked seats never exceed verified capacity',async()=>{
 const source=await read(path);
 assert.match(source,/source_kind='verified_schedule_preview_not_saleable' AND\s+booking_status='not_open' AND booked_seats=0/);
 assert.match(source,/booked_seats BETWEEN 0 AND coalesce\(verified_passenger_seats,0\)/);
 assert.match(source,/source_kind='game_verified_saleable_schedule_v1'/);
 assert.match(source,/reservation_status IN \('unissued','reserved','cancelled'\)/);
 assert.match(source,/recognized_revenue_usd/);
});
test('seven-day ticket opening requires verified game day and operating approvals',async()=>{
 const source=await read(path);
 assert.match(source,/section9_open_verified_game_ticket_occurrence_v1/);
 assert.match(source,/p_local_date<=verified_date/);
 assert.match(source,/p_local_date>verified_date\+7/);
 assert.match(source,/section9_verified_permission_game_day_v1/);
 assert.match(source,/section9_trusted_execution_release_policy_v1/);
 assert.match(source,/automatic_flight_and_fuel_settlement_enabled/);
 assert.match(source,/section9_initialize_verified_occurrence_v1/);
 assert.match(source,/SECTION9_TICKET_CAPACITY_PROOF_CHANGED/);
 assert.match(source,/section9_operated_flight_movements_v1/);
 assert.match(source,/section9_dated_flight_occurrences_v1/);
 assert.match(source,/ON CONFLICT\(schedule_id,flight_local_date,weekly_entry\) DO NOTHING/);
 assert.match(source,/section9_game_turnaround_policy_v1/);
 assert.match(source,/t.max_seats>=s.passenger_seats/);
 assert.match(source,/greatest\(45,min_ground_minutes\)/);
 assert.match(source,/sevenDayWindowVerified',true/);
});
test('passenger booking is atomic, idempotent, and cannot overbook',async()=>{
 const source=await read(path);
 assert.match(source,/section9_reserve_verified_game_passenger_seats_v1/);
 assert.match(source,/WHERE o\.id=p_occurrence FOR UPDATE OF o/);
 assert.match(source,/WHERE b\.occurrence_id=p_occurrence AND b\.reservation_key=p_reservation_key\s+FOR UPDATE/);
 assert.match(source,/SECTION9_PASSENGER_RESERVATION_REPLAY_MISMATCH/);
 assert.match(source,/capacity\.passenger_capacity-capacity\.passengers_held/);
 assert.match(source,/SECTION9_PASSENGER_CAPACITY_CHANGED_CONCURRENTLY/);
 assert.match(source,/SET passengers_held=passengers_held\+p_seats/);
 assert.match(source,/SET booked_seats=booked_seats\+p_seats/);
 assert.match(source,/game_passenger_seats_reserved/);
 assert.match(source,/reservation_status,paid_upfront,recognized_revenue_usd/);
 assert.match(source,/'reserved',false,0/);
});
test('booking is restricted to trusted game scheduler, economy only, no upfront charge',async()=>{
 const source=await read(path);
 assert.match(source,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(source,/p_fare_class IS DISTINCT FROM 'economy'/);
 assert.match(source,/p_seats NOT BETWEEN 1 AND 1000/);
 assert.match(source,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_open_verified_game_ticket_occurrence_v1[\s\S]*FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(source,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_reserve_verified_game_passenger_seats_v1[\s\S]*FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(source,/SE(CURITY)?\s+INVOKER/);
 assert.doesNotMatch(source,/\bINSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(source,/\bUPDATE airlinerra_game\.airlines/i);
 assert.doesNotMatch(source,/paid_upfront,true/);
});


test('game ticket scheduler only opens verified flights 1-7 days ahead and is a harmless no-op while disabled',async()=>{
 const sql=await read('supabase/migrations/20261113221000_section9_verified_ticket_window_batch_scheduler_v1.sql');
 assert.match(sql,/section9_open_verified_ticket_window_batch_v1/);
 assert.match(sql,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(sql,/section9_verified_permission_game_day_v1/);
 assert.match(sql,/automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true/);
 assert.match(sql,/generate_series\(\s*\(game_day\+1\)::timestamp,\(game_day\+7\)::timestamp/);
 assert.match(sql,/section9_open_verified_game_ticket_occurrence_v1/);
 assert.match(sql,/WHERE jobname='airlinerra-game-ticket-window-v1'/);
 assert.match(sql,/cron\.schedule\(/);
 assert.match(sql,/NOT EXISTS \(/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.doesNotMatch(sql,/\bINSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(sql,/\bUPDATE airlinerra_game\.airlines/i);
});
