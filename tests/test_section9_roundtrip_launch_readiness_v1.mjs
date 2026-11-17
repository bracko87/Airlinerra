import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const sqlPath='supabase/migrations/20261117120000_section9_roundtrip_launch_readiness_gates_v1.sql';

test('read-only launch preview keeps operational status separate from valid timetable',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/section9_owned_roundtrip_launch_readiness_v1/);
 assert.match(sql,/section9_owned_roundtrip_candidate_preview_v1/);
 assert.match(sql,/TIMETABLE_VALID_BUT_OPERATIONAL_RELEASE_PENDING/);
 assert.match(sql,/readyForAtomicOperationalCreate',false/);
 assert.match(sql,/gamePermissionApplicationSubmitted',false/);
 assert.match(sql,/gamePermissionApplicationFeeCharged',false/);
 assert.match(sql,/newSchedulesCreated',0/);
 assert.match(sql,/launchBlockers',to_jsonb\(block_codes\)/);
});

test('short turnaround is rejected before looking up future licences',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/GAME_TIMETABLE_OR_SLOTS_BLOCKED/);
 const input=sql.indexOf('gameRoundtripModelSuitable');
 const permission=sql.indexOf('SELECT country_iso INTO origin_country');
 assert.ok(input>=0&&permission>input);
 assert.match(sql,/launchStatus','TIMETABLE_AND_OPERATIONAL_RELEASE_PENDING/);
});

test('current aircraft position and future permit validity use separate game dates',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/section9_verified_berlin_game_hour_v1/);
 assert.match(sql,/reference_date:=\(p_out_depart AT TIME ZONE coalesce\(tz_origin,'Europe\/Berlin'\)\)::date/);
 assert.match(sql,/p_player,p_airline,p_aircraft,\(clock_proof->>'gameDate'\)::date/);
 assert.match(sql,/AIRCRAFT_ORIGIN_POSITION_NOT_VERIFIED/);
 assert.match(sql,/DEPARTURE_NOT_IN_FUTURE_GAME_WINDOW/);
});

test('licence, direction-specific route rights and separate game releases are required',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/AIR_OPERATOR_CERTIFICATE/);
 assert.match(sql,/section9_required_game_traffic_permission_v1/);
 assert.match(sql,/section9_operator_licence_evidence_v1/);
 assert.match(sql,/section9_route_operating_permission_evidence_v1/);
 assert.match(sql,/OUTBOUND_GAME_TRAFFIC_RIGHTS_NOT_ISSUED/);
 assert.match(sql,/RETURN_GAME_TRAFFIC_RIGHTS_NOT_ISSUED/);
 assert.match(sql,/ONCE_ONLY_FINANCIAL_SETTLEMENT_NOT_RELEASED/);
 assert.match(sql,/AIRCRAFT_GAME_FUEL_DISPATCH_AND_FINANCE_NOT_RELEASED/);
 assert.match(sql,/AIRPORT_REVIEWS_NOT_COMPLETED/);
});

test('hard rollback remains, and both previews use new read-only checks',async()=>{
 const sql=await read(sqlPath);
 assert.equal((sql.match(/preview:=airlinerra_game.section9_owned_roundtrip_launch_readiness_v1/g)||[]).length,2);
 assert.match(sql,/ROUNDTRIP_BOOKING_AND_EXECUTION_NOT_CONNECTED_FULL_ROLLBACK/);
 assert.match(sql,/ATOMIC_BOOKING_AND_FLIGHT_BRIDGE_NOT_COMPLETED/);
 const previewSource=sql.slice(0,sql.indexOf('CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_atomic_roundtrip_operational_create_v1'));
 assert.doesNotMatch(previewSource,/\bINSERT INTO\b/);
 assert.doesNotMatch(previewSource,/\bUPDATE airlinerra_game\./);
 assert.doesNotMatch(previewSource,/\bDELETE FROM airlinerra_game\./);
 assert.match(sql,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_owned_roundtrip_launch_readiness_v1/);
 assert.doesNotMatch(sql,/SECURITY DEFINER/i);
});

test('API preview uses new launch gate while retaining old response safety contract',async()=>{
 const server=await read('server/flight-schedule-service.mjs');
 assert.match(SCHEDULE_SQL.roundtripPreview,/section9_owned_roundtrip_launch_readiness_v1/);
 assert.match(server,/ROUNDTRIP_PREVIEW_NOT_VERIFIED/);
 assert.match(server,/result\.flightsCreated!==0/);
 assert.match(server,/result\.slotsReserved!==false/);
 assert.match(server,/result\.ledgerPosted!==false/);
});

test('UI distinguishes valid timing from missing licences, fuel and booking bridge',async()=>{
 const client=await read('website/flight-schedule-client.mjs');
 const ui=await read('website/route-planner.mjs');
 assert.match(client,/conflict\.launchBlockers=/);
 assert.match(client,/reason\.roundtripPreview\.launchBlockers/);
 assert.match(ui,/error\.roundtripModelPassed===true/);
 assert.match(ui,/GAME_OPERATOR_LICENCE_NOT_ISSUED/);
 assert.match(ui,/ATOMIC_BOOKING_AND_FLIGHT_BRIDGE_NOT_COMPLETED/);
 assert.match(ui,/The flight engine is not released\./);
 assert.match(ui,/NOT CREATED — neither flight was changed or booked\./);
});


test('atomic route creation is restricted to trusted postgres and cannot be called by client data API role',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/ROUNDTRIP_PRIVATE_TRUSTED_SERVER_ONLY/);
 assert.match(sql,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(sql,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_owned_atomic_roundtrip_operational_create_v1/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(sql,/ROUNDTRIP_BOOKING_AND_EXECUTION_NOT_CONNECTED_FULL_ROLLBACK/);
});
