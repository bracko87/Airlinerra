import test from 'node:test';
import assert from 'node:assert/strict';
import {validateAirportOfficeProposal,officeActivationEligibility} from '../server/airport-office-domain.mjs';
const valid={type:'station',airportKey:'OURAIRPORTS:4344',worldId:1,homeAirportKey:'OURAIRPORTS:4343',approvedAirportWorldId:1};
test('approved, world-matched station proposal is draft',()=>{
 const result=validateAirportOfficeProposal(valid);
 assert.deepEqual(result,{ok:true,type:'station',airportKey:'OURAIRPORTS:4344',worldId:1,requiredStaff:1,state:'draft'});
});
test('reject wrong world, HQ, duplicates, unapproved and unsupported roles',()=>{
 for(const bad of [
  {approvedAirportWorldId:2},{airportKey:'OURAIRPORTS:4343'},
  {existingAirportKeys:['OURAIRPORTS:4344']},{type:'headquarters'},
  {airportKey:'bad'},{worldId:0}
 ])assert.equal(validateAirportOfficeProposal({...valid,...bad}).ok,false);
});
test('activation requires real staff and verified fee quote',()=>{
 const office={type:'station',state:'draft'};
 assert.equal(officeActivationEligibility({office,assignedActiveEmployees:0}).ok,false);
 assert.equal(officeActivationEligibility({office,assignedActiveEmployees:1}).ok,false);
 const feeQuote={verified:true,openingUsdCents:500,monthlyUsdCents:1200};
 assert.deepEqual(officeActivationEligibility({office,assignedActiveEmployees:1,feeQuote}),
  {ok:true,openingUsdCents:500,monthlyUsdCents:1200});
 assert.equal(officeActivationEligibility({office:{...office,state:'active'},assignedActiveEmployees:1,feeQuote}).ok,false);
});
test('hubs do not require station employee but still require verified fees',()=>{
 const result=officeActivationEligibility({office:{type:'hub',state:'draft'},feeQuote:{verified:true,openingUsdCents:0,monthlyUsdCents:0}});
 assert.equal(result.ok,true);
});
