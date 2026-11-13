import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const path='supabase/migrations/20261113192000_section9_owned_candidate_slot_rights_preflight_v1.sql';

test('owner-scoped candidate route reuses existing airfield slots, restrictions, and issued game grants',async()=>{
 const sql=await read(path);
 assert.match(sql,/CREATE FUNCTION airlinerra_game\.section9_owned_candidate_slot_rights_preflight_v1/);
 assert.match(sql,/SECURITY INVOKER/);
 assert.match(sql,/a\.owner_player_id=p_player/);
 assert.match(sql,/w\.state='active'/);
 assert.match(sql,/section9_verified_world_instant_v1/);
 assert.match(sql,/section6_weekly_slot_preflight_v1/);
 assert.match(sql,/section5_weekly_route_restriction_gate_v1/);
 assert.match(sql,/section9_required_game_traffic_permission_v1/);
 assert.match(sql,/section9_route_operating_permission_evidence_v1/);
 assert.match(sql,/section9_game_permission_applications_v1/);
 assert.match(sql,/evidence\.evidence_status='verified'/);
 assert.match(sql,/app\.status='issued'/);
 assert.match(sql,/app\.ledger_entry_id IS NOT NULL/);
 assert.match(sql,/GROUP2_AIRPORT_NOT_OPERATIONALLY_ADMITTED/);
 assert.match(sql,/REFERENCE_UTC_DEPARTURE_AND_ARRIVAL_REQUIRED/);
 assert.match(sql,/AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED/);
 assert.match(sql,/TRAFFIC_RIGHTS_NOT_GRANTED/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
});
test('capacity preview is not a real reservation or licence, ever',async()=>{
 const sql=await read(path);
 assert.match(sql,/'airportSlotsReserved',false/);
 assert.match(sql,/'trafficRightsOperationallyApproved',false/);
 assert.match(sql,/'operatorLicenceOperationallyVerified',false/);
 assert.match(sql,/'operatingScheduleCreated',false/);
 assert.match(sql,/'operationallyApproved',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'passengerBookingsCreated',false/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});
test('protected operational-create reports slot and rights problems without writing any flight',async()=>{
 const source=await read('server/flight-schedule-service.mjs');
 assert.match(source,/candidateSlotRights:`SELECT airlinerra_game\.section9_owned_candidate_slot_rights_preflight_v1/);
 assert.match(source,/SCHEDULE_SQL\.candidateSlotRights/);
 assert.match(source,/JSON\.stringify\(body\.weeklySchedule\)/);
 assert.match(source,/GAME_SLOT_RIGHTS_PREFLIGHT_UNVERIFIED/);
 assert.match(source,/GAME_ROUTE_TRAFFIC_PERMISSION_NOT_GRANTED/);
 assert.match(source,/AIRPORT_SLOT_CAPACITY_NOT_VERIFIED_FOR_ROUTE/);
 assert.match(source,/gameAirportSlotCapacityAvailable:/);
 assert.match(source,/gameTrafficGrantsVerified:/);
 assert.match(source,/RECURRING_MAINTENANCE_WINDOW_CERTIFICATION_NOT_CONNECTED/);
 assert.match(source,/routeCreated:false/);
 assert.match(source,/slotsReserved:false/);
});


test('game international home-carrier route names the required third/fourth-freedom permission but does not grant it',async()=>{
 const sql=await read('supabase/migrations/20261113200000_section9_classify_required_international_game_traffic_rights.sql');
 assert.match(sql,/preview->>'status'='agreement_check_required'/);
 assert.match(sql,/p_origin<>p_destination/);
 assert.match(sql,/p_operator=p_origin OR p_operator=p_destination/);
 assert.match(sql,/RETURN 'THIRD_FOURTH_FREEDOM'/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});
test('game rights candidate checker has qualified permission variable and remains no-write',async()=>{
 const sql=await read('supabase/migrations/20261113201000_section9_candidate_slot_rights_permission_variable_fix.sql');
 assert.match(sql,/v_permission_code text/);
 assert.match(sql,/catalog\.permission_code=v_permission_code/);
 assert.match(sql,/app\.permission_code=v_permission_code/);
 assert.match(sql,/'requiredGamePermission',v_permission_code/);
 assert.doesNotMatch(sql,/\bcatalog\.permission_code=permission_code/);
 assert.doesNotMatch(sql,/\bapp\.permission_code=permission_code/);
 assert.match(sql,/'airportSlotsReserved',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});
