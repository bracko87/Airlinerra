import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFlightScheduleHandler,validateFlightSchedulePayload,SCHEDULE_SQL,
 FLIGHT_SCHEDULE_API_ROUTE} from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {createLocalOwnerFleetReaders} from '../website/local-owner-fleet-reader.mjs';
import {allowedLocalOwnerRead} from '../website/dev-scripts/real-player-read-gateway.mjs';
import {buildAircraftWeeklyTimeline} from '../website/aircraft-weekly-timeline.mjs';

const USER='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const AIRCRAFT='33333333-3333-4333-8333-333333333333';
const TOKEN='b'.repeat(48);
const args={airlineId:AIRLINE,aircraftInventoryId:AIRCRAFT,flightNumber:'PA999',
 originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'OURAIRPORTS:4615',
 weeklySchedule:Array.from({length:7},(_,day)=>({day,time:'09:00'})),
 departureStand:'terminal',arrivalStand:'terminal',turnaroundMinutes:45,
 fares:{economy:77,premium:null,business:null,first:null},
 service:{onboard:'basic',baggage:'standard',cargo:'none',cabinPackageId:'basic'},
 launchDelayDays:0,referenceDepartureUtc:null,referenceArrivalUtc:null};
const payload={action:'operational-create',...args};
const req=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',headers:{origin:'https://airlinerra.com',
 'x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
 authorization:'Bearer '+TOKEN,'content-type':'application/json'},
 body:JSON.stringify(body)});
function handler(query,verifyUserToken=async()=>({user:{id:USER}})){
 const statements=[];
 const h=createFlightScheduleHandler({
  verifyUserToken,
  database:{connect:async()=>({query:async(sql,params)=>{
   statements.push({sql,params});return query(sql,params);
  },release(){}})}
 });
 return {h,statements};
}
test('new operational-create request validates owner, airline, airport, aircraft and passenger package fields',()=>{
 assert.equal(validateFlightSchedulePayload(payload),true);
 for(const bad of [
  {...payload,flightNumber:'bad number'},
  {...payload,weeklySchedule:[]},
  {...payload,aircraftInventoryId:'other-plane'},
  {...payload,referenceArrivalUtc:'2026-11-12T09:00:00Z'},
  {...payload,bookingsCreated:true},
  {...payload,activated:true},
  {...payload,forceApproved:true},
  {...payload,action:'activate'},
 ]) assert.equal(validateFlightSchedulePayload(bad),false,
  'must reject malformed/unauthorized creation payload');
});
test('operational create fails closed, owner verified, without ANY schedule, slot, or cash write',async()=>{
 const {h,statements}=handler((sql,params)=>{
  if(sql===SCHEDULE_SQL.owner){
   assert.deepEqual(params,[AIRLINE,USER]);
   return {rowCount:1,rows:[{id:AIRLINE}]};
  }
  if(sql===SCHEDULE_SQL.operationalReadiness)
   return {rowCount:1,rows:[{world_id:1,world_state:'active',
    confirmed_game_date:'2026-11-12',
    authoritative_clock_connected:true,clock_producer_enabled:true,
    operational_certification_records:0,aircraft_operation_jobs:0,
    verified_movement_records:0,
    automatic_flight_and_fuel_settlement_enabled:false}]};
  if(sql===SCHEDULE_SQL.aircraftPrerequisites){
   assert.deepEqual(params,[USER,AIRLINE,AIRCRAFT,'OURAIRPORTS:4610']);
   return {rowCount:1,rows:[{aircraftInService:true,
    startingLocationVerified:false,atOrigin:false,originalStarterPosition:false,
    fuelDispatchModelApproved:false,fuelAccountingModelApproved:false}]};
  }
  throw Error('Any other SQL is an unauthorized operational write');
 });
 const res=await h(req(payload));
 assert.equal(res.status,409);
 const out=await res.json();
 assert.equal(out.routeCreated,false);
 assert.equal(out.activated,false);
 assert.equal(out.slotsReserved,false);
 assert.equal(out.bookingEnabled,false);
 assert.equal(out.ledgerPosted,false);
 assert.equal(out.scheduleId,null);
 assert.match(out.blockingRequirements.join(' '),/ATOMIC_SCHEDULE_AND_AIRPORT_SLOT_ACTIVATION_NOT_CONNECTED/);
 assert.match(out.blockingRequirements.join(' '),/AIRCRAFT_STARTING_LOCATION_NOT_VERIFIED/);
 assert.doesNotMatch(out.blockingRequirements.join(' '),/AIRCRAFT_NOT_VERIFIED_AT_ORIGIN/);
 assert.match(out.blockingRequirements.join(' '),/AIRCRAFT_FUEL_DISPATCH_MODEL_NOT_APPROVED/);
 assert.equal(out.crewRequired,false);
 assert.equal(out.crewCostsIncluded,false);
 assert.doesNotMatch(out.blockingRequirements.join(' '),/CREW_/);
 assert.match(out.blockingRequirements.join(' '),/TRUSTED_AIRCRAFT_EXECUTION_NOT_CONNECTED/);
 assert.match(out.blockingRequirements.join(' '),/SEVEN_DAY_PASSENGER_BOOKING_NOT_CONNECTED/);
 assert.match(out.blockingRequirements.join(' '),/FLIGHT_FINANCIAL_SETTLEMENT_NOT_CONNECTED/);
 assert.equal(statements.length,3,'owner, readiness and aircraft SELECT only');
 assert.ok(statements.every(x=>[SCHEDULE_SQL.owner,SCHEDULE_SQL.operationalReadiness,SCHEDULE_SQL.aircraftPrerequisites].includes(x.sql)));
});
test('unowned airline or invalid auth never reveals readiness and writes nothing',async()=>{
 const foreign=handler((sql)=>{
  assert.equal(sql,SCHEDULE_SQL.owner);
  return {rowCount:0,rows:[]}
 });
 assert.equal((await foreign.h(req(payload))).status,403);
 assert.equal(foreign.statements.length,1);
 const noAuth=handler(()=>{throw Error('Should not query')},
  async()=>({error:'invalid',user:null}));
 assert.equal((await noAuth.h(req(payload))).status,401);
 assert.equal(noAuth.statements.length,0);
});
test('production and localhost route creator send identical strict operational-only API commands',async()=>{
 let production,local;
 const blockers=['AIRCRAFT_STARTING_LOCATION_NOT_VERIFIED',
  'AIRCRAFT_FUEL_DISPATCH_MODEL_NOT_APPROVED','SEVEN_DAY_PASSENGER_BOOKING_NOT_CONNECTED'];
 const client=createFlightScheduleClient({
  origin:'https://airlinerra.com',auth:{getAccessToken:async()=>TOKEN},
  fetchImpl:async(_url,opts)=>{
   production=JSON.parse(opts.body);
   return Response.json({error:'OPERATIONAL_ROUTE_CREATION_BLOCKED',
    reason:'GAME_ENGINE_NOT_READY',blockingRequirements:blockers},{status:409});
  }
 });
 const preview=createLocalOwnerFleetReaders({
  origin:'http://localhost:5188',auth:{getAccessToken:async()=>TOKEN},
  fetchImpl:async(_url,opts)=>{
   local=JSON.parse(opts.body);
   return Response.json({error:'OPERATIONAL_ROUTE_CREATION_BLOCKED',
    reason:'GAME_ENGINE_NOT_READY',blockingRequirements:blockers},{status:409});
  }
 });
 await assert.rejects(()=>client.operationalCreate(args),error=>{
  assert.match(error.message,/SCHEDULE_CONFLICT_GAME_ENGINE_NOT_READY/);
  assert.deepEqual(error.operationalBlockers,blockers);
  return true;
 });
 await assert.rejects(()=>preview.scheduler.operationalCreate(args),error=>{
  assert.match(error.message,/SCHEDULE_CONFLICT_GAME_ENGINE_NOT_READY/);
  assert.deepEqual(error.operationalBlockers,blockers);
  return true;
 });
 assert.deepEqual(production,payload);
 assert.deepEqual(local,payload);
 assert.equal(allowedLocalOwnerRead(FLIGHT_SCHEDULE_API_ROUTE,payload),true);
 assert.equal(allowedLocalOwnerRead(FLIGHT_SCHEDULE_API_ROUTE,
  {...payload,activationApproved:true}),false);
});
test('the first outbound plan does not show missing return warning; second route for same aircraft does',()=>{
 const from={key:'OURAIRPORTS:4610',name:'Belgrade'};
 const to={key:'OURAIRPORTS:4615',name:'Tivat'};
 const first={aircraftId:AIRCRAFT,flightNumber:'PA888',from,to,
  schedule:args.weeklySchedule,operation:{arrivalStand:'terminal'}};
 const single=buildAircraftWeeklyTimeline({aircraftId:AIRCRAFT,
  routes:[],proposal:first,homeAirportKey:from.key});
 assert.equal(single.errors.length,0);
 assert.equal(single.warnings.some(w=>/Weekly cycle is incomplete/.test(w)),false);
 const next={aircraftId:AIRCRAFT,flightNumber:'PA999',from,to,
  schedule:[{day:0,time:'12:00'}],operation:{arrivalStand:'terminal'}};
 const second=buildAircraftWeeklyTimeline({aircraftId:AIRCRAFT,
  routes:[first],proposal:next,homeAirportKey:from.key});
 assert.ok(second.errors.some(e=>e.code==='AIRCRAFT_WRONG_AIRPORT'));
 assert.match(second.warnings.join(' '),/return or repositioning flight/i);
});
test('route creation UI no longer invokes planning-only save or claims unapproved routes exist',async()=>{
 const ui=await readFile(new URL('../website/route-planner.mjs',import.meta.url),'utf8');
 assert.match(ui,/scheduler\.operationalCreate\(/);
 assert.doesNotMatch(ui,/scheduler\.planSave\(/);
 assert.match(ui,/result\?\.routeCreated!==true/);
 assert.match(ui,/result\.activated!==true/);
 assert.match(ui,/result\.bookingEnabled!==true/);
 assert.match(ui,/NOT CREATED — automatic flight activation/);
 assert.match(ui,/AIRCRAFT_STARTING_LOCATION_NOT_VERIFIED/);
 assert.doesNotMatch(ui,/CREW_ASSIGNMENTS_INCOMPLETE/);
 assert.match(ui,/No flight was created/);
 assert.match(ui,/const text='Route '\+flightNumber\+' created\.'/);
});
