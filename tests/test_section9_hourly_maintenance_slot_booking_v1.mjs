import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql = () => readFile(
 new URL('../supabase/migrations/20261117090000_section9_hourly_maintenance_slot_and_booking_v1.sql', import.meta.url),
 'utf8');

test('maintenance can be booked between flights, not blocked by all active schedules',async()=>{
 const s=await sql();
 assert.match(s,/section9_owned_hourly_maintenance_slot_preflight_v1/);
 assert.match(s,/section9_owned_game_maintenance_job_v1/);
 assert.match(s,/slot_proof:=airlinerra_game\.section9_owned_hourly_maintenance_slot_preflight_v1/);
 assert.match(s,/slot_proof->>'slotClear' IS DISTINCT FROM 'true'/);
 assert.doesNotMatch(s,/IF EXISTS\(SELECT 1 FROM airlinerra_game\.airline_flight_schedule_drafts_v1 s/);
 assert.match(s,/status='active'/);
 assert.match(s,/overlappingRecurringFlights/);
 assert.match(s,/overlappingDatedFlights/);
});

test('aircraft owner, activated capacity, IANA timezone, DST and ground minutes checked',async()=>{
 const s=await sql();
 assert.match(s,/a\.owner_player_id=p_player/);
 assert.match(s,/m\.state='active'/);
 assert.match(s,/schedule_row\.operationally_verified IS DISTINCT FROM true/);
 assert.match(s,/capacity_version IS DISTINCT FROM schedule_row\.version/);
 assert.match(s,/pg_catalog\.pg_timezone_names/);
 assert.match(s,/blocked_ambiguous_or_nonexistent_flight_time/);
 assert.match(s,/section9_game_turnaround_policy_v1/);
 assert.match(s,/total_buffer_min:=greatest\(45,turnaround_min\)/);
 assert.match(s,/schedule_row\.reference_arrival_utc-schedule_row\.reference_departure_utc/);
});

test('maintenance conflict formula respects precise times and buffer',async()=>{
 const s=await sql();
 assert.match(s,/departure_utc<p_end_utc\+make_interval\(mins=>total_buffer_min\)/);
 assert.match(s,/arrival_utc>p_start_utc-make_interval\(mins=>total_buffer_min\)/);
 // Illustrative time fixtures: flight 09:00–10:00, with 45 min buffer.
 const conflict=(start,end,departure,arrival,buffer=45)=>
  departure<end+buffer*60000 && arrival>start-buffer*60000;
 const at=t=>Date.parse('2026-11-17T'+t+':00Z');
 assert.equal(conflict(at('07:00'),at('08:15'),at('09:00'),at('10:00')),false);
 assert.equal(conflict(at('07:00'),at('08:16'),at('09:00'),at('10:00')),true);
 assert.equal(conflict(at('10:45'),at('11:45'),at('09:00'),at('10:00')),false);
 assert.equal(conflict(at('10:44'),at('11:45'),at('09:00'),at('10:00')),true);
 assert.equal(conflict(at('07:00'),at('08:30'),at('09:00'),at('10:00'),55),true);
});

test('all sensitive maintenance operations remain private and no billing happens in preflight',async()=>{
 const s=await sql();
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_owned_hourly_maintenance_slot_preflight_v1/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_owned_game_maintenance_job_v1/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
 assert.match(s,/'ledgerPosted',false/);
 // Old service cost checks must remain intact.
 assert.match(s,/game_maintenance_insufficient_funds/);
 assert.match(s,/maintenance_airport_capabilities_v1/);
 assert.match(s,/aircraft_already_booked_for_maintenance/);
});
