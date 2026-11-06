/**
 * Authenticated server-owned flight schedule drafts for operational inventory.
 * This is not a live flight activation API. Catalog previews remain local only.
 */
export const FLIGHT_SCHEDULE_API_ROUTE='/api/v1/player/flight-schedule-drafts';
export function createFlightScheduleClient({auth,origin,fetchImpl=(...args)=>fetch(...args)}={}){
 if(origin!=='https://airlinerra.com'||typeof auth?.getAccessToken!=='function'||
    typeof fetchImpl!=='function')throw Error('Verified production flight schedule client required');
 async function post(payload){
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)throw Error('Verified session required');
  const response=await fetchImpl(origin+FLIGHT_SCHEDULE_API_ROUTE,{
   method:'POST',
   headers:{'content-type':'application/json',authorization:'Bearer '+token},
   body:JSON.stringify(payload),
   cache:'no-store',redirect:'error',credentials:'omit',mode:'same-origin',referrerPolicy:'no-referrer'
  });
  if(response.status===401)throw Error('SCHEDULE_AUTH_REQUIRED');
  if(response.status===403)throw Error('SCHEDULE_AIRLINE_NOT_OWNED');
  if(response.status===409){
   const reason=await response.json().catch(()=>({}));
   const label=typeof reason.reason==='string'?reason.reason:
    typeof reason.error==='string'?reason.error:'SCHEDULE_RESTRICTION_BLOCKED';
   throw Error('SCHEDULE_CONFLICT_'+label.replace(/[^A-Z0-9_]/gi,'_').slice(0,120));
  }
  if(!response.ok)throw Error('SCHEDULE_HTTP_'+String(response.status));
  const data=await response.json();
  if(!data||typeof data!=='object'||Array.isArray(data))throw Error('Invalid schedule response');
  return data;
 }
 return Object.freeze({
  list:airlineId=>post({action:'list',airlineId}),
  save:({airlineId,aircraftInventoryId,flightNumber,originAirportKey,destinationAirportKey,
   referenceDepartureUtc,referenceArrivalUtc,weeklySchedule,existingId})=>
    post({action:'save',airlineId,aircraftInventoryId,flightNumber,originAirportKey,
     destinationAirportKey,referenceDepartureUtc,referenceArrivalUtc,
     weeklySchedule,...(existingId?{existingId}:{})}),
  activationCheck:({airlineId,scheduleId})=>post({action:'activation-check',airlineId,scheduleId}),
  delete:({airlineId,scheduleId})=>post({action:'delete',airlineId,scheduleId})
 });
}
