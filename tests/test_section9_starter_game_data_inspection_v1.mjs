import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const MIG='supabase/migrations/20261113124000_section9_starter_game_data_inspection_v1.sql';

test('game-data commissioning inspection verifies six source-of-truth inputs',async()=>{
 const sql=await read(MIG);
 assert.match(sql,/section9_starter_commissioning_game_checks_v1/);
 for(const check of [
  'original_allocation','owner_membership','authoritative_world_clock',
  'verified_initial_position','verified_usage_baseline','no_operated_flights'
 ])assert.match(sql,new RegExp("'"+check+"'"));
 assert.match(sql,/s\.source_fixture_id=req\.original_fixture_id/);
 assert.match(sql,/a\.owner_player_id=s\.owner_player_id/);
 assert.match(sql,/w\.state='active'/);
 assert.match(sql,/world_clock\.clock_source IS DISTINCT FROM 'authoritative_game_engine'/);
 assert.match(sql,/section9_starter_origin_evidence_v1/);
 assert.match(sql,/maintenance\.verified_tracking_started_utc IS DISTINCT FROM starter\.assigned_at/);
 assert.match(sql,/section9_operated_flight_movements_v1/);
 assert.match(sql,/coalesce\(array_length\(blocked,1\),0\)>0/);
});
test('idempotent in-review only after six successful checks; nothing declares physical clearance',async()=>{
 const sql=await read(MIG);
 assert.match(sql,/FOR UPDATE/);
 assert.match(sql,/ON CONFLICT \(request_id,check_code\) DO NOTHING/);
 assert.match(sql,/IF check_count<>6 THEN RAISE EXCEPTION/);
 assert.match(sql,/SET request_status='in_review'/);
 assert.match(sql,/WHERE r\.request_id=req\.request_id AND r\.request_status='requested'/);
 assert.match(sql,/'gameDataInspectionComplete',true/);
 assert.match(sql,/'conditionVerified',false/);
 assert.match(sql,/'manufactureYearVerified',false/);
 assert.match(sql,/'maintenanceInspectionCompleted',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.doesNotMatch(sql,/\bUPDATE\s+airlinerra_game\.aircraft_maintenance_state_v1/i);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\.section9_aircraft_condition_assessments_v1/i);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\.aircraft_maintenance_completions_v1/i);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\.section9_operated_flight_movements_v1/i);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(sql,/SECURITY INVOKER/);
});
test('protected route API exposes limited game-data checks, not fake inspector result',async()=>{
 const service=await read('server/flight-schedule-service.mjs');
 assert.match(service,/commissioningDataInspection:`SELECT airlinerra_game\.section9_owned_starter_game_data_inspection_v1/);
 assert.match(service,/SCHEDULE_SQL\.commissioningDataInspection/);
 assert.match(service,/action==='request'\?'run':'status'/);
 assert.match(service,/COMMISSIONING_GAME_DATA_EVIDENCE_UNAVAILABLE/);
 assert.match(service,/gameDataInspectionComplete:gameData\?\.gameDataInspectionComplete===true/);
 assert.match(service,/physicalConditionVerified:false/);
 assert.match(service,/manufactureYearVerified:false/);
 assert.match(service,/physicalInspectionCompleted:false/);
 assert.match(service,/aircraftClearedForFlight:false/);
 assert.match(service,/routeCreated:false/);
});
