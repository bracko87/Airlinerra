import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=()=>readFile(new URL(
 '../supabase/migrations/20261117130000_section9_atomic_certified_pair_ticket_activation_v1.sql',
 import.meta.url),'utf8');

test('cannot be called by clients and refuses releases before any write',async()=>{
 const s=await sql();
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/blocked_operating_or_finance_release/);
 assert.match(s,/v_finance\.release_state IS DISTINCT FROM 'approved'/);
 assert.match(s,/v_execution\.release_state IS DISTINCT FROM 'enabled'/);
 assert.match(s,/v_activation\.release_state IS DISTINCT FROM 'enabled'/);
 assert.match(s,/v_engine\.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true/);
 assert.match(s,/WHERE world_id=1 FOR SHARE/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_commit_certified_pair_and_ticket_inventory_v1/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});
test('pre-approval pair requires two existing, owned, distinct mirrored draft legs',async()=>{
 const s=await sql();
 assert.match(s,/p_out_schedule=p_back_schedule/);
 assert.match(s,/wm\.state='active'/);
 assert.match(s,/WHERE s\.id IN\(p_out_schedule,p_back_schedule\)/);
 assert.match(s,/ORDER BY s\.id FOR UPDATE/);
 assert.match(s,/v_out\.status IS DISTINCT FROM 'draft'/);
 assert.match(s,/v_back\.status IS DISTINCT FROM 'draft'/);
 assert.match(s,/v_out\.origin_airport_key IS DISTINCT FROM v_back\.destination_airport_key/);
 assert.match(s,/v_out\.destination_airport_key IS DISTINCT FROM v_back\.origin_airport_key/);
 assert.match(s,/blocked_pair_stale_or_not_a_return_route/);
});
test('needs real independent signed certifications on both persisted schedule ids',async()=>{
 const s=await sql();
 assert.match(s,/section9_operational_certification_events_v1/);
 assert.match(s,/c\.review_status='certified'/);
 assert.match(s,/e\.action='certify'/);
 assert.match(s,/c\.clearance_type<>'crew_duty'/);
 assert.match(s,/v_signed_count<>10/);
 assert.match(s,/blocked_ten_independent_signed_certifications_missing/);
 assert.match(s,/section9_commit_certified_schedule_activation_v1/);
});
test('verifies owned aircraft, game-only fuel release, simultaneous seats and both fares',async()=>{
 const s=await sql();
 assert.match(s,/v_fleet\.fleet_status IS DISTINCT FROM 'in_service'/);
 assert.match(s,/v_fuel_model\.operational_dispatch_release IS DISTINCT FROM 'RELEASED'/);
 assert.match(s,/v_fuel_model\.financial_settlement_release IS DISTINCT FROM 'RELEASED'/);
 assert.match(s,/v_payload\.simultaneous_passenger_seats/);
 assert.match(s,/v_seats:=least\(1000,/);
 assert.match(s,/section9_route_commercial_plans_v1/);
 assert.match(s,/v_plan_out\.economy_fare_usd<=0/);
 assert.match(s,/v_plan_back\.economy_fare_usd<=0/);
 assert.match(s,/blocked_missing_or_unsupported_commercial_fare/);
});
test('both activations and verified capacities must succeed in one transaction',async()=>{
 const s=await sql();
 assert.match(s,/v_out_activated:=airlinerra_game\.section9_commit_certified_schedule_activation_v1/);
 assert.match(s,/v_back_activated:=airlinerra_game\.section9_commit_certified_schedule_activation_v1/);
 assert.match(s,/SECTION9_PAIR_ACTIVATION_CERTIFICATION_FAILED_FULL_ROLLBACK/);
 assert.match(s,/section9_register_verified_schedule_capacity_v1/);
 assert.match(s,/SECTION9_PAIR_VERIFIED_CAPACITY_FAILED_FULL_ROLLBACK/);
});
test('opens each eligible flight in seven-day inventory but never sells phantom tickets',async()=>{
 const s=await sql();
 assert.match(s,/section9_verified_saleable_departure_window_v1/);
 assert.match(s,/section9_open_verified_game_ticket_occurrence_v1/);
 assert.match(s,/p_game_day\+7/);
 assert.match(s,/v_window->>'withinWindow' IS DISTINCT FROM 'true'/);
 assert.match(s,/SECTION9_PAIR_TICKET_INVENTORY_FAILED_FULL_ROLLBACK/);
 assert.match(s,/SECTION9_PAIR_SEVEN_DAY_BOOKING_WINDOW_INCOMPLETE_FULL_ROLLBACK/);
 assert.match(s,/'outboundSaleableOccurrences',v_opened_out/);
 assert.match(s,/'returnSaleableOccurrences',v_opened_back/);
 assert.match(s,/'ticketsSold',0/);
 assert.match(s,/'flightDeparted',false,'ledgerPosted',false/);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.airline_ledger\b/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.section9_passenger_reservation_batches_v1\b/i);
});
