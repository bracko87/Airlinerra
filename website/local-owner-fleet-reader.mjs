/** Safe localhost preview reader for actual company-owned/leased fleet.
 * This uses the signed-in session and the protected same-origin proxy.
 * The proxy forwards reads, owner-verified planning drafts and non-binding refit quotes.
 * All acquisition, cancellation, delivery, slot reservation, flight activation and payments
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
  if(response.status===409&&path===SCHEDULE_PATH){
   const error=await response.json().catch(()=>null);
   const reason=typeof error?.reason==='string'&&
    /^[A-Z][A-Z0-9_]{2,100}$/.test(error.reason)?
     error.reason:'SCHEDULE_RESTRICTION_BLOCKED';
   const conflict=Error('SCHEDULE_CONFLICT_'+reason);
   if(body?.action==='operational-create'&&Array.isArray(error?.blockingRequirements))
    conflict.operationalBlockers=error.blockingRequirements.filter(x=>
     typeof x==='string'&&/^[A-Z][A-Z0-9_]{3,100}$/.test(x)).slice(0,16);
   throw conflict;
  }
  if(!response.ok)throw Error('LOCAL_AIRLINERRA_API_HTTP_'+response.status);
  const result=await response.json();
  if(!result||typeof result!=='object'||Array.isArray(result))
   throw Error('Invalid airline aircraft response');
  return result;
 }
 const fleetClient=Object.freeze({
  list:airlineId=>read(FLEET_PATH,{action:'list',airlineId}),
  listUsed:({airlineId,page=0,filterMode='all',search='',manufacturer='',family='',model='',configuration=''})=>
   read(FLEET_PATH,{action:'list-used',airlineId,page,filterMode,search,manufacturer,family,model,configuration}),
  // Same owner-verified individual-airframe detail as the production client.
  // Never allow localhost to place bids, purchase or modify the used aircraft.
  usedDetail:({airlineId,listingId})=>read(FLEET_PATH,{action:'used-detail',airlineId,listingId}),
  cabinOverview:airlineId=>read(FLEET_PATH,{action:'cabin-overview',airlineId}),
  saveCabinDraft:layout=>read(FLEET_PATH,{action:'cabin-save-draft',...layout}),
  prepareCabinRefitQuote:details=>read(FLEET_PATH,{action:'cabin-prepare-quote',...details}),
  cabinRefitQuoteStatus:({airlineId,aircraftInventoryId})=>
   read(FLEET_PATH,{action:'cabin-quote-status',airlineId,aircraftInventoryId}),
  maintenancePreview:({airlineId,aircraftInventoryId})=>
   read(FLEET_PATH,{action:'maintenance-preview',airlineId,aircraftInventoryId}),
  updateNickname:({airlineId,aircraftInventoryId,nickname})=>
   read(FLEET_PATH,{action:'update-nickname',airlineId,aircraftInventoryId,nickname})
 });
 const scheduler=Object.freeze({
  list:airlineId=>read(SCHEDULE_PATH,{action:'list',airlineId}),
  operationalCreate:({airlineId,aircraftInventoryId,flightNumber,originAirportKey,
   destinationAirportKey,weeklySchedule,departureStand=null,arrivalStand='terminal',
   turnaroundMinutes,fares,service,launchDelayDays=0,
   referenceDepartureUtc=null,referenceArrivalUtc=null})=>
    read(SCHEDULE_PATH,{action:'operational-create',airlineId,aircraftInventoryId,
     flightNumber,originAirportKey,destinationAirportKey,weeklySchedule,
     departureStand,arrivalStand,turnaroundMinutes,fares,service,launchDelayDays,
     referenceDepartureUtc,referenceArrivalUtc}),
  planSave:({airlineId,aircraftInventoryId,flightNumber,originAirportKey,
   destinationAirportKey,weeklySchedule,departureStand=null,arrivalStand='terminal',
   turnaroundMinutes,fares,service,launchDelayDays=0,
   referenceDepartureUtc=null,referenceArrivalUtc=null})=>
    read(SCHEDULE_PATH,{action:'plan-save',airlineId,aircraftInventoryId,
     flightNumber,originAirportKey,destinationAirportKey,weeklySchedule,
     departureStand,arrivalStand,turnaroundMinutes,fares,service,launchDelayDays,
     referenceDepartureUtc,referenceArrivalUtc}),
  feePreview:({airlineId,aircraftInventoryId,originAirportKey,destinationAirportKey,
   departureStand='terminal',arrivalStand='terminal',parkingMinutes=60})=>
    read(SCHEDULE_PATH,{action:'fee-preview',airlineId,aircraftInventoryId,
     originAirportKey,destinationAirportKey,departureStand,arrivalStand,parkingMinutes}),
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
