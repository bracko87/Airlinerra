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


test('Operational-readiness preview validates date, owner scope and cannot activate flights',()=>{
 const base={action:'operations-preview',airlineId:AIRLINE,scheduleId:SCHEDULE,
  startDate:'2026-11-09',days:28};
 assert.equal(validateFlightSchedulePayload(base),true);
 for(const bad of [
  {...base,playerId:USER},{...base,activate:true},
  {...base,days:50},{...base,startDate:'2026-02-30'},
  {...base,scheduleId:'invalid'}
 ])assert.equal(validateFlightSchedulePayload(bad),false);
});
test('Operations preview server injects authenticated player and returns only blocked evidence',async()=>{
 const evidence={status:'BLOCKED_OPERATIONAL_EVIDENCE_INCOMPLETE',
  canActivateNormalFlight:false,readOnly:true,
  blockers:['CREW_ASSIGNMENTS_NOT_VERIFIED'],
  turnaround:{minimumMinutes:40,shortTurnaroundOccurrences:1}};
 const h=handler(async(sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.operationsPreview);
  assert.deepEqual(args,[USER,AIRLINE,SCHEDULE,'2026-11-09',28]);
  return {rowCount:1,rows:[{result:evidence}]};
 });
 const response=await h(request({action:'operations-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2026-11-09',days:28}));
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),evidence);
 assert.equal(response.headers.get('cache-control'),'no-store');
});
test('Operations preview refuses an unsafe database activation flag',async()=>{
 const h=handler(async()=>({rowCount:1,rows:[{result:{
  canActivateNormalFlight:true,readOnly:true}}]}));
 const response=await h(request({action:'operations-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2026-11-09',days:28}));
 assert.equal(response.status,503);
});
test('Operations preview client never sends browser player identity',async()=>{
 let payload=null;
 const client=createFlightScheduleClient({auth:{getAccessToken:async()=>TOKEN},
  origin:'https://airlinerra.com',
  fetchImpl:async(_url,options)=>{
   payload=JSON.parse(options.body);
   return Response.json({readOnly:true,canActivateNormalFlight:false,blockers:[]});
  }});
 await client.operationsPreview({airlineId:AIRLINE,scheduleId:SCHEDULE,
  startDate:'2026-11-09',days:28});
 assert.deepEqual(payload,{action:'operations-preview',airlineId:AIRLINE,
  scheduleId:SCHEDULE,startDate:'2026-11-09',days:28});
});
test('Route details shows ground, crew and legal evidence without an activation CTA',async()=>{
 const doc={createElement:element},host=element('section');
 const ui=createSection9RotationReview({doc,host,getServer:()=>({
  scheduler:{
   rotationPreview:async()=>({readOnly:true,canActivateNormalFlight:false}),
   operationsPreview:async()=>({
    readOnly:true,canActivateNormalFlight:false,
    turnaround:{minimumMinutes:40,shortTurnaroundOccurrences:2},
    crew:{catalogRequirementKnown:false,assignmentsVerified:false},
    deliveryEvidence:{inspectionApproved:false},
    routeRights:{operationallyAuthorized:false},
    blockers:['CREW_REQUIREMENT_UNKNOWN','AIRCRAFT_TURNAROUND_TOO_SHORT',
     'TRAFFIC_RIGHTS_NOT_OPERATIONALLY_AUTHORIZED']
   })
  }
 })});
 await ui.open({serverScheduleId:SCHEDULE,
  referenceDepartureUtc:'2026-11-09T09:00:00Z'},AIRLINE);
 const buttons=descendants(host).filter(x=>x.tag==='button');
 assert.equal(buttons.length,2);
 await buttons[1].listeners.click();
 const output=descendants(host).map(x=>x.textContent).join(' ');
 assert.match(output,/40 minutes/);
 assert.match(output,/Short aircraft ground stops/);
 assert.match(output,/CREW REQUIREMENT UNKNOWN/);
 assert.match(output,/Turnaround figures are provisional/);
 assert.match(output,/activation remains blocked/i);
 assert.doesNotMatch(output,/Activate now/);
});

test('Crew roster and duty proposal API restrict fields and verified identity',async()=>{
 const rosterRequest={action:'crew-roster',airlineId:AIRLINE,scheduleId:SCHEDULE};
 const dutyRequest={action:'crew-plan',airlineId:AIRLINE,scheduleId:SCHEDULE,
  crewId:USER,weeklyEntry:1,decision:'plan'};
 assert.equal(validateFlightSchedulePayload(rosterRequest),true);
 assert.equal(validateFlightSchedulePayload(dutyRequest),true);
 for(const bad of [
  {...dutyRequest,playerId:USER},{...dutyRequest,employmentStatus:'verified_employed'},
  {...dutyRequest,weeklyEntry:8},{...dutyRequest,decision:'approve'},
  {...dutyRequest,crewId:'wrong'},{...rosterRequest,airlineOwnerId:USER}
 ])assert.equal(validateFlightSchedulePayload(bad),false);
 const roster={status:'crew_roster_planning_only',readOnly:true,
  canActivateNormalFlight:false,crewAvailableForPlanning:[],proposals:[]};
 const h=handler(async(sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.crewRoster);
  assert.deepEqual(args,[USER,AIRLINE,SCHEDULE]);
  return {rowCount:1,rows:[{result:roster}]};
 });
 const response=await h(request(rosterRequest));
 assert.equal(response.status,200);
 assert.deepEqual(await response.json(),roster);
 const planned={status:'planned_not_verified',
  canActivateNormalFlight:false,changed:true};
 const h2=handler(async(sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.crewPlan);
  assert.deepEqual(args,[USER,AIRLINE,SCHEDULE,USER,1,'plan']);
  return {rowCount:1,rows:[{result:planned}]};
 });
 const p=await h2(request(dutyRequest));
 assert.equal(p.status,200);
 assert.deepEqual(await p.json(),planned);
});
test('Crew assignment cannot claim confirmed employment or activated flight',async()=>{
 const h=handler(async()=>({rowCount:1,rows:[{result:{
  status:'approved',canActivateNormalFlight:true
 }}]}));
 const result=await h(request({action:'crew-plan',airlineId:AIRLINE,
  scheduleId:SCHEDULE,crewId:USER,weeklyEntry:1,decision:'plan'}));
 assert.equal(result.status,503);
});
test('Crew roster client sends only owner-scoped schedule and crew IDs',async()=>{
 const posts=[];
 const client=createFlightScheduleClient({auth:{getAccessToken:async()=>TOKEN},
  origin:'https://airlinerra.com',
  fetchImpl:async(_url,opts)=>{
   posts.push(JSON.parse(opts.body));
   return Response.json({status:posts.length===1?'crew_roster_planning_only':'planned_not_verified',
    readOnly:true,canActivateNormalFlight:false});
  }});
 await client.crewRoster({airlineId:AIRLINE,scheduleId:SCHEDULE});
 await client.crewPlan({airlineId:AIRLINE,scheduleId:SCHEDULE,
  crewId:USER,weeklyEntry:1,decision:'plan'});
 assert.deepEqual(posts[0],{action:'crew-roster',airlineId:AIRLINE,
  scheduleId:SCHEDULE});
 assert.deepEqual(posts[1],{action:'crew-plan',airlineId:AIRLINE,
  scheduleId:SCHEDULE,crewId:USER,weeklyEntry:1,decision:'plan'});
});
test('Crew planner displays empty registered roster without creating fictional crew',async()=>{
 const doc={createElement:element},host=element('section');
 let saved=false;
 const ui=createSection9RotationReview({doc,host,getServer:()=>({
  scheduler:{
   rotationPreview:async()=>({readOnly:true,canActivateNormalFlight:false}),
   crewRoster:async()=>({status:'crew_roster_planning_only',
    readOnly:true,canActivateNormalFlight:false,crewAvailableForPlanning:[],
    proposals:[]}),
   crewPlan:async()=>{saved=true}
  }
 })});
 await ui.open({serverScheduleId:SCHEDULE,schedule:[{day:0,time:'10:00'}]},AIRLINE);
 const buttons=descendants(host).filter(x=>x.tag==='button');
 const manage=buttons.find(x=>x.textContent==='Plan weekly crew');
 assert.ok(manage);
 await manage.listeners.click();
 const displayed=descendants(host).map(x=>x.textContent).join(' ');
 assert.match(displayed,/No crew members qualified/i);
 assert.equal(saved,false);
 assert.doesNotMatch(displayed,/Activated flight|Ticket issued/);
});
test('Crew proposal UI submits registered employee and schedule weekly entry only',async()=>{
 const doc={createElement:element},host=element('section');
 let received=null;
 const ui=createSection9RotationReview({doc,host,getServer:()=>({
  scheduler:{
   rotationPreview:async()=>({readOnly:true,canActivateNormalFlight:false}),
   crewRoster:async()=>({readOnly:true,canActivateNormalFlight:false,
    crewAvailableForPlanning:[{crewId:USER,crewReference:'Test crew',
     employmentStatus:'pending_verification',aircraftQualificationMatches:true}],
    proposals:[]}),
   crewPlan:async args=>{received=args;return {
    status:'planned_not_verified',canActivateNormalFlight:false}}
  }
 })});
 await ui.open({serverScheduleId:SCHEDULE,
  schedule:[{day:0,time:'10:00'}]},AIRLINE);
 await descendants(host).find(x=>x.textContent==='Plan weekly crew').listeners.click();
 const plan=descendants(host).find(x=>x.textContent==='Propose assignment');
 assert.ok(plan);
 await plan.listeners.click();
 assert.deepEqual(received,{airlineId:AIRLINE,
  scheduleId:SCHEDULE,crewId:USER,weeklyEntry:1,decision:'plan'});
 assert.match(descendants(host).map(x=>x.textContent).join(' '),
  /Flights remain inactive/);
});
