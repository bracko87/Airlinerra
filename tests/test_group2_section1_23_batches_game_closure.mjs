import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const get=async p=>readFile(new URL(p,import.meta.url),'utf8');

test('Section1 Group2 uses 23 immutable 50-airport batches with 18 final entries',async()=>{
 const sql=await get('../supabase/migrations/20261110163500_group2_23_fixed_batches_section1_game_completion.sql');
 assert.match(sql,/CREATE TABLE airlinerra_game\.airport_group2_fixed_batch_members_v1/);
 assert.match(sql,/review_batch_50/);
 assert.match(sql,/cohort_review_order-1\)%50\+1/);
 assert.match(sql,/batch_number BETWEEN 1 AND 23/);
 assert.match(sql,/CREATE TRIGGER group2_fixed_batch_members_immutable/);
 assert.match(sql,/CREATE TABLE airlinerra_game\.airport_group2_section1_batch_acceptance_v1/);
 assert.match(sql,/CREATE VIEW airlinerra_game\.airport_group2_section1_batch_completion_v1/);
 assert.match(sql,/CREATE VIEW airlinerra_game\.airport_group2_section1_overall_status_v1/);
 assert.match(sql,/game_complete_estimated/);
 assert.match(sql,/game_complete_airports/);
 assert.match(sql,/airport_name_fallbacks/);
 assert.match(sql,/count\(\*\) FROM airlinerra_game\.airport_group2_section1_batch_acceptance_v1\)<>23/);
});
test('Section1 game-only registry never fabricates source municipalities/GPS or commercial access',async()=>{
 const sql=await get('../supabase/migrations/20261110163500_group2_23_fixed_batches_section1_game_completion.sql');
 assert.match(sql,/CREATE VIEW airlinerra_game\.airport_group2_section1_game_registry_v1/);
 assert.match(sql,/ORIGINAL_REGISTRY_LOCALITY_UNVERIFIED/);
 assert.match(sql,/OFFICIAL_OPERATOR_SERVED_CITY_CANDIDATE_UNVERIFIED/);
 assert.match(sql,/AIRPORT_NAME_GAME_FALLBACK_NOT_REAL_MUNICIPALITY/);
 assert.match(sql,/source_gps_code_missing/);
 assert.match(sql,/UNSOURCED_GAME_ZERO_FALLBACK/);
 assert.match(sql,/false AS independently_source_verified/);
 assert.match(sql,/false AS commercially_admitted/);
 assert.match(sql,/false AS live_flight_authorized/);
 assert.match(sql,/source_verified_complete/);
 assert.match(sql,/commercial_flight_access_enabled/);
 assert.doesNotMatch(sql,/\b(?:INSERT INTO|UPDATE|DELETE FROM)\s+airlinerra_game\.approved_game_airports\b/);
 assert.doesNotMatch(sql,/\b(?:INSERT INTO|UPDATE|DELETE FROM)\s+airlinerra_game\.airport_group2_review_evidence_events_v1\b/);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\.airport_group2_game_profiles_v1\b/);
 assert.doesNotMatch(sql,/SECURITY DEFINER/);
});
test('Five AU corrected game-model timezones never bypass real operational authority',async()=>{
 const sql=await get('../supabase/migrations/20261110163500_group2_23_fixed_batches_section1_game_completion.sql');
 assert.match(sql,/CREATE TABLE airlinerra_game\.airport_group2_section1_game_timezone_overrides_v1/);
 assert.match(sql,/AU_STATE_TIME_RULE_GAME_CORRECTION/);
 assert.match(sql,/rba\.gov\.au\/schedules-events\/daylight-saving\.html/);
 assert.match(sql,/independently_airport_verified boolean NOT NULL DEFAULT false/);
 assert.match(sql,/allowed_for_live_flights boolean NOT NULL DEFAULT false/);
 assert.match(sql,/CREATE OR REPLACE VIEW airlinerra_game\.airport_group2_section1_identity_v1/);
 assert.match(sql,/coalesce\(t\.resolved_game_timezone_iana,g\.timezone_iana\)/);
 assert.match(sql,/CREATE TRIGGER group2_section1_game_timezone_overrides_immutable/);
 assert.match(sql,/REVOKE ALL ON airlinerra_game\.airport_group2_section1_game_timezone_overrides_v1/);
});
test('Section1 per-batch acceptance SQL and docs preserve original group1 and source research',async()=>{
 const sql=await get('../tests/sql/group2_section1_23_batches_game_acceptance.sql');
 const doc=await get('../docs/GROUP2_SECTION1_ALL_23_BATCHES_GAME_COMPLETION_2026-11-10.md');
 for(const marker of [
 'SECTION1_ALL_1118_NOT_COVERED_IN_23_BATCHES',
 'SECTION1_BATCH_SIZE_GAME_COMPLETENESS_INCONSISTENT',
 'SECTION1_FROZEN_ACCEPTANCE_DOES_NOT_MATCH_LIVE_READ_MODEL',
 'SECTION1_UNUSABLE_GAME_RECORD',
 'SECTION1_DUPLICATE_LOOKUP_OR_SOURCE_IDENT',
 'SECTION1_GAME_ESTIMATES_WRONGLY_CLAIMED_SOURCE_VERIFIED',
 'SECTION1_FALSE_COMPLETION_OR_FLIGHT_AUTHORITY',
 'SECTION1_STANDARD_GAME_INTERFACE_STILL_USING_BAD_AU_TIMEZONES',
 'SECTION1_INTERNAL_BATCH_OR_SOURCE_DATA_EXPOSED_TO_PLAYERS',
 'SECTION1_BATCH_ASSIGNMENT_MUTABLE',
 'SECTION1_GROUP1_OR_OPERATIONAL_GATE_CHANGED',
 'ROLLBACK;'])assert.ok(sql.includes(marker),marker);
 assert.match(doc,/Section 1 game-data: CLOSED/);
 assert.match(doc,/Independent source verification: OPEN/);
 assert.match(doc,/23.*fixed batches/i);
 assert.match(doc,/AirlineSim/);
 assert.match(doc,/3,141/);
 assert.match(doc,/1,118/);
});
