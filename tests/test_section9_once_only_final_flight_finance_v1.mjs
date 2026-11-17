import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const sql=()=>readFile(new URL(
 '../supabase/migrations/20261117095000_section9_once_only_final_flight_finance_guarded_v1.sql',
 import.meta.url),'utf8');

test('finance release is paused by default and never changes existing fuel model release',async()=>{
 const s=await sql();
 assert.match(s,/section9_flight_finance_posting_release_v1/);
 assert.match(s,/release_state text NOT NULL DEFAULT 'paused'/);
 assert.match(s,/VALUES\(1,'paused'\) ON CONFLICT\(world_id\) DO NOTHING/);
 assert.match(s,/v_policy\.release_state IS DISTINCT FROM 'approved'/);
 assert.match(s,/v_schedule\.financial_settlement_release IS DISTINCT FROM 'RELEASED'/);
 assert.match(s,/v_schedule\.operational_dispatch_release IS DISTINCT FROM 'RELEASED'/);
 assert.match(s,/v_readiness\.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true/);
 assert.doesNotMatch(s,/UPDATE airlinerra_game\.section9_game_fuel_model_snapshot_v1/);
});
test('approved costs require fuel reserve plus separately verified airport fee items',async()=>{
 const s=await sql();
 assert.match(s,/section9_flight_final_cost_approvals_v1/);
 assert.match(s,/approval_state text NOT NULL DEFAULT 'unapproved'/);
 assert.match(s,/fuel_reserve_verified=true AND fuel_reserve_kg>0/);
 assert.match(s,/length\(fuel_source_reference\)>=16/);
 assert.match(s,/length\(tariff_source_reference\)>=16/);
 assert.match(s,/section9_final_cost_fee_itemization_v1/);
 assert.match(s,/v_approved\.airport_navigation_cost_usd/);
 assert.match(s,/SECTION9_FINAL_AIRPORT_FEE_NEGATIVE_OR_OVERLIMIT/);
});
test('independent movement checker recomputes both HMAC signatures before money',async()=>{
 const s=await sql();
 assert.match(s,/section9_verify_operated_flight_hmac_pair_v1/);
 assert.match(s,/airlinerra-operated-game-event-v1/);
 assert.match(s,/vault\.decrypted_secrets/);
 assert.match(s,/extensions\.hmac/);
 assert.match(s,/expected IS DISTINCT FROM row_event\.event_hmac_sha256/);
 assert.match(s,/checked<>2/);
 assert.match(s,/SECTION9_SIGNED_MOVEMENT_VERIFICATION_PRIVATE_ONLY/);
 assert.match(s,/v_signatures->>'signatureVerified' IS DISTINCT FROM 'true'/);
 assert.match(s,/blocked_unverified_signed_flight_movement/);
});
test('one completed flight posts revenue and expense within same transaction and updates cash',async()=>{
 const s=await sql();
 assert.match(s,/section9_post_completed_flight_finance_once_v1/);
 assert.match(s,/pg_try_advisory_xact_lock/);
 assert.match(s,/FROM airlinerra_game\.section9_actual_ticket_finance_preparations_v1/);
 assert.match(s,/FROM airlinerra_game\.section9_flight_final_cost_approvals_v1/);
 assert.match(s,/FROM airlinerra_game\.section9_route_posted_flight_financials_v1/);
 assert.match(s,/SECTION9_POSTED_FLIGHT_REPLAY_PROOF_CONFLICT/);
 assert.match(s,/complete_game_flight_finance_already_posted/);
 assert.match(s,/section9_postarrival_ticket_reconciliation_v1/);
 assert.match(s,/INSERT INTO airlinerra_game\.airline_ledger\(airline_id,entry_kind,amount_usd\)/);
 assert.match(s,/VALUES\(v_airline\.id,'REVENUE',v_total_revenue\)/);
 assert.match(s,/VALUES\(v_airline\.id,'EXPENSE',-v_total_expense\)/);
 assert.match(s,/UPDATE airlinerra_game\.airlines\s+SET cash_usd=cash_usd\+v_net/);
 assert.match(s,/SECTION9_FLIGHT_CASH_BALANCE_CHANGED_ROLLBACK/);
 assert.match(s,/INSERT INTO airlinerra_game\.section9_route_posted_flight_financials_v1/);
});
test('wallet reconciliation refuses drift and never allows negative cash',async()=>{
 const s=await sql();
 assert.match(s,/FROM airlinerra_game\.airlines a\s+WHERE a\.id=v_prepared\.airline_id FOR UPDATE/);
 assert.match(s,/coalesce\(sum\(l\.amount_usd\),0\)/);
 assert.match(s,/v_airline\.cash_usd IS DISTINCT FROM v_ledger_balance/);
 assert.match(s,/blocked_cash_ledger_reconciliation/);
 assert.match(s,/v_airline\.cash_usd\+v_net<0/);
 assert.match(s,/blocked_insufficient_flight_settlement_funds/);
 assert.match(s,/AND cash_usd=v_airline\.cash_usd AND cash_usd\+v_net>=0/);
 assert.match(s,/v_total_revenue>0 THEN/);
});
test('crew excluded and maintenance / ownership are not double-charged in flight ledger',async()=>{
 const s=await sql();
 assert.match(s,/crew_cost_usd numeric\(16,2\) NOT NULL DEFAULT 0 CHECK\(crew_cost_usd=0\)/);
 assert.match(s,/maintenance_cost_usd numeric\(16,2\) NOT NULL DEFAULT 0 CHECK\(maintenance_cost_usd=0\)/);
 assert.match(s,/ownership_cost_usd numeric\(16,2\) NOT NULL DEFAULT 0 CHECK\(ownership_cost_usd=0\)/);
 assert.match(s,/v_approved\.maintenance_cost_usd<>0/);
 assert.match(s,/v_approved\.ownership_cost_usd<>0/);
 assert.match(s,/crewIncluded',false,'maintenanceRecharged',false/);
});
test('automatic final settlement is bounded, idempotent and harmless until released',async()=>{
 const s=await sql();
 assert.match(s,/section9_auto_post_complete_game_flights_v1/);
 assert.match(s,/p_limit NOT BETWEEN 1 AND 100/);
 assert.match(s,/NOT EXISTS\(\s*SELECT 1 FROM airlinerra_game\.section9_route_posted_flight_financials_v1 done/);
 assert.match(s,/a\.approval_state='approved'/);
 assert.match(s,/blocked_unreleased_final_finance_job/);
 assert.match(s,/SECTION9_UNEXPECTED_GAME_FINANCE_POSTING_RESULT_ROLLBACK/);
 assert.match(s,/WHERE jobname='airlinerra-game-approved-final-flight-finance-v1'/);
 assert.match(s,/'8,18,28,38,48,58 \* \* \* \*'/);
});
test('no direct anonymous, authenticated or service-role mutation rights',async()=>{
 const s=await sql();
 assert.match(s,/ALTER TABLE airlinerra_game\.section9_flight_final_cost_approvals_v1 ENABLE ROW LEVEL SECURITY/);
 assert.match(s,/ALTER TABLE airlinerra_game\.section9_flight_finance_posting_release_v1 ENABLE ROW LEVEL SECURITY/);
 assert.match(s,/REVOKE ALL ON TABLE airlinerra_game\.section9_flight_final_cost_approvals_v1/);
 assert.match(s,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_post_completed_flight_finance_once_v1/);
 assert.match(s,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.doesNotMatch(s,/SECURITY DEFINER/i);
});


test('approved finance evidence rejects missing references and incomplete airport fees',async()=>{
 const s=await sql();
 assert.match(s,/section9_finance_release_needs_real_reference_v2/);
 assert.match(s,/section9_final_cost_approval_evidence_required_v2/);
 assert.match(s,/coalesce\(length\(approval_reference\),0\)>=20/);
 assert.match(s,/coalesce\(length\(fuel_source_reference\),0\)>=16/);
 assert.match(s,/coalesce\(length\(tariff_source_reference\),0\)>=16/);
 assert.match(s,/section9_final_cost_required_all_fee_lines_v2/);
 assert.match(s,/airport_fee_lines \?& ARRAY\[/);
 assert.match(s,/section9_final_cost_no_negative_fee_items_v2/);
});
