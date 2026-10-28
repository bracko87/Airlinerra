/** End-to-end HTTP smoke of the exact built preview server, no production calls. */
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root=fileURLToPath(new URL('../',import.meta.url));
const child=spawn(process.execPath,['website/dev-scripts/dev.mjs','--built'],{
 cwd:root,env:{...process.env,PORT:'5188'},stdio:['ignore','pipe','pipe']
});
let output='',stopped=false;
child.stdout.on('data',chunk=>{output+=chunk.toString('utf8')});
child.stderr.on('data',chunk=>{output+=chunk.toString('utf8')});
child.once('exit',()=>{stopped=true});
const origin='http://localhost:5188';
const request=async(path,data,extra={})=>fetch(origin+path,{
 method:data===undefined?'GET':'POST',
 headers:{...(data===undefined?{}:{origin,'content-type':'application/json'}),...extra},
 body:data===undefined?undefined:JSON.stringify(data)
});
try{
 let available=false;
 for(let i=0;i<90;i++){
  if(stopped)throw Error('Preview exited: '+output);
  try{const res=await request('/player.html');if(res.status===200){available=true;break;}}
  catch{/* starting */ }
  await new Promise(resolve=>setTimeout(resolve,90));
 }
 assert.ok(available,'Built localhost preview failed to start: '+output);
 const page=await request('/player.html');
 assert.equal(page.status,200);
 assert.match(await page.text(),/PRIVATE PRELAUNCH/);
 const overview=await request('/__local_player__/overview',{});
 assert.equal(overview.status,200);
 const data=await overview.json();
 assert.equal(data.airportsTotal,3140);
 assert.equal(data.countries.length,229);
 assert.equal(data.worlds.length,3);
 assert.deepEqual(data.airlines,[]);
 assert.equal(data.readOnly,true);
 const airports=await request('/__local_player__/airports',{countryIso:'DE',search:'Berlin'});
 assert.equal(airports.status,200);
 assert.ok((await airports.json()).airports.some(a=>a.name==='Berlin Brandenburg Airport'));
 const denied=await request('/__local_player__/overview',{}, {origin:'https://attacker.example'});
 assert.equal(denied.status,403);
 const bad=await request('/__local_player__/airports',{countryIso:'XX',offset:999999});
 assert.equal(bad.status,400);
 const hidden=await request('/dev-data/world1-approved-airports-2026-10-28.json');
 assert.equal(hidden.status,404);
 console.log('Local Airlinerra build-to-HTTP smoke passed: pages, worlds, 3140 airports, filters, origin protection and private snapshot.');
}finally{
 child.kill('SIGTERM');
 await new Promise(resolve=>{if(stopped)return resolve();child.once('exit',resolve);setTimeout(resolve,2000)});
}
