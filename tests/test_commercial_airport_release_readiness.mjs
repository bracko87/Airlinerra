import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('Group 2 readiness audit is read-only, distinguishes simulation from actual release',async()=>{
 const sql=await read('tests/sql/airlinerra_group2_commercial_release_readiness_readonly.sql');
 const executable=sql.split('\n').filter(x=>!/^\s*--/.test(x)).join('\n');
 assert.doesNotMatch(executable,/\b(?:insert|update|delete|truncate|alter|drop|grant|revoke|call|create)\s+(?:into\s+|table\s+|function\s+|policy\s+)?/i);
 assert.match(sql,/airport_group2_simulation_admissions_v1/);
 assert.match(sql,/airport_group2_operational_releases_v1/);
 assert.match(sql,/airport_group2_admission_readiness_v1/);
 assert.match(sql,/airport_player_game_roster_v1/);
 assert.match(sql,/NOT_READY_FOR_BLANKET_COMMERCIAL_RELEASE/);
 assert.match(sql,/HARD_HOLD_DOCUMENTED_PROHIBITION/);
 assert.match(sql,/EVIDENCE_INCOMPLETE_NOT_PLAYABLE/);
});
test('commercial-readiness notes preserve known prohibited airports and block unsafe release',async()=>{
 const doc=await read('docs/AIRLINERRA_COMMERCIAL_FLIGHT_READINESS_2026-11-20.md');
 assert.match(doc,/OURAIRPORTS:29484/);
 assert.match(doc,/OURAIRPORTS:4436/);
 assert.match(doc,/SECTION6_GROUP2_NOT_YET_ADMITTED/);
 assert.match(doc,/1,116/);
 assert.match(doc,/operationally_authorized/);
 assert.match(doc,/exactly-once airline financial settlement/);
 assert.match(doc,/Do not fabricate verification events or blanket-authorize/);
});
