import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=()=>readFile(new URL(
 '../supabase/migrations/20261117131000_section9_two_phase_roundtrip_certification_queue_v1.sql',
 import.meta.url),'utf8');

test('internal two-phase pair has durable unique draft IDs, status and no player access',async()=>{
 const s=await sql();
 assert.match(s,/section9_private_roundtrip_certification_queue_v1/);
 assert.match(s,/pair_key uuid PRIMARY KEY/);
 assert.match(s,/outbound_schedule_id uuid NOT NULL UNIQUE/);
 assert.match(s,/return_schedule_id uuid NOT NULL UNIQUE/);
 assert.match(s,/awaiting_independent_certification/);
 assert.match(s,/approval_start_game_date date NOT NULL/);
 assert.match(s,/ENABLE ROW LEVEL SECURITY/);
 assert.match(s,/REVOKE ALL ON TABLE airlinerra_game\.section9_private_roundtrip_certification_queue_v1/);
});
test('stage is private and requires real issued AOC and both traffic directions',async()=>{
 const s=await sql();
 assert.match(s,/SECTION9_PRIVATE_CERTIFICATION_QUEUE_TRUSTED_GAME_SERVER_ONLY/);
 assert.match(s,/section9_owned_roundtrip_launch_readiness_v1/);
 assert.match(s,/v_launch->>'operatorLicenceValid' IS DISTINCT FROM 'true'/);
 assert.match(s,/v_launch->>'outboundGameTrafficRightValid' IS DISTINCT FROM 'true'/);
 assert.match(s,/v_launch->>'returnGameTrafficRightValid' IS DISTINCT FROM 'true'/);
 assert.match(s,/v_launch->>'aircraftGamePositionVerified' IS DISTINCT FROM 'true'/);
 assert.match(s,/blocked_issued_permissions_or_route_preview/);
 assert.match(s,/'licenceFeeCharged',false/);
});
test('only one trusted and idempotent request can save both draft schedules and zero-charge fares',async()=>{
 const s=await sql();
 assert.match(s,/v_request_md5:=md5\(jsonb_build_object\(/);
 assert.match(s,/SECTION9_CERTIFICATION_REQUEST_REPLAY_CONFLICT/);
 assert.match(s,/section6_save_owned_aircraft_schedule_with_slots_v1/);
 assert.match(s,/SECTION9_CERTIFICATION_PAIR_SCHEDULE_OR_SLOT_NOT_SAVED_ROLLBACK/);
 assert.match(s,/section9_save_owned_commercial_plan_v1/);
 assert.match(s,/v_out_id,p_out_fare_usd,0,0/);
 assert.match(s,/v_back_id,p_back_fare_usd,0,0/);
 assert.match(s,/SECTION9_CERTIFICATION_PAIR_FARE_SAVE_FAILED_ROLLBACK/);
 assert.match(s,/'operatingRouteCreated',false/);
 assert.match(s,/'ticketsOpened',0,'ticketSalesAvailable',false/);
});
test('staged pair completion calls atomic signed activation, then marks active in same transaction',async()=>{
 const s=await sql();
 assert.match(s,/section9_finish_staged_certified_roundtrip_v1/);
 assert.match(s,/section9_commit_certified_pair_and_ticket_inventory_v1/);
 assert.match(s,/outboundSaleableOccurrences/);
 assert.match(s,/returnSaleableOccurrences/);
 assert.match(s,/SET status='activated',activated_at=clock_timestamp\(\)/);
 assert.match(s,/SECTION9_PAIR_STATE_UPDATE_FAILED_FULL_ROLLBACK/);
 assert.match(s,/certification_pair_waiting_for_independent_approvals/);
 assert.match(s,/certified_roundtrip_operating_inventory_committed/);
});
test('bounded scheduler cannot activate any staged route while releases are paused',async()=>{
 const s=await sql();
 assert.match(s,/section9_auto_finish_certified_roundtrip_batch_v1/);
 assert.match(s,/blocked_certification_activation_release/);
 assert.match(s,/p_limit NOT BETWEEN 1 AND 50/);
 assert.match(s,/pg_try_advisory_xact_lock\(583732,10051\)/);
 assert.match(s,/SECTION9_CERTIFICATION_BATCH_UNKNOWN_RESULT_ROLLBACK/);
 assert.match(s,/airlinerra-game-certified-roundtrip-finalizer-v1/);
 assert.match(s,/'2,7,12,17,22,27,32,37,42,47,52,57 \* \* \* \*'/);
});
test('no signed approvals, fuel spend or live tickets fabricated by staging',async()=>{
 const s=await sql();
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.section9_operational_certification_events_v1/i);
 assert.doesNotMatch(s,/\bINSERT INTO airlinerra_game\.section9_passenger_reservation_batches_v1/i);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});
