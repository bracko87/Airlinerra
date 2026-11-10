import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const get=async filename=>readFile(new URL(filename,import.meta.url),'utf8');

test('Group2 has six source gates with commercial passenger/cargo checked independently',async()=>{
 const sql=await get('../supabase/migrations/20261110120000_group2_independent_source_admission_gates.sql');
 for(const gate of [
  'identity_and_location','current_paved_runway','civilian_access',
  'aircraft_and_facilities','operating_restrictions','commercial_service_permission'
 ])assert.ok(sql.includes(gate),'missing '+gate);
 assert.match(sql,/g\.game_traffic_type IN\('Passenger','Both'\)/);
 assert.match(sql,/g\.game_traffic_type IN\('Cargo','Both'\)/);
 assert.match(sql,/6830/);
 assert.match(sql,/review_batch_50/);
 assert.match(sql,/\/50\+1/);
 assert.match(sql,/REVOKE ALL ON airlinerra_game\.airport_group2_required_reviews_v1/);
});
test('No browser writer, auto admission, or World1/finance mutation exists in Group2 migration',async()=>{
 const sql=await get('../supabase/migrations/20261110120000_group2_independent_source_admission_gates.sql');
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/GROUP2_EVIDENCE_GATE_NOT_APPLICABLE/);
 assert.match(sql,/GROUP2_EVIDENCE_APPEND_ONLY_USE_NEW_REVIEW_EVENT/);
 assert.match(sql,/source_effective_on/);
 assert.match(sql,/reviewer_reference/);
 assert.match(sql,/HARD_HOLD_DOCUMENTED_PROHIBITION/);
 assert.match(sql,/READY_FOR_SEPARATE_OWNER_RELEASE_REVIEW/);
 assert.match(sql,/'canJoinWorld1',false,'canActivateFlights',false/);
 assert.match(sql,/false AS can_activate_flights/);
 assert.doesNotMatch(sql,/\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+(?:airlinerra_game\.approved_game_airports|airlinerra_game\.airline_ledger|public\.airlinerra_game_worlds)\b/);
 assert.doesNotMatch(sql,/GRANT\s+(?:SELECT|INSERT|UPDATE|DELETE)\s+ON[^\n]+TO\s+(?:anon|authenticated)/);
 assert.doesNotMatch(sql,/SECURITY DEFINER/);
});
test('Group2 SQL regression verifies current evidence/permissions cannot release flights',async()=>{
 const sql=await get('../tests/sql/group2_independent_admission_gate_acceptance.sql');
 const doc=await get('../docs/GROUP2_RESEARCH_AND_ADMISSION_PLAN_2026-11-10.md');
 for(const s of ['1118','6830','23','3141','HARD_HOLD_DOCUMENTED_PROHIBITION',
 'GROUP2_UNREVIEWED_CANDIDATE_RELEASED','WITHDRAWN_EVIDENCE_NOT_REVOKED',
 'APPEND_ONLY_EVIDENCE_WAS_EDITABLE','ROLLBACK;'])
  assert.ok(sql.includes(s),'test missing '+s);
 assert.match(doc,/Batch 1: 50 airports/);
 assert.match(doc,/Group 1 remains closed/);
});
