import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

const main='supabase/migrations/20261113103000_section9_owned_aircraft_maintenance_readiness_v1.sql';
const guard='supabase/migrations/20261113105500_section9_missing_maintenance_state_fails_closed.sql';

test('condition/age require a trusted reviewed inspection, never starter allocation alone',async()=>{
 const sql=await read(main);
 assert.match(sql,/CREATE TABLE airlinerra_game\.section9_aircraft_condition_assessments_v1/);
 assert.match(sql,/source_review_status text NOT NULL DEFAULT 'pending'/);
 assert.match(sql,/e\.source_review_status='verified'/);
 assert.match(sql,/state_row\.condition_pct=approved_assessment\.inspected_condition_pct/);
 assert.match(sql,/state_row\.condition_basis='verified_game_inspection'/);
 assert.match(sql,/state_row\.manufacture_year=approved_assessment\.inspected_manufacture_year/);
 assert.match(sql,/state_row\.manufacture_year_basis='verified_game_inspection'/);
 assert.match(sql,/AIRCRAFT_CONDITION_INSPECTION_NOT_VERIFIED/);
 assert.match(sql,/AIRCRAFT_MANUFACTURE_YEAR_NOT_VERIFIED/);
 assert.doesNotMatch(sql,/\b(?:SET\s+condition_pct|SET\s+manufacture_year|INSERT\s+INTO\s+airlinerra_game\.aircraft_maintenance_completions_v1)/i);
});

test('maintenance gate belongs to verified owner, clock and actual check receipts',async()=>{
 const sql=await read(main);
 assert.match(sql,/a\.owner_player_id=p_player/);
 assert.match(sql,/w\.state='active'/);
 assert.match(sql,/clock_row\.confirmed_game_date IS DISTINCT FROM p_game_day/);
 assert.match(sql,/m\.tracked_flight_hours>=0/);
 assert.match(sql,/tracked_flight_hours>=0/);
 assert.match(sql,/aircraft_maintenance_completions_v1/);
 assert.match(sql,/count\(DISTINCT c\.check_code\)/);
 assert.match(sql,/MAINTENANCE_CHECK_HISTORY_INCOMPLETE/);
 assert.match(sql,/MAINTENANCE_DUE_SCHEDULE_NOT_OPERATIONALLY_CONNECTED/);
 assert.match(sql,/MAINTENANCE_GROUNDING_AND_AVAILABILITY_NOT_CONNECTED/);
 assert.match(sql,/STABLE SECURITY INVOKER/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/FROM PUBLIC,anon,authenticated,service_role/);
 assert.match(sql,/'maintenanceReady',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'ledgerPosted',false/);
});

test('missing maintenance record fails closed before reading absent state',async()=>{
 const sql=await read(guard);
 assert.match(sql,/IF NOT FOUND THEN\s+RETURN jsonb_build_object/);
 assert.match(sql,/'status','maintenance_state_missing'/);
 assert.match(sql,/'AIRCRAFT_MAINTENANCE_STATE_MISSING'/);
 assert.match(sql,/'maintenanceReady',false/);
 assert.match(sql,/CREATE OR REPLACE FUNCTION airlinerra_game\.section9_owned_aircraft_maintenance_readiness_v1/);
});

test('protected route creation calls the private gate, reports specific blockers and cannot activate',async()=>{
 const api=await read('server/flight-schedule-service.mjs');
 assert.match(api,/maintenanceReadiness:`SELECT airlinerra_game\.section9_owned_aircraft_maintenance_readiness_v1/);
 assert.match(api,/const receipt=await client\.query\(SCHEDULE_SQL\.maintenanceReadiness/);
 assert.match(api,/maintenance\.readOnly!==true/);
 assert.match(api,/maintenance\.maintenanceReady!==false/);
 assert.match(api,/maintenance\.dispatchApproved!==false/);
 assert.match(api,/MAINTENANCE_EVIDENCE_UNAVAILABLE/);
 assert.match(api,/conditionEvidenceVerified:maintenance\?\.conditionEvidenceVerified===true/);
 assert.match(api,/manufactureYearVerified:maintenance\?\.manufactureYearVerified===true/);
 assert.match(api,/maintenanceDueEvaluationConnected:maintenance\?\.checkDueEvaluationConnected===true/);
 const start=api.indexOf("if(body.action==='operational-create'){");
 const end=api.indexOf("if(body.action==='plan-save'){",start);
 assert.ok(start>0&&end>start);
 assert.doesNotMatch(api.slice(start,end),/\b(?:INSERT INTO|UPDATE|DELETE FROM)\b/i);
 assert.match(api.slice(start,end),/routeCreated:false/);
});
