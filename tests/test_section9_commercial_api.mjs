import test from 'node:test';
import assert from 'node:assert/strict';
import {validateFlightSchedulePayload,createFlightScheduleHandler,SCHEDULE_SQL}
 from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {createSection9PartnerConsole} from '../website/section9-partner-console.mjs';
import {createSection9CommercialPlanEditor} from '../website/section9-commercial-plan-editor.mjs';

const u='11111111-1111-4111-8111-111111111111',
 airline='22222222-2222-4222-8222-222222222222',
 schedule='33333333-3333-4333-8333-333333333333';
const bearer='v'.repeat(48);
const req=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',headers:{origin:'https://airlinerra.com',
  'x-airlinerra-route':'/api/v1/player/flight-schedule-drafts',
  'content-type':'application/json',authorization:'Bearer '+bearer},
 body:JSON.stringify(body)
});
const handler=query=>createFlightScheduleHandler({
 verifyUserToken:async()=>({user:{id:u},error:null}),
 database:{connect:async()=>({query,release(){}})}
});

test('Commercial API rejects excess fields, missing price and unsafe budget',()=>{
 const good={action:'commercial-save',airlineId:airline,scheduleId:schedule,
  economyFareUsd:159.95,cargoRateUsdPerTonne:700,marketingBudgetUsdPerDay:50};
 assert.equal(validateFlightSchedulePayload(good),true);
 for(const body of [
  {...good,economyFareUsd:-1},
  {...good,economyFareUsd:'0'},
  {...good,marketingBudgetUsdPerDay:Infinity},
  {...good,extra:'fake'},
  {...good,marketingBudgetUsdPerDay:0.001},
  {...good,scheduleId:'wrong'}
 ])assert.equal(validateFlightSchedulePayload(body),false);
 assert.equal(validateFlightSchedulePayload({action:'commercial-read',airlineId:airline,scheduleId:schedule}),true);
});

test('Partner actions only accept strict code, integer ID and decision',()=>{
 assert.equal(validateFlightSchedulePayload({action:'partner-list',airlineId:airline}),true);
 assert.equal(validateFlightSchedulePayload({action:'partner-propose',
  airlineId:airline,otherAirlineCode:'LH'}),true);
 for(const body of [
  {action:'partner-propose',airlineId:airline,otherAirlineCode:'LH;'},
  {action:'partner-propose',airlineId:airline,otherAirlineCode:'a'},
  {action:'partner-decision',airlineId:airline,agreementId:'42',decision:'approve'},
  {action:'partner-decision',airlineId:airline,agreementId:42,decision:'force'},
  {action:'partner-decision',airlineId:airline,agreementId:0,decision:'approve'}
 ])assert.equal(validateFlightSchedulePayload(body),false);
 assert.equal(validateFlightSchedulePayload({action:'partner-decision',
  airlineId:airline,agreementId:42,decision:'terminate'}),true);
});

test('Server calls owned SQL functions; never trusts posted player identity',async()=>{
 const cases=[
  [{action:'commercial-read',airlineId:airline,scheduleId:schedule},
   SCHEDULE_SQL.commercialRead,[u,airline,schedule]],
  [{action:'commercial-save',airlineId:airline,scheduleId:schedule,
    economyFareUsd:100,cargoRateUsdPerTonne:500,marketingBudgetUsdPerDay:0},
   SCHEDULE_SQL.commercialSave,[u,airline,schedule,100,500,0]],
  [{action:'partner-list',airlineId:airline},
   SCHEDULE_SQL.partnershipList,[u,airline]],
  [{action:'partner-propose',airlineId:airline,otherAirlineCode:'LH'},
   SCHEDULE_SQL.partnershipPropose,[u,airline,'LH']],
  [{action:'partner-decision',airlineId:airline,agreementId:5,decision:'approve'},
   SCHEDULE_SQL.partnershipDecision,[u,airline,'approve',5]]
 ];
 for(const [body,expectedSql,expectedArgs] of cases){
  const h=handler(async(sql,args)=>{
   assert.equal(sql,expectedSql);assert.deepEqual(args,expectedArgs);
   return {rowCount:1,rows:[{result:{status:'planned',bookingsEnabled:false}}]};
  });
  const response=await h(req(body));
  assert.equal(response.status,200);
  assert.equal((await response.json()).bookingsEnabled,false);
 }
});

test('Non-owner is rejected by DB before partner or fare changes',async()=>{
 const h=handler(async()=>{throw Object.assign(Error('NOT_OWNED'),{code:'42501'});});
 for(const body of [
  {action:'commercial-read',airlineId:airline,scheduleId:schedule},
  {action:'partner-list',airlineId:airline}
 ])assert.equal((await h(req(body))).status,403);
});

test('Client can send commercial plan and bilateral interline requests',async()=>{
 const calls=[];
 const client=createFlightScheduleClient({
  auth:{getAccessToken:async()=>bearer},origin:'https://airlinerra.com',
  fetchImpl:async(_url,opts)=>{calls.push(JSON.parse(opts.body));return Response.json({status:'planned'});}
 });
 await client.commercialRead({airlineId:airline,scheduleId:schedule});
 await client.commercialSave({airlineId:airline,scheduleId:schedule,
  economyFareUsd:130,cargoRateUsdPerTonne:500,marketingBudgetUsdPerDay:100});
 await client.partnerList(airline);
 await client.partnerPropose({airlineId:airline,otherAirlineCode:'lh'});
 await client.partnerDecision({airlineId:airline,agreementId:31,decision:'terminate'});
 assert.deepEqual(calls.map(x=>x.action),[
  'commercial-read','commercial-save','partner-list','partner-propose','partner-decision']);
 assert.equal(calls[3].otherAirlineCode,'LH');
 assert.equal(calls[4].agreementId,31);
 assert.ok(calls.every(x=>x.userId===undefined));
});

function node(tag){
 return {tag,children:[],dataset:{},listeners:{},textContent:'',value:'',
  append(...xs){this.children.push(...xs)},
  replaceChildren(...xs){this.children=[...xs]},
  addEventListener(type,cb){this.listeners[type]=cb}};
}
const descend=(x)=>[x,...x.children.flatMap(descend)];
test('Partner console displays approvals without granting access itself',async()=>{
 const doc={createElement:node},host=node('section');
 let listed=0,proposed=null;
 const view=createSection9PartnerConsole({
  doc,host,getServer:()=>({
   connected:true,airline:{id:airline},scheduler:{
    partnerList:async()=>{listed++;return {agreements:[
     {agreementId:15,otherAirlineName:'Partner',otherAirlineCode:'XY',
      status:'proposed',canApprove:true}]};},
    partnerPropose:async args=>{proposed=args;return {status:'proposed'};}
   }
  })
 });
 await view.refresh();
 assert.equal(listed,1);
 const buttons=descend(host).filter(x=>x.tag==='button');
 const input=descend(host).find(x=>x.tag==='input');
 assert.ok(buttons.some(x=>x.dataset.partnerAction==='approve'));
 input.value='XY';await buttons.find(x=>x.textContent==='Request cooperation').listeners.click();
 assert.deepEqual(proposed,{airlineId:airline,otherAirlineCode:'XY'});
});

test('Commercial editor displays draft as unpaid and validates inputs',async()=>{
 const doc={createElement:node},host=node('div');
 let saved=null;
 const editor=createSection9CommercialPlanEditor({
  doc,host,getServer:()=>({scheduler:{
   commercialRead:async()=>({economyFareUsd:115,cargoRateUsdPerTonne:0,
    marketingBudgetUsdPerDay:0}),
   commercialSave:async args=>{saved=args;return {scheduleId:schedule,
    paidMarketingActive:false,version:1};}
  }})
 });
 await editor.open({serverScheduleId:schedule},airline);
 const input=descend(host).filter(x=>x.tag==='input');
 assert.equal(input.length,3);
 assert.equal(input[0].value,115);
 input[0].value='120';input[1].value='30';input[2].value='0';
 const save=descend(host).find(x=>x.tag==='button');
 await save.listeners.click();
 assert.deepEqual(saved,{airlineId:airline,scheduleId:schedule,
  economyFareUsd:120,cargoRateUsdPerTonne:30,marketingBudgetUsdPerDay:0});
 assert.match(descend(host).map(x=>x.textContent).join(' '),/Marketing remains planned/);
});
