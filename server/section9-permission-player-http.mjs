/**
 * Authenticated World 1 game-permission player application endpoint.
 * Only "status" and "apply". NO approve/reject/revoke/expiry endpoint.
 * Player identity is verified with the hosted Auth service and database
 * owner checks. Real fees/issuance remain protected by closed game policy.
 */
import {createSection9GamePermissionApplicationService}
 from './section9-game-permission-application-service.mjs';
import {verifiedPlayerId} from './airline-activation.mjs';

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
export const GAME_PERMISSION_PLAYER_SQL=Object.freeze({policy:applicationPolicySql});
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
   typeof row.gameDay!=='string'))
  throw Error('SECTION9_INVALID_RELEASED_PERMISSION_POLICY');
 return {code:row.permissionCode,title:row.title,category:row.category,
  canApply:released&&typeof row.gameDay==='string',
  feeUsd:released?fee:null,
  processingGameDays:released?days:null,
  validityGameDays:released?validity:null};
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
  if(!['status','apply'].includes(body.action)||!UUID.test(body.airlineId||''))
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
   const client=await database.connect();
   let rows;
   try{rows=(await client.query(GAME_PERMISSION_PLAYER_SQL.policy)).rows;}
   finally{client.release();}
   if(!Array.isArray(rows)||rows.length>7||rows.length<1)
    throw Error('SECTION9_INVALID_PERMISSION_POLICY_COUNT');
   const unique=new Set();
   const policies=rows.map(row=>{
    const p=safePolicyRow(row);
    if(unique.has(p.code))throw Error('SECTION9_DUPLICATE_PERMISSION_POLICY');
    unique.add(p.code);return p;
   });
   const day=rows[0]?.gameDay??null;
   if(rows.some(r=>(r.gameDay??null)!==day))
    throw Error('SECTION9_INCONSISTENT_PERMISSION_CLOCK');
   return response(200,{
    status:'permission_applications_status',
    airlineId:body.airlineId,worldId:1,gameDay:day,
    canApply:policies.some(p=>p.canApply),
    policies,applications:owned.applications,
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
