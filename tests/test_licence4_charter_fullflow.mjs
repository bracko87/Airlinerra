import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9PermissionPlayerHandler,GAME_PERMISSION_PLAYER_PATH}
 from '../server/section9-permission-player-http.mjs';
import {createGamePermissionApplicationsClient}
 from '../website/game-permission-applications-client.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const OWNER='11111111-1111-4111-8111-111111111111';
const REQUEST='33333333-3333-4333-8333-333333333333';
const ORIGIN='https://airlinerra.com';
const goodAuth=async()=>({user:{id:OWNER,email_confirmed_at:'2026-11-01T00:00:00Z',is_anonymous:false},error:null});
const mockDb=({notOwned=false,invalid=false}={})=>{
 const calls=[];
 return {calls,async connect(){return {release(){},
 async query(sql,args=[]){
  calls.push({sql,args});
  if(sql.includes('section9_owned_game_permission_applications_v1')){
   if(notOwned){const e=Error('NOT_OWNED');e.code='42501';throw e;}
   return {rowCount:1,rows:[{result:{worldId:1,airlineId:AIRLINE,applications:[],readOnly:true}}]};
  }
  if(sql.includes('licence4_submit_charter_application_v1'))
   return {rowCount:1,rows:[{result:invalid?
     {status:'SUBMITTED',charged:true,submitted:true,issued:false}:
     {status:'NOT_RELEASED',charged:false,submitted:false,issued:false}}]};
  if(sql.includes('licence4_charter_readiness_v1')&&sql.includes('licence4_charter_flight_scope_v1'))
   return {rowCount:1,rows:[{
    readiness:{airlineId:AIRLINE,issues:['CHARTER_VIP_LICENCE_ISSUANCE_NOT_RELEASED'],eligible:false},
    scope:{authorized:false},released:false,application_status:null,due_game_day:null
   }]};
  throw Error('Unexpected SQL:'+sql);
 }};}};
};
const request=(body,headers={})=>new Request(ORIGIN+GAME_PERMISSION_PLAYER_PATH,{
 method:'POST',headers:{'origin':ORIGIN,'x-airlinerra-route':GAME_PERMISSION_PLAYER_PATH,
 'content-type':'application/json','authorization':'Bearer valid-player-access-token-123456789',
 ...headers},body:JSON.stringify(body)
});
const handler=database=>createSection9PermissionPlayerHandler({
 database,verifyUserToken:goodAuth,origin:ORIGIN
});
test('Charter/VIP Licence 4 status is verified-owner scoped and keeps unreleased permission closed',async()=>{
 const db=mockDb();
 const r=await handler(db)(request({action:'licence4_status',airlineId:AIRLINE}));
 assert.equal(r.status,200);
 assert.deepEqual(await r.json(),{
  status:'licence4_charter_status',airlineId:AIRLINE,worldId:1,readOnly:true,
  issued:false,canApply:false,applicationStatus:null,dueGameDay:null,
  issues:['CHARTER_VIP_LICENCE_ISSUANCE_NOT_RELEASED'],feeUsd:40000,
  processingGameDays:3,flightActivated:false
 });
 assert.equal(db.calls.length,2);
 assert.deepEqual(db.calls[0].args,[OWNER,AIRLINE]);
 assert.deepEqual(db.calls[1].args,[OWNER,AIRLINE]);
});
test('Charter/VIP submission rejects spoofed fields and is a no-charge action while unreleased',async()=>{
 const db=mockDb();const serve=handler(db);
 for(const body of [
  {action:'licence4_submit',airlineId:AIRLINE,requestKey:REQUEST,ownerPlayerId:OWNER},
  {action:'licence4_submit',airlineId:AIRLINE,requestKey:'bad'},
  {action:'licence4_status',airlineId:AIRLINE,requestedStatus:'issued'},
  {action:'licence4_approve',airlineId:AIRLINE,requestKey:REQUEST}
 ]){
  assert.equal((await serve(request(body))).status,400);
 }
 assert.equal(db.calls.length,0);
 const r=await serve(request({action:'licence4_submit',airlineId:AIRLINE,requestKey:REQUEST}));
 assert.equal(r.status,200);
 assert.deepEqual(await r.json(),{
  status:'NOT_RELEASED',applicationId:null,dueGameDay:null,submitted:false,
  feeCharged:false,licenceIssued:false,flightActivated:false
 });
 assert.equal(db.calls.length,2);
 assert.deepEqual(db.calls[1].args,[OWNER,AIRLINE,REQUEST]);
});
test('unowned airline and unsafe charter charge are never surfaced to player',async()=>{
 const denied=mockDb({notOwned:true});
 assert.equal((await handler(denied)(request({action:'licence4_submit',airlineId:AIRLINE,requestKey:REQUEST}))).status,403);
 assert.equal(denied.calls.length,1);
 const bad=mockDb({invalid:true});
 assert.equal((await handler(bad)(request({action:'licence4_submit',airlineId:AIRLINE,requestKey:REQUEST}))).status,503);
});
test('charter browser client refuses fabricated fees and issuance',async()=>{
 const replies=[
  {status:'licence4_charter_status',airlineId:AIRLINE,worldId:1,readOnly:true,issued:false,
   canApply:false,applicationStatus:null,dueGameDay:null,
   issues:['CHARTER_VIP_LICENCE_ISSUANCE_NOT_RELEASED'],feeUsd:40000,
   processingGameDays:3,flightActivated:false},
  {status:'NOT_RELEASED',applicationId:null,dueGameDay:null,submitted:false,
   feeCharged:false,licenceIssued:false,flightActivated:false}
 ];
 const seen=[];
 const c=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:{getAccessToken:async()=>'valid-player-access-token-123456789'},
  fetchImpl:async(_url,opts)=>{
   seen.push(JSON.parse(opts.body));
   return {ok:true,status:200,json:async()=>replies.shift()};
  }
 });
 assert.equal((await c.charterLicence4Status(AIRLINE)).canApply,false);
 assert.equal((await c.submitCharterLicence4({airlineId:AIRLINE,requestKey:REQUEST})).feeCharged,false);
 assert.deepEqual(seen[0],{action:'licence4_status',airlineId:AIRLINE});
 assert.deepEqual(seen[1],{action:'licence4_submit',airlineId:AIRLINE,requestKey:REQUEST});
 const unsafe=createGamePermissionApplicationsClient({
  origin:ORIGIN,auth:{getAccessToken:async()=>'valid-player-access-token-123456789'},
  fetchImpl:async()=>({ok:true,status:200,json:async()=>({
   status:'SUBMITTED',submitted:true,applicationId:REQUEST,dueGameDay:'2026-11-22',
   feeCharged:true,licenceIssued:true,flightActivated:false
  })})
 });
 await assert.rejects(()=>unsafe.submitCharterLicence4({airlineId:AIRLINE,requestKey:REQUEST}),
 /Unsafe Charter\\/VIP Licence 4/);
});
test('Charter/VIP licence migration preserves one-time fee, 3 game days and flight gating',async()=>{
 const read=name=>readFile(new URL('../supabase/migrations/'+name,import.meta.url),'utf8');
 const issue=await read('20261120101000_licence4_charter_atomic_application.sql');
 const guard=await read('20261120103000_licence4_charter_activation_guard_cron.sql');
 assert.match(issue,/fee_usd numeric NOT NULL DEFAULT 40000 CHECK\(fee_usd=40000\)/);
 assert.match(issue,/CHECK\(due_game_day=submitted_game_day\+3\)/);
 assert.match(issue,/cash_usd=cash_usd-40000/);
 assert.match(issue,/amount_usd\)\s+VALUES\(app.airline_id,'EXPENSE',-40000\)/);
 assert.match(issue,/UNIQUE REFERENCES airlinerra_game.airline_ledger/);
 assert.match(issue,/issuance_enabled AND fee_ledger_verified AND reviewer_verified/);
 assert.match(issue,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(guard,/CHARTER_VIP_OPERATIONS_LICENCE4_REQUIRED_FOR_ACTIVATION/);
 assert.match(guard,/licence4_charter_schedule_activation_guard_v1/);
 assert.match(guard,/licence4_review_due_charter_game_applications_v1\(25\)/);
});
