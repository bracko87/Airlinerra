/**
 * PRIVATE certification orchestration for two saved reciprocal schedules.
 * This service does NOT grant licences, create permissions, activate schedules,
 * open tickets or settle money. Existing independent issuer instances retain
 * separate private HMAC secrets and database source-proof validation.
 *
 * All five existing authorities may certify each leg. Certification alone
 * never authorizes activation: the existing transactional pair gate does that.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TYPES=Object.freeze([
 'operator_licence','route_traffic_rights','airport_slot_capacity'
]);
const MISSING=Object.freeze(['trusted_flight_execution','commercial_finance']);
const allTypes=Object.freeze([...TYPES,...MISSING]);
const validDay=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&
 !Number.isNaN(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const closed=(status,results=[],sourceInspections=[])=>Object.freeze({
 status,readOnly:false,certificationComplete:false,
 scheduleActivated:false,flightActivated:false,bookingsCreated:false,
 ledgerPosted:false,confirmedCertificates:results.length,
 verifiedClearances:results,
 sourceInspections:Object.freeze(sourceInspections),
 remainingClearanceTypes:[...MISSING]
});
export function createSection9RoundtripCertificationCoordinator({
 operatorIssuer,routeRightsIssuer,slotIssuer,executionFinanceSourceReader,
 executionIssuer,financeIssuer
}={}){
 if(operatorIssuer?.clearanceType!=='operator_licence'||
  typeof operatorIssuer.verifyAndCertify!=='function'||
  routeRightsIssuer?.clearanceType!=='route_traffic_rights'||
  typeof routeRightsIssuer.verifyAndCertify!=='function'||
  slotIssuer?.clearanceType!=='airport_slot_capacity'||
  typeof slotIssuer.certifyCurrentSlotReservation!=='function')
  throw Error('SECTION9_THREE_INDEPENDENT_CERTIFICATION_ISSUERS_REQUIRED');
 if(executionFinanceSourceReader!==undefined&&
  typeof executionFinanceSourceReader?.inspect!=='function')
  throw Error('SECTION9_PRIVATE_EXECUTION_FINANCE_SOURCE_READER_REQUIRED');
 const full=executionIssuer!==undefined||financeIssuer!==undefined;
 if(full&&(
  executionIssuer?.clearanceType!=='trusted_flight_execution'||
  typeof executionIssuer.verifyAndCertify!=='function'||
  financeIssuer?.clearanceType!=='commercial_finance'||
  typeof financeIssuer.verifyAndCertify!=='function'))
  throw Error('SECTION9_BOTH_EXECUTION_FINANCE_ISSUERS_REQUIRED');
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
   // Both newer authorities use the existing signed ingress and atomic SQL
   // source recheck. The old diagnostic-only mode remains fail-closed.
   if(full){
    const outstanding=()=>allTypes.filter(type=>legs.some(leg=>
     !results.some(r=>r.scheduleId===leg.scheduleId&&r.clearanceType===type)));
    const incomplete=(status)=>Object.freeze({
     ...closed(status,results),remainingClearanceTypes:outstanding()
    });
    for(const leg of legs){
     for(const [type,issuer] of [
      ['trusted_flight_execution',executionIssuer],
      ['commercial_finance',financeIssuer]
     ]){
      let response;
      try{response=await issuer.verifyAndCertify({airlineId,...leg,gameDate});}
      catch{return incomplete('roundtrip_independent_certification_failed');}
      if(!response||response.scheduleId!==leg.scheduleId||
       response.clearanceType!==type||
       !['certification_event_recorded','certification_event_replayed'].includes(response.status)||
       response.flightActivated!==false||response.movementRecorded!==false||
       response.bookingsCreated!==false||response.ledgerPosted!==false||
       (response.status==='certification_event_recorded'?
        response.certificateIssued!==true:response.replayed!==true))
       return incomplete('roundtrip_independent_certification_blocked');
      results.push(Object.freeze({
       scheduleId:leg.scheduleId,clearanceType:type,status:response.status
      }));
     }
    }
    return Object.freeze({
     ...closed('roundtrip_all_five_clearance_types_verified_per_leg',results),
     certificationComplete:true,remainingClearanceTypes:[]
    });
   }
   // Inspect the two additional sources independently for EACH leg.
   // These are deliberately NOT certificate issuers and can never finish
   // the activation. Source inspectors only report why proofs are missing.
   const inspections=[];
   if(executionFinanceSourceReader){
    for(const leg of legs){
     for(const clearanceType of MISSING){
      let response;
      try{
       response=await executionFinanceSourceReader.inspect({
        airlineId,...leg,gameDate,clearanceType
       });
      }catch{
       return closed('roundtrip_future_source_inspection_failed',
        results,inspections);
      }
      if(!response||response.scheduleId!==leg.scheduleId||
        response.clearanceType!==clearanceType||
        response.sourceAuthorityReleased!==false||
        response.certificateIssued!==false||
        response.certificationComplete!==false||
        response.scheduleActivated!==false||
        response.flightActivated!==false||
        response.bookingsCreated!==false||
        response.ledgerPosted!==false||
        !Array.isArray(response.blockers))
       return closed('roundtrip_future_source_inspection_untrusted',
        results,inspections);
      inspections.push(Object.freeze({
       scheduleId:leg.scheduleId,clearanceType,status:response.status,
       blockers:Object.freeze([...response.blockers])
      }));
     }
    }
   }
   // 6 existing signed clearances can be recorded, but the other 4
   // must be independently issued and rechecked in the SQL sink.
   return closed('roundtrip_three_of_five_clearance_types_verified_per_leg',
     results,inspections);
  }
 });
}
export const SECTION9_ROUNDTRIP_EXISTING_AUTHORITIES=TYPES;
export const SECTION9_ROUNDTRIP_REQUIRED_AUTHORITIES=allTypes;
