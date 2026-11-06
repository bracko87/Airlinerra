import test from 'node:test';
import assert from 'node:assert/strict';
import {createPlayerReadClient} from '../website/player-read-client.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';
import {createProductionGameApi,NOISE_CURFEW_EDGE_URL,RESTRICTION_ROUTE} from '../server/production-game-api.mjs';

const ROUTE={
 originAirportKey:'OURAIRPORTS:2220',destinationAirportKey:'OURAIRPORTS:2218',
 configurationId:3,departureUtc:'2026-11-06T15:00:00Z',arrivalUtc:'2026-11-06T17:00:00Z'
};
test('route planner has a real read-only aircraft and exact-time preflight interface',()=>{
 const html=routePlannerMarkup();
 for(const id of ['route-aircraft','route-preflight-departure-utc',
  'route-preflight-arrival-utc','route-preflight-status'])
  assert.ok(html.includes('id="'+id+'"'),id);
 assert.match(html,/UTC/);
 assert.match(html,/checked automatically/);
 assert.doesNotMatch(html,/id="route-preflight-check"/);
});
test('browser restriction check uses only authenticated same-origin proxy',async()=>{
 const requests=[];
 const auth={getAccessToken:async()=>('abc'.repeat(20))};
 const client=createPlayerReadClient({
   auth,origin:'https://airlinerra.com',enabled:true,
   fetchImpl:async(url,opts)=>{requests.push({url,opts});return Response.json({
    gameHardBlocked:true,gameScheduleOutcome:'BLOCKED_BY_GAME_AIRPORT_RUNWAY_OR_NOISE_RESTRICTION',
    origin:{outcome:'BLOCKED_AIRPORT_TIME_CURFEW'},destination:{outcome:'REVIEW_REQUIRED_NOT_FULLY_VERIFIED'},
    canActivateNormalFlight:false
   })}
 });
 const result=await client.noiseCurfewCheck(ROUTE);
 assert.equal(result.gameHardBlocked,true);
 assert.equal(result.canActivateNormalFlight,false);
 assert.equal(requests.length,1);
 assert.equal(requests[0].url,'https://airlinerra.com'+RESTRICTION_ROUTE);
 assert.equal(requests[0].opts.headers.authorization,'Bearer '+('abc'.repeat(20)));
 assert.equal(requests[0].opts.credentials,'omit');
 assert.deepEqual(JSON.parse(requests[0].opts.body),ROUTE);
});
test('backend forwards only to the pinned dedicated Edge restriction checker',async()=>{
 const calls=[],token='Bearer '+('a'.repeat(40));
 const service=createProductionGameApi({fetchImpl:async(url,opts)=>{
  calls.push({url,opts});
  return Response.json({decision:'BLOCKED',canActivateNormalFlight:false});
 }});
 const denied=await service(new Request('https://airlinerra.com'+RESTRICTION_ROUTE,{
  method:'POST',body:JSON.stringify(ROUTE),headers:{origin:'https://airlinerra.com'}}));
 assert.equal(denied.status,401);
 const allowed=await service(new Request('https://airlinerra.com'+RESTRICTION_ROUTE,{
  method:'POST',body:JSON.stringify(ROUTE),
  headers:{origin:'https://airlinerra.com',authorization:token,'content-type':'application/json'}
 }));
 assert.equal(allowed.status,200);
 assert.equal((await allowed.json()).canActivateNormalFlight,false);
 assert.equal(calls.length,1);
 assert.equal(calls[0].url,NOISE_CURFEW_EDGE_URL);
 assert.equal(calls[0].opts.headers['x-airlinerra-route'],RESTRICTION_ROUTE);
});
