import test from 'node:test';import assert from 'node:assert/strict';
import {PLAYER_READ_SQL,createPlayerReadHandler} from '../server/player-read-service.mjs';
import {createPlayerReadClient,PLAYER_READ_API_ENABLED} from '../website/player-read-client.mjs';
const UUID='550e8400-e29b-41d4-a716-446655440000';
const ORIGIN='https://airlinerra.com';
const TOKEN='a'.repeat(32);
const baseRows={
 worlds:[{id:1,name:'World 01',state:'planned'},{id:2,name:'World 02',state:'planned'},{id:3,name:'World 03',state:'planned'}],
 countries:[{country_iso:'DE',airport_count:2},{country_iso:'FR',airport_count:1}],
 airlines:[],
 ledger:[{entry_kind:'STARTING_CAPITAL',amount_usd:'5000000.00',recorded_at:'2026-10-29T08:12:26.559Z'}],
 airports:[{airport_key:'OURAIRPORTS:111',airport_name:'Berlin Airport',airport_code:'EDDB',country_iso:'DE',municipality:'Berlin'}],
 licenses:[{permission_code:'EU_AIRLINE_OPERATING_LICENCE',category:'airline',holder_scope:'operating_company',
   reference_basis:'eu_reference',title:'Airline operating licence',
   purpose:'Commercial air services within approved scope',
   requirements:'National authority and AOC checks',application_guidance:'Apply to competent regulator',
   source_url:'https://eur-lex.europa.eu/eli/reg/2008/1008/oj/eng',
   research_status:'reference_only',game_fee_usd:null,processing_game_days:null,enabled_in_game:false}],
 holdingStatus:[{
   airline_id:UUID,world_id:1,world_state:'planned',minimum_registration_age_days:60,
   registered_at_utc:'2026-10-29T08:12:26Z',
   eligible_at_utc:'2026-12-28T08:12:26Z',eligible_utc_date:'2026-12-28',
   completed_registration_days:11,remaining_registration_days:49,
   minimum_age_met:false,holding_registration_open:false,
   eligibility_status:'waiting_for_60_registration_days'
 }]
};
function make({enabled=true,verified=true,rows=baseRows}={}){
 const queries=[];let connected=0,released=0,verifiedCalls=0;
 const db={connect:async()=>{connected++;return {
   query:async(sql,params)=>{queries.push({sql,params});if(sql===PLAYER_READ_SQL.worlds)return {rows:rows.worlds};
     if(sql===PLAYER_READ_SQL.countries)return {rows:rows.countries};
     if(sql===PLAYER_READ_SQL.airlines)return {rows:rows.airlines};
     if(sql===PLAYER_READ_SQL.ledger)return {rows:rows.ledger};
     if(sql===PLAYER_READ_SQL.airports)return {rows:rows.airports};
     if(sql===PLAYER_READ_SQL.licenses)return {rows:rows.licenses};
     if(sql===PLAYER_READ_SQL.holdingStatus)return {rows:rows.holdingStatus};
     throw Error('Unexpected query');},
   release:()=>{released++;}
 };}};
 const verifyUserToken=async()=>{verifiedCalls++;return verified?
   {user:{id:UUID,email_confirmed_at:'2026-10-28T10:00:00Z'}}:{user:null,error:'invalid'};};
 return {handler:createPlayerReadHandler({enabled,verifyUserToken,database:db}),counts:()=>({connected,released,verifiedCalls,queries})};
}
const request=(path,body={},headers={})=>new Request(ORIGIN+path,{
 method:'POST',headers:{origin:ORIGIN,authorization:'Bearer '+TOKEN,'content-type':'application/json',...headers},body:JSON.stringify(body)
});
test('read-only service is closed by default, before Auth or database',async()=>{
 const s=make({enabled:false});
 const response=await s.handler(request('/api/v1/player/overview'));
 assert.equal(response.status,503);assert.deepEqual(s.counts(),{connected:0,released:0,verifiedCalls:0,queries:[]});
});
test('verified managers receive real world, airport count and only owned airline query',async()=>{
 const s=make();
 const response=await s.handler(request('/api/v1/player/overview'));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.deepEqual(data.worlds.map(w=>w.state),['planned','planned','planned']);
 assert.equal(data.airportsTotal,3);assert.deepEqual(data.airlines,[]);
 assert.equal(data.gameplayAvailable,false);
 assert.deepEqual(s.counts().queries[2].params,[UUID]);
 assert.equal(s.counts().released,1);
});
test('licence reference catalogue is authenticated, read-only, and grants no market or operating rights',async()=>{
 const s=make();
 const response=await s.handler(request('/api/v1/player/licenses'));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.referenceOnly,true);
 assert.equal(data.applicationsAvailable,false);
 assert.equal(data.companyApprovalsAvailable,false);
 assert.equal(data.trafficRightsVerified,false);
 assert.equal(data.licenses.length,1);
 assert.equal(data.licenses[0].code,'EU_AIRLINE_OPERATING_LICENCE');
 assert.equal(data.licenses[0].enabledInGame,false);
 assert.equal(data.licenses[0].gameFeeUsd,null);
 assert.equal(s.counts().queries[0].sql,PLAYER_READ_SQL.licenses);
 assert.equal(s.counts().released,1);
 const invalid=make();
 assert.equal((await invalid.handler(request('/api/v1/player/licenses',{worldId:1}))).status,400);
 assert.equal(invalid.counts().connected,0);
 assert.equal((await make({verified:false}).handler(request('/api/v1/player/licenses'))).status,401);
 const tampered=make({rows:{...baseRows,licenses:[{...baseRows.licenses[0],enabled_in_game:true}]}});
 assert.equal((await tampered.handler(request('/api/v1/player/licenses'))).status,503);
});
test('holding registration age comes from the authenticated airline record, not flights or player input',async()=>{
 const s=make();
 const resp=await s.handler(request('/api/v1/player/holding-status'));
 assert.equal(resp.status,200);
 const data=await resp.json();
 assert.equal(data.ageBasis,'elapsed_calendar_days_since_airline_registration');
 assert.equal(data.holdingFormationAvailable,false);
 assert.equal(data.subsidiaryCreationAvailable,false);
 assert.equal(data.treasuryTransfersAvailable,false);
 assert.equal(data.worlds.length,1);
 const row=data.worlds[0];
 assert.equal(row.reason,'waiting_for_60_registration_days');
 assert.equal(row.completedDays,11);
 assert.equal(row.remainingDays,49);
 assert.equal(row.earliestDate,'2026-12-28');
 assert.equal(row.registeredAtUtc,'2026-10-29T08:12:26Z');
 assert.equal(row.registrationOpen,false);
 assert.deepEqual(s.counts().queries[0].params,[UUID]);
 assert.match(PLAYER_READ_SQL.holdingStatus,/holding_registration_eligibility_v2/);
 assert.match(PLAYER_READ_SQL.holdingStatus,/owner_player_id=\$1::uuid/);
 assert.doesNotMatch(PLAYER_READ_SQL.holdingStatus,/first_operating_game_date|current_verified_game_date/);
 const forged=make();
 assert.equal((await forged.handler(request('/api/v1/player/holding-status',{airlineId:UUID}))).status,400);
 assert.equal(forged.counts().connected,0);
 const tampered=make({rows:{...baseRows,holdingStatus:[{
  ...baseRows.holdingStatus[0],holding_registration_open:true
 }]}});
 assert.equal((await tampered.handler(request('/api/v1/player/holding-status'))).status,503);
 const invalidDate=make({rows:{...baseRows,holdingStatus:[{
  ...baseRows.holdingStatus[0],eligible_utc_date:'2026-12-27'
 }]}});
 assert.equal((await invalidDate.handler(request('/api/v1/player/holding-status'))).status,503);
 assert.equal((await make({verified:false}).handler(request('/api/v1/player/holding-status'))).status,401);
});

test('search is country-scoped, parameterized, bounded and never writes to database',async()=>{
 const s=make();
 const response=await s.handler(request('/api/v1/player/airports',{countryIso:'DE',search:'Berlin',offset:0}));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.airports[0].name,'Berlin Airport');
 assert.equal(s.counts().queries[0].params[1],'Berlin');
 for(const sql of Object.values(PLAYER_READ_SQL)){
   assert.match(sql,/^select /i);
   assert.doesNotMatch(sql,/\b(insert|update|delete|create|grant|alter)\b/i);
 }
});
test('denies missing Auth, external origin, invalid inputs and never connects first',async()=>{
 const bad=make({verified:false});
 assert.equal((await bad.handler(request('/api/v1/player/overview'))).status,401);
 assert.equal(bad.counts().connected,0);
 const s=make();
 assert.equal((await s.handler(request('/api/v1/player/overview',{}, {origin:'https://evil.example'}))).status,403);
 for(const args of [
   {countryIso:'D'},{countryIso:'DE',offset:100000},
   {countryIso:'DE',search:'%_%'},{countryIso:'DE',playerId:UUID}
 ]){
  assert.equal((await s.handler(request('/api/v1/player/airports',args))).status,400);
 }
 assert.equal(s.counts().connected,0);
});
test('client forwards bounded read requests with verified session only',async()=>{
 assert.equal(PLAYER_READ_API_ENABLED,false);
 let calls=[];
 const auth={getAccessToken:async()=>TOKEN};
 const client=createPlayerReadClient({auth,origin:ORIGIN,enabled:true,fetchImpl:async(url,options)=>{
   calls.push([url,options]);return new Response(JSON.stringify({worlds:[]}),{
    status:200,headers:{'content-type':'application/json'}
   });
 }});
 assert.deepEqual(await client.overview(),{worlds:[]});
 assert.equal(calls[0][0],ORIGIN+'/api/v1/player/overview');
 assert.equal(calls[0][1].headers.authorization,'Bearer '+TOKEN);
 assert.equal(calls[0][1].credentials,'omit');
 await assert.rejects(createPlayerReadClient({auth,origin:ORIGIN}).overview(),/not deployed/);
 assert.equal(calls.length,1);
});

test('request bodies exceeding 512 bytes are rejected without database contact',async()=>{
 const s=make();
 const extra='z'.repeat(800);
 const response=await s.handler(request('/api/v1/player/overview',{extra}));
 assert.equal(response.status,400);
 assert.equal(s.counts().connected,0);
});

test('owner-approved, verified premium is calculated server-side from private entitlement and verified account email',()=>{
 assert.match(PLAYER_READ_SQL.airlines,/account_entitlements/);
 assert.match(PLAYER_READ_SQL.airlines,/owner_premium_email_reservations/);
 assert.match(PLAYER_READ_SQL.airlines,/email_confirmed_at is not null/);
 assert.match(PLAYER_READ_SQL.airlines,/owner_player_id=\$1::uuid/);
});

test('owner-registered airline returns the approved home airport name and code',async()=>{
 const rows={...baseRows,airlines:[{
  id:UUID,world_id:1,name:'Test airline',home_airport_key:'OURAIRPORTS:4610',
  home_airport_name:'Belgrade Nikola Tesla Airport',home_airport_code:'LYBE',
  cash_usd:'5000000.00',complimentary_premium:true
 }]};
 const response=await make({rows}).handler(request('/api/v1/player/overview'));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.airlines[0].homeAirportName,'Belgrade Nikola Tesla Airport');
 assert.equal(data.airlines[0].homeAirportCode,'LYBE');
 assert.equal(data.airlines[0].premiumUnlimited,true);
 assert.equal(data.airlines[0].cashUsd,'5000000.00');
 assert.deepEqual(data.ledgerEntries,[{kind:'STARTING_CAPITAL',amountUsd:'5000000.00',recordedAt:'2026-10-29T08:12:26.559Z'}]);
});
test('approved fictional game airport is not dropped from Serbia airport search',async()=>{
 const rows={...baseRows,airports:[{
  airport_key:'FICTIONAL:fictional:RS:LYAL',
  airport_name:'Aleksandrovo Airport',airport_code:'LYAL',
  country_iso:'RS',municipality:'Nova Crnja'
 }]};
 const response=await make({rows}).handler(request('/api/v1/player/airports',{countryIso:'RS'}));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.airports[0].code,'LYAL');
 assert.equal(data.airports[0].name,'Aleksandrovo Airport');
});


test('authenticated airport search allows a country-free city query but rejects short or unbounded global searches',async()=>{
 const rows={...baseRows,airports:[
  {airport_key:'OURAIRPORTS:2155',airport_name:'Brussels Airport',airport_code:'EBBR',
   country_iso:'BE',municipality:'Zaventem',latitude_deg:'50.901402',longitude_deg:'4.48444'},
  {airport_key:'OURAIRPORTS:4610',airport_name:'Belgrade Nikola Tesla Airport',airport_code:'LYBE',
   country_iso:'RS',municipality:'Belgrade',latitude_deg:'44.818401',longitude_deg:'20.309099'}
 ]};
 const a=make({rows});
 const response=await a.handler(request('/api/v1/player/airports',
  {countryIso:'',search:'brus',offset:0}));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.countryIso,'');
 assert.equal(data.airports.length,2);
 assert.deepEqual(data.airports.map(x=>x.countryIso),['BE','RS']);
 assert.equal(data.airports[0].latitude,50.901402);
 assert.deepEqual(a.counts().queries[0].params,['','brus',0]);
 assert.match(PLAYER_READ_SQL.airports,/\(\$1::text='' or /);
 const bad=make();
 for(const search of ['','b','%%','a'.repeat(41)]){
  const resp=await bad.handler(request('/api/v1/player/airports',{countryIso:'',search}));
  assert.equal(resp.status,400,'Invalid global search '+search);
 }
 assert.equal(bad.counts().connected,0);
});


test('owner-only aircraft test fixtures are returned as explicitly nonoperational Panonian previews',async()=>{
 const record={id:'ddf97a11-9f22-40d4-aa75-02f3e61cb312',
   model:'A319-100',registration:'TEST-PA-A319-01',
   configurationId:16,testOnly:true,operationallyAllowed:false};
 const rows={...baseRows,airlines:[{
  id:UUID,world_id:1,name:'Panonian',home_airport_key:'OURAIRPORTS:4610',
  cash_usd:'5000000.00',test_aircraft:[
   record,{...record,id:'bad-id',testOnly:false},
   {...record,id:'bad-id-2',operationallyAllowed:true}
  ]
 }]};
 const response=await make({rows}).handler(request('/api/v1/player/overview'));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.airlines[0].testAircraft.length,1);
 assert.deepEqual(data.airlines[0].testAircraft[0],record);
 assert.match(PLAYER_READ_SQL.airlines,/airline_aircraft_test_fixtures/);
 assert.match(PLAYER_READ_SQL.airlines,/t\.airline_id=a\.id/);
 assert.match(PLAYER_READ_SQL.airlines,/a\.owner_player_id=\$1::uuid/);
 assert.match(PLAYER_READ_SQL.airlines,/t\.operationally_allowed=false/);
});
