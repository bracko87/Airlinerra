import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {ownerPlanningEstimate,planningClockEstimate}
 from '../website/route-planning-times.mjs';

const id='6fd07fce-cf98-481f-b61d-13c58732adc5';
const aircraft='a4547aef-e5a6-4362-8b2b-fbdf96d21907';
const weekly=Array.from({length:7},(_,day)=>({day,time:'09:00'}));
const plan={planId:id,aircraftInventoryId:aircraft,flightNumber:'PA888',
 originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'OURAIRPORTS:4615',
 schedule:weekly};
const draft={serverPlanningId:id,aircraftId:'owned:'+aircraft,flightNumber:'PA888',
 from:{key:'OURAIRPORTS:4610'},to:{key:'OURAIRPORTS:4615'},
 schedule:weekly,estimatedDurationSource:'five_phase_game_estimate',
 estimatedDurationMinutes:57};

test('PA888 reads its saved 57-minute aircraft estimate only from its exact Supabase workplan',()=>{
 assert.deepEqual(ownerPlanningEstimate(plan,[draft]),{
  estimatedDurationMinutes:57,estimatedDurationSource:'five_phase_game_estimate'
 });
 const mismatches=[
  {...draft,serverPlanningId:'wrong'},
  {...draft,aircraftId:'owned:other'},
  {...draft,flightNumber:'PA889'},
  {...draft,from:{key:'OTHER'}},
  {...draft,to:{key:'OTHER'}},
  {...draft,schedule:[{day:0,time:'09:00'}]},
  {...draft,estimatedDurationSource:'unverified'},
  {...draft,estimatedDurationMinutes:0}
 ];
 for(const wrong of mismatches)
  assert.deepEqual(ownerPlanningEstimate(plan,[wrong]),{});
 assert.deepEqual(ownerPlanningEstimate(plan,null),{});
});
test('57-minute model estimates 09:57 arrival and 10:42 ready, without approving a flight',()=>{
 const result=planningClockEstimate(weekly,57,45);
 assert.ok(result);
 assert.equal(result.rows.length,7);
 assert.equal(result.sameDepartureTime,true);
 assert.equal(result.rows[0].arrivalClock,'09:57');
 assert.equal(result.rows[0].availableClock,'10:42');
 assert.equal(result.rows[0].arrivalDayOffset,0);
 assert.equal(result.rows[0].availableDayOffset,0);
 assert.equal(result.durationMinutes,57);
 assert.equal(result.operationallyVerified,undefined);
 assert.equal(result.slotsReserved,undefined);
});
test('overnight time estimates wrap midnight explicitly and invalid values are refused',()=>{
 const row=[{day:0,time:'23:40'}];
 const overnight=planningClockEstimate(row,60,45);
 assert.equal(overnight.rows[0].arrivalClock,'00:40');
 assert.equal(overnight.rows[0].arrivalDayOffset,1);
 assert.equal(overnight.rows[0].availableClock,'01:25');
 assert.equal(overnight.rows[0].availableDayOffset,1);
 for(const bad of [null,0,24,-1,1441,57.5])
  assert.equal(planningClockEstimate(row,bad,45),null);
 assert.equal(planningClockEstimate([{day:0,time:'9am'}],57,45),null);
 assert.equal(planningClockEstimate(row,57,5),null);
});
test('the route form shows a short confirmation and drops repeated fake slot checks',async()=>{
 const get=p=>readFile(new URL('../website/'+p,import.meta.url),'utf8');
 const [form,details,directory,bundle]=await Promise.all([
  get('route-planner.mjs'),get('section9-route-details.mjs'),
  get('airline-operations-center.mjs'),get('dev-scripts/invited-overlay.mjs')
 ]);
 assert.match(form,/const text='Route '\+flightNumber\+' created\.'/);
 assert.doesNotMatch(form,/saved in your AIRLINE DATABASE as a planning route/);
 assert.match(form,/planningClockEstimate\(schedule,modelMinutes,target\)/);
 assert.doesNotMatch(form,/weekRow\('Slot availability'/);
 assert.match(form,/Ready after turnaround \(estimate\)/);
 assert.match(details,/planningClockEstimate\(weekly,route\.estimatedDurationMinutes/);
 assert.match(details,/These are planning estimates, not approved flight times or airport slots/);
 assert.doesNotMatch(details,/Pending verified aircraft performance/);
 assert.match(directory,/ownerPlanningEstimate\(plan,state\.routes\)/);
 assert.match(directory,/planningClockEstimate\(route\.schedule/);
 assert.match(bundle,/'route-planning-times\.mjs'/);
});
