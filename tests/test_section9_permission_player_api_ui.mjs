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
 gameFeeUsd:released?'10000.00':null,processingGameDays:released?3:null,
 validityGameDays:released?365:null,gameDay
});

const L2_MARKETS=[['L2-EU','European Union and EEA',4],['L2-US','United States',4],
 ['L2-UK','United Kingdom',2],['L2-JP','Japan',2]];
const licence2Rows=L2_MARKETS.flatMap(([marketCode,marketName,total])=>
 Array.from({length:total},(_,index)=>{
  const level=index+1,eu=marketCode==='L2-EU';
  return {marketCode,marketName,level,
   maxDirectedRoutes:eu?[20,50,150,null][index]:null,
   maxAirportCategory:eu?['Medium','Large','Major Hub','Mega Hub'][index]:null,
   quotaApproved:eu,issuanceEnabled:false,enforcementEnabled:false,
   permitStatus:'not_issued',permitLevel:null,routesUsed:0,applicationStatus:null,
   draftApplicationId:null,requestedLevel:null,draftIssues:null};
 }));
const licence2Expected={readOnly:true,applicationsOpen:false,
 marketLevels:licence2Rows.map(r=>({
  marketCode:r.marketCode,marketName:r.marketName,level:r.level,
  directedRouteLimit:r.quotaApproved?r.maxDirectedRoutes:null,
  maxAirportCategory:r.quotaApproved?r.maxAirportCategory:null,
  quotaApproved:r.quotaApproved,permitStatus:r.permitStatus,permitLevel:r.permitLevel,
  directedRoutesUsed:r.routesUsed,applicationStatus:r.applicationStatus,
  draftApplicationId:r.draftApplicationId,requestedLevel:r.requestedLevel,draftIssues:r.draftIssues,
  canApply:false,feeUsd:null,processingGameDays:null
 }))};

const owned={
 worldId:1,airlineId:AIRLINE,applications:[],readOnly:true
};
const aocStatus={
 airlineId:AIRLINE,worldId:1,status:'planned_not_released',
 verifiedCompanyRegistry:false,issued:false,safetyRating:null,readOnly:true
};
const user={user:{id:OWNER,email_confirmed_at:'2026-11-01T00:00:00Z',
 is_anonymous:false},error:null};
function database({list=owned,policies=[policy()],blockedSubmit=null,
 ownerDenied=false,l2=licence2Rows}={}){
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
     if(sql.includes('licence2_refresh_owner_draft_v1'))
      return {rowCount:1,rows:[{result:{
       status:'DRAFT_READINESS_REFRESHED',refreshed:true,
       applicationId:REQUEST,eligible:false,
       issues:['ACTIVE_OWN_AOC_NOT_VERIFIED'],
       feeCharged:false,rightsGranted:false,flightsActivated:false}}]};
     if(sql.includes('licence2_withdraw_owner_draft_v1'))
      return {rowCount:1,rows:[{result:{
       status:'DRAFT_WITHDRAWN',withdrawn:true,applicationId:REQUEST,
       feeCharged:false,rightsGranted:false,flightsActivated:false}}]};
     if(sql.includes('licence2_stage_owner_application_v1'))
      return {rowCount:1,rows:[{result:{
       status:'APPLICATION_DRAFT_STAGED_NOT_SUBMITTED',created:true,
       applicationId:REQUEST,submitted:false,feeCharged:false,
       rightsGranted:false,flightsActivated:false}}]};
     if(sql===GAME_PERMISSION_PLAYER_SQL.licence2)
      return {rowCount:l2.length,rows:l2};
     if(sql===GAME_PERMISSION_PLAYER_SQL.policy)
      return {rowCount:policies.length,rows:policies};
     if(sql.includes('section9_verified_permission_game_day_v1()::text'))
      return {rowCount:1,rows:[{game_day:null}]};
     if(sql.includes('section9_aoc_owned_status_v1'))
      return {rowCount:1,rows:[{result:aocStatus}]};
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
  applications:[],aocStatus,licence2:licence2Expected,approvalByPlayer:false,ledgerPosted:false,
  flightActivated:false
 });
 assert.match(d.calls[0].sql,/section9_owned_game_permission_applications_v1/);
 assert.deepEqual(d.calls[0].args,[OWNER,AIRLINE]);
 assert.equal(d.calls[1].sql.includes('section9_verified_permission_game_day_v1'),true);
 assert.deepEqual(d.calls[2].args,[OWNER,AIRLINE,null]);
 assert.equal(d.calls[3].sql,GAME_PERMISSION_PLAYER_SQL.policy);
 assert.equal(d.calls[4].sql,GAME_PERMISSION_PLAYER_SQL.licence2);
 assert.deepEqual(d.calls[4].args,[OWNER,AIRLINE]);
 assert.deepEqual(d.counts(),{connects:3,releases:3});
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
  obj.policies[0].validityGameDays],[10000,3,365]);
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
test('browser validates company-scoped AOC and cannot accept a fake issued certificate',()=>{
 const base={status:'permission_applications_status',airlineId:AIRLINE,
  worldId:1,gameDay:null,canApply:false,
  approvalByPlayer:false,ledgerPosted:false,flightActivated:false,
  policies:[],applications:[],aocStatus};
 assert.equal(checkedGamePermissionStatus(base,AIRLINE).aocStatus.status,'planned_not_released');
 for(const wrong of [
  {...aocStatus,airlineId:OWNER},
  {...aocStatus,worldId:2},
  {...aocStatus,issued:true},
  {...aocStatus,status:'active'},
  {...aocStatus,safetyRating:{rating:100}},
  {...aocStatus,readOnly:false}
 ]){
  assert.throws(()=>checkedGamePermissionStatus({...base,aocStatus:wrong},AIRLINE),
   /Unverified airline AOC status|Unreleased AOC exposed/);
 }
 const oldEdge={...base};delete oldEdge.aocStatus;
 assert.equal(checkedGamePermissionStatus(oldEdge,AIRLINE).aocStatus,undefined);
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


test('Licence 2 status is owner scoped, has EU 20-route Level 1, and hides pending market fees',async()=>{
 const d=database();
 const r=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
 assert.equal(r.status,200);
 const x=(await r.json()).licence2;
 assert.equal(x.readOnly,true);
 assert.equal(x.applicationsOpen,false);
 assert.equal(x.marketLevels.length,12);
 assert.deepEqual(x.marketLevels.find(m=>m.marketCode==='L2-EU'&&m.level===1),{
  marketCode:'L2-EU',marketName:'European Union and EEA',level:1,
  directedRouteLimit:20,maxAirportCategory:'Medium',quotaApproved:true,
  permitStatus:'not_issued',permitLevel:null,directedRoutesUsed:0,
  applicationStatus:null,draftApplicationId:null,requestedLevel:null,draftIssues:null,
  canApply:false,feeUsd:null,processingGameDays:null
 });
 assert.equal(x.marketLevels.find(m=>m.marketCode==='L2-US'&&m.level===1).quotaApproved,false);
 assert.match(GAME_PERMISSION_PLAYER_SQL.licence2,/a.owner_player_id=\$1::uuid/);
 assert.match(GAME_PERMISSION_PLAYER_SQL.licence2,/a.id=\$2::uuid/);
});
test('invalid foreign-network rows cause fail-closed response without invented permits',async()=>{
 for(const l2 of [
  licence2Rows.slice(0,11),
  licence2Rows.map((r,i)=>i===0?{...r,permitStatus:'approved',permitLevel:99}:r),
  licence2Rows.map((r,i)=>i===0?{...r,maxDirectedRoutes:-1}:r),
  licence2Rows.map((r,i)=>i===0?{...r,marketCode:'L2-XX'}:r)
 ]){
  const d=database({l2});
  const response=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
  assert.equal(response.status,503);
 }
});
test('browser refuses fabricated Licence 2 prices and approved limits',()=>{
 const base={status:'permission_applications_status',airlineId:AIRLINE,
 worldId:1,gameDay:null,canApply:false,
 approvalByPlayer:false,ledgerPosted:false,flightActivated:false,
 policies:[],applications:[],licence2:licence2Expected};
 assert.equal(checkedGamePermissionStatus(base,AIRLINE).licence2.marketLevels.length,12);
 for(const row of [
  {...licence2Expected.marketLevels[0],canApply:true},
  {...licence2Expected.marketLevels[0],feeUsd:25000},
  {...licence2Expected.marketLevels[0],directedRouteLimit:-1},
  {...licence2Expected.marketLevels[0],permitStatus:'approved',permitLevel:99}
 ]){
  const bad={...base,licence2:{...licence2Expected,
   marketLevels:[row,...licence2Expected.marketLevels.slice(1)]}};
  assert.throws(()=>checkedGamePermissionStatus(bad,AIRLINE),/Licence 2/);
 }
});


test('owner can save EU Licence 2 draft without submission, charge, grant or supplied player ID',async()=>{
 const d=database();
 const r=await handler(d.database)(req({
  action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-EU',level:1
 }));
 assert.equal(r.status,200);
 const data=await r.json();
 assert.equal(data.status,'APPLICATION_DRAFT_STAGED_NOT_SUBMITTED');
 assert.equal(data.created,true);
 assert.equal(data.submitted,false);
 assert.equal(data.feeCharged,false);
 assert.equal(data.rightsGranted,false);
 assert.equal(data.flightsActivated,false);
 assert.match(d.calls[0].sql,/section9_owned_game_permission_applications_v1/);
 assert.deepEqual(d.calls.at(-1).args,[OWNER,AIRLINE,'L2-EU',1]);
 assert.match(d.calls.at(-1).sql,/licence2_stage_owner_application_v1/);
});
test('Licence 2 draft rejects owner spoof, unsupported markets and invalid levels before any write',async()=>{
 const d=database();
 for(const body of [
  {action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-XX',level:1},
  {action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-UK',level:3},
  {action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-EU',level:0},
  {action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-EU',level:1,ownerPlayerId:OWNER},
  {action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-EU',level:'1'}
 ]){
  const r=await handler(d.database)(req(body));
  assert.equal(r.status,400);
 }
 assert.equal(d.calls.length,0);
 const other=database({ownerDenied:true});
 const rejected=await handler(other.database)(req({
  action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-EU',level:1
 }));
 assert.equal(rejected.status,403);
 assert.equal(other.calls.length,1);
});
test('browser Licence 2 draft client uses same-origin verified identity and rejects fabricated fee result',async()=>{
 const called=[];
 const client=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async(url,opts)=>{
   called.push({url,opts});
   return Response.json({status:'APPLICATION_DRAFT_STAGED_NOT_SUBMITTED',
    created:true,submitted:false,feeCharged:false,rightsGranted:false,
    flightsActivated:false});
  }
 });
 const x=await client.saveLicence2Draft({airlineId:AIRLINE,marketCode:'L2-EU',level:1});
 assert.equal(x.created,true);
 assert.deepEqual(JSON.parse(called[0].opts.body),{
  action:'licence2_draft',airlineId:AIRLINE,marketCode:'L2-EU',level:1});
 assert.equal(called[0].url,ORIGIN+GAME_PERMISSION_APPLICATIONS_ROUTE);
 await assert.rejects(client.saveLicence2Draft({airlineId:AIRLINE,marketCode:'L2-JP',level:3}),
  /Invalid Licence 2 draft request/);
 const forged=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async()=>Response.json({status:'APPLICATION_DRAFT_STAGED_NOT_SUBMITTED',
   created:true,submitted:false,feeCharged:true,rightsGranted:false,flightsActivated:false})
 });
 await assert.rejects(forged.saveLicence2Draft({
  airlineId:AIRLINE,marketCode:'L2-EU',level:1}),/Unsafe Licence 2 draft response/);
});


test('Licence 2 owned draft appears with level and last known eligibility blockers',async()=>{
 const l2=licence2Rows.map(row=>row.marketCode==='L2-EU'?{
  ...row,applicationStatus:'draft',draftApplicationId:REQUEST,
  requestedLevel:2,draftIssues:['ACTIVE_OWN_AOC_NOT_VERIFIED']
 }:row);
 const d=database({l2});
 const response=await handler(d.database)(req({action:'status',airlineId:AIRLINE}));
 assert.equal(response.status,200);
 const status=(await response.json()).licence2.marketLevels.find(x=>x.marketCode==='L2-EU'&&x.level===2);
 assert.equal(status.draftApplicationId,REQUEST);
 assert.equal(status.requestedLevel,2);
 assert.deepEqual(status.draftIssues,['ACTIVE_OWN_AOC_NOT_VERIFIED']);
});
test('only verified owner can withdraw an unsubmitted Licence 2 draft',async()=>{
 const d=database();
 const r=await handler(d.database)(req({action:'licence2_withdraw',airlineId:AIRLINE,applicationId:REQUEST}));
 assert.equal(r.status,200);
 const data=await r.json();
 assert.deepEqual(data,{status:'DRAFT_WITHDRAWN',withdrawn:true,
  feeCharged:false,rightsGranted:false,flightsActivated:false});
 assert.deepEqual(d.calls.at(-1).args,[OWNER,AIRLINE,REQUEST]);
 assert.match(d.calls.at(-1).sql,/licence2_withdraw_owner_draft_v1/);
 const other=database({ownerDenied:true});
 const denied=await handler(other.database)(req({action:'licence2_withdraw',airlineId:AIRLINE,applicationId:REQUEST}));
 assert.equal(denied.status,403);
});
test('withdrawal rejects fabricated owner and malformed application IDs before database access',async()=>{
 const d=database();
 for(const body of [
  {action:'licence2_withdraw',airlineId:AIRLINE,applicationId:'not-uuid'},
  {action:'licence2_withdraw',airlineId:AIRLINE,applicationId:REQUEST,ownerPlayerId:OWNER}
 ]){
  const r=await handler(d.database)(req(body));
  assert.equal(r.status,400);
 }
 assert.equal(d.calls.length,0);
});
test('browser prevents forged Licence 2 withdrawal grants',async()=>{
 const c=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async()=>Response.json({status:'DRAFT_WITHDRAWN',withdrawn:true,
   feeCharged:false,rightsGranted:false,flightsActivated:false})
 });
 assert.equal((await c.withdrawLicence2Draft({airlineId:AIRLINE,applicationId:REQUEST})).withdrawn,true);
 const bad=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async()=>Response.json({status:'DRAFT_WITHDRAWN',withdrawn:true,
   feeCharged:true,rightsGranted:false,flightsActivated:false})
 });
 await assert.rejects(bad.withdrawLicence2Draft({airlineId:AIRLINE,applicationId:REQUEST}),
  /Unsafe Licence 2 withdrawal response/);
});

test('Licence 2 draft requirement refresh is authenticated, owner-only and non-financial',async()=>{
 const db=database();
 const response=await handler(db.database)(req({
  action:'licence2_refresh',airlineId:AIRLINE,applicationId:REQUEST
 }));
 assert.equal(response.status,200);
 const result=await response.json();
 assert.deepEqual(result,{
  status:'DRAFT_READINESS_REFRESHED',refreshed:true,
  issues:['ACTIVE_OWN_AOC_NOT_VERIFIED'],eligible:false,
  feeCharged:false,rightsGranted:false,flightsActivated:false
 });
 assert.deepEqual(db.calls.at(-1).args,[OWNER,AIRLINE,REQUEST]);
 assert.match(db.calls.at(-1).sql,/licence2_refresh_owner_draft_v1/);
 const other=database({ownerDenied:true});
 assert.equal((await handler(other.database)(req({
  action:'licence2_refresh',airlineId:AIRLINE,applicationId:REQUEST
 }))).status,403);
 assert.equal(other.calls.length,1);
});
test('Licence 2 draft refresh rejects spoofed identity and fabricated money or approval',async()=>{
 const d=database();
 for(const body of [
  {action:'licence2_refresh',airlineId:AIRLINE,applicationId:'bad'},
  {action:'licence2_refresh',airlineId:AIRLINE,applicationId:REQUEST,ownerPlayerId:OWNER}
 ]){
  assert.equal((await handler(d.database)(req(body))).status,400);
 }
 assert.equal(d.calls.length,0);
 const safe=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async()=>Response.json({status:'DRAFT_READINESS_REFRESHED',refreshed:true,
   issues:['ACTIVE_OWN_AOC_NOT_VERIFIED'],eligible:false,
   feeCharged:false,rightsGranted:false,flightsActivated:false})
 });
 assert.equal((await safe.refreshLicence2Draft({
  airlineId:AIRLINE,applicationId:REQUEST})).refreshed,true);
 const forged=createGamePermissionApplicationsClient({
  auth:{getAccessToken:async()=>TOKEN},origin:ORIGIN,
  fetchImpl:async()=>Response.json({status:'DRAFT_READINESS_REFRESHED',refreshed:true,
   issues:[],eligible:true,feeCharged:true,rightsGranted:false,flightsActivated:false})
 });
 await assert.rejects(forged.refreshLicence2Draft({
  airlineId:AIRLINE,applicationId:REQUEST}),/Unsafe Licence 2 refresh response/);
});
