import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import {libraryPageForSelection,AIRCRAFT_LIBRARY_PAGE_SIZE,aircraftImagePath,aircraftDisplayModel,aircraftDisplayName,aircraftCatalogModel,aircraftCatalogName,compareAircraftCatalog} from '../website/aircraft-library.mjs';

const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('all 13 corrected aircraft images are used by website fallback without affecting nearby models',()=>{
 const replacements=[
  ['Airbus Canada','A220-100','passenger','Airbus Canada A220-100 passanger fix.png'],
  ['Airbus','A340-200','passenger','Airbus A340-200 passenger fix.png'],
  ['Boeing','737-200C','combi','Boeing 737-200C fix.png'],
  ['Boeing','737-900','passenger','Boeing 737-900 fix.png'],
  ['Boeing','747-200F','cargo','Boeing 747-200F fix.png'],
  ['Boeing','767-400ER','passenger','Boeing 767-400ER fix.png'],
  ['Boeing','777-200LR','passenger','Boeing 777-200LR Fix.png'],
  ['Boeing','777-300','passenger','Boeing 777-300 fix.png'],
  ['Boeing','777F','cargo','Boeing 777F fix.png'],
  ['Boeing','787-8','passenger','Boeing 787-8 fix.png'],
  ['Boeing','787-10','passenger','Boeing 787-10 fix.png'],
  ['Boeing','Boeing 727-200 Freighter','cargo','Boeing 727-200 Freighter fix.png'],
  ['Boeing','Boeing 737-500','passenger','Boeing 737-500 fix.png']
 ];
 for(const [manufacturer,model,useType,filename] of replacements){
  const url=aircraftImagePath({manufacturer,model,useType});
  assert.equal(url?.split('/').pop(),encodeURIComponent(filename),manufacturer+' '+model);
 }
 const er=aircraftImagePath({manufacturer:'Boeing',model:'737-900ER',useType:'passenger'});
 assert.equal(er?.split('/').pop(),'Boeing%20737-900ER%20passenge.png');
});

test('aircraft model column shows model only when manufacturer repeats at the beginning',()=>{
 const examples=[
  ['Boeing','Boeing 727-200 Freighter','727-200 Freighter'],
  ['Boeing','Boeing 737-300SF','737-300SF'],
  ['Boeing','Boeing 737-400','737-400'],
  ['Boeing','Boeing 737-500','737-500'],
  ['Boeing','737-400','737-400'],
  ['Boeing','Boeing Boeing 737-400','737-400'],
  ['Airbus','A330-300','A330-300'],
  ['Airbus','Airbus A350-900','A350-900'],
  ['De Havilland Canada','De Havilland Canada Dash 8-100','Dash 8-100']
 ];
 for(const [maker,raw,expected] of examples){
  assert.equal(aircraftDisplayModel(maker,raw),expected);
  assert.equal(aircraftDisplayName(maker,raw),maker+' '+expected);
 }
 assert.equal(aircraftDisplayModel('Boeing','Boeing'),'Boeing');
 assert.equal(aircraftDisplayModel('Boeing','Boeingfield 737'),'Boeingfield 737');
});

test('table and aircraft profile use deduplicated names while preserving original model identifiers',async()=>{
 const js=await read('../website/aircraft-library.mjs');
 assert.match(js,/library-model-link',aircraftCatalogModel\(a\)/);
 assert.match(js,/const title=element\('h2','',aircraftCatalogName\(a\)\)/);
 assert.match(js,/Open profile for '\+aircraftCatalogName\(a\)/);
 assert.match(js,/\[a\.manufacturer,a\.model,a\.useType\]\.join\('\|'\)/);
});

test('active repeated model/role pairs keep distinct display names',()=>{
 const pairs=[
  ['Boeing','737-800','cargo','AIR-INUIT-CARGO','MYINDO-737-800F','737-800F'],
  ['Boeing','Boeing 737-400','cargo','AEROSUCRE-CARGO-UNSPECIFIED','MYINDO-737-400F','737-400F'],
  ['British Aerospace','BAe 146-200','passenger','PASSENGER-BASE','DAP-ANTARCTIC-70','DAP Antarctic'],
  ['De Havilland Canada','Dash 8-300','cargo','AIR-INUIT-CARGO','AIR-INUIT-LARGE-DOOR-CARGO','Large Freight Door'],
  ['Saab','Saab 340B','cargo','AMERIFLIGHT-CARGO','RYAN-AIR-CARGO','Ryan Air']
 ];
 const names=new Set();
 for(const [manufacturer,model,useType,first,second,expected] of pairs){
  const a={manufacturer,model,useType,configuration:first},b={manufacturer,model,useType,configuration:second};
  const firstName=aircraftCatalogName(a),secondName=aircraftCatalogName(b);
  assert.notEqual(firstName,secondName,model+' '+useType);
  assert.ok(secondName.includes(expected),secondName);
  names.add(firstName+'|'+useType);
  names.add(secondName+'|'+useType);
 }
 assert.equal(names.size,10,'10 remaining repeated entries must have unique names');
 assert.equal(aircraftCatalogModel({manufacturer:'Boeing',model:'Boeing 737-500',useType:'passenger',configuration:'PASSENGER-BASE'}),'737-500');
 assert.equal(aircraftCatalogModel({manufacturer:'De Havilland Canada',model:'Dash 8-300',useType:'combi',configuration:'AIR-INUIT-PASSENGER'}),'Dash 8-300');
 assert.equal(aircraftCatalogModel({manufacturer:'De Havilland Canada',model:'DHC-6-300',useType:'passenger',configuration:'PASSENGER-BASE'}),'DHC-6-300');
});

test('default manufacturer sorting keeps aircraft families and numerical model order together',()=>{
 const sample=[
  ['777-300ER','777',0],['Boeing 727-200 Freighter','727',1],
  ['787-10','787',2],['737-800','737',3],
  ['Boeing 737-500','737',4],['Boeing 737-300SF','737',5],
  ['737-300','737',6],['Boeing 737-400','737',7],
  ['737-800BCF','737',8],['777-200LR','777',9],['787-8','787',10]
 ].map(([model,family,id])=>({manufacturer:'Boeing',model,family,id,useType:'cargo',configuration:'CARGO-BASE'}));
 const names=[...sample].sort((a,b)=>compareAircraftCatalog(a,b,'manufacturer','asc'))
  .map(a=>aircraftDisplayModel(a.manufacturer,a.model));
 assert.deepEqual(names,[
  '727-200 Freighter','737-300','737-300SF','737-400','737-500','737-800',
  '737-800BCF','777-200LR','777-300ER','787-8','787-10'
 ]);
 const byModel=[...sample].sort((a,b)=>compareAircraftCatalog(a,b,'model','asc'));
 assert.deepEqual(byModel.map(a=>aircraftDisplayModel(a.manufacturer,a.model)),names);
 // Returning from a profile still selects the correct page after the new ordering.
 assert.equal(libraryPageForSelection(byModel,4,0),0);
 assert.equal(compareAircraftCatalog({manufacturer:'Airbus',family:'A320',model:'A320',id:1},
  {manufacturer:'Boeing',family:'737',model:'737-500',id:2}),-1);
});

test('20 airplanes per page and last selected aircraft returns to its own page',()=>{
 const records=Array.from({length:235},(_,i)=>({id:i+1}));
 assert.equal(AIRCRAFT_LIBRARY_PAGE_SIZE,20);
 assert.equal(libraryPageForSelection(records,1,0),0);
 assert.equal(libraryPageForSelection(records,20,0),0);
 assert.equal(libraryPageForSelection(records,21,0),1);
 assert.equal(libraryPageForSelection(records,81,0),4);
 assert.equal(libraryPageForSelection(records,210,0),10);
 assert.equal(libraryPageForSelection(records,235,0),11);
 assert.equal(libraryPageForSelection(records,999,4),4);
 assert.equal(libraryPageForSelection([],5,0),0);
});
test('pagination controls render 20 rows, show page status and reset after filters or sorting',async()=>{
 const [js,html]=await Promise.all([
  read('../website/aircraft-library.mjs'),read('../website/private-player-app.html')
 ]);
 assert.match(js,/data\.slice\(currentPage\*AIRCRAFT_LIBRARY_PAGE_SIZE,\(currentPage\+1\)\*AIRCRAFT_LIBRARY_PAGE_SIZE\)/);
 assert.match(js,/currentPage=0;if\(aircraft\)draw\(\)/);
 assert.match(js,/previous\.addEventListener\('click',\(\)=>changePage\(-1\)\)/);
 assert.match(js,/more\.addEventListener\('click',\(\)=>changePage\(1\)\)/);
 assert.match(js,/const selectedPage=libraryPageForSelection\(ordered,lastSelectedAircraftId,currentPage\)/);
 assert.match(html,/id="aircraft-library-previous"/);
 assert.match(html,/id="aircraft-library-more"/);
 assert.match(html,/id="aircraft-library-page"/);
 assert.match(html,/20 aircraft per page/);
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
