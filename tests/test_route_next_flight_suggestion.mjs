import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {suggestNextReturnFlight,routePlannerMarkup} from '../website/route-planner.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const PA888={
 status:'planning',flightNumber:'PA888',
 aircraftId:'owned:a4547aef-e5a6-4362-8b2b-fbdf96d21907',
 from:{key:'OURAIRPORTS:4610',name:'Belgrade Nikola Tesla',code:'BEG',
  countryIso:'RS',timezoneIana:'Europe/Belgrade'},
 to:{key:'OURAIRPORTS:4615',name:'Tivat',code:'TIV',
  countryIso:'ME',timezoneIana:'Europe/Podgorica'},
 referenceDepartureUtc:'2026-11-14T08:00:00Z',
 referenceArrivalUtc:'2026-11-14T08:55:00Z',
 schedule:Array.from({length:7},(_,day)=>({day,time:'09:00'})),
 operation:{departureStand:'terminal',arrivalStand:'terminal',
 turnaroundMinutes:45}
};
test('PA888 suggests editable daily PA889 from Tivat with original aircraft',()=>{
 const r=suggestNextReturnFlight(PA888,{airlinePrefix:'PA',usedFlightNumbers:['PA888']});
 assert.ok(r);
 assert.equal(r.sourceFlightNumber,'PA888');
 assert.equal(r.flightNumberDigits,'889');
 assert.equal(r.aircraftId,PA888.aircraftId);
 assert.equal(r.from.key,'OURAIRPORTS:4615');
 assert.equal(r.to.key,'OURAIRPORTS:4610');
 assert.equal(r.referenceDepartureUtc,'2026-11-14T09:40:00Z');
 assert.equal(r.referenceArrivalUtc,'2026-11-14T10:35:00Z');
 assert.equal(r.weeklySchedule.length,7);
 assert.ok(r.weeklySchedule.every(w=>w.time==='10:40'));
 assert.deepEqual(r.weeklySchedule.map(w=>w.day),[0,1,2,3,4,5,6]);
 assert.equal(r.evidenceType,'EDITABLE_GAME_ESTIMATE_NOT_OPERATING_FLIGHT');
});
test('suggestion skips used flight numbers and never mutates the saved route',()=>{
 const before=JSON.stringify(PA888);
 const r=suggestNextReturnFlight(PA888,{
  airlinePrefix:'PA',usedFlightNumbers:['PA889','PA890']
 });
 assert.equal(r.flightNumberDigits,'891');
 assert.equal(JSON.stringify(PA888),before);
});
test('one weekly flight inherits weekday and local departure from prior example',()=>{
 const sat={...PA888,schedule:[{day:5,time:'09:00'}]};
 const r=suggestNextReturnFlight(sat,{airlinePrefix:'PA'});
 assert.deepEqual(r.weeklySchedule,[{day:5,time:'10:40'}]);
});
test('no guessing when authoritative example time or destination timezone is absent',()=>{
 assert.equal(suggestNextReturnFlight({...PA888,to:{...PA888.to,timezoneIana:null}},
  {airlinePrefix:'PA'}),null);
 assert.equal(suggestNextReturnFlight({...PA888,referenceArrivalUtc:null},
  {airlinePrefix:'PA'}),null);
 assert.equal(suggestNextReturnFlight({...PA888,aircraftId:'catalog:16'},
  {airlinePrefix:'PA'}),null);
 assert.equal(suggestNextReturnFlight(PA888,{airlinePrefix:'ZZ'}),null);
});
test('the UI offers Next flight and Blank new flight, no automatic return save',async()=>{
 const markup=routePlannerMarkup();
 assert.match(markup,/id="route-plan-next"/);
 assert.match(markup,/Next flight — suggest return/);
 assert.match(markup,/id="route-plan-blank"/);
 assert.match(markup,/id="route-plan-new"/);
 const src=await read('website/route-planner.mjs');
 assert.match(src,/const suggestReturnFromSavedFlight=async/);
 assert.match(src,/await resetRouteForm\(\{blank:true\}\)/);
 assert.match(src,/target\.id==='route-plan-blank'/);
 assert.match(src,/await suggestReturnFromSavedFlight\(flightNumber\)/);
 assert.match(src,/Return flight suggested, NOT CREATED/);
});
test('server returns source time zones from the owner-scoped airport reference table',async()=>{
 const src=await read('server/flight-schedule-service.mjs');
 assert.match(src,/'timezoneIana',origin_timezone\.timezone_iana/);
 assert.match(src,/'timezoneIana',destination_timezone\.timezone_iana/);
 assert.match(src,/origin_timezone\.world_id=1 AND origin_timezone\.airport_key=p\.origin_airport_key/);
 assert.match(src,/destination_timezone\.world_id=1 AND destination_timezone\.airport_key=p\.destination_airport_key/);
});
