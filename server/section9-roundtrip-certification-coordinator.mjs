/**
 * PRIVATE certification orchestration for two saved reciprocal schedules.
 * This service does NOT grant licences, create permissions, activate schedules,
 * open tickets or settle money. Existing independent issuer instances retain
 * separate private HMAC secrets and database source-proof validation.
 *
 * Not complete operational authorization: trusted execution and commercial
 * finance authorities are separate and MUST still issue valid clearances.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TYPES=Object.freeze([
 'operator_licence','route_traffic_rights','airport_slot_capacity'
]);
const allTypes=Object.freeze([...TYPES,'trusted_flight_execution','commercial_finance']);
const validDay=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&
 !Number.isNaN(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const closed=(status,results=[])=>Object.freeze({
 status,readOnly:false,certificationComplete:false,
 scheduleActivated:false,flightActivated:false,bookingsCreated:false,
 ledgerPosted:false,confirmedCertificates:results.length,
 verifiedClearances:results,
 remainingClearanceTypes:['trusted_flight_execution','commercial_finance']
});
export function createSection9RoundtripCertificationCoordinator({
 operatorIssuer,routeRightsIssuer,slotIssuer
}={}){
 if(operatorIssuer?.clearanceType!=='operator_licence'||
  typeof operatorIssuer.verifyAndCertify!=='function'||
  routeRightsIssuer?.clearanceType!=='route_traffic_rights'||
  typeof routeRightsIssuer.verifyAndCertify!=='function'||
  slotIssuer?.clearanceType!=='airport_slot_capacity'||
  typeof slotIssuer.certifyCurrentSlotReservation!=='function')
  throw Error('SECTION9_THREE_INDEPENDENT_CERTIFICATION_ISSUERS_REQUIRED');
 return Object.freeze({
  async certifyPreparedPair({
   airlineId,outboundScheduleId,returnScheduleId,
   outboundVersion,returnVersion,gameDate
  }={}){
   if(!UUID.test(airlineId||'')||
     !UUID.test(outboundScheduleId||'')||
     !UUID.test(returnScheduleId||'')||
     outboundScheduleId===returnScheduleId||
     !Number.isInteger(outboundVersion)||outboundVersion<1||
     !Number.isInteger(returnVersion)||returnVersion<1||
     !validDay(gameDate)||gameDate<'2000-01-01'||gameDate>'2199-12-01')
    throw Error('SECTION9_INVALID_RECIPROCAL_CERTIFICATION_REQUEST');
   const results=[];
   const legs=[
    {scheduleId:outboundScheduleId,scheduleVersion:outboundVersion},
    {scheduleId:returnScheduleId,scheduleVersion:returnVersion}
   ];
   // Require source verification and signed receipt on BOTH separate
   // schedule identities; never reuse the outbound event for the return leg.
   for(const leg of legs){
    const request={airlineId,...leg,gameDate};
    for(const [type,issuer,method] of [
      ['operator_licence',operatorIssuer,'verifyAndCertify'],
      ['route_traffic_rights',routeRightsIssuer,'verifyAndCertify'],
      ['airport_slot_capacity',slotIssuer,'certifyCurrentSlotReservation']
    ]){
     let response;
     try{response=await issuer[method](request);}
     catch{
      return closed('roundtrip_independent_certification_failed',results);
     }
     if(!response||
      !['certification_event_recorded','certification_event_replayed']
       .includes(response.status)||
      response.scheduleId!==leg.scheduleId||
      response.flightActivated!==false||
      response.bookingsCreated!==false||
      response.ledgerPosted!==false||
      (type==='airport_slot_capacity'?
       response.slotCertificateIssued!==true&&response.replayed!==true:
       response.certificateIssued!==true&&response.replayed!==true))
      return closed('roundtrip_independent_certification_blocked',results);
     results.push(Object.freeze({
      scheduleId:leg.scheduleId,clearanceType:type,status:response.status
     }));
    }
   }
   // No final authorization without two ADDITIONAL independent proofs per
   // leg; this service deliberately has no activate/commit method.
   return closed('roundtrip_three_of_five_clearance_types_verified_per_leg',
     results);
  }
 });
}
export const SECTION9_ROUNDTRIP_EXISTING_AUTHORITIES=TYPES;
export const SECTION9_ROUNDTRIP_REQUIRED_AUTHORITIES=allTypes;
