import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createGameAirportCatalogService, validatedCountryRequest,
  validatedGameAirportRow, COUNTRY_DIRECTORY_SQL,
  HOME_AIRPORT_PAGE_SQL, HOME_AIRPORT_LOOKUP_SQL
} from '../server/game-airport-catalog.mjs';

function sample(id='5336', country='US') {
  return {
    world_id:1, home_airport_source_id:id, airport_key:'OURAIRPORTS:'+id,
    airport_code:'PAQ',airport_name:'Palmer Municipal Airport',
    country_iso:country,municipality:'Palmer',provisional_game_category:'Regional'
  };
}
function pool(responseBySql={},failAt=null) {
  const history=[];
  return {history,database:{
    async connect(){
      history.push(['connect']);
      if(failAt==='connect')throw Error('connection failed');
      return {
        async query(sql,args) {
          history.push(['query',sql,args]);
          if(failAt==='query')throw Error('database unavailable');
          return {rows:responseBySql[sql]??[]};
        },
        release(){history.push(['release']);}
      };
    }
  }};
}
test('backend lookup defaults disabled with zero DB calls',async()=>{
  const {database,history}=pool();
  const client=createGameAirportCatalogService({database});
  await assert.rejects(client.listCountries(),/disabled/);
  await assert.rejects(client.lookupAirport({homeAirportSourceId:'5336'}),/disabled/);
  assert.deepEqual(history,[]);
});
test('country and pagination input must stay in World 1 and be parameterized',()=>{
  assert.deepEqual(validatedCountryRequest({countryIso:'US',limit:50,afterSourceId:'5336'}),
   {worldId:1,countryIso:'US',afterSourceId:'5336',limit:50});
  for(const invalid of [
    {countryIso:'us'},{countryIso:'US;drop table airlines'},
    {countryIso:'US',worldId:2},{countryIso:'US',limit:0},
    {countryIso:'US',limit:101},{countryIso:'US',afterSourceId:'-1'},
    {countryIso:'US',afterSourceId:'0 OR 1=1'},
    {countryIso:'US',afterSourceId:'9223372036854775808'}
  ]) assert.throws(()=>validatedCountryRequest(invalid));
  assert.ok(HOME_AIRPORT_PAGE_SQL.includes('country_iso=$2::text'));
  assert.ok(HOME_AIRPORT_PAGE_SQL.includes('home_airport_source_id>$3::bigint'));
  assert.ok(HOME_AIRPORT_LOOKUP_SQL.includes('home_airport_source_id=$2::bigint'));
});
test('stable numeric IDs must correspond to known original airport keys',()=>{
  const accepted=validatedGameAirportRow(sample());
  assert.equal(accepted.homeAirportSourceId,'5336');
  assert.equal(accepted.worldId,1);
  assert.equal(accepted.provisionalCategory,'Regional');
  assert.ok(Object.isFrozen(accepted));
  for(const row of [
    {...sample(),world_id:2},
    {...sample(),airport_key:'OURAIRPORTS:0005336'},
    {...sample(),country_iso:'USA'},
    {...sample(),provisional_game_category:'Very Large'},
    {...sample(),home_airport_source_id:'0'},
    {...sample(),home_airport_source_id:'9223372036854775808'},
    {...sample(),airport_code:''}
  ]) assert.throws(()=>validatedGameAirportRow(row));
});
test('country lookup uses no user input in SQL and releases DB connection',async()=>{
  const {database,history}=pool({[COUNTRY_DIRECTORY_SQL]:[
    {country_iso:'US',airport_count:483},{country_iso:'DE',airport_count:36}
  ]});
  const service=createGameAirportCatalogService({database,enabled:true});
  const countries=await service.listCountries();
  assert.deepEqual(countries,[{countryIso:'US',airportCount:483},{countryIso:'DE',airportCount:36}]);
  assert.ok(Object.isFrozen(countries));
  assert.deepEqual(history.map(x=>x[0]),['connect','query','release']);
  assert.deepEqual(history[1].slice(1),[COUNTRY_DIRECTORY_SQL,[1]]);
});
test('paged lookup is stable; source IDs match the create_airline_once BIGINT input',async()=>{
  const {database,history}=pool({
    [HOME_AIRPORT_PAGE_SQL]:[sample('5336'),sample('5337')],
    [HOME_AIRPORT_LOOKUP_SQL]:[sample('5336')]
  });
  const service=createGameAirportCatalogService({database,enabled:true});
  const airports=await service.listAirports({worldId:1,countryIso:'US',limit:2,afterSourceId:'5335'});
  assert.equal(airports.length,2);
  assert.deepEqual(airports.map(a=>a.homeAirportSourceId),['5336','5337']);
  const selected=await service.lookupAirport({homeAirportSourceId:5336});
  assert.equal(selected.homeAirportSourceId,'5336');
  assert.deepEqual(history.filter(h=>h[0]==='query').map(h=>h[2]),[
    [1,'US','5335',2],[1,'5336']
  ]);
  assert.equal(history.filter(h=>h[0]==='release').length,2);
});
test('reject country crossover, cursor reversal and duplicate game IDs',async()=>{
  const invalidPages=[
    [sample('5336','DE')],
    [sample('5335')],
    [sample('5337'),sample('5336')]
  ];
  for(const rows of invalidPages){
    const {database}=pool({[HOME_AIRPORT_PAGE_SQL]:rows});
    const client=createGameAirportCatalogService({database,enabled:true});
    await assert.rejects(client.listAirports({countryIso:'US',afterSourceId:'5335'}));
  }
  const {database}=pool({[HOME_AIRPORT_LOOKUP_SQL]:[sample('5336'),sample('5336')]});
  const client=createGameAirportCatalogService({database,enabled:true});
  await assert.rejects(client.lookupAirport({homeAirportSourceId:'5336'}),/Duplicate/);
});
test('connection is released on failure and no public route is installed',async()=>{
  const {database,history}=pool({},'query');
  const service=createGameAirportCatalogService({database,enabled:true});
  await assert.rejects(service.listCountries(),/unavailable/);
  assert.equal(history.at(-1)[0],'release');
  assert.equal(typeof service.createAirline,'undefined');
  assert.equal(typeof service.openWorld,'undefined');
});
