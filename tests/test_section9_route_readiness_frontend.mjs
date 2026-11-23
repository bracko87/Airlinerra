import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {summarizeProtectedRouteReadiness} from '../website/section9-route-readiness.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('readiness fails closed on absent or falsely approved server evidence',()=>{
 for(const result of [null,{}, {status:'READY',canActivateNormalFlight:true},
  {status:'unknown',canActivateNormalFlight:false},
  {status:'BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED',canActivateNormalFlight:true}]){
  const report=summarizeProtectedRouteReadiness(result);
  assert.equal(report.state,'unavailable');
  assert.equal(report.checks.length,0);
 }
});
test('aircraft shortage links the player to Fleet without claiming flight activation',()=>{
 const r=summarizeProtectedRouteReadiness({
  status:'BLOCKED_AIRCRAFT_UNAVAILABLE',canActivateNormalFlight:false,
  reasons:['AIRCRAFT_NOT_IN_SERVICE_OR_CONFIGURATION_CHANGED']
 });
 assert.equal(r.state,'blocked');
 assert.equal(r.checks[0].state,'blocked');
 assert.equal(r.checks[1].state,'unknown');
 assert.equal(r.checks[2].state,'unverified');
 assert.equal(r.actions[0].page,'fleet');
});
test('airport curfew/runway failure links to route planning and airport information',()=>{
 const r=summarizeProtectedRouteReadiness({
  status:'BLOCKED_AIRPORT_AIRCRAFT_RESTRICTIONS',canActivateNormalFlight:false
 });
 assert.equal(r.checks[1].state,'blocked');
 assert.deepEqual(r.actions.map(a=>a.page),['routes','airports']);
});
test('passing the limited restriction screen never becomes full certification',()=>{
 const r=summarizeProtectedRouteReadiness({
  status:'BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED',
  canActivateNormalFlight:false,restrictionPreflightPassed:true,
  reasons:['OPERATIONAL_FLIGHT_ACTIVATION_NOT_RELEASED']
 });
 assert.equal(r.checks[0].state,'checked');
 assert.equal(r.checks[1].state,'checked');
 assert.equal(r.checks[2].state,'unverified');
 assert.match(r.summary,/not approved/i);
 assert.match(r.note,/never activates/i);
 assert.deepEqual(r.actions.map(a=>a.page),['licenses','staff','schedule']);
});
test('Route Details wires protected drafts, but never uses legacy activation check for active routes',async()=>{
 const details=await read('../website/section9-route-details.mjs');
 assert.match(details,/summarizeProtectedRouteReadiness/);
 assert.match(details,/server\.scheduler\.activationCheck\(/);
 assert.match(details,/else if\(route\.operationallyVerified\)/);
 assert.match(details,/readinessActions/);
 assert.match(details,/server\.connected/);
 assert.match(details,/data|workspaceGo/);
 assert.doesNotMatch(details,/scheduler\.(?:activate|commitCertified|operationalSingleCreate)\(/);
});
test('Route Planner shows human-readable blockers; overview does not invent ticket-sales restrictions',async()=>{
 const planner=await read('../website/route-planner.mjs');
 const overview=await read('../website/section9-flight-readiness.mjs');
 assert.match(planner,/summarizeProtectedRouteReadiness\(result\)/);
 assert.match(planner,/This check does not activate a flight/);
 assert.doesNotMatch(overview,/Ticket sales remain disabled/);
 assert.match(overview,/Planning drafts alone do not open passenger sales/);
});
