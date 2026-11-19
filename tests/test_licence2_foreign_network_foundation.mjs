import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('EU L2 Level 1 has 20 directed routes and other level caps remain unchanged',async()=>{
 const policy=await read('supabase/migrations/20261118105000_licence2_foreign_network_20_directed_routes_policy.sql');
 const design=await read('docs/AIRLINERRA_LICENCE2_FOREIGN_NETWORK_2026-11-17.md');
 const planner=LICENCE_PLAN.find(x=>x.code==='FOREIGN_NETWORK_LICENCE_2');
 for(const [level,limit,category] of [[1,20,'Medium'],[2,50,'Large'],[3,150,'Major Hub']])
  assert.ok(policy.includes("('L2-EU',"+level+','+limit+",'"+category+"',true)"));
 assert.match(policy,/\('L2-EU',4,null,'Mega Hub',true\)/);
 assert.match(design,/\| 1 \| \*\*20\*\*/);
 assert.match(planner.operation.join(' '),/Level 1 = 20, Level 2 = 50, Level 3 = 150, Level 4 = unlimited/);
 assert.doesNotMatch(planner.operation.join(' '),/Level 1 = 10,/);
});
test('US, UK and Japan market levels are prepared but numeric permissions not invented',async()=>{
 const policy=await read('supabase/migrations/20261118105000_licence2_foreign_network_20_directed_routes_policy.sql');
 for(const m of ['L2-EU','L2-US','L2-UK','L2-JP'])assert.ok(policy.includes(m));
 assert.match(policy,/\('L2-US',4,null,null,false\)/);
 assert.match(policy,/\('L2-UK',2,null,null,false\)/);
 assert.match(policy,/\('L2-JP',2,null,null,false\)/);
 assert.match(policy,/issuance_enabled boolean not null default false/);
 assert.match(policy,/enforcement_enabled boolean not null default false/);
 assert.match(policy,/licence2_policy_no_unreviewed_release/);
 assert.match(policy,/primary key\(world_id,airline_id,market_code\)/);
 assert.match(policy,/enable row level security/g);
 assert.match(policy,/revoke all on airlinerra_game\.licence2_airline_market_permits_v1/);
});
test('merged-airport route preview leaves AOC and commercial execution separate',async()=>{
 const classifier=await read('supabase/migrations/20261118113000_licence2_no_permit_route_preview_fail_closed.sql');
 assert.match(classifier,/airport_unified_operations_v1/);
 assert.match(classifier,/L1_HOME_MARKET_ROUTE/);
 assert.match(classifier,/L2_ISSUANCE_NOT_RELEASED/);
 assert.match(classifier,/L2_TARGET_MARKET_SELECTION_REQUIRED_OR_UNAVAILABLE/);
 assert.match(classifier,/L2_ACTIVE_FOREIGN_HUB_NOT_VERIFIED/);
 assert.match(classifier,/L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK/);
 assert.match(classifier,/canActivateFlights',false/);
 assert.match(classifier,/licence2_country_market_v1/);
 assert.doesNotMatch(classifier,/insert into airlinerra_game\.licence2_airline_market_permits_v1/i);
 assert.doesNotMatch(classifier,/update airlinerra_game\.airline_flight_schedule_drafts_v1/i);
});

test('L2 readiness uses existing AOC and aircraft evidence and does not claim invented company maturity',async()=>{
 const s=await read('supabase/migrations/20261118114500_licence2_readonly_application_eligibility.sql');
 for(const phrase of ['section9_aoc_certificates_v1','airline_aircraft_inventory',
  'section9_aoc_safety_incidents_v1','holding_world_clock_v1',
  'COMPANY_90_GAME_DAY_AGE_NOT_VERIFIED',
  'NINETY_DAY_OPERATING_COST_RESERVE_NOT_VERIFIED',
  'CRITICAL_MAINTENANCE_CLEARANCE_NOT_VERIFIED',
  'ACTIVE_OWN_AOC_NOT_VERIFIED','READ_ONLY_PREAPPLICATION_ASSESSMENT']){
  assert.ok(s.includes(phrase),phrase);
 }
 assert.match(s,/rightsGranted',false/);
 assert.match(s,/feeCharged',false/);
 assert.match(s,/revoke all on function airlinerra_game\.licence2_application_readiness_v1/);
});
test('owner draft application is idempotent and cannot be issued or charged as a draft',async()=>{
 const s=await read('supabase/migrations/20261118120500_licence2_owner_application_draft_ledger.sql');
 assert.match(s,/licence2_market_applications_v1/);
 assert.match(s,/licence2_one_open_application_per_market_v1/);
 assert.match(s,/a\.owner_player_id=p_player/);
 assert.match(s,/wm\.state='active'/);
 assert.match(s,/current_user is distinct from 'postgres'/);
 assert.match(s,/LICENCE2_SUBMISSION_REVIEW_APPROVAL_NOT_RELEASED/);
 assert.match(s,/on conflict \(world_id,airline_id,market_code\)/);
 assert.match(s,/feeCharged',false/);
 assert.match(s,/enable row level security/);
 assert.match(s,/revoke all on airlinerra_game\.licence2_market_applications_v1/);
});

test('verified company registration day and reserves never infer eligibility from creation timestamp or raw cash',async()=>{
 const source=await read('supabase/migrations/20261118133000_licence2_verified_company_age_and_financial_reserves.sql');
 const readiness=await read('supabase/migrations/20261118134500_licence2_readiness_consumes_verified_company_and_reserve_evidence.sql');
 assert.match(source,/licence2_company_game_registration_evidence_v1/);
 assert.match(source,/licence2_airline_operating_reserve_evidence_v1/);
 assert.match(source,/registered_game_date/);
 assert.match(source,/projected_daily_operating_cost_usd/);
 assert.match(source,/reserve_days>=90/);
 assert.match(source,/security_invoker=true/);
 assert.match(source,/enable row level security/g);
 assert.match(readiness,/verified_company_game_days/);
 assert.match(readiness,/COMPANY_YOUNGER_THAN_90_GAME_DAYS/);
 assert.match(readiness,/INSUFFICIENT_VERIFIED_NINETY_DAY_OPERATING_RESERVE/);
 assert.match(readiness,/NINETY_DAY_OPERATING_COST_RESERVE_NOT_VERIFIED/);
 assert.doesNotMatch(readiness,/v_age:=null/);
 assert.match(readiness,/rightsGranted',false/);
 assert.match(readiness,/feeCharged',false/);
});
test('directional allocation counts direction once, holds quota lock and blocks release without approvals',async()=>{
 const schema=await read('supabase/migrations/20261118141000_licence2_atomic_directional_route_allocation_boundary.sql');
 const guard=await read('supabase/migrations/20261118142000_licence2_directional_quota_insert_update_guard_fix.sql');
 assert.match(schema,/licence2_directed_route_allocations_v1/);
 assert.match(schema,/primary key\(world_id,airline_id,market_code,origin_airport_key,destination_airport_key\)/);
 assert.match(schema,/licence2_one_active_source_per_directed_pair_v1/);
 assert.match(schema,/allocation_state in \('reserved','active'\)/);
 assert.match(schema,/licence2_market_route_quota_usage_v1/);
 assert.match(schema,/enable row level security/);
 assert.match(guard,/pg_advisory_xact_lock/);
 assert.match(guard,/LICENCE2_ROUTE_ALLOCATION_RELEASE_DISABLED/);
 assert.match(guard,/LICENCE2_VALID_APPROVED_PERMIT_REQUIRED/);
 assert.match(guard,/L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK/);
 assert.match(guard,/LICENCE2_DIRECTED_ROUTE_QUOTA_FULL/);
 assert.match(guard,/if tg_op='INSERT' then/);
 assert.match(guard,/v_used>=v_tier.max_active_directed_routes/);
});

test('licence 2 submission requires fresh owner verified eligibility and never charges at submission',async()=>{
 const sql=await read('supabase/migrations/20261118153000_licence2_verified_submission_no_fee.sql');
 for(const term of ['licence2_submit_owner_application_v1','LICENCE2_PRIVATE_OWNER_SERVICE_ONLY',
  "wm.state='active'","app.owner_player_id=p_player","a.owner_player_id=p_player",
  "v_readiness->>'eligible' is distinct from 'true'",
  'LICENCE2_SUBMISSION_REQUIRES_LIVE_VERIFIED_READINESS',
  'LICENCE2_REVIEW_APPROVAL_NOT_RELEASED',
  'APPLICATION_SUBMITTED_FOR_REVIEW',"feeCharged',false","rightsGranted',false"]){
  assert.ok(sql.includes(term),term);
 }
 assert.match(sql,/for update of app/);
 assert.match(sql,/revoke all on function airlinerra_game\.licence2_submit_owner_application_v1/);
 assert.doesNotMatch(sql,/insert into airlinerra_game\.airline_ledger/i);
 assert.doesNotMatch(sql,/update airlinerra_game\.airlines set cash_usd/i);
});
test('licence 2 uses authoritative paid-correction AOC safety rating and reviewed maintenance evidence',async()=>{
 const sql=await read('supabase/migrations/20261118155500_licence2_verified_aoc_safety_and_maintenance_check.sql');
 const evidence=await read('supabase/migrations/20261118154500_licence2_critical_maintenance_review_evidence.sql');
 assert.match(sql,/section9_aoc_safety_score_v1/);
 assert.match(sql,/licence2_critical_maintenance_clearance_v1/);
 assert.match(sql,/UNRESOLVED_MAINTENANCE_JOB_REQUIRES_REVIEW/);
 assert.match(sql,/CRITICAL_MAINTENANCE_CLEARANCE_NOT_VERIFIED/);
 assert.doesNotMatch(sql,/100-coalesce\(sum\(penalty_points\)/);
 assert.match(evidence,/clearance_reference text not null/);
 assert.match(evidence,/enable row level security/);
 assert.match(evidence,/revoke all on airlinerra_game\.licence2_critical_maintenance_clearance_v1/);
});

test('Licence 2 approval preview requires independently reviewed fees and reconciled real ledger',async()=>{
 const sql=await read('supabase/migrations/20261118164500_licence2_approval_fee_policy_preflight.sql');
 for(const phrase of [
  'licence2_reviewed_fee_policy_v1','application_kind',
  'review_state', 'fee_usd numeric(18,2)', 'processing_game_days',
  'APPROVAL_BLOCKED','LICENCE2_ISSUANCE_PAUSED',
  'FEE_AND_PROCESSING_POLICY_NOT_APPROVED',
  'APPLICATION_NOT_SUBMITTED','PROCESSING_PERIOD_NOT_FINISHED',
  'YEARLY_UPGRADE_WINDOW_NOT_REACHED','ALREADY_HAS_THIS_OR_HIGHER_LEVEL',
  'CURRENT_ELIGIBILITY_NOT_PASSED',
  'CASH_LEDGER_NOT_RECONCILED_OR_FEE_UNSET',
  'INSUFFICIENT_COMPANY_FUNDS_FOR_FEE',
  'FEE_ALREADY_LINKED_TO_APPLICATION',
  'airlinerra_game.airline_ledger',
  'airlinerra_game.licence2_application_readiness_v1'
 ])assert.ok(sql.includes(phrase),phrase);
 assert.match(sql,/revoke all on airlinerra_game\.licence2_reviewed_fee_policy_v1/);
 assert.match(sql,/revoke all on function airlinerra_game\.licence2_approval_preflight_v1/);
 assert.match(sql,/'cashChanged',false/);
 assert.match(sql,/'feeCharged',false/);
 assert.match(sql,/'permitIssued',false/);
 assert.doesNotMatch(sql,/update airlinerra_game\.airlines set cash_usd/i);
 assert.doesNotMatch(sql,/insert into airlinerra_game\.airline_ledger/i);
});

test('Licence 2 fee debit and permit issuance are atomic but production approval remains hard disabled',async()=>{
 const s=await read('supabase/migrations/20261118172000_licence2_dormant_atomic_approval_writer.sql');
 const receipt=await read('supabase/migrations/20261118174000_licence2_atomic_review_event_uniqueness.sql');
 for(const phrase of [
   'licence2_approval_release_v1','licence2_approval_must_remain_disabled_v1',
   'licence2_approve_application_atomic_v1',
   "current_user is distinct from 'postgres'",
   'LICENCE2_APPROVAL_NOT_RELEASED','licence2_approval_preflight_v1',
   'for update of a','for update','ledgerEntryId',
   'airlinerra_game.airline_ledger','EXPENSE','cash_usd=cash_usd-v_fee',
   'fee_posted_ledger_id=v_entry_id','APPROVED_AND_CHARGED_ONCE',
   'revoke all on function airlinerra_game.licence2_approve_application_atomic_v1'
 ])assert.ok(s.includes(phrase),phrase);
 assert.match(receipt,/review_event_id text primary key/);
 assert.match(receipt,/application_id uuid not null unique/);
 assert.match(receipt,/fee_ledger_id bigint not null unique/);
 assert.match(receipt,/insert into airlinerra_game\.licence2_review_event_receipts_v1/);
 assert.match(receipt,/enable row level security/);
 assert.match(receipt,/revoke all on airlinerra_game\.licence2_review_event_receipts_v1/);
 assert.doesNotMatch(s,/approval_enabled\s*=\s*true\s*,/i);
});

test('Licence 2 approved-status transition requires enabled release and matching unique paid review receipt',async()=>{
 const s=await read('supabase/migrations/20261118175500_licence2_approval_trigger_matched_review_receipt.sql');
 assert.match(s,/old.status is distinct from 'submitted'/);
 assert.match(s,/LICENCE2_APPROVAL_NOT_RELEASED/);
 assert.match(s,/licence2_review_event_receipts_v1/);
 assert.match(s,/licence2_airline_market_permits_v1/);
 assert.match(s,/licence2_approval_release_v1/);
 assert.match(s,/receipt.fee_ledger_id=new.fee_posted_ledger_id/);
 assert.match(s,/ledger.entry_kind='EXPENSE'/);
 assert.match(s,/LICENCE2_APPROVAL_MISSING_MATCHED_FEE_RECEIPT_AND_PERMIT/);
 assert.match(s,/LICENCE2_APPROVAL_UNEXPECTEDLY_ACTIVE/);
});

test('Licence 2 owner draft stage does not shadow airline alias with PL/pgSQL record',async()=>{
 const s=await read('supabase/migrations/20261118183000_licence2_owner_draft_record_alias_fix.sql');
 assert.match(s,/declare v_airline record/);
 assert.match(s,/select airline\.id into v_airline from airlinerra_game\.airlines airline/);
 assert.match(s,/airline\.owner_player_id=p_player/);
 assert.doesNotMatch(s,/declare a record/);
 assert.match(s,/on conflict \(world_id,airline_id,market_code\)/);
 assert.match(s,/'submitted',false/);
 assert.match(s,/'feeCharged',false/);
});

test('game-owner approved EU Level 1–4 Licence 2 prices and full-price upgrades remain release gated',async()=>{
 const sql=await read('supabase/migrations/20261118202000_licence2_eu_owner_approved_full_price_fee_matrix.sql');
 for(const needle of ['25000','75000','200000','500000',
  'processing_game_days=3', "market_code='L2-EU'",
  "LICENCE2_EU_REQUIRES_ALL_8_PRICING_ROWS", "review_state='APPROVED'",
  'LICENCE2_FEE_POLICY_MUST_NOT_RELEASE_ISSUANCE']){
  // The release assertion deliberately stays in the migration.
  if(needle==='LICENCE2_FEE_POLICY_MUST_NOT_RELEASE_ISSUANCE'){
   assert.match(sql,/LICENCE2_FEE_POLICY_MUST_NOT_RELEASE_ISSUANCE/);
  }else assert.ok(sql.includes(needle),needle);
 }
 assert.match(sql,/approved_by='Airlinerra game owner/);
 assert.doesNotMatch(sql,/UPDATE airlinerra_game\.airlines SET cash_usd/i);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.airline_ledger/i);
});

test('Licence 2 cannot recognize a dormant AOC certificate as flight permission',async()=>{
 const sql=await read('supabase/migrations/20261118215500_licence2_eligibility_requires_verified_aoc_release.sql');
 assert.match(sql,/section9_aoc_release_policy_v1/);
 assert.match(sql,/rp\.issuance_enabled=true/);
 assert.match(sql,/rp\.flight_enforcement_enabled=true/);
 assert.match(sql,/AOC_RELEASE_NOT_VERIFIED/);
 assert.match(sql,/ACTIVE_OWN_AOC_NOT_VERIFIED/);
 assert.doesNotMatch(sql,/INSERT INTO airlinerra_game\.section9_aoc_certificates_v1/i);
});

test('Licence 2 owner-approved full-price upgrade has no arbitrary 365-game-day cooldown',async()=>{
 const sql=await read('supabase/migrations/20261119093000_licence2_remove_unapproved_upgrade_cooldown.sql');
 assert.match(sql,/application_kind=kind/);
 assert.match(sql,/PROCESSING_PERIOD_NOT_FINISHED/);
 assert.match(sql,/fee_policy\.fee_usd/);
 assert.match(sql,/ALREADY_HAS_THIS_OR_HIGHER_LEVEL/);
 assert.doesNotMatch(sql,/YEARLY_UPGRADE_WINDOW_NOT_REACHED|UPGRADE_HISTORY_NOT_VERIFIED/);
 assert.doesNotMatch(sql,/last_upgrade_game_date\s*<|game_day-existing_permit\.last_upgrade_game_date/);
});

test('atomic Licence 2 payment uses independent verified game day, not raw clock fields',async()=>{
 const sql=await read('supabase/migrations/20261119143500_licence2_atomic_approval_verified_game_day.sql');
 assert.match(sql,/v_game_day:=airlinerra_game\.section9_verified_permission_game_day_v1\(\)/);
 assert.match(sql,/APPROVAL_GAME_DAY_UNVERIFIED/);
 assert.match(sql,/APPROVAL_CASH_LEDGER_BLOCKED/);
 assert.match(sql,/LICENCE2_APPLICATION_STATUS_CHANGED/);
 assert.match(sql,/licence2_review_event_receipts_v1/);
 assert.doesNotMatch(sql,/select confirmed_game_date into v_game_day from airlinerra_game\.holding_world_clock_v1/i);
});

test('signed EU game reviewer only runs after all independent release gates, verified date, approved fee and 3 days',async()=>{
 const sql=await read('supabase/migrations/20261119163500_licence2_private_signed_eu_automatic_review.sql');
 assert.match(sql,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(sql,/licence2_review_due_eu_game_applications_auto_v1/);
 assert.match(sql,/section9_verified_permission_game_day_v1/);
 assert.match(sql,/section9_verified_game_tick_receipts_v1/);
 assert.match(sql,/a\.submitted_game_date<=now_day-3/);
 assert.match(sql,/approval_enabled=true AND/);
 assert.match(sql,/reviewer_integration_verified=true AND fee_ledger_integration_verified=true/);
 assert.match(sql,/market_code='L2-EU' AND issuance_enabled=true/);
 assert.match(sql,/processingGameDays'\)::integer IS DISTINCT FROM 3/);
 for(const fee of ['25000','75000','200000','500000'])
  assert.match(sql,new RegExp('fee<>'+fee));
 assert.match(sql,/licence2_approval_preflight_v1/);
 assert.match(sql,/licence2_approve_application_atomic_v1/);
 assert.match(sql,/licence2_private_auto_review_audit_v1/);
 assert.match(sql,/vault\.create_secret\(/);
 assert.match(sql,/extensions\.hmac\(/);
 assert.match(sql,/pg_try_advisory_xact_lock/);
 assert.match(sql,/airlinerra-licence2-eu-auto-review-v1/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.doesNotMatch(sql,/SET\s+(?:approval_enabled|issuance_enabled|flight_enforcement_enabled)\s*=\s*true/i);
 assert.doesNotMatch(sql,/SECURITY DEFINER/);
});
