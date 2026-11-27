// Schema-only or minimal candidate-data clone rehearsal. Never a deployable migration.
// Exact pinned inputs; intentionally defer airport seed DML on empty clone.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const manifest=JSON.parse(readFileSync('docs/aircraft-storage-release-manifest.json','utf8'));
assert.equal(manifest.productionAuthorized,false);
assert.equal(manifest.executionMode,'inventory_only');
const inputs=manifest.groups.flatMap(g=>g.components);
const deferred=[];
const includeCandidateData=process.argv[3]==='--include-candidate-data';
assert.ok(process.argv.length===3 || (process.argv.length===4 && includeCandidateData),'Expected output or --validate-only, optional --include-candidate-data');
const chunks=['BEGIN;','SET LOCAL lock_timeout = \'5s\';','SET LOCAL statement_timeout = \'60s\';'];
if(includeCandidateData) chunks.push('\\echo STORAGE_SCHEMA_REHEARSAL candidate_registry_fixture.sql',readFileSync('tests/sql/storage_candidate_registry_fixture.sql','utf8'));
for(const c of inputs){
 const bytes=readFileSync(c.path);
 assert.equal(createHash('sha1').update('blob '+bytes.length+'\0').update(bytes).digest('hex'),c.gitBlobSha,c.path);
 let sql=bytes.toString('utf8');
 const name=c.path.split('/').pop();
 // Strip ONLY exact outer transaction markers; never execute COMMIT on clone.
 sql=sql.replace(/^(?:BEGIN|COMMIT|ROLLBACK);\s*$/gm,'');
 if(includeCandidateData) { /* Keep all candidate-only data blocks; gates stay disabled. */ }
 else if(name==='aircraft_storage_facilities_review.sql'||name==='aircraft_storage_airport_candidate_data_review.sql'){
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
 IF ${includeCandidateData?`(SELECT count(*) FROM airlinerra_game.aircraft_storage_facilities_v1)<>9
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_candidate_data_v1)<>9
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_only_service_candidates_v1)<>6
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE airport_key='OURAIRPORTS:19330' OR review_state<>'candidate' OR reactivation_allowed OR dismantling_allowed OR monthly_regional_usd IS DISTINCT FROM 4000::numeric OR monthly_narrowbody_usd IS DISTINCT FROM 8000::numeric OR monthly_widebody_usd IS DISTINCT FROM 15000::numeric)
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.storage_facility_final_reviews_v1)
 OR (SELECT count(*) FROM airlinerra_game.storage_billing_class_candidates_v1)<>271
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 f WHERE airlinerra_game.aircraft_storage_airport_admission_v1(f.airport_key,'storage_inbound')->>'eligible' IS DISTINCT FROM 'false' OR airlinerra_game.aircraft_storage_airport_admission_v1(f.airport_key,'storage_reactivation')->>'eligible' IS DISTINCT FROM 'false')`:'EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1)'}
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
 RAISE NOTICE 'Storage rehearsal passed; ${includeCandidateData?'nine priced candidates, six service candidates and 271 billing proposals; no activation':'selected data seeds deferred; release disabled'}';
END $rehearsal$;
ROLLBACK;`);
const output=chunks.join('\n')+'\n';
assert.equal(output.match(/^BEGIN;$/gm)?.length,1);
assert.equal(output.match(/^ROLLBACK;$/gm)?.length,1);
assert.equal(output.match(/^COMMIT;$/gm)?.length??0,0);
assert.equal(deferred.length,includeCandidateData?0:4);
if(process.argv[2]!=='--validate-only'){
 assert.ok(process.argv[2],'Private output path required');
 writeFileSync(process.argv[2],output,{mode:0o600,flag:'wx'});
}
console.log('PASS assembled '+(inputs.length-(includeCandidateData?0:1))+' SQL components in one rollback-only transaction; '+(includeCandidateData?'all four candidate data blocks included':'four airport data blocks deferred'));
console.log('Rehearsal does not validate production operational data, dispatcher runtime behavior or cron installation.');
