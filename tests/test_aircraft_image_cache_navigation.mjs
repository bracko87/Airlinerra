import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {libraryReturnVisibleCount,aircraftImagePath} from '../website/aircraft-library.mjs';

const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('the selected aircraft remains reachable after sorting or paging',()=>{
 const records=Array.from({length:235},(_,i)=>({id:i+1}));
 assert.equal(libraryReturnVisibleCount(records,1,40),40);
 assert.equal(libraryReturnVisibleCount(records,81,40),120);
 assert.equal(libraryReturnVisibleCount(records,210,80),240);
 assert.equal(libraryReturnVisibleCount(records,999,40),40);
 assert.equal(libraryReturnVisibleCount([],5,40),40);
});

test('profile immediately requests the real image without drawing a temporary aircraft icon',async()=>{
 const [aircraft,app]=await Promise.all([read('../website/aircraft-library.mjs'),read('../website/player-app.mjs')]);
 assert.doesNotMatch(aircraft,/element\('span','library-profile-plane','✈'\)/);
 assert.doesNotMatch(aircraft,/Image not yet available/);
 assert.doesNotMatch(aircraft,/picture\.loading='lazy'/);
 assert.match(aircraft,/picture\.loading='eager'/);
 assert.match(aircraft,/picture\.fetchPriority='high'/);
 assert.match(aircraft,/list\.addEventListener\('pointerover',warmRow\)/);
 assert.match(aircraft,/list\.addEventListener\('focusin',warmRow\)/);
 assert.match(aircraft,/scrollIntoView\(\{block:'center',inline:'nearest',behavior:'instant'\}\)/);
 assert.match(app,/returningFromAircraftProfile/);
 assert.match(app,/aircraftLibraryController\.restoreLastSelection\(\)/);
});

test('confirmed configuration paths still override fallback names',()=>{
 const url=aircraftImagePath({manufacturer:'Airbus',model:'A319neo',useType:'passenger',
  imagePath:'Airplanes/Airbus A319neo passanger fix.png'});
 assert.ok(url.includes('Airbus%20A319neo%20passanger%20fix.png'));
});

test('only public aircraft image requests are persistently cached; reused on a new worker session',async()=>{
 const source=await read('../website/aircraft-image-cache-sw.js');
 const stored=new Map();
 let count=0;
 class MockResponse{
  constructor(mark,type='opaque'){this.mark=mark;this.type=type;this.ok=type!=='opaque'}
  clone(){return new MockResponse(this.mark,this.type)}
 }
 const sharedCaches={
  async open(){return {
   async match(req){return stored.get(req.url)||undefined},
   async put(req,res){stored.set(req.url,res)},
   async keys(){return [...stored.keys()].map(url=>({url}))},
   async delete(req){stored.delete(req.url)}
  }},
  async keys(){return ['airlinerra-public-aircraft-images-v1']},
  async delete(){return true}
 };
 function startWorker(){
  const handlers={};
  vm.runInNewContext(source,{
   URL,caches:sharedCaches,
   self:{addEventListener:(name,cb)=>{handlers[name]=cb},skipWaiting:async()=>{},clients:{claim:async()=>{}}},
   fetch:async req=>{count++;return new MockResponse(req.url)},
   Response:{error:()=>new MockResponse('network unavailable','error')}
  },{filename:'aircraft-image-cache-sw.js'});
  return handlers;
 }
 async function request(handlers,url,destination='image'){
  let responsePromise=null;
  const waiting=[];
  const req={url,method:'GET',destination};
  handlers.fetch({request:req,
   respondWith(value){responsePromise=value},
   waitUntil(value){waiting.push(value)}
  });
  if(!responsePromise)return null;
  const response=await responsePromise;
  await Promise.all(waiting);
  return response;
 }
 const url='https://hwllkabgzaynalahvkpz.supabase.co/storage/v1/object/public/Admin/Airplanes/Airbus%20A319neo%20passanger%20fix.png';
 const first=startWorker();
 assert.ok(await request(first,url));
 assert.equal(count,1);
 assert.equal(stored.size,1);
 assert.equal(await request(first,'https://hwllkabgzaynalahvkpz.supabase.co/auth/v1/user'),null);
 assert.equal(await request(first,'https://example.com/private-image.png'),null);
 assert.equal(await request(first,url,'document'),null);
 const second=startWorker();
 assert.ok(await request(second,url));
 assert.equal(count,1,'Cache persists between worker instances (browser reload / restart)');
});
