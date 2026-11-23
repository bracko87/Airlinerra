/** Owner-scoped server schedule projection for My Routes.
 * A browser draft cannot authorize flight operation or booked seats.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FLIGHT=/^[A-Z0-9]{2}[0-9]{1,4}$/;
const airport=(key,hint)=>hint?.key===key?hint:{key,name:key};
const active=d=>d.status==='active'&&d.operationallyVerified===true;
export function projectOwnedScheduleRoutes({plans=[],schedules=[],local=[],fleet=[]}={}){
 const safePlans=Array.isArray(plans)?plans.filter(x=>x&&typeof x.flightNumber==='string'):[];
 const safeLocal=Array.isArray(local)?local.filter(x=>x&&typeof x.flightNumber==='string'):[];
 const out=[],used=new Set(),flightNumbers=new Set();
 const valid=Array.isArray(schedules)?schedules.filter(d=>d&&UUID.test(d.id||'')&&
  UUID.test(d.aircraftInventoryId||'')&&FLIGHT.test(d.flightNumber||'')&&
  typeof d.originAirportKey==='string'&&typeof d.destinationAirportKey==='string'&&
  d.originAirportKey!==d.destinationAirportKey&&
  Array.isArray(d.weeklySchedule)):[];
 // Server-owned schedule data is preferred over a potentially stale planning
 // record, and never inherits activation status from browser storage.
 for(const d of valid){
  if(used.has(d.id)||flightNumbers.has(d.flightNumber))continue;
  const p=safePlans.find(x=>x.serverScheduleId===d.id);
  const localMatch=safeLocal.find(x=>x.serverScheduleId===d.id||
   (x.flightNumber===d.flightNumber&&x.from?.key===d.originAirportKey&&
    x.to?.key===d.destinationAirportKey&&x.aircraftId==='owned:'+d.aircraftInventoryId));
  const source=p||localMatch;
  const inService=Array.isArray(fleet)?fleet.find(x=>x.id===d.aircraftInventoryId):null;
  out.push({
   ...(source||{}),
   flightNumber:d.flightNumber,
   serverScheduleId:d.id,
   serverPlanningId:p?.serverPlanningId||null,
   aircraftInventoryId:d.aircraftInventoryId,
   aircraftId:'owned:'+d.aircraftInventoryId,
   aircraftLabel:source?.aircraftLabel||inService?.registration||'Fleet aircraft',
   from:airport(d.originAirportKey,source?.from),
   to:airport(d.destinationAirportKey,source?.to),
   schedule:d.weeklySchedule,
   referenceDepartureUtc:d.referenceDepartureUtc||null,
   referenceArrivalUtc:d.referenceArrivalUtc||null,
   operation:{...(source?.operation||{}),departureStand:d.departureStand,
    arrivalStand:d.arrivalStand},
   slotsReserved:d.slotsReserved===true,
   operationallyVerified:active(d),
   status:active(d)?'active':'draft',
   storage:'server-schedule',
   serverScheduleVersion:d.version
  });
  used.add(d.id);flightNumbers.add(d.flightNumber);
 }
 for(const p of safePlans){
  if(flightNumbers.has(p.flightNumber))continue;
  // Planning-only results are not allowed to override the server list.
  out.push({...p,operationallyVerified:false,serverScheduleId:null,
   slotsReserved:false,status:'planning',storage:'server-planning'});
  flightNumbers.add(p.flightNumber);
 }
 for(const p of safeLocal){
  if(flightNumbers.has(p.flightNumber))continue;
  out.push({...p,operationallyVerified:false,slotsReserved:false,
   serverScheduleId:null,status:'planning',storage:'local-planning'});
  flightNumbers.add(p.flightNumber);
 }
 return out;
}
