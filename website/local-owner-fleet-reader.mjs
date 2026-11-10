/** Safe localhost preview reader for actual company-owned/leased fleet.
 * This uses the signed-in session and the protected same-origin proxy.
 * The proxy forwards only read-only 'list' and 'slot-check' actions.
 * All acquisition, cancellation, delivery, schedule creation and payments
 * remain unavailable in localhost preview.
 */
const LOCAL_ORIGIN='http://localhost:5188';
const FLEET_PATH='/api/v1/player/fleet-acquisition';
const SCHEDULE_PATH='/api/v1/player/flight-schedule-drafts';
export function createLocalOwnerFleetReaders({auth,origin,fetchImpl=globalThis.fetch}={}){
 if(origin!==LOCAL_ORIGIN||typeof auth?.getAccessToken!=='function'||
    typeof fetchImpl!=='function')throw Error('Verified localhost session required');
 async function read(path,body){
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)throw Error('Verified session required');
  const response=await fetchImpl(LOCAL_ORIGIN+path,{
   method:'POST',headers:{authorization:'Bearer '+token,'content-type':'application/json'},
   body:JSON.stringify(body),mode:'same-origin',credentials:'omit',
   cache:'no-store',redirect:'error',referrerPolicy:'no-referrer'
  });
  if(!response.ok)throw Error('LOCAL_AIRCRAFT_READ_HTTP_'+response.status);
  const result=await response.json();
  if(!result||typeof result!=='object'||Array.isArray(result))
   throw Error('Invalid airline aircraft response');
  return result;
 }
 const fleetClient=Object.freeze({
  list:airlineId=>read(FLEET_PATH,{action:'list',airlineId})
 });
 const scheduler=Object.freeze({
  list:airlineId=>read(SCHEDULE_PATH,{action:'list',airlineId}),
  slotCheck:args=>read(SCHEDULE_PATH,{action:'slot-check',
   airlineId:args?.airlineId,aircraftInventoryId:args?.aircraftInventoryId,
   originAirportKey:args?.originAirportKey,
   destinationAirportKey:args?.destinationAirportKey,
   referenceDepartureUtc:args?.referenceDepartureUtc,
   referenceArrivalUtc:args?.referenceArrivalUtc,
   weeklySchedule:args?.weeklySchedule,
   departureStand:args?.departureStand||'terminal',
   arrivalStand:args?.arrivalStand||'terminal',
   ...(args?.existingId?{existingId:args.existingId}:{})
  })
 });
 return Object.freeze({fleetClient,scheduler});
}
