import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 createPlayerDraftsHandler,validatePlayerDraftRequest,validPlayerDraftDocument,
 PLAYER_DRAFT_SQL,PLAYER_DRAFTS_ROUTE
} from '../server/player-drafts-service.mjs';
import {createPlayerDraftsClient} from '../website/player-drafts-client.mjs';
import {createPlayerDraftStore} from '../website/player-draft-store.mjs';
import {allowedLocalOwnerRead,createLiveReadOnlyPreviewHandler}
 from '../website/dev-scripts/real-player-read-gateway.mjs';
const ownerId='11111111-1111-4111-8111-111111111111';
const airlineId='22222222-2222-4222-8222-222222222222';
const token='r'.repeat(48);
const request=(body,origin='https://airlinerra.com')=>new Request(
 'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-player-workspace-drafts',{
 method:'POST',headers:{origin,'x-airlinerra-route':PLAYER_DRAFTS_ROUTE,
  authorization:'Bearer '+token,'content-type':'application/json'},
 body:JSON.stringify(body)
});
const body=(kind='workplan')=>({action:'save',airlineId,kind,
 state:{ticketPrice:{cabin:'economy',price:45},staff:[]},expectedVersion:0});
test('owner workspace requests are size limited and never accept operational commands',()=>{
 assert.equal(validatePlayerDraftRequest(body()),true);
 assert.equal(validatePlayerDraftRequest({action:'read',airlineId,kind:'workplan'}),true);
 for(const bad of [
  {...body(),action:'activate'},
  {...body(),action:'save',ledgerPosted:true},
  {...body(),state:{cashUsd:999999999}},
  {...body(),state:{flightMovements:[]}},
  {...body(),state:{staff:null}},
  {...body(),expectedVersion:-1},
  {...body(),kind:'admin'},
  {...body(),state:{routes:Array(26).fill({})}},
  {...body(),state:{airportOffices:Array(21).fill({})}}
 ])assert.equal(validatePlayerDraftRequest(bad),false);
 assert.equal(validPlayerDraftDocument('preferences',{theme:'dark',hints:true}),true);
 assert.equal(validPlayerDraftDocument('preferences',{password:'secret'}),false);
 assert.equal(validPlayerDraftDocument('preferences',{hints:'false'}),false);
 assert.match(PLAYER_DRAFT_SQL.owner,/owner_player_id=\$2::uuid/);
 assert.match(PLAYER_DRAFT_SQL.save,/WHERE d.version=\$5::integer/);
 assert.doesNotMatch(JSON.stringify(PLAYER_DRAFT_SQL),
  /ledger|booked_passengers|flight_movements|certifications|SET cash/i);
});
test('real owner can save inert workplan, independent foreign airline is refused',async()=>{
 const queries=[],results=[
  {rowCount:1,rows:[{id:airlineId}]},
  {rowCount:1,rows:[{state:body().state,version:1,updatedAt:null}]}
 ];
 const handler=createPlayerDraftsHandler({
  verifyUserToken:async()=>({user:{id:ownerId}}),
  database:{connect:async()=>({query:async(sql,args)=>{
   queries.push({sql,args});return results.shift();
  },release(){}})}
 });
 const response=await handler(request(body()));
 assert.equal(response.status,200);
 const saved=await response.json();
 assert.equal(saved.source,'supabase');
 assert.equal(saved.operational,false);
 assert.equal(saved.ledgerPosted,false);
 assert.equal(saved.flightsChanged,false);
 assert.equal(saved.officesActivated,false);
 assert.equal(queries.length,2);
 assert.equal(queries[1].sql,PLAYER_DRAFT_SQL.save);
 assert.deepEqual(queries[1].args.slice(0,3),[airlineId,ownerId,'workplan']);
 const unauthorized=createPlayerDraftsHandler({
  verifyUserToken:async()=>({user:{id:ownerId}}),
  database:{connect:async()=>({query:async sql=>{
   assert.equal(sql,PLAYER_DRAFT_SQL.owner);
   return {rowCount:0,rows:[]}
  },release(){}})}
 });
 assert.equal((await unauthorized(request(body()))).status,403);
 assert.equal((await handler(request(body(),'http://localhost:5188'))).status,403);
});
test('stale workspace versions fail closed without overwriting the newer database state',async()=>{
 const handler=createPlayerDraftsHandler({
  verifyUserToken:async()=>({user:{id:ownerId}}),
  database:{connect:async()=>({query:async sql=>{
   if(sql===PLAYER_DRAFT_SQL.owner)return {rowCount:1,rows:[{}]};
   if(sql===PLAYER_DRAFT_SQL.save)return {rowCount:0,rows:[]};
   throw Error('Unexpected SQL')
  },release(){}})}
 });
 const response=await handler(request(body()));
 assert.equal(response.status,409);
 assert.equal((await response.json()).error,'WORKSPACE_VERSION_CONFLICT');
});
test('localhost proxy forwards only owner-validated workspace drafts to the pinned service',async()=>{
 const calls=[],proxy=createLiveReadOnlyPreviewHandler({fetchImpl:async(url,options)=>{
  calls.push({url,options});
  return Response.json({kind:'workplan',state:body().state,version:1,
   source:'supabase',operational:false});
 }});
 const path=PLAYER_DRAFTS_ROUTE;
 const call=payload=>new Request('http://localhost:5188'+path,{
  method:'POST',headers:{origin:'http://localhost:5188',
   authorization:'Bearer '+token,'content-type':'application/json'},
  body:JSON.stringify(payload)
 });
 assert.equal(allowedLocalOwnerRead(path,body()),true);
 const response=await proxy(call(body()));
 assert.equal(response.status,200);
 assert.equal(calls.length,1);
 assert.equal(calls[0].url,
  'https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-player-workspace-drafts');
 assert.equal(calls[0].options.headers['x-airlinerra-route'],path);
 assert.equal((await proxy(call({...body(),state:{ledgerPosted:true}}))).status,403);
 assert.equal(calls.length,1);
});
test('browser client uses only trusted same-origin authenticated Supabase proxy',async()=>{
 const called=[],client=createPlayerDraftsClient({
  origin:'http://localhost:5188',auth:{getAccessToken:async()=>token},
  fetchImpl:async(url,options)=>{
   called.push({url,options});
   return Response.json({kind:'workplan',state:{},version:0,
    source:'supabase',operational:false});
  }
 });
 const response=await client.read({airlineId,kind:'workplan'});
 assert.equal(response.version,0);
 assert.equal(called[0].url,'http://localhost:5188'+PLAYER_DRAFTS_ROUTE);
 assert.equal(called[0].options.headers.authorization,'Bearer '+token);
 assert.equal(called[0].options.credentials,'omit');
 assert.throws(()=>createPlayerDraftsClient({
  origin:'http://evil.example',auth:{getAccessToken:async()=>token}
 }),/Verified Airlinerra owner drafts client required/);
});
test('legacy workplans and preferences migrate only to empty owner record, with ZERO browser writes',async()=>{
 const remote=new Map(),calls=[];
 const client={
  read:async({kind})=>{
   const found=remote.get(kind);return {kind,source:'supabase',operational:false,
    state:found?.state||{},version:found?.version||0}
  },
  save:async({kind,state,expectedVersion})=>{
   const previous=remote.get(kind);
   assert.equal(previous?.version||0,expectedVersion);
   const version=expectedVersion+1;
   remote.set(kind,{state,version});
   calls.push({kind,state,version});
   return {kind,source:'supabase',operational:false,state,version}
  }
 };
 const writes=[];
 const session={getItem:()=>JSON.stringify({budget:{fuel:4000},
  routes:[{flightNumber:'PA400',schedule:[{day:0,time:'06:00'}]}],
  airportOffices:[]}),setItem:()=>{writes.push('session')}};
 const local={getItem:()=>JSON.stringify({theme:'dark',hints:false}),
  setItem:()=>{writes.push('local')}};
 const store=createPlayerDraftStore({
  client,session,storage:local,identity:ownerId});
 assert.equal(await store.load(airlineId),true);
 assert.equal(store.snapshot('preferences').theme,'dark');
 assert.equal(store.snapshot('workplan').budget.fuel,4000);
 assert.equal(calls.length,2);
 await store.update('workplan',{ticketPrice:{price:78}});
 assert.equal(store.snapshot('workplan').budget.fuel,4000);
 assert.equal(store.snapshot('workplan').ticketPrice.price,78);
 assert.deepEqual(writes,[]);
 assert.equal(remote.get('workplan').version,2);
});
test('existing authoritative data is never overwritten by stale browser drafts',async()=>{
 const client={
  read:async({kind})=>({kind,source:'supabase',operational:false,
   version:1,state:kind==='workplan'?{staff:[{count:3,salary:1000}]}:{theme:'light'}}),
  save:async()=>{throw Error('Must not overwrite preexisting state')}
 };
 const store=createPlayerDraftStore({
  client,identity:ownerId,session:{getItem:()=>JSON.stringify({staff:[{count:99,salary:99999}]})},
  storage:{getItem:()=>JSON.stringify({theme:'dark'})}
 });
 assert.equal(await store.load(airlineId),false);
 assert.equal(store.snapshot('workplan').staff[0].count,3);
 assert.equal(store.snapshot('preferences').theme,'light');
 assert.equal(store.pendingMigration('workplan'),true);
});
test('main game screens contain no new browser-only persistence',async()=>{
 const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
 const [routes,workspace,operations,offices,cabin,app,build,sql]=await Promise.all([
  read('website/route-planner.mjs'),read('website/airline-workspace.mjs'),
  read('website/airline-operations-center.mjs'),read('website/airline-airports-office.mjs'),
  read('website/cabin-services-manager.mjs'),read('website/player-app.mjs'),
  read('website/dev-scripts/invited-overlay.mjs'),
  read('supabase/migrations/20261112114500_owner_scoped_player_drafts_database_only_v1.sql')
 ]);
 for(const [name,source] of [['routes',routes],['workspace',workspace],['operations',operations],
  ['offices',offices],['cabin',cabin]])
  assert.doesNotMatch(source,/\b(?:localStorage|sessionStorage)\s*\.\s*setItem\s*\(|(?:storage|session|store)\?*\s*\.\s*setItem\s*\(/,
   name+' must not save game state in browser storage');
 assert.match(routes,/Browser-only game routes are disabled/);
 assert.match(workspace,/playerDraftStore\.update|database\.update/);
 assert.match(operations,/playerStore\.update/);
 assert.match(offices,/live\.playerDraftStore\.update/);
 assert.match(cabin,/No browser-only writes/);
 assert.match(app,/createPlayerDraftStore/);
 assert.match(build,/'player-draft-store\.mjs'/);
 assert.match(sql,/ENABLE ROW LEVEL SECURITY/);
 assert.match(sql,/REVOKE ALL.*PUBLIC,anon,authenticated/);
});
