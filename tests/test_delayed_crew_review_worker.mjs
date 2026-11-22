import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewDelayedCrewRotations} from '../server/rolling-crew-replacement-worker.mjs';
test('review is bounded, owner scoped, read only, and classifies crew replacement without writes',async()=>{
 const queries=[];
 const client={async query(sql,args){queries.push({sql,args});return {rows:[
 {occurrenceId:'f1',result:{status:'delayed_crew_duty_windows_fit',dispatchEnforced:false}},
 {occurrenceId:'f2',result:{status:'delayed_crew_replacement_required',dispatchEnforced:false,employeesRequiringReplacementOrReview:6}}
 ]};}};
 const r=await reviewDelayedCrewRotations({client,playerId:'p',airlineId:'a',limit:20});
 assert.equal(r.assessedFlights,2);assert.equal(r.counts.delayed_crew_replacement_required,1);
 assert.equal(r.changesPersisted,false);assert.equal(r.dispatchEnforced,false);
 assert.equal(queries.length,1);assert.match(queries[0].sql,/owner_player_id=\$1/);
 assert.match(queries[0].sql,/^\s*SELECT/);assert.deepEqual(queries[0].args,['p','a',20]);
});
test('invalid limits and unverified database replies fail closed',async()=>{
 const client={async query(){return {rows:[{occurrenceId:'f1',result:{status:'ok',dispatchEnforced:true}}]};}};
 await assert.rejects(reviewDelayedCrewRotations({client,limit:101}),/INVALID_DELAYED_CREW_REVIEW/);
 await assert.rejects(reviewDelayedCrewRotations({client,limit:10}),/DELAYED_CREW_ASSESSMENT_UNVERIFIED/);
});
