import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const get=async p=>readFile(new URL(p,import.meta.url),'utf8');

test('Section1 pass2 adds 21 primary served-city and seven official airport elevations, never canonical overwrites',async()=>{
 const s=await get('../supabase/migrations/20261110151000_group2_section1_official_localities_elevations.sql');
 const values=s.slice(s.indexOf('VALUES\n'),s.indexOf('CREATE VIEW'));
 assert.equal((values.match(/'served_city'/g)||[]).length,21);
 assert.equal((values.match(/'elevation_reference'/g)||[]).length,7);
 assert.equal((values.match(/'OURAIRPORTS:/g)||[]).length,28);
 assert.match(s,/source_kind<>'AIRLINESIM_THIRD_PARTY_SIMULATION'/);
 assert.match(s,/airports_with_primary_served_city_candidate/);
 assert.match(s,/published_elevation_candidates/);
 assert.match(s,/missing_locality_without_primary_candidate/);
 assert.match(s,/independently_approved_corrections/);
 assert.match(s,/section1_verified_complete/);
 assert.match(s,/commercial_flights_authorized/);
 for(const a of ['OURAIRPORTS:27013','OURAIRPORTS:27138','OURAIRPORTS:26568','OURAIRPORTS:26651','OURAIRPORTS:26671'])
  assert.ok(s.includes(a));
 assert.doesNotMatch(s,/INSERT INTO airlinerra_game\.approved_game_airports/);
 assert.doesNotMatch(s,/UPDATE airlinerra_game\.airport_group2_game_profiles_v1/);
 assert.doesNotMatch(s,/INSERT INTO airlinerra_game\.airport_group2_review_evidence_events_v1/);
});
test('Five DST mismatches are source-backed, private, not marked verified or applied to game clock',async()=>{
 const s=await get('../supabase/migrations/20261110152000_group2_section1_timezone_rule_conflicts.sql');
 assert.match(s,/CREATE TABLE airlinerra_game\.airport_group2_section1_timezone_correction_candidates_v1/);
 assert.match(s,/CREATE VIEW airlinerra_game\.airport_group2_section1_timezone_discrepancy_v1/);
 for(const k of ['OURAIRPORTS:27110','OURAIRPORTS:26990','OURAIRPORTS:27094','OURAIRPORTS:27125','OURAIRPORTS:27011'])
  assert.ok(s.includes(k),'missing timezone case '+k);
 assert.match(s,/2026-11-10 12:00:00\+00/);
 assert.match(s,/2026-06-10 12:00:00\+00/);
 assert.match(s,/SOURCE_GAME_TIMEZONE_ICA_/i.test(s)?/source_game_timezone_iana/:/source_game_timezone_iana/);
 assert.match(s,/applied_to_canonical_game_profile boolean NOT NULL DEFAULT false/);
 assert.match(s,/authority_verified_for_flight_schedule boolean NOT NULL DEFAULT false/);
 assert.match(s,/ENABLE ROW LEVEL SECURITY/);
 assert.match(s,/REVOKE ALL ON airlinerra_game\.airport_group2_section1_timezone_correction_candidates_v1/);
 assert.doesNotMatch(s,/SECURITY DEFINER|UPDATE airlinerra_game\.airport_group2_game_profiles_v1/);
});
test('Source acceptance distinguishes 24 locality candidates, 17 unresolved, zero certified and unchanged 3141 original airports',async()=>{
 const s=await get('../tests/sql/group2_section1_locality_timezone_source_acceptance.sql');
 for(const marker of ['GROUP2_S1_PUBLIC_SOURCE_COUNT_WRONG',
  'GROUP2_S1_STILL_UNRESOLVED_GAPS_WERE_LOST',
  'GROUP2_S1_SIMULATION_SOURCE_PROMOTED',
  'GROUP2_S1_TIMEZONE_ESTIMATE_REPLACED_BY_CANDIDATE',
  'GROUP2_S1_5_MATERIAL_TIMEZONE_ERRORS_NOT_DETECTED',
  'GROUP2_S1_SOURCE_PRIVATE_RLS_BYPASS',
  'GROUP2_S1_SOURCE_RESEARCH_CHANGED_WORLD_OR_FLIGHTS','ROLLBACK;'])
  assert.ok(s.includes(marker),'missing required test '+marker);
 const doc=await get('../docs/GROUP2_SECTION1_LOCALITIES_ELEVATION_TIMEZONES_2026-11-10.md');
 assert.match(doc,/\*\*24\*\*/);
 assert.match(doc,/\*\*17\*\*/);
 assert.match(doc,/Group 1 \(3,141\)/);
 assert.match(doc,/Section 1 is NOT closed/);
 assert.match(doc,/AirlineSim remains secondary/);
});
