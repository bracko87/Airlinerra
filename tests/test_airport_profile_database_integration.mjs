import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRPORT_PROFILE_SQL,AIRPORT_PROFILE_PATH,serializeAirportProfile,validAirportKey} from '../server/airport-profile-service.mjs';
import {createPlayerReadHandler,PLAYER_READ_PATHS} from '../server/player-read-service.mjs';
const source=path=>readFile(new URL(path,import.meta.url),'utf8');
const belgrade={
 airport_key:'OURAIRPORTS:4610',airport_name:'Belgrade Nikola Tesla Airport',
 airport_code:'LYBE',country_iso:'RS',roster_municipality:'Belgrade',
 game_municipality:'Belgrade',game_official_name:'Belgrade Nikola Tesla Airport',
 icao_reported:'LYBE',iata_reported:'BEG',region_iso:'RS-00',
 latitude_deg:'44.818401',longitude_deg:'20.309099',
 timezone_iana:null,timezone_candidate_iana:'Europe/Belgrade',
 provisional_category:'Major Hub',approved_category:null,
 game_elevation_ft:'335.0',game_elevation_provenance:'source_reported_unverified',
 official_name_verified:null,coordinates_verification:'source_unverified',
 terminal_count:null,passenger_gate_count:null,aircraft_stand_count:null,
 runways:[{name:'12R/30L',lengthM:3500,widthM:45.1,surface:'ASPH',
  operationalStatus:'unknown',verification:'historical_unverified'},
 {name:'12L/30R',lengthM:3400,widthM:45.1,surface:'ASP',
  operationalStatus:'unknown',verification:'historical_unverified'}]
};
test('profile query only returns approved World 1 airport data',()=>{
 assert.equal(AIRPORT_PROFILE_PATH,'/api/v1/player/airport-profile');
 assert.ok(PLAYER_READ_PATHS.includes(AIRPORT_PROFILE_PATH));
 assert.match(AIRPORT_PROFILE_SQL,/approved_game_airports a/);
 assert.match(AIRPORT_PROFILE_SQL,/WHERE a.world_id=1 AND a.airport_key=\$1::text/);
 assert.match(AIRPORT_PROFILE_SQL,/airport_reference_profiles/);
 assert.match(AIRPORT_PROFILE_SQL,/airport_runway_inventory/);
 assert.match(AIRPORT_PROFILE_SQL,/airport_facilities/);
 assert.equal(validAirportKey('OURAIRPORTS:4610'),true);
 assert.equal(validAirportKey('FICTIONAL:fictional:RS:LYAL'),true);
 for(const key of ['','OURAIRPORTS:0',"OURAIRPORTS:1' OR true",'bad','OURAIRPORTS: 4610']){
  assert.equal(validAirportKey(key),false);
 }
});
test('Belgrade reports real stored candidate fields without promoting to verified',()=>{
 const p=serializeAirportProfile(belgrade);
 assert.equal(p.icao,'LYBE');assert.equal(p.iata,'BEG');
 assert.equal(p.category,'Major Hub');assert.equal(p.categoryStatus,'provisional');
 assert.equal(p.timezone,'Europe/Belgrade');assert.equal(p.timezoneStatus,'candidate');
 assert.equal(p.latitude,44.818401);assert.equal(p.longitude,20.309099);
 assert.equal(p.elevationFt,335);assert.equal(p.nameChecked,false);
 assert.equal(p.runways.length,2);
 assert.equal(p.runways[0].operationalStatus,'unknown');
 assert.equal(p.facilities.terminals,null);
});
test('estimated fictional terrain is not disguised as verified aerodrome elevation',()=>{
 const p=serializeAirportProfile({...belgrade,airport_key:'FICTIONAL:fictional:RS:LYAL',
  airport_name:'Aleksandrovo Airport',game_elevation_ft:'230',
  game_elevation_provenance:'game_only_terrain_approximation',
  icao_reported:null,iata_reported:null,timezone_iana:'Europe/Belgrade',
  runways:null});
 assert.equal(p.elevationStatus,'game_only_terrain_approximation');
 assert.equal(p.iata,null);assert.equal(p.runways.length,0);
 assert.equal(p.timezoneStatus,'checked');
});
test('authenticated profile endpoint rejects invalid keys before database connection',async()=>{
 const calls=[];
 const database={connect:async()=>{calls.push('connect');return {query:async()=>({rows:[belgrade]}),release(){}}}};
 const verifyUserToken=async()=>({user:{id:'f49f495b-32e5-4f55-b8ca-6447e327ff78',email_confirmed_at:'2026-10-29T00:00:00Z'},error:null});
 const handler=createPlayerReadHandler({enabled:true,verifyUserToken,database,origin:'http://localhost:5188'});
 const request=(body,authorization='Bearer abcdef12345678901234')=>new Request('http://localhost:5188'+AIRPORT_PROFILE_PATH,{
  method:'POST',headers:{origin:'http://localhost:5188','content-type':'application/json',authorization},
  body:JSON.stringify(body)
 });
 assert.equal((await handler(await request({airportKey:'OURAIRPORTS:1 OR true'}))).status,400);
 assert.equal(calls.length,0);
 assert.equal((await handler(await request({airportKey:'OURAIRPORTS:4610'},'Bearer bad'))).status,401);
 assert.equal(calls.length,0);
 const response=await handler(await request({airportKey:'OURAIRPORTS:4610'}));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.airport.key,'OURAIRPORTS:4610');
 assert.equal(data.airport.runways.length,2);
 assert.equal(calls.length,1);
});
test('localhost and hosted bridges route profile reads to the isolated Edge function',async()=>{
 const [local,hosted,office,bridge,edge]=await Promise.all([
  source('../website/dev-scripts/real-player-read-gateway.mjs'),
  source('../server/production-game-api.mjs'),
  source('../website/airline-airports-office.mjs'),
  source('../website/player-read-client.mjs'),
  source('../server/airport-profile-edge-entry.ts')
 ]);
 assert.match(local,/airlinerra-airport-profile/);
 assert.match(hosted,/AIRPORT_PROFILE_EDGE_URL/);
 assert.match(office,/live.reader.airportProfile\(airport.key\)/);
 assert.match(office,/operational status unverified/);
 assert.match(bridge,/airportProfile:airportKey/);
 assert.match(edge,/createHostedAuthVerifier/);
 assert.match(edge,/validAirportKey\(body.airportKey\)/);
 assert.doesNotMatch(edge,/UPDATE |INSERT |DELETE |TRUNCATE /i);
});
