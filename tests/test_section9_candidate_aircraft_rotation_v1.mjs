import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('shared owner-scoped candidate rotation checks every recurring departure with no writes',async()=>{
 const sql=await read('supabase/migrations/20261113212000_section9_owned_candidate_rotation_preflight.sql');
 assert.match(sql,/CREATE OR REPLACE FUNCTION airlinerra_game\.section9_owned_candidate_rotation_preflight_v1/);
 assert.match(sql,/a\.owner_player_id=p_player AND a\.world_id=1/);
 assert.match(sql,/s\.aircraft_inventory_id=p_aircraft/);
 assert.match(sql,/s\.status='active' AND s\.operationally_verified=true/);
 assert.match(sql,/p_days NOT BETWEEN 7 AND 42/);
 assert.match(sql,/wrongAirportDepartures/);
 assert.match(sql,/returnOrRepositionRequired/);
 assert.match(sql,/overlappingFlights/);
 assert.match(sql,/AMBIGUOUS_OR_NONEXISTENT_LOCAL_TIME/);
 assert.match(sql,/airportSlotsReserved',false/);
 assert.match(sql,/flightActivated',false/);
 assert.match(sql,/operationallyApproved',false/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});

test('shared candidate preflight rejects wrong-airport repeats and removes positive game suitability',async()=>{
 const sql=await read('supabase/migrations/20261113213000_section9_candidate_preflight_requires_aircraft_rotation.sql');
 assert.match(sql,/section9_owned_candidate_rotation_preflight_v1/);
 assert.match(sql,/rotation_preview->>'gameRotationCompatible'/);
 assert.match(sql,/AIRCRAFT_ROTATION_REQUIRES_RETURN_OR_REPOSITION/);
 assert.match(sql,/gameModelPreliminarySuitable/);
 assert.match(sql,/gameModelChecks/);
 assert.match(sql,/aircraftRotationCandidate',rotation_preview/);
 assert.match(sql,/'airportSlotsReserved',false/);
 assert.match(sql,/'flightActivated',false/);
});

test('client and UI show missing return or overlapping flights, never activate on error',async()=>{
 const service=await read('server/flight-schedule-service.mjs');
 const client=await read('website/flight-schedule-client.mjs');
 const planner=await read('website/route-planner.mjs');
 assert.match(service,/gameAircraftRotationCandidate:/);
 assert.match(service,/returnOrRepositionRequired/);
 assert.match(service,/wrongAirportDepartures/);
 assert.match(client,/conflict\.aircraftRotationWarning=/);
 assert.match(client,/Number\.isInteger\(a\.wrongAirportDepartures\)/);
 assert.match(planner,/The aircraft will still be at the previous destination/);
 assert.match(planner,/Add a return or repositioning flight/);
 assert.match(planner,/NOT CREATED/);
});
