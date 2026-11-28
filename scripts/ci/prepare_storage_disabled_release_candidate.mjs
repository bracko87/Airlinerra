// Review artifact only. No database connection, credentials or deployment.
// The blocked candidate has the exact tested installation body and final COMMIT,
// but cannot execute until a separate, explicitly authorized release is prepared.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const [previewPath,candidatePath,receiptPath]=process.argv.slice(2);
assert.equal(process.argv.length,5);
const manifest=JSON.parse(readFileSync('docs/aircraft-storage-release-manifest.json','utf8'));
assert.equal(manifest.productionAuthorized,false);
assert.equal(manifest.executionMode,'inventory_only');
const preview=manifest.lastSuccessfulInstallationPreview;
const persistent=manifest.lastSuccessfulPersistentInstallation;
assert.ok(preview&&persistent);
assert.equal(persistent.productionAuthorized,false);
assert.equal(persistent.committedOnDisposableClone,true);
assert.equal(persistent.persistedAcrossConnections,true);
assert.equal(persistent.repeatInstallationRejected,true);
assert.equal(persistent.registryPreserved,true);
assert.equal(persistent.repeatStructuralFingerprintUnchanged,true);
assert.equal(persistent.components,62);
assert.equal(persistent.disabledControlRecords,18);
assert.equal(persistent.verifiedPreviewSha256,preview.sha256);
const digest=b=>createHash('sha256').update(b).digest('hex');
const bytes=readFileSync(previewPath);
assert.equal(digest(bytes),preview.sha256,'Preview differs from persistent-installation evidence');
const sql=bytes.toString('utf8');
assert.ok(sql.startsWith('BEGIN;\n')&&sql.endsWith('\nROLLBACK;\n'));
assert.equal(sql.match(/^BEGIN;$/gm)?.length,1);
assert.equal(sql.match(/^ROLLBACK;$/gm)?.length,1);
assert.equal(sql.match(/^COMMIT;$/gm)?.length??0,0);
assert.ok(sql.includes('STORAGE_SCHEMA_REHEARSAL storage_candidate_existing_registry_preflight.sql'));
assert.ok(!sql.includes('STORAGE_SCHEMA_REHEARSAL candidate_registry_fixture.sql'));
const body=sql.slice('BEGIN;\n'.length,-'ROLLBACK;\n'.length);
const block="DO $authorization$\nBEGIN\n RAISE EXCEPTION 'STORAGE_PRODUCTION_INSTALLATION_NOT_AUTHORIZED';\nEND $authorization$;\n";
const output='-- BLOCKED RELEASE CANDIDATE. Not an authorized migration. Do not execute.\n'
 +'-- Persistent disposable rehearsal: '+persistent.runId+'\n'
 +'-- Verified rollback preview SHA-256: '+preview.sha256+'\n'
 +'\\set ON_ERROR_STOP on\nBEGIN;\n'+block+body+'COMMIT;\n';
assert.equal(output.match(/^BEGIN;$/gm)?.length,1);
assert.equal(output.match(/^COMMIT;$/gm)?.length,1);
assert.equal(output.match(/^ROLLBACK;$/gm)?.length??0,0);
const receipt={status:'blocked_pending_explicit_production_installation_authorization',productionAuthorized:false,
 persistentInstallationRun:persistent.runId,persistentInstallationCommit:persistent.commit,
 verifiedPreviewSha256:preview.sha256,installationBodySha256:digest(body),blockedCandidateSha256:digest(output),
 components:62,airportCandidates:9,serviceCandidates:6,billingProposals:271,disabledControlRecords:18,
 excludes:['synthetic_registry_inserts','commercial_runway_correction','facility_approval','billing_class_activation','scheduler_installation','application_deployment'],
 execution:'none',next:'Separate authorization and reviewed production execution boundary required; do not remove the block manually.'};
writeFileSync(candidatePath,output,{mode:0o600,flag:'wx'});
writeFileSync(receiptPath,JSON.stringify(receipt,null,2)+'\n',{mode:0o600,flag:'wx'});
console.log('PASS blocked disabled-installation candidate assembled from exact persistent rehearsal input; SHA-256 '+receipt.blockedCandidateSha256);
