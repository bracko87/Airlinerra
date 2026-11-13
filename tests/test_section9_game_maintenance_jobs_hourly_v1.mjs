import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('game-hour clock requires matching daily signed proof, 1:1 Berlin date and active world',async()=>{
 const sql=await read('supabase/migrations/20261113170000_section9_hourly_verified_maintenance_jobs_v1.sql');
 assert.match(sql,/CREATE FUNCTION airlinerra_game\.section9_verified_world_instant_v1/);
 assert.match(sql,/c\.confirmed_game_date IS DISTINCT FROM \(x AT TIME ZONE 'Europe\/Berlin'\)::date/);
 assert.match(sql,/section9_verified_game_tick_receipts_v1/);
 assert.match(sql,/r\.engine_event_id=c\.engine_proof_ref/);
 assert.match(sql,/length\(r\.event_hmac_sha256\)=64/);
 assert.match(sql,/c\.producer_status IS DISTINCT FROM 'enabled'/);
 assert.match(sql,/c\.last_verified_at<x-interval '26 hours'/);
 assert.match(sql,/SECTION9_SIGNED_HOUR_GAME_CLOCK_NOT_VERIFIED/);
 assert.match(sql,/SECURITY INVOKER/);
});
test('private job ledger enforces one live job per airframe, aircraft position, MRO and no money',async()=>{
 const sql=await read('supabase/migrations/20261113170000_section9_hourly_verified_maintenance_jobs_v1.sql');
 const alias=await read('supabase/migrations/20261113172000_section9_maintenance_job_aircraft_alias_repair.sql');
 assert.match(sql,/CREATE UNIQUE INDEX section9_one_unfinished_game_maintenance_job_per_aircraft_v1/);
 assert.match(sql,/WHERE status IN \('scheduled','in_progress'\)/);
 assert.match(sql,/FOR UPDATE OF fleet/);
 assert.match(sql,/section9_owned_aircraft_operational_position_v1/);
 assert.match(sql,/approval_status='game_approved'/);
 assert.match(sql,/airline_flight_schedule_drafts_v1/);
 assert.match(sql,/section9_dated_flight_occurrences_v1/);
 assert.match(sql,/CHECK\(cost_usd IS NULL\)/);
 assert.match(sql,/CHECK\(paid_usd IS NULL\)/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(alias,/CREATE OR REPLACE FUNCTION airlinerra_game\.section9_owned_game_maintenance_job_v1/);
 assert.match(alias,/section9_dated_flight_occurrences_v1 fo/);
 assert.doesNotMatch(alias,/FROM airlinerra_game\.section9_dated_flight_occurrences_v1 f\n/);
 assert.doesNotMatch(sql,/INSERT INTO\s+airlinerra_game\.section9_route_posted_flight_financials_v1/i);
});
test('engine completion is atomic, exactly once, isolated from physical checks and finances',async()=>{
 const sql=await read('supabase/migrations/20261113170000_section9_hourly_verified_maintenance_jobs_v1.sql');
 const cron=await read('supabase/migrations/20261113175000_section9_world1_maintenance_minute_cron.sql');
 assert.match(sql,/CREATE FUNCTION airlinerra_game\.section9_advance_game_maintenance_jobs_v1/);
 assert.match(sql,/FOR UPDATE SKIP LOCKED/);
 assert.match(sql,/status='in_progress',engine_start_observed_at=v_now/);
 assert.match(sql,/status='completed',engine_completion_observed_at=v_now/);
 assert.match(sql,/ON CONFLICT\(job_id\) DO NOTHING/);
 assert.match(sql,/verified_game_service_job_v1/);
 assert.match(sql,/'physicalInspectionsRecorded',0,'financialPostings',0,'flightsActivated',0/);
 assert.match(cron,/cron\.schedule\('airlinerra-section9-game-maintenance-v1','\* \* \* \* \*'/);
 assert.match(cron,/section9_advance_game_maintenance_jobs_v1\(\)/);
});
test('due evaluator resets from completed game job receipts and grounds while job reserved',async()=>{
 const sql=await read('supabase/migrations/20261113174000_section9_maintenance_due_uses_game_job_receipts.sql');
 assert.match(sql,/section9_game_maintenance_service_receipts_v1/);
 assert.match(sql,/latest\.game_completed_at_utc/);
 assert.match(sql,/last_hours\+policy\.flight_hour_interval/);
 assert.match(sql,/job_block/);
 assert.match(sql,/gameMaintenanceGrounded',\(due_count>0 OR job_block\)/);
 assert.match(sql,/maintenanceCompletionSchedulingConnected',true/);
 assert.match(sql,/realManufactureYearVerified',false/);
});
test('production API validates owner scoped book/status/cancel and reports service reservation preflight',async()=>{
 const api=await read('server/flight-schedule-service.mjs');
 assert.match(api,/MAINTENANCE_JOB_FIELDS=new Set/);
 assert.match(api,/withinFields\(body,MAINTENANCE_JOB_FIELDS\)/);
 assert.match(api,/maintenanceGameJob:`SELECT airlinerra_game\.section9_owned_game_maintenance_job_v1/);
 assert.match(api,/SCHEDULE_SQL\.maintenanceGameJob/);
 assert.match(api,/GAME_MAINTENANCE_JOB_RESPONSE_UNVERIFIED/);
 assert.match(api,/AIRCRAFT_ALREADY_RESERVED_FOR_MAINTENANCE/);
 assert.match(api,/GAME_AIRCRAFT_MAINTENANCE_CHECK_DUE/);
 assert.match(api,/routeCreated:false/);
});
test('authenticated player client submits maintenance booking and cancellation with bearer credentials',async()=>{
 const payloads=[];
 const client=createFlightScheduleClient({
  origin:'https://airlinerra.com',
  auth:{getAccessToken:async()=> 'fake-token-for-tests-123456789012'},
  fetchImpl:async(url,options)=>{
   const payload=JSON.parse(options.body);payloads.push(payload);
   assert.equal(options.method,'POST');
   assert.equal(options.headers.authorization,'Bearer fake-token-for-tests-123456789012');
   assert.equal(options.credentials,'omit');
   return Response.json(payload.action==='maintenance-job-status'?
    {status:'game_maintenance_jobs',jobs:[],flightActivated:false,ledgerPosted:false}:
    payload.action==='maintenance-job-book'?
    {status:'scheduled',created:true,jobId:'test-id',gameJobOnly:true,flightActivated:false,ledgerPosted:false}:
    {status:'cancelled',changed:true,flightActivated:false,ledgerPosted:false});
  }
 });
 const ids={airlineId:'00000000-0000-4000-8000-000000000001',
  aircraftInventoryId:'00000000-0000-4000-8000-000000000002'};
 await client.maintenanceJobStatus(ids);
 await client.maintenanceJobBook({...ids,checkCode:'daily'});
 await client.maintenanceJobCancel(ids);
 assert.deepEqual(payloads.map(p=>p.action),[
  'maintenance-job-status','maintenance-job-book','maintenance-job-cancel']);
 assert.equal(payloads[1].checkCode,'daily');
 assert.equal(payloads[2].checkCode,undefined);
});
test('aircraft details UI has six small maintenance buttons and no fake clearance',async()=>{
 const ui=await read('website/airline-workspace.mjs');
 assert.match(ui,/id="fleet-game-maintenance-jobs"/);
 for(const code of ['daily','weekly','a','b','c','d'])
  assert.match(ui,new RegExp('data-game-maint-check="'+code+'"'));
 assert.match(ui,/async function loadGameMaintenanceJobs\(aircraftId\)/);
 assert.match(ui,/scheduler\.maintenanceJobStatus\(/);
 assert.match(ui,/scheduler\?\.maintenanceJobBook/);
 assert.match(ui,/scheduler\?\.maintenanceJobCancel/);
 assert.match(ui,/The aircraft is reserved until the check completes/);
 assert.match(ui,/No financial charge posted/);
 assert.match(ui,/has NOT received operational clearance|NOT received operational clearance/);
});
test('exact 1:1 flight window checks full UTC maintenance overlap plus overnight due dates',async()=>{
 const sql=await read('supabase/migrations/20261113180000_section9_hour_level_maintenance_flight_window_gate.sql');
 const api=await read('server/flight-schedule-service.mjs');
 assert.match(sql,/CREATE FUNCTION airlinerra_game\.section9_owned_game_maintenance_flight_window_v1/);
 assert.match(sql,/section9_verified_world_instant_v1\(\)/);
 assert.match(sql,/p_arrival_utc>p_departure_utc\+interval '72 hours'/);
 assert.match(sql,/generate_series\(/);
 assert.match(sql,/section9_owned_game_maintenance_due_v1\(/);
 assert.match(sql,/j\.game_start_utc<p_arrival_utc/);
 assert.match(sql,/j\.game_end_utc>p_departure_utc/);
 assert.match(sql,/hourlyJobOverlapChecked',true/);
 assert.match(sql,/dispatchApproved',false/);
 assert.match(sql,/REVOKE ALL ON FUNCTION/);
 assert.match(api,/maintenanceFlightWindow:`SELECT airlinerra_game\.section9_owned_game_maintenance_flight_window_v1/);
 assert.match(api,/SCHEDULE_SQL\.maintenanceFlightWindow/);
 assert.match(api,/GAME_MAINTENANCE_HOUR_WINDOW_UNVERIFIED/);
 assert.match(api,/MAINTENANCE_FLIGHT_WINDOW_BLOCKED/);
 assert.match(api,/RECURRING_MAINTENANCE_WINDOW_CERTIFICATION_NOT_CONNECTED/);
});