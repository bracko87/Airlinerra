import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createFlightScheduleHandler,validateFlightSchedulePayload,SCHEDULE_SQL
} from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {validateRouteFinancialDashboard}
 from '../website/section9-route-finance-panel.mjs';

const ORIGIN='https://airlinerra.com';
const ROUTE='/api/v1/player/flight-schedule-drafts';
const PLAYER='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='33333333-3333-4333-8333-333333333333';
const TOKEN='test-only-session-token-verified-by-stub';
const fields={
 departureAirportMovementUsd:957.14,
 arrivalLandingUsd:1759.77,
 departureGroundHandlingUsd:2877.96,
 arrivalStandParkingUsd:105.06,
 departureTerminalAirTrafficControlUsd:509.80,
 enrouteAirTrafficControlUsd:1103.02,
 departingPassengerFacilityUsd:4728.00,
 departingPassengerSecurityUsd:1083.50,
 internationalPassengerProcessingUsd:1182.00,
 originCargoHandlingUsd:0,
 destinationCargoHandlingUsd:0
};
const quote={status:'game_operating_fee_preview_only',
 canPostToLedger:false,cashPosted:false,fuelIncluded:false,
 aircraftModel:'737-8200',greatCircleDistanceKm:1363.56,fees:fields};
const amount=Object.values(fields).reduce((a,b)=>a+b,0);
const route={serverScheduleId:SCHEDULE};
function view({completed=0,older=0,flightOverride=null}={}){
 const flights=Array.from({length:Math.min(7,completed)},(_,index)=>({
  physicalFlightId:SCHEDULE+':2000-01-'+String(10-index).padStart(2,'0')+':1',
  gameDate:'2000-01-'+String(10-index).padStart(2,'0'),
  passengers:197,cargoTonnes:0,
  ticketIncomeUsd:29550,cargoIncomeUsd:0,otherIncomeUsd:0,
  revenueUsd:29550,fees:fields,
  airportNavigationCostsUsd:14306.25,
  fuelCostsUsd:4000,crewCostsUsd:1500,maintenanceCostsUsd:750,
  ownershipCostsUsd:1000,otherCostsUsd:0,
  totalCostsUsd:21556.25,profitLossUsd:7993.75,
  tariffVersion:'section8_airline_operating_fees_game_v1_20261109',
  source:'verified_arrival_and_posted_ledger',
  ...flightOverride
 }));
 return {
  status:'route_financial_dashboard_read_only',
  worldId:1,airlineId:AIRLINE,scheduleId:SCHEDULE,
  readOnly:true,cashPosted:false,bookingsCreated:false,flightActivated:false,
  aircraftConfigurationId:2,
  estimate:{
   status:'draft_not_earned',loadPercent:100,
   passengers:197,cargoTonnes:0,
   plannedEconomyFareUsd:150,plannedCargoRatePerTonneUsd:0,
   ticketIncomeIfSoldUsd:29550,cargoIncomeIfSoldUsd:0,
   potentialRevenueUsd:29550,
   knownAirportNavigationCostsUsd:14306.25,
   partialMarginBeforeOtherCostsUsd:15243.75,
   actualNetProfitKnown:false,
   airportFeeQuote:quote,
   notIncludedCosts:['fuel','crew','maintenance','aircraft_ownership_or_leasing']
  },
  history:{
   source:'verified_arrival_and_posted_airline_ledger_only',
   completedFlightCount:completed,olderFlightCount:older,
   totalRevenueUsd:completed*29550,
   totalCostsUsd:completed*21556.25,
   totalProfitLossUsd:completed*7993.75,
   olderRevenueUsd:older*29550,
   olderCostsUsd:older*21556.25,
   olderProfitLossUsd:older*7993.75,
   olderFlightsDisplay:'aggregate_only',
   lastSevenFlights:flights
  }
 };
}
const req=(body,{url=ORIGIN+ROUTE,token=TOKEN}={})=>new Request(url,{
 method:'POST',headers:{
  'content-type':'application/json',
  'x-airlinerra-route':ROUTE,'origin':ORIGIN,
  authorization:'Bearer '+token
 },body:JSON.stringify(body)
});
test('route finance API accepts only owned schedule identifiers and bounded assumptions',()=>{
 const valid={action:'route-financials',airlineId:AIRLINE,
  scheduleId:SCHEDULE,loadPercent:100,parkingMinutes:180};
 assert.equal(validateFlightSchedulePayload(valid),true);
 for(const payload of [
  {...valid,action:'route-profit-save'},
  {...valid,loadPercent:-1},
  {...valid,loadPercent:101},
  {...valid,parkingMinutes:-1},
  {...valid,parkingMinutes:10081},
  {...valid,loadPercent:'100'},
  {...valid,parkingMinutes:'180'},
  {...valid,ownerPlayerId:PLAYER},
  {...valid,flightRevenueUsd:1e9},
  {...valid,actualCostsUsd:0}
 ]){
  assert.equal(validateFlightSchedulePayload(payload),false);
 }
});
test('server sends trusted owner identity and schedule ID only to private finance SQL',async()=>{
 const calls=[];let releases=0;
 const db={async connect(){return {
  async query(sql,args){calls.push({sql,args});return{
   rowCount:1,rows:[{result:view()}]
  };},release(){releases++}
 }}};
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:{id:PLAYER},error:null}),database:db
 });
 const r=await handler(req({action:'route-financials',
  airlineId:AIRLINE,scheduleId:SCHEDULE,loadPercent:100,parkingMinutes:180}));
 assert.equal(r.status,200);
 const body=await r.json();
 assert.equal(body.status,'route_financial_dashboard_read_only');
 assert.deepEqual(calls,[{
  sql:SCHEDULE_SQL.routeFinancials,
  args:[PLAYER,AIRLINE,SCHEDULE,100,180]
 }]);
 assert.equal(releases,1);
});
test('invalid authentication and forbidden inputs never access the database',async()=>{
 let opens=0;
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:null,error:'no'}),database:{
   async connect(){opens++;throw Error('should not reach private DB')}
  }
 });
 const v={action:'route-financials',airlineId:AIRLINE,
  scheduleId:SCHEDULE,loadPercent:100,parkingMinutes:180};
 assert.equal((await handler(req(v))).status,401);
 assert.equal((await handler(req({...v,loadPercent:101}))).status,400);
 assert.equal((await handler(req({...v,action:'route-profit-post'}))).status,400);
 assert.equal(opens,0);
});
test('server refuses fake profit, missing history or unsafe cost responses',async()=>{
 for(const mutated of [
  {...view(),cashPosted:true},
  {...view(),flightActivated:true},
  {...view(),history:{...view().history,lastSevenFlights:null}},
  {...view(),estimate:{...view().estimate,
   airportFeeQuote:{...quote,canPostToLedger:true}}}
 ]){
  const handler=createFlightScheduleHandler({
   verifyUserToken:async()=>({user:{id:PLAYER},error:null}),
   database:{async connect(){return{
    async query(){return{rowCount:1,rows:[{result:mutated}]}},
    release(){}
   }}}
  });
  const r=await handler(req({action:'route-financials',airlineId:AIRLINE,
   scheduleId:SCHEDULE,loadPercent:100,parkingMinutes:180}));
  assert.equal(r.status,503);
 }
});
test('browser client requests only a protected read; no charge or save action',async()=>{
 let request;
 const client=createFlightScheduleClient({
  origin:ORIGIN,auth:{getAccessToken:async()=>TOKEN},
  fetchImpl:async(url,init)=>{
   request={url,init};return Response.json(view());
  }
 });
 const res=await client.routeFinancials({
  airlineId:AIRLINE,scheduleId:SCHEDULE,
  loadPercent:75,parkingMinutes:360
 });
 assert.equal(res.readOnly,true);
 assert.equal(request.url,ORIGIN+ROUTE);
 assert.deepEqual(JSON.parse(request.init.body),{
  action:'route-financials',airlineId:AIRLINE,
  scheduleId:SCHEDULE,loadPercent:75,parkingMinutes:360
 });
 assert.match(request.init.headers.authorization,/^Bearer /);
 assert.equal(request.init.credentials,'omit');
});
test('front-end refuses fabricated costs, unposted flights and wrong owner',()=>{
 assert.equal(Math.abs(amount-14306.25)<0.001,true);
 assert.equal(validateRouteFinancialDashboard(view(),route,AIRLINE).history.completedFlightCount,0);
 assert.equal(validateRouteFinancialDashboard(view({completed:8,older:1}),
  route,AIRLINE).history.lastSevenFlights.length,7);
 for(const invalid of [
  {...view(),scheduleId:'44444444-4444-4444-8444-444444444444'},
  {...view(),airlineId:'44444444-4444-4444-8444-444444444444'},
  {...view(),history:{...view().history,completedFlightCount:1}},
  {...view(),estimate:{...view().estimate,actualNetProfitKnown:true}},
  {...view(),estimate:{...view().estimate,airportFeeQuote:{
   ...quote,fees:{...fields,arrivalLandingUsd:0}
  }}},
  {...view({completed:1}),history:{
   ...view({completed:1}).history,
   lastSevenFlights:view({completed:1}).history.lastSevenFlights.map(x=>({
    ...x,profitLossUsd:100000
   }))
  }}
 ]){
  assert.throws(()=>validateRouteFinancialDashboard(invalid,route,AIRLINE),
   /Unverified|Incomplete|did not reconcile/);
 }
});
test('route financial UI mounted beside commercial plan and refreshed on fare save',async()=>{
 const files=await Promise.all([
  readFile(new URL('../website/section9-route-details.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/section9-commercial-plan-editor.mjs',import.meta.url),'utf8'),
  readFile(new URL('../supabase/migrations/20261109224500_section9_owned_route_financial_dashboard.sql',import.meta.url),'utf8')
 ]);
 assert.match(files[0],/createSection9RouteFinancePanel/);
 assert.match(files[0],/financePanel\.open/);
 assert.match(files[0],/onSaved:\(\)=>financePanel\.refresh/);
 assert.match(files[1],/if\(typeof onSaved==='function'\)/);
 assert.match(files[2],/row_number\(\) OVER/);
 assert.match(files[2],/FILTER\(WHERE sequence<=7\)/);
 assert.match(files[2],/FILTER\(WHERE sequence>7\)/);
 assert.match(files[2],/revenue\.entry_kind='REVENUE'/);
 assert.match(files[2],/m\.phase='arrived'/);
 assert.match(files[2],/ownerAcceptedGameFeeRates/);
 assert.doesNotMatch(files[2],/UPDATE airlinerra_game\.airline_ledger|UPDATE airlinerra_game\.airlines/);
});
