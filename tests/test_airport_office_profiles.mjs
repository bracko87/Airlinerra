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
  'Current departures and arrivals','Destinations and frequencies']){
  assert.ok(office.includes(heading),heading);
 }
 for(const feature of ['runway','slots','Passenger demand (0-100%)','Cargo demand (0-100%)',
  'Time zone','Current commercial movements','Operating airlines','Station desk fee'])
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
