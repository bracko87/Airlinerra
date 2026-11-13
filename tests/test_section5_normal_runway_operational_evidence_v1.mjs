import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('Belgrade official AIP identifies routine and alternate runway without live clearance',async()=>{
 const sql=await read('supabase/migrations/20261113204000_section5_belgrade_normal_runway_procedural_evidence.sql');
 assert.match(sql,/smatsa\.rs\/upload\/vfraip\/published\/pdf\/amdt\/VFR_LY_Amdt_A_2026_02_en\.pdf/);
 assert.match(sql,/OFFICIAL_AIP_NORMAL_RUNWAY_USE/);
 assert.match(sql,/'246233'::text,'open_reported_unverified'::text/);
 assert.match(sql,/'506930'::text,'restricted_reported_unverified'::text/);
 assert.match(sql,/r\.runway_designator='12L\/30R'/);
 assert.match(sql,/r\.runway_designator='12R\/30L'/);
 assert.match(sql,/ON CONFLICT\(world_id,airport_key,source_runway_id\) DO NOTHING/);
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.airport_runway_inventory/i);
 assert.doesNotMatch(sql,/operational_status\s*=\s*'operational'/i);
});

test('universal airport gate prefers documented routine runway over longer conditional alternate',async()=>{
 const sql=await read('supabase/migrations/20261113205000_section5_prefer_sourced_normal_main_runway.sql');
 assert.match(sql,/CREATE OR REPLACE FUNCTION airlinerra_game\.section5_universal_airport_leg_restriction_v1/);
 assert.match(sql,/LEFT JOIN airlinerra_game\.airport_runway_source_status_evidence normal_use/);
 assert.match(sql,/normal_use\.evidence_provenance LIKE 'OFFICIAL_AIP_NORMAL_RUNWAY_USE:%'/);
 assert.match(sql,/WHEN 'open_reported_unverified' THEN 1/);
 assert.match(sql,/WHEN 'restricted_reported_unverified' THEN -1/);
 assert.match(sql,/i\.length_m DESC/);
 assert.match(sql,/chosen\.normal_use_reported_status='restricted_reported_unverified'/);
 assert.match(sql,/'alternateRunwayNeedsMainClosureEvidence'/);
 assert.match(sql,/'selectedRunwayNormalUseEvidence'/);
 assert.match(sql,/'runwayOperationalStatusVerified',chosen\.operational_status='operational'/);
 assert.match(sql,/'canActivateNormalFlight',false/);
 assert.match(sql,/'realWorldDispatchApproved',false/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});
