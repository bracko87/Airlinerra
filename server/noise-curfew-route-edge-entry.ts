/** World1 authenticated route noise/curfew check, game planning only.
 * Does not grant certified aircraft noise/airport operating permission.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';

const ORIGIN='https://airlinerra.com';
const ROUTE='/api/v1/player/noise-curfew-check';
const AUTH=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const AIRPORT=/^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const ISO_UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u;
const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const verify=createHostedAuthVerifier({publishableKey:settings.publishableKey});
const respond=(status:number,payload:unknown)=>Response.json(payload,{
 status,headers:{'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}
});
const isUtc=(value:unknown):value is string=>
 typeof value==='string'&&ISO_UTC.test(value)&&Number.isFinite(Date.parse(value))&&
 new Date(value).toISOString().slice(0,19)+'Z'===value;
let pool:any=null;
const SQL=`SELECT airlinerra_game.section5_universal_route_restriction_gate_v1(
 1::smallint,$1::text,$2::text,$3::bigint,$4::timestamptz,$5::timestamptz,$6::text,$7::text
) AS gate`;
const ALLOWED_FIELDS=new Set(['arrivalUtc','configurationId','departureUtc',
 'destinationAirportKey','originAirportKey','originRunwaySourceId','destinationRunwaySourceId']);
const RUNWAY_ID=/^[A-Za-z0-9:_-]{1,64}$/u;
Deno.serve(async(request:Request)=>{
 if(request.method!=='POST')return respond(405,{error:'Method not allowed'});
 if(request.headers.get('origin')!==ORIGIN||
    request.headers.get('x-airlinerra-route')!==ROUTE)return respond(403,{error:'Forbidden'});
 if(request.headers.get('content-type')!=='application/json')
    return respond(415,{error:'JSON required'});
 const token=AUTH.exec(request.headers.get('authorization')||'')?.[1];
 if(!token)return respond(401,{error:'Verified session required'});
 let body:any;
 try {
  const bytes=await request.arrayBuffer();
  if(bytes.byteLength>1024)return respond(413,{error:'Request too large'});
  body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
 }catch{return respond(400,{error:'Invalid JSON request'});}
 if(!body||typeof body!=='object'||Array.isArray(body)||
  Object.keys(body).some(field=>!ALLOWED_FIELDS.has(field))||
  !['arrivalUtc','configurationId','departureUtc','destinationAirportKey','originAirportKey']
    .every(field=>Object.prototype.hasOwnProperty.call(body,field))||
  (body.originRunwaySourceId!==undefined&&!RUNWAY_ID.test(body.originRunwaySourceId))||
  (body.destinationRunwaySourceId!==undefined&&!RUNWAY_ID.test(body.destinationRunwaySourceId))||
  !Number.isInteger(body.configurationId)||body.configurationId<1||body.configurationId>1000000||
  typeof body.originAirportKey!=='string'||!AIRPORT.test(body.originAirportKey)||
  typeof body.destinationAirportKey!=='string'||!AIRPORT.test(body.destinationAirportKey)||
  body.originAirportKey===body.destinationAirportKey||
  !isUtc(body.departureUtc)||!isUtc(body.arrivalUtc)||
  Date.parse(body.arrivalUtc)<=Date.parse(body.departureUtc)||
  Date.parse(body.arrivalUtc)-Date.parse(body.departureUtc)>72*3600*1000)
   return respond(400,{error:'Invalid route aircraft or UTC schedule'});
 const result=await verify(token);
 if(result.error||!result.user?.id)return respond(401,{error:'Verified session required'});
 if(!DB_URL)return respond(503,{error:'Route airport noise model not configured'});
 let client:any;
 try{
  if(!pool)pool=new Pool({connectionString:DB_URL,ssl:{rejectUnauthorized:true},
    max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
  client=await pool.connect();
  const rows=(await client.query(SQL,[
    body.originAirportKey,body.destinationAirportKey,body.configurationId,
    body.departureUtc,body.arrivalUtc,
    body.originRunwaySourceId??null,body.destinationRunwaySourceId??null
  ])).rows;
  const gate=rows[0]?.gate;
  if(rows.length!==1||!gate||typeof gate!=='object')
   return respond(404,{error:'Airport or aircraft restriction screen not found'});
  const dep=gate.origin||{},arr=gate.destination||{};
  const runwayPass=(leg:any)=>leg.runwayLengthEvidence==='FULL_WEIGHT_GAME_REFERENCE'&&
    Number.isFinite(Number(leg.runwayLengthM))&&
    Number.isFinite(Number(leg.requiredGameRunwayLengthM))&&
    Number(leg.runwayLengthM)>=Number(leg.requiredGameRunwayLengthM);
  return respond(200,{
    modelVersion:'AIRLINERRA_UNIVERSAL_ROUTE_RESTRICTIONS_V1',
    worldId:1,
    aircraft:{configurationId:body.configurationId,model:dep.aircraftModel??null,
      sourceSupportedIcaoChapter:dep.sourceMatchedIcaoChapter??null,
      chapterConfigurationNotMatched:dep.aircraftChapterNotConfigurationMatched===true},
    origin:{code:dep.airportCode??null,localTime:dep.localAirportTime??null,
      selectedRunwaySourceId:dep.selectedRunwaySourceId??null,
      selectedRunwayDesignator:dep.selectedRunwayDesignator??null,
      requiredRunwayM:dep.requiredGameRunwayLengthM??null,
      availableRunwayM:dep.runwayLengthM??null,
      runwayOperationalStatusVerified:dep.runwayOperationalStatusVerified===true,
      outcome:dep.decision??null,curfewBlocked:dep.blockedByAirportTimeRule===true,
      runwayBlocked:dep.blockedByRunwayRule===true||dep.blockedByRunwayLength===true,
      verifiedNoiseBlocked:dep.blockedByVerifiedNoiseRule===true,
      noiseOrSlotReviewRequired:dep.noiseReview===true||dep.quotaOrSlotReview===true},
    destination:{code:arr.airportCode??null,localTime:arr.localAirportTime??null,
      selectedRunwaySourceId:arr.selectedRunwaySourceId??null,
      selectedRunwayDesignator:arr.selectedRunwayDesignator??null,
      requiredRunwayM:arr.requiredGameRunwayLengthM??null,
      availableRunwayM:arr.runwayLengthM??null,
      runwayOperationalStatusVerified:arr.runwayOperationalStatusVerified===true,
      outcome:arr.decision??null,curfewBlocked:arr.blockedByAirportTimeRule===true,
      runwayBlocked:arr.blockedByRunwayRule===true||arr.blockedByRunwayLength===true,
      verifiedNoiseBlocked:arr.blockedByVerifiedNoiseRule===true,
      noiseOrSlotReviewRequired:arr.noiseReview===true||arr.quotaOrSlotReview===true},
    gameScheduleOutcome:gate.decision,
    gameHardBlocked:gate.gameHardBlocked===true,
    needsReview:gate.needsReview===true,
    runwayFullWeightScreenPass:runwayPass(dep)&&runwayPass(arr),
    canActivateNormalFlight:false,
    preliminarilyAllowed:gate.gamePreliminaryAllow===true,
    legalRealWorldClearance:false,
    universalGate:gate,
    note:'Game preflight restriction check only. No live flight or slot activation. Unknown runway operating status, noise certificates, traffic rights, NOTAM and real-world dispatch conditions require separate checks.'
  });
 }catch(error){
  const sqlError=error as {code?:unknown}|null;
  const code=typeof sqlError?.code==='string'&&/^[A-Z0-9]{5}$/.test(sqlError.code)?sqlError.code:'NONE';
  console.error('Airlinerra noise curfew read failed, SQLSTATE',code);
  return respond(503,{error:'Noise and curfew route check temporarily unavailable'});
 }finally{try{client?.release()}catch{/* ignore */}}
});
