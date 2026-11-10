import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const get=async p=>readFile(new URL(p,import.meta.url),'utf8');

test('Batch1 has fifty frozen cases and precisely scoped public source notes',async()=>{
 const m=await get('../supabase/migrations/20261110124500_group2_batch1_50_source_desk_review.sql');
 assert.match(m,/cohort_review_order BETWEEN 1 AND 50/);
 assert.match(m,/CREATE TABLE airlinerra_game\.airport_group2_batch1_desk_cases_v1/);
 assert.match(m,/CREATE TABLE airlinerra_game\.airport_group2_batch1_public_source_findings_v1/);
 assert.match(m,/count\(\*\) FROM airlinerra_game\.airport_group2_batch1_desk_cases_v1\)<>50/);
 assert.match(m,/count\(\*\) FROM airlinerra_game\.airport_group2_batch1_public_source_findings_v1\)<>11/);
 assert.match(m,/airports_with_public_source_candidates/);
 assert.match(m,/source_class text NOT NULL DEFAULT 'PUBLIC_PRIMARY_SOURCE_CANDIDATE_NOT_VALIDATED'/);
 assert.match(m,/independent_review_complete boolean NOT NULL DEFAULT false/);
 assert.match(m,/permitted_for_simulation_flight boolean NOT NULL DEFAULT false/);
 assert.match(m,/desk_state='INITIAL_TRIAGE_COMPLETE_INDEPENDENT_REVIEW_PENDING'/);
 assert.match(m,/airport_group2_batch1_case_immutable/);
 assert.match(m,/airport_group2_batch1_findings_immutable/);
});
test('Seven physical runway measurements remain only public candidate claims and two AIP prohibitions stay blocked',async()=>{
 const m=await get('../supabase/migrations/20261110124500_group2_batch1_50_source_desk_review.sql');
 for(const source of [
 'OURAIRPORTS:29801','OURAIRPORTS:27866','OURAIRPORTS:21335',
 'OURAIRPORTS:20581','OURAIRPORTS:3403','OURAIRPORTS:21315',
 'OURAIRPORTS:3436','OURAIRPORTS:29484','OURAIRPORTS:4436'
 ])assert.ok(m.includes(source),source+' source missing');
 for(const issuer of [
 'Austro Control Austria','Airservices Australia','US Federal Aviation Administration',
 'City of Victorville Airport Authority','Mobile Airport Authority',
 'Arkansas Department of Commerce Aviation Division'
 ])assert.ok(m.includes(issuer),issuer+' provenance missing');
 assert.match(m,/source_published_on date/);
 assert.match(m,/currency_or_freshness_warning/);
 assert.match(m,/runway_designator/);
 assert.match(m,/observed_runway_width_m/);
 assert.match(m,/source_class='PUBLIC_PRIMARY_SOURCE_CANDIDATE_NOT_VALIDATED'/);
 assert.doesNotMatch(m,/\bUPDATE\s+airlinerra_game\.airport_group2_game_profiles_v1\b/);
 assert.doesNotMatch(m,/\bINSERT INTO airlinerra_game\.airport_group2_review_evidence_events_v1\b/);
});
test('Rollback acceptance checks game-and-finance isolation and source contradictions',async()=>{
 const t=await get('../tests/sql/group2_batch1_public_source_review_acceptance.sql');
 const doc=await get('../docs/GROUP2_BATCH1_50_DESK_SOURCES_2026-11-10.md');
 for(const check of [
 'BATCH1_CASE_OR_SOURCE_COUNT_INVALID',
 'BATCH1_SOURCE_FINDING_FALSIFIED_OR_NOT_IN_COHORT',
 'BATCH1_SOURCE_CANDIDATE_BYPASSED_CURRENT_GAME_ESTIMATE',
 'BATCH1_PRIVATE_REVIEW_DATA_EXPOSED',
 'BATCH1_SOURCE_FINDINGS_NOT_APPEND_ONLY',
 'BATCH1_CASE_SNAPSHOT_MUTABLE',
 'BATCH1_DESK_REVIEW_UNEXPECTED_COMMERCIAL_RELEASE',
 'ROLLBACK;'
 ])assert.ok(t.includes(check),'missing rollback validation '+check);
 assert.match(doc,/41 cases do not yet have newly located public source/);
 assert.match(doc,/seven original game estimates have deliberately NOT been updated/);
 assert.match(doc,/Batch 1 independent airport reviews are still open/);
});
