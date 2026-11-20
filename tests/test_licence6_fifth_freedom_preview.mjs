import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9PermissionPlayerHandler,GAME_PERMISSION_PLAYER_PATH} from '../server/section9-permission-player-http.mjs';
import {createGamePermissionApplicationsClient} from '../website/game-permission-applications-client.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const OWNER='11111111-1111-4111-8111-111111111111';
const HOME='OURAIRPORTS:4610',STOP='OURAIRPORTS:29001',FINAL='OURAIRPORTS:298716';
const ORIGIN='https://airlinerra.com';
const auth=async()=>({user:{id:OWNER,email_confirmed_at:'2026-11-01T00:00:00Z',is_anonymous:false},error:null});
const readiness={
 status:'LICENCE6_FIFTH_FREEDOM_READINESS',airlineId:AIRLINE,
 permissionCode:'FIFTH_FREEDOM',serviceType:'passenger',
 homeCountry:'RS',firstForeignCountry:'FR',secondForeignCountry:'IT',
 homeAirport:HOME,foreignStop:STOP,foreignDestination:FINAL,
 gameDay:'2026-11-20',feeUsd:null,proposedFeeMinUsd:100000,
 proposedFeeMaxUsd:250000,processingGameDays:7,
 eligible:false,canApply:false,
 issues:['MARKET_SPECIFIC_FEE_UNDECIDED','LICENCE6_NOT_RELEASED'],
 routeAuthorized:false,foreignSegmentAuthorized:false,flightActivated:false
};
const expected={
 status:'licence6_route_preview',airlineId:AIRLINE,worldId:1,
 homeAirport:HOME,foreignStop:STOP,foreignDestination:FINAL,
 homeCountry:'RS',firstForeignCountry:'FR',secondForeignCountry:'IT',
 serviceType:'passenger',gameDay:'2026-11-20',feeUsd:null,
 proposedFeeMinUsd:100000,proposedFeeMaxUsd:250000,processingGameDays:7,
 canApply:false,issues:readiness.issues,routeAuthorized:false,
 foreignSegmentAuthorized:false,flightActivated:false
};
const body={action:'licence6_preview',airlineId:AIRLINE,
 homeAirport:HOME,foreignStop:STOP,foreignDestination:FINAL,
 serviceType:'passenger'};
const makeDb=({unowned=false,unsafe=false}={})=>{
 const calls=[];
 return {calls,async connect(){return {release(){},async query(sql,args=[]){
  calls.push({sql,args});
  if(sql.includes('section9_owned_game_permission_applications_v1')){
   if(unowned){const e=Error('NOT_OWNED');e.code='42501';throw e;}
   return {rowCount:1,rows:[{result:{airlineId:AIRLINE,worldId:1,
    applications:[],readOnly:true}}]};
  }
  if(sql.includes('licence6_fifth_readiness_v1')){
   return {rowCount:1,rows:[{result:unsafe?{...readiness,routeAuthorized:true}:readiness}]};
  }
  throw Error('Unexpected query: '+sql);
 }};}};
};
const request=payload=>new Request(ORIGIN+GAME_PERMISSION_PLAYER_PATH,{
 method:'POST',headers:{origin:ORIGIN,'x-airlinerra-route':GAME_PERMISSION_PLAYER_PATH,
 'content-type':'application/json',authorization:'Bearer valid-player-access-token-123456789'},
 body:JSON.stringify(payload)});
const handler=db=>createSection9PermissionPlayerHandler({
 database:db,verifyUserToken:auth,origin:ORIGIN
});
test('Licence 6 is a private, game-only route preview without any charge',async()=>{
 const db=makeDb(),res=await handler(db)(request(body));
 assert.equal(res.status,200);
 assert.deepEqual(await res.json(),expected);
 assert.equal(db.calls.length,2);
 assert.deepEqual(db.calls[0].args,[OWNER,AIRLINE]);
 assert.deepEqual(db.calls[1].args,[OWNER,AIRLINE,HOME,STOP,FINAL,'passenger']);
});
test('Licence 6 preview rejects spoofed grants, invalid airports and other player companies',async()=>{
 const db=makeDb();for(const payload of [
 {...body,approved:true},{...body,feeUsd:100000},
 {...body,foreignStop:'bad<script>'},{...body,serviceType:'vip'},
 {...body,action:'licence6_approve'}]){
  assert.equal((await handler(db)(request(payload))).status,400);
 }
 assert.equal(db.calls.length,0);
 const foreign=makeDb({unowned:true});
 assert.equal((await handler(foreign)(request(body))).status,403);
 const unsafe=makeDb({unsafe:true});
 assert.equal((await handler(unsafe)(request(body))).status,503);
});
test('Browser rejects fabricated Fifth Freedom rights or fees outside reviewed band',async()=>{
 const token={getAccessToken:async()=>'valid-player-access-token-123456789'};
 const client=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:token,fetchImpl:async(_url,options)=>{
   assert.deepEqual(JSON.parse(options.body),body);
   return {ok:true,status:200,json:async()=>expected};
  }
 });
 assert.deepEqual(await client.licence6FifthFreedomPreview(body),expected);
 const wrong=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:token,fetchImpl:async()=>({ok:true,status:200,
    json:async()=>({...expected,foreignSegmentAuthorized:true,feeUsd:95000})})
 });
 await assert.rejects(()=>wrong.licence6FifthFreedomPreview(body),
  /Unsafe Fifth Freedom route preview/);
});
test('Fifth Freedom policies are verified market-specific and issuance hard-locked',async()=>{
 const read=p=>readFile(new URL('../supabase/migrations/'+p,import.meta.url),'utf8');
 const migration=await read('20261120130000_licence6_fifth_freedom_readiness.sql');
 const correction=await read('20261120130500_licence6_approved_network_dependency.sql');
 assert.match(migration,/fee_usd numeric CHECK\(fee_usd BETWEEN 100000 AND 250000\)/);
 assert.match(migration,/processing_game_days=7/);
 assert.match(migration,/country_rights_verified boolean NOT NULL DEFAULT false/);
 assert.match(migration,/licence6_fifth_hard_release_lock_v1/);
 assert.match(migration,/HOME_CONNECTED_THREE_COUNTRY_ITINERARY_REQUIRED/);
 assert.match(migration,/INDEPENDENT_FIFTH_FREEDOM_MARKET_PROOF_REQUIRED/);
 assert.match(migration,/foreignSegmentAuthorized',false/);
 assert.match(correction,/l2.status=''approved''/);
 const view=await readFile(new URL('../website/game-permission-applications-view.mjs',import.meta.url),'utf8');
 assert.match(view,/Licence 6 — Fifth Freedom Rights/);
 assert.match(view,/licence6FifthFreedomPreview/);
});
