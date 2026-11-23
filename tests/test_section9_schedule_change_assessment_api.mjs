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
 reservedBookingBatches:2,reservedPassengerSeats:7,
 paidUpfrontReservationCount:1,nonReservedReservationCount:2,
 quotedReservedFareUsd:625,certificateRecords:5,
 operatedMovementCount:1,actualFinancePreparationCount:2,preparedSettlementCount:3,
 pendingConnectingJourneyLegCount:1,connectingHoldPlanItemCount:2,
 recognizedFlightRevenueUsd:450,
 recognizedReservationRevenueUsd:450});
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
 assert.equal(v.bookingWriterLockProtocolVerified,false);
 assert.ok(v.blockers.includes('BOOKING_CANCELLATION_LOCK_PROTOCOL_UNVERIFIED'));
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
 assert.ok(v.blockers.includes('UPFRONT_PAID_TICKETS_REQUIRE_PAYMENT_AUDIT'));
 assert.ok(v.blockers.includes('HISTORICAL_RESERVATION_STATES_REQUIRE_REVIEW'));
 assert.equal(v.evidence.quotedReservedFareUsd,625);
 assert.equal(v.flightLedgerReconciliationAvailable,false);
 assert.equal(v.quotedFareIsRefundAmount,false);
 assert.ok(v.blockers.includes('OPERATED_MOVEMENTS_MUST_BE_PRESERVED'));
 assert.ok(v.blockers.includes('PREPARED_SETTLEMENTS_REQUIRE_ACCOUNTING_RECONCILIATION'));
 assert.ok(v.blockers.includes('CONNECTING_JOURNEY_HOLDS_REQUIRE_ATOMIC_RECOVERY'));
 assert.equal(v.evidence.pendingConnectingJourneyLegCount,1);
 assert.ok(v.blockers.includes('RECOGNIZED_REVENUE_REQUIRES_ACCOUNTING_RECONCILIATION'));
 assert.equal(v.evidence.operatedMovementCount,1);
 assert.equal(v.evidence.recognizedFlightRevenueUsd,450);
});
test('invalid evidence never becomes a valid cancellation receipt',async()=>{
 for(const row of [{...defaultEvidence(),reservedSlotCount:-1},
  {...defaultEvidence(),reservedPassengerSeats:'7'},
  {...defaultEvidence(),scheduleId:'44444444-4444-4444-8444-444444444444'},
  {...defaultEvidence(),scheduleVersion:null},
  {...defaultEvidence(),operatedMovementCount:-1},
  {...defaultEvidence(),actualFinancePreparationCount:-1},
  {...defaultEvidence(),preparedSettlementCount:'3'},
  {...defaultEvidence(),pendingConnectingJourneyLegCount:-1},
  {...defaultEvidence(),connectingHoldPlanItemCount:'2'},
  {...defaultEvidence(),paidUpfrontReservationCount:-1},
  {...defaultEvidence(),nonReservedReservationCount:'2'},
  {...defaultEvidence(),quotedReservedFareUsd:Infinity},
  {...defaultEvidence(),recognizedFlightRevenueUsd:'450'},
  {...defaultEvidence(),recognizedReservationRevenueUsd:Infinity}]){
  const f=fixture({row}),r=await f.handler(request());
  assert.equal(r.status,503);
 }
});

test('a schedule with a past movement remains non-cancellable even without future bookings',async()=>{
 const row={...defaultEvidence(),reservedSlotCount:0,flightOccurrenceCount:0,
  currentVersionOccurrenceCount:0,reservedBookingBatches:0,reservedPassengerSeats:0,
  certificateRecords:0,recognizedFlightRevenueUsd:0,
  recognizedReservationRevenueUsd:0};
 const f=fixture({row}),r=await f.handler(request());assert.equal(r.status,200);
 const result=await r.json();
 assert.equal(result.canCancelOperationalFlight,false);
 assert.ok(result.blockers.includes('OPERATED_MOVEMENTS_MUST_BE_PRESERVED'));
});

test('active schedule cancellation stays disabled even if all other blockers are absent',async()=>{
 const row={...defaultEvidence(),reservedSlotCount:0,flightOccurrenceCount:0,
  currentVersionOccurrenceCount:0,reservedBookingBatches:0,reservedPassengerSeats:0,
  certificateRecords:0,operatedMovementCount:0,actualFinancePreparationCount:0,
  preparedSettlementCount:0,paidUpfrontReservationCount:0,
  nonReservedReservationCount:0,quotedReservedFareUsd:0,pendingConnectingJourneyLegCount:0,
  connectingHoldPlanItemCount:0,recognizedFlightRevenueUsd:0,recognizedReservationRevenueUsd:0};
 const f=fixture({row}),reply=await f.handler(request());
 assert.equal(reply.status,200);
 const value=await reply.json();
 assert.equal(value.bookingWriterLockProtocolVerified,false);
 assert.equal(value.canCancelOperationalFlight,false);
 assert.equal(value.canRescheduleOperationalFlight,false);
 assert.ok(value.blockers.includes('BOOKING_CANCELLATION_LOCK_PROTOCOL_UNVERIFIED'));
});

test('an outstanding two-leg hold independently blocks cancellation review',async()=>{
 const row={...defaultEvidence(),reservedBookingBatches:0,reservedPassengerSeats:0,
  pendingConnectingJourneyLegCount:1,connectingHoldPlanItemCount:1};
 const f=fixture({row}),reply=await f.handler(request());
 assert.equal(reply.status,200);
 const result=await reply.json();
 assert.equal(result.canCancelOperationalFlight,false);
 assert.ok(result.blockers.includes('CONNECTING_JOURNEY_HOLDS_REQUIRE_ATOMIC_RECOVERY'));
});

test('paid upfront reservations block payment recovery even with no active booked seats',async()=>{
 const row={...defaultEvidence(),reservedBookingBatches:0,reservedPassengerSeats:0,
  paidUpfrontReservationCount:1,nonReservedReservationCount:0,
  recognizedFlightRevenueUsd:0,recognizedReservationRevenueUsd:0,
  quotedReservedFareUsd:0};
 const f=fixture({row}),reply=await f.handler(request());
 assert.equal(reply.status,200);const value=await reply.json();
 assert.equal(value.flightLedgerReconciliationAvailable,false);
 assert.equal(value.quotedFareIsRefundAmount,false);
 assert.ok(value.blockers.includes('UPFRONT_PAID_TICKETS_REQUIRE_PAYMENT_AUDIT'));
 assert.equal(value.canCancelOperationalFlight,false);
});
