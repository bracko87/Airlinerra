import test from 'node:test';
import assert from 'node:assert/strict';
import {createFlightScheduleHandler,FLIGHT_SCHEDULE_API_ROUTE} from '../server/flight-schedule-service.mjs';
const airlineId='11111111-1111-4111-8111-111111111111';
const scheduleId='22222222-2222-4222-8222-222222222222';
const userId='33333333-3333-4333-8333-333333333333';
const endpoint='https://airlinerra.com'+FLIGHT_SCHEDULE_API_ROUTE;
const request=(bearer=true)=>new Request(endpoint,{method:'POST',headers:{
 origin:'https://airlinerra.com','x-airlinerra-route':FLIGHT_SCHEDULE_API_ROUTE,
 'content-type':'application/json',...(bearer?{authorization:'Bearer '+'x'.repeat(32)}:{})
},body:JSON.stringify({action:'schedule-change-assessment',airlineId,scheduleId})});
const defaultEvidence=()=>({scheduleId,scheduleVersion:2,scheduleStatus:'active',operationallyVerified:true,
 reservedSlotCount:6,flightOccurrenceCount:4,currentVersionOccurrenceCount:4,
 reservedBookingBatches:2,reservedPassengerSeats:7,certificateRecords:5});
function fixture({found=true,row=defaultEvidence()}={}){
 const queries=[],holder={released:false};
 const handler=createFlightScheduleHandler({
  verifyUserToken:async()=>({user:{id:userId}}),
  database:{connect:async()=>({
   query:async(sql,params)=>{queries.push({sql,params});
    assert.match(sql,/schedule_operational_certifications_v1/);
    return {rowCount:found?1:0,rows:found?[row]:[]};
   },release:()=>{holder.released=true}
  })}
 });
 return {handler,queries,holder};
}
test('read-only schedule change evidence requires authenticated bearer',async()=>{
 const f=fixture();const r=await f.handler(request(false));
 assert.equal(r.status,401);assert.equal(f.queries.length,0);
});
test('read-only assessment hides another player\'s schedules',async()=>{
 const f=fixture({found:false}),r=await f.handler(request());
 assert.equal(r.status,404);
 assert.equal(f.queries.length,1);
 assert.deepEqual(f.queries[0].params,[userId,airlineId,scheduleId]);
 assert.match(f.queries[0].sql,/a.owner_player_id=\$1::uuid/);
 assert.equal(f.holder.released,true);
});
test('active flights always remain locked even with zero bookings',async()=>{
 const row={...defaultEvidence(),reservedBookingBatches:0,reservedPassengerSeats:0};
 const f=fixture({row}),r=await f.handler(request());assert.equal(r.status,200);
 const v=await r.json();
 assert.equal(v.status,'schedule_change_assessment_read_only');
 assert.equal(v.readOnly,true);
 assert.equal(v.canCancelOperationalFlight,false);
 assert.equal(v.canRescheduleOperationalFlight,false);
 assert.equal(v.bookingMutation,false);
 assert.equal(v.slotMutation,false);
 assert.equal(v.ledgerPosted,false);
 assert.equal(v.evidence.reservedSlotCount,6);
 assert.equal(v.evidence.flightOccurrenceCount,4);
 assert.ok(v.blockers.includes('ACTIVE_SCHEDULE_REQUIRES_TRANSACTIONAL_RELEASE'));
 assert.ok(v.blockers.includes('AIRPORT_SLOTS_REQUIRE_ATOMIC_RELEASE'));
 assert.equal(f.queries.length,1);
 assert.doesNotMatch(f.queries[0].sql,/\b(?:INSERT|UPDATE|DELETE|CALL)\b/i);
 assert.equal(f.holder.released,true);
});
test('reserved passengers trigger explicit protection blocker',async()=>{
 const f=fixture(),r=await f.handler(request());
 assert.equal(r.status,200);const v=await r.json();
 assert.equal(v.evidence.reservedPassengerSeats,7);
 assert.ok(v.blockers.includes('PASSENGER_RESERVATIONS_REQUIRE_PROTECTION'));
});
test('invalid evidence never becomes a valid cancellation receipt',async()=>{
 for(const row of [{...defaultEvidence(),reservedSlotCount:-1},
  {...defaultEvidence(),reservedPassengerSeats:'7'},
  {...defaultEvidence(),scheduleId:'44444444-4444-4444-8444-444444444444'},
  {...defaultEvidence(),scheduleVersion:null}]){
  const f=fixture({row}),r=await f.handler(request());
  assert.equal(r.status,503);
 }
});
