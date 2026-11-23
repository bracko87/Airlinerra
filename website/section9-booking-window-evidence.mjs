/** Validate owner-scoped game booking evidence before rendering Route Details.
 * This cannot issue bookings, certify availability or authorize operations.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ISO_DATE=/^\d{4}-\d{2}-\d{2}$/;
const validInt=n=>Number.isSafeInteger(n)&&n>=0;
const validMoney=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
const parseUtc=s=>{
 if(typeof s!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(s))return null;
 const ms=Date.parse(s);
 return Number.isFinite(ms)?ms:null;
};
export function summarizeOwnedBookingWindow(data,{scheduleId}={}){
 if(!UUID.test(scheduleId||'')||data?.status!=='operating_booking_window'||
  data.readOnly!==true||data.scheduleId!==scheduleId||
  !Array.isArray(data.occurrences)||data.occurrences.length>7)return null;
 const rows=[],seen=new Set();let prior=-Infinity;
 for(const item of data.occurrences){
  if(!item||!ISO_DATE.test(item.flightDate||'')||
   !validInt(item.capacity)||item.capacity<1||item.capacity>1000||
   !validInt(item.bookedSeats)||item.bookedSeats>item.capacity||
   !validMoney(item.reservedTicketRevenueUsd)||
   typeof item.bookingStatus!=='string'||!/^[-_a-z]{2,64}$/.test(item.bookingStatus))return null;
  const dep=parseUtc(item.departureUtc),arr=parseUtc(item.arrivalUtc);
  if(dep===null||arr===null||arr<=dep||dep<prior||seen.has(dep))return null;
  seen.add(dep);prior=dep;
  rows.push(Object.freeze({
   flightDate:item.flightDate,
   departureUtc:new Date(dep).toISOString(),
   arrivalUtc:new Date(arr).toISOString(),
   bookingStatus:item.bookingStatus.replaceAll('_',' '),
   capacity:item.capacity,bookedSeats:item.bookedSeats,
   unbookedSeats:item.capacity-item.bookedSeats,
   reservedRevenueUsd:item.reservedTicketRevenueUsd
  }));
 }
 return Object.freeze({rows:Object.freeze(rows),totalBooked:rows.reduce((a,r)=>a+r.bookedSeats,0),
  totalCapacity:rows.reduce((a,r)=>a+r.capacity,0),
  totalReservedRevenueUsd:rows.reduce((a,r)=>a+r.reservedRevenueUsd,0),
  readOnly:true});
}
