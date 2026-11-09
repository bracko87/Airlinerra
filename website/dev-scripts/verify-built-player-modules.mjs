/**
 * Fail the Airlinerra build before publishing a broken player page.
 *
 * The player shell uses native browser ESM imports. A missing transitive
 * module causes all of player-app.mjs to stop evaluating (the loading screen
 * then stays on "Opening Airlinerra..."). Validate the ACTUAL dist tree.
 */
import {readFile,stat} from 'node:fs/promises';
import path from 'node:path';

const STATIC_FROM = /\bfrom\s*['"](\.{1,2}\/[^'"\s]+)['"]/gu;
const STATIC_SIDE_EFFECT = /\bimport\s*['"](\.{1,2}\/[^'"\s]+)['"]/gu;
const LITERAL_DYNAMIC = /\bimport\s*\(\s*['"](\.{1,2}\/[^'"\s]+)['"]\s*\)/gu;
const MODULE_EXTENSIONS = new Set(['.mjs','.js']);

export async function verifyBuiltPlayerModules({distDir}={}){
 if(typeof distDir!=='string'||!path.isAbsolute(distDir))
  throw Error('Absolute built website directory required');
 const visited = new Set();
 const pending = [{file:'player-app.mjs',from:'player.html'}];
 while(pending.length){
  const {file,from}=pending.pop();
  const absolute=path.resolve(distDir,file);
  if(absolute!==distDir&&!absolute.startsWith(distDir+path.sep))
   throw Error('Built player module import escapes website directory: '+file);
  const relative=path.relative(distDir,absolute).split(path.sep).join('/');
  if(visited.has(relative))continue;
  let bytes;
  try{
   const info=await stat(absolute);
   if(!info.isFile())throw Error('Not a file');
   bytes=await readFile(absolute,'utf8');
  }catch{
   throw Error('Built player module missing: '+relative+' (required by '+from+')');
  }
  visited.add(relative);
  if(!MODULE_EXTENSIONS.has(path.extname(relative)))continue;
  const imports=new Set();
  for(const rule of [STATIC_FROM,STATIC_SIDE_EFFECT,LITERAL_DYNAMIC]){
   rule.lastIndex=0;
   for(const match of bytes.matchAll(rule))imports.add(match[1]);
  }
  for(const specifier of imports){
   if(/[?#]/u.test(specifier))
    throw Error('Unexpected browser module import query: '+specifier);
   const next=path.relative(distDir,path.resolve(path.dirname(absolute),specifier));
   pending.push({file:next,from:relative});
  }
 }
 for(const mandatory of [
  'player-app.mjs',
  'game-permission-applications-client.mjs',
  'game-permission-applications-view.mjs'
 ]){
  if(!visited.has(mandatory))
   throw Error('Required player module not included in verified import graph: '+mandatory);
 }
 return Object.freeze({modulesChecked:visited.size,files:[...visited].sort()});
}
