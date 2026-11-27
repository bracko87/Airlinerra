// Schema-only clone rehearsal. Never a deployable migration.
// Exact pinned inputs; intentionally defer airport seed DML on empty clone.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const manifest=JSON.parse(readFileSync('docs/aircraft-storage-release-manifest.json','utf8'));
assert.equal(manifest.productionAuthorized,false);
assert.equal(manifest.executionMode,'inventory_only');
const inputs=manifest.groups.flatMap(g=>g.components);
const deferred=[];
const chunks=['BEGIN;','SET LOCAL lock_timeout = \'5s\';','SET LOCAL statement_timeout = \'60s\';'];
for(const c of inputs){
 const bytes=readFileSync(c.path);
 assert.equal(createHash('sha1').update('blob '+bytes.length+'\0').update(bytes).digest('hex'),c.gitBlobSha,c.path);
 let sql=bytes.toString('utf8');
 const name=c.path.split('/').pop();
 // Strip ONLY exact outer transaction markers; never execute COMMIT on clone.
 sql=sql.replace(/^(?:BEGIN|COMMIT|ROLLBACK);\s*$/gm,'');
 if(name==='aircraft_storage_facilities_review.sql'||name==='aircraft_storage_airport_candidate_data_review.sql'){
  const marker=name.includes('candidate_data')?'INSERT INTO airlinerra_game.aircraft_storage_airport_candidate_data_v1 VALUES':'INSERT INTO airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key,admission_scope)';
  assert.equal(sql.split(marker).length,2,name);
  sql=sql.slice(0,sql.indexOf(marker));
  deferred.push(name+': seed and dependent data assertions');
 }else if(name==='aircraft_storage_approved_game_prices_review.sql'){
  deferred.push(name+': data-only staging');continue;
 }else if(name==='aircraft_storage_only_service_profiles_review.sql'){
  const marker='INSERT INTO airlinerra_game.aircraft_storage_only_service_candidates_v1 VALUES';
  const start=sql.indexOf(marker),end=sql.indexOf(';\n',start);
  assert.ok(start>=0&&end>start,name);
  sql=sql.slice(0,start)+sql.slice(end+2);
  deferred.push(name+': service candidate seed');
 }
 chunks.push('\\echo STORAGE_SCHEMA_REHEARSAL '+name,sql);
}
chunks.push(`DO $rehearsal$
BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_billing_classes_v1)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_background_worker_release_v1 WHERE world_id=1 AND NOT movement_enabled AND NOT billing_enabled AND NOT expiry_enabled AND NOT custody_enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_player_automatic_booking_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_booking_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_departure_validation_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_automatic_booking_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_plan_handoff_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_binding_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_plan_retirement_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_combined_booking_history_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_custody_release_policy_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_operational_departure_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_facility_admission_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_game_permission_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_billing_class_release_v1 WHERE world_id=1 AND enabled=false)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE world_id=1 AND NOT execution_enabled AND NOT fuel_adapter_enabled)
 THEN RAISE EXCEPTION 'STORAGE_SCHEMA_REHEARSAL_RELEASE_NOT_DISABLED';END IF;
 RAISE NOTICE 'Storage schema-only rehearsal passed; selected data seeds deferred; release disabled';
END $rehearsal$;
ROLLBACK;`);
const output=chunks.join('\n')+'\n';
assert.equal(output.match(/^BEGIN;$/gm)?.length,1);
assert.equal(output.match(/^ROLLBACK;$/gm)?.length,1);
assert.equal(output.match(/^COMMIT;$/gm)?.length??0,0);
assert.equal(deferred.length,4);
if(process.argv[2]!=='--validate-only'){
 assert.ok(process.argv[2]&&process.argv.length===3,'Private output path required');
 writeFileSync(process.argv[2],output,{mode:0o600,flag:'wx'});
}
console.log('PASS assembled '+(inputs.length-1)+' structural SQL components in one rollback-only transaction; four airport data blocks deferred');
console.log('Schema-only rehearsal does not validate production data, dispatcher runtime behavior or cron installation.');
