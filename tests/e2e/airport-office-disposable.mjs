/** Full API -> verified Auth -> private PostgreSQL integration, CI-local ONLY.
 * This file MUST only run on an isolated disposable PostgreSQL instance.
 */
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createCanonicalGameApi} from '../../server/canonical-game-api.mjs';
import {createProductionGameApi,EDGE_FUNCTION_URL} from '../../server/production-game-api.mjs';

const ORIGIN='http://localhost:5188';
const PATH='/api/v1/player/airport-offices';
const IDS=Object.freeze({
 owner1:'11111111-1111-4111-8111-111111111111',
 owner2:'22222222-2222-4222-8222-222222222222',
 airline1:'33333333-3333-4333-8333-333333333333',
 airline2:'44444444-4444-4444-8444-444444444444',
 airlineWorld2:'55555555-5555-4555-8555-555555555555'
});
const airports={belgrade:'OURAIRPORTS:4343',sarajevo:'OURAIRPORTS:4344',zagreb:'OURAIRPORTS:4345',novisad:'OURAIRPORTS:4346'};
const token1='owner1.private-test-token-123456789',token2='owner2.private-test-token-123456789';
if(process.env.PGHOST!=='127.0.0.1'||process.env.PGDATABASE!=='airlinerra_office_disposable'||
 process.env.PGPORT!=='5432'||process.env.GITHUB_ACTIONS!=='true')
 throw Error('Refusing to run office integration against anything except disposable GitHub Actions PostgreSQL');

const require=createRequire(new URL('../../website/package.json',import.meta.url));
const {Pool}=require('pg');
const pool=new Pool({host:'127.0.0.1',port:5432,
 database:'airlinerra_office_disposable',
 user:process.env.PGUSER,password:process.env.PGPASSWORD,
 max:4,connectionTimeoutMillis:3000,application_name:'airlinerra-office-disposable-test'});
const auth=async token=>({
 user:token===token1?{id:IDS.owner1,email_confirmed_at:'2026-10-29T00:00:00Z',is_anonymous:false}:
  token===token2?{id:IDS.owner2,email_confirmed_at:'2026-10-29T00:00:00Z',is_anonymous:false}:null
});
const game=createCanonicalGameApi({
 enabled:true,airportOfficeDraftsEnabled:true,
 origin:ORIGIN,verifyUserToken:auth,database:pool
});
// Simulate the real Netlify -> Supabase Edge request transport while retaining
// the same disposable PostgreSQL backing store and test-only verified identity.
const HOSTED_ORIGIN='https://airlinerra.com';
const edgeGame=createCanonicalGameApi({
 enabled:true,airportOfficeDraftsEnabled:true,
 origin:HOSTED_ORIGIN,verifyUserToken:auth,database:pool
});
const proxy=createProductionGameApi({airportOfficeDraftsEnabled:true,
 fetchImpl:async(url,upstream)=>{
  assert.equal(url,EDGE_FUNCTION_URL,'pinned project endpoint');
  assert.equal(upstream.headers.origin,HOSTED_ORIGIN,'Edge sees pinned origin');
  return edgeGame(new Request(HOSTED_ORIGIN+upstream.headers['x-airlinerra-route'],{
   method:upstream.method,
   headers:{
    origin:upstream.headers.origin,
    authorization:upstream.headers.authorization,
    'content-type':upstream.headers['content-type']
   },
   body:upstream.body
  }));
 }
});
async function proxyPost(token,data){
 const request=new Request(HOSTED_ORIGIN+PATH,{
  method:'POST',
  headers:{origin:HOSTED_ORIGIN,'content-type':'application/json',authorization:'Bearer '+token},
  body:JSON.stringify(data)
 });
 const response=await proxy(request);
 return {status:response.status,body:await response.json()};
}
const post=async(token,data,{origin=ORIGIN}={})=>{
 const response=await game(new Request(ORIGIN+PATH,{
  method:'POST',headers:{'content-type':'application/json',origin,
   authorization:'Bearer '+token},
  body:JSON.stringify(data)
 }));
 return {status:response.status,body:await response.json()};
};
const list=(token,worldId)=>post(token,{operation:'list',worldId});
const save=(token,worldId,airportKey,type)=>post(token,{operation:'save',worldId,airportKey,type});
const remove=(token,worldId,airportKey)=>post(token,{operation:'remove',worldId,airportKey});
async function seed(){
 await pool.query("UPDATE public.airlinerra_game_worlds SET state='registration_open' WHERE id IN (1,2)");
 for(const player of [IDS.owner1,IDS.owner2]){
  await pool.query('INSERT INTO auth.users(id,email_confirmed_at) VALUES ($1::uuid,now())',[player]);
 }
 for(const [world,player] of [[1,IDS.owner1],[1,IDS.owner2],[2,IDS.owner1]]){
  await pool.query("INSERT INTO airlinerra_game.world_memberships(world_id,player_id,state) VALUES ($1::smallint,$2::uuid,'active')",[world,player]);
 }
 for(const [world,key,name,code,country] of [
  [1,airports.belgrade,'Belgrade Nikola Tesla Airport','LYBE','RS'],
  [1,airports.sarajevo,'Sarajevo International Airport','LQSA','BA'],
  [1,airports.zagreb,'Zagreb Airport','LDZA','HR'],
  [1,airports.novisad,'Novi Sad Airport','LYNS','RS'],
  [2,airports.zagreb,'Zagreb Airport','LDZA','HR'],
  [2,airports.novisad,'Novi Sad Airport','LYNS','RS']]){
  await pool.query('INSERT INTO airlinerra_game.approved_game_airports(world_id,airport_key,approval_reference,airport_name,airport_code,country_iso) VALUES ($1::smallint,$2::text,$3::text,$4::text,$5::text,$6::text)',
  [world,key,'CI-ONLY-DO-NOT-PUBLISH',name,code,country]);
 }
 for(const [id,world,owner,name,home] of [
  [IDS.airline1,1,IDS.owner1,'Test Panonian',airports.belgrade],
  [IDS.airline2,1,IDS.owner2,'Test Second Air',airports.sarajevo],
  [IDS.airlineWorld2,2,IDS.owner1,'Test Atlas',airports.zagreb]]){
  await pool.query('INSERT INTO airlinerra_game.airlines(id,world_id,owner_player_id,name,home_airport_key,cash_usd) VALUES ($1::uuid,$2::smallint,$3::uuid,$4::text,$5::text,5000000.00)',
  [id,world,owner,name,home]);
 }
}
try{
 await seed();
 assert.equal((await list(token1,1)).body.offices.length,0);
 assert.equal((await save(token1,1,airports.belgrade,'hub')).status,409,'cannot add HQ');
 assert.equal((await save(token1,1,'OURAIRPORTS:777777','hub')).status,409,'unapproved airport');
 assert.equal((await save(token1,2,airports.sarajevo,'hub')).status,409,'cross-world airport');
 assert.equal((await save('invalid-token-with-length-1234',1,airports.sarajevo,'station')).status,401);
 assert.equal((await post(token1,{operation:'activate',worldId:1,airportKey:airports.sarajevo})).status,400);
 assert.equal((await post(token1,{operation:'list',worldId:1},{origin:'https://other.example'})).status,403);

 const created=await save(token1,1,airports.sarajevo,'station');
 assert.equal(created.status,201);
 assert.equal(created.body.office.newlyCreated,true);
 assert.equal((await save(token1,1,airports.sarajevo,'station')).status,200,'idempotent replay');
 assert.equal((await save(token1,1,airports.sarajevo,'hub')).status,409,'cannot replace role');
 const duo=await Promise.all([save(token1,1,airports.zagreb,'hub'),save(token1,1,airports.zagreb,'hub')]);
 assert.deepEqual(duo.map(r=>r.status).sort(),[200,201],'same-airline concurrent create serialized');

 const own=(await list(token1,1)).body.offices;
 assert.equal(own.length,2);
 assert.deepEqual(own.map(o=>o.key).sort(),[airports.sarajevo,airports.zagreb].sort());
 assert.equal((await list(token2,1)).body.offices.length,0,'second user must not see first user offices');
 assert.equal((await remove(token2,1,airports.sarajevo)).body.removed,false,'second user cannot delete owner office');
 assert.equal((await list(token1,2)).body.offices.length,0,'world isolation');

 assert.equal((await save(token2,1,airports.belgrade,'hub')).status,201,'same airport allowed to a different airline');
 assert.equal((await save(token1,2,airports.novisad,'station')).status,201,'world 2 authorized independently');
 assert.equal((await list(token1,2)).body.offices.length,1);
 assert.equal((await list(token1,1)).body.offices.length,2);

 const privilege=await pool.query("select not has_table_privilege('authenticated','airlinerra_game.airport_offices','select') and not has_table_privilege('anon','airlinerra_game.airport_offices','select') as protected");
 assert.equal(privilege.rows[0].protected,true);
 await assert.rejects(
  pool.query("UPDATE airlinerra_game.airport_offices SET office_status='active' WHERE airline_id=$1",[IDS.airline1]),
  e=>e.code==='23514','cannot activate any office even with elevated test DB role'
 );
 await assert.rejects(
  pool.query("INSERT INTO airlinerra_game.airport_offices(world_id,airline_id,airport_key,office_type) VALUES (2,$1,$2,'hub')",[IDS.airline1,airports.novisad]),
  e=>e.code==='23503','cannot mix world and airline'
 );
 await assert.rejects(
  pool.query("INSERT INTO airlinerra_game.airport_offices(world_id,airline_id,airport_key,office_type) VALUES (1,$1,$2,'hub')",[IDS.airline1,airports.belgrade]),
  e=>e.code==='23514','HQ database trigger'
 );

 assert.equal((await remove(token1,1,airports.sarajevo)).body.removed,true);
 assert.equal((await remove(token1,1,airports.sarajevo)).body.removed,false,'repeat delete is safe');
 assert.equal((await list(token1,1)).body.offices.length,1);
 // The complete Netlify -> Edge canonical API -> private PostgreSQL chain,
 // using in-process Edge emulation and no actual external network traffic.
 const viaProxy=await proxyPost(token1,{
  operation:'save',worldId:1,airportKey:airports.sarajevo,type:'station'
 });
 assert.equal(viaProxy.status,201,'real proxy chain accepts valid save');
 assert.equal(viaProxy.body.office.status,'draft');
 assert.equal((await proxyPost(token2,{operation:'list',worldId:1})).body.offices.length,1,
  'second owner sees only their own office through Netlify');
 assert.equal((await proxyPost(token1,{operation:'list',worldId:1})).body.offices.length,2,
  'same owner sees two drafts via proxy');
 assert.equal((await proxyPost(token1,{
  operation:'remove',worldId:1,airportKey:airports.sarajevo
 })).body.removed,true,'proxied delete is owner-scoped');
 const money=await pool.query('select id,cash_usd::text from airlinerra_game.airlines order by id');
 assert.equal(money.rows.length,3);
 assert.ok(money.rows.every(row=>Number(row.cash_usd)===5000000),'no money charged');
 assert.equal(Number((await pool.query('select count(*) as n from airlinerra_game.airline_ledger')).rows[0].n),0,'no ledger entries');
 assert.equal(Number((await pool.query("select count(*) as n from airlinerra_game.airport_offices where office_status <> 'draft'")).rows[0].n),0,'never active');
 console.log('PASS: CI-local Netlify -> in-process Edge -> Auth verifier -> PostgreSQL owner/world isolation, concurrency, no charges');
} finally {
 await pool.end();
}
