import test from 'node:test';
import assert from 'node:assert/strict';
import {createFlightScheduleHandler,validateFlightSchedulePayload,SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';
import {AIRPORT_PROFILE_SQL,serializeAirportProfile} from '../server/airport-profile-service.mjs';
const uid='11111111-1111-4111-8111-111111111111';
const airline='22222222-2222-4222-8222-222222222222';
const plane='33333333-3333-4333-8333-333333333333';
const token='a'.repeat(48);
const base={airlineId:airline,aircraftInventoryId:plane,
 originAirportKey:'OURAIRPORTS:2220',destinationAirportKey:'OURAIRPORTS:4001',
 referenceDepartureUtc:'2026-11-06T10:00:00Z',
 referenceArrivalUtc:'2026-11-06T12:00:00Z',
 weeklySchedule:[{day:0,time:'13:00'}],departureStand:'remote',arrivalStand:'remote'};
const request=body=>new Request('https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-flight-schedule-drafts',{
 method:'POST',body:JSON.stringify(body),
 headers:{origin:'https://airlinerra.com',
 'x-airlinerra-route':'/api/v1/player/flight-schedule-drafts',
 authorization:'Bearer '+token,'content-type':'application/json'}
});
const handler=query=>createFlightScheduleHandler({
 verifyUserToken:async()=>({user:{id:uid},error:null}),
 database:{connect:async()=>({query,release(){}})}
});
test('Section 6 validates both stand choices, and rejects unknown slot-check payload fields',()=>{
 assert.equal(validateFlightSchedulePayload({...base,action:'slot-check'}),true);
 assert.equal(validateFlightSchedulePayload({...base,action:'slot-check',departureStand:'cargo'}),true);
 assert.equal(validateFlightSchedulePayload({...base,action:'slot-check',departureStand:'airport'}),false);
 assert.equal(validateFlightSchedulePayload({...base,action:'slot-check',unknown:'x'}),false);
 assert.equal(validateFlightSchedulePayload({...base,action:'save',flightNumber:'PA101'}),true);
});
test('slot checks require an owned airline and an in-service aircraft',async()=>{
 let calls=0;
 const h=handler(async sql=>{calls++;if(sql===SCHEDULE_SQL.owner)return {rowCount:0,rows:[]};throw Error('Unexpected query');});
 assert.equal((await h(request({...base,action:'slot-check'}))).status,403);
 assert.equal(calls,1);
});
test('slot check reports only directional availability, never remaining slot counts',async()=>{
 const h=handler(async(sql,args)=>{
  if(sql===SCHEDULE_SQL.owner)return {rowCount:1,rows:[{id:airline}]};
  if(sql===SCHEDULE_SQL.fleetUse)return {rowCount:1,rows:[{useType:'passenger'}]};
  if(sql===SCHEDULE_SQL.slotCheck){
   assert.deepEqual(args.slice(0,2),[base.originAirportKey,base.destinationAirportKey]);
   assert.deepEqual(args.slice(5,7),['remote','remote']);
   return {rowCount:1,rows:[{result:{available:false,
     departureAvailable:true,arrivalAvailable:false,windowsChecked:2}}]};
  }
  throw Error('Unexpected SQL');
 });
 const res=await h(request({...base,action:'slot-check'}));
 const data=await res.json();
 assert.equal(res.status,200);
 assert.deepEqual(data,{available:false,departureAvailable:true,
  arrivalAvailable:false,slotModel:'weekly_stand_capacity_v1'});
 assert.equal(data.windowsChecked,undefined);
});
test('save commits stand choices through the protected database wrapper',async()=>{
 const h=handler(async(sql,args)=>{
  assert.equal(sql,SCHEDULE_SQL.save);
  assert.deepEqual(args.slice(-2),['remote','remote']);
  return {rowCount:1,rows:[{result:{status:'draft',
   slotsReserved:true,canActivateNormalFlight:false,
   scheduleId:'44444444-4444-4444-8444-444444444444'}}]};
 });
 const res=await h(request({...base,action:'save',flightNumber:'PA101'}));
 assert.equal(res.status,200);
 assert.equal((await res.json()).slotsReserved,true);
});
test('airport page receives separate terminal, remote and cargo capacity',()=>{
 assert.match(AIRPORT_PROFILE_SQL,/section6_airport_slot_capacity_v1/);
 const sample=serializeAirportProfile({airport_key:'OURAIRPORTS:2220',
  airport_name:'Test Airport',airport_code:'TEST',country_iso:'RS',
  slot_terminal_stands:30,slot_remote_stands:10,slot_cargo_stands:4,
  slot_terminal_per_direction_10m:5,slot_remote_per_direction_10m:2,
  slot_cargo_per_direction_10m:1});
 assert.equal(sample.slotCapacity.terminal.arrivalsPerHour,30);
 assert.equal(sample.slotCapacity.remote.departuresPer10Minutes,2);
 assert.equal(sample.slotCapacity.cargo.arrivalsPer10Minutes,1);
 const markup=routePlannerMarkup();
 assert.match(markup,/route-departure-stand/);
 assert.match(markup,/Remote stand \(lower fees\)/);
 assert.match(markup,/route-arrival-stand/);
});
