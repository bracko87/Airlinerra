import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {projectOwnedScheduleRoutes} from '../website/section9-owned-schedule-routes.mjs';
const id='11111111-1111-4111-8111-111111111111';
const aircraft='22222222-2222-4222-8222-222222222222';
const base={id,aircraftInventoryId:aircraft,flightNumber:'AL101',
 originAirportKey:'OURAIRPORTS:2218',destinationAirportKey:'OURAIRPORTS:2212',
 weeklySchedule:[{day:1,time:'10:00'}],referenceDepartureUtc:'2026-11-23T10:00:00Z',
 referenceArrivalUtc:'2026-11-23T11:00:00Z',departureStand:'terminal',
 arrivalStand:'terminal',status:'active',operationallyVerified:true,
 slotsReserved:true,version:2};
const local={flightNumber:'AL101',aircraftId:'owned:'+aircraft,serverScheduleId:id,
 from:{key:base.originAirportKey,name:'Frankfurt Airport'},
 to:{key:base.destinationAirportKey,name:'Munich Airport'},
 status:'draft',operationallyVerified:false};
test('server active schedules survive reload even when local workplan is empty',()=>{
 const routes=projectOwnedScheduleRoutes({schedules:[base],fleet:[{id:aircraft,registration:'D-AIR1'}]});
 assert.equal(routes.length,1);
 assert.equal(routes[0].serverScheduleId,id);
 assert.equal(routes[0].operationallyVerified,true);
 assert.equal(routes[0].status,'active');
 assert.equal(routes[0].aircraftLabel,'D-AIR1');
 assert.equal(routes[0].schedule.length,1);
});
test('local plan display names survive but local status can never authorize flight',()=>{
 const routes=projectOwnedScheduleRoutes({schedules:[{...base,status:'draft',operationallyVerified:false}],
  local:[{...local,operationallyVerified:true,status:'active',slotsReserved:true}]});
 assert.equal(routes.length,1);
 assert.equal(routes[0].from.name,'Frankfurt Airport');
 assert.equal(routes[0].status,'draft');
 assert.equal(routes[0].operationallyVerified,false);
 assert.equal(routes[0].slotsReserved,true);
});
test('both active schedule state and operational verification must be backed by server',()=>{
 for(const s of [{status:'active',operationallyVerified:false},
  {status:'draft',operationallyVerified:true},{status:'draft',operationallyVerified:false}]){
  const routes=projectOwnedScheduleRoutes({schedules:[{...base,...s}]});
  assert.equal(routes[0].operationallyVerified,false);
  assert.equal(routes[0].status,'draft');
 }
});
test('mismatched server planning draft cannot override a verified schedule',()=>{
 const fake={flightNumber:'AL101',serverScheduleId:'33333333-3333-4333-8333-333333333333',
  operationallyVerified:true,status:'active',from:local.from,to:local.to};
 const routes=projectOwnedScheduleRoutes({schedules:[base],plans:[fake]});
 assert.equal(routes.length,1);
 assert.equal(routes[0].serverScheduleId,id);
 assert.equal(routes[0].operationallyVerified,true);
 assert.equal(routes[0].from.key,base.originAirportKey);
});
test('stale browser-only route must not claim server activation after reload',()=>{
 const routes=projectOwnedScheduleRoutes({local:[{...local,status:'active',
  operationallyVerified:true,slotsReserved:true}]});
 assert.equal(routes.length,1);
 assert.equal(routes[0].status,'planning');
 assert.equal(routes[0].serverScheduleId,null);
 assert.equal(routes[0].slotsReserved,false);
 assert.equal(routes[0].operationallyVerified,false);
});
test('invalid schedule identity is excluded and planning records remain non-operational',()=>{
 const routes=projectOwnedScheduleRoutes({
  schedules:[{...base,id:'unsafe-uuid'}],
  plans:[{...local,serverPlanningId:'plan',operationallyVerified:true}]});
 assert.equal(routes.length,1);
 assert.equal(routes[0].operationallyVerified,false);
 assert.equal(routes[0].serverScheduleId,null);
});
test('My Routes uses server schedule list and the browser build includes recovery module',async()=>{
 const files=await Promise.all(['../website/airline-operations-center.mjs',
  '../website/route-planner.mjs','../server/flight-schedule-service.mjs',
  '../website/dev-scripts/invited-overlay.mjs'].map(p=>readFile(new URL(p,import.meta.url),'utf8')));
 const [ops,planner,api,build]=files;
 assert.match(ops,/remoteSchedules=reply\.drafts/);
 assert.match(ops,/projectOwnedScheduleRoutes\(/);
 assert.match(ops,/event\.detail\?\.operationallyVerified===true/);
 assert.match(planner,/serverSaved:true,operationallyVerified:true/);
 assert.match(api,/s\.operationally_verified AS "operationallyVerified"/);
 assert.match(build,/'section9-owned-schedule-routes\.mjs'/);
});

test('My Routes exposes a manual owner-scoped refresh and never reports failed server reload as success',async()=>{
 const ops=await readFile(new URL('../website/airline-operations-center.mjs',import.meta.url),'utf8');
 assert.match(ops,/id="operations-routes-refresh"/);
 assert.match(ops,/target\.id==='operations-routes-refresh'/);
 assert.match(ops,/const verified=await loadRemotePlans\(\)/);
 assert.match(ops,/if\(verified\)message\('operations-routes-feedback'/);
 assert.match(ops,/renderRoutes\(\);[\s\S]{0,250}void details\.refresh\(\);[\s\S]{0,80}return true;/);
 assert.match(ops,/Server planning routes could not be loaded/);
});
