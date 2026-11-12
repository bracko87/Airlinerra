import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const src=()=>readFile(new URL(
 '../supabase/migrations/20261112164500_section9_phase1_no_crew_still_signed_five_certificates.sql',
 import.meta.url),'utf8');
test('Phase 1 crew defer is explicit, reversible and never disables commercial release',async()=>{
 const sql=await src();
 assert.match(sql,/ADD COLUMN IF NOT EXISTS crew_mode text NOT NULL DEFAULT 'deferred_phase1'/);
 assert.match(sql,/CHECK \(crew_mode IN \('deferred_phase1','required'\)\)/);
 assert.match(sql,/crew_deferred:=coalesce\(control_row\.crew_mode,'required'\)='deferred_phase1'/);
 assert.match(sql,/required_certificate_count:=CASE WHEN crew_deferred THEN 5 ELSE 6 END/);
 assert.match(sql,/control_row\.release_state IS DISTINCT FROM 'enabled'/);
 assert.match(sql,/control_row\.enabled_at IS NULL/);
 assert.match(sql,/control_row\.reviewed_at IS NULL/);
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.section9_activation_release_policy_v1\s+SET\s+release_state\s*=\s*'enabled'/i);
 assert.doesNotMatch(sql,/INSERT\s+INTO\s+airlinerra_game\.section9_schedule_operational_certifications_v1/i);
 assert.doesNotMatch(sql,/INSERT\s+INTO\s+airlinerra_game\.section9_operated_flight_movements_v1/i);
 assert.doesNotMatch(sql,/INSERT\s+INTO\s+airlinerra_game\.section9_route_posted_flight_financials_v1/i);
});
test('five independent certs remain signed, version-fenced, non-crew and time-valid',async()=>{
 const sql=await src();
 assert.match(sql,/c\.clearance_type<>'crew_duty'/);
 assert.match(sql,/c\.schedule_version=p_expected_version/);
 assert.match(sql,/c\.review_status='certified'/);
 assert.match(sql,/c\.valid_from_game_date<=p_game_date/);
 assert.match(sql,/c\.valid_to_game_date>=p_game_date\+p_days/);
 assert.match(sql,/c\.last_verified_event_id IS NOT NULL/);
 assert.match(sql,/e\.action='certify'/);
 assert.match(sql,/c\.source_kind=e\.source_kind|e\.source_kind=c\.source_kind/);
 assert.match(sql,/IF certificate_count<>required_certificate_count/);
 assert.match(sql,/FIVE_NON_CREW_OPERATIONAL_CERTIFICATIONS_MISSING/);
 assert.match(sql,/OPERATOR_GAME_LICENCE_SIGNED_PROOF_STALE/);
 assert.match(sql,/ROUTE_GAME_RIGHTS_SIGNED_PROOF_STALE/);
});
test('crew is skipped only in deferred mode; all other checks remain mandatory',async()=>{
 const sql=await src();
 assert.match(sql,/IF NOT crew_deferred AND checklist->>'proposedCrewAssignmentsComplete'/);
 assert.match(sql,/IF NOT crew_deferred AND checklist->>'crewRestPreviewConflictFree'/);
 for(const blocker of [
  'AIRPORT_RESTRICTIONS_NOT_CLEARED',
  'AIRCRAFT_ROTATION_NOT_CLEARED',
  'SCHEDULED_SLOTS_NOT_RECORDED',
  'AIRCRAFT_DELIVERY_NOT_VERIFIED',
  'AIRCRAFT_LOCATION_NOT_GROUNDED',
  'LICENCE_AND_ROUTE_EVIDENCE_MISSING',
  'GAME_CLOCK_NOT_CONNECTED',
  'TURNAROUND_POLICY_NOT_CLEARED',
  'SLOT_RESERVATION_MISMATCH',
  'AIRPORT_SLOT_CAPACITY_CHANGED',
  'COMMERCIAL_ACTIVATION_ADMIN_RELEASE_MISSING'
 ])assert.ok(sql.includes(blocker),blocker);
 assert.match(sql,/section9_owned_commercial_activation_preflight_v1/);
 assert.match(sql,/section6_weekly_slot_preflight_v1/);
 assert.match(sql,/fingerprint_md5/);
 assert.match(sql,/requiredCertifications',required_certificate_count/);
 assert.match(sql,/crewMode',CASE WHEN crew_deferred THEN 'deferred_phase1'/);
 assert.match(sql,/flightActivated',false/);
 assert.match(sql,/bookingsCreated',false/);
 assert.match(sql,/ledgerPosted',false/);
});
