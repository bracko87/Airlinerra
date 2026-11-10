/**
 * Airlinerra private FIVE-PHASE flight simulation timeline.
 *
 * PURE PLANNING / DRY RUN. This is not independent proof that a scheduled
 * aircraft has flown. No flight activation, movement ingress, fuel tank
 * deduction, refuelling, customer bookings, or financial settlement.
 *
 * Future trusted game workers may use this as a deterministic duration /
 * phase-budget reference AFTER independently verifying a certified game day,
 * active schedule, actual phase progress, crew, permissions and physical state.
 */
import {estimateFivePhaseFuel} from '../website/flight-fuel-phase-engine.mjs';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;
const KEYS=Object.freeze(['taxiOut','climb','cruise','descent','taxiIn']);
const round=n=>Math.round(n*100)/100;
const validUtc=x=>typeof x==='string'&&UTC.test(x)&&
 Number.isFinite(Date.parse(x))&&new Date(x).toISOString().slice(0,19)+'Z'===x;
const iso=t=>new Date(t).toISOString().replace('.000Z','Z');
const locked=reason=>Object.freeze({
 status:'FLIGHT_PHASE_PLAN_BLOCKED',reason,simulatedOnly:true,
 dispatchAuthorized:false,flightActivated:false,movementRecorded:false,
 tankUpdated:false,bookingsCreated:false,ledgerPosted:false
});

/** Constructs a five-phase plan; even a valid one is NEVER a flight receipt.
 * The airplane identity and date MUST originate from a server-owned schedule.
 */
export function planSection9FivePhaseFlight({
 airlineId,aircraftInventoryId,scheduleId,flightLocalDate,weeklyEntry,
 scheduledDepartureUtc,originAirportKey,destinationAirportKey,
 distanceKm,aircraft={},payloadFraction=.5,fuelPriceUsdPerKg=.95
}={}){
 if(!UUID.test(airlineId||'')||!UUID.test(aircraftInventoryId||'')||
    !UUID.test(scheduleId||'')||!DAY.test(flightLocalDate||'')||
    !Number.isInteger(weeklyEntry)||weeklyEntry<1||weeklyEntry>7||
    !validUtc(scheduledDepartureUtc)||
    typeof originAirportKey!=='string'||originAirportKey.length<4||
    typeof destinationAirportKey!=='string'||destinationAirportKey.length<4||
    originAirportKey===destinationAirportKey)
  return locked('UNVERIFIED_OR_INVALID_FLIGHT_IDENTITY');
 if(aircraft.airlineId!==airlineId||
    aircraft.id!==aircraftInventoryId||
    !Number.isSafeInteger(Number(aircraft.configurationId))||
    aircraft.fuelFamily!=='TURBINE_KEROSENE_ASSUMED')
  return locked('UNVERIFIED_AIRCRAFT_OR_GAME_FUEL_FAMILY');

 const fuel=estimateFivePhaseFuel({
  distanceKm,cruiseSpeedKmh:aircraft.cruiseSpeedKmh,
  cruiseFuelKgPerHour:aircraft.cruiseFuelKgPerHour,
  emptyFuelKgPer100Km:aircraft.emptyFuelKgPer100Km,
  halfFuelKgPer100Km:aircraft.halfFuelKgPer100Km,
  fullFuelKgPer100Km:aircraft.fullFuelKgPer100Km,
  fuelTankCapacityKg:aircraft.fuelTankCapacityKg,
  payloadFraction,priceUsdPerKg:fuelPriceUsdPerKg
 });
 if(fuel.status!=='PLANNING_ESTIMATE'||fuel.phases.length!==5||
    fuel.phases.some((p,i)=>p.key!==KEYS[i]||p.minutes<0||p.fuelKg<0))
  return locked('AIRCRAFT_PHASE_FUEL_UNAVAILABLE');

 const flightOccurrenceId=scheduleId+':'+flightLocalDate+':'+weeklyEntry;
 let instant=Date.parse(scheduledDepartureUtc);
 const phases=fuel.phases.map((phase,index)=>{
  const start=instant;
  // Integer seconds make repeated reads deterministic and avoid drifting
  // phase boundaries. Zero-duration cruise on short sectors is valid.
  const elapsedSeconds=Math.max(0,Math.round(phase.minutes*60));
  instant+=elapsedSeconds*1000;
  return Object.freeze({
   index,key:phase.key,label:phase.label,
   scheduledStartUtc:iso(start),scheduledEndUtc:iso(instant),
   durationSeconds:elapsedSeconds,
   fuelBudgetKg:phase.fuelKg,
   distanceKm:phase.distanceKm,
   // This ID MUST NOT be accepted by the signed movement ingress.
   forecastId:'flight-phase-preview:'+flightOccurrenceId+':'+phase.key,
   movementRecorded:false,actualOperationVerified:false
  });
 });
 return Object.freeze({
  status:'FLIGHT_PHASE_DRY_RUN_PLAN',
  flightOccurrenceId,airlineId,aircraftInventoryId,scheduleId,
  flightLocalDate,weeklyEntry,originAirportKey,destinationAirportKey,
  scheduledDepartureUtc,plannedCompletionUtc:iso(instant),
  scheduledBlockSeconds:(instant-Date.parse(scheduledDepartureUtc))/1000,
  phases,fuel,
  tankScreen:fuel.referenceTankScreen,
  requiresCertifiedGameClock:true,
  requiresIndependentOperationalEvidence:true,
  simulatedOnly:true,dispatchAuthorized:false,flightActivated:false,
  movementRecorded:false,tankUpdated:false,bookingsCreated:false,ledgerPosted:false
 });
}

/** Inspect simulated progress against a supplied, independently verified
 * game-clock instant. This function does NOT verify a clock signature and
 * cannot produce a trusted "departed" or "arrived" movement event.
 */
export function inspectSection9FlightProjection(plan,gameClockUtc){
 if(plan?.status!=='FLIGHT_PHASE_DRY_RUN_PLAN'||!validUtc(gameClockUtc))
  return locked('PLAN_OR_GAME_CLOCK_INVALID');
 const t=Date.parse(gameClockUtc),start=Date.parse(plan.scheduledDepartureUtc),
  done=Date.parse(plan.plannedCompletionUtc);
 let state='scheduled',phase=null,secondsIntoPhase=0,projectedBurnKg=0;
 if(t>=done){
  state='forecast_complete';
  projectedBurnKg=plan.fuel.tripFuelKg;
 }else if(t>=start){
  state='forecast_in_progress';
  for(const stage of plan.phases){
   const a=Date.parse(stage.scheduledStartUtc),
    b=Date.parse(stage.scheduledEndUtc);
   if(t>=b){projectedBurnKg+=stage.fuelBudgetKg;continue;}
   if(t>=a&&t<b){
    phase=stage.key;secondsIntoPhase=(t-a)/1000;
    if(stage.durationSeconds>0)
     projectedBurnKg+=stage.fuelBudgetKg*(secondsIntoPhase/stage.durationSeconds);
    break;
   }
  }
 }
 return Object.freeze({
  status:'FLIGHT_PHASE_PROJECTION',
  flightOccurrenceId:plan.flightOccurrenceId,
  gameClockUtc,state,phase,secondsIntoPhase,
  projectedFuelBurnKg:round(projectedBurnKg),
  projectedFuelRemainingFromScreeningLoadKg:
   round(Math.max(0,plan.fuel.screeningFuelLoadKg-projectedBurnKg)),
  simulatedOnly:true,
  actualDepartureVerified:false,actualArrivalVerified:false,
  movementRecorded:false,ledgerPosted:false,tankUpdated:false
 });
}
