import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {summarizeProtectedRouteReadiness} from '../website/section9-route-readiness.mjs';
import {summarizeRecordedCertifications,CERTIFICATION_SOURCES} from '../website/section9-certification-records.mjs';
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

test('all five source types are displayed without equating records to flight authorization',()=>{
 const reply={status:'signed_certification_records_read_only',readOnly:true,
  canActivateNormalFlight:false,certificationRevalidated:false,
  scheduleId:'schedule-1',scheduleVersion:3,verifiedGameDate:'2026-11-23',
  certificates:CERTIFICATION_SOURCES.map(([type])=>({
   type,status:'certified',scheduleVersion:3,validFromGameDate:'2026-11-01',validToGameDate:'2026-12-01'
  }))};
 const summary=summarizeRecordedCertifications(reply);
 assert.equal(summary.checks.length,5);
 assert(summary.checks.every(c=>c.state==='recorded'));
 assert.match(summary.summary,/does not revalidate/i);
 assert.equal(summarizeRecordedCertifications({...reply,canActivateNormalFlight:true}),null);
 assert.equal(summarizeRecordedCertifications({...reply,certificationRevalidated:true}),null);
});
test('missing game clock, expired certificates and mismatched versions fail closed',()=>{
 const base={status:'signed_certification_records_read_only',readOnly:true,
  canActivateNormalFlight:false,certificationRevalidated:false,
  scheduleId:'schedule-1',scheduleVersion:2,verifiedGameDate:'2026-11-23',
  certificates:[{type:'operator_licence',status:'certified',
   scheduleVersion:2,validFromGameDate:'2026-11-01',validToGameDate:'2026-11-22'}]};
 assert.equal(summarizeRecordedCertifications(base).checks[0].state,'unverified');
 assert.equal(summarizeRecordedCertifications({...base,verifiedGameDate:null}).checks[0].state,'unverified');
 assert.equal(summarizeRecordedCertifications({...base,certificates:[{
  type:'operator_licence',status:'certified',scheduleVersion:2,
  validFromGameDate:'2026-11-24',validToGameDate:'2026-12-01'}]}).checks[0].state,'unverified');
 assert.equal(summarizeRecordedCertifications({...base,certificates:[{
  type:'operator_licence',status:'certified',scheduleVersion:1,
  validFromGameDate:'2026-11-01',validToGameDate:'2026-12-01'}]}).checks[0].state,'unverified');
});
test('authenticated route certification endpoint has read-only owner-scoped query',async()=>{
 const server=await read('../server/flight-schedule-service.mjs');
 const client=await read('../website/flight-schedule-client.mjs');
 const details=await read('../website/section9-route-details.mjs');
 assert.match(server,/body\.action==='certification-status'/);
 assert.match(server,/a\.owner_player_id=\$1::uuid/);
 assert.match(server,/certificationRevalidated:false/);
 assert.match(server,/canActivateNormalFlight:false/);
 assert.match(client,/certificationStatus:/);
 assert.match(details,/summarizeRecordedCertifications/);
 assert.match(details,/certificationStatus\(/);
});
