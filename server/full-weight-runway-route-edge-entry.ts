/** Authenticated read-only full MTOW/MLW airport runway length planning lookup.
 * Airlinerra World 1 only. Non-certified game calculation, not flight dispatch.
 */
import {Pool} from 'npm:pg@8.16.3';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings} from '../website/invited-tester-public-settings.mjs';

const ORIGIN='https://airlinerra.com';
const ROUTE='/api/v1/player/runway-full-weight-check';
const AUTH=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const AIRPORT_KEY=/^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const auth=createHostedAuthVerifier({publishableKey:settings.publishableKey});
const respond=(status:number,payload:unknown)=>Response.json(payload,{status,headers:{
 'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'
}});
let pool:any=null;
const SQL=`SELECT * FROM airlinerra_game.section5_full_weight_route_runway_check_v2(
 1::smallint,$1::text,$2::text,$3::bigint)`;
function valueOrNull(x:unknown):number|null{
 if(x===null||x===undefined||x==='')return null;
 const n=Number(x);return Number.isFinite(n)?n:null;
}
Deno.serve(async(request:Request)=>{
 if(request.method!=='POST')return respond(405,{error:'Method not allowed'});
 if(request.headers.get('origin')!==ORIGIN||
   request.headers.get('x-airlinerra-route')!==ROUTE)return respond(403,{error:'Forbidden'});
 if(request.headers.get('content-type')!=='application/json')
   return respond(415,{error:'JSON required'});
 const token=AUTH.exec(request.headers.get('authorization')||'')?.[1];
 if(!token)return respond(401,{error:'Verified session required'});
 let input:any;
 try{
  const raw=await request.arrayBuffer();
  if(raw.byteLength>512)return respond(413,{error:'Request too large'});
  input=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(raw));
 }catch{return respond(400,{error:'Invalid request JSON'});}
 if(!input||typeof input!=='object'||Array.isArray(input)||
    Object.keys(input).sort().join(',')!=='configurationId,destinationAirportKey,originAirportKey'||
    typeof input.originAirportKey!=='string'||!AIRPORT_KEY.test(input.originAirportKey)||
    typeof input.destinationAirportKey!=='string'||!AIRPORT_KEY.test(input.destinationAirportKey)||
    input.originAirportKey===input.destinationAirportKey||
    !Number.isInteger(input.configurationId)||input.configurationId<1||input.configurationId>1000000)
    return respond(400,{error:'Invalid airport/aircraft route parameters'});
 const verified=await auth(token);
 if(verified?.error||!verified?.user?.id)return respond(401,{error:'Verified session required'});
 if(!DB_URL)return respond(503,{error:'Runway model not configured'});
 let client:any;
 try{
  if(!pool)pool=new Pool({connectionString:DB_URL,ssl:{rejectUnauthorized:true},
   max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
  client=await pool.connect();
  const rows=(await client.query(SQL,[
   input.originAirportKey,input.destinationAirportKey,input.configurationId])).rows;
  if(!Array.isArray(rows)||rows.length!==1)return respond(404,{error:'World 1 airport or aircraft model not found'});
  const r=rows[0];
  const toOkay=r.origin_full_weight_takeoff_possible===true;
  const landOkay=r.destination_full_weight_landing_possible===true;
  return respond(200,{
   modelVersion:'FULL_WEIGHT_MTOW_MLW_ISA_ELEVATION_PLANNING_V2',
   scope:'AIRLINERRA_GAME_ONLY_NOT_CERTIFIED_DISPATCH',
   aircraft:{configurationId:input.configurationId,model:r.aircraft_model,
     maximumTakeoffWeightKg:valueOrNull(r.mtow_kg),
     maximumLandingWeightKg:valueOrNull(r.mlw_kg)},
   origin:{code:r.origin_airport_code,runwayAvailableM:valueOrNull(r.origin_runway_available_m),
     requiredTakeoffM:valueOrNull(r.required_origin_takeoff_m),fullWeightTakeoffPass:toOkay},
   destination:{code:r.destination_airport_code,runwayAvailableM:valueOrNull(r.destination_runway_available_m),
     requiredLandingM:valueOrNull(r.required_destination_landing_m),fullWeightLandingPass:landOkay},
   fullWeightOneWayRunwayPass:toOkay&&landOkay,
   fullWeightReverseRunwayPass:r.reverse_full_weight_length_screen_pass===true,
   reason:r.game_screening_result,
   flightFuelPayloadWeatherDeclaredDistancesAndPermissionsNotYetChecked:true
  });
 }catch{
  return respond(503,{error:'Runway planning data temporarily unavailable'});
 }finally{try{client?.release()}catch{/* release failure intentionally hidden */}}
});
