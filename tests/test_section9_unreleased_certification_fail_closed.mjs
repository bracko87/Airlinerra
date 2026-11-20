import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=()=>readFile(new URL(
 '../supabase/migrations/20261120211500_section9_unreleased_execution_finance_certification_fail_closed.sql',
 import.meta.url),'utf8');

test('future trusted execution and finance certifications fail closed in the actual private sink',async()=>{
 const s=await read();
 assert.match(s,/pg_get_functiondef\(p\.oid\)/);
 assert.match(s,/section9_record_verified_certification_event_v1/);
 assert.match(s,/SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION/);
 assert.match(s,/ERRCODE='42501'/);
 assert.match(s,/EXECUTE replace\(definition,old_block,new_block\)/);
 assert.match(s,/SECTION9_CERTIFICATION_SINK_UNEXPECTED_DEFINITION_ABORTED/);
 assert.match(s,/SECTION9_CERTIFICATION_SINK_AMBIGUOUS_REPLACEMENT/);
 assert.match(s,/FROM PUBLIC,anon,authenticated,service_role/);
 const failOpen=s.indexOf('eligible:=true;');
 const replace=s.indexOf('old_block:=');
 assert.ok(failOpen>replace,'fail-open string appears only as old replacement target');
 assert.match(s,/new_block:=\$new\$[\s\S]*RAISE EXCEPTION USING ERRCODE='42501'/);
});
test('the patch does not set flight operation, booking, licence or finance releases',async()=>{
 const s=await read();
 assert.doesNotMatch(s,/\bUPDATE\s+airlinerra_game\./i);
 assert.doesNotMatch(s,/\bINSERT\s+INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(s,/\bALTER\s+TABLE\b/i);
 assert.doesNotMatch(s,/\bGRANT\s+EXECUTE\b/i);
});
