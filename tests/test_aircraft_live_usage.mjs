import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRCRAFT_LIBRARY_SQL,serializeAircraftLibrary} from '../server/aircraft-library-query.mjs';

const sample={
 id:15,manufacturer:'Airbus',family:'A300',model:'A300-600F',
 configuration:'CARGO-BASE',use_type:'cargo',
 image_storage_object_path:'Airplanes/Airbus A300-600F cargo.png',
 game_icao_noise_chapter:3,official_icao_chapter:null,
 fleet_in_use:0,top_airlines:[]
};

test('live usage query reads real airline airframes, never isolated test fixtures',()=>{
 assert.match(AIRCRAFT_LIBRARY_SQL,/airlinerra_game\.airline_aircraft_inventory/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/fleet_status='in_service'/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/join airlinerra_game\.airlines airline/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/limit 3/);
 assert.doesNotMatch(AIRCRAFT_LIBRARY_SQL,/airline_aircraft_test_fixtures/);
 assert.match(AIRCRAFT_LIBRARY_SQL,/^\s*select\s/);
 assert.doesNotMatch(AIRCRAFT_LIBRARY_SQL,/\b(?:insert|update|delete|alter|drop|truncate|grant)\b/);
});

test('zero actual airframes is zero, not fake user or sample airlines',()=>{
 const [aircraft]=serializeAircraftLibrary([sample]).aircraft;
 assert.equal(aircraft.fleetInUse,0);
 assert.deepEqual(aircraft.topAirlines,[]);
 assert.equal(aircraft.imagePath,sample.image_storage_object_path);
});

test('only three safe airline names and positive quantities are serialized',()=>{
 const top_airlines=[
  {airlineName:'Operator One',quantity:25},
  {airlineName:'Operator Two',quantity:20},
  {airlineName:'Operator Three',quantity:14},
  {airlineName:'Operator Four',quantity:7}
 ];
 const [aircraft]=serializeAircraftLibrary([{...sample,fleet_in_use:66,top_airlines}]).aircraft;
 assert.equal(aircraft.fleetInUse,66);
 assert.deepEqual(aircraft.topAirlines,top_airlines.slice(0,3));
});

test('UI shows usage totals and three operators, with no crossed-out qualification row',async()=>{
 const js=await readFile(new URL('../website/aircraft-library.mjs',import.meta.url),'utf8');
 const css=await readFile(new URL('../website/aircraft-library.css',import.meta.url),'utf8');
 assert.match(js,/liveFleetGroup\(a\)/);
 assert.match(js,/Top 3 airlines by quantity/);
 assert.match(js,/No airlines currently use this aircraft configuration/);
 assert.doesNotMatch(js,/Source & operational qualifications/);
 assert.doesNotMatch(js,/Classification evidence/);
 assert.match(css,/height:380px;min-height:380px;max-height:380px/);
 assert.match(css,/object-fit:contain/);
 assert.match(css,/object-position:center center;transform:none/);
 assert.doesNotMatch(css,/object-fit:cover/);
});
