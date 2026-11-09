/** Same-origin browser client for *player-only* game licence applications.
 * No browser signing keys, approval route, database credentials or cash writes.
 */
export const GAME_PERMISSION_APPLICATIONS_ROUTE='/api/v1/player/permission-applications';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const CODES=new Set(['AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC',
 'INTEGRATED_MARKET','THIRD_FOURTH_FREEDOM','FIFTH_FREEDOM',
 'SEVENTH_FREEDOM','CABOTAGE']);
const AIRPORT=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
export function checkedGamePermissionStatus(data,airlineId){
 if(data?.status!=='permission_applications_status'||
   data.airlineId!==airlineId||data.worldId!==1||
   data.approvalByPlayer!==false||data.ledgerPosted!==false||
   data.flightActivated!==false||
   typeof data.canApply!=='boolean'||
   !Array.isArray(data.policies)||data.policies.length>7||
   !Array.isArray(data.applications)||data.applications.length>2000||
   (data.gameDay!==null&&!DAY.test(data.gameDay)))
  throw Error('Unverified game licence application status');
 const codes=new Set();
 for(const policy of data.policies){
  if(!CODES.has(policy?.code)||codes.has(policy.code)||
    typeof policy.title!=='string'||typeof policy.canApply!=='boolean')
   throw Error('Unverified game licence release policy');
  codes.add(policy.code);
  if(policy.canApply&&(
   data.gameDay===null||!Number.isFinite(policy.feeUsd)||policy.feeUsd<=0||
   !Number.isInteger(policy.processingGameDays)||policy.processingGameDays<1||
   !Number.isInteger(policy.validityGameDays)||policy.validityGameDays<35))
   throw Error('Unverified released licence fee or timing');
  if(!policy.canApply&&(
   policy.feeUsd!==null||policy.processingGameDays!==null||
   policy.validityGameDays!==null))
   throw Error('Unreleased licence policy exposed unpublished fee');
 }
 if(data.canApply!==data.policies.some(p=>p.canApply))
  throw Error('Inconsistent licence release status');
 for(const row of data.applications){
  if(!UUID.test(row?.applicationId||'')||
    !CODES.has(row.permissionCode)||typeof row.scope!=='string'||
    !['submitted','issued','rejected','revoked','expired'].includes(row.status)||
    !DAY.test(row.appliedGameDate)||!DAY.test(row.dueGameDate)||
    typeof row.feeCharged!=='boolean')
   throw Error('Unverified licence application history');
 }
 return data;
}
export function createGamePermissionApplicationsClient({
 auth,origin,fetchImpl=(...args)=>fetch(...args)
}={}){
 if(origin!=='https://airlinerra.com'||typeof auth?.getAccessToken!=='function'||
   typeof fetchImpl!=='function')
  throw Error('Verified live game licence client required');
 async function post(body){
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)
   throw Error('Verified airline manager session required');
  const response=await fetchImpl(origin+GAME_PERMISSION_APPLICATIONS_ROUTE,{
   method:'POST',headers:{
    'content-type':'application/json','authorization':'Bearer '+token},
   body:JSON.stringify(body),cache:'no-store',redirect:'error',
   credentials:'omit',mode:'same-origin',referrerPolicy:'no-referrer'
  });
  if(response.status===401)throw Error('Game licence session expired');
  if(response.status===403)throw Error('Airline ownership could not be verified');
  if(!response.ok)throw Error('Game licence API unavailable ('+String(response.status)+')');
  const result=await response.json();
  if(!result||typeof result!=='object'||Array.isArray(result))
   throw Error('Invalid game licence API response');
  return result;
 }
 return Object.freeze({
  async status(airlineId){
   if(!UUID.test(airlineId||''))throw Error('Valid airline required');
   return checkedGamePermissionStatus(
    await post({action:'status',airlineId}),airlineId);
  },
  async apply({airlineId,requestKey,permissionCode,
     originAirportKey,destinationAirportKey,serviceType}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(requestKey||'')||
      !CODES.has(permissionCode))
    throw Error('Invalid game licence application');
   const data={action:'apply',airlineId,requestKey,permissionCode};
   if(permissionCode!=='AIR_OPERATOR_CERTIFICATE'){
    if(!AIRPORT.test(originAirportKey||'')||
      !AIRPORT.test(destinationAirportKey||'')||
      originAirportKey===destinationAirportKey||
      !['passenger','cargo'].includes(serviceType))
     throw Error('Choose valid origin, destination and passenger/cargo service');
    Object.assign(data,{originAirportKey,destinationAirportKey,serviceType});
   }
   const result=await post(data);
   if(result.flightActivated!==false||result.ledgerPosted!==false||
      result.charged!==false||result.licenceIssued!==false||
      !['permission_application_submitted','permission_application_replayed',
       'blocked_unverified_world_or_game_day',
       'blocked_game_permission_issuance_disabled',
       'blocked_operator_licence_required',
       'blocked_game_permission_already_valid',
       'blocked_game_permission_application_pending'].includes(result.status))
    throw Error('Unsafe licence application response');
   return result;
  }
 });
}
