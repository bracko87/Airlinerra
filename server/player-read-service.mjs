/**
 * Airlinerra Batch 2: server-side READ-ONLY player data provider.
 * Source only: no Netlify Function or browser-accessible database credentials.
 * A future credential-scoped runtime injects verifyUserToken and a private pg pool.
 */
import {verifiedPlayerId} from './airline-activation.mjs';
import {countrySqlExpression,GAME_COUNTRY_CODES,GAME_COUNTRY_SET} from './country-policy.mjs';
const PARENT_ISO=countrySqlExpression('country_iso');
const MEMBER_CODES=GAME_COUNTRY_CODES.map(code=>"'"+code+"'").join(',');

export const PLAYER_READ_PATHS=Object.freeze([
 '/api/v1/player/overview','/api/v1/player/airports'
]);
export const PLAYER_READ_SQL=Object.freeze({
 worlds:'select id,name,state from public.airlinerra_game_worlds order by id',
 countries:"select "+PARENT_ISO+" as country_iso,count(*)::integer as airport_count from airlinerra_game.approved_game_airports where world_id=1 and "+PARENT_ISO+" in ("+MEMBER_CODES+") group by "+PARENT_ISO+" order by "+PARENT_ISO,
 airlines:"select a.id,a.world_id,a.name,a.home_airport_key,a.cash_usd::text as cash_usd,a.created_at,a.icao_code,a.iata_code,h.airport_name as home_airport_name,h.airport_code as home_airport_code, (e.membership_state='active' and exists(select 1 from airlinerra_game.owner_premium_email_reservations r join auth.users u on r.email=lower(btrim(u.email)) where u.id=a.owner_player_id and u.email_confirmed_at is not null)) as complimentary_premium from airlinerra_game.airlines a left join airlinerra_game.account_entitlements e on e.player_id=a.owner_player_id left join airlinerra_game.approved_game_airports h on h.world_id=a.world_id and h.airport_key=a.home_airport_key where a.owner_player_id=$1::uuid order by a.world_id limit 3",
 ledger:"select entry_kind,amount_usd::text as amount_usd,recorded_at from airlinerra_game.airline_ledger where airline_id=$1::uuid order by recorded_at desc,id desc limit 5",
 airports:"select airport_key,airport_name,airport_code,"+PARENT_ISO+" as country_iso,municipality from airlinerra_game.approved_game_airports where world_id=1 and "+PARENT_ISO+"=$1::text and "+PARENT_ISO+" in ("+MEMBER_CODES+") and ($2::text='' or strpos(lower(coalesce(airport_name,'')),lower($2::text))>0 or strpos(lower(coalesce(airport_code,'')),lower($2::text))>0 or strpos(lower(coalesce(municipality,'')),lower($2::text))>0) order by airport_name nulls last,airport_key limit 51 offset $3::integer"
});
const ORIGIN='https://airlinerra.com';
const BEARER=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const GOOD_STATES=new Set(['planned','registration_open','active','closed']);
const SAFE_SEARCH=/^[\p{L}\p{N} .,'()\-]{0,40}$/u;
const headers={
 'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer',
 'content-security-policy':"default-src 'none'"
};
function respond(status,body){return new Response(JSON.stringify(body),{status,headers});}
function expectArray(x){if(!Array.isArray(x))throw Error('Invalid private data');return x;}
function airport(row){
 if(typeof row?.airport_key!=='string'||!(/^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{3,8})$/u.test(row.airport_key))||
   typeof row.airport_name!=='string'||!row.airport_name.trim()||
   typeof row.country_iso!=='string'||!/^[A-Z]{2}$/u.test(row.country_iso))throw Error('Invalid approved airport');
 return {key:row.airport_key,name:row.airport_name,code:String(row.airport_code||''),
   countryIso:row.country_iso,municipality:typeof row.municipality==='string'?row.municipality:''};
}
async function readBody(request){
 const n=request.headers.get('content-length');
 if(n!==null&&(!/^\d+$/u.test(n)||Number(n)>512))return null;
 if(!request.body)return null;
 const reader=request.body.getReader();
 let bytes=0;
 const chunks=[];
 try{
   while(true){
     const {done,value}=await reader.read();
     if(done)break;
     bytes+=value.byteLength;
     if(bytes>512){await reader.cancel().catch(()=>{});return null;}
     chunks.push(value);
   }
 }finally{reader.releaseLock();}
 const buffer=new Uint8Array(bytes);
 let offset=0;
 for(const chunk of chunks){buffer.set(chunk,offset);offset+=chunk.length;}
 let raw;
 try{raw=new TextDecoder('utf-8',{fatal:true}).decode(buffer);}
 catch{return null;}
 try{const v=JSON.parse(raw);return v && typeof v==='object'&&!Array.isArray(v)?v:null;}
 catch{return null;}
}
export function createPlayerReadHandler({enabled=false,verifyUserToken,database,origin=ORIGIN}={}){
 if(!enabled)return async()=>respond(503,{error:'Player data service is not available.'});
 if(![ORIGIN,'http://localhost:5188'].includes(origin)||typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
   throw Error('Private player backend configuration required');
 return async(request)=>{
   if(!(request instanceof Request))return respond(400,{error:'Invalid request'});
   const url=new URL(request.url);
   if(url.origin!==origin||request.headers.get('origin')!==origin)return respond(403,{error:'Forbidden'});
   if(!PLAYER_READ_PATHS.includes(url.pathname)||url.search||url.hash)return respond(404,{error:'Not found'});
   if(request.method!=='POST')return respond(405,{error:'Method not allowed'});
   if(request.headers.get('content-type')!=='application/json')return respond(415,{error:'JSON only'});
   const token=BEARER.exec(request.headers.get('authorization')||'')?.[1];
   if(!token)return respond(401,{error:'Verified account required'});
   const data=await readBody(request);
   if(!data)return respond(400,{error:'Invalid request'});
   if(url.pathname===PLAYER_READ_PATHS[0]&&Object.keys(data).length!==0)return respond(400,{error:'Invalid request'});
   let country='',search='',offset=0;
   if(url.pathname===PLAYER_READ_PATHS[1]){
     country=data.countryIso;search=data.search??'';offset=data.offset??0;
     if(Object.keys(data).some(k=>!['countryIso','search','offset'].includes(k))||
       typeof country!=='string'||!GAME_COUNTRY_SET.has(country)||
       typeof search!=='string'||!SAFE_SEARCH.test(search)||
       !Number.isInteger(offset)||offset<0||offset>3100)return respond(400,{error:'Invalid airport search'});
   }
   let playerId;
   try{playerId=verifiedPlayerId(await verifyUserToken(token));}
   catch{return respond(401,{error:'Verified account required'});}
   let client;
   let phase='db-connect';
   try{
     client=await database.connect();
     if(url.pathname===PLAYER_READ_PATHS[0]){
       phase='world-directory';
       const worlds=expectArray((await client.query(PLAYER_READ_SQL.worlds)).rows).map(row=>{
         const id=Number(row.id);
         if(!Number.isInteger(id)||id<1||id>3||typeof row.name!=='string'||
           !GOOD_STATES.has(row.state))throw Error('Invalid world record');
         return {id,name:row.name,state:row.state};
       });
       if(worlds.length!==3||new Set(worlds.map(w=>w.id)).size!==3)throw Error('Incomplete worlds');
       phase='country-directory';
       const countries=expectArray((await client.query(PLAYER_READ_SQL.countries)).rows).map(row=>{
         const airportCount=Number(row.airport_count);
         if(!/^[A-Z]{2}$/u.test(row.country_iso||'')||!Number.isInteger(airportCount)||airportCount<1)
           throw Error('Invalid country record');
         return {countryIso:row.country_iso,airportCount};
       });
       if(countries.length>250||new Set(countries.map(c=>c.countryIso)).size!==countries.length)
         throw Error('Invalid country directory');
       phase='airline-directory';
       const airlines=expectArray((await client.query(PLAYER_READ_SQL.airlines,[playerId])).rows).map(row=>{
         if(typeof row.id!=='string'||!Number.isInteger(Number(row.world_id))||
           typeof row.name!=='string'||!/^\d+(\.\d+)?$/u.test(String(row.cash_usd)))
           throw Error('Invalid airline record');
         const airline={id:row.id,worldId:Number(row.world_id),name:row.name,
           homeAirportKey:row.home_airport_key,homeAirportName:typeof row.home_airport_name==='string'?row.home_airport_name:null,
           homeAirportCode:typeof row.home_airport_code==='string'?row.home_airport_code:null,
           icaoCode:typeof row.icao_code==='string'?row.icao_code:null,
           iataCode:typeof row.iata_code==='string'?row.iata_code:null,cashUsd:String(row.cash_usd)};
         if(row.complimentary_premium===true)airline.premiumUnlimited=true;
         return airline;
       });
       // The ledger query is strictly scoped to the already-verified owner's
       // airline. It contains real financial events only, not fake operating profit.
       let ledgerEntries=[];
       if(airlines.length>0){
         phase='owner-ledger';
         const rows=expectArray((await client.query(PLAYER_READ_SQL.ledger,[airlines[0].id])).rows);
         if(rows.length>5)throw Error('Invalid ledger page');
         ledgerEntries=rows.map(row=>{
           if(typeof row.entry_kind!=='string'||!/^[A-Z][A-Z0-9_]{0,40}$/.test(row.entry_kind)||
             !/^-?\d+(\.\d+)?$/.test(String(row.amount_usd)))
             throw Error('Invalid ledger event');
           const date=new Date(row.recorded_at);
           if(!Number.isFinite(date.getTime()))throw Error('Invalid ledger date');
           return {kind:row.entry_kind,amountUsd:String(row.amount_usd),recordedAt:date.toISOString()};
         });
       }
       return respond(200,{worlds,countries,airlines,ledgerEntries,
         airportsTotal:countries.reduce((n,c)=>n+c.airportCount,0),gameplayAvailable:false});
     }
     phase='airport-search';
     const rows=expectArray((await client.query(PLAYER_READ_SQL.airports,[country,search.trim(),offset])).rows);
     if(rows.length>51)throw Error('Invalid page size');
     const hasMore=rows.length>50;
     const airports=rows.slice(0,50).map(airport);
     if(airports.some(a=>a.countryIso!==country))throw Error('Cross-country airport data');
     return respond(200,{airports,nextOffset:hasMore?offset+50:null,countryIso:country});
   }catch(error){
     // Do not log SQL, tokens, user IDs, airline records or stack traces.
     // A fixed phase name and optional PostgreSQL SQLSTATE are sufficient
     // for debugging without leaking the authenticated user's information.
     const sqlstate=typeof error?.code==='string'&&/^[A-Z0-9]{5}$/.test(error.code)
       ?error.code:'NONE';
     console.error('Airlinerra player read failure',phase,'SQLSTATE',sqlstate);
     return respond(503,{error:'Player data service unavailable'});
   }finally{try{client?.release();}catch{/* no unsafe log */}}
 };
}
