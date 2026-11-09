import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createSection9ScheduledGameDayProducer,SECTION9_PRODUCER_SQL}
 from '../server/section9-scheduled-game-day-producer.mjs';
import {createSection9ClockJobHandler}
 from '../server/section9-clock-job-handler.mjs';
import {createSection9VerifiedGameClockIngress,SECTION9_CLOCK_SQL}
 from '../server/section9-verified-game-clock-ingress.mjs';

const SECRET='private-test-only-game-engine-signer-abcdefghijklmnopqrstuvwxyz';
const JOB_SECRET='independent-private-cron-job-secret-123456789abcdefghijklmnopqrstuvwxyz';
const day=n=>'2000-01-'+String(n).padStart(2,'0');
const eventId=d=>'horizon-world1-day-'+d;
const due=(n,behind=0)=>({
 status:'due',worldId:1,readOnly:true,clockAdvanced:false,
 gameDate:day(n),eventId:eventId(day(n)),daysBehind:behind,
 payrollPosted:false,bookingsCreated:false
});
const stop=(status='caught_up')=>({
 status,worldId:1,readOnly:true,clockAdvanced:false
});
function mockDatabase(states){
 const calls=[];let releases=0,connections=0,idx=0;
 const database={connect:async()=>{
  connections++;
  return {release(){releases++;},async query(sql,args){
   calls.push({sql,args});
   if(sql!==SECTION9_PRODUCER_SQL.due)throw Error('unexpected DB query');
   return {rowCount:1,rows:[{result:states[Math.min(idx++,states.length-1)]}]};
  }};
 }};
 return {database,calls,stats:()=>({connections,releases})};
}
function mockIngress(){
 const calls=[];
 return {calls,acceptScheduledEngineTick:async event=>{
  calls.push(event);
  const expected=createHmac('sha256',SECRET).update(
   'airlinerra-game-engine-day-v1\n1\n'+event.gameDate+'\n'+event.eventId
  ).digest('hex');
  assert.equal(event.signature,expected);
  return {status:'verified_tick_accepted',worldId:1,
   gameDate:event.gameDate,engineEventId:event.eventId,
   clockAdvanced:true,replayed:false,
   payrollPosted:false,bookingsCreated:false,forecastEnqueued:false};
 }};
}

test('No world release means no signed event or game-day transition',async()=>{
 for(const reason of ['blocked_world_not_open','not_configured','paused',
  'opening_anchor_changed','clock_state_invalid','caught_up']){
  const db=mockDatabase([stop(reason)]),adapter=mockIngress();
  const producer=createSection9ScheduledGameDayProducer({
   database:db.database,gameEngineHmacSecret:SECRET,ingress:adapter
  });
  const result=await producer.runBounded({maxDays:3});
  assert.equal(result.status,reason);
  assert.equal(result.ticksAccepted,0);
  assert.equal(result.payrollPosted,false);
  assert.equal(adapter.calls.length,0);
  assert.deepEqual(db.stats(),{connections:1,releases:1});
 }
});
test('Two missed real days are processed sequentially, without skipping dates',async()=>{
 const db=mockDatabase([due(1,2),due(2,1),due(3,0),stop()]);
 const adapter=mockIngress();
 const producer=createSection9ScheduledGameDayProducer({
  database:db.database,gameEngineHmacSecret:SECRET,ingress:adapter
 });
 const r=await producer.runBounded({maxDays:3});
 assert.equal(r.status,'caught_up');
 assert.equal(r.ticksAccepted,3);
 assert.deepEqual(r.acceptedGameDates,[day(1),day(2),day(3)]);
 assert.equal(adapter.calls.length,3);
 assert.equal(db.calls.length,4);
 assert.deepEqual(db.stats(),{connections:4,releases:4});
 assert.equal(r.bookingsCreated,false);
});
test('Catch-up batch budget never runs unbounded or claims completion early',async()=>{
 const db=mockDatabase([due(1,16),due(2,15),due(3,14),due(4,13)]);
 const adapter=mockIngress();
 const producer=createSection9ScheduledGameDayProducer({
  database:db.database,gameEngineHmacSecret:SECRET,ingress:adapter
 });
 const r=await producer.runBounded({maxDays:3});
 assert.equal(r.status,'catchup_more_due');
 assert.equal(r.ticksAccepted,3);
 assert.equal(r.pendingDays,14);
 assert.equal(adapter.calls.length,3);
});
test('Concurrent worker replay is not treated as locally committed game-day advancement',async()=>{
 const db=mockDatabase([due(1,1)]);
 const adapter={acceptScheduledEngineTick:async evt=>({
  status:'already_applied',worldId:1,
  gameDate:evt.gameDate,engineEventId:evt.eventId,clockAdvanced:false,
  replayed:true,payrollPosted:false,bookingsCreated:false,
  forecastEnqueued:false
 })};
 const producer=createSection9ScheduledGameDayProducer({
  database:db.database,gameEngineHmacSecret:SECRET,ingress:adapter
 });
 const r=await producer.runBounded({maxDays:3});
 assert.equal(r.status,'concurrent_tick_already_applied');
 assert.equal(r.ticksAccepted,0);
 assert.equal(r.pendingDays,2);
 assert.equal(db.calls.length,1);
});
test('Malformed, caller-forged or salary-enabled due state is rejected before signing',async()=>{
 for(const invalid of [
  {...due(1),gameDate:'2000-02-30'},
  {...due(1),eventId:'horizon-world1-day-2099-01-01'},
  {...due(1),payrollPosted:true},
  {...due(1),bookingsCreated:true},
  {...due(1),daysBehind:-1},
  {...due(1),worldId:2},
  {...due(1),clockAdvanced:true},
  {...due(1),readOnly:false},
  {...due(1),status:'invented'}
 ]){
  const db=mockDatabase([invalid]),adapter=mockIngress();
  const producer=createSection9ScheduledGameDayProducer({
   database:db.database,gameEngineHmacSecret:SECRET,ingress:adapter
  });
  await assert.rejects(producer.runBounded({maxDays:2}),
   /SECTION9_CLOCK_PRODUCER_UNTRUSTED_DATABASE_STATE|SECTION9_CLOCK_PRODUCER_INVALID_DUE_DATE|SECTION9_CLOCK_PRODUCER_INVALID_STATUS/);
  assert.equal(adapter.calls.length,0);
 }
});
test('Budget and signing secret are verified before opening private DB',async()=>{
 const db=mockDatabase([due(1)]);
 assert.throws(()=>createSection9ScheduledGameDayProducer({
  database:db.database,gameEngineHmacSecret:'short'}),
  /SECTION9_CLOCK_ENGINE_SECRET_REQUIRED/);
 const producer=createSection9ScheduledGameDayProducer({
  database:db.database,gameEngineHmacSecret:SECRET,ingress:mockIngress()
 });
 for(const n of [0,4,3.1,'3']){
  await assert.rejects(producer.runBounded({maxDays:n}),
   /SECTION9_INVALID_CLOCK_PRODUCER_BUDGET/);
 }
 assert.deepEqual(db.stats(),{connections:0,releases:0});
});
test('Existing signed clock ingress routes producer events through due-gated SQL',async()=>{
 const calls=[];let release=0;
 const db={connect:async()=>({
  release(){release++},async query(sql,args){
   calls.push({sql,args});
   return {rowCount:1,rows:[{result:{
    status:'verified_tick_accepted',worldId:1,
    gameDate:day(1),engineEventId:eventId(day(1)),
    clockAdvanced:true,replayed:false,
    forecastEnqueued:false,payrollPosted:false,bookingsCreated:false
   }}]};
  }
 })};
 const ingress=createSection9VerifiedGameClockIngress({
  database:db,gameEngineHmacSecret:SECRET
 });
 const signature=createHmac('sha256',SECRET).update(
  'airlinerra-game-engine-day-v1\n1\n'+day(1)+'\n'+eventId(day(1))
 ).digest('hex');
 const r=await ingress.acceptScheduledEngineTick({
  worldId:1,gameDate:day(1),eventId:eventId(day(1)),signature
 });
 assert.equal(r.clockAdvanced,true);
 assert.equal(calls[0].sql,SECTION9_CLOCK_SQL.scheduled);
 assert.equal(release,1);
});
test('Job handler requires token, rejects caller-controlled game dates',async()=>{
 let calls=0;
 const handler=createSection9ClockJobHandler({
  jobToken:JOB_SECRET,
  producer:{runBounded:async args=>{
   calls++;assert.deepEqual(args,{maxDays:3});
   return {status:'blocked_world_not_open',worldId:1,
    ticksAccepted:0,acceptedGameDates:[],
    payrollPosted:false,bookingsCreated:false};
  }}
 });
 const request=(method,token,body)=>new Request('https://example.test/clock-job',{
  method,headers:token?{'x-airlinerra-clock-job-token':token}:{},
  ...(method==='POST'&&body!==undefined?{body}: {})
 });
 assert.equal((await handler(request('GET',JOB_SECRET))).status,405);
 assert.equal((await handler(request('POST',null,'{}'))).status,401);
 assert.equal((await handler(request('POST','incorrect-secret','{}'))).status,401);
 assert.equal((await handler(request('POST',JOB_SECRET,JSON.stringify({gameDate:day(1)})))).status,400);
 assert.equal(calls,0);
 const r=await handler(request('POST',JOB_SECRET,'{}'));
 assert.equal(r.status,200);
 assert.equal((await r.json()).ticksAccepted,0);
 assert.equal(calls,1);
 assert.equal(r.headers.get('Cache-Control'),'no-store');
});
test('Cron handler fails closed if producer claims financial or flight activation',async()=>{
 const handler=createSection9ClockJobHandler({
  jobToken:JOB_SECRET,
  producer:{runBounded:async()=>({
   status:'caught_up',worldId:1,ticksAccepted:1,
   acceptedGameDates:[day(1)],payrollPosted:true,bookingsCreated:false
  })}
 });
 const r=await handler(new Request('https://example.test/clock-job',{
  method:'POST',headers:{'x-airlinerra-clock-job-token':JOB_SECRET},body:'{}'
 }));
 assert.equal(r.status,503);
 assert.deepEqual(await r.json(),{error:'Unverified clock producer result'});
});
