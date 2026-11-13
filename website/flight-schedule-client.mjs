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
   const conflict=Error('SCHEDULE_CONFLICT_'+label.replace(/[^A-Z0-9_]/gi,'_').slice(0,120));
   if(payload.action==='operational-create'&&Array.isArray(reason.blockingRequirements))
    conflict.operationalBlockers=reason.blockingRequirements.filter(x=>
      typeof x==='string'&&/^[A-Z][A-Z0-9_]{3,100}$/.test(x)).slice(0,16);
   if(payload.action==='operational-create'&&
      reason.gameAirportRestrictionFindings?.readOnly===true&&
      reason.gameAirportRestrictionFindings?.operationApproved===false){
    const safeSide=side=>
     side&&/^[A-Z0-9]{3,4}$/.test(side.airportCode||'')?
      {airportCode:side.airportCode,
       runway:typeof side.runway==='string'&&/^[0-9]{1,2}[LRC]?\/[0-9]{1,2}[LRC]?$/.test(side.runway)?
        side.runway:null,
       runwayOperationalStatusVerified:side.runwayOperationalStatusVerified===true,
       aircraftChapterMatched:side.aircraftChapterMatched===true,
       anyHardTimeRuleBlock:side.anyHardTimeRuleBlock===true}:null;
    const findings=reason.gameAirportRestrictionFindings;
    conflict.operationalAirportFindings={
     origin:safeSide(findings.origin),
     destination:safeSide(findings.destination)
    };
   }
   if(payload.action==='operational-create'&&
      reason.gameModelEvidenceType==='GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE'&&
      typeof reason.gameModelPreliminarySuitable==='boolean')
    conflict.gameModelPreliminarySuitable=reason.gameModelPreliminarySuitable;
   throw conflict;
  }
  if(!response.ok)throw Error('SCHEDULE_HTTP_'+String(response.status));
  const data=await response.json();
  if(!data||typeof data!=='object'||Array.isArray(data))throw Error('Invalid schedule response');
  return data;
 }
 return Object.freeze({
  list:airlineId=>post({action:'list',airlineId}),
  commissioningStatus:({airlineId,aircraftInventoryId})=>
    post({action:'commissioning-status',airlineId,aircraftInventoryId}),
  commissioningRequest:({airlineId,aircraftInventoryId})=>
    post({action:'commissioning-request',airlineId,aircraftInventoryId}),
  maintenanceJobStatus:({airlineId,aircraftInventoryId})=>
    post({action:'maintenance-job-status',airlineId,aircraftInventoryId}),
  maintenanceJobBook:({airlineId,aircraftInventoryId,checkCode})=>
    post({action:'maintenance-job-book',airlineId,aircraftInventoryId,checkCode}),
  maintenanceJobCancel:({airlineId,aircraftInventoryId})=>
    post({action:'maintenance-job-cancel',airlineId,aircraftInventoryId}),
  operationalCreate:({airlineId,aircraftInventoryId,flightNumber,originAirportKey,
   destinationAirportKey,weeklySchedule,departureStand=null,arrivalStand='terminal',
   turnaroundMinutes,fares,service,launchDelayDays=0,
   referenceDepartureUtc=null,referenceArrivalUtc=null})=>
    post({action:'operational-create',airlineId,aircraftInventoryId,flightNumber,
     originAirportKey,destinationAirportKey,weeklySchedule,departureStand,
     arrivalStand,turnaroundMinutes,fares,service,launchDelayDays,
     referenceDepartureUtc,referenceArrivalUtc}),

  planSave:({airlineId,aircraftInventoryId,flightNumber,originAirportKey,
   destinationAirportKey,weeklySchedule,departureStand=null,arrivalStand='terminal',
   turnaroundMinutes,fares,service,launchDelayDays=0,
   referenceDepartureUtc=null,referenceArrivalUtc=null})=>
    post({action:'plan-save',airlineId,aircraftInventoryId,flightNumber,
     originAirportKey,destinationAirportKey,weeklySchedule,departureStand,
     arrivalStand,turnaroundMinutes,fares,service,launchDelayDays,
     referenceDepartureUtc,referenceArrivalUtc}),

  planDelete:({airlineId,planId})=>
   post({action:'plan-delete',airlineId,planId}),
  save:({airlineId,aircraftInventoryId,flightNumber,originAirportKey,destinationAirportKey,
   referenceDepartureUtc,referenceArrivalUtc,weeklySchedule,existingId,
   departureStand='terminal',arrivalStand='terminal'})=>
    post({action:'save',airlineId,aircraftInventoryId,flightNumber,originAirportKey,
     destinationAirportKey,referenceDepartureUtc,referenceArrivalUtc,weeklySchedule,
     departureStand,arrivalStand,...(existingId?{existingId}:{})}),
  slotCheck:({airlineId,aircraftInventoryId,originAirportKey,destinationAirportKey,
   referenceDepartureUtc,referenceArrivalUtc,weeklySchedule,existingId,
   departureStand='terminal',arrivalStand='terminal'})=>
    post({action:'slot-check',airlineId,aircraftInventoryId,originAirportKey,
     destinationAirportKey,referenceDepartureUtc,referenceArrivalUtc,weeklySchedule,
     departureStand,arrivalStand,...(existingId?{existingId}:{})}),
  demandPreview:({airlineId,scheduleId,month})=>
    post({action:'demand-preview',airlineId,scheduleId,month}),
  commercialRead:({airlineId,scheduleId})=>
    post({action:'commercial-read',airlineId,scheduleId}),
  feePreview:({airlineId,aircraftInventoryId,originAirportKey,destinationAirportKey,
   departureStand='terminal',arrivalStand='terminal',parkingMinutes=60})=>
    post({action:'fee-preview',airlineId,aircraftInventoryId,originAirportKey,
     destinationAirportKey,departureStand,arrivalStand,parkingMinutes}),
  routeFinancials:({airlineId,scheduleId,loadPercent=100,parkingMinutes=180})=>
    post({action:'route-financials',airlineId,scheduleId,loadPercent,parkingMinutes}),
  commercialSave:({airlineId,scheduleId,economyFareUsd,
   cargoRateUsdPerTonne,marketingBudgetUsdPerDay})=>
    post({action:'commercial-save',airlineId,scheduleId,
     economyFareUsd,cargoRateUsdPerTonne,marketingBudgetUsdPerDay}),
  partnerList:airlineId=>post({action:'partner-list',airlineId}),
  partnerPropose:({airlineId,otherAirlineCode})=>
    post({action:'partner-propose',airlineId,
     otherAirlineCode:String(otherAirlineCode||'').toUpperCase().trim()}),
  partnerDecision:({airlineId,agreementId,decision})=>
    post({action:'partner-decision',airlineId,agreementId,decision}),
  bookingWindowPreview:({airlineId,scheduleId})=>
    post({action:'booking-window-preview',airlineId,scheduleId}),
  rotationPreview:({airlineId,scheduleId,startDate,days=28})=>
    post({action:'rotation-preview',airlineId,scheduleId,startDate,days}),
  operationsPreview:({airlineId,scheduleId,startDate,days=28})=>
    post({action:'operations-preview',airlineId,scheduleId,startDate,days}),
  crewRoster:({airlineId,scheduleId})=>
    post({action:'crew-roster',airlineId,scheduleId}),
  crewOffers:({airlineId,scheduleId})=>
    post({action:'crew-offers',airlineId,scheduleId}),
  crewHire:({airlineId,scheduleId,candidateSlot})=>
    post({action:'crew-hire',airlineId,scheduleId,candidateSlot}),
  crewSalary:({airlineId})=>post({action:'crew-salary',airlineId}),
  crewPlan:({airlineId,scheduleId,crewId,weeklyEntry,decision})=>
    post({action:'crew-plan',airlineId,scheduleId,crewId,weeklyEntry,decision}),
  activationCheck:({airlineId,scheduleId})=>post({action:'activation-check',airlineId,scheduleId}),
  delete:({airlineId,scheduleId})=>post({action:'delete',airlineId,scheduleId})
 });
}
