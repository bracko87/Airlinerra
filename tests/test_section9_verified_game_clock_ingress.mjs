import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {
 createSection9VerifiedGameClockIngress,SECTION9_CLOCK_SQL
} from '../server/section9-verified-game-clock-ingress.mjs';

const SECRET='this-is-a-unique-test-only-engine-event-secret-32chars';
const EVENT='horizon-world1-step-00001';
const DAY='2000-01-01';
const signed=(overrides={})=>{
 const fields={worldId:1,gameDate:DAY,eventId:EVENT,...overrides};
 const content='airlinerra-game-engine-day-v1\n'+fields.worldId+'\n'+
  fields.gameDate+'\n'+fields.eventId;
 return {...fields,signature:createHmac('sha256',SECRET).update(content,'utf8')
  .digest('hex')};
};
function mockDb({response,throwSql=false}={}){
 let opened=0,released=0;const calls=[];
 const db={connect:async()=>{
  opened++;
  return {release(){released++},async query(sql,args){
   calls.push({sql,args});
   if(throwSql)throw Error('SECTION9_GAME_CLOCK_SOURCE_DB_UNAVAILABLE');
   const x=typeof response==='function'?response(sql,args):response;
   return {rowCount:1,rows:[{result:x}]};
  }};
 }};
 return {db,calls,counts:()=>({opened,released})};
}
const blocked={worldId:1,status:'blocked_world_not_open',
 clockAdvanced:false,forecastEnqueued:false,
 payrollPosted:false,bookingsCreated:false};
const accepted={worldId:1,status:'verified_tick_accepted',
 gameDate:DAY,engineEventId:EVENT,
 clockAdvanced:true,forecastEnqueued:false,forecastJobId:null,
 payrollPosted:false,bookingsCreated:false,replayed:false};
const replayed={worldId:1,status:'already_applied',
 gameDate:DAY,engineEventId:EVENT,clockAdvanced:false,
 forecastEnqueued:false,forecastJobId:null,payrollPosted:false,
 bookingsCreated:false,replayed:true};

test('Engine secret is mandatory and never accepted from player-supplied date alone',()=>{
 assert.throws(()=>createSection9VerifiedGameClockIngress({
  database:{connect:async()=>{}},gameEngineHmacSecret:'short'}),
  /SECTION9_ENGINE_CLOCK_SIGNING_SECRET_NOT_CONFIGURED/);
 assert.throws(()=>createSection9VerifiedGameClockIngress({
  database:{connect:async()=>{}}
 }),/SECTION9_ENGINE_CLOCK_SIGNING_SECRET_NOT_CONFIGURED/);
});

test('Invalid signatures and modified dates do not reach SQL',async()=>{
 const d=mockDb({response:accepted});
 const ingress=createSection9VerifiedGameClockIngress({
  database:d.db,gameEngineHmacSecret:SECRET});
 const correct=signed();
 for(const invalid of [
  {...correct,signature:'0'.repeat(64)},
  {...correct,gameDate:'2000-01-02'},
  {...correct,eventId:EVENT+'-forged'},
  {...correct,worldId:2},
  {...correct,signature:'test'},
  {...correct,gameDate:'2000-02-30'},
  {...correct,eventId:'short'},
  {...correct,gameDate:'2199-12-32'}
 ]){
  await assert.rejects(
   ingress.acceptEngineTick(invalid),
   /SECTION9_INVALID_SIGNED_GAME_DAY|SECTION9_UNTRUSTED_GAME_ENGINE_EVENT/);
 }
 assert.deepEqual(d.counts(),{opened:0,released:0});
});

test('Correct HMAC tick is passed to single private SQL transaction',async()=>{
 const d=mockDb({response:accepted});
 const ingress=createSection9VerifiedGameClockIngress({
  database:d.db,gameEngineHmacSecret:SECRET});
 const event=signed();
 const response=await ingress.acceptEngineTick(event);
 assert.deepEqual(response,accepted);
 assert.equal(d.calls.length,1);
 assert.equal(d.calls[0].sql,SECTION9_CLOCK_SQL.accept);
 assert.deepEqual(d.calls[0].args,[1,DAY,EVENT,event.signature]);
 assert.deepEqual(d.counts(),{opened:1,released:1});
});

test('An unopened world returns a durable blocked result and no forecast',async()=>{
 const d=mockDb({response:blocked});
 const ingress=createSection9VerifiedGameClockIngress({
  database:d.db,gameEngineHmacSecret:SECRET});
 const out=await ingress.acceptEngineTick(signed());
 assert.equal(out.status,'blocked_world_not_open');
 assert.equal(out.clockAdvanced,false);
 assert.equal(out.forecastEnqueued,false);
 assert.equal(out.payrollPosted,false);
 assert.equal(out.bookingsCreated,false);
});

test('Replaying signed day uses the same event without advancing clock',async()=>{
 const d=mockDb({response:replayed});
 const ingress=createSection9VerifiedGameClockIngress({
  database:d.db,gameEngineHmacSecret:SECRET});
 const x=await ingress.acceptEngineTick(signed());
 assert.equal(x.replayed,true);
 assert.equal(x.clockAdvanced,false);
 assert.equal(x.forecastEnqueued,false);
});

test('Never trust an SQL response asserting salary or booking operations',async()=>{
 for(const unsafe of [
  {...accepted,payrollPosted:true},
  {...accepted,bookingsCreated:true},
  {...accepted,clockAdvanced:false},
  {...accepted,gameDate:'2000-01-03'},
  {...accepted,engineEventId:'wrong-event'},
  {...accepted,worldId:2},
  {...accepted,status:'unrecognized'}
 ]){
  const d=mockDb({response:unsafe});
  const ingress=createSection9VerifiedGameClockIngress({
   database:d.db,gameEngineHmacSecret:SECRET});
  await assert.rejects(ingress.acceptEngineTick(signed()),
   /SECTION9_UNSAFE_GAME_CLOCK_RESPONSE|SECTION9_CLOCK_EVENT_MISMATCH/);
  assert.deepEqual(d.counts(),{opened:1,released:1});
 }
});

test('Readiness reports world gates without any source-side writes',async()=>{
 const state={worldId:1,worldState:'planned',worldOpensAt:null,
  gameDate:null,clockSource:'not_connected',verifiedTickCount:0,
  clockConnected:false,engineEventProducerConnected:false,
  automaticPayrollEnabled:false,actualFlightBookingsEnabled:false,
  readOnly:true};
 const d=mockDb({response:state});
 const ingress=createSection9VerifiedGameClockIngress({
  database:d.db,gameEngineHmacSecret:SECRET});
 const out=await ingress.readiness();
 assert.deepEqual(out,state);
 assert.equal(d.calls[0].sql,SECTION9_CLOCK_SQL.readiness);
 assert.deepEqual(d.calls[0].args,[]);
});
test('Database failure always releases private connection',async()=>{
 const d=mockDb({throwSql:true});
 const ingress=createSection9VerifiedGameClockIngress({
  database:d.db,gameEngineHmacSecret:SECRET});
 await assert.rejects(ingress.acceptEngineTick(signed()),
  /SECTION9_GAME_CLOCK_SOURCE_DB_UNAVAILABLE/);
 assert.deepEqual(d.counts(),{opened:1,released:1});
});
