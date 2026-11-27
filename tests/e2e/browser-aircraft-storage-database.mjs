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
 const database={connect:async()=>{
  const connection=await db.connect();
  try{await connection.query("SELECT set_config('test.storage_hour',$1,false)",[fixture.now]);return connection;}
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
    assert.equal(action,'storage-overview','Only the reviewed read action is routed');
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
  const client={storageOverview:real.storageOverview,crewCapacity:async()=>({airlineId,status:'fixture_unavailable'}),managementResponsibilities:async()=>({airlineId,status:'fixture_unavailable'}),list:async()=>({airlineId,offers:[],fleet:[{id:aircraftId,ownershipType:fixture.ownership_type,fleetStatus:fixture.fleet_status,manufacturer:'Airbus',model:'A319',registration:'CI-001',locationStatus:'grounded',locationAirportKey:fixture.airport_key}]})};
  const workspace=createAirlineWorkspace({doc:document,identity:'database-review',storage:sessionStorage,session:null,goTo:()=>{}});
  const refresh=()=>workspace.updateData({connected:true,airline:{id:airlineId,name:'CI airline',worldId:1},worlds:[],fleetClient:client});
  window.databaseReview={deny:()=>{currentToken=otherToken;refresh()},restore:()=>{currentToken=token;refresh()}};
  refresh();
 },{airlineId,aircraftId,fixture,token,otherToken});
 const waitText=(id,text)=>page.waitForFunction(({id,text})=>document.getElementById(id)?.textContent.includes(text),{id,text});
 await waitText('fleet-storage-monthly','$8,000.00');
 await waitText('fleet-storage-state','Stored');
 await waitText('fleet-storage-airport','OURAIRPORTS:316427');
 assert.ok(calls.includes(200));
 assert.equal(await page.locator('#fleet-storage-plan').isDisabled(),true);
 await Promise.all([page.waitForResponse(r=>r.url().endsWith(FLEET_ACQUISITION_API_ROUTE)&&r.status()===403),page.evaluate(()=>window.databaseReview.deny())]);
 await waitText('fleet-storage-monthly','Not available');
 assert.ok(calls.includes(403),'Foreign owner must be rejected by real API');
 await page.evaluate(()=>window.databaseReview.restore());
 await waitText('fleet-storage-monthly','$8,000.00');
 assert.deepEqual(await snapshot(),before,'Read-only requests must not alter cash, ledger or requests');
 assert.deepEqual(errors,[]);
 console.log('PASS Chromium -> actual fleet client -> authenticated storage handler -> PostgreSQL overview; foreign owner denied, no financial mutations');
}finally{
 if(browser)await browser.close();
 if(server)await new Promise(r=>server.close(r));
 await db.end();
}
