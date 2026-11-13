import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const sqlPath='supabase/migrations/20261113111500_section9_starter_commissioning_request_workflow_v1.sql';

test('starter commissioning requests are private, owner-bound and repeat safe',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/CREATE TABLE airlinerra_game\.section9_starter_commissioning_requests_v1/);
 assert.match(sql,/aircraft_inventory_id uuid NOT NULL UNIQUE/);
 assert.match(sql,/s\.source_kind='original_airline_starter_allocation'/);
 assert.match(sql,/s\.owner_player_id=p_player AND s\.airline_id=p_airline/);
 assert.match(sql,/a\.owner_player_id=s\.owner_player_id/);
 assert.match(sql,/w\.state='active'/);
 assert.match(sql,/f\.registration=s\.registration AND f\.configuration_id=s\.configuration_id/);
 assert.match(sql,/ON CONFLICT \(aircraft_inventory_id\) DO NOTHING/);
 assert.match(sql,/GET DIAGNOSTICS inserted_count=ROW_COUNT/);
 assert.match(sql,/source_fixture_id IS NOT NULL/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL ON TABLE airlinerra_game\.section9_starter_commissioning_requests_v1/);
 assert.match(sql,/REVOKE ALL ON FUNCTION airlinerra_game\.section9_owned_starter_commissioning_v1/);
});

test('commissioning requests cannot fabricate condition, maintenance, inspected year or billing',async()=>{
 const sql=await read(sqlPath);
 assert.match(sql,/request_status text NOT NULL DEFAULT 'requested'/);
 assert.match(sql,/'inspectionCompleted',false/);
 assert.match(sql,/'maintenanceCompleted',false/);
 assert.match(sql,/'flightActivated',false/);
 assert.match(sql,/'ledgerPosted',false/);
 assert.match(sql,/'conditionVerified',false/);
 assert.match(sql,/'manufactureYearVerified',false/);
 assert.match(sql,/section9_operated_flight_movements_v1/);
 assert.match(sql,/verified_original_starter_allocation_since_assignment/);
 assert.doesNotMatch(sql,/\b(?:INSERT INTO|UPDATE)\s+airlinerra_game\.aircraft_maintenance_state_v1/i);
 assert.doesNotMatch(sql,/\b(?:INSERT INTO|UPDATE)\s+airlinerra_game\.section9_aircraft_condition_assessments_v1/i);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\.aircraft_maintenance_completions_v1/i);
 assert.doesNotMatch(sql,/\bINSERT INTO\s+airlinerra_game\.section9_operated_flight_movements_v1/i);
});

test('verified bearer session connects to owner-scoped commissioning request/status only',async()=>{
 const service=await read('server/flight-schedule-service.mjs');
 const entry=await read('server/flight-schedule-edge-entry.ts');
 assert.match(service,/COMMISSIONING_FIELDS=new Set\(\[\.\.\.BASE_FIELDS,'aircraftInventoryId'\]\)/);
 assert.match(service,/body\.action==='commissioning-status'\|\|body\.action==='commissioning-request'/);
 assert.match(service,/withinFields\(body,COMMISSIONING_FIELDS\)&&uuid\(body\.aircraftInventoryId\)/);
 assert.match(service,/commissioning:`SELECT airlinerra_game\.section9_owned_starter_commissioning_v1/);
 assert.match(service,/userId,body\.airlineId,body\.aircraftInventoryId,action/);
 assert.match(service,/COMMISSIONING_STATUS_UNVERIFIED/);
 assert.match(service,/result\.flightActivated!==false/);
 assert.match(service,/result\.inspectionCompleted!==false/);
 assert.match(entry,/createHostedAuthVerifier/);
 assert.match(entry,/createFlightScheduleHandler/);
 assert.match(service,/if\(auth\?\.error\|\|!uuid\(userId\)\)/);
 const start=service.indexOf("if(body.action==='commissioning-status'||body.action==='commissioning-request'){",service.indexOf('export function createFlightScheduleHandler'));
 const end=service.indexOf("if(body.action==='operational-create'){",start);
 assert.ok(start>0&&end>start,'scope the commissioning API branch');
 assert.doesNotMatch(service.slice(start,end),/\b(?:INSERT INTO|UPDATE|DELETE FROM)\b/i);
 assert.match(service,/routeCreated:false/);
});
