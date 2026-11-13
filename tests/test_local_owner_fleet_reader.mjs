import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createLiveReadOnlyPreviewHandler,allowedLocalOwnerRead}
 from '../website/dev-scripts/real-player-read-gateway.mjs';
import {createLocalOwnerFleetReaders} from '../website/local-owner-fleet-reader.mjs';
import {initialCabinState,createBasicCabinPackage,cleanCabinState} from '../website/cabin-services-manager.mjs';

const AIRLINE='9c5c6aff-588f-4d25-abe5-dd91efc2e0d1';
const AIRCRAFT='a4547aef-e5a6-4362-8b2b-fbdf96d21907';
const TOKEN='x'.repeat(40),LOCAL='http://localhost:5188';
const pathFleet='/api/v1/player/fleet-acquisition';
const pathSchedule='/api/v1/player/flight-schedule-drafts';
const request=(path,payload,auth=TOKEN)=>new Request(LOCAL+path,{
 method:'POST',headers:{
  origin:LOCAL,authorization:'Bearer '+auth,'content-type':'application/json'
 },body:JSON.stringify(payload)
});

test('local gateway forwards only owner-scoped real fleet/schedule reads, never acquisitions',async()=>{
 const calls=[];
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,options)=>{
  calls.push({url,body:JSON.parse(options.body),route:options.headers['x-airlinerra-route']});
  return Response.json({airlineId:AIRLINE,fleet:[
   {id:AIRCRAFT,configurationId:16,registration:'YU-PAN01',ownershipType:'owned',fleetStatus:'in_service'}
  ],drafts:[],offers:[]});
 }});
 const fleet=await handler(request(pathFleet,{action:'list',airlineId:AIRLINE}));
 assert.equal(fleet.status,200);
 assert.equal((await fleet.json()).fleet[0].registration,'YU-PAN01');
 const schedule=await handler(request(pathSchedule,{action:'list',airlineId:AIRLINE}));
 assert.equal(schedule.status,200);
 assert.equal(calls.length,2);
 assert.equal(calls[0].url,'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-fleet-acquisition');
 assert.equal(calls[1].url,'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts');
 assert.equal(calls[0].route,pathFleet);
 assert.equal(calls[1].route,pathSchedule);
 for(const bad of [
  request(pathFleet,{action:'acquire',airlineId:AIRLINE,registration:'YU-PAN02'}),
  request(pathFleet,{action:'check-delivery',airlineId:AIRLINE,orderId:AIRCRAFT}),
  request(pathSchedule,{action:'save',airlineId:AIRLINE}),
  request(pathSchedule,{action:'delete',airlineId:AIRLINE}),
  request(pathSchedule,{action:'commercial-save',airlineId:AIRLINE}),
  request(pathFleet,{action:'list',airlineId:AIRLINE,priceUsd:0})
 ])assert.equal((await handler(bad)).status,403);
 assert.equal(calls.length,2,'no write must reach Supabase');
 assert.equal((await handler(request(pathFleet,{action:'list',airlineId:AIRLINE},'bad'))).status,401);
});

test('slot preflight remains readable but cannot reserve or save a route',async()=>{
 const payload={action:'slot-check',airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
  originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'OURAIRPORTS:4611',
  referenceDepartureUtc:'2026-11-11T09:00:00Z',
  referenceArrivalUtc:'2026-11-11T10:00:00Z',
  weeklySchedule:[{day:0,time:'09:00'}],
  departureStand:'terminal',arrivalStand:'terminal'};
 assert.equal(allowedLocalOwnerRead(pathSchedule,payload),true);
 assert.equal(allowedLocalOwnerRead(pathSchedule,{...payload,action:'save'}),false);
 let forwarded=0;
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,opts)=>{
  forwarded++;
  assert.equal(JSON.parse(opts.body).action,'slot-check');
  return Response.json({available:true,departureAvailable:true,arrivalAvailable:true});
 }});
 const response=await handler(request(pathSchedule,payload));
 assert.equal(response.status,200);
 assert.equal((await response.json()).available,true);
 assert.equal(forwarded,1);
});

test('local fleet reader uses signed-in Auth and exposes no purchase, inspection or schedule writes',async()=>{
 const calls=[];
 const clients=createLocalOwnerFleetReaders({auth:{getAccessToken:async()=>TOKEN},
  origin:LOCAL,fetchImpl:async(url,options)=>{
   calls.push({url,options});
   return Response.json({airlineId:AIRLINE,fleet:[],offers:[],drafts:[]});
  }});
 await clients.fleetClient.list(AIRLINE);
 await clients.scheduler.list(AIRLINE);
 assert.equal(calls.length,2);
 assert.equal(calls[0].url,LOCAL+pathFleet);
 assert.equal(calls[1].url,LOCAL+pathSchedule);
 for(const c of calls){
  assert.equal(c.options.headers.authorization,'Bearer '+TOKEN);
  assert.equal(c.options.mode,'same-origin');
  assert.equal(c.options.credentials,'omit');
 }
 assert.equal(clients.fleetClient.acquire,undefined);
 assert.equal(clients.fleetClient.checkDelivery,undefined);
 assert.equal(clients.scheduler.save,undefined);
 assert.equal(clients.scheduler.delete,undefined);
 assert.throws(()=>createLocalOwnerFleetReaders({auth:{getAccessToken:async()=>TOKEN},
  origin:'https://airlinerra.com'}),/Verified localhost session/);
});

test('actual player startup connects the local read-only owner fleet to the workspace',async()=>{
 const [app,overlay,sql]=await Promise.all([
  readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8'),
  readFile(new URL('../supabase/migrations/20261110104500_world1_panonian_initial_a319_allocation.sql',import.meta.url),'utf8')
 ]);
 assert.match(app,/createLocalOwnerFleetReaders\(/);
 assert.match(app,/fleetClient=localReaders\?\.fleetClient/);
 assert.match(app,/scheduler=localReaders\?\.scheduler/);
 assert.match(overlay,/'local-owner-fleet-reader\.mjs'/);
 assert.match(sql,/initial_aircraft_allocations_v1/);
 assert.match(sql,/owned','in_service'/);
 assert.match(sql,/DELETE FROM airlinerra_game\.airline_aircraft_test_fixtures/);
 assert.doesNotMatch(sql,/UPDATE airlinerra_game\.airlines\s+SET cash/);
 assert.doesNotMatch(sql,/inspection_status='approved'/);
});

test('localhost allows owner-validated refit estimate and quote reload but never bookings',async()=>{
 const requestId='44444444-4444-4444-8444-444444444444';
 const quote={action:'cabin-prepare-quote',airlineId:AIRLINE,
  aircraftInventoryId:AIRCRAFT,airportKey:'OURAIRPORTS:15',
  providerKey:'lht-sofia',requestId};
 const status={action:'cabin-quote-status',airlineId:AIRLINE,
  aircraftInventoryId:AIRCRAFT};
 assert.equal(allowedLocalOwnerRead(pathFleet,quote),true);
 assert.equal(allowedLocalOwnerRead(pathFleet,status),true);
 for(const bad of [{...quote,quotedCostUsd:'1'},
   {...quote,airlineCashOverride:100000},
   {...status,playerId:'spoofed'},
   {...status,approved:true},
   {action:'cabin-book-refit',airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT}])
  assert.equal(allowedLocalOwnerRead(pathFleet,bad),false);
 const seen=[];
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,opts)=>{
  seen.push({url,body:JSON.parse(opts.body)});
  return Response.json({status:'prepared_not_booked',appointmentBooked:false,
   moneyCharged:false,installedSeatsChanged:false});
 }});
 assert.equal((await handler(request(pathFleet,quote))).status,200);
 assert.equal((await handler(request(pathFleet,status))).status,200);
 assert.deepEqual(seen.map(x=>x.body.action),['cabin-prepare-quote','cabin-quote-status']);
 assert.equal((await handler(request(pathFleet,{action:'cabin-book-refit',
  airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT}))).status,403);
 const calls=[];
 const local=createLocalOwnerFleetReaders({auth:{getAccessToken:async()=>TOKEN},
  origin:LOCAL,fetchImpl:async(url,opts)=>{
   calls.push(JSON.parse(opts.body));
   return Response.json({status:'prepared_not_booked'});
  }});
 await local.fleetClient.prepareCabinRefitQuote({
  airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
  airportKey:'OURAIRPORTS:15',providerKey:'lht-sofia',requestId});
 await local.fleetClient.cabinRefitQuoteStatus({
  airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT});
 assert.deepEqual(calls.map(x=>x.action),['cabin-prepare-quote','cabin-quote-status']);
 assert.equal(local.fleetClient.bookRefit,undefined);
});

test('localhost owner can save validated cabin packages to Supabase, not only browser storage',async()=>{
 const path='/api/v1/player/cabin-services',state=initialCabinState();
 const basic=createBasicCabinPackage();
 state.packages.push({...basic,id:'pkg-1',name:'New flight package',locked:false,
  items:structuredClone(basic.items)});
 const canonicalState=cleanCabinState(state);
 const actions=[];
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,options)=>{
  const body=JSON.parse(options.body);
  actions.push(body.action);
  assert.equal(url,'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-cabin-services');
  assert.equal(options.headers['x-airlinerra-route'],path);
  assert.equal(options.headers.origin,'https://airlinerra.com');
  assert.equal(options.headers.authorization,'Bearer '+TOKEN);
  return Response.json({source:'supabase',operational:false,state:canonicalState,
   version:body.action==='save'?1:0});
 }});
 const read={action:'read',airlineId:AIRLINE};
 const save={action:'save',airlineId:AIRLINE,state:canonicalState,expectedVersion:0};
 assert.equal(allowedLocalOwnerRead(path,read),true);
 assert.equal(allowedLocalOwnerRead(path,save),true);
 assert.equal((await handler(request(path,read))).status,200);
 const response=await handler(request(path,save));
 assert.equal(response.status,200);
 assert.equal((await response.json()).version,1);
 assert.deepEqual(actions,['read','save']);
 assert.equal(allowedLocalOwnerRead(path,{...save,expectedVersion:-1}),false);
 assert.equal(allowedLocalOwnerRead(path,{...save,flightActivated:true}),false);
 assert.equal((await handler(request(path,{action:'activate',airlineId:AIRLINE}))).status,403);
 assert.equal((await handler(request(path,{action:'save',airlineId:AIRLINE,
  state:{...state,operational:true},expectedVersion:0}))).status,403);
 assert.deepEqual(actions,['read','save'],'invalid cabin requests never reach the server');
 const [server,app]=await Promise.all([
  readFile(new URL('../website/dev-scripts/dev.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8')
 ]);
 assert.match(server,/pathname==='\/api\/v1\/player\/cabin-services'\?16384:2048/);
 assert.match(app,/local&&window\.location\.origin===LOCAL_REAL_AUTH_ORIGIN/);
});

test('localhost route planner displays the precise Supabase 409 cause and preserves launch preference',async()=>{
 const calls=[],local=createLocalOwnerFleetReaders({
  auth:{getAccessToken:async()=>TOKEN},origin:LOCAL,
  fetchImpl:async(url,options)=>{
   const requestBody=JSON.parse(options.body);calls.push(requestBody);
   return Response.json({error:'ROUTE_PLANNING_REQUIREMENTS_NOT_MET',
    reason:'CABIN_PACKAGE_NOT_SAVED'},{status:409});
  }
 });
 const draft={
  airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
  flightNumber:'PA400',originAirportKey:'OURAIRPORTS:4610',
  destinationAirportKey:'OURAIRPORTS:4615',
  weeklySchedule:[{day:0,time:'06:00'}],
  departureStand:'terminal',arrivalStand:'terminal',turnaroundMinutes:45,
  fares:{economy:45,premium:null,business:null,first:null},
  service:{onboard:'basic',baggage:'standard',cargo:'none',cabinPackageId:'pkg-1'},
  launchDelayDays:3,referenceDepartureUtc:null,referenceArrivalUtc:null
 };
 await assert.rejects(()=>local.scheduler.planSave(draft),/SCHEDULE_CONFLICT_CABIN_PACKAGE_NOT_SAVED/);
 assert.equal(calls.length,1);
 assert.equal(calls[0].launchDelayDays,3);
 assert.equal(allowedLocalOwnerRead(pathSchedule,calls[0]),true);
});


test('localhost used-aircraft profile opens from a signed-in auction listing without enabling purchases',async()=>{
 const LISTING='fab819e6-cd24-4e50-af80-2745b29e4031';
 const detail={action:'used-detail',airlineId:AIRLINE,listingId:LISTING};
 const invalid=[
  {...detail,listingId:'not-an-aircraft'},
  {...detail,airlineId:'not-an-airline'},
  {...detail,playerId:'override'},
  {...detail,priceUsd:0},
  {...detail,action:'bid-used'},
  {...detail,action:'acquire'}
 ];
 assert.equal(allowedLocalOwnerRead(pathFleet,detail),true,
  'single-aircraft detail is a permitted owner-verified local read');
 for(const payload of invalid)
  assert.equal(allowedLocalOwnerRead(pathFleet,payload),false,
   'invalid or write-capable request is blocked');

 const forwarded=[];
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,opts)=>{
  forwarded.push({url,opts});
  return Response.json({airlineId:AIRLINE,readOnly:true,marketOpen:false,
   offer:{listingId:LISTING,manufacturer:'Airbus',model:'A300-600F',
    useType:'cargo',conditionPct:'81',manufactureYear:2002,
    openingBidUsd:'21030000',rangeKm:'7500',cabinSnapshot:null}});
 }});
 const response=await handler(request(pathFleet,detail));
 assert.equal(response.status,200);
 assert.equal((await response.json()).offer.listingId,LISTING);
 assert.equal(forwarded.length,1);
 assert.equal(forwarded[0].url,
  'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-fleet-acquisition');
 assert.equal(forwarded[0].opts.headers['x-airlinerra-route'],pathFleet);
 assert.equal(forwarded[0].opts.headers.authorization,'Bearer '+TOKEN);
 assert.equal(forwarded[0].opts.headers.origin,'https://airlinerra.com');
 assert.equal((await handler(request(pathFleet,{...detail,action:'bid-used'}))).status,403);
 assert.equal(forwarded.length,1,'no invalid write reaches the protected service');

 const outgoing=[];
 const local=createLocalOwnerFleetReaders({auth:{getAccessToken:async()=>TOKEN},
  origin:LOCAL,fetchImpl:async(url,opts)=>{
   outgoing.push({url,payload:JSON.parse(opts.body),auth:opts.headers.authorization});
   return Response.json({airlineId:AIRLINE,readOnly:true,
    offer:{listingId:LISTING,model:'A300-600F'}});
  }});
 const viewed=await local.fleetClient.usedDetail({airlineId:AIRLINE,listingId:LISTING});
 assert.equal(viewed.readOnly,true);
 assert.equal(viewed.offer.listingId,LISTING);
 assert.deepEqual(outgoing.map(x=>x.payload),[detail]);
 assert.equal(outgoing[0].url,LOCAL+pathFleet);
 assert.equal(outgoing[0].auth,'Bearer '+TOKEN);
 assert.equal(local.fleetClient.bidUsed,undefined);
 assert.equal(local.fleetClient.acquire,undefined);
});

test('local profile disconnection message distinguishes missing reader from expired login',async()=>{
 const [workspace,source,gateway]=await Promise.all([
  readFile(new URL('../website/airline-workspace.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/local-owner-fleet-reader.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/dev-scripts/real-player-read-gateway.mjs',import.meta.url),'utf8')
 ]);
 assert.match(workspace,/Individual aircraft details are not connected in this version/);
 assert.match(workspace,/Your airline data is unavailable/);
 assert.doesNotMatch(workspace,/Sign in to a verified airline to view this aircraft/);
 assert.match(source,/usedDetail:.*action:'used-detail'/);
 assert.match(gateway,/\['list-used','used-detail'\]/);
 assert.doesNotMatch(gateway,/\['list-used','used-detail','bid-used'\]/);
});
