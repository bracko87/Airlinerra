import test from 'node:test';
import assert from 'node:assert/strict';
import {createSection9RoundtripCertificationCoordinator,
 SECTION9_ROUNDTRIP_EXISTING_AUTHORITIES,
 SECTION9_ROUNDTRIP_REQUIRED_AUTHORITIES}
 from '../server/section9-roundtrip-certification-coordinator.mjs';
import {createSection9GamePermissionVerifierIssuer}
 from '../server/section9-game-permission-verifier-issuer.mjs';
import {createSection9GameSlotClearanceIssuer}
 from '../server/section9-game-slot-clearance-issuer.mjs';
import {createSection9SignedCertificationIngress}
 from '../server/section9-signed-certification-ingress.mjs';
const AIRLINE='11111111-1111-4111-8111-111111111111';
const OUT='44444444-4444-4444-8444-444444444444';
const BACK='55555555-5555-4555-8555-555555555555';
const DAY='2026-11-20';
const TO='2026-12-18';
const secret={
 operator_licence:'test-independent-licence-hmac-key-v1-000000001',
 route_traffic_rights:'test-independent-route-hmac-key-v1-000000002',
 airport_slot_capacity:'test-independent-slot-hmac-key-v1-00000000003'
};
const source={
 operator_licence:['verified_game_operator_licence','verified_game_licence_engine',
  'game-operator-licence-v1-','independent-game-licence-authority-v1'],
 route_traffic_rights:['verified_game_route_traffic_rights',
  'verified_game_traffic_rights_engine','game-route-rights-v1-',
  'independent-game-traffic-rights-v1'],
 airport_slot_capacity:['verified_game_airport_slots','verified_airport_slot_engine',
  'game-slot-capacity-v1-','independent-game-slot-authority-v1']
};
const pair={
 airlineId:AIRLINE,outboundScheduleId:OUT,returnScheduleId:BACK,
 outboundVersion:1,returnVersion:1,gameDate:DAY
};
function build({deny=null,replay=false,wrongIdentity=false}={}){
 const signatures=[],checks=[];
 const issuer=[];
 for(const type of SECTION9_ROUNDTRIP_EXISTING_AUTHORITIES){
  const ingressDb={async connect(){return {
   release(){},
   async query(sql,args){
    const event={type,scheduleId:args[1],eventId:args[5]};
    signatures.push(event);
    return {rowCount:1,rows:[{result:{
     status:replay?'certification_event_replayed':'certification_event_recorded',
     eventId:args[5],scheduleId:wrongIdentity?OUT:args[1],
     scheduleVersion:args[2],clearanceType:type,
     reviewStatus:'certified',replayed:replay,certificateChanged:!replay,
     activationPreparationInvalidated:true,
     flightActivated:false,movementRecorded:false,bookingsCreated:false,
     ledgerPosted:false
    }}]};
   }
  }}};
  const ingress=createSection9SignedCertificationIngress({
   database:ingressDb,clearanceType:type,verifierSecret:secret[type]});
  const authorityDb={async connect(){return {
   release(){},
   async query(sql,args){
    const [airlineId,scheduleId,scheduleVersion,gameDate]=args;
    checks.push({type,scheduleId,sql});
    if(deny?.type===type&&deny.scheduleId===scheduleId){
     const status=type==='airport_slot_capacity'?
      'blocked_slot_clearance_evidence':
      type==='operator_licence'?'blocked_game_operator_licence':
       'blocked_game_route_traffic_rights';
     return {rowCount:1,rows:[{result:{
      status,verified:false,readOnly:true,
      blockers:['TEST_DENIED_SOURCE'],
      flightActivated:false,movementRecorded:false,
      bookingsCreated:false,ledgerPosted:false
     }}]};
    }
    const fields=source[type];const fingerprint=scheduleId===OUT?'a'.repeat(32):'b'.repeat(32);
    return {rowCount:1,rows:[{result:{
     status:fields[0],verified:true,readOnly:true,
     worldId:1,airlineId,scheduleId,scheduleVersion,
     gameDate,validThroughGameDate:TO,
     clearanceType:type,sourceKind:fields[1],
     sourceReference:fields[2]+fingerprint,
     proofFingerprint:fingerprint,reviewerReference:fields[3],
     flightActivated:false,movementRecorded:false,
     bookingsCreated:false,ledgerPosted:false,
     ...(type==='operator_licence'?{gameLicenceOnly:true,jurisdictionIso2:'DE'}:{}),
     ...(type==='route_traffic_rights'?{
       gameRightsOnly:true,requiredServiceTypes:['passenger'],
       verifiedServiceTypes:1}:{}),
     ...(type==='airport_slot_capacity'?{
       proposedSlots:2,reservedSlots:2}:{})
    }}]};
   }
  }}};
  const instance=type==='airport_slot_capacity'?
   createSection9GameSlotClearanceIssuer({
    database:authorityDb,slotAuthoritySecret:secret[type],
    certificationIngress:ingress
   }):
   createSection9GamePermissionVerifierIssuer({
    database:authorityDb,clearanceType:type,
    verifierSecret:secret[type],certificationIngress:ingress
   });
  issuer.push(instance);
 }
 return {
  service:createSection9RoundtripCertificationCoordinator({
   operatorIssuer:issuer[0],routeRightsIssuer:issuer[1],slotIssuer:issuer[2]}),
  checks,signatures
 };
}
test('genuine independent issuer and signed ingress flow records three clearance types for each separate leg',async()=>{
 const b=build();const r=await b.service.certifyPreparedPair(pair);
 assert.equal(r.status,'roundtrip_three_of_five_clearance_types_verified_per_leg');
 assert.equal(r.confirmedCertificates,6);
 assert.equal(r.certificationComplete,false);
 assert.equal(r.scheduleActivated,false);
 assert.equal(r.bookingsCreated,false);
 assert.equal(r.ledgerPosted,false);
 assert.deepEqual(new Set(b.checks.map(x=>x.scheduleId)),new Set([OUT,BACK]));
 assert.deepEqual(new Set(b.signatures.map(x=>x.scheduleId)),new Set([OUT,BACK]));
 assert.equal(b.signatures.length,6);
 for(const scheduleId of [OUT,BACK])
  assert.deepEqual(
   b.signatures.filter(x=>x.scheduleId===scheduleId).map(x=>x.type).sort(),
   [...SECTION9_ROUNDTRIP_EXISTING_AUTHORITIES].sort());
 assert.deepEqual(r.remainingClearanceTypes,
  ['trusted_flight_execution','commercial_finance']);
 assert.deepEqual(SECTION9_ROUNDTRIP_REQUIRED_AUTHORITIES,
  ['operator_licence','route_traffic_rights','airport_slot_capacity',
   'trusted_flight_execution','commercial_finance']);
});
test('return-direction route denial is not borrowed from outbound approval',async()=>{
 const b=build({deny:{type:'route_traffic_rights',scheduleId:BACK}});
 const r=await b.service.certifyPreparedPair(pair);
 assert.equal(r.status,'roundtrip_independent_certification_blocked');
 assert.equal(r.confirmedCertificates,4);
 assert.equal(r.certificationComplete,false);
 assert.equal(b.signatures.filter(x=>x.scheduleId===BACK).length,1);
 assert.equal(b.checks.filter(x=>x.scheduleId===BACK).length,2);
 assert.equal(b.checks.some(x=>x.scheduleId===BACK&&x.type==='airport_slot_capacity'),false);
});
test('slot refusal on outbound stops before return leg source checks',async()=>{
 const b=build({deny:{type:'airport_slot_capacity',scheduleId:OUT}});
 const r=await b.service.certifyPreparedPair(pair);
 assert.equal(r.status,'roundtrip_independent_certification_blocked');
 assert.equal(r.confirmedCertificates,2);
 assert.equal(b.checks.every(x=>x.scheduleId===OUT),true);
});
test('signed certificate replay is evidence reuse but never activates pair',async()=>{
 const b=build({replay:true});
 const r=await b.service.certifyPreparedPair(pair);
 assert.equal(r.confirmedCertificates,6);
 assert.equal(r.certificationComplete,false);
 assert.equal(r.scheduleActivated,false);
 assert.equal(r.status,'roundtrip_three_of_five_clearance_types_verified_per_leg');
});
test('an issuer response swapping return identity fails closed',async()=>{
 const b=build({wrongIdentity:true});
 const r=await b.service.certifyPreparedPair(pair);
 assert.equal(r.certificationComplete,false);
 assert.ok(r.confirmedCertificates<=3);
 assert.equal(r.status,'roundtrip_independent_certification_failed');
});
test('reject invalid pair and incomplete private dependencies before database reads',async()=>{
 const b=build();
 await assert.rejects(b.service.certifyPreparedPair({...pair,
  returnScheduleId:OUT}),/INVALID_RECIPROCAL_CERTIFICATION_REQUEST/);
 await assert.rejects(b.service.certifyPreparedPair({...pair,
  gameDate:'2026-02-30'}),/INVALID_RECIPROCAL_CERTIFICATION_REQUEST/);
 assert.equal(b.checks.length,0);
 assert.throws(()=>createSection9RoundtripCertificationCoordinator(),
  /THREE_INDEPENDENT_CERTIFICATION_ISSUERS_REQUIRED/);
});


test('both unreleased source checks inspect each leg without granting execution or money',async()=>{
 const db=build();
 const calls=[];
 const coordinator=createSection9RoundtripCertificationCoordinator({
  operatorIssuer:{
   clearanceType:'operator_licence',
   verifyAndCertify:db.service?async request=>({
    status:'certification_event_recorded',scheduleId:request.scheduleId,
    certificateIssued:true,flightActivated:false,bookingsCreated:false,ledgerPosted:false
   }):null
  },
  routeRightsIssuer:{
   clearanceType:'route_traffic_rights',verifyAndCertify:async request=>({
    status:'certification_event_recorded',scheduleId:request.scheduleId,
    certificateIssued:true,flightActivated:false,bookingsCreated:false,ledgerPosted:false
   })
  },
  slotIssuer:{
   clearanceType:'airport_slot_capacity',certifyCurrentSlotReservation:async request=>({
    status:'certification_event_recorded',scheduleId:request.scheduleId,
    slotCertificateIssued:true,flightActivated:false,bookingsCreated:false,ledgerPosted:false
   })
  },
  executionFinanceSourceReader:{
   async inspect(request){
    calls.push(request);
    return {
     status:'blocked_unreleased_execution_finance_source',
     scheduleId:request.scheduleId,
     clearanceType:request.clearanceType,
     blockers:['WORLD_1_PAUSED'],
     sourceAuthorityReleased:false,certificateIssued:false,
     certificationComplete:false,scheduleActivated:false,
     flightActivated:false,bookingsCreated:false,ledgerPosted:false
    };
   }
  }
 });
 const result=await coordinator.certifyPreparedPair(pair);
 assert.equal(result.confirmedCertificates,6);
 assert.equal(result.sourceInspections.length,4);
 assert.equal(result.certificationComplete,false);
 assert.equal(result.flightActivated,false);
 assert.equal(result.ledgerPosted,false);
 assert.deepEqual(calls.map(x=>[x.scheduleId,x.clearanceType]),[
  [OUT,'trusted_flight_execution'],[OUT,'commercial_finance'],
  [BACK,'trusted_flight_execution'],[BACK,'commercial_finance']
 ]);
 for(const item of result.sourceInspections)
  assert.deepEqual(item.blockers,['WORLD_1_PAUSED']);
});
test('untrusted positive source assertion never becomes final activation proof',async()=>{
 const buildIssuer=(type)=>({
  clearanceType:type,
  verifyAndCertify:async req=>({
   status:'certification_event_recorded',scheduleId:req.scheduleId,
   certificateIssued:true,flightActivated:false,bookingsCreated:false,ledgerPosted:false
  }),
  certifyCurrentSlotReservation:async req=>({
   status:'certification_event_recorded',scheduleId:req.scheduleId,
   slotCertificateIssued:true,flightActivated:false,bookingsCreated:false,ledgerPosted:false
  })
 });
 const coordinator=createSection9RoundtripCertificationCoordinator({
  operatorIssuer:buildIssuer('operator_licence'),
  routeRightsIssuer:buildIssuer('route_traffic_rights'),
  slotIssuer:buildIssuer('airport_slot_capacity'),
  executionFinanceSourceReader:{
   async inspect(req){
    return {scheduleId:req.scheduleId,clearanceType:req.clearanceType,
     blockers:[],sourceAuthorityReleased:true,certificateIssued:true,
     certificationComplete:true,scheduleActivated:true,flightActivated:true,
     bookingsCreated:true,ledgerPosted:true};
   }
  }
 });
 const result=await coordinator.certifyPreparedPair(pair);
 assert.equal(result.status,'roundtrip_future_source_inspection_untrusted');
 assert.equal(result.certificationComplete,false);
 assert.equal(result.flightActivated,false);
 assert.equal(result.ledgerPosted,false);
 assert.equal(result.sourceInspections.length,0);
});
test('missing inspector remains a diagnostic-only six-clearance workflow',async()=>{
 const b=build();
 const result=await b.service.certifyPreparedPair(pair);
 assert.equal(result.confirmedCertificates,6);
 assert.deepEqual(result.sourceInspections,[]);
 assert.equal(result.certificationComplete,false);
});
