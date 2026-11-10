/**
 * Airlinerra Section 9 -> fuel phase calculation integration contract.
 *
 * READ-ONLY dry-run adapter. No DB writes, dispatch activation or charges.
 * The caller MUST obtain movementReceipt directly from the private signed
 * movement ingress AFTER the database commits an arrival. Never accept a
 * movement receipt directly from a browser or player.
 *
 * A future settlement adapter must perform one atomic transaction keyed by
 * flightOccurrenceId, reconcile tank fuel/airport uplift and never rely on
 * a provisional game-tier price as an invoice.
 */
import {estimateFivePhaseFuel} from '../website/flight-fuel-phase-engine.mjs';
import {planSection9FivePhaseFlight} from './section9-flight-phase-timeline.mjs';
import {previewAirportFuelPrice} from '../website/airport-fuel-price-preview.mjs';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const expectedOccurrence=e=>e.scheduleId+':'+e.flightLocalDate+':'+e.weeklyEntry;
const expectedEventId=e=>'operate-v1.'+e.scheduleId.replaceAll('-','').toLowerCase()+'.'+
 e.flightLocalDate.replaceAll('-','')+'.'+e.weeklyEntry+'.arrived';
const unavailable=reason=>Object.freeze({status:'FUEL_BRIDGE_BLOCKED',
 reason,flightActivated:false,ledgerPosted:false,refuellingPosted:false,
 flightFuelWritten:false,financialSettlementAuthorized:false});

export function inspectVerifiedArrivalForFuel({
 movementReceipt,movementEvent,aircraft,route,departureAirport,payloadFraction=.5
}={}){
 if(!movementEvent||!UUID.test(movementEvent.airlineId||'')||
  !UUID.test(movementEvent.scheduleId||'')||
  !DAY.test(movementEvent.flightLocalDate||'')||
  !Number.isInteger(movementEvent.weeklyEntry)||
  movementEvent.weeklyEntry<1||movementEvent.weeklyEntry>7||
  movementEvent.worldId!==1||movementEvent.phase!=='arrived'||
  movementEvent.eventId!==expectedEventId(movementEvent))
  return unavailable('NO_TRUSTED_ARRIVAL_EVENT');
 const occurrence=expectedOccurrence(movementEvent);
 if(!movementReceipt||
  movementReceipt.status!=='operated_flight_arrival_recorded'||
  movementReceipt.phase!=='arrived'||
  movementReceipt.flightOccurrenceId!==occurrence||
  movementReceipt.movementRecorded!==true||
  movementReceipt.replayed!==false||
  movementReceipt.locationStatus!=='grounded'||
  movementReceipt.canActivateNormalFlight!==false||
  movementReceipt.flightActivated!==false||
  movementReceipt.ledgerPosted!==false||
  movementReceipt.bookingsCreated!==false)
  return unavailable('ARRIVAL_NOT_CONFIRMED_BY_MOVEMENT_INGRESS');
 if(!aircraft||aircraft.airlineId!==movementEvent.airlineId||
  !UUID.test(aircraft.id||'')||
  !Number.isInteger(Number(aircraft.configurationId))||
  typeof aircraft.fuelFamily!=='string'||
  !route||route.scheduleId!==movementEvent.scheduleId||
  route.airlineId!==movementEvent.airlineId||
  route.aircraftInventoryId!==aircraft.id||
  typeof route.originAirportKey!=='string'||
  typeof route.destinationAirportKey!=='string'||
  route.originAirportKey===route.destinationAirportKey||
  typeof route.distanceKm!=='number'||route.distanceKm<=0)
  return unavailable('SCHEDULE_AIRCRAFT_OR_AIRLINE_MISMATCH');
 if(movementReceipt.lastVerifiedAirport!==route.destinationAirportKey)
  return unavailable('AIRCRAFT_DESTINATION_NOT_CONFIRMED');
 if(!departureAirport||departureAirport.key!==route.originAirportKey)
  return unavailable('DEPARTURE_FUEL_AIRPORT_NOT_VERIFIED');
 const price=previewAirportFuelPrice(departureAirport,{
  fuelFamily:aircraft.fuelFamily
 });
 const fuel=estimateFivePhaseFuel({
  distanceKm:route.distanceKm,
  cruiseSpeedKmh:aircraft.cruiseSpeedKmh,
  cruiseFuelKgPerHour:aircraft.cruiseFuelKgPerHour,
  emptyFuelKgPer100Km:aircraft.emptyFuelKgPer100Km,
  halfFuelKgPer100Km:aircraft.halfFuelKgPer100Km,
  fullFuelKgPer100Km:aircraft.fullFuelKgPer100Km,
  fuelTankCapacityKg:aircraft.fuelTankCapacityKg,
  priceUsdPerKg:price.usdPerKg,
  payloadFraction
 });
 if(fuel.status!=='PLANNING_ESTIMATE')
  return unavailable('AIRCRAFT_FUEL_REFERENCE_INCOMPLETE');
 // An optional, server-owned schedule timestamp enriches the arrival audit
 // with a five-phase reference. It cannot certify an actual operation.
 let projectedTimeline=null;
 if(Object.hasOwn(route,'scheduledDepartureUtc')){
  const projection=planSection9FivePhaseFlight({
   airlineId:movementEvent.airlineId,
   aircraftInventoryId:aircraft.id,scheduleId:movementEvent.scheduleId,
   flightLocalDate:movementEvent.flightLocalDate,
   weeklyEntry:movementEvent.weeklyEntry,
   scheduledDepartureUtc:route.scheduledDepartureUtc,
   originAirportKey:route.originAirportKey,
   destinationAirportKey:route.destinationAirportKey,
   distanceKm:route.distanceKm,aircraft,payloadFraction,
   fuelPriceUsdPerKg:price.usdPerKg
  });
  if(projection.status!=='FLIGHT_PHASE_DRY_RUN_PLAN')
   return unavailable('PHASE_TIMELINE_SOURCE_INVALID');
  projectedTimeline=projection;
 }
 return Object.freeze({
  status:'ARRIVAL_FUEL_DRY_RUN_READY',
  flightOccurrenceId:occurrence,
  worldId:1,airlineId:movementEvent.airlineId,
  aircraftInventoryId:aircraft.id,scheduleId:movementEvent.scheduleId,
  fuel,price,projectedTimeline,
  source:'VERIFIED_SIGNED_MOVEMENT_ARRIVAL_REQUIRED',
  idempotencyCandidate:'fuel:'+occurrence,
  flightActivated:false,ledgerPosted:false,refuellingPosted:false,
  flightFuelWritten:false,financialSettlementAuthorized:false
 });
}
