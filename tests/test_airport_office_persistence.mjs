import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createAirportOfficePersistence,AirportOfficeError} from '../server/airport-office-persistence.mjs';

const OWNER='11111111-1111-4111-8111-111111111111';
const STRANGER='22222222-2222-4222-8222-222222222222';
const AIRLINE='33333333-3333-4333-8333-333333333333';
const HOME='OURAIRPORTS:4343',SARAJEVO='OURAIRPORTS:4344';
function fixture(){
 const records=[];const calls=[];let commits=0,rollbacks=0;
 const database={async connect(){return {
  async query(sql,params=[]){
   calls.push({sql,params});
   if(sql==='BEGIN')return {rows:[]};
   if(sql==='COMMIT'){commits++;return {rows:[]};}
   if(sql==='ROLLBACK'){rollbacks++;return {rows:[]};}
   if(sql.includes('from airlinerra_game.airlines where owner_player_id=')){
    return {rows:params[0]===OWNER&&params[1]===1?[{id:AIRLINE,world_id:1,home_airport_key:HOME}]:[]};
   }
   if(sql.includes('from airlinerra_game.approved_game_airports where')){
    return {rows:params[0]===1&&[HOME,SARAJEVO].includes(params[1])?
     [{world_id:1,airport_key:params[1]}]:[]};
   }
   if(sql.startsWith('select airport_key,office_type,office_status')){
    return {rows:records.map(x=>({airport_key:x.airport_key,office_type:x.office_type,office_status:x.office_status}))};
   }
   if(sql.startsWith('insert into airlinerra_game.airport_offices')){
    const row={airport_key:params[2],office_type:params[3],office_status:'draft'};
    records.push(row);return {rows:[row]};
   }
   if(sql.startsWith('select o.airport_key')){
    return {rows:params[0]===OWNER&&params[1]===1?records.map(x=>({
     ...x,airport_name:'Sarajevo International Airport',airport_code:'LQSA',
     country_iso:'BA',municipality:'Sarajevo'
    })):[]};
   }
   if(sql.startsWith('delete from airlinerra_game.airport_offices')){
    if(params[0]!==OWNER||params[1]!==1)return {rows:[]};
    const index=records.findIndex(x=>x.airport_key===params[2]&&x.office_status==='draft');
    return {rows:index<0?[]:[records.splice(index,1)[0]]};
   }
   throw Error('Unexpected SQL statement.');
  },
  release(){}
 };}};
 const verifyUserToken=async token=>({user:{
  id:token.startsWith('owner')?OWNER:STRANGER,
  email_confirmed_at:'2026-10-29T00:00:00Z',is_anonymous:false
 }});
 const service=createAirportOfficePersistence({verifyUserToken,database,enabled:true});
 return {service,records,calls,stats:()=>({commits,rollbacks})};
}
const own='owner-valid-token-123456789',other='other-valid-token-123456789';
const draft={accessToken:own,worldId:1,airportKey:SARAJEVO,type:'station'};
test('private drafts are persisted, owner-scoped, idempotent, and removable',async()=>{
 const f=fixture();
 const created=await f.service.save(draft);
 assert.deepEqual(created,{key:SARAJEVO,type:'station',status:'draft',newlyCreated:true});
 const again=await f.service.save(draft);
 assert.equal(again.newlyCreated,false);
 assert.equal(f.records.length,1);
 const listed=await f.service.list({accessToken:own,worldId:1});
 assert.equal(listed.length,1);
 assert.equal(listed[0].name,'Sarajevo International Airport');
 assert.deepEqual(await f.service.list({accessToken:other,worldId:1}),[]);
 assert.deepEqual(await f.service.remove({accessToken:other,worldId:1,airportKey:SARAJEVO}),{removed:false});
 assert.equal(f.records.length,1);
 assert.deepEqual(await f.service.remove({accessToken:own,worldId:1,airportKey:SARAJEVO}),{removed:true});
 assert.equal(f.records.length,0);
 assert.equal(f.stats().rollbacks,0);
});
test('reject cross-world, headquarters, unapproved, duplicate type and missing airline',async()=>{
 const f=fixture();
 for(const request of [
  {...draft,worldId:2},{...draft,airportKey:HOME},
  {...draft,airportKey:'OURAIRPORTS:999999'}, {...draft,worldId:4},
  {...draft,accessToken:other}
 ]){
  await assert.rejects(f.service.save(request),error=>error instanceof Error);
 }
 assert.equal(f.records.length,0);
 await f.service.save({...draft,type:'hub'});
 await assert.rejects(f.service.save(draft),e=>e instanceof AirportOfficeError&&e.code==='OFFICE_CONFLICT');
 assert.equal(f.records.length,1);
 assert.ok(f.stats().rollbacks>=4);
});
test('strict auth, disabled by default and no active office mutations',async()=>{
 const f=fixture();
 await assert.rejects(f.service.save({...draft,accessToken:'bad'}));
 assert.equal(f.calls.length,0);
 const disabled=createAirportOfficePersistence({
  verifyUserToken:async()=>({user:{id:OWNER}}),database:{connect:async()=>{throw Error('Should not connect');}}
 });
 await assert.rejects(disabled.save(draft),e=>e.code==='DISABLED');
 f.records.push({airport_key:SARAJEVO,office_type:'station',office_status:'active'});
 assert.deepEqual(await f.service.remove({accessToken:own,worldId:1,airportKey:SARAJEVO}),{removed:false});
});
test('migration keeps private schema, world foreign keys and draft-only state',async()=>{
 const sql=await readFile(new URL('../supabase/migrations/20261029154000_airlinerra_airport_office_drafts.sql',import.meta.url),'utf8');
 assert.match(sql,/FOREIGN KEY \(world_id,airline_id\)/);
 assert.match(sql,/FOREIGN KEY \(world_id,airport_key\)/);
 assert.match(sql,/office_status = 'draft'/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/FROM PUBLIC, anon, authenticated/);
 assert.match(sql,/validate_additional_airport_office/);
 assert.doesNotMatch(sql,/GRANT .*TO authenticated/i);
});
