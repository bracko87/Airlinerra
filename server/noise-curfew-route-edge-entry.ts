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
const SQL=`WITH dep AS (
 SELECT * FROM airlinerra_game.section5_game_airport_noise_curfew_check_v3(
 1::smallint,$1::text,$3::bigint,'departure',$4::timestamptz)
), arr AS (
 SELECT * FROM airlinerra_game.section5_game_airport_noise_curfew_check_v3(
 1::smallint,$2::text,$3::bigint,'arrival',$5::timestamptz)
)
SELECT dep.airport_code origin_code,arr.airport_code destination_code,
 dep.aircraft_model,dep.selected_engine,dep.game_icao_chapter,
 dep.official_icao_chapter,dep.aircraft_noise_evidence_level,
 dep.game_schedule_outcome dep_outcome,arr.game_schedule_outcome arr_outcome,
 dep.normal_schedule_prelim_permitted dep_preliminary,
 arr.normal_schedule_prelim_permitted arr_preliminary,
 dep.denied_by_documented_curfew dep_curfew,
 arr.denied_by_documented_curfew arr_curfew,
 dep.denied_by_game_chapter_rule dep_game_chapter,
 arr.denied_by_game_chapter_rule arr_game_chapter,
 dep.requires_special_noise_or_slot_review dep_review,
 arr.requires_special_noise_or_slot_review arr_review,
 dep.local_airport_time::text dep_local,arr.local_airport_time::text arr_local,
 dep.airport_chapter_evidence_status dep_airport_evidence,
 arr.airport_chapter_evidence_status arr_airport_evidence,
 airlinerra_game.section5_timed_route_schedule_gate_v1(
  1::smallint,$1::text,$2::text,$3::bigint,$4::timestamptz,$5::timestamptz)
  AS consolidated_gate
FROM dep CROSS JOIN arr`;
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
  Object.keys(body).sort().join(',')!=='arrivalUtc,configurationId,departureUtc,destinationAirportKey,originAirportKey'||
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
    body.departureUtc,body.arrivalUtc
  ])).rows;
  if(rows.length!==1)return respond(404,{error:'Airport or aircraft game configuration not found'});
  const r=rows[0];
  const gate=r.consolidated_gate||{};
  const status=String(gate.decision||'BLOCKED_UNRESOLVED_SCHEDULE_GATE');
  const blocked=status.startsWith('BLOCKED_');
  const needsReview=status==='SPECIAL_PERMISSION_OR_SLOT_REVIEW_REQUIRED';
  return respond(200,{
    modelVersion:'AIRLINERRA_SECTION5_COMBINED_SCHEDULE_GATE_V1',
    worldId:1,
    aircraft:{configurationId:body.configurationId,model:r.aircraft_model,
      selectedEngine:r.selected_engine,gameIcaoNoiseChapter:r.game_icao_chapter,
      sourceSupportedIcaoChapter:r.official_icao_chapter,
      noiseEvidence:r.aircraft_noise_evidence_level},
    origin:{code:r.origin_code,localTime:r.dep_local,
      outcome:r.dep_outcome,curfewBlocked:r.dep_curfew,
      gameNoiseChapterBlocked:r.dep_game_chapter,
      specialNoiseSlotReviewRequired:r.dep_review,
      airportNoiseResearchStatus:r.dep_airport_evidence},
    destination:{code:r.destination_code,localTime:r.arr_local,
      outcome:r.arr_outcome,curfewBlocked:r.arr_curfew,
      gameNoiseChapterBlocked:r.arr_game_chapter,
      specialNoiseSlotReviewRequired:r.arr_review,
      airportNoiseResearchStatus:r.arr_airport_evidence},
    gameScheduleOutcome:status,
    runwayFullWeightScreenPass:gate.runwayFullWeightScreenPass===true,
    runwayGameResult:gate.runwayGameResult??null,
    airportResearchPending:gate.airportResearchPending===true,
    aircraftChapterSourceEstimated:gate.aircraftChapterSourceEstimated===true,
    canActivateNormalFlight:false,
    preliminarilyAllowed:!blocked&&!needsReview,
    legalRealWorldClearance:false,
    exceptionsWeatherRunwayPerformanceAndActualQuotaLedgerNotChecked:true,
    actualRunwayNotamsOwnershipCrewWeatherAndQuotaLedgerNotChecked:true,
    note:'Based on source-backed or clearly estimated game noise Chapter and documented local operating limits. Runway-length screen and aircraft-noise game Chapter checks are not full dispatch clearance. Unknown airport curfews remain UNVERIFIED.'
  });
 }catch(error){
  const sqlError=error as {code?:unknown}|null;
  const code=typeof sqlError?.code==='string'&&/^[A-Z0-9]{5}$/.test(sqlError.code)?sqlError.code:'NONE';
  console.error('Airlinerra noise curfew read failed, SQLSTATE',code);
  return respond(503,{error:'Noise and curfew route check temporarily unavailable'});
 }finally{try{client?.release()}catch{/* ignore */}}
});
