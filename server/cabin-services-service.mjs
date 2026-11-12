/** Verified owner API for cabin package designs. Does not operate flights or money. */
import {cleanCabinState,initialCabinState,CABIN_DATA_SCHEMA_ID} from '../website/cabin-services-manager.mjs';
export const CABIN_ROUTE='/api/v1/player/cabin-services';
const TOKEN=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const response=(status,body)=>Response.json(body,{status,headers:{
 'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
function equal(a,b){
 if(a===b)return true;
 if(Array.isArray(a)||Array.isArray(b))
  return Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((v,i)=>equal(v,b[i]));
 if(!object(a)||!object(b))return false;
 const keys=Object.keys(a);
 return keys.length===Object.keys(b).length&&keys.every(k=>Object.hasOwn(b,k)&&equal(a[k],b[k]));
}
export function validCabinState(s){return object(s)&&equal(s,cleanCabinState(s));}
export function validCabinRequest(b){
 if(!object(b)||!UUID.test(b.airlineId||''))return false;
 if(b.action==='read')return Object.keys(b).length===2;
 return b.action==='save'&&Object.keys(b).length===4&&
  Number.isSafeInteger(b.expectedVersion)&&b.expectedVersion>=0&&b.expectedVersion<2147483647&&
  validCabinState(b.state);
}
export const CABIN_SQL=Object.freeze({
 owner:'SELECT id FROM airlinerra_game.airlines WHERE id=$1::uuid AND owner_player_id=$2::uuid AND world_id=1',
 read:'SELECT state,version,updated_at AS "updatedAt" FROM airlinerra_game.airline_cabin_service_settings_v1 WHERE airline_id=$1::uuid',
 save:`INSERT INTO airlinerra_game.airline_cabin_service_settings_v1 AS c
 (airline_id,world_id,state,version)
 SELECT a.id,1,$3::jsonb,1 FROM airlinerra_game.airlines a
 WHERE a.id=$1::uuid AND a.owner_player_id=$2::uuid AND a.world_id=1
 AND ($4::integer=0 OR EXISTS (SELECT 1 FROM airlinerra_game.airline_cabin_service_settings_v1 q WHERE q.airline_id=a.id))
 ON CONFLICT (airline_id) DO UPDATE
 SET state=EXCLUDED.state,version=c.version+1,updated_at=now()
 WHERE c.version=$4::integer
 RETURNING state,version,updated_at AS "updatedAt"`
});
export function createCabinServicesHandler({verifyUserToken,database}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
  throw Error('Verified cabin backend required');
 return async function handle(req){
  if(!(req instanceof Request))return response(400,{error:'Invalid request'});
  if(req.method!=='POST')return response(405,{error:'POST required'});
  if(req.headers.get('origin')!=='https://airlinerra.com'||
     req.headers.get('x-airlinerra-route')!==CABIN_ROUTE)return response(403,{error:'Forbidden'});
  if(req.headers.get('content-type')!=='application/json')return response(415,{error:'JSON required'});
  const token=TOKEN.exec(req.headers.get('authorization')||'')?.[1];
  if(!token)return response(401,{error:'Verified session required'});
  let body;
  try{
   const bytes=await req.arrayBuffer();
   if(bytes.byteLength>16384)return response(413,{error:'Request too large'});
   body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
  }catch{return response(400,{error:'Invalid JSON'});}
  if(!validCabinRequest(body))return response(400,{error:'Invalid cabin state'});
  const verified=await verifyUserToken(token),userId=verified?.user?.id;
  if(verified?.error||!UUID.test(userId||''))return response(401,{error:'Verified session required'});
  let db;
  try{
   db=await database.connect();
   const owned=await db.query(CABIN_SQL.owner,[body.airlineId,userId]);
   if(owned.rowCount!==1)return response(403,{error:'Airline not owned'});
   if(body.action==='read'){
    const rows=await db.query(CABIN_SQL.read,[body.airlineId]),first=rows.rows[0];
    return response(200,{state:first?.state||initialCabinState(),version:first?.version||0,
      source:'supabase',schemaId:CABIN_DATA_SCHEMA_ID,operational:false,updatedAt:first?.updatedAt||null});
   }
   const rows=await db.query(CABIN_SQL.save,[body.airlineId,userId,JSON.stringify(body.state),body.expectedVersion]);
   if(rows.rowCount!==1)return response(409,{error:'CABIN_VERSION_CONFLICT'});
   const first=rows.rows[0];
   return response(200,{state:first.state,version:first.version,updatedAt:first.updatedAt,
      source:'supabase',schemaId:CABIN_DATA_SCHEMA_ID,operational:false,ledgerPosted:false,flightsChanged:false});
  }catch{return response(503,{error:'Cabin storage temporarily unavailable'});}
  finally{try{db?.release()}catch{}}
 };
}
