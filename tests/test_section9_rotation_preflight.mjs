import test from 'node:test';
import assert from 'node:assert/strict';
import {validateFlightSchedulePayload,createFlightScheduleHandler,SCHEDULE_SQL}
 from '../server/flight-schedule-service.mjs';
import {createFlightScheduleClient} from '../website/flight-schedule-client.mjs';
import {createSection9RotationReview} from '../website/section9-rotation-review.mjs';

const USER='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const SCHEDULE='44444444-4444-4444-8444-444444444444';
const TOKEN='x'.repeat(48);
const request=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',headers:{origin:'https://airlinerra.com',
  'x-airlinerra-route':'/api/v1/player/flight-schedule-drafts',
  'content-type':'application/json',authorization:'Bearer '+TOKEN},
 body:JSON.stringify(body)
});
const handler=query=>createFlightScheduleHandler({
 verifyUserToken:async()=>({user:{id:USER},error:null}),
 database:{connect:async()=>({query,release(){}})}
});
test('Owner-scoped rotation check validates date, horizon and exact fields',()=>{
 const valid={action:'rotation-preview',airlineId:AIRLINE,scheduleId:SCHEDULE,
  startDate:'2026-11-09',days:28};
 assert.equal(validateFlightSchedulePayload(valid),true);
 for(const v of [
  {...valid,startDate:'2026-02-30'},
  {...valid,startDate:'not-a-date'},
  {...valid,startDate:'2200-01-01'},
  {...valid,days:6},
  {...valid,days:43},
  {...valid,days:'28'},
  {...valid,playerId:USER},
  {...valid,activate:true},
  {...valid,scheduleId:'not-a-uuid'}
 ])assert.equal(validateFlightSchedulePayload(v),false);
});

test('Rotation preview injects only verified player identity, never posted user data',async()=>{
 const expected={status:'ROTATION_CONFLICT_OR_UNVERIFIED',readOnly:true,
  canActivateNormalFlight:false,overlappingFlights:2};
 const h=handler(async(sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.rotationPreview);
  assert.deepEqual(args,[USER,AIRLINE,SCHEDULE,'2026-11-09',28]);
  return {rowCount:1,rows:[{result:expected}]};
 });
 const response=await h(request({action:'rotation-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2026-11-09',days:28}));
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),expected);
 assert.equal(response.headers.get('cache-control'),'no-store');
});

test('Database non-owner denial remains an authorization failure',async()=>{
 const h=handler(async()=>{throw Object.assign(
  Error('SECTION9_ROTATION_SCHEDULE_NOT_OWNED'),{code:'42501'});});
 const response=await h(request({action:'rotation-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2026-11-09',days:28}));
 assert.equal(response.status,403);
});

test('Browser sends only rotation preview parameters',async()=>{
 let posted=null;
 const client=createFlightScheduleClient({
  auth:{getAccessToken:async()=>TOKEN},origin:'https://airlinerra.com',
  fetchImpl:async(_url,opts)=>{
   posted=JSON.parse(opts.body);
   return Response.json({status:'ROTATION_CONFLICT_OR_UNVERIFIED',
    canActivateNormalFlight:false,readOnly:true});
  }
 });
 await client.rotationPreview({airlineId:AIRLINE,scheduleId:SCHEDULE,
  startDate:'2026-11-09',days:28});
 assert.deepEqual(posted,{action:'rotation-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2026-11-09',days:28});
 assert.equal(posted.playerId,undefined);
});

function element(tag){
 return {tag,children:[],dataset:{},listeners:{},textContent:'',value:'',
  append(...x){this.children.push(...x)},
  replaceChildren(...x){this.children=[...x]},
  addEventListener(type,fn){this.listeners[type]=fn}};
}
const descendants=x=>[x,...x.children.flatMap(descendants)];

test('Route Details rotation panel reports conflicts without presenting activation',async()=>{
 const doc={createElement:element},host=element('section');
 let captured=null;
 const ui=createSection9RotationReview({doc,host,getServer:()=>({
  airline:{id:AIRLINE},scheduler:{rotationPreview:async args=>{
   captured=args;
   return {status:'ROTATION_CONFLICT_OR_UNVERIFIED',
    readOnly:true,canActivateNormalFlight:false,flightOccurrences:12,
    overlappingFlights:2,wrongAirportDepartures:1,
    daylightSavingTimeIssues:0,invalidWeeklyEntries:0,unknownOriginTimezones:0,
    slotsRecorded:{departure:true,arrival:true},
    sampleConflicts:[{flightNumber:'PA101',reason:'AIRCRAFT_OVERLAP',
      origin:'HAM',destination:'FRA'}]};
  }}
 })});
 await ui.open({serverScheduleId:SCHEDULE,
  referenceDepartureUtc:'2026-11-09T09:00:00Z'},AIRLINE);
 const controls=descendants(host);
 const button=controls.find(x=>x.tag==='button');
 assert.ok(button);
 await button.listeners.click();
 assert.equal(captured.airlineId,AIRLINE);
 assert.equal(captured.scheduleId,SCHEDULE);
 assert.equal(captured.days,28);
 const output=descendants(host).map(x=>x.textContent).join(' ');
 assert.match(output,/overlapping flights|Overlapping flights/i);
 assert.match(output,/AIRCRAFT_OVERLAP/);
 assert.match(output,/Activation remains blocked/);
 assert.doesNotMatch(output,/Activate now|Start commercial flight/);
});

test('Rotation preview fails closed when backend claims flights may activate',async()=>{
 const doc={createElement:element},host=element('section');
 const ui=createSection9RotationReview({doc,host,getServer:()=>({
  scheduler:{rotationPreview:async()=>({readOnly:false,canActivateNormalFlight:true})}
 })});
 await ui.open({serverScheduleId:SCHEDULE,referenceDepartureUtc:'2026-11-09T09:00:00Z'},AIRLINE);
 await descendants(host).find(x=>x.tag==='button').listeners.click();
 const output=descendants(host).map(x=>x.textContent).join(' ');
 assert.match(output,/unavailable/i);
});
