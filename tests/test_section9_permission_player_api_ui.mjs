import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createSection9PermissionPlayerHandler,GAME_PERMISSION_PLAYER_PATH,
 GAME_PERMISSION_PLAYER_SQL
} from '../server/section9-permission-player-http.mjs';
import {
 createGamePermissionApplicationsClient,
 checkedGamePermissionStatus,GAME_PERMISSION_APPLICATIONS_ROUTE
} from '../website/game-permission-applications-client.mjs';

const ORIGIN='https://airlinerra.com';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const OWNER='11111111-1111-4111-8111-111111111111';
const REQUEST='33333333-3333-4333-8333-333333333333';
const TOKEN='not-a-real-verified-access-token-with-length';
const policy=(released=false,gameDay=null)=>({
 permissionCode:'AIR_OPERATOR_CERTIFICATE',title:'Air Operator Certificate',
 category:'airline',catalogueEnabled:released,releaseEnabled:released,
 gameFeeUsd:released?'150000.00':null,processingGameDays:released?7:null,
 validityGameDays:released?365:null,gameDay
});
const owned={
 worldId:1,airlineId:AIRLINE,applications:[],readOnly:true
};
const user={user:{id:OWNER,email_confirmed_at:'2026-11-01T00:00:00Z',
 is_anonymous:false},error:null};
function database({list=owned,policies=[policy()],blockedSubmit=null,
 ownerDenied=false}={}){
 const calls=[];let connects=0,releases=0;
 return {
  database:{async connect(){
   connects++;return {
    async query(sql,args=[]){
     calls.push({sql,args});
     if(ownerDenied&&sql.includes('section9_owned_game_permission_applications'))
      {const e=Error('SECTION9_PERMISSION_APPLICATION_LIST_NOT_OWNED');e.code='42501';throw e;}
     if(sql.includes('section9_owned_game_permission_applications'))
      return {rowCount:1,rows:[{result:list}]};
     if(sql===GAME_PERMISSION_PLAYER_SQL.policy)
      return {rowCount:policies.length,rows:policies};
     if(sql.includes('section9_submit_game_permission_application_v1'))
      return {rowCount:1,rows:[{result:blockedSubmit??{
       status:'blocked_unverified_world_or_game_day',submitted:false,
       charged:false,licenceIssued:false,flightActivated:false,
       ledgerPosted:false
      }}]};
     throw Error('Unexpected private SQL');
    },release(){releases++}
   };
  }},
  calls,counts:()=>({connects,releases})
 };
}
function req(body,{origin=ORIGIN,method='POST',
 path=GAME_PERMISSION_PLAYER_PATH,token=TOKEN,
 contentType='application/json',route=GAME_PERMISSION_PLAYER_PATH}={}){
 return new Request(origin+path,{
  method,headers:{'origin':origin,'authorization':'Bearer '+token,
   'content-type':contentType,'x-airlinerra-route':route},
  ...(method==='POST'?{body:JSON.stringify(body)}:{})
 });
}
function handler(database,auth=async()=>user){
 return createSection9PermissionPlayerHandler({
  database,verifyUserToken:auth,origin:ORIGIN
 });
}
test('player policy lookup is strictly behind authenticated airline ownership',async()=>{
 const d=database();
 const res=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
 assert.equal(res.status,200);
 const payload=await res.json();
 assert.deepEqual(payload,{
  status:'permission_applications_status',airlineId:AIRLINE,
  worldId:1,gameDay:null,canApply:false,
  policies:[{
   code:'AIR_OPERATOR_CERTIFICATE',title:'Air Operator Certificate',
   category:'airline',canApply:false,feeUsd:null,
   processingGameDays:null,validityGameDays:null
  }],
  applications:[],approvalByPlayer:false,ledgerPosted:false,
  flightActivated:false
 });
 assert.match(d.calls[0].sql,/section9_owned_game_permission_applications_v1/);
 assert.deepEqual(d.calls[0].args,[OWNER,AIRLINE]);
 assert.equal(d.calls[1].sql,GAME_PERMISSION_PLAYER_SQL.policy);
 assert.deepEqual(d.counts(),{connects:2,releases:2});
});
test('unowned airline gets 403 without reading catalogue',async()=>{
 const d=database({ownerDenied:true});
 const result=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
 assert.equal(result.status,403);
 assert.equal(d.calls.length,1);
});
test('missing/invalid authentication rejects before database',async()=>{
 const d=database();
 const tests=[
  req({action:'status',airlineId:AIRLINE},{token:'bad'}),
  req({action:'status',airlineId:AIRLINE},{origin:'https://fake.example'}),
  req({action:'status',airlineId:AIRLINE},{route:'/wrong'}),
  req({action:'status',airlineId:AIRLINE},{path:'/wrong'}),
  req({action:'status',airlineId:AIRLINE},{contentType:'text/plain'}),
  req({action:'approve',airlineId:AIRLINE})
 ];
 const h=handler(d.database,async()=>({user:null,error:{code:'invalid'}}));
 for(const t of tests){
  const response=await h(t);
  assert.ok([400,401,403,415].includes(response.status));
 }
 assert.equal(d.calls.length,0);
});
test('verified session but unknown review/action cannot reach private SQL',async()=>{
 const d=database();
 const h=handler(d.database);
 for(const body of [
  {action:'approve',airlineId:AIRLINE},
  {action:'revoke',airlineId:AIRLINE},
  {action:'status',airlineId:AIRLINE,ownerPlayerId:OWNER},
  {action:'apply',airlineId:AIRLINE,requestKey:REQUEST,
   permissionCode:'AIR_OPERATOR_CERTIFICATE',reviewStatus:'approved'},
  {action:'status',airlineId:'wrong'}
 ]){
  const r=await h(req(body));
  assert.equal(r.status,400);
 }
 assert.equal(d.calls.length,0);
});
test('valid application route uses independently verified player ID, never user body',async()=>{
 const d=database();
 const h=handler(d.database);
 const r=await h(req({action:'apply',airlineId:AIRLINE,
  requestKey:REQUEST,permissionCode:'AIR_OPERATOR_CERTIFICATE'}));
 assert.equal(r.status,200);
 const data=await r.json();
 assert.equal(data.status,'blocked_unverified_world_or_game_day');
 assert.equal(data.charged,false);
 assert.equal(d.calls.length,1);
 assert.deepEqual(d.calls[0].args,[
  OWNER,AIRLINE,REQUEST,'AIR_OPERATOR_CERTIFICATE',null,null,null
 ]);
});
test('releasing catalogue while World 1 clock closed still hides prices',async()=>{
 const d=database({policies:[policy(true,null)]});
 const result=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
 assert.equal(result.status,200);
 const obj=await result.json();
 assert.equal(obj.canApply,false);
 assert.equal(obj.policies[0].feeUsd,null);
});
test('a released, verified current game day exposes real fee and processing time',async()=>{
 const d=database({policies:[policy(true,'2000-11-09')]});
 const result=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
 assert.equal(result.status,200);
 const obj=await result.json();
 assert.equal(obj.canApply,true);
 assert.deepEqual([
  obj.policies[0].feeUsd,
  obj.policies[0].processingGameDays,
  obj.policies[0].validityGameDays],[150000,7,365]);
});
test('player API cannot be used to create an issue without release',async()=>{
 const d=database();
 const h=handler(d.database);
 const result=await h(req({action:'apply',airlineId:AIRLINE,
  requestKey:REQUEST,permissionCode:'AIR_OPERATOR_CERTIFICATE'}));
 const payload=await result.json();
 assert.equal(payload.licenceIssued,false);
 assert.equal(payload.ledgerPosted,false);
});
test('browser status client rejects a fake licence grant or unpublished fee',()=>{
 const valid={status:'permission_applications_status',airlineId:AIRLINE,
  worldId:1,gameDay:null,canApply:false,
  approvalByPlayer:false,ledgerPosted:false,flightActivated:false,
  policies:[{code:'AIR_OPERATOR_CERTIFICATE',
   title:'Air Operator Certificate',canApply:false,
   feeUsd:null,processingGameDays:null,validityGameDays:null}],
  applications:[]};
 assert.deepEqual(checkedGamePermissionStatus(valid,AIRLINE),valid);
 assert.throws(()=>checkedGamePermissionStatus({
  ...valid,policies:[{...valid.policies[0],feeUsd:150000}]
 },AIRLINE),/Unreleased licence policy/);
 assert.throws(()=>checkedGamePermissionStatus({
  ...valid,flightActivated:true
 },AIRLINE),/Unverified game licence application status/);
 assert.throws(()=>checkedGamePermissionStatus({
  ...valid,canApply:true
 },AIRLINE),/Inconsistent licence release status/);
});
test('browser posts only to the same-origin, authenticated player endpoint',async()=>{
 let captured;
 const client=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async(url,init)=>{
   captured={url,init};
   return Response.json({
    status:'blocked_game_permission_issuance_disabled',
    submitted:false,charged:false,licenceIssued:false,
    ledgerPosted:false,flightActivated:false
   });
  }
 });
 const r=await client.apply({airlineId:AIRLINE,requestKey:REQUEST,
  permissionCode:'AIR_OPERATOR_CERTIFICATE'});
 assert.equal(r.status,'blocked_game_permission_issuance_disabled');
 assert.equal(captured.url,ORIGIN+GAME_PERMISSION_APPLICATIONS_ROUTE);
 assert.equal(captured.init.method,'POST');
 assert.equal(captured.init.credentials,'omit');
 assert.match(captured.init.headers.authorization,/^Bearer /);
 assert.deepEqual(JSON.parse(captured.init.body),{
  action:'apply',airlineId:AIRLINE,requestKey:REQUEST,
  permissionCode:'AIR_OPERATOR_CERTIFICATE'
 });
});
test('route application requires exact game airport IDs and service type',async()=>{
 let n=0;
 const c=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async()=>{n++;return Response.json({
   status:'blocked_game_permission_issuance_disabled',
   submitted:false,charged:false,licenceIssued:false,
   ledgerPosted:false,flightActivated:false
  });}
 });
 await assert.rejects(c.apply({airlineId:AIRLINE,requestKey:REQUEST,
  permissionCode:'CABOTAGE',originAirportKey:'some city',
  destinationAirportKey:'OURAIRPORTS:4',serviceType:'passenger'}));
 assert.equal(n,0);
});
test('website mounts applications separately from reference-only licence planner',async()=>{
 const html=await readFile(new URL(
  '../website/private-player-app.html',import.meta.url),'utf8');
 const js=await readFile(new URL(
  '../website/player-app.mjs',import.meta.url),'utf8');
 const proxy=await readFile(new URL(
  '../server/production-game-api.mjs',import.meta.url),'utf8');
 const edge=await readFile(new URL(
  '../server/section9-permission-player-edge-entry.ts',import.meta.url),'utf8');
 assert.match(html,/id="game-permission-applications-root"/);
 assert.match(js,/loadGamePermissionApplications/);
 assert.match(js,/getPermissionApplicationsClient/);
 assert.match(proxy,/GAME_PERMISSION_EDGE_URL/);
 assert.match(edge,/createSection9PermissionPlayerHandler/);
 assert.doesNotMatch(edge,/decide_game_permission_application_v1|independentReviewSecret/);
});
