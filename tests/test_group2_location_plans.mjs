import test from 'node:test';
import assert from 'node:assert/strict';
import {createGroup2LocationPlanHandler,GROUP2_LOCATION_PATH} from '../server/group2-location-plans-service.mjs';

const ID='550e8400-e29b-41d4-a716-446655440000';
const A='OURAIRPORTS:20581',ORIGIN='https://airlinerra.com';
const req=(body,token='a'.repeat(32),origin=ORIGIN)=>new Request(ORIGIN+GROUP2_LOCATION_PATH,{
 method:'POST',headers:{origin,authorization:'Bearer '+token,'content-type':'application/json'},
 body:JSON.stringify(body)
});
function mock({noOwner=false,noAirport=false,existing=[],list=[]}={}){
 const calls=[],events=[];
 const connection={
  query:async(sql,args)=>{
   calls.push({sql,args});
   if(['BEGIN','COMMIT','ROLLBACK'].includes(sql)){events.push(sql);return {rows:[]};}
   if(sql.includes('from airlinerra_game.airlines where owner_player_id')&&sql.includes('for update'))
    return {rows:noOwner?[]:[{id:ID}]};
   if(sql.includes('from airlinerra_game.airport_group2_game_profiles_v1 g')&&sql.includes('c.source_group'))
    return {rows:noAirport?[]:[{airport_key:A}]};
   if(sql.includes('from airlinerra_game.airport_group2_location_intents_v1 i'))
    return {rows:list};
   if(sql.includes('select intent_type,airport_key'))
    return {rows:existing};
   if(sql.startsWith('insert into airlinerra_game.airport_group2_location_intents_v1'))
    return {rows:[{airport_key:A,intent_type:args[2],intent_status:'planned_only'}]};
   if(sql.startsWith('delete from airlinerra_game.airport_group2_location_intents_v1'))
    return {rows:[{airport_key:A}]};
   throw Error('Unexpected database statement');
  },release:()=>events.push('RELEASE')
 };
 let connections=0;
 const handler=createGroup2LocationPlanHandler({
  verifyUserToken:async()=>({user:{id:ID,email_confirmed_at:'2026-11-10T10:00:00Z'}}),
  database:{connect:async()=>{connections++;return connection;}},origin:ORIGIN
 });
 return {handler,calls,events,getConnections:()=>connections};
}
test('Group 2 plan route refuses unauthenticated and cross-origin requests before DB access',async()=>{
 const m=mock();
 assert.equal((await m.handler(req({action:'list',worldId:1},'bad'))).status,401);
 assert.equal((await m.handler(req({action:'list',worldId:1},'a'.repeat(32),'https://evil.example'))).status,403);
 assert.equal((await m.handler(req({action:'save',worldId:2,airportKey:A,type:'hub'}))).status,400);
 assert.equal((await m.handler(req({action:'save',worldId:1,airportKey:A,type:'active'}))).status,400);
 assert.equal((await m.handler(req({action:'save',worldId:1,airportKey:A,type:'hub',ownerPlayerId:ID}))).status,400);
 assert.equal(m.getConnections(),0);
});
test('Group 2 owners can list only owner-filtered plans, always non-operational',async()=>{
 const m=mock({list:[{key:A,name:'Grant County',code:'G2-20581',
 countryIso:'US',category:'Medium',type:'future_hq',status:'planned_only'}]});
 const r=await m.handler(req({action:'list',worldId:1}));assert.equal(r.status,200);
 const data=await r.json();assert.equal(data.locations[0].type,'future_hq');
 assert.equal(data.commercialAccess,false);assert.equal(data.flightsEnabled,false);
 assert.deepEqual(m.calls[0].args,[ID]);assert.match(m.calls[0].sql,/owner_player_id=\$1::uuid/);
});
test('Group 2 owner can save a prepared future HQ without any airline HQ, office or flight write',async()=>{
 const m=mock(),r=await m.handler(req({action:'save',worldId:1,airportKey:A,type:'future_hq'}));
 assert.equal(r.status,201);
 const data=await r.json();
 assert.deepEqual(data.location,{key:A,type:'future_hq',status:'planned_only'});
 assert.equal(data.commercialAccess,false);assert.equal(data.flightsEnabled,false);
 assert.deepEqual(m.events,['BEGIN','COMMIT','RELEASE']);
 assert.ok(m.calls.some(c=>c.sql.includes('GROUP2_PREPARED_NOT_ADMITTED')));
 assert.ok(m.calls.every(c=>!/(insert into airlinerra_game\.airlines|insert into airlinerra_game\.airport_offices|schedule_reservations|airline_ledger)/i.test(c.sql)));
});
test('reject missing airline, unavailable airport and competing future HQ',async()=>{
 for(const [config,payload,expected] of [
  [{noOwner:true},{action:'save',worldId:1,airportKey:A,type:'hub'},404],
  [{noAirport:true},{action:'save',worldId:1,airportKey:A,type:'hub'},409],
  [{existing:[{airport_key:'OURAIRPORTS:111',intent_type:'future_hq'}]},
   {action:'save',worldId:1,airportKey:A,type:'future_hq'},409]
 ]){
  const m=mock(config);assert.equal((await m.handler(req(payload))).status,expected);
  assert.ok(m.events.includes('ROLLBACK'));
 }
});
test('remove plan is scoped to authenticated airline and never touches operational airport tables',async()=>{
 const m=mock(),r=await m.handler(req({action:'remove',worldId:1,airportKey:A}));
 assert.equal(r.status,200);
 const data=await r.json();assert.equal(data.removed,true);
 assert.equal(data.commercialAccess,false);assert.equal(data.flightsEnabled,false);
 assert.ok(m.calls.some(c=>c.sql.startsWith('delete from airlinerra_game.airport_group2_location_intents_v1')));
});
