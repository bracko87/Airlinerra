/**
 * Cabin-refit authorization gate for a future trusted operations worker.
 * No DB writes, no payment, no aircraft changes, and never runs in the browser.
 * The upstream worker must supply independently verified/current facts,
 * not values from a player request or a saved cabin draft.
 */
const whole=(x,min,max)=>Number.isSafeInteger(x)&&x>=min&&x<=max;
const text=x=>typeof x==='string'&&x.length>0&&x.length<=160;
export function cabinRefitReadiness(facts={}){
 const reasons=[];
 const requireFlag=(name,code)=>{if(facts[name]!==true)reasons.push(code)};
 requireFlag('officialGameClockConnected','GAME_CLOCK_NOT_CONNECTED');
 requireFlag('trustedFlightOperationsReleased','FLIGHT_OPERATIONS_NOT_RELEASED');
 requireFlag('aircraftOwnershipVerified','AIRCRAFT_NOT_OWNED');
 requireFlag('aircraftAtApprovedRefitAirport','AIRCRAFT_NOT_AT_REFIT_SITE');
 requireFlag('providerTypeApproved','REFIT_PROVIDER_NOT_TYPE_APPROVED');
 requireFlag('providerSlotConfirmed','REFIT_SLOT_NOT_CONFIRMED');
 requireFlag('certifiedOrGameApprovedLayout','CABIN_LAYOUT_NOT_APPROVED');
 requireFlag('savedDraftMatchesQuotedRevision','DRAFT_REVISION_CHANGED');
 requireFlag('aircraftAvailableForGrounding','AIRCRAFT_NOT_AVAILABLE');
 requireFlag('noConflictingFlightSchedule','FLIGHT_SCHEDULE_CONFLICT');
 requireFlag('financialPostingServiceReleased','FINANCIAL_SETTLEMENT_NOT_RELEASED');
 requireFlag('airlineFundsVerified','FUNDS_NOT_VERIFIED');
 requireFlag('idempotencyKeyReserved','IDEMPOTENCY_NOT_RESERVED');
 if(!text(facts.aircraftInventoryId)||!text(facts.airlineId))reasons.push('INVALID_AIRCRAFT_IDENTITY');
 if(!whole(facts.downtimeHours,24,48))reasons.push('INVALID_DOWNTIME');
 if(!whole(facts.quotedTotalCents,1,100000000000))reasons.push('INVALID_QUOTE');
 return Object.freeze({ready:reasons.length===0,blockers:Object.freeze(reasons),
  // Readiness never authorizes direct client payment or installation.
  initiatesPayment:false,installsCabin:false,groundsAircraft:false});
}
/** The real worker must still atomically reserve the slot, lock cash and aircraft,
 * debit once, track downtime and commit installed cabin only at completion. */
export const CABIN_REFIT_REQUIRED_ATOMIC_STEPS=Object.freeze([
 'reserve_provider_slot','lock_aircraft_and_airline_wallet',
 'verify_preconditions_and_no_flights','debit_once_and_create_refit_job',
 'ground_aircraft_until_due','complete_after_official_game_clock',
 'verify_completion_and_install_layout','release_aircraft'
]);
