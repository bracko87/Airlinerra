import test from 'node:test';
import assert from 'node:assert/strict';
import {validateFleetAcquisitionRequest,createFleetAcquisitionHandler,FLEET_SQL,FLEET_ACQUISITION_API_ROUTE} from '../server/fleet-acquisition-service.mjs';
import {readCrewHireCounts} from '../website/crew-hiring-panel.mjs';
import {createFleetAcquisitionClient} from '../website/fleet-acquisition-client.mjs';
const user='11111111-1111-4111-8111-111111111111',airlineId='22222222-2222-4222-8222-222222222222',requestId='33333333-3333-4333-8333-333333333333';
const payload={airlineId,baseAirportKey:'OURAIRPORTS:4610',qualificationGroup:'family:12',captains:1,firstOfficers:1,cabinCrew:4};
const quote={action:'crew-hire-quote',...payload};
const confirm={action:'crew-hire-confirm',...payload,requestId,monthlyLimitUsd:'22800.00'};
test('strict quote and confirmation payloads',()=>{
 assert.equal(validateFleetAcquisitionRequest(quote),true);assert.equal(validateFleetAcquisitionRequest(confirm),true);
 for(const bad of [{...quote,qualificationGroup:null},{...quote,captains:201},{...quote,playerId:user},{...confirm,monthlyLimitUsd:'1e6'},{...quote,monthlySalaryUsd:0}])assert.equal(validateFleetAcquisitionRequest(bad),false);
 assert.deepEqual(readCrewHireCounts(['1','1','4']),{captains:1,firstOfficers:1,cabinCrew:4});
 assert.equal(readCrewHireCounts(['0','0','0']),null);assert.equal(readCrewHireCounts(['200','1','0']),null);assert.equal(readCrewHireCounts(['1.5','0','0']),null);
});
test('owner check precedes quote or confirm and SQL parameters are scoped',async()=>{
 const call=async(owned,body)=>{
  const statements=[];
  const handler=createFleetAcquisitionHandler({verifyUserToken:async()=>({user:{id:user},error:null}),database:{connect:async()=>({query:async(sql,args)=>{
   statements.push({sql,args});
   if(sql===FLEET_SQL.owner)return {rowCount:owned?1:0,rows:owned?[{id:airlineId}]:[]};
   return {rowCount:1,rows:[{result:{status:'shared_crew_hiring_disabled'}}]};
  },release(){}})}});
  const response=await handler(new Request('https://example.test',{method:'POST',headers:{origin:'https://airlinerra.com','x-airlinerra-route':FLEET_ACQUISITION_API_ROUTE,authorization:'Bearer '+'v'.repeat(48),'content-type':'application/json'},body:JSON.stringify(body)}));
  return {response,statements};
 };
 const denied=await call(false,confirm);assert.equal(denied.response.status,403);assert.equal(denied.statements.length,1);
 const accepted=await call(true,confirm);assert.equal(accepted.response.status,200);
 assert.deepEqual(accepted.statements[1].args,[user,airlineId,requestId,payload.baseAirportKey,payload.qualificationGroup,1,1,4,'22800.00']);
 assert.equal((await accepted.response.json()).status,'shared_crew_hiring_disabled');
});
test('client sends explicit request id and confirmed monthly cap',async()=>{
 let sent;
 const client=createFleetAcquisitionClient({auth:{getAccessToken:async()=>'v'.repeat(48)},origin:'https://airlinerra.com',fetchImpl:async(url,options)=>{sent=JSON.parse(options.body);return new Response(JSON.stringify({status:'shared_crew_hiring_disabled',airlineId}),{status:200});}});
 await client.crewHireConfirm({...payload,requestId,monthlyLimitUsd:'22800.00'});assert.deepEqual(sent,confirm);
});
