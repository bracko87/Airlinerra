import test from 'node:test';
import assert from 'node:assert/strict';
import {createFlightScheduleHandler,FLIGHT_SCHEDULE_API_ROUTE}
 from '../server/flight-schedule-service.mjs';

const airlineId='11111111-1111-4111-8111-111111111111';
const scheduleId='22222222-2222-4222-8222-222222222222';
const aircraftId='33333333-3333-4333-8333-333333333333';
const userId='44444444-4444-4444-8444-444444444444';
const endpoint='https://airlinerra.com'+FLIGHT_SCHEDULE_API_ROUTE;
const request=(action='operational-evidence',overrides={})=>new Request(endpoint,{
 method:'POST',
 headers:{origin:'https://airlinerra.com','x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
  'content-type':'application/json',authorization:'Bearer '+'x'.repeat(32)},
 body:JSON.stringify({action,airlineId,scheduleId,...overrides})
});
function fixture({owner=true,gameDate='2026-11-23',unsafe=false,stale=false}={}){
 const queries=[];let released=false;
 const database={connect:async()=>({
  query:async(sql,params)=>{
   queries.push({sql,params});
   if(sql.includes('SELECT s.aircraft_inventory_id::text'))
    return {rowCount:owner?1:0,rows:owner?[{aircraftId,scheduleVersion:1}]:[]};
   if(sql.includes('section9_verified_permission_game_day_v1()::text AS game_day'))
    return {rowCount:1,rows:[{game_day:gameDate}]};
   if(sql.includes('section9_owned_commercial_activation_preflight_v1'))
    return {rowCount:1,rows:[{result:{
     readOnly:!unsafe,canActivateNormalFlight:false,
     scheduleId,scheduleVersion:stale?0:1,
     activationChecklist:{worldClockConnected:true,crewRequired:true},
     activationBlockers:['AIRPORT_SLOT_CAPACITY_NOT_CERTIFIED_FOR_ACTIVATION']}}]};
   if(sql.includes('section9_owned_crew_licence_preflight_v1'))
    return {rowCount:1,rows:[{result:{readOnly:true,canActivateNormalFlight:false,
     scheduleId,scheduleVersion:1,
     crew:{registeredEmployeeAssignments:0},permissions:{}}}]};
   if(sql.includes('section9_owned_aircraft_maintenance_readiness_v1'))
    return {rowCount:1,rows:[{result:{readOnly:true,flightActivated:false,
     maintenanceReady:false,status:'maintenance_verification_incomplete',
     blockers:['MAINTENANCE_CHECK_HISTORY_INCOMPLETE']}}]};
   throw Error('Unexpected SQL query');
  },
  release:()=>{released=true}
 })};
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:{id:userId}}),database
 });
 return {handler,queries,released:()=>released};
}
test('operational evidence is rejected before any database read without a verified bearer',async()=>{
 const f=fixture();
 const req=new Request(endpoint,{method:'POST',
  headers:{origin:'https://airlinerra.com','x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
   'content-type':'application/json'},
  body:JSON.stringify({action:'operational-evidence',airlineId,scheduleId})});
 const response=await f.handler(req);
 assert.equal(response.status,401);
 assert.equal(f.queries.length,0);
});
test('operational evidence denies schedules not owned by the authenticated account',async()=>{
 const f=fixture({owner:false});
 const response=await f.handler(request());
 assert.equal(response.status,404);
 assert.equal(f.queries.length,1);
 assert.match(f.queries[0].sql,/a.owner_player_id=\$1::uuid/);
 assert.equal(f.queries[0].params[0],userId);
 assert.equal(f.released(),true);
});
test('operational evidence uses only owner-scoped read-only functions and cannot authorize dispatch',async()=>{
 const f=fixture();
 const response=await f.handler(request());
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.status,'read_only_operational_diagnostics');
 assert.equal(data.readOnly,true);
 assert.equal(data.canActivateNormalFlight,false);
 assert.equal(data.flightActivated,false);
 assert.equal(data.scheduleId,scheduleId);
 assert.equal(data.verifiedGameDate,'2026-11-23');
 assert.equal(data.maintenance.maintenanceReady,false);
 assert.equal(data.activationBlockers.length,1);
 assert.equal(f.queries.length,5);
 assert.equal(f.released(),true);
 for(const {sql,params} of f.queries){
  assert.doesNotMatch(sql,/\b(?:INSERT|UPDATE|DELETE|CALL)\b/i);
  if(params?.length)assert.equal(params[0],userId);
 }
});
test('operational evidence fails closed when verified game day is missing',async()=>{
 const f=fixture({gameDate:null});
 const response=await f.handler(request());
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.status,'operational_evidence_unavailable');
 assert.equal(data.canActivateNormalFlight,false);
 assert.equal(f.queries.length,2);
});
test('unsafe preflight evidence contract is rejected instead of treated as approval',async()=>{
 const f=fixture({unsafe:true});
 const response=await f.handler(request());
 assert.equal(response.status,503);
 assert.equal((await response.json()).error,'Operational evidence contract not verified');
 assert.equal(f.released(),true);
});

test('stale schedule-version diagnostics fail closed',async()=>{
 const f=fixture({stale:true});
 const response=await f.handler(request());
 assert.equal(response.status,503);
 assert.equal((await response.json()).error,'Operational evidence contract not verified');
 assert.equal(f.released(),true);
});
