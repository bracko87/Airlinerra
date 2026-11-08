import test from 'node:test';
import assert from 'node:assert/strict';
import {validateFlightSchedulePayload,createFlightScheduleHandler,SCHEDULE_SQL}
 from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {createSection9RouteDetails} from '../website/section9-route-details.mjs';

const U='11111111-1111-4111-8111-111111111111';
const A='22222222-2222-4222-8222-222222222222';
const S='44444444-4444-4444-8444-444444444444';
const bearer='m'.repeat(48);
const request=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',headers:{origin:'https://airlinerra.com',
  'x-airlinerra-route':'/api/v1/player/flight-schedule-drafts',
  'content-type':'application/json',authorization:'Bearer '+bearer},
 body:JSON.stringify(body)
});
const api=query=>createFlightScheduleHandler({
 verifyUserToken:async()=>({user:{id:U},error:null}),
 database:{connect:async()=>({query,release(){}})}
});
test('only authenticated schedule, valid month, and exact preview fields allowed',()=>{
 const valid={action:'demand-preview',airlineId:A,scheduleId:S,month:7};
 assert.equal(validateFlightSchedulePayload(valid),true);
 for(const body of [
  {...valid,month:0},{...valid,month:13},{...valid,month:6.5},
  {...valid,requestedPlayerId:U},{...valid,scheduleId:'unowned'}
 ])assert.equal(validateFlightSchedulePayload(body),false);
});
test('Section 9 read-only API forwards verified owner identity to database',async()=>{
 const result={scheduleId:S,status:'draft_market_estimate',
  market:{directPassengersPerDay:100},connections:{inbound:[],outbound:[]},
  passengersAllocated:false,flightActivationAllowed:false};
 const handler=api(async(sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.demandPreview);
  assert.deepEqual(args,[U,A,S,7]);
  return {rowCount:1,rows:[{result}]};
 });
 const response=await handler(request({action:'demand-preview',airlineId:A,scheduleId:S,month:7}));
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),result);
 assert.equal(response.headers.get('cache-control'),'no-store');
});
test('database owner denial is not converted into a successful forecast',async()=>{
 const handler=api(async()=>{throw Object.assign(Error('SECTION9_ROUTE_NOT_OWNED'),{code:'42501'});});
 const response=await handler(request({action:'demand-preview',airlineId:A,scheduleId:S,month:7}));
 assert.equal(response.status,403);
});
test('browser passes only schedule identity and month, never player ID',async()=>{
 let posted;
 const client=createFlightScheduleClient({
  auth:{getAccessToken:async()=>bearer},origin:'https://airlinerra.com',
  fetchImpl:async(_url,options)=>{posted=JSON.parse(options.body);
   return Response.json({status:'draft_market_estimate',market:{},connections:{}});}
 });
 await client.demandPreview({airlineId:A,scheduleId:S,month:11});
 assert.deepEqual(posted,{action:'demand-preview',airlineId:A,scheduleId:S,month:11});
});

function element(tag){
 return {tag,id:'',textContent:'',value:'',children:[],listeners:{},
  append(...nodes){this.children.push(...nodes)},
  replaceChildren(...nodes){this.children=[...nodes]},
  addEventListener(type,cb){this.listeners[type]=cb}};
}
const textOf=el=>[String(el.textContent||''),...(el.children||[]).map(textOf)].join(' ');
test('Route Details shows both timed connections but no invented airline load factor',async()=>{
 const host=element('div'),doc={createElement:element};
 let lastMonth=null;
 const route={flightNumber:'PA100',from:{key:'OURAIRPORTS:2214',name:'Hamburg'},
  to:{key:'OURAIRPORTS:2212',name:'Frankfurt'},aircraftLabel:'A320',
  operation:{departureStand:'remote',arrivalStand:'terminal'},
  schedule:[{day:0,time:'12:00'}],referenceDepartureUtc:'2026-11-09T11:00:00Z',
  serverScheduleId:S};
 const view=createSection9RouteDetails({
  doc,host,getRoutes:()=>[route],
  getServer:()=>({connected:true,airline:{id:A},
   reader:{airportProfile:async key=>({airport:{connectionPolicy:{
    minimumMinutes:key===route.from.key?55:65}}})},
   scheduler:{demandPreview:async args=>{
    lastMonth=args.month;
    return {status:'draft_market_estimate',market:{directPassengersPerDay:850,
     cargoTonnesPerDay:1.5,destinationSeasonIndex:100,destinationBackground:'capital_city'},
     connections:{inboundMinimumMinutes:55,outboundMinimumMinutes:65,
      inboundCount:1,outboundCount:1,
      inbound:[{flightNumber:'PA200',airlineName:'Partner',shortestTransferMinutes:80,matchesInFourWeeks:4}],
      outbound:[{flightNumber:'PA300',airlineName:'Partner',shortestTransferMinutes:90,matchesInFourWeeks:4}]}};
   }}
  })
 });
 await view.open(0,7);
 const output=textOf(host);
 assert.equal(lastMonth,7);
 assert.match(output,/PA100/);assert.match(output,/Hamburg/);
 assert.match(output,/Inbound connections/);assert.match(output,/PA200/);
 assert.match(output,/Outbound connections/);assert.match(output,/PA300/);
 assert.match(output,/not passengers booked/);
 assert.doesNotMatch(output,/99% load factor|confirmed booking/);
});
