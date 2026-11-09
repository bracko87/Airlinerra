import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {verifyBuiltPlayerModules} from '../website/dev-scripts/verify-built-player-modules.mjs';

test('the actual production player bundle resolves all local JavaScript imports',async()=>{
 const distDir=fileURLToPath(new URL('../dist/',import.meta.url));
 const info=await verifyBuiltPlayerModules({distDir});
 assert.ok(info.modulesChecked>10,'expected a complete player import graph');
 assert.ok(info.files.includes('game-permission-applications-client.mjs'));
 assert.ok(info.files.includes('game-permission-applications-view.mjs'));
 assert.ok(info.files.includes('section9-route-finance-panel.mjs'));
});

test('a missing imported game licence module breaks the build rather than hanging onboarding',async()=>{
 const dir=await mkdtemp(path.join(tmpdir(),'airlinerra-player-graph-'));
 try{
  await writeFile(path.join(dir,'player-app.mjs'),
   "import './game-permission-applications-client.mjs';\n"+
   "import './game-permission-applications-view.mjs';\n");
  await writeFile(path.join(dir,'game-permission-applications-client.mjs'),
   "export const client=true;\n");
  await assert.rejects(
   verifyBuiltPlayerModules({distDir:dir}),
   /Built player module missing: game-permission-applications-view\.mjs/
  );
  await writeFile(path.join(dir,'game-permission-applications-view.mjs'),
   "export const view=true;\n");
  const info=await verifyBuiltPlayerModules({distDir:dir});
  assert.equal(info.modulesChecked,3);
 }finally{
  await rm(dir,{recursive:true,force:true});
 }
});
