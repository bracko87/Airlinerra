import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const hour='supabase/migrations/20261113222000_section9_verified_berlin_game_hour_v1.sql';
const apply='supabase/migrations/20261113223000_section9_hour_accurate_tickets_and_movement_enforcement_v1.sql';

test('World 1 verified hour is Berlin-synced and fails closed on missing producer proof',async()=>{
 const sql=await read(hour);
 assert.match(sql,/section9_verified_berlin_game_hour_v1/);
 assert.match(sql,/AT TIME ZONE 'Europe\/Berlin'/);
 assert.match(sql,/clock_row\.confirmed_game_date=date_berlin/);
 assert.match(sql,/producer\.producer_status='enabled'/);
 assert.match(sql,/receipt\.game_date=date_berlin/);
 assert.match(sql,/receipt\.event_hmac_sha256 ~ '\^\[a-f0-9\]\{64\}\$'/);
 assert.match(sql,/last_verified_at BETWEEN midnight_berlin/);
 assert.match(sql,/authoritativeGameHourAvailable/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(sql,/'movementRecorded',false/);
});
test('same-day future departures allowed only for verified exact flight time',async()=>{
 const sql=await read(apply);
 assert.match(sql,/section9_verified_saleable_departure_window_v1/);
 assert.match(sql,/expected_utc>p_hour_utc/);
 assert.match(sql,/expected_utc<=p_hour_utc\+interval '7 days'/);
 assert.match(sql,/AT TIME ZONE flight\.timezone_iana/);
 assert.match(sql,/invalid_weekly|weekly_item/);
 assert.match(sql,/section9_verified_berlin_game_hour_v1/);
 assert.match(sql,/p_local_date<verified_date/);
 assert.match(sql,/blocked_departure_past_or_beyond_seven_days/);
 assert.doesNotMatch(sql,/p_local_date<=verified_date/);
});
test('every successful ticket opening and booking is tied to the current game hour',async()=>{
 const sql=await read(apply);
 assert.match(sql,/section9_open_verified_game_ticket_occurrence_v1/);
 assert.match(sql,/section9_reserve_verified_game_passenger_seats_v1/);
 assert.match(sql,/section9_open_verified_ticket_window_batch_v1/);
 const uses=(sql.match(/section9_verified_saleable_departure_window_v1/g)||[]).length;
 assert.ok(uses>=4);
 assert.match(sql,/game_day::timestamp,\(game_day\+7\)::timestamp/);
 assert.match(sql,/paid_upfront,recognized_revenue_usd/);
 assert.match(sql,/'reserved',false,0/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
});
test('signed movement writer refuses the wrong hour or disabled engine',async()=>{
 const sql=await read(apply);
 assert.match(sql,/section9_record_signed_operated_flight_movement_v1/);
 assert.match(sql,/SECTION9_TRUSTED_MOVEMENT_ENGINE_ONLY/);
 assert.match(sql,/blocked_unverified_game_hour/);
 assert.match(sql,/blocked_unreleased_movement_engine/);
 assert.match(sql,/fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'/);
 assert.match(sql,/p_event_utc>\(hour_proof->>'gameHourUtc'\)::timestamptz/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
});
