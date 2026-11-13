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


test('sourced Tivat winter 2026/27 airport hours remain review-only, with daylight consent exception',async()=>{
 const sql=await read('supabase/migrations/20261113202000_section5_tivat_winter_2026_27_operating_hours_review.sql');
 assert.match(sql,/TIVAT_WINTER_2026_27_OUTSIDE_MANDATORY_OPEN_HOURS/);
 assert.match(sql,/'16:30'::time,'07:00'::time/);
 assert.match(sql,/DATE '2026-10-25',DATE '2027-03-27'/);
 assert.match(sql,/'OPERATING_HOURS_REVIEW'/);
 assert.match(sql,/game_auto_enforcement/);
 assert.match(sql,/NULL::smallint\[\],false,false,true/);
 assert.match(sql,/prior airport operator consent and daylight/);
 assert.match(sql,/sluzbenilist\.me\/propisi\/399378/);
});
test('owner route candidate includes four-week per-airport evidence details, never approvals',async()=>{
 const sql=await read('supabase/migrations/20261113203000_section9_owner_candidate_airport_restriction_evidence_details.sql');
 assert.match(sql,/airport_findings jsonb:=NULL/);
 assert.match(sql,/restrictionDecision/);
 assert.match(sql,/weeklyOccurrencesChecked/);
 assert.match(sql,/runwayOperationalStatusVerified/);
 assert.match(sql,/aircraftChapterMatched/);
 assert.match(sql,/anyHardTimeRuleBlock/);
 assert.match(sql,/'airportRestrictionFindings',airport_findings/);
 assert.match(sql,/'operationApproved',false/);
 assert.match(sql,/'airportSlotsReserved',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});
test('blocked route response carries read-only airport evidence through client into explicit UI blockers',async()=>{
 const server=await read('server/flight-schedule-service.mjs');
 const client=await read('website/flight-schedule-client.mjs');
 const planner=await read('website/route-planner.mjs');
 assert.match(server,/gameAirportRestrictionFindings:/);
 assert.match(server,/candidate\.airportRestrictionFindings\?\.readOnly===true/);
 assert.match(server,/candidate\.airportRestrictionFindings\?\.operationApproved===false/);
 assert.match(client,/conflict\.operationalAirportFindings=/);
 assert.match(client,/reason\.gameAirportRestrictionFindings\?\.readOnly===true/);
 assert.match(planner,/unresolvedAirports/);
 assert.match(planner,/runway status/);
 assert.match(planner,/aircraft noise certificate/);
 assert.match(planner,/NOT CREATED/);
});


test('preliminary game suitability never acts as operational flight clearance',async()=>{
 const sql=await read('supabase/migrations/20261113210000_section9_shared_game_model_preliminary_route_suitability_v1.sql');
 assert.match(sql,/'gameModelPreliminarySuitable'/);
 assert.match(sql,/'gameModelEvidenceType','GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE'/);
 assert.match(sql,/'gameModelChecks'/);
 assert.match(sql,/'gameModelFlightActivated',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'airportSlotsReserved',false/);
 assert.match(sql,/'operatorLicenceOperationallyVerified',false/);
 assert.match(sql,/'operationallyApproved',false/);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\./i);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\./i);
});
test('game permission fee draft is worldwide but applications cannot issue or charge',async()=>{
 const sql=await read('supabase/migrations/20261113211000_section9_global_game_licence_fee_policy_draft_v1.sql');
 for(const code of ['AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM'])
  assert.match(sql,new RegExp(code));
 assert.match(sql,/enabled_in_game=false/);
 assert.match(sql,/release_enabled,validity_game_days/);
 assert.match(sql,/false,365,1/);
 assert.match(sql,/ON CONFLICT\(permission_code\) DO NOTHING/);
 assert.doesNotMatch(sql,/SET\s+enabled_in_game\s*=\s*true/i);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\.airline_ledger/i);
});
test('UI carries model estimate but keeps operational route creation blocked',async()=>{
 const server=await read('server/flight-schedule-service.mjs');
 const client=await read('website/flight-schedule-client.mjs');
 const planner=await read('website/route-planner.mjs');
 assert.match(server,/gameModelPreliminarySuitable:/);
 assert.match(server,/gameModelEvidenceType:'GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE'/);
 assert.match(server,/routeCreated:false/);
 assert.match(client,/conflict\.gameModelPreliminarySuitable=reason\.gameModelPreliminarySuitable/);
 assert.match(planner,/error\?\.gameModelPreliminarySuitable===true/);
 assert.match(planner,/game estimate, not an operating clearance/);
 assert.match(planner,/NOT CREATED/);
});
