import test from 'node:test';
import assert from 'node:assert/strict';
import {previewStorageAwareCrewPlan} from '../server/persistent-crew-plan-worker.mjs';
const airlineId='airline',playerId='player',windowStartUtc='2026-11-27T12:00:00Z';
const member=(id,role)=>({id,initialAirport:'STORAGE',baseTimezone:'UTC',locationEffectiveUtc:'2026-11-01T00:00:00Z',employmentFrom:'2026-11-01',history:[{startUtc:'2026-11-26T15:00:00Z',endUtc:'2026-11-26T20:00:00Z',origin:'STORAGE',destination:'BASE'}],absences:[],permissions:[{group:'family',issued:'2026-11-01',expires:'2027-11-01',active:true,captain:role==='captain',firstOfficer:role==='firstOfficer'}]});
const snapshot=()=>({status:'storage_aware_crew_input_preview',airlineId,windowStartUtc,planNotBeforeUtc:windowStartUtc,storageHistoryIncluded:true,enforceRollingWeeklyDutyHours:true,saveAllowed:false,crewReleased:false,dispatchEnforced:false,excludedEmployees:[],pilots:[member('cap','captain'),member('fo','firstOfficer')],cabinMembers:[],flights:[{id:'flight',aircraftId:'tail',group:'family',origin:'BASE',destination:'NEXT',departureUtc:'2026-11-27T15:00:00Z',arrivalUtc:'2026-11-27T17:00:00Z',cabinRequired:0}]});
function mock(value){let calls=0;return {get calls(){return calls},query:async(sql,args)=>{calls++;assert.match(sql,/owned_storage_aware_crew_input_preview_v1/);assert.deepEqual(args,[playerId,airlineId,windowStartUtc]);return {rows:[{result:value}]};}};}
test('storage-aware crew planning uses signed-history destination without saving',async()=>{
 const client=mock(snapshot());const result=await previewStorageAwareCrewPlan({client,playerId,airlineId,windowStartUtc});
 assert.equal(result.saved,false);assert.equal(result.crewReleased,false);assert.equal(result.plan.assignedFlightCount,1);assert.deepEqual(result.plan.assignments[0].captains,['cap']);assert.equal(client.calls,1);
 await assert.rejects(previewStorageAwareCrewPlan({client,playerId,airlineId,windowStartUtc,save:true}),/PREVIEW_ONLY/);assert.equal(client.calls,1);
});
test('storage-aware crew planning prevents premature rest and wrong location',async()=>{
 const a=snapshot();a.pilots[0].history[0].endUtc='2026-11-27T04:00:00Z';a.pilots[0].history[0].startUtc='2026-11-26T20:00:00Z';
 const result=await previewStorageAwareCrewPlan({client:mock(a),playerId,airlineId,windowStartUtc});assert.equal(result.plan.assignedFlightCount,0);
 const b=snapshot();b.pilots[0].history[0].destination='OTHER';assert.equal((await previewStorageAwareCrewPlan({client:mock(b),playerId,airlineId,windowStartUtc})).plan.assignedFlightCount,0);
});
test('storage-aware crew planning rejects unverified server response',async()=>{
 for(const change of [{crewReleased:true},{saveAllowed:true},{airlineId:'other'},{enforceRollingWeeklyDutyHours:false}]){
  await assert.rejects(previewStorageAwareCrewPlan({client:mock({...snapshot(),...change}),playerId,airlineId,windowStartUtc}),/INPUT_NOT_VERIFIED/);
 }
});
test('storage-aware crew planning enforces 60 hours including extended duty',async()=>{
 const {planWeeklyCrew}=await import('../server/weekly-crew-allocation-engine.mjs');
 const base=snapshot();base.windowStartUtc='2026-11-27T00:00:00Z';base.planNotBeforeUtc=base.windowStartUtc;
 // 54 hours of completed duty. The first reporting date is outside the
 // five-day-in-seven calendar check but its duty falls in a 168-hour window.
 const histories=[20,21,22,23,24].map(day=>({startUtc:'2026-11-'+day+'T12:00:00Z',endUtc:day===20?'2026-11-20T18:00:00Z':'2026-11-'+(day+1)+'T00:00:00Z',origin:'BASE',destination:'BASE'}));
 for(const p of base.pilots){p.initialAirport='BASE';p.history=histories;}
 base.flights=[{id:'one',aircraftId:'tail',group:'family',origin:'BASE',destination:'NEXT',departureUtc:'2026-11-27T02:00:00Z',arrivalUtc:'2026-11-27T04:00:00Z',cabinRequired:0},{id:'two',aircraftId:'tail',group:'family',origin:'NEXT',destination:'BASE',departureUtc:'2026-11-27T05:00:00Z',arrivalUtc:'2026-11-27T07:00:00Z',cabinRequired:0}];
 const limited=planWeeklyCrew(base);assert.equal(limited.assignedFlightCount,1);assert.equal(limited.shortages[0].flightId,'two');
 const legacy=planWeeklyCrew({...base,enforceRollingWeeklyDutyHours:false});assert.equal(legacy.assignedFlightCount,2);assert.equal(legacy.assignments[1].duties[0].continuedDuty,true);
});
