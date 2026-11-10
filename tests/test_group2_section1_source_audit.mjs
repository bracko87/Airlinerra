import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const get=async path=>readFile(new URL(path,import.meta.url),'utf8');

test('Group2 Section1 source chain uses primary operator evidence and limited AirlineSim fallback',async()=>{
 const m=await get('../supabase/migrations/20261110141000_group2_section1_primary_airlinesim_source_audit.sql');
 assert.match(m,/CREATE TABLE airlinerra_game\.airport_group2_section1_source_candidates_v1/);
 assert.match(m,/CREATE VIEW airlinerra_game\.airport_group2_section1_identity_quality_v1/);
 assert.match(m,/CREATE VIEW airlinerra_game\.airport_group2_section1_progress_v1/);
 assert.match(m,/OFFICIAL_AIRPORT_OPERATOR/);
 assert.match(m,/AIRLINESIM_THIRD_PARTY_SIMULATION/);
 assert.match(m,/SIMULATION_COMPARISON_ONLY/);
 assert.match(m,/source_kind='AIRLINESIM_THIRD_PARTY_SIMULATION'/);
 assert.match(m,/identity_field IN \('iata_reference','icao_reference'\)/);
 assert.match(m,/section1_source_candidates_immutable/);
 assert.match(m,/ENABLE ROW LEVEL SECURITY/);
 assert.match(m,/REVOKE ALL ON airlinerra_game\.airport_group2_section1_source_candidates_v1/);
 assert.match(m,/independently_authority_verified boolean NOT NULL DEFAULT false/);
 assert.match(m,/may_replace_game_profile boolean NOT NULL DEFAULT false/);
 assert.match(m,/operational_or_commercial_authority boolean NOT NULL DEFAULT false/);
});
test('Group2 Section1 proposal references have exact airport identity and exclude game-only airport activation',async()=>{
 const m=await get('../supabase/migrations/20261110141000_group2_section1_primary_airlinesim_source_audit.sql');
 for(const key of ['OURAIRPORTS:26916','OURAIRPORTS:27866',
  'OURAIRPORTS:26969','OURAIRPORTS:27069','OURAIRPORTS:27152'])
  assert.ok(m.includes(key),'missing source-proposed airport '+key);
 for(const url of [
  'https://www.ballarat.vic.gov.au/Airport',
  'https://www.ashburton.wa.gov.au/community/shire-facilities/onslow-airport.aspx',
  'https://www.wdrc.qld.gov.au/Services-Payments/Aerodromes-Aircraft-Landing-Areas',
  'https://paine.airlinesim.aero/action/info/county?id=10'
 ])assert.ok(m.includes(url),'missing reproducible source URL '+url);
 for(const term of ['source_municipalities_missing','missing_city_with_primary_candidate',
  'missing_city_without_primary_candidate','source_gps_codes_missing',
  'game_timezones_not_authority_verified','game_zero_elevation_fallbacks',
  'airlinesim_field_comparisons','authority_verified_section1_airports'])
  assert.ok(m.includes(term),'missing Section1 quality metric '+term);
 assert.doesNotMatch(m,/\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+(?:airlinerra_game\.approved_game_airports|airlinerra_game\.airline_ledger|airlinerra_game\.airport_group2_game_profiles_v1|airlinerra_game\.airport_group2_review_evidence_events_v1)\b/);
});
test('Section1 acceptance forbids AirlineSim municipality certification and false source completion',async()=>{
 const sql=await get('../tests/sql/group2_section1_source_fallback_acceptance.sql');
 const doc=await get('../docs/GROUP2_SECTION1_IDENTITY_AIRLINESIM_FALLBACK_2026-11-10.md');
 for(const must of ['1118','41','38','2','11',
  'SECTION1_AIRLINESIM_CITY_GATE_BYPASS',
  'SECTION1_SOURCE_GAPS_HIDDEN_OR_FABRICATED',
  'SECTION1_RESEARCH_WAS_MUTABLE','SECTION1_FALLBACK_CHANGED_PLAYABLE_GAME_STATE',
  'ROLLBACK;'])assert.ok(sql.includes(must),'missing audit safeguard '+must);
 assert.match(doc,/one section at a time/i);
 assert.match(doc,/AirlineSim/);
 assert.match(doc,/Section 1 stays open/);
 assert.match(doc,/Section 2/);
 assert.match(doc,/Group 1.*3,141/);
});
