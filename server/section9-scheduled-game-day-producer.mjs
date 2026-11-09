/**
 * Airlinerra World1 game-day producer. One real elapsed 24-hour interval is
 * one in-game date, anchored to an independently administrator-approved
 * World1 opening timestamp and starting game date in private PostgreSQL.
 *
 * Never derives dates from player/browser input or JS clock; the DB
 * calculates the next due date from World1's actual opening timestamp.
 * Each trigger processes at most 1..3 sequential days, allowing safe
 * recovery after missed runs with no skip or unbounded catch-up.
 *
 * Requires a protected server-side HMAC engine secret and a configured,
 * explicitly enabled world schedule. Does not open worlds, enable flights,
 * charge crew salaries, generate tickets or credit revenues.
 */
import {createHmac} from 'node:crypto';
import {createSection9VerifiedGameClockIngress}
 from './section9-verified-game-clock-ingress.mjs';

export const SECTION9_PRODUCER_SQL=Object.freeze({
 due:`SELECT airlinerra_game.section9_clock_producer_due_v1(
  1::smallint) AS result`
});
const ISO_DATE=/^\d{4}-\d{2}-\d{2}$/;
const validDate=s=>typeof s==='string'&&ISO_DATE.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
const quiet=new Set(['blocked_world_not_open','not_configured','paused',
 'opening_anchor_changed','clock_state_invalid','clock_outside_release',
 'clock_date_limit','caught_up']);
const eventPayload=({worldId,gameDate,eventId})=>
 'airlinerra-game-engine-day-v1\n'+worldId+'\n'+gameDate+'\n'+eventId;

export function createSection9ScheduledGameDayProducer({
 database,gameEngineHmacSecret,ingress
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 if(typeof gameEngineHmacSecret!=='string'||gameEngineHmacSecret.length<32)
  throw Error('SECTION9_CLOCK_ENGINE_SECRET_REQUIRED');
 const adapter=ingress||createSection9VerifiedGameClockIngress({
  database,gameEngineHmacSecret
 });
 if(typeof adapter.acceptScheduledEngineTick!=='function')
  throw Error('SECTION9_DUE_GATED_INGRESS_REQUIRED');

 async function readDue(){
  const client=await database.connect();
  try{
   const query=await client.query(SECTION9_PRODUCER_SQL.due,[]);
   const due=query.rows?.[0]?.result;
   if(query.rowCount!==1||due?.worldId!==1||
      due.readOnly!==true||due.clockAdvanced!==false)
    throw Error('SECTION9_CLOCK_PRODUCER_UNTRUSTED_DATABASE_STATE');
   if(due.status==='due'){
    if(!validDate(due.gameDate)||typeof due.eventId!=='string'||
      due.eventId!=='horizon-world1-day-'+due.gameDate||
      !Number.isSafeInteger(due.daysBehind)||due.daysBehind<0||
      due.daysBehind>73000||due.payrollPosted!==false||
      due.bookingsCreated!==false)
     throw Error('SECTION9_CLOCK_PRODUCER_INVALID_DUE_DATE');
   }else if(!quiet.has(due.status)){
    throw Error('SECTION9_CLOCK_PRODUCER_INVALID_STATUS');
   }
   return due;
  }finally{client.release();}
 }
 return Object.freeze({
  readDue,
  async runBounded({maxDays=1}={}){
   if(!Number.isInteger(maxDays)||maxDays<1||maxDays>3)
    throw Error('SECTION9_INVALID_CLOCK_PRODUCER_BUDGET');
   const accepted=[];
   for(let i=0;i<maxDays;i++){
    const due=await readDue();
    if(due.status!=='due'){
     return {status:due.status,worldId:1,
      ticksAccepted:accepted.length,acceptedGameDates:accepted,
      pendingDays:0,clockAdvanced:accepted.length>0,
      payrollPosted:false,bookingsCreated:false};
    }
    const event={worldId:1,gameDate:due.gameDate,eventId:due.eventId};
    const signature=createHmac('sha256',gameEngineHmacSecret)
     .update(eventPayload(event),'utf8').digest('hex');
    const result=await adapter.acceptScheduledEngineTick({
     ...event,signature
    });
    if(result?.payrollPosted!==false||result?.bookingsCreated!==false||
     result?.worldId!==1||result?.gameDate!==due.gameDate||
     result?.engineEventId!==due.eventId||
     !['verified_tick_accepted','already_applied'].includes(result.status))
     throw Error('SECTION9_CLOCK_PRODUCER_UNCONFIRMED_COMMIT');
    // Other concurrent workers may have won the same tick. Never claim a
    // successful advancement from this worker or spin on that replay.
    if(result.status==='already_applied'){
     return {status:'concurrent_tick_already_applied',worldId:1,
      ticksAccepted:accepted.length,acceptedGameDates:accepted,
      pendingDays:due.daysBehind+1,clockAdvanced:accepted.length>0,
      payrollPosted:false,bookingsCreated:false};
    }
    if(result.clockAdvanced!==true||result.replayed!==false)
     throw Error('SECTION9_CLOCK_PRODUCER_COMMIT_NOT_CONFIRMED');
    accepted.push(due.gameDate);
   }
   const remaining=await readDue();
   return {status:remaining.status==='due'?'catchup_more_due':'caught_up',
    worldId:1,ticksAccepted:accepted.length,acceptedGameDates:accepted,
    pendingDays:remaining.status==='due'?remaining.daysBehind+1:0,
    clockAdvanced:accepted.length>0,payrollPosted:false,
    bookingsCreated:false};
  }
 });
}
