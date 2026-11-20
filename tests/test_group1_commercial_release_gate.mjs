import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('first Group 1 route release report is strictly read-only',async()=>{
 const sql=await read('tests/sql/section9_group1_commercial_flight_release_gate_readonly.sql');
 const executable=sql.split('\n').filter(line=>!/^\s*--/.test(line)).join('\n');
 assert.match(sql,/OURAIRPORTS:2212/);
 assert.match(sql,/OURAIRPORTS:2218/);
 assert.match(sql,/group1_airport_admission_ready/);
 assert.match(sql,/operationally_authorized/);
 assert.match(sql,/BLOCKED_AIRPORT_ADMISSION/);
 assert.match(sql,/BLOCKED_FLIGHT_ENGINE_AND_FINANCE_RELEASE/);
 assert.match(sql,/RELEASE_FLAGS_PRESENT_STILL_REQUIRES_VERIFIED_OWNER_AIRCRAFT_LICENCE_CERTIFICATES_SLOTS_CREW/);
 assert.doesNotMatch(executable,/\b(?:insert|update|delete|truncate|alter|drop|grant|revoke|create|call)\s+(?:into\s+|table\s+|function\s+)?/i);
});
test('gate uses actual Section 9 activation, trusted execution, finance and fuel release controls',async()=>{
 const sql=await read('tests/sql/section9_group1_commercial_flight_release_gate_readonly.sql');
 for(const name of [
 'section9_activation_release_policy_v1',
 'section9_trusted_execution_release_policy_v1',
 'section9_flight_finance_posting_release_v1',
 'section9_flight_engine_readiness_audit_v1',
 'automatic_flight_and_fuel_settlement_enabled',
 'trusted_flight_execution_release',
 'fuel_transaction_release',
 'section9'
 ])assert.ok(sql.includes(name),name);
});
