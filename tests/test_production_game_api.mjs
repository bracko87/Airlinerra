import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createProductionGameApi,validProductionDatabaseUrl} from '../server/production-game-api.mjs';
import {CANONICAL_GAME_API_PATHS} from '../server/canonical-game-api.mjs';
import {PLAYER_READ_SQL} from '../server/player-read-service.mjs';
import {REGISTRATION_READINESS_SQL} from '../server/registration-readiness.mjs';

const REF='hwllkabgzaynalahvkpz';
const origin='https://airlinerra.com';
const url='postgresql://postgres.'+REF+':password@aws-0-eu-central-1.pooler.supabase.com:5432/postgres';
const apikey='sb_publishable_'+('Z'.repeat(32));
const token='a'.repeat(32);
const uid='550e8400-e29b-41d4-a716-446655440000';
test('production API requires pinned real database, explicit enabling and canonical origin',async()=>{
 assert.equal(validProductionDatabaseUrl(url),true);
 assert.equal(validProductionDatabaseUrl(url+'?sslmode=require'),true);
 assert.equal(validProductionDatabaseUrl(url+'?sslmode=disable'),false);
 for(const rejected of [
  '',null,'postgresql://postgres:password@db.other.supabase.co:5432/postgres',
  'postgresql://postgres.other:password@aws-0-eu-central-1.pooler.supabase.com:5432/postgres',
  'postgresql://postgres.'+REF+':password@evil.example:5432/postgres'
 ])assert.equal(validProductionDatabaseUrl(rejected),false);
 let loaded=0;
 const app=createProductionGameApi({
  env:{AIRLINERRA_PRODUCTION_API_ENABLED:'false',AIRLINERRA_DATABASE_URL:url},
  loadPg:async()=>{loaded++;throw Error('Must not load');}
 });
 assert.equal((await app(new Request(origin+'/api/v1/registration/readiness'))).status,503);
 assert.equal(loaded,0);
 assert.equal((await app(new Request('https://attacker.example/api/v1/registration/readiness'))).status,403);
});
test('production API validates hosted identity and uses exact owner-scoped SQL',async()=>{
 const queries=[];
 let constructed=0;
 class Pool{
  constructor(options){constructed++;assert.equal(options.max,2);assert.equal(options.ssl.rejectUnauthorized,true)}
  async connect(){return {query:async(sql,params)=>{
   queries.push([sql,params]);
   if(sql===REGISTRATION_READINESS_SQL)return {rows:[{
    gate_on:false,legal_on:false,world_on:false,airports_on:true,owner_pilot_on:true
   }]};
   if(sql===PLAYER_READ_SQL.worlds)return {rows:[
    {id:1,name:'World 1',state:'planned'},
    {id:2,name:'World 2',state:'planned'},
    {id:3,name:'World 3',state:'planned'}
   ]};
   if(sql===PLAYER_READ_SQL.countries)return {rows:[{country_iso:'DE',airport_count:3140}]};
   if(sql===PLAYER_READ_SQL.airlines)return {rows:[]};
   throw Error('Unexpected SQL');
  },release:()=>{}}}
 }
 const app=createProductionGameApi({
  env:{AIRLINERRA_PRODUCTION_API_ENABLED:'true',AIRLINERRA_DATABASE_URL:url,
   AIRLINERRA_PUBLIC_SUPABASE_KEY:apikey},
  loadPg:async()=>({Pool}),
  fetchImpl:async(url,opts)=>{
    assert.equal(opts.headers.authorization,'Bearer '+token);
    return new Response(JSON.stringify({id:uid,email:'owner@example.test',
     email_confirmed_at:'2026-10-28T10:00:00Z'}),
     {status:200,headers:{'content-type':'application/json'}});
  }
 });
 const ready=await app(new Request(origin+'/api/v1/registration/readiness'));
 assert.equal(ready.status,200);
 const reply=await ready.json();
 assert.equal(reply.registrationReady,false);
 assert.equal(reply.privateOwnerPilotAvailable,true);
 const res=await app(new Request(origin+'/api/v1/player/overview',{
  method:'POST',headers:{origin,'content-type':'application/json',authorization:'Bearer '+token},
  body:'{}'
 }));
 assert.equal(res.status,200);
 assert.equal((await res.json()).airlines.length,0);
 assert.deepEqual(queries.find(q=>q[0]===PLAYER_READ_SQL.airlines)[1],[uid]);
 assert.equal(constructed,1);
});
test('manual Netlify release routes real endpoints without publishing private backend code',async()=>{
 const root=new URL('../',import.meta.url);
 const [toml,fn,build]=await Promise.all([
  readFile(new URL('netlify.toml',root),'utf8'),
  readFile(new URL('website/netlify/functions/airlinerra-game.mjs',root),'utf8'),
  readFile(new URL('website/dev-scripts/build.mjs',root),'utf8')
 ]);
 assert.match(toml,/directory = "netlify\/functions"/);
 assert.match(toml,/node_bundler = "esbuild"/);
 assert.match(fn,/createProductionGameApi/);
 assert.match(fn,/loadPg:\(\)=>import\('pg'\)/);
 for(const path of CANONICAL_GAME_API_PATHS)assert.ok(fn.includes(path),path);
 assert.doesNotMatch(build,/server\/production-game-api|AIRLINERRA_DATABASE_URL|service_role/);
});
