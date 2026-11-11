import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRPORT_PROFILE_SQL,GROUP2_AIRPORT_PROFILE_SQL,AIRPORT_PROFILE_PATH,serializeAirportProfile,validAirportKey,passengerTrafficGroup,cargoTrafficGroup} from '../server/airport-profile-service.mjs';
import {createPlayerReadHandler,PLAYER_READ_PATHS} from '../server/player-read-service.mjs';
import {routeLongestRunwayLabel} from '../website/route-planner.mjs';
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
 assert.match(office,/Airport operational status/);
 assert.match(office,/Not independently confirmed/);
 assert.match(bridge,/airportProfile:airportKey/);
 assert.match(edge,/createHostedAuthVerifier/);
 assert.match(edge,/validAirportKey\(body.airportKey\)/);
 assert.doesNotMatch(edge,/UPDATE |INSERT |DELETE |TRUNCATE /i);
});

test('airport-wide metrics show sourced HQ and active offices without inventing flights',()=>{
 assert.match(AIRPORT_PROFILE_SQL,/registered_airline_headquarters_count/);
 assert.match(AIRPORT_PROFILE_SQL,/active_airline_hubs_count/);
 assert.match(AIRPORT_PROFILE_SQL,/active_airline_stations_count/);
 const profile=serializeAirportProfile({...belgrade,
  registered_airline_headquarters_count:1,
  active_airline_hubs_count:0,active_airline_stations_count:0});
 assert.deepEqual(profile.airportActivity,{
  registeredHeadquarters:1,activeHubs:0,activeStations:0,
  dailyFlights:null,operatingAirlines:null
 });
});

test('five bands depend on daily traffic rather than percent rank or airport maximum',()=>{
 assert.deepEqual([0,999,1000,9999,10000,24999,25000,74999,75000].map(passengerTrafficGroup),
  [1,1,2,2,3,3,4,4,5]);
 assert.deepEqual([0,0.99,1,9.99,10,99.99,100,999.99,1000].map(cargoTrafficGroup),
  [1,1,2,2,3,3,4,4,5]);
 assert.equal(passengerTrafficGroup(null),null);
 assert.equal(cargoTrafficGroup(null),null);
 const p=serializeAirportProfile({...belgrade,
  daily_outbound_passengers:12205,daily_outbound_cargo_tonnes:'22.50',
  passenger_demand_percentile:92,cargo_demand_percentile:88});
 assert.equal(p.demand.passengerGroup,3);
 assert.equal(p.demand.cargoGroup,3);
 assert.equal(p.demand.passengerPercent,92);
 assert.equal(p.demand.cargoPercent,88);
});
test('nearby-airport read is bounded to approved nearby locations and excludes the current airport',()=>{
 assert.match(AIRPORT_PROFILE_SQL,/AS nearby_airports/);
 assert.match(AIRPORT_PROFILE_SQL,/FROM airlinerra_game\.approved_game_airports a2/);
 assert.match(AIRPORT_PROFILE_SQL,/a2.airport_key<>a.airport_key/);
 assert.match(AIRPORT_PROFILE_SQL,/distance_km <=100/);
 assert.match(AIRPORT_PROFILE_SQL,/LIMIT 12/);
 const p=serializeAirportProfile({...belgrade,nearby_airports:[
  {key:'FICTIONAL:fictional:RS:LYAL',name:'Aleksandrovo Airport',distanceKm:94.3,iata:null},
  {key:'OURAIRPORTS:42',name:'Too distant',distanceKm:155}
 ]});
 assert.deepEqual(p.nearbyAirports,[{
  key:'FICTIONAL:fictional:RS:LYAL',name:'Aleksandrovo Airport',
  distanceKm:94.3,iata:null,fictional:true
 }]);
});

test('Aleksandrovo uses the 2,200 m fictional runway DESIGN rather than an invented official inventory',()=>{
 const airport=serializeAirportProfile({...belgrade,
  airport_key:'FICTIONAL:fictional:RS:LYAL',
  airport_name:'Aleksandrovo Airport',runways:null,
  game_design_runway_length_m:'2200',
  game_design_runway_surface:'Asphalt',
  game_design_runway_status:'fictional_game_only'
 });
 assert.equal(airport.runways.length,0,'fictional design must not become an observed runway');
 assert.deepEqual(airport.gameRunwayDesign,{
  lengthM:2200,surface:'Asphalt',status:'fictional_game_only'
 });
 assert.equal(routeLongestRunwayLabel(airport),'2,200 m');
 assert.match(AIRPORT_PROFILE_SQL,/airport_fictional_runway_design fd/);
 assert.match(AIRPORT_PROFILE_SQL,/game_design_runway_length_m/);
 const noSource=serializeAirportProfile({...belgrade,
  airport_key:'FICTIONAL:fictional:RS:LYAL',runways:null,
  game_design_runway_length_m:'2200',game_design_runway_status:'unverified'});
 assert.equal(noSource.gameRunwayDesign,null);
 assert.equal(routeLongestRunwayLabel(noSource),'Unverified');
 assert.equal(routeLongestRunwayLabel(serializeAirportProfile(belgrade)),'3,500 m');
 const noData=serializeAirportProfile({...belgrade,runways:[]});
 assert.equal(routeLongestRunwayLabel(noData),'Unverified');
});
test('route cards omit the neutral default note but keep honest restriction statuses',async()=>{
 const sourceCode=await source('../website/route-planner.mjs');
 assert.doesNotMatch(sourceCode,/Neutral game assumption — not independently verified/);
 assert.doesNotMatch(sourceCode,/gameDefault\?'Not source-verified'/);
 assert.match(sourceCode,/routeAirportGameRules\(profile\)/);
 assert.match(sourceCode,/routeLongestRunwayLabel\(profile\)/);
});

test('hosted airport profile supports Group 2 prepared data without approving commercial flights',async()=>{
 const edge=await source('../server/airport-profile-edge-entry.ts');
 assert.match(edge,/GROUP2_AIRPORT_PROFILE_SQL/);
 assert.match(edge,/client\.query\(GROUP2_AIRPORT_PROFILE_SQL,\[key\]\)/);
 assert.match(edge,/group2:true/);
 assert.match(edge,/commercialAccess:false,canActivateFlights:false/);
 assert.match(GROUP2_AIRPORT_PROFILE_SQL,/airport_sections1_8_combined_catalog_v1/);
 assert.match(GROUP2_AIRPORT_PROFILE_SQL,/commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'/);
 assert.match(GROUP2_AIRPORT_PROFILE_SQL,/game_daily_outbound_passengers AS daily_outbound_passengers/);
 assert.match(GROUP2_AIRPORT_PROFILE_SQL,/game_daily_outbound_cargo_tonnes AS daily_outbound_cargo_tonnes/);
 for(const [key,code,runway,passengers,cargo] of [
  ['OURAIRPORTS:31795','LAKU',2197.9,120,0],
  ['OURAIRPORTS:5071','OAJL',2213.5,0,0.056],
  ['OURAIRPORTS:2935','FNBG',1620,77,0]
 ]){
  const profile=serializeAirportProfile({
   airport_key:key,airport_name:'Group 2 airport',
   airport_code:code,country_iso:code==='FNBG'?'AO':code==='OAJL'?'AF':'AL',
   provisional_category:'Regional',
   simple_game_nighttime_ban:false,simple_game_noise_restrictions:false,
   daily_outbound_passengers:passengers,daily_outbound_cargo_tonnes:cargo,
   runways:[{name:'Game runway reference',lengthM:runway,
    surface:null,verification:'game_estimate',operationalStatus:'planning_only'}]
  });
  assert.equal(profile.code,code);
  assert.equal(profile.runways[0].lengthM,runway);
  assert.equal(profile.demand.passengerGroup,1);
  assert.equal(profile.demand.cargoGroup,1);
  assert.equal(profile.operations.simpleNightNoise.nighttimeBan,false);
  assert.equal(profile.operations.simpleNightNoise.noiseRestrictions,false);
 }
});
