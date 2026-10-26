import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const FILES = [
  'docs/sql/airlinerra_game_identity_schema_prelaunch.sql',
  'docs/sql/airlinerra_game_activation_prelaunch.sql',
  'tests/sql/airline_activation_isolated_assertions.sql',
  'tests/sql/airline_activation_disposable_fixtures.sql',
  'tests/sql/airline_activation_negative_cases.sql',
  'tests/sql/airline_activation_postconditions.sql',
  'tests/sql/legal_consent_isolated.sql',
  'tests/sql/player_profile_rls_isolated.sql'
];
const load = name => readFile(path.join(ROOT,name),'utf8');

test('all account SQL files share one text-key activation function signature',async()=>{
  for(const filename of FILES) {
    const sql=await load(filename);
    assert.doesNotMatch(sql,/create_airline_once\(uuid,smallint,text,bigint\)/i,filename);
    assert.doesNotMatch(sql,/\bhome_airport_source_id\b|\bsource_airport_id\s+bigint\b/i,filename);
    assert.doesNotMatch(sql,/,\s*101\s*\)/,filename+' retained a numeric source-ID argument');
  }
  const activation=await load(FILES[1]);
  assert.match(activation,/p_home_airport_key text/);
  assert.match(activation,/create_airline_once\(uuid,smallint,text,text\)/);
  assert.match(activation,/a\.airport_key = p_home_airport_key/);
});
test('draft schema has one approved-airport table, one airline table and no duplicate suffix',async()=>{
  const schema=await load(FILES[0]);
  assert.equal((schema.match(/create table if not exists airlinerra_game\.approved_game_airports/g)||[]).length,1);
  assert.equal((schema.match(/create table if not exists airlinerra_game\.airlines\s*\(/g)||[]).length,1);
  assert.equal((schema.match(/^begin;$/gm)||[]).length,1);
  assert.equal((schema.match(/^commit;$/gm)||[]).length,1);
  assert.ok(schema.trimEnd().endsWith('commit;'));
  assert.match(schema,/primary key \(world_id, airport_key\)/);
  assert.match(schema,/foreign key \(world_id,home_airport_key\)/);
  assert.match(schema,/references airlinerra_game\.approved_game_airports\(world_id,airport_key\)/);
});
test('disposable tests verify real matching function privileges and legal policy rotation',async()=>{
  const legal=await load('tests/sql/legal_consent_isolated.sql');
  const profile=await load('tests/sql/player_profile_rls_isolated.sql');
  const asserts=await load('tests/sql/airline_activation_isolated_assertions.sql');
  assert.match(profile,/create_airline_once\(uuid,smallint,text,text\)/);
  assert.match(asserts,/create_airline_once\(uuid,smallint,text,text\)/);
  assert.match(legal,/'Should Reject Old Legal Consent','OURAIRPORTS:101'\)/);
  assert.match(legal,/Published terms and verified player consent required/);
});
test('fictional airport remains testable only with explicit disposable approval',async()=>{
  const fixture=await load('tests/sql/airline_activation_disposable_fixtures.sql');
  const post=await load('tests/sql/airline_activation_postconditions.sql');
  assert.match(fixture,/'FICTIONAL:fictional:RS:LYAL','ISOLATED-TEST-ONLY'/);
  assert.match(post,/'Atlantic Routes','FICTIONAL:fictional:RS:LYAL'/);
  assert.match(fixture,/'OURAIRPORTS:101','ISOLATED-TEST-ONLY'/);
});
test('isolated PostgreSQL validation remains manual-only with explicit DB preflight',async()=>{
  const workflow=await load('.github/workflows/airlinerra-postgres-isolated.yml');
  assert.match(workflow,/workflow_dispatch:/);
  assert.doesNotMatch(workflow,/^\s*push:\s*$/m);
  assert.doesNotMatch(workflow,/^\s*pull_request:\s*$/m);
  assert.ok(workflow.indexOf('tests/sql/disposable_database_preflight.sql') <
    workflow.indexOf('docs/sql/airlinerra_game_identity_schema_prelaunch.sql'));
  assert.match(workflow,/\bpostgres:17\b/);
  assert.match(workflow,/PGDATABASE: airlinerra_disposable/);
});

test('disposable activation calls use explicit PostgreSQL smallint world IDs',async()=>{
  const sources = [
    ...FILES,
    '.github/workflows/airlinerra-postgres-isolated.yml',
    '.github/workflows/airlinerra-account-node-ci.yml'
  ];
  let typedCalls = 0;
  for (const filename of sources) {
    const sql = await load(filename);
    assert.doesNotMatch(sql,
      /create_airline_once\(\s*'[0-9a-f-]{36}'\s*,\s*[123]\s*,/i,
      filename+' calls a smallint function with an untyped integer world ID');
    typedCalls += [...sql.matchAll(
      /create_airline_once\(\s*'[0-9a-f-]{36}'\s*,\s*[123]::smallint\s*,/gi
    )].length;
  }
  assert.ok(typedCalls >= 16,'expected all disposable activation calls to be typed');
});
