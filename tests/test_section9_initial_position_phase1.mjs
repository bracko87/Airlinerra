import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('starter initial allocation is a valid origin ONLY before any verified movement',async()=>{
 const sql=await read('supabase/migrations/20261112182500_section9_aircraft_position_resolver_record_alias_repair.sql');
 assert.match(sql,/section9_starter_origin_evidence_v1/);
 assert.match(sql,/starter->>'sourceKind'='original_airline_starter_allocation'/);
 assert.match(sql,/starter->>'airportKey'=aircraft_row.home_airport_key/);
 assert.match(sql,/section9_operated_flight_movements_v1/);
 assert.match(sql,/IF EXISTS\([\s\S]*?FROM airlinerra_game.section9_operated_flight_movements_v1[\s\S]*?THEN RETURN jsonb_build_object\([\s\S]*?'status','operated_position_record_missing'/);
 assert.match(sql,/SELECT \* INTO pos/);
 assert.match(sql,/IF FOUND THEN\s+SELECT \* INTO movement_row/);
 assert.match(sql,/m\.actual_event_utc|movement_row\.actual_event_utc/);
 assert.match(sql,/later.actual_event_utc>movement_row.actual_event_utc/);
 assert.match(sql,/current_position_movement_evidence_mismatch/);
 assert.match(sql,/verified_original_game_starter_position/);
 assert.match(sql,/initialOnly',true/);
 assert.match(sql,/readOnly',true/);
 assert.match(sql,/flightActivated',false/);
 assert.match(sql,/movementRecorded',false/);
 assert.doesNotMatch(sql,/(?:INSERT|UPDATE|DELETE)\s+(?:INTO|FROM)?\s*airlinerra_game/i);
 assert.match(sql,/SECURITY INVOKER/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
});
test('preflight uses initial or last signed position, not a browser hub assumption',async()=>{
 const sql=await read('supabase/migrations/20261112184000_section9_noncrew_preflight_verified_game_position.sql');
 assert.match(sql,/section9_owned_aircraft_operational_position_v1\(/);
 assert.match(sql,/verified_position->>'verified' IS DISTINCT FROM 'true'/);
 assert.match(sql,/verified_position->>'atGroundAirport'='true'/);
 assert.match(sql,/verified_position->>'airportKey'/);
 assert.match(sql,/movements->>'deliveryAnchorValid' IS DISTINCT FROM 'true'/);
 assert.match(sql,/aircraftDeliveryAnchorVerified/);
 assert.match(sql,/initialGamePositionVerified/);
 assert.match(sql,/crewDeferredPhase1/);
 assert.match(sql,/crewRequired',NOT crew_deferred/);
 assert.match(sql,/IF NOT crew_deferred AND NOT crew_proposed/);
 assert.match(sql,/IF NOT crew_deferred THEN/);
 for(const blocker of [
  'AIRPORT_SLOT_CAPACITY_NOT_CERTIFIED_FOR_ACTIVATION',
  'OPERATOR_LICENCE_AND_TRAFFIC_RIGHTS_NOT_GRANTED',
  'TRUSTED_FLIGHT_EXECUTION_PRODUCER_NOT_CONNECTED',
  'COMMERCIAL_FLIGHT_ACTIVATION_NOT_RELEASED',
  'AIRCRAFT_ROTATION_HAS_CONFLICTS_OR_UNKNOWN_DATA'
 ])assert.ok(sql.includes(blocker),blocker);
 assert.match(sql,/canActivateNormalFlight',false/);
 assert.match(sql,/flightActivated',false/);
 assert.match(sql,/bookingsCreated',false/);
 assert.match(sql,/ledgerPosted',false/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
});
test('route API trusts server-only position provenance, not supplied airplane airport',async()=>{
 const api=await read('server/flight-schedule-service.mjs');
 assert.match(api,/aircraftPrerequisites:`SELECT/);
 assert.match(api,/section9_owned_aircraft_operational_position_v1\(/);
 assert.match(api,/location\.position->>'verified'/);
 assert.match(api,/location\.position->>'airportKey'=\$4::text/);
 assert.match(api,/AIRCRAFT_STARTING_LOCATION_NOT_VERIFIED/);
 assert.match(api,/AIRCRAFT_NOT_VERIFIED_AT_ORIGIN/);
 assert.match(api,/originalStarterPosition:aircraft\?\.originalStarterPosition===true/);
 assert.match(api,/fuelDispatchModelApproved/);
 assert.match(api,/fuelAccountingModelApproved/);
 assert.match(api,/automatic_flight_and_fuel_settlement_enabled/);
 assert.match(api,/routeCreated:false/);
 assert.doesNotMatch(api,/action==='operational-create'[\s\S]*?INSERT INTO airlinerra_game/);
});
