/** Isolated Chromium -> real fleet client -> real authenticated fleet handler
 * -> real PostgreSQL storage overview. Identity verification and unrelated
 * fleet-list fields are CI fixtures; this is not a hosted login or write test.
 */
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,sep} from 'node:path';
import {chromium} from 'playwright';
import pg from 'pg';
import {createFleetAcquisitionHandler,FLEET_ACQUISITION_API_ROUTE} from '../../server/fleet-acquisition-service.mjs';

assert.equal(process.env.AIRLINERRA_STORAGE_DB_REVIEW,'1');
const db=new pg.Pool({host:'127.0.0.1',port:5432,user:'postgres',password:'review',database:'review',max:2});
const root=resolve('website');
const owner='00000000-0000-4000-8000-000000000002', foreign='00000000-0000-4000-8000-000000000004';
const airlineId='00000000-0000-4000-8000-000000000001',aircraftId='00000000-0000-4000-8000-000000000003';
const token='storage-ci-owner-token-00000000000000000000', otherToken='storage-ci-foreign-token-00000000000000000';
let browser,server;
try{
 const proof=await db.query("SELECT current_database() AS db, current_user AS usr");
 assert.deepEqual(proof.rows[0],{db:'review',usr:'postgres'});
 const result=await db.query("SELECT s.storage_started_utc::text AS now, i.fleet_status, i.ownership_type, s.airport_key FROM airlinerra_game.aircraft_storage_sessions_v1 s JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=s.aircraft_inventory_id WHERE s.aircraft_inventory_id=$1 AND s.storage_ended_utc IS NULL",[aircraftId]);
 assert.equal(result.rowCount,1);
 const fixture=result.rows[0];
 assert.equal(fixture.fleet_status,'stored');
 let reviewNow=fixture.now;
 const database={connect:async()=>{
  const connection=await db.connect();
  try{await connection.query("SELECT set_config('test.storage_hour',$1,false)",[reviewNow]);return connection;}
  catch(e){connection.release();throw e;}
 }};
 const handler=createFleetAcquisitionHandler({database,verifyUserToken:async t=>({user:t===token?{id:owner}:t===otherToken?{id:foreign}:null})});
 const snapshot=async()=> (await db.query("SELECT (SELECT cash_usd::text FROM airlinerra_game.airlines WHERE id=$1) AS cash,(SELECT count(*)::int FROM airlinerra_game.aircraft_storage_relocation_requests_v1) AS requests,(SELECT count(*)::int FROM airlinerra_game.airline_ledger) AS entries",[airlineId])).rows[0];
 const before=await snapshot();
 const calls=[];
 server=createServer(async(req,res)=>{
  try{
   const pathname=new URL(req.url,'http://localhost').pathname;
   if(pathname==='/fixture'){
    res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});
    res.end('<!doctype html><html><body><main id="player-main"><section id="workspace-fleet-aircraft"></section><section id="workspace-routes" hidden></section></main></body></html>');return;
   }
   if(pathname===FLEET_ACQUISITION_API_ROUTE){
    const chunks=[];for await(const chunk of req)chunks.push(chunk);
    const body=Buffer.concat(chunks);
    const action=JSON.parse(body.toString()).action;
    assert.ok(['storage-overview','storage-destinations','storage-cost-preview','storage-book-confirm','storage-book-cancel'].includes(action),'Only reviewed storage actions are routed');
    const reply=await handler(new Request('https://airlinerra.com'+pathname,{method:'POST',headers:{origin:'https://airlinerra.com','x-airlinerra-route':pathname,'content-type':'application/json',authorization:req.headers.authorization||''},body}));
    calls.push(reply.status);
    res.writeHead(reply.status,{'Content-Type':'application/json'});res.end(await reply.text());return;
   }
   const file=resolve(root,'.'+pathname);
   if(!file.startsWith(root+sep)){res.writeHead(403).end();return;}
   const bytes=await readFile(file);res.writeHead(200,{'Content-Type':file.endsWith('.mjs')||file.endsWith('.js')?'text/javascript':'application/octet-stream'});res.end(bytes);
  }catch{res.writeHead(500).end();}
 });
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const url='http://127.0.0.1:'+server.address().port;
 browser=await chromium.launch({headless:true,...(process.env.AIRLINERRA_CHROME_PATH?{executablePath:process.env.AIRLINERRA_CHROME_PATH}:{})});
 const page=await browser.newPage();
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',r=>r.request().url().startsWith(url+'/')?r.continue():r.abort());
 await page.goto(url+'/fixture#fleet-aircraft/'+aircraftId);
 await page.evaluate(async({airlineId,aircraftId,fixture,token,otherToken})=>{
  const {createAirlineWorkspace}=await import('/airline-workspace.mjs');
  const {createFleetAcquisitionClient,FLEET_ACQUISITION_API_ROUTE}=await import('/fleet-acquisition-client.mjs');
  let currentToken=token;
  // Explicit CI-only transport: never send a token to a public origin.
  const real=createFleetAcquisitionClient({origin:'https://airlinerra.com',auth:{getAccessToken:async()=>currentToken},fetchImpl:(target,options)=>{
   if(target!=='https://airlinerra.com'+FLEET_ACQUISITION_API_ROUTE)throw Error('Unexpected fleet target');
   return fetch(location.origin+FLEET_ACQUISITION_API_ROUTE,options);
  }});
  const client={storageOverview:real.storageOverview,storageDestinations:real.storageDestinations,storageCostPreview:real.storageCostPreview,confirmStorageBooking:real.confirmStorageBooking,cancelStorageBooking:real.cancelStorageBooking,crewCapacity:async()=>({airlineId,status:'fixture_unavailable'}),managementResponsibilities:async()=>({airlineId,status:'fixture_unavailable'}),list:async()=>({airlineId,offers:[],fleet:[{id:aircraftId,ownershipType:fixture.ownership_type,fleetStatus:fixture.fleet_status,manufacturer:'Airbus',model:'A319',registration:'CI-001',locationStatus:fixture.location_status||'grounded',locationAirportKey:fixture.airport_key}]})};
  const workspace=createAirlineWorkspace({doc:document,identity:'database-review',storage:sessionStorage,session:null,goTo:()=>{}});
  const refresh=()=>workspace.updateData({connected:true,airline:{id:airlineId,name:'CI airline',worldId:1},worlds:[],fleetClient:client});
  window.databaseReview={refreshFromDatabase:next=>{Object.assign(fixture,next);refresh()},deny:()=>{currentToken=otherToken;refresh()},restore:()=>{currentToken=token;refresh()}};
  refresh();
 },{airlineId,aircraftId,fixture,token,otherToken});
 const waitText=(id,text)=>page.waitForFunction(({id,text})=>document.getElementById(id)?.textContent.includes(text),{id,text});
 await waitText('fleet-storage-monthly','$8,000.00');
 await waitText('fleet-storage-state','Stored');
 await waitText('fleet-storage-airport','OURAIRPORTS:316427');
 assert.ok(calls.includes(200));
 await page.waitForFunction(()=>!document.getElementById('fleet-storage-plan').disabled);
 await page.locator('#fleet-storage-plan').click();
 await waitText('fleet-storage-planning-feedback','Enter at least two characters');
 await page.locator('#fleet-storage-search').fill('TEST');
 await page.locator('#fleet-storage-search-button').click();
 await page.locator('#fleet-storage-destination').locator('option[value="OURAIRPORTS:999"]').waitFor({state:'attached'});
 await page.locator('#fleet-storage-destination').selectOption('OURAIRPORTS:999');
 const quoteResponse=page.waitForResponse(async r=>r.url().endsWith(FLEET_ACQUISITION_API_ROUTE)&&r.request().postDataJSON()?.action==='storage-cost-preview');
 await page.locator('#fleet-storage-quote').click();
 const q=await (await quoteResponse).json();
 assert.equal(q.status,'storage_cost_preview_verified');
 assert.equal(Number(q.relocationUsd),2688.13);
 assert.equal(q.bookingEligible,false);
 assert.equal(q.dispatchAuthorized,false);
 await waitText('fleet-storage-quote-result','Relocation estimate');
 assert.equal(await page.locator('#fleet-storage-book').isDisabled(),true);
 await page.locator('#fleet-storage-close').click();
 await Promise.all([page.waitForResponse(r=>r.url().endsWith(FLEET_ACQUISITION_API_ROUTE)&&r.status()===403),page.evaluate(()=>window.databaseReview.deny())]);
 await waitText('fleet-storage-monthly','Not available');
 assert.ok(calls.includes(403),'Foreign owner must be rejected by real API');
 assert.equal(await page.locator('#fleet-storage-plan').isDisabled(),true);
 await page.evaluate(()=>window.databaseReview.restore());
 await waitText('fleet-storage-monthly','$8,000.00');
 assert.deepEqual(await snapshot(),before,'Read-only requests must not alter cash, ledger or requests');
 // Enable synthetic review switches only after the closed-gate read checks.
 await db.query("UPDATE airlinerra_game.storage_player_automatic_booking_release_v1 SET enabled=true; UPDATE airlinerra_game.storage_facility_admission_release_v1 SET enabled=true; UPDATE airlinerra_game.aircraft_storage_automatic_booking_release_v1 SET enabled=true; UPDATE airlinerra_game.storage_operational_departure_release_v1 SET enabled=true; UPDATE airlinerra_game.storage_crew_departure_validation_release_v1 SET enabled=true; UPDATE airlinerra_game.aircraft_storage_crew_booking_release_v1 SET enabled=true; UPDATE airlinerra_game.aircraft_storage_booking_release_v1 SET enabled=true; UPDATE airlinerra_game.aircraft_storage_execution_release_v1 SET execution_enabled=true,fuel_adapter_enabled=true; UPDATE airlinerra_game.aircraft_storage_signed_movement_release_v1 SET enabled=true; UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=true;");
 await page.waitForFunction(()=>!document.getElementById('fleet-storage-plan').disabled);
 await page.locator('#fleet-storage-plan').click();
 await waitText('fleet-storage-planning-feedback','Enter at least two characters');
 await page.locator('#fleet-storage-search').fill('TEST');
 await page.locator('#fleet-storage-search-button').click();
 await page.locator('#fleet-storage-destination').locator('option[value="OURAIRPORTS:999"]').waitFor({state:'attached'});
 await page.locator('#fleet-storage-destination').selectOption('OURAIRPORTS:999');
 const departure=new Date(Math.ceil((Date.parse(fixture.now)+3*3600000)/60000)*60000).toISOString().slice(0,16);
 await page.locator('#fleet-storage-departure').fill(departure);
 await page.locator('#fleet-storage-quote').click();
 await page.waitForFunction(()=>!document.getElementById('fleet-storage-book').disabled);
 const bookingResponse=page.waitForResponse(r=>r.url().endsWith(FLEET_ACQUISITION_API_ROUTE)&&r.request().postDataJSON()?.action==='storage-book-confirm');
 await page.locator('#fleet-storage-book').click();
 const booking=await (await bookingResponse).json();
 assert.equal(booking.booked,true,JSON.stringify(booking));
 assert.equal(booking.crewReserved,true);
 assert.equal(booking.slotsReserved,2);
 assert.equal(booking.dispatchAuthorized,false);
 await waitText('fleet-storage-state','Reactivation requested');
 const record=async()=> (await db.query("SELECT (SELECT status FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=$1) AS funds,(SELECT count(*)::int FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=$1) AS slots,(SELECT count(*)::int FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=$1 AND status='reserved') AS crew,(SELECT count(*)::int FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=$1) AS movements",[booking.requestId])).rows[0];
 assert.deepEqual(await record(),{funds:'held',slots:2,crew:2,movements:0});
 assert.equal(Math.round((Number(before.cash)-Number((await snapshot()).cash))*100),268813);
 page.once('dialog',d=>d.accept());
 const cancelResponse=page.waitForResponse(r=>r.url().endsWith(FLEET_ACQUISITION_API_ROUTE)&&r.request().postDataJSON()?.action==='storage-book-cancel');
 await page.locator('#fleet-storage-cancel').click();
 const cancelled=await (await cancelResponse).json();
 assert.equal(cancelled.cancelled,true,JSON.stringify(cancelled));
 await waitText('fleet-storage-state','Stored');
 assert.deepEqual(await record(),{funds:'refunded',slots:0,crew:0,movements:0});
 assert.equal(Number((await snapshot()).cash),Number(before.cash));
 console.log('PASS connected browser booking and cancellation: actual held funds, two slots, two crew reservations, full refund, no movements');
 // Book again through the actual player UI, then let the database worker
 // process the signed return flight. Do not insert movements from the browser.
 const tick=async at=>{
  reviewNow=at;
  const connection=await db.connect();
  try{
   await connection.query("SELECT set_config('test.storage_hour',$1,false)",[at]);
   return (await connection.query("SELECT airlinerra_game.run_storage_background_tick_v1(25) AS result")).rows[0].result;
  }finally{connection.release();}
 };
 const refreshFromDatabase=async()=>{
  const next=(await db.query("SELECT i.fleet_status,i.ownership_type,p.location_status,p.airport_key FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.section9_aircraft_current_position_v1 p ON p.aircraft_inventory_id=i.id WHERE i.id=$1",[aircraftId])).rows[0];
  await page.evaluate(next=>window.databaseReview.refreshFromDatabase(next),next);
 };
 await db.query("UPDATE airlinerra_game.storage_background_worker_release_v1 SET billing_enabled=true,movement_enabled=true WHERE world_id=1");
 const billing=await tick(reviewNow);
 assert.ok(billing.results.some(x=>x.phase==='billing'&&x.status==='paid'&&Number(x.amountUsd)===8000),JSON.stringify(billing));
 assert.equal(Math.round((Number(before.cash)-Number((await snapshot()).cash))*100),800000);
 await refreshFromDatabase();
 await waitText('fleet-storage-arrears','$0.00');
 await page.waitForFunction(()=>!document.getElementById('fleet-storage-plan').disabled);
 await page.locator('#fleet-storage-plan').click();
 await waitText('fleet-storage-planning-feedback','Enter at least two characters');
 await page.locator('#fleet-storage-search').fill('TEST');
 await page.locator('#fleet-storage-search-button').click();
 await page.locator('#fleet-storage-destination').locator('option[value="OURAIRPORTS:999"]').waitFor({state:'attached'});
 await page.locator('#fleet-storage-destination').selectOption('OURAIRPORTS:999');
 await page.locator('#fleet-storage-departure').fill(departure);
 await page.locator('#fleet-storage-quote').click();
 await page.waitForFunction(()=>!document.getElementById('fleet-storage-book').disabled);
 const nextResponse=page.waitForResponse(r=>r.url().endsWith(FLEET_ACQUISITION_API_ROUTE)&&r.request().postDataJSON()?.action==='storage-book-confirm');
 await page.locator('#fleet-storage-book').click();
 const next=await (await nextResponse).json();
 assert.equal(next.booked,true,JSON.stringify(next));
 assert.notEqual(next.requestId,booking.requestId);
 await waitText('fleet-storage-state','Reactivation requested');
 const flight=(await db.query("SELECT departure_utc::text AS dep,arrival_utc::text AS arr,storage_session_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=$1",[next.requestId])).rows[0];
 const early=await tick(new Date(Date.parse(flight.dep)-1000).toISOString());
 assert.ok(!early.results.some(x=>x.requestId===next.requestId&&x.movementRecorded===true));
 const departed=await tick(flight.dep);
 assert.ok(departed.results.some(x=>x.requestId===next.requestId&&x.phase==='departed'&&x.movementRecorded===true&&x.settlement.billingStopped===true),JSON.stringify(departed));
 await refreshFromDatabase();
 await waitText('fleet-storage-state','Relocation flight in progress');
 assert.equal(await page.locator('#fleet-storage-cancel').isDisabled(),true);
 const arrived=await tick(flight.arr);
 assert.ok(arrived.results.some(x=>x.requestId===next.requestId&&x.phase==='arrived'&&x.settlement?.status==='aircraft_reactivated'),JSON.stringify(arrived));
 await refreshFromDatabase();
 await waitText('fleet-storage-state','In service');
 await waitText('fleet-storage-history','OURAIRPORTS:316427');
 const end=(await db.query("SELECT (SELECT count(*)::int FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=$1) AS movements,(SELECT status FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=$1) AS funds,(SELECT count(*)::int FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 WHERE request_id=$2) AS payments,(SELECT storage_ended_utc= $3::timestamptz FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=$2) AS closed",( [next.requestId,flight.storage_session_id,flight.dep]))).rows[0];
 assert.deepEqual(end,{movements:2,funds:'settled',payments:1,closed:true});
 const after=await snapshot();
 assert.equal(Math.round((Number(before.cash)-Number(after.cash))*100),1068813);
 await tick(new Date(Date.parse(flight.arr)+60000).toISOString());
 assert.deepEqual(await snapshot(),after,'Worker replay must not change finances or requests');
 console.log('PASS connected browser reactivation: monthly billing, signed worker departure and arrival, storage closure, restored fleet status and exactly-once settlement (synthetic operational inputs)');
 assert.deepEqual(errors,[]);
 console.log('PASS Chromium -> actual fleet client -> authenticated storage handler -> PostgreSQL overview, return airport search and exact server quote; booking gate enforced, foreign owner denied, no financial mutations');
}finally{
 if(browser)await browser.close();
 if(server)await new Promise(r=>server.close(r));
 await db.end();
}
