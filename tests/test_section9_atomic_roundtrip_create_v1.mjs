import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validateFlightSchedulePayload,SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const EXAMPLE={
 action:'operational-roundtrip-create',
 airlineId:'11111111-1111-4111-8111-111111111111',
 aircraftInventoryId:'22222222-2222-4222-8222-222222222222',
 outboundFlightNumber:'PA888',returnFlightNumber:'PA889',
 originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'OURAIRPORTS:4615',
 referenceDepartureUtc:'2026-11-14T08:00:00Z',
 referenceArrivalUtc:'2026-11-14T08:55:00Z',
 returnDepartureUtc:'2026-11-14T09:40:00Z',
 returnArrivalUtc:'2026-11-14T10:35:00Z',
 weeklySchedule:[{day:5,time:'09:00'}],
 returnWeeklySchedule:[{day:5,time:'10:40'}],
 departureStand:'terminal',arrivalStand:'terminal',
 returnDepartureStand:'terminal',returnArrivalStand:'terminal',
 turnaroundMinutes:45
};
test('atomic roundtrip accepts exactly two complete proposed schedules',()=>{
 assert.equal(validateFlightSchedulePayload(EXAMPLE),true);
 for(const key of Object.keys(EXAMPLE)){
  const x={...EXAMPLE};delete x[key];
  assert.equal(validateFlightSchedulePayload(x),false,key);
 }
 assert.equal(validateFlightSchedulePayload({...EXAMPLE,outboundFlightNumber:'XX'}),false);
 assert.equal(validateFlightSchedulePayload({...EXAMPLE,returnFlightNumber:'PA888'}),false);
 assert.equal(validateFlightSchedulePayload({...EXAMPLE,returnDepartureUtc:'2026-11-14T08:45:00Z'}),false);
 assert.equal(validateFlightSchedulePayload({...EXAMPLE,playerId:EXAMPLE.airlineId}),false);
});
test('atomic writer is private and rolls back unless BOTH certified and booked',async()=>{
 const sql=await read('supabase/migrations/20261113215000_section9_atomic_roundtrip_operational_boundary_v1.sql');
 assert.match(sql,/SECURITY INVOKER/);
 assert.match(sql,/section9_owned_roundtrip_candidate_preview_v1/);
 assert.match(sql,/section6_save_owned_aircraft_schedule_with_slots_v1[\s\S]*section6_save_owned_aircraft_schedule_with_slots_v1/);
 assert.match(sql,/section9_commit_certified_schedule_activation_v1[\s\S]*section9_commit_certified_schedule_activation_v1/);
 assert.match(sql,/ROUNDTRIP_OUTBOUND_NOT_CERTIFIED_ROLLBACK/);
 assert.match(sql,/ROUNDTRIP_RETURN_NOT_CERTIFIED_ROLLBACK/);
 assert.match(sql,/ROUNDTRIP_BOOKING_AND_EXECUTION_NOT_CONNECTED_FULL_ROLLBACK/);
 assert.match(sql,/INDEPENDENT_OPERATIONAL_ACTIVATION_NOT_RELEASED/);
 assert.match(sql,/FLIGHT_EXECUTION_AND_SETTLEMENT_NOT_RELEASED/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated/);
 assert.match(sql,/TO service_role/);
 assert.doesNotMatch(sql,/SECURITY DEFINER/);
});
test('connected service never calls the unsafe one-leg slot writer for the pair',async()=>{
 const service=await read('server/flight-schedule-service.mjs');
 assert.match(service,/SCHEDULE_SQL\.roundtripAtomicCreate/);
 assert.match(service,/operational-roundtrip-create/);
 assert.match(SCHEDULE_SQL.roundtripAtomicCreate,/section9_owned_atomic_roundtrip_operational_create_v1/);
 assert.match(service,/result\.routeCreated!==false/);
 assert.match(service,/result\.outboundCreated!==false/);
 assert.match(service,/result\.returnCreated!==false/);
 assert.match(service,/result\.slotsReserved!==false/);
 assert.match(service,/return respond\(409,\{\.\.\.result,routeCreated:false/);
});
test('client exposes paired action and preserves release blockers',async()=>{
 const client=await read('website/flight-schedule-client.mjs');
 assert.match(client,/operationalRoundtripCreate:\(\{/);
 assert.match(client,/post\(\{action:'operational-roundtrip-create'/);
 assert.match(client,/reason\.blockers\.filter/);
 assert.match(client,/conflict\.isAtomicRoundtrip=true/);
});
test('route planner sends both flights when return suggestion still matches aircraft and airports',async()=>{
 const src=await read('website/route-planner.mjs');
 assert.match(src,/const matchingReturn=Boolean\(source&&source\.aircraftId===flightAircraft/);
 assert.match(src,/source\.from\?\.key===to\.key&&source\.to\?\.key===from\.key/);
 assert.match(src,/await scheduler\.operationalRoundtripCreate/);
 assert.match(src,/outboundFlightNumber:source\.flightNumber,returnFlightNumber:flightNumber/);
 assert.match(src,/No airport slots were reserved and no charge was made/);
 assert.match(src,/suggestedSourceFlight=null/);
});


test('phase-1 crew exemption is represented as a PAUSED, never-open release policy',async()=>{
 const sql=await read('supabase/migrations/20261113216000_section9_world1_paused_crew_deferred_phase1.sql');
 assert.match(sql,/'paused'/);
 assert.match(sql,/'deferred_phase1'/);
 assert.match(sql,/clock_timestamp\(\),NULL/);
 assert.match(sql,/ON CONFLICT\(world_id\) DO NOTHING/);
 assert.doesNotMatch(sql,/'enabled'/);
});
