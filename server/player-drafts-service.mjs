/** Protected World 1 owner-scoped, non-operational player workspace data.
 * No gameplay writes: routes, certifications, staff, slots and finance must use
 * their own independently verified APIs. This endpoint only saves draft JSON.
 */
export const PLAYER_DRAFTS_ROUTE='/api/v1/player/workspace-drafts';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const TOKEN=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const RESP_HEADERS={'cache-control':'no-store','x-content-type-options':'nosniff',
 'referrer-policy':'no-referrer'};
const make=(status,payload)=>Response.json(payload,{status,headers:RESP_HEADERS});
const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
const KINDS=new Set(['preferences','workplan']);
const PREFERENCE_KEYS=new Set(['units','time','date','timezone','language','theme',
 'density','motion','landing','hints']);
const WORKPLAN_KEYS=new Set(['budget','routes','route','hubs','staff',
 'ticketPrice','airportOffices']);
function noPrototypes(value,depth=0){
 if(depth>8)return false;
 if(Array.isArray(value))return value.length<=100&&value.every(v=>noPrototypes(v,depth+1));
 if(!object(value))return value===null||typeof value==='string'&&value.length<=1024||
  typeof value==='boolean'||typeof value==='number'&&Number.isFinite(value);
 return Object.keys(value).length<=50&&Object.entries(value).every(([key,v])=>
  key!=='__proto__'&&key!=='constructor'&&key!=='prototype'&&
  key.length<=80&&noPrototypes(v,depth+1));
}
export function validPlayerDraftDocument(kind,state){
 if(!KINDS.has(kind)||!object(state))return false;
 const keys=Object.keys(state),allowed=kind==='preferences'?PREFERENCE_KEYS:WORKPLAN_KEYS;
 if(keys.length>allowed.size||!keys.every(k=>allowed.has(k))||!noPrototypes(state))return false;
 if(kind==='preferences'&&!keys.every(k=>k==='hints'?
  typeof state[k]==='boolean':
  typeof state[k]==='string'&&state[k].length<=64))return false;
 for(const key of ['routes','hubs','staff','airportOffices'])
  if(Object.hasOwn(state,key)&&(!Array.isArray(state[key])||
    state[key].length>(key==='routes'?25:key==='airportOffices'?20:50)))return false;
 try{return new TextEncoder().encode(JSON.stringify(state)).length<=30000}
 catch{return false}
}
export function validatePlayerDraftRequest(body){
 if(!object(body)||!UUID.test(body.airlineId||'')||!KINDS.has(body.kind))return false;
 if(body.action==='read')
  return Object.keys(body).length===3;
 return body.action==='save'&&Object.keys(body).length===5&&
  Number.isSafeInteger(body.expectedVersion)&&body.expectedVersion>=0&&
  body.expectedVersion<2147483647&&validPlayerDraftDocument(body.kind,body.state);
}
export const PLAYER_DRAFT_SQL=Object.freeze({
 owner:`SELECT id FROM airlinerra_game.airlines
 WHERE id=$1::uuid AND owner_player_id=$2::uuid AND world_id=1`,
 read:`SELECT state,version,updated_at AS "updatedAt"
 FROM airlinerra_game.airline_player_drafts_v1
 WHERE airline_id=$1::uuid AND kind=$2::text AND world_id=1`,
 save:`INSERT INTO airlinerra_game.airline_player_drafts_v1 AS d
  (airline_id,world_id,kind,state,version)
  SELECT a.id,1,$3::text,$4::jsonb,1
  FROM airlinerra_game.airlines a
  WHERE a.id=$1::uuid AND a.owner_player_id=$2::uuid AND a.world_id=1
   AND ($5::integer=0 OR EXISTS(
    SELECT 1 FROM airlinerra_game.airline_player_drafts_v1 q
    WHERE q.airline_id=a.id AND q.kind=$3::text))
  ON CONFLICT (airline_id,kind) DO UPDATE
  SET state=EXCLUDED.state,version=d.version+1,updated_at=now()
  WHERE d.version=$5::integer
  RETURNING state,version,updated_at AS "updatedAt"`
});
export function createPlayerDraftsHandler({verifyUserToken,database}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
  throw Error('Verified player drafts backend required');
 return async function handler(request){
  if(!(request instanceof Request))return make(400,{error:'Invalid request'});
  if(request.method!=='POST')return make(405,{error:'POST required'});
  if(request.headers.get('origin')!=='https://airlinerra.com'||
   request.headers.get('x-airlinerra-route')!==PLAYER_DRAFTS_ROUTE)
   return make(403,{error:'Forbidden'});
  if(request.headers.get('content-type')!=='application/json')
   return make(415,{error:'JSON required'});
  const token=TOKEN.exec(request.headers.get('authorization')||'')?.[1];
  if(!token)return make(401,{error:'Verified session required'});
  let body;
  try{
   const bytes=await request.arrayBuffer();
   if(bytes.byteLength>32768)return make(413,{error:'Workspace draft too large'});
   body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));
  }catch{return make(400,{error:'Invalid request body'})}
  if(!validatePlayerDraftRequest(body))return make(400,{error:'Invalid draft'});
  const verified=await verifyUserToken(token),userId=verified?.user?.id;
  if(verified?.error||!UUID.test(userId||''))
   return make(401,{error:'Verified session required'});
  let client;
  try{
   client=await database.connect();
   const owner=await client.query(PLAYER_DRAFT_SQL.owner,[body.airlineId,userId]);
   if(owner.rowCount!==1)return make(403,{error:'Airline not owned'});
   if(body.action==='read'){
    const result=await client.query(PLAYER_DRAFT_SQL.read,[body.airlineId,body.kind]);
    const row=result.rows[0];
    return make(200,{kind:body.kind,state:row?.state||{},version:row?.version||0,
     updatedAt:row?.updatedAt||null,source:'supabase',operational:false});
   }
   const result=await client.query(PLAYER_DRAFT_SQL.save,[
    body.airlineId,userId,body.kind,JSON.stringify(body.state),body.expectedVersion
   ]);
   if(result.rowCount!==1)return make(409,{error:'WORKSPACE_VERSION_CONFLICT'});
   const row=result.rows[0];
   return make(200,{kind:body.kind,state:row.state,version:row.version,
    updatedAt:row.updatedAt,source:'supabase',operational:false,
    flightsChanged:false,ledgerPosted:false,officesActivated:false});
  }catch{return make(503,{error:'Workspace database unavailable'})}
  finally{try{client?.release()}catch{}}
 };
}
