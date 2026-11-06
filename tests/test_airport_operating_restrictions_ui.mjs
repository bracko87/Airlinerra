import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {serializeAirportProfile,AIRPORT_PROFILE_SQL} from '../server/airport-profile-service.mjs';
import {summarizeAirportRestrictions,formatAirportRule,safeEvidenceUrl} from '../website/airport-restriction-display.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('all-airport restriction read only joins approved catalog and keeps operational approval false',()=>{
 assert.match(AIRPORT_PROFILE_SQL,/section5_airport_game_restriction_catalog_v1 restriction/);
 assert.match(AIRPORT_PROFILE_SQL,/restriction\.time_rule_details AS precise_time_rule_details/);
 assert.match(AIRPORT_PROFILE_SQL,/restriction\.runway_rule_details AS precise_runway_rule_details/);
 const profile=serializeAirportProfile({
  airport_key:'OURAIRPORTS:2220',airport_name:'Leipzig/Halle',airport_code:'EDDP',
  game_restriction_status:'MANDATORY_GAME_RULES_PRESENT',
  operating_condition_screen:'YES',
  operating_research_note:'Passenger night restriction, cargo exempt.',
  operating_research_source:'https://example.org/airport',
  noise_condition_screen:'YES',
  noise_research_note:'Aircraft-specific and quota rules separately reviewed.',
  structured_time_rule_count:1,enforced_time_rule_count:1,review_time_rule_count:0,
  structured_runway_rule_count:0,enforced_runway_rule_count:0,
  precise_time_rule_details:[{
   code:'LEIPZIG_PASSENGER_ONLY_NIGHT_CLOSURE',kind:'CURFEW_SCHEDULED',
   operation:'both',startLocal:'23:30',endLocal:'05:30',hardBlock:true,
   weekdays:null,aircraftUseTypes:['passenger'],
   activeFrom:null,activeUntil:null,exceptionsExpected:true,
   notes:'Cargo flights not restricted by this rule.',source:'https://example.org/rule'
  }]
 });
 assert.equal(profile.operations.restrictionResearch.enforcedTimeRules,1);
 assert.equal(profile.operations.restrictionResearch.realWorldDispatchApproved,false);
 assert.equal(profile.operations.timeRestrictions[0].gameEnforcement,true);
 assert.deepEqual(profile.operations.timeRestrictions[0].aircraftUseTypes,['passenger']);
 const formatted=summarizeAirportRestrictions(profile);
 assert.equal(formatted.hardCount,1);
 assert.match(formatted.status,/Mandatory/);
 assert.match(formatted.rules[0].detail,/passenger aircraft only/);
 assert.equal(formatted.sources.length,2);
});

test('uncertain research remains visible as a review, never a fabricated mandatory ban',()=>{
 const p=serializeAirportProfile({
  airport_key:'OURAIRPORTS:4001',airport_name:'Bilbao',airport_code:'LEBB',
  game_restriction_status:'RESEARCH_CONDITIONS_REQUIRE_SPECIFIC_RULE_REVIEW',
  operating_condition_screen:'YES',operating_research_note:'PPR extension after service close',
  noise_condition_screen:'NO',
  structured_time_rule_count:1,enforced_time_rule_count:0,review_time_rule_count:1,
  research_still_unstructured:false,
  precise_time_rule_details:[{
    code:'PPR',kind:'PPR_WINDOW',operation:'both',startLocal:'23:30',endLocal:'06:45',
    weekdays:null,hardBlock:false,notes:'Permission required',source:'https://example.org/ppr'
  }]
 });
 const formatted=summarizeAirportRestrictions(p);
 assert.equal(formatted.hardCount,0);
 assert.equal(formatted.reviewCount,1);
 assert.match(formatted.status,/research.*verification/i);
 assert.match(formatted.rules[0].title,/Permission/);
 assert.equal(formatted.realWorldClearance,false);
});
test('runway-specific rules and calendar scope are clear to players',()=>{
 const rule=formatAirportRule({
   kind:'RUNWAY_TIME_CLOSURE',operation:'departure',
   runwayDesignator:'08/26',gameEnforcement:true,
   localStart:'07:30',localEnd:'11:30',
   weekdays:[6],activeFrom:'2026-11-05',activeUntil:'2026-11-30',
   prohibitedChapters:[],notes:'Saturday maintenance',
   source:'https://example.org/source'
 },{runway:true});
 assert.match(rule.title,/Runway 08\/26/);
 assert.match(rule.title,/blocked/i);
 assert.match(rule.detail,/Sat/);
 assert.match(rule.detail,/Valid 2026-11-05 to 2026-11-30/);
 assert.match(rule.detail,/Runway-specific/);
});
test('evidence URL rendering allows HTTPS only, rejecting scripting and unsafe protocols',()=>{
 assert.equal(safeEvidenceUrl('javascript:alert(1)'),null);
 assert.equal(safeEvidenceUrl('http://example.org'),null);
 assert.equal(safeEvidenceUrl('data:text/plain,pwn'),null);
 assert.equal(safeEvidenceUrl('https://example.org/a'),'https://example.org/a');
});
test('player airport profile and route previews display classified evidence without granting dispatch approval',async()=>{
 const [office,route,bundle,edge]=await Promise.all([
   read('../website/airline-airports-office.mjs'),
   read('../website/route-planner.mjs'),
   read('../website/dev-scripts/invited-overlay.mjs'),
   read('../server/airport-profile-edge-entry.ts')
 ]);
 assert.match(office,/airport-profile-operating-rules/);
 assert.match(office,/airport-profile-restriction-sources/);
 assert.match(office,/safeEvidenceUrl/);
 assert.match(office,/summarizeAirportRestrictions/);
 assert.match(route,/Operating conditions need rule verification/);
 assert.match(bundle,/airport-restriction-display\.mjs/);
 assert.match(edge,/serializeAirportProfile/);
 assert.doesNotMatch(office,/href\s*=\s*evidence\.url/);
});
