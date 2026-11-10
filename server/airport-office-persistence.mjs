/** Private persistence for ADDITIONAL airport office drafts, not active locations.
 * This is not a public route, client module, fee service or deployed endpoint.
 * A trusted caller must supply the Auth getUser() verifier and private pg pool.
 */
import {verifiedPlayerId} from './airline-activation.mjs';
import {validateAirportOfficeProposal} from './airport-office-domain.mjs';

export const AIRPORT_OFFICE_SQL=Object.freeze({
 airline:'select id,world_id,home_airport_key from airlinerra_game.airlines where owner_player_id=$1::uuid and world_id=$2::smallint for update',
 approved:'select world_id,airport_key from airlinerra_game.approved_game_airports where world_id=$1::smallint and airport_key=$2::text',
 existing:'select airport_key,office_type,office_status from airlinerra_game.airport_offices where airline_id=$1::uuid for update',
 insert:"insert into airlinerra_game.airport_offices (world_id,airline_id,airport_key,office_type) values ($1::smallint,$2::uuid,$3::text,$4::text) returning airport_key,office_type,office_status",
 list:"select o.airport_key,o.office_type,o.office_status,p.airport_name,p.airport_code,p.country_iso,p.municipality from airlinerra_game.airport_offices o join airlinerra_game.airlines a on a.id=o.airline_id and a.world_id=o.world_id join airlinerra_game.approved_game_airports p on p.world_id=o.world_id and p.airport_key=o.airport_key where a.owner_player_id=$1::uuid and a.world_id=$2::smallint order by o.created_at,o.id limit 21",
 remove:"delete from airlinerra_game.airport_offices o using airlinerra_game.airlines a where o.airline_id=a.id and o.world_id=a.world_id and a.owner_player_id=$1::uuid and a.world_id=$2::smallint and o.airport_key=$3::text and o.office_status='draft' returning o.airport_key"
});
const VALID_KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/;
export class AirportOfficeError extends Error {
 constructor(code,message){super(message);this.name='AirportOfficeError';this.code=code;}
}
const failure=(code,message)=>{throw new AirportOfficeError(code,message);};
function validateWorld(worldId){
 if(!Number.isSafeInteger(worldId)||worldId<1||worldId>3)failure('INVALID_WORLD','Invalid game world.');
 return worldId;
}
function validateKey(key){
 if(typeof key!=='string'||!VALID_KEY.test(key))failure('INVALID_AIRPORT','Invalid approved airport key.');
 return key;
}
function validateType(type){
 if(!['hub','station'].includes(type))failure('INVALID_TYPE','Unknown office type.');
 return type;
}
function rows(result){
 if(!Array.isArray(result?.rows))throw Error('Invalid database result.');
 return result.rows;
}
function validateToken(accessToken){
 if(typeof accessToken!=='string'||accessToken.length<16)
  failure('UNAUTHENTICATED','Verified player authentication is required.');
 return accessToken;
}
/** Only the verified owner, not a client-supplied airlineId, may access rows. */
export function createAirportOfficePersistence({verifyUserToken,database,enabled=false}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
  throw Error('Trusted authentication and private PostgreSQL pool required.');
 async function owner(accessToken){
  return verifiedPlayerId(await verifyUserToken(validateToken(accessToken)));
 }
 async function transact(action){
  const client=await database.connect();
  let started=false;
  try{
   await client.query('BEGIN');started=true;
   const value=await action(client);
   await client.query('COMMIT');started=false;
   return value;
  }catch(error){
   if(started)try{await client.query('ROLLBACK');}catch{/* original error is authoritative */}
   throw error;
  }finally{client.release();}
 }
 function requireEnabled(){
  if(!enabled)failure('DISABLED','Airport office persistence is not enabled.');
 }
 async function list({accessToken,worldId}={}){
  requireEnabled();
  const id=await owner(accessToken),world=validateWorld(worldId);
  const client=await database.connect();
  try{
   const result=rows(await client.query(AIRPORT_OFFICE_SQL.list,[id,world]));
   if(result.length>20)throw Error('Office draft bound exceeded.');
   return Object.freeze(result.map(r=>Object.freeze({
    key:r.airport_key,type:r.office_type,status:r.office_status,
    name:r.airport_name,code:r.airport_code||'',countryIso:r.country_iso||null,
    municipality:r.municipality||''
   })));
  }finally{client.release();}
 }
 async function save({accessToken,worldId,airportKey,type}={}){
  requireEnabled();
  const id=await owner(accessToken),world=validateWorld(worldId);
  const key=validateKey(airportKey),kind=validateType(type);
  return transact(async client=>{
   // Serialize saves per owned airline. Never trust an airline ID in request data.
   const airline=rows(await client.query(AIRPORT_OFFICE_SQL.airline,[id,world]))[0];
   if(!airline)failure('AIRLINE_NOT_FOUND','An airline in this world is required.');
   const approved=rows(await client.query(AIRPORT_OFFICE_SQL.approved,[world,key]))[0];
   const existing=rows(await client.query(AIRPORT_OFFICE_SQL.existing,[airline.id]));
   const validation=validateAirportOfficeProposal({
    type:kind,airportKey:key,worldId:world,homeAirportKey:airline.home_airport_key,
    approvedAirportWorldId:approved?.world_id,
    existingAirportKeys:[]
   });
   if(!validation.ok)failure('INVALID_OFFICE',validation.reason);
   const previous=existing.find(x=>x.airport_key===key);
   if(previous){
    if(previous.office_type!==kind)failure('OFFICE_CONFLICT','An office of another type already exists here.');
    return Object.freeze({key,type:kind,status:previous.office_status,newlyCreated:false});
   }
   if(existing.length>=20)failure('OFFICE_LIMIT','Maximum 20 proposed airport offices per airline.');
   const record=rows(await client.query(AIRPORT_OFFICE_SQL.insert,[world,airline.id,key,kind]))[0];
   if(!record||record.airport_key!==key||record.office_type!==kind||record.office_status!=='draft')
    throw Error('Invalid airport office insertion.');
   return Object.freeze({key,type:kind,status:'draft',newlyCreated:true});
  });
 }
 async function remove({accessToken,worldId,airportKey}={}){
  requireEnabled();
  const id=await owner(accessToken),world=validateWorld(worldId),key=validateKey(airportKey);
  const client=await database.connect();
  try{
   const result=rows(await client.query(AIRPORT_OFFICE_SQL.remove,[id,world,key]));
   return Object.freeze({removed:result.length===1});
  }finally{client.release();}
 }
 return Object.freeze({list,save,remove});
}
