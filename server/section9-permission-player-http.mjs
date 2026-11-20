/**
 * Authenticated World 1 game-permission player application endpoint.
 * Only "status" and "apply". NO approve/reject/revoke/expiry endpoint.
 * Player identity is verified with the hosted Auth service and database
 * owner checks. Real fees/issuance remain protected by closed game policy.
 */
import {createSection9GamePermissionApplicationService}
 from './section9-game-permission-application-service.mjs';
import {verifiedPlayerId} from './airline-activation.mjs';
import {createSection9AocReadService} from './section9-aoc-read-service.mjs';

export const GAME_PERMISSION_PLAYER_PATH='/api/v1/player/permission-applications';
const PROD='https://airlinerra.com';
const TOKEN=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const POLICY_CODES=new Set(['AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC',
 'INTEGRATED_MARKET','THIRD_FOURTH_FREEDOM','FIFTH_FREEDOM',
 'SEVENTH_FREEDOM','CABOTAGE']);
const HEADERS={'cache-control':'no-store','content-type':'application/json; charset=utf-8',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
const response=(status,body)=>Response.json(body,{status,headers:HEADERS});
const applicationPolicySql=[
 'SELECT c.permission_code AS "permissionCode",c.title, c.category,',
 'c.enabled_in_game AS "catalogueEnabled",',
 'COALESCE(p.release_enabled,false) AS "releaseEnabled",',
 'CASE WHEN c.enabled_in_game AND COALESCE(p.release_enabled,false)',
 'THEN c.game_fee_usd::text ELSE NULL END AS "gameFeeUsd",',
 'CASE WHEN c.enabled_in_game AND COALESCE(p.release_enabled,false)',
 'THEN c.processing_game_days ELSE NULL END AS "processingGameDays",',
 'CASE WHEN c.enabled_in_game AND COALESCE(p.release_enabled,false)',
 'THEN p.validity_game_days ELSE NULL END AS "validityGameDays",',
 'airlinerra_game.section9_verified_permission_game_day_v1()::text AS "gameDay"',
 'FROM airlinerra_game.business_permission_catalog_v1 c',
 'LEFT JOIN airlinerra_game.section9_game_permission_issuance_policy_v1 p',
 'ON p.permission_code=c.permission_code',
 "WHERE c.permission_code IN ('AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC',",
 "'INTEGRATED_MARKET','THIRD_FOURTH_FREEDOM','FIFTH_FREEDOM',",
 "'SEVENTH_FREEDOM','CABOTAGE')",
 "ORDER BY CASE WHEN c.permission_code='AIR_OPERATOR_CERTIFICATE' THEN 0 ELSE 1 END,c.title"
].join(' ');

const LICENCE2_OWNER_STATUS_SQL=[
 'SELECT m.market_code AS "marketCode",m.market_name AS "marketName",',
 'l.level AS "level",l.max_active_directed_routes AS "maxDirectedRoutes",',
 'l.max_category AS "maxAirportCategory",l.quota_approved AS "quotaApproved",',
 'CASE WHEN fee_initial.review_state=\'APPROVED\' AND fee_upgrade.review_state=\'APPROVED\'',
 'THEN fee_initial.fee_usd::text ELSE NULL END AS "initialFeeUsd",',
 'CASE WHEN fee_initial.review_state=\'APPROVED\' AND fee_upgrade.review_state=\'APPROVED\'',
 'THEN fee_upgrade.fee_usd::text ELSE NULL END AS "upgradeFeeUsd",',
 'CASE WHEN fee_initial.review_state=\'APPROVED\' AND fee_upgrade.review_state=\'APPROVED\'',
 'AND fee_initial.processing_game_days=fee_upgrade.processing_game_days',
 'THEN fee_initial.processing_game_days ELSE NULL END AS "approvedProcessingGameDays",',
 'm.issuance_enabled AS "issuanceEnabled",m.enforcement_enabled AS "enforcementEnabled",',
 'COALESCE(permit.status,\'not_issued\') AS "permitStatus",',
 'permit.level AS "permitLevel",',
 'COALESCE((SELECT count(*)::integer FROM airlinerra_game.licence2_directed_route_allocations_v1 routes',
 'WHERE routes.world_id=1 AND routes.airline_id=a.id AND routes.market_code=m.market_code',
 'AND routes.allocation_state IN (\'reserved\',\'active\')),0) AS "routesUsed",',
 'latest.status AS "applicationStatus", latest.application_id::text AS "draftApplicationId",',
 'latest.requested_level AS "requestedLevel", latest.latest_readiness->\'issues\' AS "draftIssues"',
 'FROM airlinerra_game.airlines a',
 'JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id',
 'AND w.player_id=a.owner_player_id AND w.state=\'active\'',
 'CROSS JOIN airlinerra_game.licence2_market_policy_v1 m',
 'JOIN airlinerra_game.licence2_market_levels_v1 l ON l.market_code=m.market_code',
 'LEFT JOIN airlinerra_game.licence2_reviewed_fee_policy_v1 fee_initial',
 'ON fee_initial.market_code=m.market_code AND fee_initial.level=l.level AND fee_initial.application_kind=\'INITIAL\'',
 'LEFT JOIN airlinerra_game.licence2_reviewed_fee_policy_v1 fee_upgrade',
 'ON fee_upgrade.market_code=m.market_code AND fee_upgrade.level=l.level AND fee_upgrade.application_kind=\'UPGRADE\'',
 'LEFT JOIN airlinerra_game.licence2_airline_market_permits_v1 permit',
 'ON permit.world_id=a.world_id AND permit.airline_id=a.id AND permit.market_code=m.market_code',
 'LEFT JOIN LATERAL (SELECT app.status,app.application_id,app.requested_level,app.latest_readiness FROM airlinerra_game.licence2_market_applications_v1 app',
 'WHERE app.world_id=a.world_id AND app.airline_id=a.id AND app.market_code=m.market_code',
 'AND app.status IN (\'draft\',\'submitted\',\'under_review\')',
 'ORDER BY app.requested_at DESC,app.application_id DESC LIMIT 1) latest ON true',
 'WHERE a.id=$2::uuid AND a.owner_player_id=$1::uuid AND a.world_id=1',
 'ORDER BY m.market_code,l.level'
].join(' ');
const L2_MARKETS=Object.freeze({'L2-EU':4,'L2-US':4,'L2-UK':2,'L2-JP':2});
const L2_CATEGORIES=new Set(['Local','Regional','Medium','Large','Major Hub','Mega Hub']);
function safeLicence2Rows(rows){
 if(!Array.isArray(rows)||rows.length!==12)throw Error('LICENCE2_INVALID_PRIVATE_MARKET_COUNT');
 const counts=new Map(),perMarket=new Map();
 const items=rows.map(r=>{
  if(!Object.hasOwn(L2_MARKETS,r?.marketCode)||typeof r.marketName!=='string'||
    r.marketName.length<3||r.marketName.length>80||
    !Number.isInteger(r.level)||r.level<1||r.level>L2_MARKETS[r.marketCode]||
    typeof r.quotaApproved!=='boolean'||typeof r.issuanceEnabled!=='boolean'||
    typeof r.enforcementEnabled!=='boolean'||
    !Number.isInteger(r.routesUsed)||r.routesUsed<0||
    !['not_issued','draft','pending_review','approved','suspended','revoked'].includes(r.permitStatus)||
    (r.permitLevel!==null&&(!Number.isInteger(r.permitLevel)||r.permitLevel<1||r.permitLevel>L2_MARKETS[r.marketCode]))||
    (r.applicationStatus!==null&&!['draft','submitted','under_review'].includes(r.applicationStatus))||
    (r.draftApplicationId!==null&&!UUID.test(r.draftApplicationId))||
    (r.requestedLevel!==null&&(!Number.isInteger(r.requestedLevel)||r.requestedLevel<1||r.requestedLevel>L2_MARKETS[r.marketCode]))||
    (r.draftIssues!==null&&(!Array.isArray(r.draftIssues)||r.draftIssues.length>20||r.draftIssues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))))||
    (r.maxDirectedRoutes!==null&&(!Number.isInteger(r.maxDirectedRoutes)||r.maxDirectedRoutes<1))||
    (r.maxAirportCategory!==null&&!L2_CATEGORIES.has(r.maxAirportCategory))||
    ((r.initialFeeUsd===null)!==(r.upgradeFeeUsd===null))||
    ((r.initialFeeUsd===null)!==(r.approvedProcessingGameDays===null))||
    (r.initialFeeUsd!==null&&(
      !Number.isFinite(Number(r.initialFeeUsd))||Number(r.initialFeeUsd)<=0||
      !Number.isFinite(Number(r.upgradeFeeUsd))||Number(r.upgradeFeeUsd)<=0||
      !Number.isInteger(r.approvedProcessingGameDays)||r.approvedProcessingGameDays<1||
      r.approvedProcessingGameDays>90||
      (r.marketCode==='L2-EU'&&Number(r.upgradeFeeUsd)!==Number(r.initialFeeUsd)))))
   throw Error('LICENCE2_INVALID_PRIVATE_MARKET_ROW');
  if((r.applicationStatus===null)!==(r.draftApplicationId===null)||
     (r.applicationStatus===null)!==(r.requestedLevel===null)||
     (r.applicationStatus===null&&r.draftIssues!==null))throw Error('LICENCE2_INVALID_DRAFT_STATUS');
  if(r.permitStatus==='not_issued'&&r.permitLevel!==null)
   throw Error('LICENCE2_INCONSISTENT_PERMIT');
  if(r.quotaApproved&&r.maxAirportCategory===null)
   throw Error('LICENCE2_APPROVED_QUOTA_MISSING_CATEGORY');
  const key=r.marketCode+':'+r.level;
  if(counts.has(key))throw Error('LICENCE2_DUPLICATE_MARKET_LEVEL');
  counts.set(key,true);
  const shared=[r.permitStatus,r.permitLevel,r.routesUsed,r.applicationStatus,r.draftApplicationId,r.requestedLevel,r.draftIssues,r.issuanceEnabled,r.enforcementEnabled];
  if(perMarket.has(r.marketCode)&&JSON.stringify(perMarket.get(r.marketCode))!==JSON.stringify(shared))
   throw Error('LICENCE2_INCONSISTENT_MARKET_STATUS');
  perMarket.set(r.marketCode,shared);
  // Display approved design fees only. These are NOT active charges or application permissions.
  return {
   marketCode:r.marketCode,marketName:r.marketName,level:r.level,
   directedRouteLimit:r.quotaApproved?r.maxDirectedRoutes:null,
   maxAirportCategory:r.quotaApproved?r.maxAirportCategory:null,
   quotaApproved:r.quotaApproved,
   permitStatus:r.permitStatus,permitLevel:r.permitLevel,
   directedRoutesUsed:r.routesUsed,applicationStatus:r.applicationStatus,
   approvedInitialFeeUsd:r.initialFeeUsd===null?null:Number(r.initialFeeUsd),
   approvedUpgradeFeeUsd:r.upgradeFeeUsd===null?null:Number(r.upgradeFeeUsd),
   approvedProcessingGameDays:r.approvedProcessingGameDays,
   draftApplicationId:r.draftApplicationId,requestedLevel:r.requestedLevel,
   draftIssues:r.draftIssues,
   canApply:false,feeUsd:null,processingGameDays:null
  };
 });
 return {readOnly:true,applicationsOpen:false,marketLevels:items};
}

export const GAME_PERMISSION_PLAYER_SQL=Object.freeze({policy:applicationPolicySql,licence2:LICENCE2_OWNER_STATUS_SQL});
async function readBody(req){
 const n=req.headers.get('content-length');
 if(n!==null&&(!/^\d+$/.test(n)||Number(n)>2048))
  throw Error('body_too_large');
 const source=await req.text();
 if(new TextEncoder().encode(source).byteLength>2048)
  throw Error('body_too_large');
 const obj=JSON.parse(source);
 if(!obj||Array.isArray(obj)||typeof obj!=='object')
  throw Error('invalid_json');
 return obj;
}
function safePolicyRow(row){
 if(!POLICY_CODES.has(row?.permissionCode)||typeof row.title!=='string'||
  row.title.length<3||row.title.length>180||
  !['airline','traffic_rights'].includes(row.category)||
  typeof row.catalogueEnabled!=='boolean'||
  typeof row.releaseEnabled!=='boolean')
  throw Error('SECTION9_INVALID_PERMISSION_POLICY_ROW');
 const released=row.catalogueEnabled===true&&row.releaseEnabled===true;
 const fee=released?Number(row.gameFeeUsd):null;
 const days=released?Number(row.processingGameDays):null;
 const validity=released?Number(row.validityGameDays):null;
 if(released&&(!Number.isFinite(fee)||fee<=0||fee>1000000||
   !Number.isInteger(days)||days<1||days>90||
   !Number.isInteger(validity)||validity<35||validity>1095||
   (row.gameDay!==null&&typeof row.gameDay!=='string')))
  throw Error('SECTION9_INVALID_RELEASED_PERMISSION_POLICY');
 const open=released&&typeof row.gameDay==='string';
 return {code:row.permissionCode,title:row.title,category:row.category,
  canApply:open,feeUsd:open?fee:null,
  processingGameDays:open?days:null,
  validityGameDays:open?validity:null};
}
export function createSection9PermissionPlayerHandler({
 database,verifyUserToken,origin=PROD
}={}){
 if(typeof database?.connect!=='function'||typeof verifyUserToken!=='function'||
    origin!==PROD)
  throw Error('SECTION9_PERMISSION_PRIVATE_PLAYER_HANDLER_REQUIRED');
 return async function handle(req){
  if(!(req instanceof Request))return response(400,{error:'Invalid request'});
  const url=new URL(req.url);
  if(url.origin!==origin||url.pathname!==GAME_PERMISSION_PLAYER_PATH||
     url.search||url.hash||req.headers.get('origin')!==origin||
     req.headers.get('x-airlinerra-route')!==GAME_PERMISSION_PLAYER_PATH)
   return response(403,{error:'Forbidden'});
  if(req.method!=='POST')return response(405,{error:'POST required'});
  if(req.headers.get('content-type')!=='application/json')
   return response(415,{error:'JSON required'});
  const token=TOKEN.exec(req.headers.get('authorization')||'')?.[1];
  if(!token)return response(401,{error:'Verified session required'});
  let body;
  try{body=await readBody(req);}
  catch{return response(400,{error:'Invalid application request'});}
  if(!['status','apply','licence2_draft','licence2_withdraw','licence2_refresh','licence2_submit','licence3_status','licence3_submit','licence4_status','licence4_submit'].includes(body.action)||!UUID.test(body.airlineId||''))
   return response(400,{error:'Invalid application request'});
  if(body.action==='status'&&Object.keys(body).sort().join(',')!=='action,airlineId')
   return response(400,{error:'Invalid status request'});

  let playerId;
  try{playerId=verifiedPlayerId(await verifyUserToken(token));}
  catch{return response(401,{error:'Verified session required'});}
  const identity={
   authorizeApplication:async r=>({authorized:true,
    source:'verified_game_player_session',ownerPlayerId:playerId,
    airlineId:r.airlineId}),
   authorizeList:async r=>({authorized:true,
    source:'verified_game_player_session',ownerPlayerId:playerId,
    airlineId:r.airlineId})
  };
  const service=createSection9GamePermissionApplicationService({
   database,identityAuthority:identity
  });
  try{
   if(body.action==='licence3_status'||body.action==='licence3_submit'){
    const isSubmit=body.action==='licence3_submit';
    if(Object.keys(body).sort().join(',')!==
      (isSubmit?'action,airlineId,requestKey':'action,airlineId')||
      (isSubmit&&!UUID.test(body.requestKey||'')))
     return response(400,{error:'Invalid Cargo Licence 3 request'});
    // The existing authenticated private owner lookup must complete before
    // accessing company-scoped cargo records or attempting submission.
    await service.listApplications({airlineId:body.airlineId});
    const client=await database.connect();
    try{
     if(isSubmit){
      const r=await client.query(
       'SELECT airlinerra_game.licence3_submit_cargo_application_v1($1::uuid,$2::uuid,$3::uuid) AS result',
       [playerId,body.airlineId,body.requestKey]);
      const x=r.rows?.[0]?.result;
      if(r.rowCount!==1||!x||!['NOT_RELEASED','NOT_ELIGIBLE','GAME_TICK_UNVERIFIED',
        'ALREADY_APPROVED','SUBMITTED','submitted','issued','withdrawn'].includes(x.status)||
        x.charged!==false||typeof x.submitted!=='boolean'||
        (x.status==='SUBMITTED'&&(!UUID.test(x.applicationId||'')||x.issued!==false)))
       throw Error('LICENCE3_UNSAFE_APPLICATION_RESPONSE');
      return response(200,{status:x.status,applicationId:x.applicationId??null,
       dueGameDay:x.dueGameDay??null,submitted:x.submitted,feeCharged:false,
       licenceIssued:false,flightActivated:false});
     }
     const r=await client.query(
      `SELECT airlinerra_game.licence3_cargo_readiness_v1($2::uuid) AS readiness,
         airlinerra_game.licence3_cargo_flight_scope_v1($2::uuid) AS scope,
         EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1
          WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified) AS released,
         (SELECT a.status FROM airlinerra_game.licence3_cargo_applications_v1 a
          WHERE a.airline_id=$2::uuid ORDER BY created_at DESC LIMIT 1) AS application_status,
         (SELECT a.due_game_day::text FROM airlinerra_game.licence3_cargo_applications_v1 a
          WHERE a.airline_id=$2::uuid ORDER BY created_at DESC LIMIT 1) AS due_game_day
        FROM airlinerra_game.airlines owner
        WHERE owner.id=$2::uuid AND owner.owner_player_id=$1::uuid AND owner.world_id=1`,
      [playerId,body.airlineId]);
     const x=r.rows?.[0];
     if(r.rowCount!==1||!x||!x.readiness||
       x.readiness.airlineId!==body.airlineId||
       !x.scope||typeof x.scope.authorized!=='boolean'||
       typeof x.released!=='boolean'||
       (x.application_status!==null&&
        !['submitted','issued','withdrawn'].includes(x.application_status)))
      throw Error('LICENCE3_UNSAFE_PRIVATE_STATUS');
     return response(200,{status:'licence3_cargo_status',
      airlineId:body.airlineId,worldId:1,readOnly:true,
      issued:x.scope.authorized===true,
      canApply:x.released===true&&x.readiness.eligible===true,
      applicationStatus:x.application_status,dueGameDay:x.due_game_day,
      issues:Array.isArray(x.readiness.issues)?x.readiness.issues.slice(0,20):[],
      feeUsd:50000,processingGameDays:3,
      flightActivated:false});
    }finally{client.release();}
   }
   if(body.action==='licence4_status'||body.action==='licence4_submit'){
    const isSubmit=body.action==='licence4_submit';
    if(Object.keys(body).sort().join(',')!==
      (isSubmit?'action,airlineId,requestKey':'action,airlineId')||
      (isSubmit&&!UUID.test(body.requestKey||'')))
     return response(400,{error:'Invalid Charter/VIP Licence 4 request'});
    // The existing authenticated private owner lookup must complete before
    // accessing company-scoped charter records or attempting submission.
    await service.listApplications({airlineId:body.airlineId});
    const client=await database.connect();
    try{
     if(isSubmit){
      const r=await client.query(
       'SELECT airlinerra_game.licence4_submit_charter_application_v1($1::uuid,$2::uuid,$3::uuid) AS result',
       [playerId,body.airlineId,body.requestKey]);
      const x=r.rows?.[0]?.result;
      if(r.rowCount!==1||!x||!['NOT_RELEASED','NOT_ELIGIBLE','GAME_TICK_UNVERIFIED',
        'ALREADY_APPROVED','SUBMITTED','submitted','issued','withdrawn'].includes(x.status)||
        x.charged!==false||typeof x.submitted!=='boolean'||
        (x.status==='SUBMITTED'&&(!UUID.test(x.applicationId||'')||x.issued!==false)))
       throw Error('LICENCE4_UNSAFE_APPLICATION_RESPONSE');
      return response(200,{status:x.status,applicationId:x.applicationId??null,
       dueGameDay:x.dueGameDay??null,submitted:x.submitted,feeCharged:false,
       licenceIssued:false,flightActivated:false});
     }
     const r=await client.query(
      `SELECT airlinerra_game.licence4_charter_readiness_v1($2::uuid) AS readiness,
         airlinerra_game.licence4_charter_flight_scope_v1($2::uuid) AS scope,
         EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_release_v1
          WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified) AS released,
         (SELECT a.status FROM airlinerra_game.licence4_charter_applications_v1 a
          WHERE a.airline_id=$2::uuid ORDER BY created_at DESC LIMIT 1) AS application_status,
         (SELECT a.due_game_day::text FROM airlinerra_game.licence4_charter_applications_v1 a
          WHERE a.airline_id=$2::uuid ORDER BY created_at DESC LIMIT 1) AS due_game_day
        FROM airlinerra_game.airlines owner
        WHERE owner.id=$2::uuid AND owner.owner_player_id=$1::uuid AND owner.world_id=1`,
      [playerId,body.airlineId]);
     const x=r.rows?.[0];
     if(r.rowCount!==1||!x||!x.readiness||
       x.readiness.airlineId!==body.airlineId||
       !x.scope||typeof x.scope.authorized!=='boolean'||
       typeof x.released!=='boolean'||
       (x.application_status!==null&&
        !['submitted','issued','withdrawn'].includes(x.application_status)))
      throw Error('LICENCE4_UNSAFE_PRIVATE_STATUS');
     return response(200,{status:'licence4_charter_status',
      airlineId:body.airlineId,worldId:1,readOnly:true,
      issued:x.scope.authorized===true,
      canApply:x.released===true&&x.readiness.eligible===true,
      applicationStatus:x.application_status,dueGameDay:x.due_game_day,
      issues:Array.isArray(x.readiness.issues)?x.readiness.issues.slice(0,20):[],
      feeUsd:40000,processingGameDays:3,
      flightActivated:false});
    }finally{client.release();}
   }
   if(body.action==='licence2_submit'){
    if(Object.keys(body).sort().join(',')!=='action,airlineId,applicationId'||
       !UUID.test(body.applicationId||''))
      return response(400,{error:'Invalid Licence 2 application submission'});
    // Authenticate the owner before the private submission procedure independently
    // rechecks membership, eligibility, and the verified world game date.
    await service.listApplications({airlineId:body.airlineId});
    const client=await database.connect();
    try{
     const r=await client.query(
      'SELECT airlinerra_game.licence2_submit_owner_application_v1($1::uuid,$2::uuid) AS result',
      [playerId,body.applicationId]);
     const x=r.rows?.[0]?.result;
     if(r.rowCount!==1||!x||![
       'APPLICATION_SUBMITTED_FOR_REVIEW','ALREADY_SUBMITTED',
       'APPLICATION_NOT_SUBMITTABLE','APPLICATION_NOT_ELIGIBLE','GAME_DATE_UNVERIFIED'
      ].includes(x.status)||
      typeof x.submitted!=='boolean'||x.feeCharged!==false||
      x.rightsGranted!==false||x.flightsActivated===true||
      ((x.status==='APPLICATION_SUBMITTED_FOR_REVIEW'||x.status==='ALREADY_SUBMITTED')&&x.submitted!==true))
      throw Error('LICENCE2_UNSAFE_SUBMISSION_RESULT');
     return response(200,{
      status:x.status,submitted:x.submitted,
      applicationId:body.applicationId,
      issues:Array.isArray(x.readiness?.issues)?x.readiness.issues.slice(0,20)
       .filter(issue=>typeof issue==='string'&&/^[A-Z0-9_]{3,100}$/.test(issue)):[],
      feeCharged:false,rightsGranted:false,flightsActivated:false
     });
    }finally{client.release();}
   }
   if(body.action==='licence2_refresh'){
    if(Object.keys(body).sort().join(',')!=='action,airlineId,applicationId'||
       !UUID.test(body.applicationId||''))
     return response(400,{error:'Invalid Licence 2 draft refresh'});
    await service.listApplications({airlineId:body.airlineId});
    const client=await database.connect();
    try{
     const r=await client.query(
      'SELECT airlinerra_game.licence2_refresh_owner_draft_v1($1::uuid,$2::uuid,$3::uuid) AS result',
      [playerId,body.airlineId,body.applicationId]);
     const result=r.rows?.[0]?.result;
     if(r.rowCount!==1||!result||![
      'DRAFT_READINESS_REFRESHED','DRAFT_NOT_FOUND',
      'DRAFT_REFRESH_NOT_ALLOWED','DRAFT_READINESS_UNAVAILABLE'
     ].includes(result.status)||
      typeof result.refreshed!=='boolean'||result.feeCharged!==false||
      result.rightsGranted!==false||result.flightsActivated!==false||
      (result.refreshed===true&&(
       !Array.isArray(result.issues)||result.issues.length>20||
       result.issues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))||
       typeof result.eligible!=='boolean'||!UUID.test(result.applicationId||''))))
       throw Error('LICENCE2_UNSAFE_REFRESH_RESULT');
     return response(200,{
      status:result.status,refreshed:result.refreshed,
      issues:result.refreshed?result.issues:[],
      eligible:result.refreshed?result.eligible:false,
      feeCharged:false,rightsGranted:false,flightsActivated:false
     });
    }finally{client.release();}
   }
   if(body.action==='licence2_withdraw'){
    if(Object.keys(body).sort().join(',')!=='action,airlineId,applicationId'||
      !UUID.test(body.applicationId||''))return response(400,{error:'Invalid Licence 2 draft withdrawal'});
    await service.listApplications({airlineId:body.airlineId});
    const client=await database.connect();
    try{
     const r=await client.query(
      'SELECT airlinerra_game.licence2_withdraw_owner_draft_v1($1::uuid,$2::uuid,$3::uuid) AS result',
      [playerId,body.airlineId,body.applicationId]);
     const result=r.rows?.[0]?.result;
     if(r.rowCount!==1||!result||!['DRAFT_WITHDRAWN','DRAFT_ALREADY_WITHDRAWN','DRAFT_NOT_WITHDRAWABLE','DRAFT_NOT_FOUND'].includes(result.status)||
       typeof result.withdrawn!=='boolean'||result.feeCharged!==false||result.rightsGranted!==false||result.flightsActivated===true)
       throw Error('LICENCE2_UNSAFE_WITHDRAWAL_RESULT');
     return response(200,{status:result.status,withdrawn:result.withdrawn,
      feeCharged:false,rightsGranted:false,flightsActivated:false});
    }finally{client.release();}
   }
   if(body.action==='licence2_draft'){
    if(Object.keys(body).sort().join(',')!=='action,airlineId,level,marketCode'||
       !Object.hasOwn(L2_MARKETS,body.marketCode)||
       !Number.isInteger(body.level)||body.level<1||
       body.level>L2_MARKETS[body.marketCode])
     return response(400,{error:'Invalid Licence 2 draft'});
    // The existing private owner-verified listing must succeed first.
    await service.listApplications({airlineId:body.airlineId});
    const client=await database.connect();
    try{
     const r=await client.query(
      'SELECT airlinerra_game.licence2_stage_owner_application_v1($1::uuid,$2::uuid,$3::text,$4::smallint) AS result',
      [playerId,body.airlineId,body.marketCode,body.level]);
     const result=r.rows?.[0]?.result;
     if(r.rowCount!==1||!result||![
       'APPLICATION_DRAFT_STAGED_NOT_SUBMITTED','EXISTING_APPLICATION_ALREADY_OPEN',
       'ALREADY_HOLDS_SUFFICIENT_LEVEL','INVALID_OR_UNSUPPORTED_MARKET_LEVEL'
      ].includes(result.status)||
      result.feeCharged===true||result.rightsGranted===true||
      result.flightsActivated===true||result.submitted===true)
      throw Error('LICENCE2_UNSAFE_DRAFT_RESULT');
     return response(200,{
      status:result.status,created:result.created===true,
      applicationId:result.applicationId??null,
      submitted:false,feeCharged:false,rightsGranted:false,flightsActivated:false
     });
    }finally{client.release();}
   }
   if(body.action==='apply'){
    const {action,...request}=body;
    if(Object.keys(request).some(key=>![
      'airlineId','requestKey','permissionCode','originAirportKey',
      'destinationAirportKey','serviceType'
    ].includes(key)))return response(400,{error:'Invalid application fields'});
    const applied=await service.submitApplication(request);
    return response(200,applied);
   }
   // Verify ownership using the private DB BEFORE returning policy/status.
   const owned=await service.listApplications({airlineId:body.airlineId});
   // Separate owner-scoped AOC source: no certificate is inferred from
   // registration or an empty incident history while AOC release is disabled.
   // The client only receives private, read-only status. No issue action.
   const aocRead=createSection9AocReadService({
    database,identityAuthority:{
     authorizeStatus:async({airlineId})=>({
      authorized:true,source:'verified_game_player_session',
      ownerPlayerId:playerId,airlineId
     })
    }
   });
   const aocStatus=await aocRead.getOwnedStatus({airlineId:body.airlineId});
   const client=await database.connect();
   let rows,l2Rows;
   try{
    rows=(await client.query(GAME_PERMISSION_PLAYER_SQL.policy)).rows;
    l2Rows=(await client.query(GAME_PERMISSION_PLAYER_SQL.licence2,[playerId,body.airlineId])).rows;
   }finally{client.release();}
   if(!Array.isArray(rows)||rows.length>7||rows.length<1)
    throw Error('SECTION9_INVALID_PERMISSION_POLICY_COUNT');
   const unique=new Set();
   const policies=rows.map(row=>{
    const p=safePolicyRow(row);
    if(unique.has(p.code))throw Error('SECTION9_DUPLICATE_PERMISSION_POLICY');
    unique.add(p.code);return p;
   });
   const licence2=safeLicence2Rows(l2Rows);
   const day=rows[0]?.gameDay??null;
   if(rows.some(r=>(r.gameDay??null)!==day))
    throw Error('SECTION9_INCONSISTENT_PERMISSION_CLOCK');
   return response(200,{
    status:'permission_applications_status',
    airlineId:body.airlineId,worldId:1,gameDay:day,
    canApply:policies.some(p=>p.canApply),
    policies,applications:owned.applications,aocStatus,licence2,
    approvalByPlayer:false,ledgerPosted:false,flightActivated:false
   });
  }catch(error){
   if(error?.code==='42501'||/NOT_OWNED|UNVERIFIED_PERMISSION_OWNER/.test(
      String(error?.message||'')))
    return response(403,{error:'Airline not owned'});
   if(/INVALID_PERMISSION_APPLICATION_REQUEST/.test(String(error?.message||'')))
    return response(400,{error:'Invalid application fields'});
   return response(503,{error:'Permission service unavailable'});
  }
 };
}
