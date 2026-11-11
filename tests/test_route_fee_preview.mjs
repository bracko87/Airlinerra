import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validateFlightSchedulePayload,createFlightScheduleHandler,SCHEDULE_SQL}
 from '../server/flight-schedule-service.mjs';
import {checkedRouteFeeBaseline} from '../website/route-fee-preview.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {allowedLocalOwnerRead} from '../website/dev-scripts/real-player-read-gateway.mjs';
const U='11111111-1111-4111-8111-111111111111';
const A='22222222-2222-4222-8222-222222222222';
const P='33333333-3333-4333-8333-333333333333';
const draft={action:'fee-preview',airlineId:A,aircraftInventoryId:P,
 originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'OURAIRPORTS:4001',
 departureStand:'terminal',arrivalStand:'terminal',parkingMinutes:60};
const fees={
 departureAirportMovementUsd:486.02,arrivalLandingUsd:274.16,
 departureGroundHandlingUsd:1445.08,arrivalStandParkingUsd:0,
 departureTerminalAirTrafficControlUsd:333.6,enrouteAirTrafficControlUsd:43.41,
 departingPassengerFacilityUsd:0,departingPassengerSecurityUsd:0,
 internationalPassengerProcessingUsd:0,originCargoHandlingUsd:0,
 destinationCargoHandlingUsd:0
};
const sum=Object.values(fees).reduce((n,x)=>n+x,0);
const quote={status:'game_operating_fee_preview_only',worldId:1,currency:'USD',
 costBasis:'airlinerra_game_model_only',
 originAirportKey:draft.originAirportKey,destinationAirportKey:draft.destinationAirportKey,
 departureStand:'terminal',arrivalStand:'terminal',arrivalParkingMinutes:60,
 passengers:0,cargoTonnes:0,fees,totalGameOperatingFeesUsd:Math.round(sum*100)/100,
 isOfficialAviationTariff:false,canPostToLedger:false,cashPosted:false,
 operationAuthorized:false,fuelIncluded:false,modelVersion:'section8_game_v1'};
const result={status:'owner_verified_fixed_fee_baseline',readOnly:true,
 airlineId:A,aircraftInventoryId:P,passengersAssumed:0,cargoTonnesAssumed:0,
 canBookFlight:false,cashPosted:false,operationAuthorized:false,
 estimatedWholeFlightCost:false,airportFeeQuote:quote};
const request=body=>new Request('https://example.invalid/schedule',{
 method:'POST',headers:{origin:'https://airlinerra.com',
 'x-airlinerra-route':'/api/v1/player/flight-schedule-drafts',
 authorization:'Bearer '+('a'.repeat(48)),'content-type':'application/json'},
 body:JSON.stringify(body)});
const handler=query=>createFlightScheduleHandler({
 verifyUserToken:async()=>({user:{id:U}}),
 database:{connect:async()=>({query,release(){}})}
});
test('strict fee preview accepts only bounded fields and no browser price or user identity',()=>{
 assert.equal(validateFlightSchedulePayload(draft),true);
 assert.equal(allowedLocalOwnerRead('/api/v1/player/flight-schedule-drafts',draft),true);
 for(const bad of [
  {...draft,playerId:U},{...draft,passengers:100},
  {...draft,estimatedCostUsd:0},{...draft,parkingMinutes:-1},
  {...draft,parkingMinutes:10081},
  {...draft,aircraftInventoryId:'catalog:1'},
  {...draft,originAirportKey:draft.destinationAirportKey},
  {...draft,departureStand:'unverified'}
 ]){
  assert.equal(validateFlightSchedulePayload(bad),false);
  assert.equal(allowedLocalOwnerRead('/api/v1/player/flight-schedule-drafts',bad),false);
 }
});
test('fee preview checks server identity, active owned aircraft and strict nonposting flags',async()=>{
 let checks=[];
 const h=handler((sql,args)=>{
  checks.push({sql,args});
  if(sql===SCHEDULE_SQL.feeAircraft){
   assert.deepEqual(args,[U,A,P]);
   return {rowCount:1,rows:[{configurationId:16,useType:'passenger'}]};
  }
  if(sql===SCHEDULE_SQL.feePreview){
   assert.deepEqual(args,[
    draft.originAirportKey,draft.destinationAirportKey,16,
    'terminal','terminal',60
   ]);
   return {rowCount:1,rows:[{result:quote}]};
  }
  throw Error('Unknown SQL');
 });
 const response=await h(request(draft));
 assert.equal(response.status,200);
 const output=await response.json();
 assert.deepEqual(output,result);
 assert.deepEqual(checks.map(x=>x.sql),[SCHEDULE_SQL.feeAircraft,SCHEDULE_SQL.feePreview]);
 assert.equal(checkedRouteFeeBaseline(output,{airlineId:A,aircraftInventoryId:P})
  .fixedSubtotalUsd,2582.27);
});
test('cross-owner/unknown aircraft is denied before any fee quote',async()=>{
 const h=handler(sql=>{
  if(sql===SCHEDULE_SQL.feeAircraft)return {rowCount:0,rows:[]};
  throw Error('UNAUTHORIZED_BILLING_QUERY');
 });
 assert.equal((await h(request(draft))).status,403);
});
test('incompatible cargo stands and false safe-to-operate flags are refused',async()=>{
 const cargo=handler(sql=>{
  if(sql===SCHEDULE_SQL.feeAircraft)return {rowCount:1,
   rows:[{configurationId:16,useType:'cargo'}]};
  throw Error('Cargo must not be quoted with passenger stands');
 });
 assert.equal((await cargo(request(draft))).status,409);
 for(const wrong of [
  {...quote,cashPosted:true},
  {...quote,operationAuthorized:true},
  {...quote,canPostToLedger:true},
  {...quote,totalGameOperatingFeesUsd:1},
  {...quote,fees:{...fees,arrivalLandingUsd:-10}}
 ]){
  const h=handler(sql=>sql===SCHEDULE_SQL.feeAircraft?
   {rowCount:1,rows:[{configurationId:16,useType:'passenger'}]}:
   {rowCount:1,rows:[{result:wrong}]});
  assert.equal((await h(request(draft))).status,503);
  assert.equal(checkedRouteFeeBaseline({...result,airportFeeQuote:wrong},{
   airlineId:A,aircraftInventoryId:P}),null);
 }
});
test('browser flight client and route UI consume safe quote only, not a passenger forecast',async()=>{
 let posted=null;
 const client=createFlightScheduleClient({
  origin:'https://airlinerra.com',
  auth:{getAccessToken:async()=>('a'.repeat(48))},
  fetchImpl:async(url,opts)=>{posted=JSON.parse(opts.body);return Response.json(result);}
 });
 const data=await client.feePreview(draft);
 assert.equal(data.canBookFlight,false);
 assert.equal(posted.action,'fee-preview');
 assert.equal(posted.passengers,undefined);
 const ui=await readFile(new URL('../website/route-planner.mjs',import.meta.url),'utf8');
 assert.match(ui,/checkedRouteFeeBaseline/);
 assert.match(ui,/feePreview\(\{/);
 assert.match(ui,/feeBaseline\.fixedRows/);
 assert.match(ui,/NOT the complete flight cost/);
 assert.doesNotMatch(ui,/feePreview\(\{[^}]*passengerCount/);
});
