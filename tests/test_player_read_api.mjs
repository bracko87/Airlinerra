import test from 'node:test';import assert from 'node:assert/strict';
import {PLAYER_READ_SQL,createPlayerReadHandler} from '../server/player-read-service.mjs';
import {createPlayerReadClient,PLAYER_READ_API_ENABLED} from '../website/player-read-client.mjs';
const UUID='550e8400-e29b-41d4-a716-446655440000';
const ORIGIN='https://airlinerra.com';
const TOKEN='a'.repeat(32);
const baseRows={
 worlds:[{id:1,name:'World 01',state:'planned'},{id:2,name:'World 02',state:'planned'},{id:3,name:'World 03',state:'planned'}],
 countries:[{country_iso:'DE',airport_count:2},{country_iso:'FR',airport_count:1}],
 airlines:[],
 airports:[{airport_key:'OURAIRPORTS:111',airport_name:'Berlin Airport',airport_code:'EDDB',country_iso:'DE',municipality:'Berlin'}]
};
function make({enabled=true,verified=true,rows=baseRows}={}){
 const queries=[];let connected=0,released=0,verifiedCalls=0;
 const db={connect:async()=>{connected++;return {
   query:async(sql,params)=>{queries.push({sql,params});if(sql===PLAYER_READ_SQL.worlds)return {rows:rows.worlds};
     if(sql===PLAYER_READ_SQL.countries)return {rows:rows.countries};
     if(sql===PLAYER_READ_SQL.airlines)return {rows:rows.airlines};
     if(sql===PLAYER_READ_SQL.airports)return {rows:rows.airports};
     throw Error('Unexpected query');},
   release:()=>{released++;}
 };}};
 const verifyUserToken=async()=>{verifiedCalls++;return verified?
   {user:{id:UUID,email_confirmed_at:'2026-10-28T10:00:00Z'}}:{user:null,error:'invalid'};};
 return {handler:createPlayerReadHandler({enabled,verifyUserToken,database:db}),counts:()=>({connected,released,verifiedCalls,queries})};
}
const request=(path,body={},headers={})=>new Request(ORIGIN+path,{
 method:'POST',headers:{origin:ORIGIN,authorization:'Bearer '+TOKEN,'content-type':'application/json',...headers},body:JSON.stringify(body)
});
test('read-only service is closed by default, before Auth or database',async()=>{
 const s=make({enabled:false});
 const response=await s.handler(request('/api/v1/player/overview'));
 assert.equal(response.status,503);assert.deepEqual(s.counts(),{connected:0,released:0,verifiedCalls:0,queries:[]});
});
test('verified managers receive real world, airport count and only owned airline query',async()=>{
 const s=make();
 const response=await s.handler(request('/api/v1/player/overview'));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.deepEqual(data.worlds.map(w=>w.state),['planned','planned','planned']);
 assert.equal(data.airportsTotal,3);assert.deepEqual(data.airlines,[]);
 assert.equal(data.gameplayAvailable,false);
 assert.deepEqual(s.counts().queries[2].params,[UUID]);
 assert.equal(s.counts().released,1);
});
test('search is country-scoped, parameterized, bounded and never writes to database',async()=>{
 const s=make();
 const response=await s.handler(request('/api/v1/player/airports',{countryIso:'DE',search:'Berlin',offset:0}));
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.airports[0].name,'Berlin Airport');
 assert.equal(s.counts().queries[0].params[1],'Berlin');
 for(const sql of Object.values(PLAYER_READ_SQL)){
   assert.match(sql,/^select /i);
   assert.doesNotMatch(sql,/\b(insert|update|delete|create|grant|alter)\b/i);
 }
});
test('denies missing Auth, external origin, invalid inputs and never connects first',async()=>{
 const bad=make({verified:false});
 assert.equal((await bad.handler(request('/api/v1/player/overview'))).status,401);
 assert.equal(bad.counts().connected,0);
 const s=make();
 assert.equal((await s.handler(request('/api/v1/player/overview',{}, {origin:'https://evil.example'}))).status,403);
 for(const args of [
   {countryIso:'D'},{countryIso:'DE',offset:100000},
   {countryIso:'DE',search:'%_%'},{countryIso:'DE',playerId:UUID}
 ]){
  assert.equal((await s.handler(request('/api/v1/player/airports',args))).status,400);
 }
 assert.equal(s.counts().connected,0);
});
test('client forwards bounded read requests with verified session only',async()=>{
 assert.equal(PLAYER_READ_API_ENABLED,false);
 let calls=[];
 const auth={getAccessToken:async()=>TOKEN};
 const client=createPlayerReadClient({auth,origin:ORIGIN,enabled:true,fetchImpl:async(url,options)=>{
   calls.push([url,options]);return new Response(JSON.stringify({worlds:[]}),{
    status:200,headers:{'content-type':'application/json'}
   });
 }});
 assert.deepEqual(await client.overview(),{worlds:[]});
 assert.equal(calls[0][0],ORIGIN+'/api/v1/player/overview');
 assert.equal(calls[0][1].headers.authorization,'Bearer '+TOKEN);
 assert.equal(calls[0][1].credentials,'omit');
 await assert.rejects(createPlayerReadClient({auth,origin:ORIGIN}).overview(),/not deployed/);
 assert.equal(calls.length,1);
});

test('request bodies exceeding 512 bytes are rejected without database contact',async()=>{
 const s=make();
 const extra='z'.repeat(800);
 const response=await s.handler(request('/api/v1/player/overview',{extra}));
 assert.equal(response.status,400);
 assert.equal(s.counts().connected,0);
});

test('owner-approved, verified premium is calculated server-side from private entitlement and verified account email',()=>{
 assert.match(PLAYER_READ_SQL.airlines,/account_entitlements/);
 assert.match(PLAYER_READ_SQL.airlines,/owner_premium_email_reservations/);
 assert.match(PLAYER_READ_SQL.airlines,/email_confirmed_at is not null/);
 assert.match(PLAYER_READ_SQL.airlines,/owner_player_id=\$1::uuid/);
});
