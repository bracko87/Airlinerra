/** Regression barrier: in the authenticated player website, browser storage
 * must NEVER be used as the persistence destination for game records.
 * Developer-only fake-account previews are intentionally isolated and are NOT
 * the real game. Browser Auth credentials are managed by Supabase Auth only.
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import {readdir,readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const site=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../website');
const demoOnly=new Set([
 'local-demo-session.mjs',
 'local-onboarding-draft.mjs',
 'dev-only/registration.mjs',
 'dev-only/state.mjs'
]);
async function sourceFiles(dir=''){
 const entries=await readdir(path.join(site,dir),{withFileTypes:true});
 const out=[];
 for(const e of entries){
  const rel=path.posix.join(dir,e.name);
  if(e.isDirectory()){
   if(['node_modules','assets','dev-data'].includes(e.name))continue;
   out.push(...await sourceFiles(rel));
  }else if(/\.(?:js|mjs)$/i.test(e.name))out.push(rel);
 }
 return out;
}
test('all player site modules prohibit browser writes outside developer-only demo modules',async()=>{
 const files=await sourceFiles();
 assert.ok(files.length>=45,'inspect the complete game site, not one file');
 for(const filename of files){
  const source=await readFile(path.join(site,filename),'utf8');
  if(demoOnly.has(filename))continue;
  const forbidden=[
   /\b(?:localStorage|sessionStorage)\s*(?:\.|\[)\s*setItem\s*\(/g,
   /\b(?:storage|session|store)\s*\?*\.\s*setItem\s*\(/g,
   /\bindexedDB\s*\.\s*open\s*\(/g
  ];
  for(const rule of forbidden)
   assert.doesNotMatch(source,rule,'Forbidden browser game data write in '+filename);
 }
});
test('developer-only browser drafts cannot become authoritative signed-in game records',async()=>{
 const read=filename=>readFile(path.join(site,filename),'utf8');
 const [app,workspace,operations,office,cabin,planner,store]=await Promise.all([
  read('player-app.mjs'),read('airline-workspace.mjs'),
  read('airline-operations-center.mjs'),read('airline-airports-office.mjs'),
  read('cabin-services-manager.mjs'),read('route-planner.mjs'),
  read('player-draft-store.mjs')
 ]);
 assert.match(app,/if\(!preview\|\|!playerData\)return;/);
 assert.match(workspace,/await database\.update\('workplan'/);
 assert.match(operations,/await playerStore\.update\('workplan'/);
 assert.match(office,/await live\.playerDraftStore\.update\('workplan'/);
 assert.match(cabin,/No browser-only writes/);
 assert.match(planner,/No route or flight was saved/);
 assert.doesNotMatch(store,/\.setItem\s*\(/);
});
