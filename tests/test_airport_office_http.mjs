import test from 'node:test';
import assert from 'node:assert/strict';
import {parseOfficeRequest,createAirportOfficeHttpHandler,AIRPORT_OFFICE_API_PATH} from '../server/airport-office-http-handler.mjs';
import {createCanonicalGameApi,CANONICAL_GAME_API_PATHS} from '../server/canonical-game-api.mjs';
const ORIGIN='http://localhost:5188';
const TOKEN='Bearer owner-token-with-22-characters';
const payload={operation:'save',worldId:1,airportKey:'OURAIRPORTS:4344',type:'station'};
const request=(body=payload,headers={})=>({
 path:AIRPORT_OFFICE_API_PATH,method:'POST',
 headers:{origin:ORIGIN,'content-type':'application/json',authorization:TOKEN,...headers},
 body:JSON.stringify(body)
});
function fixture(){
 const calls=[];
 const officeService={
  list:async args=>{calls.push(['list',args]);return [{key:'OURAIRPORTS:4344',name:'Sarajevo',type:'station',status:'draft'}]},
  save:async args=>{calls.push(['save',args]);return {key:args.airportKey,type:args.type,status:'draft',newlyCreated:true}},
  remove:async args=>{calls.push(['remove',args]);return {removed:true}}
 };
 return {handler:createAirportOfficeHttpHandler({officeService,origin:ORIGIN,enabled:true}),calls};
}
test('office API is closed by default and registered without enabling other game writes',async()=>{
 const f=fixture();
 const disabled=createAirportOfficeHttpHandler({officeService:{
  list:async()=>{throw Error('No backend calls allowed')},save:async()=>{},remove:async()=>{}
 },origin:ORIGIN});
 assert.equal((await disabled(request())).status,503);
 assert.ok(CANONICAL_GAME_API_PATHS.includes(AIRPORT_OFFICE_API_PATH));
 const api=createCanonicalGameApi({
  enabled:true,origin:ORIGIN,
  verifyUserToken:async()=>{throw Error('No auth needed when disabled')},
  database:{connect:async()=>{throw Error('No DB when disabled')}}
 });
 const response=await api(new Request(ORIGIN+AIRPORT_OFFICE_API_PATH,{
  method:'POST',headers:request().headers,body:request().body
 }));
 assert.equal(response.status,503);
 assert.equal(f.calls.length,0);
});
test('office HTTP validates fixed fields, size, origins and token before service',async()=>{
 const f=fixture();
 for(const r of [
  request(payload,{origin:'https://evil.example'}),
  request(payload,{authorization:'Bearer bad'}),
  request(payload,{'content-type':'text/plain'}),
  request({...payload,airlineId:'forged'}),
  request({...payload,worldId:4}),
  request({...payload,airportKey:'not-approved'}),
  request({operation:'list',worldId:1,airportKey:'OURAIRPORTS:4344'}),
  {...request(),body:' '.repeat(513)},
  {...request(),method:'GET'},
  {...request(),path:'/api/v1/player/airports'}
 ]){
  const response=await f.handler(r);
  assert.ok(response.status>=400,'Untrusted request rejected');
 }
 assert.equal(f.calls.length,0);
});
test('office HTTP passes only authenticated, strictly parsed action data',async()=>{
 const f=fixture();
 let response=await f.handler(request());
 assert.equal(response.status,201);
 assert.equal(JSON.parse(response.body).office.status,'draft');
 assert.deepEqual(f.calls[0],['save',{accessToken:TOKEN.slice(7),worldId:1,airportKey:'OURAIRPORTS:4344',type:'station'}]);
 response=await f.handler(request({operation:'list',worldId:1}));
 assert.equal(response.status,200);
 assert.equal(JSON.parse(response.body).offices.length,1);
 response=await f.handler(request({operation:'remove',worldId:1,airportKey:'OURAIRPORTS:4344'}));
 assert.equal(response.status,200);
 assert.equal(JSON.parse(response.body).removed,true);
});
test('office HTTP redacts DB errors, never leaks secrets or exposes SQL',async()=>{
 const service={
  list:async()=>{throw Error('private SELECT secret-key')},
  save:async()=>{throw Error('private INSERT secret-key')},
  remove:async()=>{throw Error('private DELETE secret-key')}
 };
 const h=createAirportOfficeHttpHandler({officeService:service,origin:ORIGIN,enabled:true});
 const result=await h(request());
 assert.equal(result.status,503);
 assert.doesNotMatch(result.body,/SELECT|INSERT|secret-key/);
});
test('office request decoder accepts exact operations only',()=>{
 assert.deepEqual(parseOfficeRequest(JSON.stringify({operation:'list',worldId:1})),
  {operation:'list',worldId:1});
 assert.throws(()=>parseOfficeRequest('{}'));
 assert.throws(()=>parseOfficeRequest(JSON.stringify({operation:'activate',worldId:1})));
 assert.throws(()=>parseOfficeRequest(JSON.stringify({...payload,price:0})));
});
