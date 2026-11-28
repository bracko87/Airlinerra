// Disposable clone test only. Never generate a production migration.
// Preserve every verified preview statement; remove only the final ROLLBACK.
// The local runner supplies COMMIT separately in its explicitly local session.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const [previewPath,bodyPath,assertionsPath]=process.argv.slice(2);
assert.equal(process.argv.length,5);
const manifest=JSON.parse(readFileSync('docs/aircraft-storage-release-manifest.json','utf8'));
assert.equal(manifest.productionAuthorized,false);
assert.equal(manifest.executionMode,'inventory_only');
const receipt=manifest.lastSuccessfulInstallationPreview;
assert.equal(receipt.scope,'rollback_only_existing_registry_preview_on_private_schema_clone_with_minimal_local_fixture');
assert.equal(receipt.productionAuthorized,false);
const bytes=readFileSync(previewPath);
assert.equal(createHash('sha256').update(bytes).digest('hex'),receipt.sha256,'Verified preview digest mismatch');
const sql=bytes.toString('utf8');
assert.equal(sql.match(/^BEGIN;$/gm)?.length,1);
assert.equal(sql.match(/^ROLLBACK;$/gm)?.length,1);
assert.equal(sql.match(/^COMMIT;$/gm)?.length??0,0);
assert.ok(sql.startsWith('BEGIN;\n')&&sql.endsWith('\nROLLBACK;\n'));
assert.ok(sql.includes('STORAGE_SCHEMA_REHEARSAL storage_candidate_existing_registry_preflight.sql'));
assert.ok(!sql.includes('STORAGE_SCHEMA_REHEARSAL candidate_registry_fixture.sql'));
const guard=`DO $local_only$
BEGIN
 IF current_database() IS DISTINCT FROM 'postgres' OR current_user IS DISTINCT FROM 'postgres'
 OR to_regclass('pg_temp.storage_disposable_commit_witness') IS NULL
 THEN RAISE EXCEPTION 'STORAGE_DISPOSABLE_COMMIT_SESSION_REQUIRED';END IF;
 IF (SELECT count(*) FROM pg_temp.storage_disposable_commit_witness WHERE backend_pid=pg_backend_pid())<>1
 THEN RAISE EXCEPTION 'STORAGE_DISPOSABLE_COMMIT_WITNESS_MISMATCH';END IF;
END $local_only$;
`;
const body=sql.slice(0,-'ROLLBACK;\n'.length).replace('BEGIN;\n','BEGIN;\n'+guard);
const start=sql.lastIndexOf('DO $rehearsal$\n');
const end=sql.lastIndexOf('END $rehearsal$;');
assert.ok(start>0&&end>start);
const assertions=sql.slice(start,end+'END $rehearsal$;'.length)+'\n';
assert.equal(body.match(/^COMMIT;$/gm)?.length??0,0);
assert.equal(body.match(/^ROLLBACK;$/gm)?.length??0,0);
writeFileSync(bodyPath,body,{mode:0o600,flag:'wx'});
writeFileSync(assertionsPath,assertions,{mode:0o600,flag:'wx'});
console.log('PASS exact verified rollback preview digest; prepared transaction body for local session only (no COMMIT in file)');
