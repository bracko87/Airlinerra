import test from 'node:test';
import assert from 'node:assert/strict';
import {spawn} from 'node:child_process';
import {request as httpRequest} from 'node:http';
import {fileURLToPath} from 'node:url';
import {dirname,resolve} from 'node:path';
import {readFile} from 'node:fs/promises';
import {LOCAL_PLAYER_API_PATHS} from '../website/dev-scripts/real-player-read-gateway.mjs';

const local='http://localhost:5188';
const cwd=resolve(dirname(fileURLToPath(import.meta.url)),'../website');
const airline='9c5c6aff-588f-4d25-abe5-dd91efc2e0d1';

function post(path,payload,token){
 const body=JSON.stringify(payload);
 return new Promise((resolvePromise,reject)=>{
  const req=httpRequest({hostname:'127.0.0.1',port:5188,
   path,method:'POST',headers:{host:'localhost:5188',origin:local,
    'content-type':'application/json','content-length':Buffer.byteLength(body),
    ...(token?{authorization:'Bearer '+token}:{})}
  },res=>{
   let text='';
   res.on('data',chunk=>{text+=chunk;});
   res.on('end',()=>resolvePromise({status:res.statusCode,text}));
  });
  req.setTimeout(7000,()=>req.destroy(Error('Local preview did not respond')));
  req.on('error',reject);
  req.end(body);
 });
}
function startPreview(){
 const child=spawn(process.execPath,['dev-scripts/dev.mjs','--built'],{
  cwd,env:{...process.env,PORT:'5188',AIRLINERRA_LOCAL_USE_DATABASE:'0'},
  stdio:['ignore','pipe','pipe']
 });
 return {child,ready:new Promise((resolvePromise,reject)=>{
  let output='';
  const timer=setTimeout(()=>reject(Error('Local preview failed to start: '+output.slice(-1800))),14000);
  child.stdout.on('data',chunk=>{
   output+=String(chunk);
   if(output.includes('built-site preview server:')){
    clearTimeout(timer);resolvePromise();
   }
  });
  child.stderr.on('data',chunk=>{output+=String(chunk);});
  child.on('error',error=>{clearTimeout(timer);reject(error);});
  child.on('exit',code=>{
   clearTimeout(timer);
   reject(Error('Local preview exited '+code+': '+output.slice(-1800)));
  });
 })};
}

test('real built localhost server routes fleet URLs to protected gateway (not static 404)',{
 timeout:30000
},async()=>{
 for(const path of ['/api/v1/player/fleet-acquisition','/api/v1/player/flight-schedule-drafts'])
  assert.ok(LOCAL_PLAYER_API_PATHS.includes(path),'missing HTTP dispatch for '+path);
 const dev=await readFile(new URL('../website/dev-scripts/dev.mjs',import.meta.url),'utf8');
 assert.match(dev,/LOCAL_PLAYER_API_PATHS\.includes\(pathname\)/);
 const app=await readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8');
 assert.match(app,/await loadPlayerReadData\(\{local:true\}\)/);
 const {child,ready}=startPreview();
 try{
  await ready;
  for(const path of ['/api/v1/player/fleet-acquisition','/api/v1/player/flight-schedule-drafts']){
   const noBearer=await post(path,{action:'list',airlineId:airline});
   assert.equal(noBearer.status,401,path+' should reach local Auth guard, not a static 404');
   const mutation=await post(path,{action:'acquire',airlineId:airline},'x'.repeat(40));
   assert.equal(mutation.status,403,path+' must not forward game-state writes');
  }
 }finally{child.kill();}
});
