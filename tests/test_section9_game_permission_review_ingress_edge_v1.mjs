import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('independent game permission reviewer is server-only and fails closed without credentials',async()=>{
 const entry=await read('server/section9-game-permission-review-edge-entry.ts');
 assert.match(entry,/AIRLINERRA_GAME_PERMISSION_REVIEW_HMAC_SECRET/);
 assert.match(entry,/SUPABASE_DB_URL/);
 assert.match(entry,/REVIEW_SECRET\.length>=32/);
 assert.match(entry,/if\(!ingress\)return fail\(503/);
 assert.match(entry,/req\.method!=='POST'/);
 assert.match(entry,/req\.headers\.get\('origin'\)/);
 assert.match(entry,/x-airlinerra-review-protocol/);
 assert.match(entry,/req\.headers\.get\('content-type'\)!=='application\/json'/);
 assert.match(entry,/new TextEncoder\(\)\.encode\(raw\)\.byteLength>4096/);
 assert.match(entry,/ingress\.acceptSignedReview\(event\)/);
 assert.doesNotMatch(entry,/\bconsole\.(?:log|info|debug)\s*\(/);
 assert.doesNotMatch(entry,/export\s+const\s+REVIEW_SECRET/);
});
test('reviewer uses independent HMAC signature validation, not client-supplied ownership',async()=>{
 const source=await read('server/section9-game-permission-application-service.mjs');
 assert.match(source,/createSection9GamePermissionReviewIngress/);
 assert.match(source,/timingSafeEqual/);
 assert.match(source,/section9PermissionReviewPayload/);
 assert.match(source,/INDEPENDENT_GAME_PERMISSION_REVIEW_SECRET_REQUIRED/);
 assert.match(source,/SECTION9_UNTRUSTED_GAME_PERMISSION_REVIEW_SIGNATURE/);
 assert.match(source,/SECTION9_GAME_PERMISSION_SQL\.decide/);
 assert.match(source,/replayed===true/);
});
test('player endpoint still cannot approve or revoke permissions',async()=>{
 const source=await read('server/section9-permission-player-http.mjs');
 assert.match(source,/\['status','apply'\]/);
 assert.doesNotMatch(source,/action==='approve'/);
 assert.doesNotMatch(source,/action==='revoke'/);
});
