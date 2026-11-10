import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFlightScheduleHandler,validateFlightSchedulePayload,SCHEDULE_SQL,
 FLIGHT_SCHEDULE_API_ROUTE} from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {createLocalOwnerFleetReaders} from '../website/local-owner-fleet-reader.mjs';
import {allowedLocalOwnerRead,createLiveReadOnlyPreviewHandler} from '../website/dev-scripts/real-player-read-gateway.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const AIRCRAFT='33333333-3333-4333-8333-333333333333';
const USER='11111111-1111-4111-8111-111111111111';
const PLAN='55555555-5555-4555-8555-555555555555';
const TOKEN='z'.repeat(45);
const request=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',headers:{origin:'https://airlinerra.com',
 'x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
 authorization:'Bearer '+TOKEN,'content-type':'application/json'},
 body:JSON.stringify(body)
});
const plan={
 action:'plan-save',airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,
 flightNumber:'PA444',originAirportKey:'OURAIRPORTS:4610',
 destinationAirportKey:'FICTIONAL:fictional:RS:LYAL',
 weeklySchedule:[{day:0,time:'09:00'},{day:1,time:'09:00'},
  {day:4,time:'09:00'},{day:5,time:'09:00'}],
 departureStand:'terminal',arrivalStand:'terminal',turnaroundMinutes:45,
 fares:{economy:49,premium:null,business:null,first:null},
 service:{onboard:'standard',baggage:'standard',cargo:'none'},
 referenceDepartureUtc:null,referenceArrivalUtc:null
};
const mock=(fn,auth=async()=>({user:{id:USER}}))=>{
 let count=0;
 const handler=createFlightScheduleHandler({verifyUserToken:auth,
  database:{connect:async()=>({query:async(sql,args)=>{count++;return fn(sql,args)},release(){}})}});
 return {handler,count:()=>count};
};

test('pre-operational planning accepts no invented arrival time, rejects same airport, unowned IDs and extra actions',()=>{
 assert.equal(validateFlightSchedulePayload(plan),true);
 const bad=[
  {...plan,destinationAirportKey:plan.originAirportKey},
  {...plan,weeklySchedule:[{day:0,time:'09:00'},{day:0,time:'10:00'}]},
  {...plan,turnaroundMinutes:10},
  {...plan,aircraftInventoryId:'catalog:16'},
  {...plan,flightNumber:'AB#444'},
  {...plan,fares:{...plan.fares,economy:100001}},
  {...plan,fares:{...plan.fares,first:'100'}},
  {...plan,service:{onboard:'premium',baggage:'standard',cargo:'none'}},
  {...plan,referenceArrivalUtc:'2026-11-10T10:00:00Z'},
  {...plan,activateFlight:true},
  {...plan,action:'save'}
 ];
 for(const candidate of bad)assert.equal(validateFlightSchedulePayload(candidate),false,JSON.stringify(candidate).slice(0,150));
});

test('planning save never reserves slots, posts cash or activates flights',async()=>{
 let sqlText;
 const {handler,count}=mock((sql,args)=>{
  sqlText=sql;
  assert.equal(sql,SCHEDULE_SQL.planSave);
  assert.deepEqual(args.slice(0,6),[USER,AIRLINE,AIRCRAFT,'PA444',
   'OURAIRPORTS:4610','FICTIONAL:fictional:RS:LYAL']);
  assert.equal(args[7],'terminal');
  assert.equal(args[11],null);
  assert.equal(args[12],null);
  return {rowCount:1,rows:[{planId:PLAN,flightNumber:'PA444',
    version:1,status:'planning',airlineId:AIRLINE}]};
 });
 const reply=await handler(request(plan));
 const data=await reply.json();
 assert.equal(reply.status,200);assert.equal(count(),1);
 assert.equal(data.planId,PLAN);assert.equal(data.canActivateNormalFlight,false);
 assert.equal(data.slotsReserved,false);assert.equal(data.ledgerPosted,false);
 assert.equal(data.passengerBookingsCreated,false);
 assert.match(sqlText,/a\.owner_player_id=\$1::uuid/);
 assert.match(sqlText,/i\.airline_id=a\.id/);
 assert.match(sqlText,/i\.fleet_status='in_service'/);
 assert.match(sqlText,/w\.state='active'/);
 assert.match(sqlText,/NOT EXISTS[\s\S]*airline_flight_schedule_drafts_v1/);
 assert.doesNotMatch(sqlText,/section6_weekly_airport_slot_reservations_v1|section9_accept_scheduled_game_tick/);
});

test('planning save rejects unsuccessful ownership, without fabricated acknowledgement',async()=>{
 const {handler}=mock(()=>({rowCount:0,rows:[]}));
 const result=await handler(request(plan));
 assert.equal(result.status,409);
 assert.match(JSON.stringify(await result.json()),/ROUTE_PLANNING_REQUIREMENTS_NOT_MET/);
 const deny=mock(()=>{throw Error('Must not access database')},async()=>({user:null,error:'invalid'}));
 assert.equal((await deny.handler(request(plan))).status,401);
 assert.equal(deny.count(),0);
});

test('local gateway only forwards a validated owner planning draft; not flight schedule writes',async()=>{
 const url='/api/v1/player/flight-schedule-drafts';
 assert.equal(allowedLocalOwnerRead(url,plan),true);
 for(const bad of [
  {...plan,action:'save'},
  {...plan,action:'commercial-save'},
  {...plan,action:'delete'},
  {...plan,flightNumber:'PA/444'},
  {...plan,authorization:'OTHER'}
 ])assert.equal(allowedLocalOwnerRead(url,bad),false);
 let action;
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(_url,opts)=>{
  action=JSON.parse(opts.body).action;
  return Response.json({status:'planning',planId:PLAN,flightNumber:'PA444',slotsReserved:false});
 }});
 const result=await handler(new Request('http://localhost:5188'+url,{
  method:'POST',headers:{origin:'http://localhost:5188','content-type':'application/json',
   authorization:'Bearer '+TOKEN},body:JSON.stringify(plan)
 }));
 assert.equal(result.status,200);assert.equal(action,'plan-save');
});

test('both production and localhost clients expose planning save but not localhost flight activation',async()=>{
 let prodBody,localBody;
 const prod=createFlightScheduleClient({origin:'https://airlinerra.com',
  auth:{getAccessToken:async()=>TOKEN},
  fetchImpl:async(_url,options)=>{prodBody=JSON.parse(options.body);
   return Response.json({status:'planning',planId:PLAN})}
 });
 const local=createLocalOwnerFleetReaders({origin:'http://localhost:5188',
  auth:{getAccessToken:async()=>TOKEN},
  fetchImpl:async(_url,options)=>{localBody=JSON.parse(options.body);
   return Response.json({status:'planning',planId:PLAN})}
 });
 const args={...plan};delete args.action;
 await prod.planSave(args);
 await local.scheduler.planSave(args);
 assert.deepEqual(prodBody,plan);
 assert.deepEqual(localBody,plan);
 assert.equal(local.scheduler.save,undefined);
 assert.equal(local.scheduler.delete,undefined);
 assert.equal(local.scheduler.commercialSave,undefined);
});

test('route detail uses geographic map and organised operational and finance sections without inventing results',async()=>{
 const read=path=>readFile(new URL('../website/'+path,import.meta.url),'utf8');
 const [details,operations,planner,css,sql]=await Promise.all([
  read('section9-route-details.mjs'),read('airline-operations-center.mjs'),
  read('route-planner.mjs'),read('player-app.css'),
  read('../supabase/migrations/20261110130000_airlinerra_owner_route_planning_drafts_v1.sql')
 ]);
 assert.match(details,/renderRouteMap\(mapRoot,from,to,\{doc\}\)/);
 assert.match(details,/route-details-top/);
 assert.match(details,/FLIGHT SCHEDULE/);
 assert.match(details,/PASSENGER & CARGO MARKET/);
 assert.match(details,/ROUTE FINANCES/);
 assert.match(details,/TICKETS & SERVICES/);
 assert.match(details,/No flight path is approved/);
 assert.match(details,/last seven settled flights/i);
 assert.match(operations,/async function loadRemotePlans\(/);
 assert.match(operations,/serverPlanningId/);
 assert.match(operations,/operations-route-publish-plan/);
 assert.match(planner,/scheduler\.planSave\(/);
 assert.match(css,/\.route-details-top/);
 assert.match(sql,/operationally_verified boolean NOT NULL DEFAULT false CHECK \(operationally_verified=false\)/);
 assert.match(sql,/slots_reserved boolean NOT NULL DEFAULT false CHECK \(slots_reserved=false\)/);
 assert.match(sql,/REVOKE ALL ON airlinerra_game\.airline_route_planning_drafts_v1 FROM PUBLIC, anon, authenticated/);
});
