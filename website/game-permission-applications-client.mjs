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
 // Older deployed Edge versions may omit AOC; never synthesize one.
 if(data.aocStatus!==undefined){
  const aoc=data.aocStatus;
  if(!aoc||typeof aoc!=='object'||Array.isArray(aoc)||
     aoc.airlineId!==airlineId||aoc.worldId!==1||aoc.readOnly!==true||
     !['planned_not_released','not_issued','active','expired'].includes(aoc.status)||
     typeof aoc.issued!=='boolean'||
     (aoc.status==='planned_not_released'&&aoc.issued!==false)||
     (aoc.status==='not_issued'&&aoc.issued!==false)||
     (['active','expired'].includes(aoc.status)&&aoc.issued!==true))
   throw Error('Unverified airline AOC status');
  if(aoc.issued){
   if(!DAY.test(aoc.issuedGameDay||'')||
      !DAY.test(aoc.expiresGameDay||'')||
      !Number.isInteger(aoc.safetyRating?.rating)||
      aoc.safetyRating.rating<0||aoc.safetyRating.rating>100||
      aoc.safetyRating.airlineId!==airlineId)
    throw Error('Unverified issued AOC details');
  }else if(aoc.safetyRating!==null&&aoc.safetyRating!==undefined){
   // No provisional safety value should look like an issued licence.
   if(aoc.status==='planned_not_released')
    throw Error('Unreleased AOC exposed an unverified rating');
  }
 }

 // Older deployed versions may omit Licence 2. Never invent a permit in that case.
 if(data.licence2!==undefined){
  const l2=data.licence2;
  if(!l2||l2.readOnly!==true||l2.applicationsOpen!==false||
    !Array.isArray(l2.marketLevels)||l2.marketLevels.length!==12)
   throw Error('Unverified Licence 2 market status');
  const expected={'L2-EU':4,'L2-US':4,'L2-UK':2,'L2-JP':2};
  const seen=new Set(),shared=new Map();
  const categories=new Set(['Local','Regional','Medium','Large','Major Hub','Mega Hub']);
  for(const r of l2.marketLevels){
   if(!Object.hasOwn(expected,r?.marketCode)||!Number.isInteger(r.level)||
     r.level<1||r.level>expected[r.marketCode]||
     typeof r.marketName!=='string'||r.marketName.length<3||
     typeof r.quotaApproved!=='boolean'||
     (r.directedRouteLimit!==null&&(!Number.isInteger(r.directedRouteLimit)||r.directedRouteLimit<1))||
     (r.maxAirportCategory!==null&&!categories.has(r.maxAirportCategory))||
     (r.quotaApproved&&r.maxAirportCategory===null)||
     (r.permitLevel!==null&&(!Number.isInteger(r.permitLevel)||r.permitLevel<1||r.permitLevel>expected[r.marketCode]))||
     !Number.isInteger(r.directedRoutesUsed)||r.directedRoutesUsed<0||
     !['not_issued','draft','pending_review','approved','suspended','revoked'].includes(r.permitStatus)||
     (r.applicationStatus!==null&&!['draft','submitted','under_review'].includes(r.applicationStatus))||
     (r.draftApplicationId!==null&&!UUID.test(r.draftApplicationId||''))||
     (r.requestedLevel!==null&&(!Number.isInteger(r.requestedLevel)||r.requestedLevel<1||r.requestedLevel>expected[r.marketCode]))||
     (r.draftIssues!==null&&(!Array.isArray(r.draftIssues)||r.draftIssues.length>20||
      r.draftIssues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))))||
     (r.approvedInitialFeeUsd===null)!==(r.approvedUpgradeFeeUsd===null)||
     (r.approvedInitialFeeUsd===null)!==(r.approvedProcessingGameDays===null)||
     (r.approvedInitialFeeUsd!==null&&(
      !Number.isFinite(r.approvedInitialFeeUsd)||r.approvedInitialFeeUsd<=0||
      !Number.isFinite(r.approvedUpgradeFeeUsd)||r.approvedUpgradeFeeUsd<=0||
      !Number.isInteger(r.approvedProcessingGameDays)||r.approvedProcessingGameDays<1||
      r.approvedProcessingGameDays>90||
      (r.marketCode==='L2-EU'&&r.approvedInitialFeeUsd!==r.approvedUpgradeFeeUsd)))||
     r.canApply!==false||r.feeUsd!==null||r.processingGameDays!==null)
    throw Error('Unverified Licence 2 market level');
   const key=r.marketCode+':'+r.level;
   if(seen.has(key))throw Error('Duplicate Licence 2 level');
   seen.add(key);
   if((r.applicationStatus===null)!==(r.draftApplicationId===null)||
      (r.applicationStatus===null)!==(r.requestedLevel===null)||
      (r.applicationStatus===null&&r.draftIssues!==null))
    throw Error('Unverified Licence 2 draft metadata');
   if(!r.quotaApproved&&(r.directedRouteLimit!==null||r.maxAirportCategory!==null))
    throw Error('Unapproved Licence 2 rules displayed as final');
   if(r.permitStatus==='not_issued'&&r.permitLevel!==null)
    throw Error('Unverified Licence 2 permit');
   const status=[r.permitStatus,r.permitLevel,r.directedRoutesUsed,r.applicationStatus,r.draftApplicationId,r.requestedLevel,r.draftIssues];
   if(shared.has(r.marketCode)&&JSON.stringify(shared.get(r.marketCode))!==JSON.stringify(status))
    throw Error('Inconsistent Licence 2 permit status');
   shared.set(r.marketCode,status);
  }
  for(const [market,max] of Object.entries(expected))
   for(let level=1;level<=max;level++)
    if(!seen.has(market+':'+level))throw Error('Missing Licence 2 market level');
 }

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
  async cargoLicence3Status(airlineId){
   if(!UUID.test(airlineId||''))throw Error('Valid cargo airline required');
   const x=await post({action:'licence3_status',airlineId});
   if(x?.status!=='licence3_cargo_status'||x.airlineId!==airlineId||
      x.worldId!==1||x.readOnly!==true||x.flightActivated!==false||
      typeof x.issued!=='boolean'||typeof x.canApply!=='boolean'||
      x.feeUsd!==50000||x.processingGameDays!==3||
      x.minimumSafetyRating!==50||
      !['NOT_ISSUED','REVOKED','SUSPENDED_UNVERIFIED_GAME_CLOCK',
        'SUSPENDED_SAFETY','SUSPENDED_NO_AIRCRAFT','ACTIVE',
        'SUSPENDED_OTHER_REQUIREMENTS'].includes(x.lifecycleStatus)||
      typeof x.operationsAuthorized!=='boolean'||
      (x.safetyRating!==null&&(!Number.isInteger(x.safetyRating)||x.safetyRating<0||x.safetyRating>100))||
      (x.aircraftGraceDaysRemaining!==null&&
        (!Number.isInteger(x.aircraftGraceDaysRemaining)||x.aircraftGraceDaysRemaining<0||
          x.aircraftGraceDaysRemaining>90))||
      !Array.isArray(x.issues)||x.issues.length>20||
      x.issues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))||
      (x.applicationStatus!==null&&!['submitted','issued','withdrawn'].includes(x.applicationStatus))||
      (x.dueGameDay!==null&&!DAY.test(x.dueGameDay)))
     throw Error('Unverified Cargo Licence 3 status');
   return x;
  },
  async submitCargoLicence3({airlineId,requestKey}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(requestKey||''))
    throw Error('Invalid Cargo Licence 3 request');
   const x=await post({action:'licence3_submit',airlineId,requestKey});
   if(!['NOT_RELEASED','NOT_ELIGIBLE','GAME_TICK_UNVERIFIED','ALREADY_APPROVED',
         'SUBMITTED','submitted','issued','withdrawn'].includes(x?.status)||
     typeof x.submitted!=='boolean'||x.feeCharged!==false||
     x.licenceIssued!==false||x.flightActivated!==false||
     (x.applicationId!==null&&!UUID.test(x.applicationId||''))||
     (x.dueGameDay!==null&&!DAY.test(x.dueGameDay)))
    throw Error('Unsafe Cargo Licence 3 application response');
   return x;
  },
  async charterLicence4Status(airlineId){
   if(!UUID.test(airlineId||''))throw Error('Valid charter airline required');
   const x=await post({action:'licence4_status',airlineId});
   if(x?.status!=='licence4_charter_status'||x.airlineId!==airlineId||
      x.worldId!==1||x.readOnly!==true||x.flightActivated!==false||
      typeof x.issued!=='boolean'||typeof x.canApply!=='boolean'||
      x.feeUsd!==40000||x.processingGameDays!==3||
      x.minimumSafetyRating!==70||
      !['NOT_ISSUED','REVOKED','SUSPENDED_UNVERIFIED_GAME_CLOCK',
        'SUSPENDED_SAFETY','SUSPENDED_NO_AIRCRAFT','ACTIVE',
        'SUSPENDED_OTHER_REQUIREMENTS'].includes(x.lifecycleStatus)||
      typeof x.operationsAuthorized!=='boolean'||
      (x.safetyRating!==null&&(!Number.isInteger(x.safetyRating)||x.safetyRating<0||x.safetyRating>100))||
      (x.aircraftGraceDaysRemaining!==null&&
        (!Number.isInteger(x.aircraftGraceDaysRemaining)||x.aircraftGraceDaysRemaining<0||
          x.aircraftGraceDaysRemaining>90))||
      !Array.isArray(x.issues)||x.issues.length>20||
      x.issues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))||
      (x.applicationStatus!==null&&!['submitted','issued','withdrawn'].includes(x.applicationStatus))||
      (x.dueGameDay!==null&&!DAY.test(x.dueGameDay)))
     throw Error('Unverified Charter/VIP Licence 4 status');
   return x;
  },
  async submitCharterLicence4({airlineId,requestKey}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(requestKey||''))
    throw Error('Invalid Charter/VIP Licence 4 request');
   const x=await post({action:'licence4_submit',airlineId,requestKey});
   if(!['NOT_RELEASED','NOT_ELIGIBLE','GAME_TICK_UNVERIFIED','ALREADY_APPROVED',
         'SUBMITTED','submitted','issued','withdrawn'].includes(x?.status)||
     typeof x.submitted!=='boolean'||x.feeCharged!==false||
     x.licenceIssued!==false||x.flightActivated!==false||
     (x.applicationId!==null&&!UUID.test(x.applicationId||''))||
     (x.dueGameDay!==null&&!DAY.test(x.dueGameDay)))
    throw Error('Unsafe Charter/VIP Licence 4 application response');
   return x;
  },
  async dangerousGoodsLicence5Status(airlineId){
   if(!UUID.test(airlineId||''))throw Error('Valid cargo airline required');
   const x=await post({action:'licence5_status',airlineId});
   if(x?.status!=='licence5_dg_status'||x.airlineId!==airlineId||
      x.worldId!==1||x.readOnly!==true||x.flightActivated!==false||
      typeof x.issued!=='boolean'||typeof x.canApply!=='boolean'||
      x.feeUsd!==60000||x.processingGameDays!==5||
      typeof x.operatorScopeApproved!=='boolean'||
      x.operatorScopeApproved!==x.issued||
      x.shipmentAuthorization!==false||
      !Array.isArray(x.approvedCommodityClasses)||x.approvedCommodityClasses.length!==0||
      !Array.isArray(x.issues)||x.issues.length>20||
      x.issues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))||
      (x.applicationStatus!==null&&!['submitted','issued','withdrawn'].includes(x.applicationStatus))||
      (x.dueGameDay!==null&&!DAY.test(x.dueGameDay)))
     throw Error('Unverified Dangerous Goods Licence 5 status');
   return x;
  },
  async submitDangerousGoodsLicence5({airlineId,requestKey}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(requestKey||''))
    throw Error('Invalid Dangerous Goods Licence 5 request');
   const x=await post({action:'licence5_submit',airlineId,requestKey});
   if(!['NOT_RELEASED','NOT_ELIGIBLE','GAME_TICK_UNVERIFIED','ALREADY_APPROVED',
         'SUBMITTED','submitted','issued','withdrawn'].includes(x?.status)||
     typeof x.submitted!=='boolean'||x.feeCharged!==false||
     x.licenceIssued!==false||x.flightActivated!==false||
     (x.applicationId!==null&&!UUID.test(x.applicationId||''))||
     (x.dueGameDay!==null&&!DAY.test(x.dueGameDay)))
    throw Error('Unsafe Dangerous Goods Licence 5 application response');
   return x;
  },
  async licence6FifthFreedomPreview({airlineId,homeAirport,foreignStop,foreignDestination,serviceType}={}){
   if(!UUID.test(airlineId||'')||!['passenger','cargo'].includes(serviceType)
    ||![homeAirport,foreignStop,foreignDestination].every(
     v=>typeof v==='string'&&/^[A-Z0-9:_-]{3,120}$/.test(v)))
    throw Error('Invalid Fifth Freedom route preview');
   const x=await post({action:'licence6_preview',airlineId,homeAirport,
    foreignStop,foreignDestination,serviceType});
   if(x?.status!=='licence6_route_preview'||x.worldId!==1||
    x.airlineId!==airlineId||x.homeAirport!==homeAirport||
    x.foreignStop!==foreignStop||x.foreignDestination!==foreignDestination||
    x.serviceType!==serviceType||
    x.canApply!==false||x.routeAuthorized!==false||
    x.foreignSegmentAuthorized!==false||x.flightActivated!==false||
    x.proposedFeeMinUsd!==100000||x.proposedFeeMaxUsd!==250000||
    x.processingGameDays!==7||
    (x.feeUsd!==null&&(!Number.isInteger(x.feeUsd)||
      x.feeUsd<100000||x.feeUsd>250000))||
    !Array.isArray(x.issues)||x.issues.length>20||
    x.issues.some(v=>typeof v!=='string'||! /^[A-Z0-9_]{3,100}$/.test(v))||
    ![x.homeCountry,x.firstForeignCountry,x.secondForeignCountry].every(
      v=>typeof v==='string'&&/^[A-Z]{2}$/.test(v)))
    throw Error('Unsafe Fifth Freedom route preview');
   return x;
  },
  async status(airlineId){
   if(!UUID.test(airlineId||''))throw Error('Valid airline required');
   return checkedGamePermissionStatus(
    await post({action:'status',airlineId}),airlineId);
  },
  async submitLicence2Application({airlineId,applicationId}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(applicationId||''))
    throw Error('Invalid Licence 2 submission request');
   const result=await post({action:'licence2_submit',airlineId,applicationId});
   if(!['APPLICATION_SUBMITTED_FOR_REVIEW','ALREADY_SUBMITTED',
      'APPLICATION_NOT_SUBMITTABLE','APPLICATION_NOT_ELIGIBLE','GAME_DATE_UNVERIFIED']
      .includes(result.status)||
      typeof result.submitted!=='boolean'||
      !Array.isArray(result.issues)||result.issues.length>20||
      result.issues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue))||
      result.feeCharged!==false||result.rightsGranted!==false||
      result.flightsActivated!==false||
      (['APPLICATION_SUBMITTED_FOR_REVIEW','ALREADY_SUBMITTED'].includes(result.status)&&result.submitted!==true))
     throw Error('Unsafe Licence 2 submission response');
   return result;
  },
  async refreshLicence2Draft({airlineId,applicationId}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(applicationId||''))
    throw Error('Invalid Licence 2 refresh request');
   const result=await post({action:'licence2_refresh',airlineId,applicationId});
   if(!['DRAFT_READINESS_REFRESHED','DRAFT_NOT_FOUND',
      'DRAFT_REFRESH_NOT_ALLOWED','DRAFT_READINESS_UNAVAILABLE'].includes(result.status)||
      typeof result.refreshed!=='boolean'||result.feeCharged!==false||
      result.rightsGranted!==false||result.flightsActivated!==false||
      !Array.isArray(result.issues)||result.issues.length>20||
      typeof result.eligible!=='boolean'||
      result.issues.some(issue=>typeof issue!=='string'||! /^[A-Z0-9_]{3,100}$/.test(issue)))
    throw Error('Unsafe Licence 2 refresh response');
   return result;
  },
  async withdrawLicence2Draft({airlineId,applicationId}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(applicationId||''))
    throw Error('Invalid Licence 2 withdrawal request');
   const result=await post({action:'licence2_withdraw',airlineId,applicationId});
   if(!['DRAFT_WITHDRAWN','DRAFT_ALREADY_WITHDRAWN','DRAFT_NOT_WITHDRAWABLE','DRAFT_NOT_FOUND'].includes(result.status)||
      typeof result.withdrawn!=='boolean'||result.feeCharged!==false||
      result.rightsGranted!==false||result.flightsActivated!==false)
     throw Error('Unsafe Licence 2 withdrawal response');
   return result;
  },
  async saveLicence2Draft({airlineId,marketCode,level}={}){
   const levels={'L2-EU':4,'L2-US':4,'L2-UK':2,'L2-JP':2};
   if(!UUID.test(airlineId||'')||!Object.hasOwn(levels,marketCode)||
      !Number.isInteger(level)||level<1||level>levels[marketCode])
    throw Error('Invalid Licence 2 draft request');
   const result=await post({action:'licence2_draft',airlineId,marketCode,level});
   if(!['APPLICATION_DRAFT_STAGED_NOT_SUBMITTED','EXISTING_APPLICATION_ALREADY_OPEN',
     'ALREADY_HOLDS_SUFFICIENT_LEVEL','INVALID_OR_UNSUPPORTED_MARKET_LEVEL']
      .includes(result.status)||
      result.submitted!==false||result.feeCharged!==false||
      result.rightsGranted!==false||result.flightsActivated!==false||
      typeof result.created!=='boolean')
    throw Error('Unsafe Licence 2 draft response');
   return result;
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
