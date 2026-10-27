/**
 * Verify the actual pinned node-postgres driver (not a stub) respects the
 * server's certificate-verification settings after connection-url sanitation.
 * This test never opens a network socket or contacts a real database.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readFile} from 'node:fs/promises';
import {parseHostedRuntimeConfig,AIRLINERRA_AUTH_API} from '../server/hosted-runtime-config.mjs';

const fromWebsite=createRequire(new URL('../website/package.json',import.meta.url));
const pg=fromWebsite('pg');
const PROJECT='hwllkabgzaynalahvkpz';
const synthetic=()=>({
  CONTEXT:'deploy-preview',
  AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
  AIRLINERRA_PRIVATE_PREVIEW_APPROVED:'true',
  AIRLINERRA_PREVIEW_ORIGIN:'https://deploy-preview-123--airlinerra.netlify.app',
  AIRLINERRA_SUPABASE_URL:AIRLINERRA_AUTH_API,
  AIRLINERRA_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_'+('A'.repeat(32)),
  AIRLINERRA_PRIVATE_DATABASE_URL:
    'postgresql://postgres.'+PROJECT+':synthetic-ci-password@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require',
  AIRLINERRA_TERMS_PATH:'/legal/terms-v1.html',
  AIRLINERRA_PRIVACY_PATH:'/legal/privacy-v1.html'
});

test('committed npm lock pins exact driver version and contains integrity hashes',async()=>{
  const pkg=JSON.parse(await readFile(new URL('../website/package.json',import.meta.url)));
  const lock=JSON.parse(await readFile(new URL('../website/package-lock.json',import.meta.url)));
  assert.equal(pkg.dependencies.pg,'8.23.1');
  assert.equal(lock.packages[''].dependencies.pg,pkg.dependencies.pg);
  assert.equal(lock.packages['node_modules/pg'].version,pkg.dependencies.pg);
  assert.match(lock.packages['node_modules/pg'].integrity,/^sha512-/);
  assert.equal(fromWebsite('pg/package.json').version,pkg.dependencies.pg);
});

test('pinned pg Client retains TLS certificate verification after sanitization',()=>{
  const conf=parseHostedRuntimeConfig(synthetic());
  assert.equal(new URL(conf.dbUrl).search,'');
  const client=new pg.Client({
    connectionString:conf.dbUrl,
    ssl:{rejectUnauthorized:true},
    connectionTimeoutMillis:5000
  });
  // Inspect real parsed config; no .connect() is called.
  assert.deepEqual(client.connectionParameters.ssl,{rejectUnauthorized:true});
  assert.equal(client.connectionParameters.host,'aws-0-eu-central-1.pooler.supabase.com');
  assert.equal(client.connectionParameters.port,6543);
});

test('actual pg Pool construction is lazy and bounded; no connection is opened',async()=>{
  const conf=parseHostedRuntimeConfig(synthetic());
  const pool=new pg.Pool({
    connectionString:conf.dbUrl,ssl:{rejectUnauthorized:true},max:2,
    connectionTimeoutMillis:5000,statement_timeout:8000,allowExitOnIdle:true
  });
  assert.equal(pool.options.max,2);
  assert.deepEqual(pool.options.ssl,{rejectUnauthorized:true});
  assert.equal(pool.totalCount,0);
  assert.equal(pool.idleCount,0);
  await pool.end();
});
