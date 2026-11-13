import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validateFlightSchedulePayload,SCHEDULE_SQL}
 from '../server/flight-schedule-service.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const WEEK=[{day:5,time:'09:00'}];
const BACK=[{day:5,time:'10:40'}];
const good={
 action:'roundtrip-preview',
 airlineId:'22222222-2222-4222-8222-222222222222',
 aircraftInventoryId:'33333333-3333-4333-8333-333333333333',
 originAirportKey:'OURAIRPORTS:4610',
 destinationAirportKey:'OURAIRPORTS:4615',
 referenceDepartureUtc:'2026-11-14T08:00:00Z',
 referenceArrivalUtc:'2026-11-14T08:55:00Z',
 returnDepartureUtc:'2026-11-14T09:40:00Z',
 returnArrivalUtc:'2026-11-14T10:35:00Z',
 weeklySchedule:WEEK,returnWeeklySchedule:BACK,
 departureStand:'terminal',arrivalStand:'terminal',
 returnDepartureStand:'terminal',returnArrivalStand:'terminal',
 turnaroundMinutes:45
};
test('two-leg preview requires a complete authenticated-friendly schema',()=>{
 assert.equal(validateFlightSchedulePayload(good),true);
 for(const key of Object.keys(good)){
  const invalid={...good};delete invalid[key];
  assert.equal(validateFlightSchedulePayload(invalid),false,key);
 }
 assert.equal(validateFlightSchedulePayload({...good,ownerPlayerId:good.airlineId}),false);
 assert.equal(validateFlightSchedulePayload({...good,action:'save'}),false);
 assert.equal(validateFlightSchedulePayload({...good,returnDepartureUtc:'2026-11-14T08:30:00Z'}),false);
 assert.equal(validateFlightSchedulePayload({...good,returnArrivalUtc:'2026-11-14T09:00:00Z'}),false);
 assert.equal(validateFlightSchedulePayload({...good,returnWeeklySchedule:[...BACK,...BACK]}),false);
 assert.equal(validateFlightSchedulePayload({...good,destinationAirportKey:good.originAirportKey}),false);
 assert.equal(validateFlightSchedulePayload({...good,departureStand:'bad'}),false);
});
test('SQL aggregates outbound and return requests and remains read-only',async()=>{
 const sql=await read('supabase/migrations/20261113214000_section9_owned_roundtrip_candidate_game_preview.sql');
 assert.match(sql,/section9_owned_roundtrip_candidate_preview_v1/);
 assert.match(sql,/JOIN airlinerra_game\.world_memberships/);
 assert.match(sql,/owner_player_id=p_player/);
 assert.match(sql,/ROUNDTRIP_TURNAROUND_TOO_SHORT/);
 assert.match(sql,/count\(\*\) OVER\(PARTITION BY airport_key,stand_type,direction,weekday,minute_of_day\/60\)/);
 assert.match(sql,/UNION ALL\s+SELECT prop\.\* FROM airlinerra_game\.section6_weekly_slot_proposals_v1/);
 assert.match(sql,/combinedSlotCapacityAvailable/);
 assert.match(sql,/wrongAirportDepartures/);
 assert.match(sql,/flightsCreated',0/);
 assert.match(sql,/slotsReserved',false/);
 assert.match(sql,/flightActivated',false/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.doesNotMatch(sql,/\bINSERT INTO airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE airlinerra_game\./i);
});
test('the private API calls only the two-leg read-only query',async()=>{
 const src=await read('server/flight-schedule-service.mjs');
 assert.match(SCHEDULE_SQL.roundtripPreview,/section9_owned_roundtrip_candidate_preview_v1/);
 assert.match(src,/body\.action==='roundtrip-preview'/);
 assert.match(src,/SCHEDULE_SQL\.owner/);
 assert.match(src,/SCHEDULE_SQL\.roundtripPreview/);
 assert.match(src,/result\.flightsCreated!==0/);
 assert.match(src,/result\.slotsReserved!==false/);
 assert.match(src,/result\.flightActivated!==false/);
 assert.match(src,/result\.ledgerPosted!==false/);
 assert.match(src,/GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE/);
});
test('player schedule client explicitly exposes preview without a create action',async()=>{
 const client=await read('website/flight-schedule-client.mjs');
 assert.match(client,/roundtripPreview:\(\{/);
 assert.match(client,/post\(\{action:'roundtrip-preview'/);
 assert.match(client,/returnWeeklySchedule/);
});
