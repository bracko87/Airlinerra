import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHmac} from 'node:crypto';
import {section9PermissionReviewPayload} from '../server/section9-game-permission-application-service.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const sqlPath='supabase/migrations/20261113217000_section9_private_signed_game_permission_auto_review_v1.sql';

test('game authority HMAC matches independently tested PostgreSQL pgcrypto fixture',()=>{
 const event={
  worldId:1,
  applicationId:'11111111-1111-4111-8111-111111111111',
  eventId:'auto-game-permission-v1-11111111-1111-4111-8111-111111111111-20261113',
  decision:'approve',
  gameDate:'2026-11-13',
  reviewerReference:'airlinerra-game-automatic-authority-v1'
 };
 const key='unit-test-only-key-1234567890abcdefghijklmnopqrstuvwxyz';
 assert.equal(createHmac('sha256',key)
  .update(section9PermissionReviewPayload(event),'utf8').digest('hex'),
  '732c3256f811b549a1f4462172789e37391e093627fac7b9d570d6c2cdf090ff');
});

test('automatic reviewer is postgres-only, transaction-safe, and strictly policy-gated',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/SECURITY INVOKER/);
 assert.match(sql,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(sql,/pg_try_advisory_xact_lock\(583729,10019\)/);
 assert.match(sql,/section9_verified_permission_game_day_v1\(\)/);
 assert.match(sql,/r\.release_enabled=true AND r\.released_at IS NOT NULL/);
 assert.match(sql,/c\.enabled_in_game=true/);
 assert.match(sql,/r\.reviewed_by='AIRLINERRA_GAME_AUTHORITY_AUTO_V1'/);
 assert.match(sql,/section9_decide_game_permission_application_v1/);
 assert.match(sql,/game_permission_issuance_not_released/);
 assert.match(sql,/chargesAppliedOnlyAtIssuance',true/);
 assert.match(sql,/game_permission_decision_replayed/);
 assert.match(sql,/blocked_insufficient_airline_cash/);
 assert.doesNotMatch(sql,/\bALTER TABLE airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE airlinerra_game\.business_permission_catalog_v1/i);
 assert.doesNotMatch(sql,/\bUPDATE airlinerra_game\.section9_game_permission_issuance_policy_v1/i);
});

test('private signing secret is generated in Vault, not committed in plaintext',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/vault\.create_secret\(/);
 assert.match(sql,/extensions\.gen_random_bytes\(48\)/);
 assert.match(sql,/vault\.decrypted_secrets/);
 assert.match(sql,/extensions\.hmac\(/);
 assert.match(sql,/signingSecretExposed',false/);
 assert.doesNotMatch(sql,/\bconsole\.(?:log|warn|info|debug)\s*\(/);
 assert.doesNotMatch(sql,/decrypted_secret AS returned_/i);
 assert.doesNotMatch(sql,/secret_value[,\s]*\)/i);
});

test('cron scheduling is idempotent and never enables the licence release itself',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/WHERE jobname='airlinerra-game-permission-auto-review-v1'/);
 assert.match(sql,/PERFORM cron\.schedule\(/);
 assert.match(sql,/'\*\/5 \* \* \* \*'/);
 assert.match(sql,/section9_review_due_game_permissions_auto_v1\(50\)/);
 assert.doesNotMatch(sql,/SET\s+release_enabled\s*=\s*true/i);
 assert.doesNotMatch(sql,/SET\s+enabled_in_game\s*=\s*true/i);
});
