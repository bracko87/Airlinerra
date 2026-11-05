import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {normalizeApprovedAirport,proposeAirportOffice} from '../website/airline-airports-office.mjs';
import {PLAYER_VIEWS} from '../website/player-app-model.mjs';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
const belgrade={key:'OURAIRPORTS:4343',name:'Belgrade Nikola Tesla Airport',code:'LYBE',
 countryIso:'RS',municipality:'Belgrade'};
const sarajevo={key:'OURAIRPORTS:4344',name:'Sarajevo International Airport',code:'LQSA',
 countryIso:'BA',municipality:'Sarajevo'};
test('HQ, hub, station proposal rules preserve the registered headquarters',()=>{
 assert.deepEqual(normalizeApprovedAirport(belgrade),belgrade);
 assert.equal(normalizeApprovedAirport({key:'invalid',name:'Bad'}),null);
 assert.equal(proposeAirportOffice({type:'hub',airport:belgrade,homeAirportKey:belgrade.key}).ok,false);
 const hub=proposeAirportOffice({type:'hub',airport:sarajevo,homeAirportKey:belgrade.key,existing:[]});
 assert.equal(hub.ok,true);
 assert.equal(hub.entry.status,'draft');
 assert.equal(hub.entry.type,'hub');
 assert.equal(hub.entry.minimumStaff,null);
 const station=proposeAirportOffice({type:'station',airport:sarajevo,homeAirportKey:belgrade.key,existing:[]});
 assert.equal(station.ok,true);
 assert.equal(station.entry.minimumStaff,1);
 assert.equal(proposeAirportOffice({type:'station',airport:sarajevo,homeAirportKey:belgrade.key,existing:[hub.entry]}).ok,false);
 assert.equal(proposeAirportOffice({type:'airport',airport:sarajevo}).ok,false);
 assert.equal(proposeAirportOffice({type:'station',airport:{...sarajevo,countryIso:null}}).ok,false);
});
test('airport detail view, catalog open buttons and build bundle are registered',async()=>{
 const [html,player,builder,operations,model]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),
  read('../website/airline-operations-center.mjs'),read('../website/player-app-model.mjs')
 ]);
 assert.equal(PLAYER_VIEWS.length,23);
 assert.ok(PLAYER_VIEWS.includes('airport-profile'));
 assert.match(html,/data-player-view="airport-profile"/);
 assert.match(html,/id="workspace-airport-profile"/);
 assert.match(html,/data-view-link="airport-profile"/);
 assert.match(player,/operationsController\?\.openAirport\(airport\)/);
 assert.match(builder,/'airline-airports-office.mjs'/);
 assert.match(operations,/import \{createAirportOffice\} from '.\/airline-airports-office.mjs'/);
 assert.match(operations,/airportOfficeController=createAirportOffice/);
 assert.match(model,/'airport-profile'/);
});
test('headquarters, hubs, stations are distinct - with honest missing operational data',async()=>{
 const [office,styles]=await Promise.all([
  read('../website/airline-airports-office.mjs'),
  read('../website/player-app.css')
 ]);
 for(const heading of ['Registered headquarters','My hubs','My stations','Airport profile',
  'Runways, terminals and slots','Passenger and cargo demand','Airlines and airport presence',
  'Departures and arrivals','Destinations and frequencies']){
  assert.ok(office.includes(heading),heading);
 }
 for(const feature of ['runway','slots','Passenger demand (0-100%)','Cargo demand (0-100%)',
  'Time zone','Flights per day','Operating airlines','Station desk fee'])
  assert.ok(office.toLowerCase().includes(feature.toLowerCase()),feature);
 assert.match(office,/No fees or salaries were charged/);
 assert.match(office,/Not connected/);
 assert.match(office,/Data pending/);
 assert.match(office,/station'\?1:null/);
 assert.match(office,/if\(!live.connected\|\|!live.airline\?\.id\)/);
 assert.doesNotMatch(office,/fetch\(|from\('airlines'\)|insert\(|update\(/);
 for(const style of ['airport-office-headquarters','airport-office-cost-grid','airport-profile-facts','airport-flight-board'])
  assert.ok(styles.includes(style),style);
});

test('airport profile hides internal labels and places weather and country flag in header',async()=>{
 const [html,office,styles]=await Promise.all([
  read('../website/private-player-app.html'),
  read('../website/airline-airports-office.mjs'),
  read('../website/player-app.css')
 ]);
 assert.match(html,/class="airport-profile-back" data-office-action="back"/);
 assert.match(html,/airport-profile-navline/);
 assert.match(office,/id="airport-weather-summary-temperature"/);
 assert.match(office,/id="airport-weather-summary-conditions"/);
 assert.match(office,/id="airport-weather-summary-wind"/);
 assert.match(office,/https:\/\/flagcdn\.com\/w40\//);
 for(const label of ["['Name verification'","['Region'","['Game world'","['Catalog key'"])
  assert.ok(!office.includes(label),label);
 assert.ok(!office.includes('World 1 approved airport'));
 assert.ok(!office.includes(' (source-reported; unverified)'));
 assert.match(office,/\['Airport category',category\]/);
 assert.match(office,/\['Time zone',tz\]/);
 assert.match(office,/\['Elevation',elevation\]/);
 assert.match(office,/Forecast source: /);
 assert.match(styles,/\.airport-profile-weather-summary/);
});

test('header weather icon is bounded to a compact 30px vector',async()=>{
 const styles=await read('../website/player-app.css');
 assert.match(styles,/\.airport-weather-icon\{[^}]*width:30px;height:30px/);
 assert.match(styles,/\.airport-weather-summary-main\{[^}]*display:flex/);
});

test('airport profile uses a left-side detail list and a right-side country-outline map',async()=>{
 const [office,css,map]=await Promise.all([
  read('../website/airline-airports-office.mjs'),
  read('../website/player-app.css'),
  read('../website/route-map.mjs')
 ]);
 const start=office.indexOf("profileField('airport-profile-facts',[");
 const end=office.indexOf("]);",start);
 assert.ok(start>0 && end>start);
 const fields=office.slice(start,end);
 assert.deepEqual([...fields.matchAll(/\['([^']+)',/g)].map(m=>m[1]),[
  'Airport name','ICAO code','IATA code','Country','Municipality',
  'Airport category','Time zone','Latitude / longitude','Elevation'
 ]);
 assert.doesNotMatch(fields,/Airport code/);
 assert.match(office,/id="airport-profile-map"/);
 assert.match(office,/renderAirportLocationMap\(/);
 assert.match(office,/class="airport-weather-summary-details"/);
 assert.match(css,/\.airport-profile-main\{display:grid;grid-template-columns/);
 assert.match(css,/\.airport-office-panel \.airport-profile-head\{background:transparent/);
 assert.match(css,/\.airport-weather-summary-details\{display:flex/);
 assert.match(map,/export function renderAirportLocationMap\(/);
 assert.match(map,/WORLD_OUTLINES/);
 assert.match(map,/fill:'#ff6917'/);
});

test('airport profile is a shared airport view with ten explicitly fictional flights',async()=>{
 const [source,styles,builder,routeMap,borders]=await Promise.all([
  read('../website/airline-airports-office.mjs'),
  read('../website/player-app.css'),
  read('../website/dev-scripts/invited-overlay.mjs'),
  read('../website/route-map.mjs'),
  read('../website/world-borders-50m.mjs')
 ]);
 const {DEMO_AIRPORT_FLIGHTS}=await import('../website/airline-airports-office.mjs');
 assert.equal(DEMO_AIRPORT_FLIGHTS.length,10);
 assert.ok(DEMO_AIRPORT_FLIGHTS.some(f=>f.airline==='Panonian'));
 assert.match(source,/Fictional preview/);
 assert.match(source,/renderDemoFlightBoard\(\)/);
 assert.match(source,/airportActivity/);
 assert.doesNotMatch(source,/Your verified airline headquarters/);
 assert.doesNotMatch(source,/Your planned office/);
 assert.match(styles,/\.airport-flight-sample-row/);
 assert.match(builder,/'world-borders-50m.mjs'/);
 assert.match(routeMap,/WORLD_BORDER_LINES_50M/);
 assert.match(routeMap,/C-3-5-9-11-9-17/);
 assert.match(borders,/Natural Earth 1:50m/);
});
