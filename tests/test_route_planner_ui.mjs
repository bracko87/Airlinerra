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
 // The hub/station picker was intentionally removed; airport profiles now own requests.
 assert.doesNotMatch(office,/createAirportCountryPicker/);
 assert.match(office,/airport-profile-office-buttons/);
 assert.doesNotMatch(office,/id="office-find"/);
 assert.match(builder,/'route-planner.mjs'/);
 assert.match(builder,/'world-outlines.mjs'/);
 assert.match(readModel,/left join \(select world_number,airport_key,latitude_deg,longitude_deg from airlinerra\.airport_game_world1_catalog\) c on c\.airport_key=a\.airport_key/);
 assert.match(css,/route-planner-grid/);
 assert.doesNotMatch(view,/298 km|0h 47m|3,400 m|slot capacity.*high/i);
});


test('Panonian uses provisional PA prefix while real saved airline IATA codes take priority',async()=>{
 const {flightPrefixFor,flightNumberFor,validLocalDeparture}=await import('../website/route-planner.mjs');
 assert.deepEqual(flightPrefixFor({name:'Panonian',iataCode:null}),{prefix:'PA',provisional:true});
 assert.deepEqual(flightPrefixFor({name:'Panonian',iataCode:'PN'}),{prefix:'PN',provisional:false});
 assert.deepEqual(flightPrefixFor({name:'Other Air',iataCode:null}),{prefix:null,provisional:true});
 assert.equal(flightNumberFor('PA','101'),'PA101');
 assert.equal(flightNumberFor('PA','0001'),'PA0001');
 for(const x of ['','A1B','00000','-2'])assert.equal(flightNumberFor('PA',x),null);
 assert.equal(flightNumberFor(null,'101'),null);
 assert.equal(validLocalDeparture('00:00'),true);
 assert.equal(validLocalDeparture('23:59'),true);
 assert.equal(validLocalDeparture('24:00'),false);
});
test('route planning has two steps, stacked airport lookup, real flag indicators and local weekday schedule',async()=>{
 const [ui,css,picker,work]=await Promise.all([
  read('../website/route-planner.mjs'),read('../website/player-app.css'),
  read('../website/airport-country-picker.mjs'),read('../website/airline-workspace.mjs')
 ]);
 const view=routePlannerMarkup();
 for(const id of ['route-number-prefix','route-prefix-note','route-plan-number',
  'route-from-hub','route-to-hub','route-from-country-flag','route-to-country-flag',
  'route-from-search','route-to-search','route-from-airport','route-to-airport',
  'route-plan-preview','route-map-canvas','route-aircraft','route-flights',
  'route-slot-check','route-traffic-rights','route-origin-demand','route-destination-demand',
  'route-origin-restrictions','route-destination-restrictions','route-plan-save']){
  assert.ok(view.includes('id="'+id+'"'),id);
 }
 for(let day=0;day<7;day++){
  assert.ok(view.includes('data-route-day="'+day+'"'));
  assert.ok(view.includes('data-route-time="'+day+'"'));
 }
 assert.ok(view.indexOf('route-number-prefix')<view.indexOf('route-from-hub'));
 assert.ok(view.indexOf('route-from-hub')<view.indexOf('route-to-hub'));
 assert.ok(view.indexOf('route-to-hub')<view.indexOf('route-map-canvas'));
 assert.ok(view.indexOf('route-map-canvas')<view.indexOf('route-aircraft'));
 assert.doesNotMatch(view,/AIRPORT OVERVIEW|ROUTE METRICS|PREPARE YOUR ROUTE/);
 assert.match(css,/#workspace-routes \.route-week-grid\{/);
 assert.match(css,/repeat\(7,minmax\(110px,1fr\)\)/);
 assert.match(css,/\.route-country-flag/);
 assert.match(picker,/const choose=key=>/);
 assert.match(ui,/reader\.airportProfile\(homeKey\)/);
 assert.match(ui,/pickers\[side\]\.choose\(home\.key\)/);
 assert.match(ui,/aircraftId:flightAircraft,/);
 assert.match(ui,/testAircraft:false/);
 assert.match(ui,/status:'draft',operationallyVerified:false/);
 assert.match(ui,/Aircraft, crew, airport slots and traffic rights require verification/);
 assert.match(work,/createRoutePlanner/);
});


test('country-free airport search returns approved airports across multiple countries and selects from one input',async()=>{
 const original=globalThis.Option;globalThis.Option=FakeOption;
 try{
  const country=new FakeControl(),search=new FakeControl(),airportSelect=new FakeControl();
  const results=[],calls=[],selected=[];
  const picker=createAirportCountryPicker({country,search,airport:airportSelect,
   getReader:()=>({airports:async({countryIso,search:q,offset})=>{
    calls.push({countryIso,q,offset});
    return {countryIso:'',airports:[
     {...airport('OURAIRPORTS:2155','Brussels Airport','EBBR','BE'),latitude:50.901402,longitude:4.48444},
     {...airport('OURAIRPORTS:111','Brussels South Airport','EBCI','BE'),latitude:50.459,longitude:4.453},
     {...airport('OURAIRPORTS:4610','Belgrade Brussels Example','LYXX','RS'),latitude:44.8,longitude:20.3}
    ],nextOffset:null};
   }}),
   onResults:(list,ready)=>{if(ready)results.push(list)},
   onSelect:choice=>selected.push(choice?.key||null)
  });
  country.value='';search.value='brus';await picker.load();
  assert.equal(calls.length,1);
  assert.deepEqual(calls[0],{countryIso:'',q:'brus',offset:0});
  assert.equal(picker.getAirports().length,3);
  assert.equal(results.at(-1).length,3);
  assert.equal(picker.choose('OURAIRPORTS:2155'),true);
  assert.equal(picker.selected().name,'Brussels Airport');
  assert.equal(search.value,'Brussels Airport');
  assert.equal(selected.at(-1),'OURAIRPORTS:2155');
 }finally{globalThis.Option=original}
});
test('airports now use one visible autocomplete, actual-image country flags and route facts below map',async()=>{
 const [src,style,map]=await Promise.all([
  read('../website/route-planner.mjs'),read('../website/player-app.css'),read('../website/route-map.mjs')
 ]);
 const ui=routePlannerMarkup();
 for(const side of ['from','to']){
  assert.match(ui,new RegExp('id="route-'+side+'-country-list"'));
  assert.match(ui,new RegExp('id="route-'+side+'-suggestions"'));
  assert.match(ui,new RegExp('id="route-'+side+'-search"'));
  assert.match(ui,new RegExp('id="route-'+side+'-airport" class="route-native-airport"'));
  assert.match(ui,new RegExp('id="route-'+side+'-country" tabindex="-1"'));
 }
 assert.match(src,/button\.dataset\.routeCountryChoice=side/);
 assert.match(src,/flagcdn\.com\/w40/);
 assert.match(src,/button\.dataset\.routeAirportKey=a\.key/);
 assert.match(src,/onResults:\(results,ready\)=>renderSuggestions/);
 assert.match(src,/p\?\.key===a\.key&&typeof p\.latitude==='number'/);
 assert.match(src,/drawMap\(\);/);
 const mapPos=ui.indexOf('route-map-canvas');
 const detailsPos=ui.indexOf('Route information and limitations');
 const schedulePos=ui.indexOf('STEP 2');
 assert.ok(mapPos>=0&&detailsPos>mapPos&&schedulePos>detailsPos);
 assert.match(style,/\.route-native-country,\.route-native-airport\{display:none!important\}/);
 assert.match(style,/\.route-country-list,\.route-airport-suggestions\{position:absolute/);
 assert.match(map,/WORLD_BORDER_LINES_50M/);
 assert.match(map,/stroke:'#315c85'/);
 assert.match(map,/stroke:'#ff6917'/);
});


test('route aircraft dropdown lists only owner-scoped operational fleet, not test or catalogue models',async()=>{
 const [route,office,styles]=await Promise.all([
  read('../website/route-planner.mjs'),
  read('../website/airline-workspace.mjs'),
  read('../website/player-app.css')
 ]);
 assert.match(route,/for\(const aircraft of ownedFleet\)/);
 assert.match(route,/!\['owned','leased'\]\.includes\(aircraft\.ownershipType\)/);
 assert.doesNotMatch(route,/select\.add\(new Option\('TEST ONLY/);
 assert.doesNotMatch(route,/\(catalog preview\)/);
 assert.match(route,/aircraftId:flightAircraft,/);
 assert.match(route,/testAircraft:false/);
 assert.match(route,/status:'draft',operationallyVerified:false/);
 assert.match(route,/cannot use the route|cannot be used on this route/);
 assert.match(office,/id="fleet-test-count"/);
 assert.match(office,/id="fleet-test-aircraft"/);
 assert.match(office,/testOnly===true&&a\.operationallyAllowed===false/);
 assert.match(styles,/#workspace-routes>\.route-planner-first-step\+\.route-planner-panel\{/);
 assert.match(styles,/margin-top:28px/);
 assert.match(styles,/\.fleet-test-aircraft-row\{display:flex/);
});


test('three-step flight draft screen includes daily aircraft assignments and prices without fabricated flight calculations',async()=>{
 const ui=routePlannerMarkup(),source=await read('../website/route-planner.mjs');
 for(const id of ['route-departure-stand-derived','route-arrival-stand','route-turnaround',
  'route-cruise-speed','route-airborne-time','route-min-turnaround','route-rotation-check',
  'route-fare-economy','route-fare-premium','route-fare-business','route-fare-first',
  'route-onboard-service','route-baggage-service','route-cargo-service',
  'route-plan-save','route-plan-new']){
  assert.ok(ui.includes('id="'+id+'"'),id);
 }
 assert.ok(ui.indexOf('STEP 2')<ui.indexOf('STEP 3'));
 assert.ok(ui.indexOf('route-turnaround')<ui.indexOf('route-week-grid'));
 for(let day=0;day<7;day++){
  assert.ok(ui.includes('data-route-day="'+day+'"'));
  assert.ok(ui.includes('data-route-time="'+day+'"'));
  assert.ok(ui.includes('id="route-arrival-'+day+'"'));
  assert.ok(ui.includes('id="route-stand-'+day+'"'));
  assert.ok(ui.includes('id="route-arrival-stand-'+day+'"'));
  assert.ok(ui.includes('id="route-next-departure-'+day+'"'));
 }
 assert.match(source,/status:'draft',operationallyVerified:false/);
 assert.match(source,/await resetRouteForm\(\)/);
 assert.match(source,/airlinerra:edit-route-draft/);
 assert.match(ui,/Pending verified performance/);
 assert.doesNotMatch(ui,/Apply schedule settings|Reserve flights/);
});
test('route fare and service draft validation limits values without implying live bookings',async()=>{
 const {validateFlightDraftOptions,routeWeekdays}=await import('../website/route-planner.mjs');
 const good={
  arrivalStand:'terminal',turnaroundMinutes:60,
  fares:{economy:'100',premium:'',business:'200',first:null},
  onboard:'standard',baggage:'checked',cargo:'requested'
 };
 const result=validateFlightDraftOptions(good);
 assert.equal(result.operationallyVerified,false);
 assert.deepEqual(result.fares,{economy:100,premium:null,business:200,first:null});
 assert.equal(result.departureStand,'terminal');
 assert.equal(result.arrivalStand,'terminal');
 assert.equal(result.turnaroundMinutes,60);
 for(const bad of [
  {...good,turnaroundMinutes:30},{...good,turnaroundMinutes:361},
  {...good,departureStand:'invalid'},{...good,arrivalStand:'invalid'},{...good,onboard:'unsafe'},
  {...good,fares:{...good.fares,economy:'101.5'}},
  {...good,fares:{...good.fares,first:'-1'}},
  {...good,fares:{...good.fares,business:'100001'}}
 ])assert.equal(validateFlightDraftOptions(bad),null);
 assert.deepEqual(routeWeekdays([{day:0,time:'09:00'},{day:2,time:'11:20'}]).filter(x=>x.active).map(x=>x.label),
  ['Mo','We']);
});
test('My Routes is a plain one-line table with weekday indicators and a text edit link',async()=>{
 const [operations,styles]=await Promise.all([
  read('../website/airline-operations-center.mjs'),
  read('../website/player-app.css')
 ]);
 assert.match(operations,/operations-route-directory-row/);
 assert.match(operations,/const headings=\['Flight','City to city','Departure','Arrival','Aircraft','Weekly days','More'\]/);
 assert.match(operations,/className='operations-route-open-text'/);
 assert.match(operations,/data[s]et\.opsRouteEdit/);
 assert.match(operations,/goTo\?\.\('routes'\)/);
 assert.match(operations,/airlinerra:edit-route-draft/);
 assert.match(styles,/\.operations-route-directory-row\{/);
 assert.match(styles,/#player-main \.route-text-action,#player-main \.operations-route-open-text/);
});


test('saved legacy route ideas remain editable while applied drafts reset the form',async()=>{
 const src=await read('../website/route-planner.mjs');
 assert.match(src,/editingLegacyIndex=null/);
 assert.match(src,/editingLegacyIndex=route\.flightNumber\?null:index/);
 assert.match(src,/i!==editingLegacyIndex/);
 assert.match(src,/message\('route-plan-status',route\.flightNumber\?/);
 assert.match(src,/await resetRouteForm\(\)/);
 assert.match(src,/showDetails\(\);/);
 const css=await read('../website/player-app.css');
 assert.match(css,/#player-main \.operations-route-directory-row \.operations-route-open-text\{/);
 assert.match(css,/justify-self:end/);
});


test('Step 2 inherits departure stand and keeps arrival stand selector, including remote stands',async()=>{
 const source=await read('../website/route-planner.mjs');
 const markup=routePlannerMarkup();
 assert.equal(markup.includes('id="route-departure-stand"'),false);
 assert.match(markup,/Remote stand \(lower fees\)/);
 assert.ok(markup.includes('id="route-departure-stand-derived"'));
 assert.ok(markup.includes('id="route-aircraft-position-status"'));
 assert.ok(markup.includes('id="route-aircraft-timeline-content"'));
 assert.match(source,/const timeline=selectedAircraftTimeline\(\)/);
 assert.match(source,/if\(timeline\.errors\.length\)/);
 assert.match(source,/Aircraft schedule conflict:/);
 assert.match(source,/departureStand:departureStandFromTimeline\(selectedAircraftTimeline\(\)\)/);
 assert.match(source,/arrivalStand:\$\('route-arrival-stand'\)\?\.value/);
 assert.match(source,/renderAircraftWeeklyTimeline\(doc,\$\('route-aircraft-timeline-content'\),timeline\)/);
 const office=await read('../website/airline-workspace.mjs');
 assert.match(office,/fleet-aircraft-timeline-content/);
 assert.match(office,/data-fleet-aircraft-timeline/);
 assert.match(office,/buildAircraftWeeklyTimeline\(\{aircraftId,routes,/);
});


test('route planner initializes both airport pickers without an early preflight crash',async()=>{
 const {createRoutePlanner}=await import('../website/route-planner.mjs');
 const originalOption=globalThis.Option;
 globalThis.Option=FakeOption;
 try{
  const nodes=new Map();
  class StubNode extends FakeControl{
   constructor(){
    super();
    this.dataset={};this.hidden=false;this.checked=false;
    this.classList={toggle(){},add(){},remove(){}};
   }
   append(...items){this.children.push(...items)}
   setAttribute(){}
   removeAttribute(){}
   querySelectorAll(){return []}
   querySelector(){return null}
  }
  const node=id=>{
   if(!nodes.has(id))nodes.set(id,new StubNode());
   return nodes.get(id);
  };
  const doc={
   getElementById:node,
   createElement:()=>new StubNode(),
   querySelector:()=>null,
   addEventListener(){}
  };
  const planner=createRoutePlanner({
   doc,getData:()=>({connected:false,airline:null}),
   loadDraft:()=>({}),draftWrite:()=>true
  });
  assert.equal(typeof planner.updateData,'function');
  assert.equal(planner.selected('from'),null);
  assert.equal(planner.selected('to'),null);
  assert.match(node('route-preflight-status').textContent,
   /Select two different airports and an aircraft/);
 }finally{globalThis.Option=originalOption}
});

test('next departure calculation uses entered UTC arrival plus turnaround, never guesses a duration',async()=>{
 const {exampleNextDepartureUtc}=await import('../website/route-planner.mjs');
 assert.deepEqual(exampleNextDepartureUtc('2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',45),{
  iso:'2026-11-09T10:45:00.000Z',clock:'10:45 UTC',arrivalClock:'10:00 UTC'});
 assert.equal(exampleNextDepartureUtc(null,null,45),null);
 assert.equal(exampleNextDepartureUtc('2026-11-09T10:00:00Z','2026-11-09T09:00:00Z',45),null);
 assert.equal(exampleNextDepartureUtc('2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',30),null);
 const markup=routePlannerMarkup();
 assert.equal(markup.includes("section('AIRPORT RESTRICTIONS'"),false);
 assert.match(markup,/route-inline-restrictions/);
});
