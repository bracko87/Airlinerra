/** Localhost-only, read-only game catalog served from an exported verified snapshot.
 * No production database access, Supabase credentials, Auth tokens or game writes.
 */
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export const LOCAL_CATALOG_PATHS=Object.freeze({
 overview:'/__local_player__/overview',
 airports:'/__local_player__/airports'
});
const file=path.resolve(path.dirname(fileURLToPath(import.meta.url)),
 '..','dev-data','world1-approved-airports-2026-10-28.json');
const searchRe=/^[\p{L}\p{N} .,'()\-]{0,40}$/u;
export async function loadLocalCatalog(filename=file){
 const data=JSON.parse(await readFile(filename,'utf8'));
 if(!data.readOnly||data.snapshotDate!=='2026-10-28'||
   data.releaseGate!=='closed'||!Array.isArray(data.airports)||
   data.airports.length!==3140||!Array.isArray(data.worlds)||data.worlds.length!==3)
   throw Error('Verified local snapshot missing or incomplete');
 if(new Set(data.airports.map(x=>x.airport_key)).size!==3140)throw Error('Duplicate airport IDs');
 return data;
}
function reply(status,data){
 return new Response(JSON.stringify(data),{status,headers:{
   'content-type':'application/json; charset=utf-8','cache-control':'no-store',
   'x-content-type-options':'nosniff','referrer-policy':'no-referrer'
 }});
}
function countryCounts(rows){
 const result=new Map();
 for(const row of rows){
   if(!/^[A-Z]{2}$/u.test(row.country_iso))throw Error('Invalid country ISO');
   result.set(row.country_iso,(result.get(row.country_iso)||0)+1);
 }
 return [...result].sort(([a],[b])=>a.localeCompare(b))
   .map(([countryIso,airportCount])=>({countryIso,airportCount}));
}
async function boundedBody(request){
 if(!request.body)return null;
 const reader=request.body.getReader();
 let size=0;
 const chunks=[];
 try{
  while(true){
   const {done,value}=await reader.read();
   if(done)break;
   size+=value.byteLength;
   if(size>512){await reader.cancel().catch(()=>{});return null}
   chunks.push(value);
  }
 }finally{reader.releaseLock()}
 const buffer=new Uint8Array(size);let offset=0;
 for(const chunk of chunks){buffer.set(chunk,offset);offset+=chunk.byteLength}
 try{
  const value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(buffer));
  return value && typeof value==='object'&&!Array.isArray(value)?value:null;
 }catch{return null}
}
export async function handleLocalCatalogRequest(request,{catalog}={}){
 if(!(request instanceof Request))return reply(400,{error:'Invalid request'});
 const url=new URL(request.url),origin=request.headers.get('origin');
 if(url.protocol!=='http:'||!['localhost','127.0.0.1'].includes(url.hostname)||
   url.port!=='5188'||origin!==url.origin)return reply(403,{error:'Local preview only'});
 if(!Object.values(LOCAL_CATALOG_PATHS).includes(url.pathname)||url.search||url.hash)
   return reply(404,{error:'Not found'});
 if(request.method!=='POST')return reply(405,{error:'POST required'});
 if(request.headers.get('content-type')!=='application/json')
   return reply(415,{error:'JSON required'});
 const body=await boundedBody(request);
 if(!body)return reply(400,{error:'Invalid request'});
 const data=catalog||await loadLocalCatalog();
 if(url.pathname===LOCAL_CATALOG_PATHS.overview){
   if(Object.keys(body).length)return reply(400,{error:'Unexpected request fields'});
   return reply(200,{
     mode:'local-approved-airport-snapshot',snapshotDate:data.snapshotDate,
     worlds:data.worlds,countries:countryCounts(data.airports),airportsTotal:data.airports.length,
     airlines:[],gameplayAvailable:false,readOnly:true
   });
 }
 const {countryIso,search='',offset=0}=body;
 if(Object.keys(body).some(k=>!['countryIso','search','offset'].includes(k))||
   typeof countryIso!=='string'||!/^[A-Z]{2}$/u.test(countryIso)||
   typeof search!=='string'||!searchRe.test(search)||
   !Number.isInteger(offset)||offset<0||offset>3100)
   return reply(400,{error:'Invalid airport filter'});
 const term=search.trim().toLocaleLowerCase('und');
 const rows=data.airports.filter(row=>row.country_iso===countryIso &&
   (!term||[row.airport_name,row.airport_code,row.municipality]
     .some(v=>typeof v==='string'&&v.toLocaleLowerCase('und').includes(term))))
   .sort((a,b)=>a.airport_name.localeCompare(b.airport_name)||a.airport_key.localeCompare(b.airport_key));
 const page=rows.slice(offset,offset+50).map(row=>({
   key:row.airport_key,name:row.airport_name,code:row.airport_code||'',
   countryIso:row.country_iso,municipality:row.municipality||''
 }));
 return reply(200,{
   mode:'local-approved-airport-snapshot',countryIso,airports:page,
   nextOffset:offset+50<rows.length?offset+50:null,readOnly:true
 });
}
