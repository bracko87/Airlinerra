import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,stat} from 'node:fs/promises';
const root = new URL('../',import.meta.url);
const source = path => readFile(new URL(path,root),'utf8');
const exists = async path => {
  try{await stat(new URL(path,root));return true;}
  catch(error){if(error.code==='ENOENT')return false;throw error;}
};

test('prelaunch website and Netlify cannot auto-expose hosted account routes',async()=>{
  const [rules,netlify,build]=await Promise.all([
    source('website/auth-rules.mjs'),
    source('netlify.toml'),
    source('website/dev-scripts/build.mjs')
  ]);
  assert.match(rules,/export const PUBLIC_AUTH_ENABLED = false;/);
  assert.match(rules,/ALLOWED_AUTH_ORIGINS = Object\.freeze\(\['http:\/\/localhost:5187'\]\)/);
  assert.match(netlify,/base = "website"/);
  assert.doesNotMatch(netlify,/\/api\/v1\/(?:airlines|onboarding|legal)/);
  assert.doesNotMatch(netlify,/\[functions\]/);
  assert.doesNotMatch(build,/hosted-runtime-config|preview-account-app|hosted-auth-verifier|hosted-account-stack/);
  assert.equal(await exists('website/netlify/functions/'),false,
    'No discoverable Netlify Functions may launch preapproved');
  assert.equal(await exists('netlify/functions/'),false,
    'No root functions may automatically deploy without owner authorization');
});

test('server-only hosted backend requires independent preview or canonical-production opt-in',async()=>{
  const [runtime,config,stack]=await Promise.all([
    source('server/preview-account-app.mjs'),
    source('server/hosted-runtime-config.mjs'),
    source('server/hosted-account-stack.mjs')
  ]);
  assert.match(config,/AIRLINERRA_HOSTED_BACKEND_ENABLED !== 'true'/);
  assert.match(config,/AIRLINERRA_PRIVATE_PREVIEW_APPROVED !== 'true'/);
  assert.match(config,/AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED !== 'true'/);
  assert.match(config,/AIRLINERRA_HOSTED_RUNTIME_MODE/);
  assert.match(config,/https:\/\/airlinerra\.com/);
  assert.match(config,/ALLOWED_PREVIEW_CONTEXTS = new Set\(\['deploy-preview', 'branch-deploy'\]\)/);
  assert.doesNotMatch(config,/\['production'/);
  assert.match(runtime,/if\(!config\.enabled\)/);
  assert.match(runtime,/loadPg=loadServerPostgresDriver/);
  const loader=await source('website/server-only-pg-loader.mjs');
  assert.match(loader,/import pg from 'pg';/);
  assert.match(loader,/return pg;/);
  const build=await source('website/dev-scripts/build.mjs');
  assert.doesNotMatch(build,/server-only-pg-loader/);
  assert.match(stack,/if\(!enabled\)return createHostedAccountRouter\(\)/);
});
