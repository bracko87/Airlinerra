import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createFlightScheduleHandler,validateFlightSchedulePayload,validWeeklyFlightSchedule,
 SCHEDULE_SQL,FLIGHT_SCHEDULE_API_ROUTE
} from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {createProductionGameApi,SCHEDULE_ROUTE,SCHEDULE_EDGE_URL} from '../server/production-game-api.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
const USER='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const PLANE='33333333-3333-4333-8333-333333333333';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const TOKEN='v'.repeat(48);
const flight={
 action:'save',airlineId:AIRLINE,aircraftInventoryId:PLANE,
 flightNumber:'PA101',originAirportKey:'OURAIRPORTS:2220',
 destinationAirportKey:'OURAIRPORTS:4001',
 referenceDepartureUtc:'2026-11-06T10:00:00Z',
 referenceArrivalUtc:'2026-11-06T12:00:00Z',
 weeklySchedule:[{day:0,time:'13:00'},{day:2,time:'14:00'}]
};
const req=(body,headers={})=>new Request(
 'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',headers:{origin:'https://airlinerra.com',
 'x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
 authorization:'Bearer '+TOKEN,'content-type':'application/json',...headers},
 body:JSON.stringify(body)
});
const create=(query,verification=async()=>({user:{id:USER},error:null}))=>{
 const statements=[];let releases=0,connections=0;
 const database={connect:async()=>{connections++;return {
  query:async(sql,args)=>{statements.push({sql,args});return query(sql,args)},
  release:()=>{releases++}
 }}};
 return {handler:createFlightScheduleHandler({verifyUserToken:verification,database}),
  statements,connections:()=>connections,releases:()=>releases};
};
test('payload validator rejects cross-airline IDs, fake UTC timestamps, oversized and duplicate weekdays',()=>{
 assert.equal(validateFlightSchedulePayload(flight),true);
 assert.equal(validWeeklyFlightSchedule([{day:0,time:'10:30'}]),true);
 assert.equal(validWeeklyFlightSchedule([{day:0,time:'10:30'},{day:0,time:'11:00'}]),false);
 assert.equal(validateFlightSchedulePayload({...flight,unknownField:'x'}),false);
 assert.equal(validateFlightSchedulePayload({...flight,flightNumber:'PA-200'}),false);
 assert.equal(validateFlightSchedulePayload({...flight,referenceDepartureUtc:'2026-11-06T10:00:00+01:00'}),false);
 assert.equal(validateFlightSchedulePayload({...flight,aircraftInventoryId:'catalog:3'}),false);
 assert.equal(validateFlightSchedulePayload({...flight,weeklySchedule:[]}),false);
 assert.equal(validateFlightSchedulePayload({...flight,referenceArrivalUtc:'2026-11-06T09:00:00Z'}),false);
 assert.equal(validateFlightSchedulePayload({...flight,action:'activate'}),false);
});
test('authentication and strict proxy origin are required before any database connection',async()=>{
 let verified=0;
 const {handler,connections}=create(()=>{throw Error('should not query')},
  async()=>{verified++;return {user:{id:USER}}});
 const noBearer=await handler(req(flight,{authorization:''}));
 assert.equal(noBearer.status,401);
 const noOrigin=await handler(req(flight,{origin:'https://evil.example'}));
 assert.equal(noOrigin.status,403);
 const invalidBody=await handler(req({...flight,weeklySchedule:[{day:8,time:'25:00'}]}));
 assert.equal(invalidBody.status,400);
 assert.equal(verified,0);assert.equal(connections(),0);
});
test('verified player ID is injected by the server into SQL, never from the browser',async()=>{
 const planned={scheduleId:SCHEDULE,status:'draft',canActivateNormalFlight:false,
  weeklyOccurrencesScreened:8,needsReview:true};
 const {handler,statements,connections,releases}=create((sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.save);
  assert.deepEqual(args.slice(0,4),[USER,AIRLINE,PLANE,'PA101']);
  assert.equal(args[8],JSON.stringify(flight.weeklySchedule));
  return {rowCount:1,rows:[{result:planned}]};
 });
 const response=await handler(req(flight));
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),planned);
 assert.equal(connections(),1);assert.equal(releases(),1);
 assert.equal(statements.length,1);
});
test('unowned airline cannot list its fleet or schedules',async()=>{
 const {handler,statements}=create((sql)=>{
  assert.equal(sql,SCHEDULE_SQL.owner);return {rowCount:0,rows:[]};
 });
 const result=await handler(req({action:'list',airlineId:AIRLINE}));
 assert.equal(result.status,403);
 assert.equal(statements.length,1);
});
test('owned airline list returns only the protected fleet and saved drafts',async()=>{
 const calls=[];
 const {handler}=create((sql,args)=>{
  calls.push(sql);
  if(sql===SCHEDULE_SQL.owner)return {rowCount:1,rows:[{id:AIRLINE}]};
  if(sql===SCHEDULE_SQL.fleet)return {rowCount:1,rows:[{
   id:PLANE,configurationId:3,registration:'D-EXAM',
   ownershipType:'leased',fleetStatus:'in_service'}]};
  if(sql===SCHEDULE_SQL.drafts)return {rowCount:1,rows:[{
   id:SCHEDULE,flightNumber:'PA101',status:'draft'}]};
  if(sql===SCHEDULE_SQL.planList)return {rowCount:0,rows:[]};
  throw Error('Unexpected SQL');
 });
 const response=await handler(req({action:'list',airlineId:AIRLINE}));
 const result=await response.json();
 assert.equal(response.status,200);
 assert.equal(result.activationAvailable,false);
 assert.equal(result.fleet[0].configurationId,3);
 assert.equal(result.drafts[0].status,'draft');
 assert.deepEqual(result.plans,[]);
 assert.equal(calls.length,4);
});
test('curfew rejection cannot be masked as a successful schedule save',async()=>{
 const {handler}=create(()=>{
  throw Object.assign(Error('SCHEDULE_BLOCKED_BY_AIRPORT_OR_AIRCRAFT_RULE'),{code:'P0001'});
 });
 const response=await handler(req(flight));
 const output=await response.json();
 assert.equal(response.status,409);
 assert.equal(output.reason,'SCHEDULE_BLOCKED_BY_AIRPORT_OR_AIRCRAFT_RULE');
});
test('activation readiness is a nonmutating backend check; no action can activate a flight',async()=>{
 const {handler,statements}=create((sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.check);
  assert.deepEqual(args,[USER,SCHEDULE]);
  return {rowCount:1,rows:[{result:{
   status:'BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED',
   canActivateNormalFlight:false,
   reasons:['CREW_ASSIGNMENT_NOT_CONNECTED','AIRPORT_SLOTS_AND_TRAFFIC_RIGHTS_NOT_CONNECTED']
  }}]};
 });
 const response=await handler(req({action:'activation-check',airlineId:AIRLINE,scheduleId:SCHEDULE}));
 assert.equal(response.status,200);
 const result=await response.json();
 assert.equal(result.canActivateNormalFlight,false);
 assert.equal(statements.length,1);
 assert.equal((await handler(req({action:'activate',airlineId:AIRLINE,scheduleId:SCHEDULE}))).status,400);
});
test('unified commercial preflight returns only read-only blockers with no activation write',async()=>{
 const {handler,statements}=create((sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.operationsPreview);
  assert.match(sql,/section9_owned_commercial_activation_preflight_v1/);
  assert.deepEqual(args,[USER,AIRLINE,SCHEDULE,'2000-11-09',28]);
  return {rowCount:1,rows:[{result:{
   status:'BLOCKED_COMMERCIAL_ACTIVATION_NOT_RELEASED',
   canActivateNormalFlight:false,readOnly:true,flightActivated:false,
   movementRecorded:false,ledgerPosted:false,
   activationBlockers:['SCHEDULE_IS_DRAFT_NOT_CERTIFIED']
  }}]};
 });
 const response=await handler(req({action:'operations-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2000-11-09',days:28}));
 assert.equal(response.status,200);
 const result=await response.json();
 assert.equal(result.readOnly,true);
 assert.equal(result.canActivateNormalFlight,false);
 assert.equal(result.flightActivated,false);
 assert.equal(statements.length,1);
});
test('activation-check fails closed if SQL ever claims flight activation is allowed',async()=>{
 const {handler,statements}=create((sql)=>{
  assert.equal(sql,SCHEDULE_SQL.check);
  return {rowCount:1,rows:[{result:{status:'incorrectly_ready',canActivateNormalFlight:true}}]};
 });
 const response=await handler(req({action:'activation-check',airlineId:AIRLINE,scheduleId:SCHEDULE}));
 assert.equal(response.status,503);
 assert.equal(statements.length,1);
});
test('operations-preview refuses unsafe database response and cannot activate flights',async()=>{
 const {handler}=create((sql)=>{
  assert.equal(sql,SCHEDULE_SQL.operationsPreview);
  return {rowCount:1,rows:[{result:{readOnly:false,canActivateNormalFlight:true}}]};
 });
 const response=await handler(req({action:'operations-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2000-11-09',days:28}));
 assert.equal(response.status,503);
});

test('Netlify routes authenticated schedule requests only to pinned dedicated Supabase Edge URL',async()=>{
 const targets=[],app=createProductionGameApi({fetchImpl:async(url,options)=>{
  targets.push({url,options});return Response.json({drafts:[],fleet:[]});
 }});
 const response=await app(new Request('https://airlinerra.com'+SCHEDULE_ROUTE,{
  method:'POST',body:JSON.stringify({action:'list',airlineId:AIRLINE}),
  headers:{authorization:'Bearer '+TOKEN,origin:'https://airlinerra.com'}
 }));
 assert.equal(response.status,200);
 assert.equal(targets.length,1);
 assert.equal(targets[0].url,SCHEDULE_EDGE_URL);
 assert.equal(targets[0].options.headers['x-airlinerra-route'],SCHEDULE_ROUTE);
});
test('browser schedule API never sends a player ID or database credentials',async()=>{
 const seen=[];
 const client=createFlightScheduleClient({auth:{getAccessToken:async()=>TOKEN},
  origin:'https://airlinerra.com',
  fetchImpl:async(url,options)=>{
   seen.push({url,options});
   return Response.json({status:'draft',scheduleId:SCHEDULE,canActivateNormalFlight:false});
  }
 });
 const reply=await client.save({
  airlineId:AIRLINE,aircraftInventoryId:PLANE,flightNumber:'PA101',
  originAirportKey:flight.originAirportKey,destinationAirportKey:flight.destinationAirportKey,
  referenceDepartureUtc:flight.referenceDepartureUtc,
  referenceArrivalUtc:flight.referenceArrivalUtc,weeklySchedule:flight.weeklySchedule
 });
 assert.equal(reply.canActivateNormalFlight,false);
 assert.equal(seen.length,1);
 assert.equal(seen[0].options.credentials,'omit');
 assert.equal(seen[0].options.headers.authorization,'Bearer '+TOKEN);
 assert.equal(JSON.parse(seen[0].options.body).playerId,undefined);
 assert.equal(seen[0].url,'https://airlinerra.com'+FLIGHT_SCHEDULE_API_ROUTE);
});
test('route planner exposes owned fleet schedule drafts, not live activation',async()=>{
 const source=await read('../website/route-planner.mjs');
 const markup=routePlannerMarkup();
 assert.match(markup,/route-server-draft-list/);
 assert.match(source,/loadOwnedScheduleData/);
 assert.match(source,/scheduler\.planSave/);
 assert.match(source,/scheduler\.activationCheck/);
 assert.match(source,/serverScheduleId/);
 assert.doesNotMatch(source,/status:'active'/);
});
