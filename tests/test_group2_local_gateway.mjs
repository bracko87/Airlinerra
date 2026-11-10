import test from 'node:test';
import assert from 'node:assert/strict';
import {validGroup2LocationPlanRequest,createLiveReadOnlyPreviewHandler} from '../website/dev-scripts/real-player-read-gateway.mjs';
const A='OURAIRPORTS:20581', ORIGIN='http://localhost:5188';
test('Group 2 planned location payloads have exact owner-safe shape',()=>{
 for(const type of ['future_hq','hub','station'])
  assert.equal(validGroup2LocationPlanRequest({action:'save',worldId:1,airportKey:A,type}),true);
 assert.equal(validGroup2LocationPlanRequest({action:'list',worldId:1}),true);
 assert.equal(validGroup2LocationPlanRequest({action:'remove',worldId:1,airportKey:A}),true);
 for(const x of [
  {action:'save',worldId:1,airportKey:A,type:'active'},
  {action:'save',worldId:2,airportKey:A,type:'hub'},
  {action:'save',worldId:1,airportKey:A,type:'hub',airlineId:'forged'},
  {action:'remove',worldId:1,airportKey:A,type:'hub'},
  {action:'list',worldId:1,ownerId:'forged'},
  {action:'save',worldId:1,airportKey:'OURAIRPORTS:bad',type:'future_hq'}
 ])assert.equal(validGroup2LocationPlanRequest(x),false,JSON.stringify(x));
});
test('local gateway forwards planned locations only to protected game API',async()=>{
 const calls=[];
 const handler=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,options)=>{
  calls.push({url,options});
  return new Response(JSON.stringify({
   location:{key:A,type:'future_hq',status:'planned_only'},
   commercialAccess:false,flightsEnabled:false
  }),{status:201,headers:{'content-type':'application/json'}});
 }});
 const request=body=>new Request(ORIGIN+'/api/v1/player/group2-location-plans',{
  method:'POST',headers:{origin:ORIGIN,authorization:'Bearer '+'A'.repeat(32),
  'content-type':'application/json'},body:JSON.stringify(body)});
 const good=await handler(request({action:'save',worldId:1,airportKey:A,type:'future_hq'}));
 assert.equal(good.status,201);assert.equal((await good.json()).flightsEnabled,false);
 assert.equal(calls.length,1);
 assert.match(calls[0].url,/\/functions\/v1\/airlinerra-game$/);
 assert.equal(calls[0].options.headers['x-airlinerra-route'],'/api/v1/player/group2-location-plans');
 const bad=await handler(request({action:'save',worldId:1,airportKey:A,type:'active'}));
 assert.equal(bad.status,403);assert.equal(calls.length,1);
});
