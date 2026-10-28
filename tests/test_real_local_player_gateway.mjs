import test from 'node:test';
import assert from 'node:assert/strict';
import {makeRealLocalPlayerHandler,validConnectionUrl} from '../website/dev-scripts/real-player-read-gateway.mjs';
import {PLAYER_READ_SQL} from '../server/player-read-service.mjs';
import {createRegistrationReadinessHandler,REGISTRATION_READINESS_SQL} from '../server/registration-readiness.mjs';

const REF='hwllkabgzaynalahvkpz';
const connection='postgresql://postgres.'+REF+':fake-password@aws-0-eu-central-1.pooler.supabase.com:5432/postgres';
const id='550e8400-e29b-41d4-a716-446655440000';
const token='a'.repeat(32);
const base='http://localhost:5188';
const request=(body={},url='/api/v1/player/overview',auth=token,origin=base)=>
 new Request(base+url,{method:'POST',headers:{
  origin,'content-type':'application/json',authorization:'Bearer '+auth
 },body:JSON.stringify(body)});

test('local player gateway rejects absent or unrelated database credentials',async()=>{
 assert.equal(validConnectionUrl(connection),true);
 for(const candidate of ['','postgresql://postgres:password@evil.com/postgres',
 'postgresql://postgres.other:password@aws-0-eu-central-1.pooler.supabase.com:5432/postgres',
 'postgresql://postgres:password@db.other.supabase.co:5432/postgres',
 'postgresql://postgres.'+REF+'@aws-0-eu-central-1.pooler.supabase.com:5432/postgres'])
 assert.equal(validConnectionUrl(candidate),false,candidate);
 const handler=await makeRealLocalPlayerHandler({env:{},loadPg:async()=>{throw Error('PG must not load')}});
 assert.equal((await handler(request())).status,503);
});
test('live read adapter verifies hosted identity before using private PostgreSQL',async()=>{
 let connected=0,released=0,queries=[],poolOptions,authCalls=0;
 class Pool{
   constructor(options){poolOptions=options;}
   async connect(){
     connected++;
     return {
       query:async(sql,params)=>{
         queries.push([sql,params]);
         if(sql===PLAYER_READ_SQL.worlds)return {rows:[
          {id:1,name:'World 01',state:'planned'},
          {id:2,name:'World 02',state:'planned'},
          {id:3,name:'World 03',state:'planned'}
         ]};
         if(sql===PLAYER_READ_SQL.countries)return {rows:[{country_iso:'DE',airport_count:3140}]};
         if(sql===PLAYER_READ_SQL.airlines)return {rows:[]};
         throw Error('Unexpected SQL');
       },
       release:()=>{released++;}
     };
   }
 }
 const handler=await makeRealLocalPlayerHandler({
  env:{AIRLINERRA_LOCAL_DATABASE_URL:connection},
  loadPg:async()=>({Pool}),
  fetchImpl:async(url,options)=>{
   authCalls++;
   assert.equal(url,'https://'+REF+'.supabase.co/auth/v1/user');
   assert.equal(options.headers.authorization,'Bearer '+token);
   return new Response(JSON.stringify({id,email:'owner@example.com',
      email_confirmed_at:'2026-10-28T10:00:00Z'}),{
      status:200,headers:{'content-type':'application/json'}});
  }
 });
 assert.equal(poolOptions.max,2);
 assert.equal(poolOptions.ssl.rejectUnauthorized,true);
 const response=await handler(request());
 assert.equal(response.status,200);
 const data=await response.json();
 assert.equal(data.worlds.length,3);
 assert.equal(data.airportsTotal,3140);
 assert.deepEqual(data.airlines,[]);
 assert.equal(data.gameplayAvailable,false);
 assert.deepEqual(queries[2][1],[id]);
 assert.equal(authCalls,1);
 assert.equal(connected,1);
 assert.equal(released,1);
 assert.equal((await handler(request({},'/api/v1/player/overview',token,'http://evil.example'))).status,403);
 assert.equal(connected,1);
});
test('unverified hosted identity fails before database connection',async()=>{
 let connected=0;
 const handler=await makeRealLocalPlayerHandler({
  env:{AIRLINERRA_LOCAL_DATABASE_URL:connection},
  loadPg:async()=>({Pool:class {
   async connect(){connected++;throw Error('should not connect');}
  }}),
  fetchImpl:async()=>new Response('Unauthorized',{status:401})
 });
 assert.equal((await handler(request())).status,401);
 assert.equal(connected,0);
});

test('real signup preflight refuses until ALL four independent release conditions hold',async()=>{
 for(const which of ['gate_on','legal_on','world_on','airports_on']){
   let connections=0,releases=0;
   const all={gate_on:true,legal_on:true,world_on:true,airports_on:true};
   all[which]=false;
   const handler=createRegistrationReadinessHandler({database:{connect:async()=>{
     connections++;
     return {query:async sql=>{
       assert.equal(sql,REGISTRATION_READINESS_SQL);
       return {rows:[all]};
     },release:()=>{releases++;}};
   }}});
   const response=await handler(new Request(base+'/api/v1/registration/readiness'));
   assert.equal(response.status,200);
   const data=await response.json();
   assert.equal(data.registrationReady,false,which);
   assert.equal(data.flightsEnabled,false);
   assert.equal(connections,1);
   assert.equal(releases,1);
 }
});
test('release preflight reports ready only when the real database says so',async()=>{
 const handler=createRegistrationReadinessHandler({database:{
  connect:async()=>({query:async()=>({rows:[{
   gate_on:true,legal_on:true,world_on:true,airports_on:true
  }]}),release:()=>{}})
 }});
 const good=await handler(new Request(base+'/api/v1/registration/readiness'));
 assert.equal((await good.json()).registrationReady,true);
 assert.equal((await handler(new Request('http://attacker.test/api/v1/registration/readiness'))).status,403);
 assert.equal((await handler(new Request(base+'/api/v1/registration/readiness?debug=1'))).status,404);
 assert.equal((await handler(request({},'/api/v1/registration/readiness'))).status,405);
});
