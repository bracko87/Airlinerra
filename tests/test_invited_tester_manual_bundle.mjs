import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,access} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';

const root=new URL('../',import.meta.url);
const fsPath=url=>url.pathname;
const run=(script,env={})=>execFileSync(process.execPath,[script],{
  cwd:fsPath(root),
  env:{...process.env,AIRLINERRA_INVITED_TESTER_BUILD_APPROVED:'',...env},
  stdio:'pipe',timeout:20000
});
const dist=path=>new URL('../dist/'+path,import.meta.url);
const read=async path=>readFile(dist(path),'utf8');
async function exists(path){try{await access(dist(path));return true;}catch{return false;}}

test('default static site remains closed; private build requires explicit approval and is reversible',async()=>{
  run('website/dev-scripts/build.mjs');
  const preview=await read('account.html');
  assert.match(preview,/Prelaunch preview/);
  assert.match(await read('auth-rules.mjs'),/export const PUBLIC_AUTH_ENABLED = false;/);
  for(const p of [
    'invited-tester-page.mjs','invited-tester-auth.mjs',
    'invited-tester-entry.mjs','invited-tester-config.js'
  ])assert.equal(await exists(p),false,'default build published '+p);
  assert.throws(()=>run('website/dev-scripts/build-invited-tester.mjs'));
  assert.equal(await read('account.html'),preview,'denied overlay cannot change account page');

  run('website/dev-scripts/build-invited-tester.mjs',{
    AIRLINERRA_INVITED_TESTER_BUILD_APPROVED:'I APPROVE PRIVATE TESTER BUILD'
  });
  const html=await read('account.html');
  assert.match(html,/PRIVATE PRELAUNCH ACCESS/);
  assert.match(html,/id="set-password"/);
  assert.match(html,/invited-tester-config\.js/);
  assert.doesNotMatch(html,/id="register"|id="airline-onboarding"/);
  assert.equal(await exists('invited-tester-page.mjs'),true);
  assert.equal(await exists('invited-tester-entry.mjs'),true);
  assert.equal(await exists('invited-tester-auth.mjs'),true);
  const runtime=await read('invited-tester-config.js');
  assert.match(runtime,/operatorPrelaunchApproved":true/);
  assert.match(runtime,/sb_publishable_[A-Za-z0-9_-]{16,128}/);
  assert.doesNotMatch(runtime,/service_role|sb_secret_/);
  assert.match(await read('auth-rules.mjs'),/export const PUBLIC_AUTH_ENABLED = false;/);

  run('website/dev-scripts/build.mjs');
  assert.equal(await read('account.html'),preview);
  for(const p of ['invited-tester-entry.mjs','invited-tester-config.js']){
    assert.equal(await exists(p),false,'default build failed to scrub '+p);
  }
});
