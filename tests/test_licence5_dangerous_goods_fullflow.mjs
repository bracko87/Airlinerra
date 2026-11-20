import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9PermissionPlayerHandler,GAME_PERMISSION_PLAYER_PATH} from '../server/section9-permission-player-http.mjs';
import {createGamePermissionApplicationsClient} from '../website/game-permission-applications-client.mjs';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const OWNER='11111111-1111-4111-8111-111111111111';
const REQUEST='33333333-3333-4333-8333-333333333333';
const ORIGIN='https://airlinerra.com';
const auth=async()=>({user:{id:OWNER,email_confirmed_at:'2026-11-01T00:00:00Z',is_anonymous:false},error:null});
const mockDb=(options={})=>{
 const calls=[];
 return {calls,async connect(){return {release(){},async query(sql,args=[]){
  calls.push({sql,args});
  if(sql.includes('section9_owned_game_permission_applications_v1')){
   if(options.unowned){const e=Error('NOT_OWNED');e.code='42501';throw e;}
   return {rowCount:1,rows:[{result:{worldId:1,airlineId:AIRLINE,applications:[],readOnly:true}}]};
  }
  if(sql.includes('licence5_submit_dg_application_v1'))
   return {rowCount:1,rows:[{result:options.unsafe?{status:'SUBMITTED',charged:true,submitted:true,issued:false}:
    {status:'NOT_RELEASED',charged:false,submitted:false,issued:false}}]};
  if(sql.includes('licence5_dg_readiness_v1')&&sql.includes('licence5_dg_operator_scope_v1'))
   return {rowCount:1,rows:[{
    readiness:{airlineId:AIRLINE,eligible:false,issues:['VALID_CARGO_LICENCE3_REQUIRED']},
    scope:{authorized:false,dangerousGoodsShipmentAuthorized:false},
    released:false,application_status:null,due_game_day:null
   }]};
  throw Error('Unexpected SQL: '+sql);
 }};}};
};
const request=body=>new Request(ORIGIN+GAME_PERMISSION_PLAYER_PATH,{
 method:'POST',headers:{origin:ORIGIN,'x-airlinerra-route':GAME_PERMISSION_PLAYER_PATH,
 'content-type':'application/json',authorization:'Bearer valid-player-access-token-123456789'},
 body:JSON.stringify(body)
});
const handler=db=>createSection9PermissionPlayerHandler({database:db,verifyUserToken:auth,origin:ORIGIN});
const status={
 status:'licence5_dg_status',airlineId:AIRLINE,worldId:1,readOnly:true,issued:false,
 canApply:false,operatorScopeApproved:false,shipmentAuthorization:false,
 approvedCommodityClasses:[],applicationStatus:null,dueGameDay:null,
 issues:['VALID_CARGO_LICENCE3_REQUIRED'],feeUsd:60000,processingGameDays:5,
 flightActivated:false
};
const reply={status:'NOT_RELEASED',applicationId:null,dueGameDay:null,submitted:false,
 feeCharged:false,licenceIssued:false,flightActivated:false};
test('Licence 5 API reads owner-verified release-locked status, with zero authorized commodities',async()=>{
 const db=mockDb();const r=await handler(db)(request({action:'licence5_status',airlineId:AIRLINE}));
 assert.equal(r.status,200);
 assert.deepEqual(await r.json(),status);
 assert.equal(db.calls.length,2);
 assert.deepEqual(db.calls[0].args,[OWNER,AIRLINE]);
 assert.deepEqual(db.calls[1].args,[OWNER,AIRLINE]);
});
test('Licence 5 API is owner-verified, rejects spoofed fields and cannot grant approvals',async()=>{
 const db=mockDb();const serve=handler(db);
 for(const body of [
  {action:'licence5_submit',airlineId:AIRLINE,requestKey:REQUEST,ownerPlayerId:OWNER},
  {action:'licence5_submit',airlineId:AIRLINE,requestKey:'invalid'},
  {action:'licence5_status',airlineId:AIRLINE,approvedClasses:['9']},
  {action:'licence5_approve',airlineId:AIRLINE,requestKey:REQUEST}
 ])assert.equal((await serve(request(body))).status,400);
 assert.equal(db.calls.length,0);
 const r=await serve(request({action:'licence5_submit',airlineId:AIRLINE,requestKey:REQUEST}));
 assert.equal(r.status,200);assert.deepEqual(await r.json(),reply);
 assert.deepEqual(db.calls[1].args,[OWNER,AIRLINE,REQUEST]);
 const unowned=mockDb({unowned:true});
 assert.equal((await handler(unowned)(request({action:'licence5_submit',airlineId:AIRLINE,requestKey:REQUEST}))).status,403);
 const unsafe=mockDb({unsafe:true});
 assert.equal((await handler(unsafe)(request({action:'licence5_submit',airlineId:AIRLINE,requestKey:REQUEST}))).status,503);
});
test('Licence 5 client rejects forged shipment rights and forged payment',async()=>{
 const seen=[];let replies=[status,reply];
 const client=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:{getAccessToken:async()=>'valid-player-access-token-123456789'},
  fetchImpl:async(_url,opts)=>{seen.push(JSON.parse(opts.body));
   return {ok:true,status:200,json:async()=>replies.shift()};}
 });
 assert.deepEqual(await client.dangerousGoodsLicence5Status(AIRLINE),status);
 assert.deepEqual(await client.submitDangerousGoodsLicence5({airlineId:AIRLINE,requestKey:REQUEST}),reply);
 assert.deepEqual(seen,[{action:'licence5_status',airlineId:AIRLINE},{action:'licence5_submit',airlineId:AIRLINE,requestKey:REQUEST}]);
 const bad=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:{getAccessToken:async()=>'valid-player-access-token-123456789'},
  fetchImpl:async()=>({ok:true,status:200,json:async()=>({...status,
   shipmentAuthorization:true,approvedCommodityClasses:['9']})})
 });
 await assert.rejects(()=>bad.dangerousGoodsLicence5Status(AIRLINE),/Unverified Dangerous Goods Licence 5 status/);
 const badFee=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:{getAccessToken:async()=>'valid-player-access-token-123456789'},
  fetchImpl:async()=>({ok:true,status:200,json:async()=>({...reply,feeCharged:true})})
 });
 await assert.rejects(()=>badFee.submitDangerousGoodsLicence5({airlineId:AIRLINE,requestKey:REQUEST}),/Unsafe Dangerous Goods Licence 5/);
});
test('Five-day, single-charge, fail-closed database contracts exist',async()=>{
 const read=name=>readFile(new URL('../supabase/migrations/'+name,import.meta.url),'utf8');
 const app=await read('20261120120000_licence5_dg_atomic_application.sql');
 const eligibility=await read('20261120115500_licence5_dg_readiness.sql');
 const guarded=await read('20261120120500_licence5_dg_no_blanket_rights.sql');
 assert.match(app,/fee_usd numeric NOT NULL DEFAULT 60000 CHECK\(fee_usd=60000\)/);
 assert.match(app,/CHECK\(due_game_day=submitted_game_day\+5\)/);
 assert.match(app,/cash_usd=cash_usd-60000/);
 assert.match(app,/VALUES\(app.airline_id,'EXPENSE',-60000\)/);
 assert.match(app,/UNIQUE\(airline_id,request_key\)/);
 assert.match(app,/issuance_enabled AND fee_ledger_verified AND reviewer_verified/);
 assert.match(eligibility,/VALID_CARGO_LICENCE3_REQUIRED/);
 assert.match(eligibility,/SAFETY_BELOW_70_FOR_LICENCE5/);
 assert.match(guarded,/dangerousGoodsShipmentAuthorized',false/);
 assert.match(guarded,/licence5_review_due_dg_game_applications_v1\(25\)/);
});
