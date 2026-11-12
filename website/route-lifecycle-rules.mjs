/**
 * Airlinerra route lifecycle POLICY (read-only planning).
 * This module does not create flights, accept passenger payments, reserve
 * airport slots, release capacity, or post a financial transaction.
 * All dates must be server-authoritative GAME dates, never browser Date.now().
 */
export const ROUTE_BOOKING_WINDOW_GAME_DAYS=7;
export const LATE_CANCELLATION_HOURS=48;
export const ROUTE_LAUNCH_DELAY_GAME_DAYS=Object.freeze([0,3,7]);
export const ROUTE_CANCELLATION_MODES=Object.freeze([
 'single-occurrence','all-upcoming','finish-seven-day-window'
]);
export const routeLaunchDelay=value=>
 ROUTE_LAUNCH_DELAY_GAME_DAYS.includes(value)?value:null;

/** A sale window is seven complete game days starting on the booking date. */
export function gameFlightBookingWindow(gameDay){
 if(!Number.isSafeInteger(gameDay)||gameDay<0)return null;
 return Object.freeze({opensGameDay:gameDay,
  latestDepartureGameDay:gameDay+ROUTE_BOOKING_WINDOW_GAME_DAYS});
}

/** Day-only cancellation planning; live engine must operate on dated flight IDs.
 * 'finish-seven-day-window' means STOP new sales beyond the current window,
 * fly existing saleable occurrences through day +7, then retire the route.
 * Immediate cancellation affects the next unoperated flight and all future.
 */
export function previewRouteCancellation({gameDay,mode,occurrences=[],
 selectedOccurrenceId=null}={}){
 if(!Number.isSafeInteger(gameDay)||gameDay<0||
  !ROUTE_CANCELLATION_MODES.includes(mode)||!Array.isArray(occurrences)||
  occurrences.length>1000)return null;
 const valid=occurrences.every(o=>o&&typeof o.id==='string'&&o.id.length>0&&
  Number.isSafeInteger(o.gameDay)&&o.gameDay>=0&&
  ['planned','on_sale','booked','completed','cancelled'].includes(o.status)&&
  Number.isSafeInteger(o.bookingCount)&&o.bookingCount>=0);
 if(!valid)return null;
 const impacted=occurrences.filter(o=>{
  if(o.gameDay<gameDay||['completed','cancelled'].includes(o.status))return false;
  if(mode==='single-occurrence')return o.id===selectedOccurrenceId;
  if(mode==='all-upcoming')return true;
  return o.gameDay>gameDay+ROUTE_BOOKING_WINDOW_GAME_DAYS;
 });
 const protectedPassengers=impacted.reduce((sum,o)=>sum+o.bookingCount,0);
 return Object.freeze({
  mode,affectedFlightIds:impacted.map(o=>o.id),protectedPassengers,
  // This function never discharges a passenger or releases an airport slot.
  safeToExecute:false,requiresPassengerReaccommodation:protectedPassengers>0,
  reason:'Preview only: booking, re-accommodation, slot release and finance are not connected.'
 });
}

/** Extra cancellation handling is tied to 48 hours, NOT the entitlement to
 * assistance. Every confirmed booking within the 7-day horizon is protected. */
export function passengerProtectionStatus({hasBooking,hoursUntilDeparture}={}){
 if(typeof hasBooking!=='boolean'||typeof hoursUntilDeparture!=='number'||
  !Number.isFinite(hoursUntilDeparture))return null;
 if(!hasBooking)return {protected:false,urgent:false};
 return {protected:true,
  urgent:hoursUntilDeparture>=0&&hoursUntilDeparture<=LATE_CANCELLATION_HOURS};
}
