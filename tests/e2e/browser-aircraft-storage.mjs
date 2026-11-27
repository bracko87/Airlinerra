/** Chromium acceptance of the actual aircraft workspace with controlled
 * server responses. No hosted service, real player, or database mutation.
 * SQL lifecycle acceptance is separate; this is not a hosted end-to-end test.
 */
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,sep} from 'node:path';
import {chromium} from 'playwright';

const root=resolve('website');
const airlineId='00000000-0000-4000-8000-000000000001';
const aircraftId='00000000-0000-4000-8000-000000000003';
const originAirport='OURAIRPORTS:999', storageAirport='OURAIRPORTS:316427';
const server=createServer(async(req,res)=>{
 try{
  const pathname=new URL(req.url,'http://localhost').pathname;
  if(pathname==='/fixture'){
   res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});
   res.end('<!doctype html><html><body><main id="player-main"><section id="workspace-fleet-aircraft"></section></main></body></html>');return;
  }
  const file=resolve(root,'.'+pathname);
  if(!file.startsWith(root+sep)){res.writeHead(403).end();return;}
  const bytes=await readFile(file);
  res.writeHead(200,{'Content-Type':file.endsWith('.mjs')||file.endsWith('.js')?'text/javascript':file.endsWith('.svg')?'image/svg+xml':'application/octet-stream'});
  res.end(bytes);
 }catch{res.writeHead(404).end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
const url='http://127.0.0.1:'+server.address().port;
let browser;
try{
 browser=await chromium.launch({headless:true,...(process.env.AIRLINERRA_CHROME_PATH?{executablePath:process.env.AIRLINERRA_CHROME_PATH}:{})});
 const page=await browser.newPage();
 page.setDefaultTimeout(15000);
 const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 // The test must never contact a hosted API or real game.
 await page.route('**/*',route=>route.request().url().startsWith(url+'/')?route.continue():route.abort());
 await page.goto(url+'/fixture#fleet-aircraft/'+aircraftId);
 await page.evaluate(async({airlineId,aircraftId,originAirport,storageAirport})=>{
  const {createAirlineWorkspace}=await import('/airline-workspace.mjs');
  let fleetStatus='in_service',pending=null,session=null,history=[],bookings=[],quoteAllowed=true,wrongOwner=false;
  const date='2026-11-27T10:00:00Z';
  const aircraft=()=>({id:aircraftId,ownershipType:'owned',fleetStatus,manufacturer:'Airbus',model:'A319',registration:'TEST-001',locationStatus:'grounded',locationAirportKey:fleetStatus==='stored'?storageAirport:originAirport});
  const client={
   list:async()=>({airlineId,fleet:[aircraft()],offers:[]}),
   storageOverview:async()=>({status:'storage_overview_verified',readOnly:true,airlineId:wrongOwner?'other':airlineId,aircraftId,ownershipType:'owned',fleetStatus,session,pendingRequest:pending,history,cancellationEligible:!!pending&&!pending.departed}),
   storageDestinations:async args=>({status:'storage_destinations_verified',airlineId,aircraftId,purpose:args.purpose,readOnly:true,actionsReleased:false,originAirportKey:args.purpose==='storage_inbound'?originAirport:storageAirport,serverNowUtc:date,airports:[{airportKey:args.purpose==='storage_inbound'?storageAirport:originAirport,airportCode:args.purpose==='storage_inbound'?'TEV':'TEST',airportName:'Synthetic airport',scope:args.purpose==='storage_inbound'?'relocation_only':'existing_commercial'}]}),
   storageCostPreview:async args=>({status:'storage_cost_preview_verified',airlineId,aircraftId,purpose:args.purpose,destinationAirportKey:args.destinationAirportKey,departureUtc:args.departureUtc,readOnly:true,actionsReleased:false,bookable:false,bookingEligible:quoteAllowed,distanceKm:1200,durationMinutes:120,arrivalUtc:'2026-11-27T12:01:00Z',fuelUsd:1200,airportFeesUsd:1500,relocationUsd:2700,monthlyStorageUsd:8000,billingAtDeparture:{arrearsUsd:0}}),
   confirmStorageBooking:async args=>{
    bookings.push(args);
    pending={requestId:args.requestId,purpose:args.purpose,departed:false,originAirportKey:args.purpose==='storage_inbound'?originAirport:storageAirport,destinationAirportKey:args.destinationAirportKey,departureUtc:args.departureUtc};
    return {airlineId,aircraftId,booked:true};
   },
   cancelStorageBooking:async args=>{pending=null;return {airlineId,aircraftId,requestId:args.requestId,cancelled:true};}
  };
  const workspace=createAirlineWorkspace({doc:document,identity:'isolated-browser',storage:sessionStorage,session:null,goTo:()=>{}});
  const refresh=()=>workspace.updateData({connected:true,airline:{id:airlineId,name:'CI airline',worldId:1},worlds:[],fleetClient:client});
  window.storageTest={refresh,bookings:()=>bookings,denyQuote:()=>{quoteAllowed=false},allowQuote:()=>{quoteAllowed=true},wrongOwner:()=>{wrongOwner=true;refresh()},correctOwner:()=>{wrongOwner=false;refresh()},arriveStored:()=>{fleetStatus='stored';pending=null;session={airportKey:storageAirport,startedUtc:'2026-11-27T12:01:00Z',monthlyUsd:8000,billing:{arrearsUsd:0,nextDueGameDate:'2026-12-27'}};refresh()},arriveReturned:()=>{history=[{airportKey:storageAirport,startedUtc:session.startedUtc,endedUtc:'2026-11-28T12:00:00Z'}];fleetStatus='in_service';pending=null;session=null;refresh()}};
  refresh();
 },{airlineId,aircraftId,originAirport,storageAirport});
 const el=id=>page.locator('#'+id);
 const waitEnabled=async id=>page.waitForFunction(id=>!document.getElementById(id)?.disabled,id);
 const waitText=async(id,text)=>page.waitForFunction(({id,text})=>document.getElementById(id)?.textContent.includes(text),{id,text});
 async function openQuote(destination){
  await waitEnabled('fleet-storage-plan');
  await el('fleet-storage-plan').click();
  await el('fleet-storage-destination').locator('option[value="'+destination+'"]').waitFor({state:'attached'});
  await el('fleet-storage-destination').selectOption(destination);
  await waitEnabled('fleet-storage-quote');
  await el('fleet-storage-quote').click();
  await waitText('fleet-storage-quote-result','Relocation estimate');
 }
 await waitEnabled('fleet-storage-plan');
 assert.equal(await el('fleet-store-aircraft').isDisabled(),true);
 assert.equal(await el('fleet-reactivate-aircraft').isDisabled(),true);
 await page.evaluate(()=>window.storageTest.denyQuote());
 await openQuote(storageAirport);
 assert.equal(await el('fleet-storage-book').isDisabled(),true);
 await el('fleet-storage-close').click();
 await page.evaluate(()=>window.storageTest.allowQuote());
 await openQuote(storageAirport);
 await waitEnabled('fleet-storage-book');
 await el('fleet-storage-book').click();
 await waitText('fleet-storage-state','Storage relocation requested');
 assert.equal(await page.evaluate(()=>window.storageTest.bookings().length),1);
 assert.equal(await el('fleet-storage-plan').isDisabled(),true);
 await waitEnabled('fleet-storage-cancel');
 page.once('dialog',d=>d.accept());
 await el('fleet-storage-cancel').click();
 await waitText('fleet-storage-state','In service');
 await openQuote(storageAirport);
 await waitEnabled('fleet-storage-book');
 await el('fleet-storage-book').click();
 await waitText('fleet-storage-state','Storage relocation requested');
 await page.evaluate(()=>window.storageTest.arriveStored());
 await waitText('fleet-storage-monthly','$8,000.00');
 await waitText('fleet-storage-state','Stored');
 await openQuote(originAirport);
 await waitEnabled('fleet-storage-book');
 await el('fleet-storage-book').click();
 await waitText('fleet-storage-state','Reactivation requested');
 const requests=await page.evaluate(()=>window.storageTest.bookings());
 assert.deepEqual(requests.map(r=>r.purpose),['storage_inbound','storage_inbound','storage_reactivation']);
 assert.equal(new Set(requests.map(r=>r.requestId)).size,3);
 assert.ok(requests.every(r=>r.airlineId===airlineId&&r.aircraftInventoryId===aircraftId&&r.expectedCostUsd==='2700.00'));
 await page.evaluate(()=>window.storageTest.arriveReturned());
 await waitText('fleet-storage-state','In service');
 await waitText('fleet-storage-history',storageAirport);
 await page.evaluate(()=>window.storageTest.wrongOwner());
 await waitText('fleet-storage-release-note','not connected');
 assert.equal(await el('fleet-storage-plan').isDisabled(),true);
 assert.deepEqual(errors,[]);
 console.log('PASS real Chromium storage workspace: quote gating, booking, cancellation, stored fee, reactivation, history and owner mismatch (controlled server responses)');
}finally{
 if(browser)await browser.close();
 await new Promise(r=>server.close(r));
}
