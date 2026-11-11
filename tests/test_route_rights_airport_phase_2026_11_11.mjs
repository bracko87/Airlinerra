import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {TRAFFIC_RIGHTS,candidateTrafficFreedoms,renderTrafficRightIndicators,trafficRightDisplayState}
 from '../website/route-traffic-rights.mjs';
import {TAXI_CATEGORY_MINUTES,estimateFlightPhaseTiming}
 from '../website/airport-flight-phase-timing.mjs';
import {estimateFivePhaseFuel} from '../website/flight-fuel-phase-engine.mjs';
import {routePlannerMarkup,routeAirportIcaoCode,routeAirportGameRules}
 from '../website/route-planner.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('nine freedoms are distinct and never equal a licence, slot or implied grant',()=>{
 assert.equal(TRAFFIC_RIGHTS.length,9);
 assert.deepEqual(TRAFFIC_RIGHTS.map(x=>x.number),[1,2,3,4,5,6,7,8,9]);
 assert.equal(new Set(TRAFFIC_RIGHTS.map(x=>x.symbol)).size,9);
 assert.deepEqual(candidateTrafficFreedoms({
  homeIso:'RS',originIso:'RS',destinationIso:'CZ'}),[3]);
 assert.deepEqual(candidateTrafficFreedoms({
  homeIso:'RS',originIso:'CZ',destinationIso:'RS'}),[4]);
 assert.deepEqual(candidateTrafficFreedoms({
  homeIso:'RS',originIso:'CZ',destinationIso:'DE'}),[7]);
 assert.deepEqual(candidateTrafficFreedoms({
  homeIso:'RS',originIso:'CZ',destinationIso:'CZ'}),[9]);
 assert.deepEqual(candidateTrafficFreedoms({
  homeIso:'RS',originIso:'RS',destinationIso:'RS'}),[]);
 assert.deepEqual(candidateTrafficFreedoms({
  homeIso:null,originIso:'RS',destinationIso:'CZ'}),[]);
});
test('relevant rights remain unverified and no approval check is invented',()=>{
 const element=tag=>({tag,children:[],attributes:{},className:'',textContent:'',
  append(...els){this.children.push(...els)},
  replaceChildren(...els){this.children=els},
  setAttribute(k,v){this.attributes[k]=v}
 });
 const doc={createElement:element},strip=element('div'),legend=element('div');
 renderTrafficRightIndicators(doc,strip,legend,{
  homeIso:'RS',originIso:'RS',destinationIso:'CZ'
 });
 assert.equal(strip.children.length,9);
 assert.equal(legend.children.length,9);
 assert.equal(strip.children[2].className,'route-right-icon is-unverified');
 assert.equal(strip.children.filter(x=>x.className.includes('is-approved')).length,0);
 assert.ok(strip.children.every((x,i)=>x.textContent===TRAFFIC_RIGHTS[i].symbol),
  'show standalone symbols only, no number beside each symbol');
 assert.ok(strip.children.every((x,i)=>x.title===TRAFFIC_RIGHTS[i].name),
  'hover label is only the name, not Freedom plus a number');
 assert.ok(strip.children.every(x=>!x.title.includes('Freedom')));
 assert.ok(strip.children.every(x=>x.attributes['aria-label'].includes('permission not yet confirmed')||
  x.attributes['aria-label'].includes('Not needed')));
 assert.equal(strip.children[2].textContent,'⇗');
 assert.equal(strip.children[2].title,'Outbound international');
});
test('traffic-right icon states respond to route geography without fabricating an approved grant',()=>{
 const element=tag=>({tag,children:[],attributes:{},className:'',textContent:'',
  append(...els){this.children.push(...els)},
  replaceChildren(...els){this.children=els},
  setAttribute(k,v){this.attributes[k]=v}
 });
 const doc={createElement:element},strip=element('div'),legend=element('div');
 const cases=[
  [{homeIso:'RS',originIso:'RS',destinationIso:'DE'},3],
  [{homeIso:'RS',originIso:'DE',destinationIso:'RS'},4],
  [{homeIso:'RS',originIso:'DE',destinationIso:'FR'},7],
  [{homeIso:'RS',originIso:'DE',destinationIso:'DE'},9]
 ];
 for(const [countries,number] of cases){
  renderTrafficRightIndicators(doc,strip,legend,countries);
  assert.equal(strip.children[number-1].className,'route-right-icon is-unverified');
  assert.equal(strip.children.filter(x=>x.className.includes('is-unverified')).length,1);
  assert.equal(strip.children.filter(x=>x.className.includes('is-approved')).length,0);
 }
 renderTrafficRightIndicators(doc,strip,legend,{
  homeIso:'RS',originIso:'RS',destinationIso:'RS'});
 assert.ok(strip.children.every(x=>x.className==='route-right-icon is-inapplicable'));
});
test('traffic-rights UI has plain colored icons and no below-icon instructions or incomplete-route text',async()=>{
 const [ui,css]=await Promise.all([
  read('website/route-planner.mjs'),read('website/player-app.css')
 ]);
 const markup=routePlannerMarkup();
 assert.match(markup,/id="route-rights-icons"/);
 assert.match(markup,/id="route-rights-info"/);
 assert.doesNotMatch(markup,/id="route-traffic-rights"|id="route-check-message"/);
 assert.doesNotMatch(markup,/class="route-rights-key"/);
 assert.doesNotMatch(ui,/Select both airports to assess possible rights|Choose two different airports\./);
 assert.match(css,/\.route-right-icon\.is-unverified,/);
 assert.match(css,/\.route-right-icon\.is-route-blocked,/);
 assert.match(css,/width:25px;height:25px;min-width:25px/);
 assert.match(css,/border:1px solid #aab8c8;border-radius:50%/);
 assert.match(css,/\.route-right-icon\.is-unverified::after\{content:'\?'/);
 assert.match(css,/\.route-right-icon\.is-approved::after\{content:'✓'/);
 assert.match(css,/\.route-right-icon\.is-route-blocked::after\{content:'✕'/);
});
test('taxi estimates depend on airport tier and are stable for identical route inputs',()=>{
 const local=estimateFlightPhaseTiming({
  originAirportCategory:'Local',destinationAirportCategory:'Local',
  originAirportKey:'A',destinationAirportKey:'B',distanceKm:800
 });
 const hub=estimateFlightPhaseTiming({
  originAirportCategory:'Mega Hub',destinationAirportCategory:'Mega Hub',
  originAirportKey:'A',destinationAirportKey:'B',distanceKm:800
 });
 assert.ok(local.taxiOutMinutes>=3&&local.taxiOutMinutes<=9);
 assert.ok(local.taxiInMinutes>=3&&local.taxiInMinutes<=6);
 assert.ok(hub.taxiOutMinutes>=15&&hub.taxiOutMinutes<=28);
 assert.ok(hub.taxiInMinutes>=11&&hub.taxiInMinutes<=19);
 assert.ok(hub.climbMinutes>=12&&hub.climbMinutes<=20);
 assert.ok(hub.descentMinutes>=12&&hub.descentMinutes<=20);
 assert.deepEqual(estimateFlightPhaseTiming({
  originAirportCategory:'Local',destinationAirportCategory:'Local',
  originAirportKey:'A',destinationAirportKey:'B',distanceKm:800
 }),local);
 assert.equal(Object.keys(TAXI_CATEGORY_MINUTES).length,6);
});
test('five-phase fuel and time share one set of airport-dependent assumptions',()=>{
 const data={distanceKm:750,cruiseSpeedKmh:840,
  emptyFuelKgPer100Km:266.6,halfFuelKgPer100Km:288.3,
  fullFuelKgPer100Km:310,payloadFraction:.5,priceUsdPerKg:.95,
  originAirportKey:'BEG',destinationAirportKey:'PRG'};
 const local=estimateFivePhaseFuel({...data,
  originAirportCategory:'Local',destinationAirportCategory:'Local'});
 const hub=estimateFivePhaseFuel({...data,
  originAirportCategory:'Mega Hub',destinationAirportCategory:'Mega Hub'});
 assert.equal(local.status,'PLANNING_ESTIMATE');
 assert.equal(hub.status,'PLANNING_ESTIMATE');
 assert.ok(local.phases[0].minutes>=3&&local.phases[0].minutes<=9);
 assert.ok(local.phases[4].minutes>=3&&local.phases[4].minutes<=6);
 assert.ok(hub.totalMinutes>local.totalMinutes);
 for(const estimate of [local,hub]){
  assert.ok(Math.abs(estimate.totalMinutes-
   (estimate.airborneMinutes+estimate.taxiMinutes))<.05);
  assert.ok(Math.abs(estimate.phases.reduce((n,p)=>n+p.distanceKm,0)-750)<.1);
  assert.ok(estimate.tripFuelKg>0);
  assert.equal(estimate.ledgerPosted,false);
  assert.equal(estimate.dispatchApproved,false);
 }
});
test('origin first, Belgrade AIP nuance, and no fake total or debug paragraphs',async()=>{
 const markup=routePlannerMarkup(),ui=await read('website/route-planner.mjs');
 assert.ok(markup.indexOf('id="route-origin-title"')<
  markup.indexOf('id="route-destination-title"'));
 assert.match(markup,/route-rights-info/);
 assert.match(markup,/route-rights-icons/);
 assert.ok(markup.indexOf('Estimated operating costs per flight')>
  markup.indexOf('Ticket prices and onboard services'));
 assert.doesNotMatch(markup,/route-aircraft-performance-grid/);
 assert.match(ui,/routeAirportGameRules\(profile\)/);
 assert.match(ui,/routeAirportIcaoCode\(profile,selected/);
 assert.doesNotMatch(ui,/Published departure noise procedures/);
 assert.doesNotMatch(ui,/return 'BEG'/);
 assert.match(ui,/Math.round\(fuel.airborneMinutes\)/);
 assert.match(ui,/aircraft\?\.cruiseSpeedKmh/);
 assert.match(ui,/NOT the complete flight cost/);
 assert.doesNotMatch(ui,/const caveat=doc.createElement\('p'\)/);
});

test('ICAO airport headings are consistent on origin and destination, never IATA BEG',()=>{
 const belgrade={iata:'BEG',icao:'LYBE',code:'LYBE'};
 const aleksandrovo={iata:null,icao:null,code:'LYAL'};
 assert.equal(routeAirportIcaoCode(belgrade,{code:'LYBE'}),'LYBE');
 assert.equal(routeAirportIcaoCode(aleksandrovo,{code:'LYAL'}),'LYAL');
 assert.equal(routeAirportIcaoCode({iata:'BEG',code:'LYBE'}),'LYBE');
 assert.equal(routeAirportIcaoCode({iata:'BEG'}),null,
  'do not display three-letter IATA code in an ICAO-only heading');
});
test('game default curfew and chapter flags display stored values without inventing chapter numbers',()=>{
 const game={operations:{simpleNightNoise:{
  nighttimeBan:false,noiseRestrictions:false,permittedChapters:[],
  sourceStatus:'AIRLINESIM_NOT_FOUND'
 },icaoNoiseRules:{prohibitedChapters:[],rules:[]}}};
 assert.deepEqual(routeAirportGameRules(game),{
  curfew:'No',noise:'No Chapter restriction'
 });
 const belgrade={operations:{simpleNightNoise:{
  nighttimeBan:false,noiseRestrictions:false,permittedChapters:[],
  sourceStatus:'AIRLINESIM_PAGE_OBSERVED'
 },icaoNoiseRules:{prohibitedChapters:[],rules:[]}}};
 assert.deepEqual(routeAirportGameRules(belgrade),{
  curfew:'No',noise:'No Chapter restriction'
 });
 const chapter={operations:{simpleNightNoise:{
  nighttimeBan:true,nighttimeWindow:'23:00-06:00',
  noiseRestrictions:true,permittedChapters:[3,14]
 },icaoNoiseRules:{prohibitedChapters:[2]}}};
 assert.deepEqual(routeAirportGameRules(chapter),{
  curfew:'Yes · 23:00–06:00',noise:'No Chapter 2'
 });
 const minimum={operations:{simpleNightNoise:{nighttimeBan:false,
  noiseRestrictions:false},icaoNoiseRules:{nationalCivilJetMinimumChapter:14}}};
 assert.equal(routeAirportGameRules(minimum).noise,'Chapter 14 minimum',
  'documented chapter overrides simplified false flag');
});
test('the player no longer sees origin warning, duplicate AIP footer or demand disclaimer',async()=>{
 const ui=await read('website/route-planner.mjs');
 const markup=routePlannerMarkup();
 assert.doesNotMatch(ui,/Published departure noise procedures|Official Serbia AIP: LYBE/);
 assert.doesNotMatch(ui,/Indicative game demand rating; not actual passenger/);
 assert.doesNotMatch(ui,/not source-verified/);
 assert.doesNotMatch(markup,/Departure stand follows previous arrival/);
 assert.match(markup,/id="route-departure-stand-derived"/,
  'retain hidden programmatic stand readout');
 assert.match(ui,/runwayAssessment\(aircraft\)/);
 assert.match(ui,/noiseCurfewCheck\(\{/);
 assert.match(ui,/gameHardBlocked===true/);
});

test('rights start grey and only applicable rights turn orange with unknown status',()=>{
 const make=tag=>({tag,className:'',textContent:'',title:'',attributes:{},children:[],
  append(...items){this.children.push(...items)},
  replaceChildren(...items){this.children=[...items]},
  setAttribute(k,v){this.attributes[k]=v}});
 const doc={createElement:make},strip=make('div'),info=make('div');
 renderTrafficRightIndicators(doc,strip,info);
 assert.equal(strip.children.length,9);
 assert.ok(strip.children.every(x=>x.className==='route-right-icon is-inapplicable'));
 assert.ok(strip.children.every(x=>x.attributes['data-right-status']==='inapplicable'));
 renderTrafficRightIndicators(doc,strip,info,{
  homeIso:'RS',originIso:'RS',destinationIso:'AL'});
 assert.equal(strip.children[2].className,'route-right-icon is-unverified');
 assert.ok(strip.children.filter(x=>x.className==='route-right-icon is-unverified').length===1);
 assert.ok(strip.children.every((x,i)=>x.title===TRAFFIC_RIGHTS[i].name));
 assert.ok(strip.children.every(x=>x.className!=='route-right-icon is-approved'));
});
test('✓ and ✕ depend on proven decisions or real airport admission blocks',()=>{
 const route={homeIso:'RS',originIso:'RS',destinationIso:'AL'};
 assert.equal(trafficRightDisplayState(3,route),'unverified');
 assert.equal(trafficRightDisplayState(4,route),'inapplicable');
 assert.equal(trafficRightDisplayState(3,{...route,verifiedDecisions:[
  {number:3,status:'granted'}]}),'unverified',
  'unsupported approval is not sufficient');
 assert.equal(trafficRightDisplayState(3,{...route,verifiedDecisions:[
  {number:3,status:'granted',sourceVerified:true}]}),'approved');
 assert.equal(trafficRightDisplayState(3,{...route,verifiedDecisions:[
  {number:3,status:'denied',sourceVerified:true}]}),'denied');
 assert.equal(trafficRightDisplayState(3,{...route,
  routeBlockReason:'Group 2 airport not admitted for commercial flights'}),'route-blocked');
 assert.equal(trafficRightDisplayState(4,{...route,
  routeBlockReason:'Group 2 airport not admitted for commercial flights'}),'inapplicable');
 const make=tag=>({tag,className:'',textContent:'',title:'',attributes:{},children:[],
  append(...items){this.children.push(...items)},
  replaceChildren(...items){this.children=[...items]},
  setAttribute(k,v){this.attributes[k]=v}});
 const doc={createElement:make},strip=make('div'),info=make('div');
 renderTrafficRightIndicators(doc,strip,info,{...route,
  routeBlockReason:'Group 2 airport not admitted for commercial flights'});
 assert.equal(strip.children[2].className,'route-right-icon is-route-blocked');
 assert.match(strip.children[2].attributes['aria-label'],/Route blocked/);
 assert.match(strip.children[2].attributes['aria-label'],/Traffic-right permission has not been decided/);
});
