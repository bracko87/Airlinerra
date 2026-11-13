import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createFlightScheduleClient,FLIGHT_SCHEDULE_API_ROUTE}
 from '../website/flight-schedule-client.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const airlineId='00000000-0000-4000-8000-000000000001';
const aircraftInventoryId='00000000-0000-4000-8000-000000000002';
const token='fake-valid-test-token-1234567';

test('authenticated flight client sends commissioning status and request with owner scope',async()=>{
 const calls=[];
 const client=createFlightScheduleClient({
  auth:{getAccessToken:async()=>token},
  origin:'https://airlinerra.com',
  fetchImpl:async(url,options)=>{
   calls.push({url,options,body:JSON.parse(options.body)});
   return Response.json({status:'in_review',flightActivated:false,
    inspectionCompleted:false,physicalInspectionCompleted:false,
    aircraftClearedForFlight:false});
  }
 });
 await client.commissioningStatus({airlineId,aircraftInventoryId});
 await client.commissioningRequest({airlineId,aircraftInventoryId});
 assert.deepEqual(calls.map(c=>c.body.action),
  ['commissioning-status','commissioning-request']);
 for(const call of calls){
  assert.equal(call.url,'https://airlinerra.com'+FLIGHT_SCHEDULE_API_ROUTE);
  assert.equal(call.body.airlineId,airlineId);
  assert.equal(call.body.aircraftInventoryId,aircraftInventoryId);
  assert.equal(call.options.headers.authorization,'Bearer '+token);
  assert.equal(call.options.method,'POST');
  assert.equal(call.options.credentials,'omit');
 }
});

test('aircraft details renders game-data checks separately from physical condition',async()=>{
 const ui=await read('website/airline-workspace.mjs');
 assert.match(ui,/id="fleet-starter-commissioning"/);
 assert.match(ui,/id="fleet-commissioning-status"/);
 assert.match(ui,/id="fleet-commissioning-request"/);
 assert.match(ui,/async function loadCommissioningStatus\(aircraftId\)/);
 assert.match(ui,/scheduler\.commissioningStatus\(/);
 assert.match(ui,/scheduler\.commissioningRequest|data\.scheduler\.commissioningRequest/);
 assert.match(ui,/data\.airline\?\.id!==airlineId/);
 assert.match(ui,/selectedFleetAircraftId!==aircraftId/);
 assert.match(ui,/Game records checked:/);
 assert.match(ui,/Awaiting independent condition and age review/);
 assert.match(ui,/Aircraft is not yet cleared to fly/);
 assert.match(ui,/button\.hidden=!\['not_requested','requested'\]/);
 assert.match(ui,/panel\.hidden=true;button\.hidden=true/);
 assert.match(ui,/typeof data\.scheduler\?\.commissioningRequest!=='function'/);
 assert.match(ui,/result\.aircraftClearedForFlight!==false/);
 assert.match(ui,/void loadCommissioningStatus\(selectedFleetAircraftId\)/);
 assert.match(ui,/void loadCommissioningStatus\(aircraftId\)/);
});
