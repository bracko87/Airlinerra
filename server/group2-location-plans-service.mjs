/** Owner-only Group 2 location planning: never sets active HQ, office, flight or ledger. */
import {verifiedPlayerId} from './airline-activation.mjs';
export const GROUP2_LOCATION_PATH='/api/v1/player/group2-location-plans';
const KEY=/^OURAIRPORTS:[1-9][0-9]{0,18}$/u;
const BEARER=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const HEADERS={'content-type':'application/json; charset=utf-8','cache-control':'no-store','x-content-type-options':'nosniff'};
const reply=(status,payload)=>new Response(JSON.stringify(payload),{status,headers:HEADERS});
const fail=(code,status=409)=>{const e=new Error(code);e.httpStatus=status;return e;};
const TYPES=new Set(['future_hq','hub','station']);
const listSql=`select i.airport_key as "key",g.game_airport_name as "name",
 g.game_lookup_code as "code",g.country_iso as "countryIso",
 g.owner_category as "category",i.intent_type as "type",i.intent_status as "status"
 from airlinerra_game.airport_group2_location_intents_v1 i
 join airlinerra_game.airlines a on a.id=i.airline_id and a.world_id=i.world_id
 join airlinerra_game.airport_group2_game_profiles_v1 g on g.airport_key=i.airport_key
 where a.owner_player_id=$1::uuid and a.world_id=1
 order by i.created_at,i.id limit 22`;
const airlineSql=`select id from airlinerra_game.airlines where owner_player_id=$1::uuid and world_id=1 for update`;
const eligibleSql=`select g.airport_key from airlinerra_game.airport_group2_game_profiles_v1 g
 join airlinerra_game.airport_sections1_8_combined_members_v1 c
 on c.airport_key=g.airport_key and c.world_id=1
 where g.airport_key=$1::text and c.source_group='GROUP_2'
 and c.commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'
 and g.game_data_status='game_complete_estimated'
 and not g.commercial_playable and not g.commercial_access_verified`;
const countsSql=`select intent_type,airport_key from airlinerra_game.airport_group2_location_intents_v1
 where airline_id=$1::uuid and world_id=1 for update`;
const insertSql=`insert into airlinerra_game.airport_group2_location_intents_v1
 (world_id,airline_id,airport_key,intent_type)
 values (1,$1::uuid,$2::text,$3::text)
 returning airport_key,intent_type,intent_status`;
const deleteSql=`delete from airlinerra_game.airport_group2_location_intents_v1
 where world_id=1 and airline_id=$1::uuid and airport_key=$2::text returning airport_key`;
export function createGroup2LocationPlanHandler({verifyUserToken,database,origin='https://airlinerra.com'}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function'||
 !['https://airlinerra.com','http://localhost:5188'].includes(origin))
 throw Error('Trusted game API required');
 return async request=>{
  const url=new URL(request.url);
  if(url.origin!==origin||request.headers.get('origin')!==origin)return reply(403,{error:'Forbidden'});
  if(url.pathname!==GROUP2_LOCATION_PATH||url.search||url.hash)return reply(404,{error:'Not found'});
  if(request.method!=='POST')return reply(405,{error:'POST only'});
  if(request.headers.get('content-type')!=='application/json')return reply(415,{error:'JSON only'});
  const token=BEARER.exec(request.headers.get('authorization')||'')?.[1];
  if(!token)return reply(401,{error:'Verified session required'});
  let payload;
  try{
   const raw=await request.text();
   if(new TextEncoder().encode(raw).byteLength>512)throw Error('oversized');
   payload=JSON.parse(raw);
   if(!payload||typeof payload!=='object'||Array.isArray(payload)||
      !['list','save','remove'].includes(payload.action)||
      (payload.worldId!==undefined&&payload.worldId!==1)||
      Object.keys(payload).some(k=>!['action','worldId','airportKey','type'].includes(k))||
      (payload.action==='list'&&Object.keys(payload).some(k=>!['action','worldId'].includes(k)))||
      (payload.action==='save'&&(!KEY.test(payload.airportKey||'')||!TYPES.has(payload.type)))||
      (payload.action==='remove'&&(!KEY.test(payload.airportKey||'')||payload.type!==undefined)))
      throw Error('Invalid payload');
  }catch{return reply(400,{error:'Invalid request'});}
  let playerId;
  try{playerId=verifiedPlayerId(await verifyUserToken(token))}
  catch{return reply(401,{error:'Verified session required'});}
  let db,started=false;
  try{
   db=await database.connect();
   if(payload.action==='list'){
    const rows=(await db.query(listSql,[playerId])).rows;
    if(!Array.isArray(rows)||rows.length>21)throw Error('Invalid owner locations');
    return reply(200,{locations:rows,source:'group2_planned_only',commercialAccess:false,flightsEnabled:false});
   }
   await db.query('BEGIN');started=true;
   const owner=(await db.query(airlineSql,[playerId])).rows[0];
   if(!owner)throw fail('Register an airline before planning locations',404);
   if(payload.action==='remove'){
    const removed=(await db.query(deleteSql,[owner.id,payload.airportKey])).rows.length===1;
    await db.query('COMMIT');started=false;
    return reply(200,{removed,commercialAccess:false,flightsEnabled:false});
   }
   const airport=(await db.query(eligibleSql,[payload.airportKey])).rows[0];
   if(!airport)throw fail('Airport not eligible for Group 2 planning');
   const existing=(await db.query(countsSql,[owner.id])).rows;
   if(existing.some(x=>x.airport_key===payload.airportKey)){
    const old=existing.find(x=>x.airport_key===payload.airportKey);
    if(old.intent_type!==payload.type)throw fail('Location already planned with different type');
    await db.query('COMMIT');started=false;
    return reply(200,{location:{key:payload.airportKey,type:payload.type,status:'planned_only'},commercialAccess:false,flightsEnabled:false});
   }
   if(payload.type==='future_hq'&&existing.some(x=>x.intent_type==='future_hq'))
    throw fail('One future HQ at a time');
   if(payload.type!=='future_hq'&&existing.filter(x=>x.intent_type!=='future_hq').length>=20)
    throw fail('Maximum 20 planned hubs and stations');
   const saved=(await db.query(insertSql,[owner.id,payload.airportKey,payload.type])).rows[0];
   if(!saved||saved.intent_status!=='planned_only')throw Error('Invalid location save');
   await db.query('COMMIT');started=false;
   return reply(201,{location:{key:saved.airport_key,type:saved.intent_type,status:'planned_only'},commercialAccess:false,flightsEnabled:false});
  }catch(e){
   if(started)try{await db.query('ROLLBACK')}catch{}
   return reply(e.httpStatus||((e.code==='23505'||e.code==='23514')?409:503),
    {error:e.httpStatus?e.message:'Location planning unavailable'});
  }finally{try{db?.release()}catch{}}
 };
}
