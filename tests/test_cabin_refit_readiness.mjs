import test from 'node:test';
import assert from 'node:assert/strict';
import {cabinRefitReadiness,CABIN_REFIT_REQUIRED_ATOMIC_STEPS}
 from '../server/cabin-refit-readiness.mjs';
const approved={officialGameClockConnected:true,trustedFlightOperationsReleased:true,
 aircraftOwnershipVerified:true,aircraftAtApprovedRefitAirport:true,
 providerTypeApproved:true,providerSlotConfirmed:true,
 certifiedOrGameApprovedLayout:true,savedDraftMatchesQuotedRevision:true,
 aircraftAvailableForGrounding:true,noConflictingFlightSchedule:true,
 financialPostingServiceReleased:true,airlineFundsVerified:true,
 idempotencyKeyReserved:true,aircraftInventoryId:'airframe-1',
 airlineId:'airline-1',downtimeHours:24,quotedTotalCents:12590000};
test('refit is denied in the unreleased World 1',()=>{
 const x=cabinRefitReadiness({});
 assert.equal(x.ready,false);
 assert.ok(x.blockers.includes('GAME_CLOCK_NOT_CONNECTED'));
 assert.ok(x.blockers.includes('FLIGHT_OPERATIONS_NOT_RELEASED'));
 assert.ok(x.blockers.includes('FINANCIAL_SETTLEMENT_NOT_RELEASED'));
 assert.equal(x.initiatesPayment,false);
});
test('every necessary independently confirmed gate is fail closed',()=>{
 assert.equal(cabinRefitReadiness(approved).ready,true);
 for(const name of Object.keys(approved).filter(k=>approved[k]===true)){
  const x=cabinRefitReadiness({...approved,[name]:false});
  assert.equal(x.ready,false,name);
 }
 for(const quotedTotalCents of [0,-1,1.5,NaN,Infinity]){
  assert.equal(cabinRefitReadiness({...approved,quotedTotalCents}).ready,false);
 }
 for(const downtimeHours of [0,23,49,1.2]){
  assert.equal(cabinRefitReadiness({...approved,downtimeHours}).ready,false);
 }
});
test('readiness is pure and never settles, grounds, or installs',()=>{
 const x=cabinRefitReadiness(approved);
 assert.equal(x.initiatesPayment,false);
 assert.equal(x.installsCabin,false);
 assert.equal(x.groundsAircraft,false);
 assert.ok(CABIN_REFIT_REQUIRED_ATOMIC_STEPS.includes('debit_once_and_create_refit_job'));
 assert.ok(CABIN_REFIT_REQUIRED_ATOMIC_STEPS.includes('verify_completion_and_install_layout'));
});
