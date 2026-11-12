/** Owner-scoped Supabase is the sole authoritative store for in-game drafts.
 * Browser stores may be READ ONCE to migrate legacy drafts; never written.
 * Incomplete drafts have no operational or financial effect.
 */
const KINDS=Object.freeze(['preferences','workplan']);
const PREF_KEYS=new Set(['units','time','date','timezone','language','theme',
 'density','motion','landing','hints']);
const PLAN_KEYS=new Set(['budget','routes','route','hubs','staff','ticketPrice','airportOffices']);
const MAX_BYTES=30000;
const safeObject=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
const clone=x=>JSON.parse(JSON.stringify(x));
const jsonBytes=x=>new TextEncoder().encode(JSON.stringify(x)).length;
const clean=(kind,raw)=>{
 if(!safeObject(raw))return {};
 const keys=kind==='preferences'?PREF_KEYS:PLAN_KEYS;
 const found=Object.fromEntries(Object.entries(raw).filter(([k])=>keys.has(k)));
 if(kind==='workplan'){
  for(const key of ['routes','hubs','staff','airportOffices'])
   if(key in found&&!Array.isArray(found[key]))delete found[key];
  if(Array.isArray(found.routes))found.routes=found.routes.slice(0,25);
  if(Array.isArray(found.hubs))found.hubs=found.hubs.slice(0,50);
  if(Array.isArray(found.staff))found.staff=found.staff.slice(0,50);
  if(Array.isArray(found.airportOffices))found.airportOffices=found.airportOffices.slice(0,20);
 }else for(const k of Object.keys(found))
  if(k==='hints'?typeof found[k]!=='boolean':
   typeof found[k]!=='string'||found[k].length>64)delete found[k];
 try{return jsonBytes(found)<=MAX_BYTES?clone(found):{}}
 catch{return {}}
};
const readLegacy=(store,key)=>{
 try{return JSON.parse(store?.getItem(key)||'null')}
 catch{return null}
};
const canonical=value=>{
 if(Array.isArray(value))return '['+value.map(canonical).join(',')+']';
 if(value&&typeof value==='object')return '{'+Object.keys(value).sort().map(k=>
  JSON.stringify(k)+':'+canonical(value[k])).join(',')+'}';
 return JSON.stringify(value);
};
const fullLegacyMatch=(kind,raw,remote)=>{
 if(!safeObject(raw)||!safeObject(remote))return false;
 const allowed=kind==='preferences'?PREF_KEYS:PLAN_KEYS;
 return Object.keys(raw).every(k=>allowed.has(k))&&
  canonical(raw)===canonical(remote);
};
const retireVerifiedLegacy=(store,key,kind,raw,remote)=>{
 if(!fullLegacyMatch(kind,raw,remote))return false;
 try{store?.removeItem?.(key);return typeof store?.removeItem==='function'}
 catch{return false}
};
export function createPlayerDraftStore({client,identity,session,storage}={}){
 if(typeof client?.read!=='function'||typeof client?.save!=='function'||
  typeof identity!=='string'||identity.length<3)
  throw Error('Verified owner draft client required');
 let airlineId=null,generation=0;
 const records=Object.fromEntries(KINDS.map(kind=>[kind,{ready:false,version:0,state:{},
  migrationPending:false}]));
 const queue={preferences:Promise.resolve(),workplan:Promise.resolve()};
 const listeners=new Set();
 const tell=()=>{for(const fn of listeners)try{fn()}catch{}};
 const snapshot=kind=>clone(records[kind]?.state??{});
 // Unresolved legacy data is a blocked save, not a silent overwrite.
 const ready=kind=>Boolean(airlineId&&records[kind]?.ready&&
  !records[kind]?.migrationPending);
 const pendingMigration=kind=>Boolean(records[kind]?.migrationPending);
 const load=async id=>{
  const serial=++generation;airlineId=id;
  for(const kind of KINDS)records[kind]={ready:false,version:0,state:{},
   migrationPending:false};
  tell();
  if(typeof id!=='string')return false;
  const legacyKeys={
   preferences:'airlinerra.ui.preferences.v1.'+identity,
   workplan:'airlinerra.local.workplan.v1.'+identity
  };
  const sources={preferences:storage,workplan:session};
  const results=await Promise.all(KINDS.map(async kind=>{
   const result=await client.read({airlineId:id,kind});
   if(result.kind!==kind||result.source!=='supabase'||result.operational!==false||
    !Number.isInteger(result.version)||result.version<0)
    throw Error('Unverified server workspace document');
   let current=result,migrationPending=false;
   const legacyRaw=readLegacy(sources[kind],legacyKeys[kind]);
   const legacy=clean(kind,legacyRaw);
   if(safeObject(legacyRaw)&&Object.keys(legacyRaw).length&&
     !Object.keys(legacy).length)migrationPending=true;
   if(Object.keys(legacy).length&&current.version===0){
    try{
     current=await client.save({airlineId:id,kind,state:legacy,expectedVersion:0});
     if(current.source!=='supabase'||current.version!==1||
      current.operational!==false)throw Error('Unconfirmed legacy import');
     if(!retireVerifiedLegacy(sources[kind],legacyKeys[kind],
       kind,legacyRaw,current.state))migrationPending=true;
    }catch{migrationPending=true}
   }else if(Object.keys(legacy).length&&current.version>0){
    // Existing database records win. Retire browser data only if identical.
    if(!retireVerifiedLegacy(sources[kind],legacyKeys[kind],
      kind,legacyRaw,current.state))migrationPending=true;
   }
   return {kind,version:current.version,state:clean(kind,current.state),
    migrationPending};
  }).map(p=>p.catch(error=>({error}))));
  if(serial!==generation||airlineId!==id)return false;
  for(let i=0;i<KINDS.length;i++){
   const kind=KINDS[i],result=results[i];
   records[kind]=result.error?
    {ready:false,version:0,state:{},migrationPending:true}:
    {ready:true,version:result.version,state:result.state,
     migrationPending:result.migrationPending};
  }
  tell();return KINDS.every(kind=>ready(kind)&&!pendingMigration(kind));
 };
 const update=async(kind,patch)=>{
  if(!KINDS.includes(kind)||!safeObject(patch))throw Error('Invalid workspace patch');
  const run=async()=>{
   if(!ready(kind))throw Error('Workspace database not ready');
   const record=records[kind],newState=clean(kind,{...record.state,...patch});
   if(Object.keys(newState).length!==new Set([
    ...Object.keys(record.state),...Object.keys(patch)
   ].filter(k=>(kind==='preferences'?PREF_KEYS:PLAN_KEYS).has(k))).size)
    throw Error('Invalid workspace fields');
   const answer=await client.save({airlineId,kind,state:newState,
    expectedVersion:record.version});
   if(answer.source!=='supabase'||answer.kind!==kind||
    answer.operational!==false||answer.version!==record.version+1)
    throw Error('Unconfirmed database save');
   record.state=clean(kind,answer.state);record.version=answer.version;
   tell();return snapshot(kind);
  };
  const operation=queue[kind].catch(()=>{}).then(run);
  queue[kind]=operation;return operation;
 };
 return Object.freeze({
  load,update,snapshot,ready,pendingMigration,
  subscribe:fn=>{if(typeof fn!=='function')throw Error('Subscriber required');
   listeners.add(fn);return ()=>listeners.delete(fn)}
 });
}
