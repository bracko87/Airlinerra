import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {airportFlag,populateAirportCountries,createAirportCountryPicker} from '../website/airport-country-picker.mjs';
import {airportCoordinates,routeDistanceKm,renderRouteMap} from '../website/route-map.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';
import {WORLD_OUTLINES} from '../website/world-outlines.mjs';
import {PLAYER_READ_SQL} from '../server/player-read-service.mjs';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
class FakeOption{
 constructor(label,value){this.textContent=label;this.value=value;this.dataset={};}
}
class FakeControl{
 constructor(){this.value='';this.options=[];this.listeners={};this.disabled=false;this.children=[];}
 replaceChildren(...children){this.options=children;this.children=children;this.value=children[0]?.value||''}
 add(value){this.options.push(value)}
 addEventListener(type,fn){this.listeners[type]=fn}
}
const airport=(key,name,code,iso)=>({key,name,code,countryIso:iso,municipality:'City'});
test('flags, country sort and natural singular/plural displayed on the actual select',()=>{
 const original=globalThis.Option;globalThis.Option=FakeOption;
 try{
  const control=new FakeControl();
  populateAirportCountries(control,[{countryIso:'RS',airportCount:3},{countryIso:'MT',airportCount:1}]);
  assert.equal(airportFlag('MT'),'🇲🇹');
  assert.equal(control.options[1].textContent,'🇲🇹 Malta (1 airport)');
  assert.equal(control.options[2].textContent,'🇷🇸 Serbia (3 airports)');
 }finally{globalThis.Option=original}
});
test('selecting a country loads ALL approved airport pages immediately, and filtering is client-side',async()=>{
 const original=globalThis.Option;globalThis.Option=FakeOption;
 try{
  const country=new FakeControl(),search=new FakeControl(),select=new FakeControl();
  const calls=[],changes=[];
  const rows=[airport('OURAIRPORTS:4427','Malta International Airport','LMML','MT'),
   airport('OURAIRPORTS:9000','Example Approved Airport','LMXX','MT')];
  const picker=createAirportCountryPicker({country,search,airport:select,
   getReader:()=>({airports:async({countryIso,offset})=>{
    calls.push([countryIso,offset]);
    return {countryIso,airports:[rows[offset/50]],nextOffset:offset===0?50:null};
   }}),
   onSelect:a=>changes.push(a?.key||null)});
  country.value='MT';await picker.load();
  assert.equal(calls.length,2);
  assert.deepEqual(picker.getAirports().map(a=>a.name),['Example Approved Airport','Malta International Airport']);
  assert.equal(select.options.length,3);
  assert.equal(select.disabled,false);
  search.value='Malta';search.listeners.input();
  assert.equal(select.options.length,2);
  select.value='OURAIRPORTS:4427';select.listeners.change();
  assert.equal(picker.selected()?.name,'Malta International Airport');
  assert.equal(changes.at(-1),'OURAIRPORTS:4427');
 }finally{globalThis.Option=original}
});
test('country changes invalidate late responses from previous country',async()=>{
 const original=globalThis.Option;globalThis.Option=FakeOption;
 try{
  const country=new FakeControl(),search=new FakeControl(),select=new FakeControl();
  let release;
  const stale=new Promise(resolve=>{release=resolve});
  const picker=createAirportCountryPicker({country,search,airport:select,
   getReader:()=>({airports:async({countryIso})=>countryIso==='MT'?stale:{
    countryIso,airports:[airport('OURAIRPORTS:4610','Belgrade Airport','LYBE','RS')],nextOffset:null
   }})});
  country.value='MT';const old=picker.load();
  country.value='RS';await picker.load();
  release({countryIso:'MT',airports:[airport('OURAIRPORTS:4427','Malta','LMML','MT')],nextOffset:null});
  await old;
  assert.deepEqual(picker.getAirports().map(a=>a.countryIso),['RS']);
 }finally{globalThis.Option=original}
});
test('real coordinates give plausible distance; unknown coordinates remain missing',()=>{
 const belgrade={latitude:44.818401,longitude:20.309099};
 const tivat={latitude:42.404701,longitude:18.723301};
 const km=routeDistanceKm(belgrade,tivat);
 assert.ok(km>270&&km<330);
 assert.equal(routeDistanceKm(belgrade,{latitude:null,longitude:null}),null);
 assert.equal(airportCoordinates({latitude:91,longitude:18}),null);
 assert.ok(WORLD_OUTLINES.length>150,'self-hosted world geography');
});
test('SVG route map renders real geography and route line using source coordinates only',()=>{
 const doc={
  createElementNS:(ns,tag)=>({tag,attrs:{},children:[],setAttribute(k,v){this.attrs[k]=v},append(...e){this.children.push(...e)}}),
  createElement:tag=>({tag,className:'',textContent:''})
 };
 const host={children:[],replaceChildren(){this.children=[]},append(el){this.children.push(el)}};
 const from={latitude:44.818401,longitude:20.309099,name:'Belgrade',code:'LYBE'};
 const to={latitude:42.404701,longitude:18.723301,name:'Tivat',code:'LYTV'};
 const outcome=renderRouteMap(host,from,to,{doc});
 assert.ok(outcome.distanceKm>270);
 assert.equal(host.children[0].tag,'svg');
 assert.ok(host.children[0].children.some(x=>x.tag==='line'&&x.attrs.stroke==='#ff6917'));
 assert.equal(renderRouteMap(host,from,{name:'Missing'},{doc}),null);
 assert.equal(host.children[0].tag,'p');
});
test('manager route page is coded and bundled, with valid map and no invented operational stats',async()=>{
 const [operations,office,builder,readModel,css]=await Promise.all([
  read('../website/airline-workspace.mjs'),
  read('../website/airline-airports-office.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),
  read('../server/player-read-service.mjs'),
  read('../website/player-app.css')
 ]);
 const view=routePlannerMarkup();
 assert.match(PLAYER_READ_SQL.airports,/from airlinerra_game\.approved_game_airports a left join/);
 assert.match(PLAYER_READ_SQL.airports,/latitude_deg::text as latitude_deg/);
 assert.match(PLAYER_READ_SQL.airports,/where a\.world_id=1/);
 for(const id of ['route-from-country','route-to-country','route-map-canvas','route-distance',
  'route-plan-save','route-plan-number','route-from-summary','route-to-summary'])assert.ok(view.includes(id),id);
 assert.match(operations,/createRoutePlanner/);
 assert.match(operations,/routePlannerMarkup\(\)/);
 assert.match(office,/createAirportCountryPicker/);
 assert.doesNotMatch(office,/id="office-find"/);
 assert.match(builder,/'route-planner.mjs'/);
 assert.match(builder,/'world-outlines.mjs'/);
 assert.match(readModel,/left join \(select world_number,airport_key,latitude_deg,longitude_deg from airlinerra\.airport_game_world1_catalog\) c on c\.airport_key=a\.airport_key/);
 assert.match(css,/route-planner-grid/);
 assert.doesNotMatch(view,/298 km|0h 47m|3,400 m|slot capacity.*high/i);
});
