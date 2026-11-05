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
  'Departures and arrivals','Airlines, flights and destinations']){
  assert.ok(office.includes(heading),heading);
 }
 for(const feature of ['runway','slots','Passenger demand','Cargo demand',
  'Time zone','Flights per day','Operating airlines','Request hub','Open station'])
  assert.ok(office.toLowerCase().includes(feature.toLowerCase()),feature);
 assert.match(office,/No airport office, staffing, fees or slots have been activated/);
 assert.match(office,/Not connected/);
 assert.match(office,/Data pending/);
 assert.match(office,/station'\?1:null/);
 assert.match(office,/if\(!live.connected\|\|!live.airline\?\.id\)/);
 assert.doesNotMatch(office,/fetch\(|from\('airlines'\)|insert\(|update\(/);
 for(const style of ['airport-office-headquarters','airport-office-list-row','airport-office-pagination',
  'airport-profile-office-actions','airport-profile-facts','airport-flight-board'])
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

test('traffic groups and nearby-airport panel do not expose daily passenger thresholds',async()=>{
 const office=await read('../website/airline-airports-office.mjs');
 const styles=await read('../website/player-app.css');
 assert.match(office,/Nearby airports within 100 km/);
 assert.match(office,/Straight-line distance, not driving distance/);
 assert.match(office,/airport-nearby-airports/);
 assert.match(office,/groupLabel\(demand\?\.passengerGroup\)/);
 assert.match(office,/groupLabel\(demand\?\.cargoGroup\)/);
 assert.doesNotMatch(office,/Passenger demand \(0-100%\)/);
 assert.doesNotMatch(office,/Cargo demand \(0-100%\)/);
 assert.match(styles,/\.airport-nearby-row/);
});
test('flight board has correct six-column order with cropped mock airline logos',async()=>{
 const [office,styles,builder]=await Promise.all([
  read('../website/airline-airports-office.mjs'),
  read('../website/player-app.css'),
  read('../website/dev-scripts/invited-overlay.mjs')
 ]);
 assert.match(office,/<span>Time<\/span><span>Flight<\/span><span>Airline<\/span><span>Logo<\/span><span>Origin \/ destination<\/span><span>Status<\/span>/);
 assert.match(office,/createAirportAirlineLogo\(doc,flight.airline,live.airline/);
 assert.match(office,/route:'Departure · Barcelona'/);
 assert.match(styles,/\.airport-airline-logo-crop\{[^}]*overflow:hidden/);
 assert.match(styles,/\.airport-flight-columns>span:last-child/);
 assert.match(builder,/'airport-network-tabs.mjs'/);
});
test('airport statistics tabs show airline lists, daily date groups, destination dropdown and cargo data without pretending to be live',async()=>{
 const [source,css]=await Promise.all([
  read('../website/airport-network-tabs.mjs'),read('../website/player-app.css')
 ]);
 const {sampleAirportDestinations}=await import('../website/airport-network-tabs.mjs');
 const destinations=sampleAirportDestinations([
  {route:'Departure · Barcelona'},{route:'Arrival · Vienna'},
  {route:'Departure · Barcelona'}
 ]);
 assert.deepEqual(destinations,['Barcelona','Vienna']);
 for(const heading of ['Airlines','Destinations','Cargo'])
  assert.ok(source.includes("'"+heading+"'"),heading);
 assert.doesNotMatch(source,/\['statistics','Statistics'\]/);
 assert.doesNotMatch(source,/function showStatistics\(/);
 assert.match(source,/createAirportNetworkTabs/);
 assert.match(source,/airport-network-destination-select/);
 assert.match(source,/No airline cargo movements have been recorded/);
 assert.match(source,/SCHEDULE_DAYS/);
 assert.match(source,/role','tab'/);
 assert.match(css,/\.airport-network-tabs/);
 assert.match(css,/data-columns="4"/);
});

test('airport statistics use five simple bars, small nearby links and subtle text tabs',async()=>{
 const [office,css,net]=await Promise.all([
  read('../website/airline-airports-office.mjs'),
  read('../website/player-app.css'),
  read('../website/airport-network-tabs.mjs')
 ]);
 assert.match(office,/className='airport-demand-bars'/);
 assert.match(office,/airport-demand-segment/);
 assert.match(office,/setAttribute\('aria-label',label\+': group '/);
 assert.ok(!office.includes("'Game airport','airport-nearby-tag'"));
 assert.match(office,/AIRPORT STATISTICS/);
 assert.match(css,/\.airport-demand-segment\.is-active\{background:#0b3d80/);
 assert.match(css,/\.airport-network-tab\[aria-selected="true"\]\{background:transparent;border-bottom-color:var\(--orange\)/);
 assert.match(css,/\.airport-network-airline-row/);
 assert.match(css,/\.airport-network-day-title/);
 assert.match(net,/airport-network-airline-list/);
 assert.match(net,/airport-network-day-empty/);
 assert.match(net,/renderDayGroups\(destination\)/);
});
test('only a signed authenticated company-logo URL replaces the illustrative mock crop',async()=>{
 const [tabs,office,operations,player]=await Promise.all([
  read('../website/airport-network-tabs.mjs'),
  read('../website/airline-airports-office.mjs'),
  read('../website/airline-operations-center.mjs'),
  read('../website/player-app.mjs')
 ]);
 assert.match(tabs,/verifiedLogoUrl\.startsWith\(signedPrefix\)/);
 assert.match(tabs,/el\(doc,'img','airport-airline-logo-actual'\)/);
 assert.match(office,/getAirlineLogoUrl\(airline.id\)/);
 assert.match(office,/networkTabs\.setOwnerLogo\(name,ownLogoUrl\)/);
 assert.match(operations,/createAirportOffice\(\{doc,identity,session,goTo,getAirlineLogoUrl\}\)/);
 assert.match(player,/getAirlineLogoUrl:airlineId=>auth\?\.getAirlineLogoUrl/);
});

test('white framed airport logos and unboxed origin are consistent across flight board and destinations',async()=>{
 const [styles,source]=await Promise.all([
  read('../website/player-app.css'),read('../website/airport-network-tabs.mjs')
 ]);
 assert.match(styles,/\.airport-airline-logo-crop\{[^}]*border:1px solid #cedae8[^}]*background:#fff/);
 assert.match(source,/fill:'#fff',rx:7/);
 assert.match(source,/el\(doc,'img','airport-airline-logo-actual'\)/);
 assert.match(source,/el\(doc,'span','airport-network-origin-name',airport\?\.name/);
 assert.doesNotMatch(source,/el\(doc,'strong','',airport\?\.name/);
 assert.match(styles,/\.airport-network-origin \.airport-network-origin-name\{[^}]*background:transparent;border:0;padding:0/);
});
test('airlines table has headers and computes honest example weekly movement shares',async()=>{
 const [source,styles]=await Promise.all([
  read('../website/airport-network-tabs.mjs'),read('../website/player-app.css')
 ]);
 const {summarizePreviewAirlineOperations}=await import('../website/airport-network-tabs.mjs');
 const {DEMO_AIRPORT_FLIGHTS}=await import('../website/airline-airports-office.mjs');
 const summary=summarizePreviewAirlineOperations(DEMO_AIRPORT_FLIGHTS);
 assert.equal(summary.length,9);
 assert.equal(summary.reduce((n,row)=>n+row.weeklyFlights,0),25);
 const panonian=summary.find(row=>row.name==='Panonian');
 assert.deepEqual(panonian,{
  name:'Panonian',weeklyFlights:6,dailyAverage:6/7,movementSharePercent:24
 });
 assert.equal(summary.reduce((n,row)=>n+row.movementSharePercent,0),100);
 assert.deepEqual(summarizePreviewAirlineOperations([]),[]);
 for(const heading of ['Airline','Logo','Flights / day','Flights / week','Share of flights'])
  assert.ok(source.includes("'"+heading+"'"),heading);
 assert.match(source,/airport-network-airline-head/);
 assert.match(styles,/\.airport-network-airline-head,.airport-network-airline-row\{display:grid;grid-template-columns:170px 145px repeat\(3/);
 assert.match(source,/sample flight movements only, not passenger market share/);
 assert.doesNotMatch(source,/\['statistics','Statistics'\]/);
});


test('registered headquarters remains unchanged; remove independent planning form and cost model',async()=>{
 const office=await read('../website/airline-airports-office.mjs');
 const hq=office.slice(office.indexOf("panel('HEADQUARTERS','Registered headquarters'"),
  office.indexOf("panel('NETWORK LOCATIONS','My hubs'"));
 assert.match(hq,/This is the airport chosen when the airline was created/);
 assert.match(hq,/id="airport-office-hq-name"/);
 assert.match(hq,/data-office-action="home-profile"/);
 assert.doesNotMatch(office,/Plan an airport office/);
 assert.doesNotMatch(office,/panel\('COST MODEL'/);
 for(const removed of ['office-country','office-search','office-result','office-location-type',
  'office-save','office-preview'])assert.ok(!office.includes("'"+removed+"'")&&!office.includes('id="'+removed+'"'),removed);
 assert.match(office,/panel\('NETWORK LOCATIONS','My hubs'/);
 assert.match(office,/panel\('AIRPORT REPRESENTATION','My stations'/);
});
test('airport profile offers safe station and hub request actions without opening offices',async()=>{
 const office=await read('../website/airline-airports-office.mjs');
 assert.match(office,/data-office-action="plan-station" disabled>Open station/);
 assert.match(office,/data-office-action="plan-hub" disabled>Request hub/);
 assert.match(office,/function refreshOfficeActions\(airport,loading=false\)/);
 assert.match(office,/airport\?\.key===live\.airline\?\.homeAirportKey/);
 assert.match(office,/activeAirport=effective/);
 assert.match(office,/proposeAirportOffice\(\{type,airport,/);
 assert.match(office,/saveSession\(session,keyForAccount\(\),\[\.\.\.entries\(\),proposed\.entry\]\)/);
 assert.match(office,/No airport office, staffing, fees or slots have been activated/);
});
test('hub and station pages list ten slim records per page with independent pagination',async()=>{
 const [office,css]=await Promise.all([
  read('../website/airline-airports-office.mjs'),read('../website/player-app.css')
 ]);
 assert.match(office,/const OFFICE_PAGE_SIZE=10;/);
 assert.match(office,/const listPages=\{hub:0,station:0\}/);
 assert.match(office,/items\.slice\(first,first\+OFFICE_PAGE_SIZE\)/);
 assert.match(office,/const pages=Math\.ceil\(items\.length\/OFFICE_PAGE_SIZE\)/);
 assert.match(office,/Math\.min\(Math\.max\(0,listPages\[type\]\),pages-1\)/);
 assert.match(office,/previous\.disabled=page===0;next\.disabled=page===pages-1/);
 assert.match(office,/action==='page'/);
 assert.match(office,/id="office-hub-pagination"/);
 assert.match(office,/id="office-station-pagination"/);
 assert.match(css,/\.airport-office-list-row\{display:grid/);
 assert.match(css,/\.airport-office-page-caption/);
});
