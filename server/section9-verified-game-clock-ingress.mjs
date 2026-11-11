/**
 * Airlinerra Section 9: trusted game-engine day ingress.
 *
 * This is a BACKEND ONLY adapter for the future authoritative world engine.
 * Never import into the player website and never expose through an HTTP
 * endpoint. The engine must emit an HMAC-authenticated per-game-day event.
 *
 * Does not infer a game day from Date.now(), world registration time,
 * a browser timezone, or a player's chosen date. If the world has not opened
 * or the engine event secret is unavailable, no clock/flight/ledger update.
 *
 * One SQL statement atomically:
 *   verifies world opening and strict +1 game date progression,
 *   appends unique signed-event receipt and sets the existing world clock,
 *   queues a READ-ONLY demand forecast only for certified active schedules.
 *
 * Crew payroll and passenger/flight settlements are NOT triggered here.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';
import {Buffer} from 'node:buffer';

export const SECTION9_CLOCK_SQL=Object.freeze({
 accept:`SELECT airlinerra_game.section9_accept_verified_game_tick_v1(
  $1::smallint,$2::date,$3::text,$4::text) AS result`,
 scheduled:`SELECT airlinerra_game.section9_accept_scheduled_game_tick_v1(
  $1::smallint,$2::date,$3::text,$4::text) AS result`,
 readiness:`SELECT airlinerra_game.section9_world_clock_dispatch_readiness_v1(
  1::smallint) AS result`
});
const DATE=/^\d{4}-\d{2}-\d{2}$/;
const EVENT=/^[A-Za-z0-9._:-]{12,128}$/;
const HEX=/^[a-f0-9]{64}$/;
const dateValid=x=>typeof x==='string'&&DATE.test(x)&&
 Number.isFinite(Date.parse(x+'T00:00:00Z'))&&
 new Date(x+'T00:00:00Z').toISOString().slice(0,10)===x&&
 x>='2000-01-01'&&x<='2199-12-31';
const eventPayload=({worldId,gameDate,eventId})=>
 'airlinerra-game-engine-day-v1\n'+worldId+'\n'+gameDate+'\n'+eventId;
const legitimateResult=r=>{
 if(!r||r.payrollPosted!==false||r.bookingsCreated!==false||
    r.worldId!==1)return false;
 if(r.status==='blocked_world_not_open')
  return r.clockAdvanced===false&&r.forecastEnqueued===false;
 if(r.status==='verified_tick_accepted')
  return r.clockAdvanced===true&&r.replayed===false&&
   typeof r.forecastEnqueued==='boolean';
 if(r.status==='already_applied')
  return r.clockAdvanced===false&&r.replayed===true&&
   typeof r.forecastEnqueued==='boolean';
 return false;
};
async function runSingle(client,sql,args){
 const r=await client.query(sql,args);
 if(r.rowCount!==1||!r.rows?.[0]?.result)
  throw Error('SECTION9_CLOCK_DATABASE_RESULT_UNAVAILABLE');
 return r.rows[0].result;
}
export function createSection9VerifiedGameClockIngress({
 database,gameEngineHmacSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_PRIVATE_DATABASE_REQUIRED');
 // Must come from an independent trusted game-engine secret store, NEVER
 // from a player request, the repository, or a database user-controlled row.
 if(typeof gameEngineHmacSecret!=='string'||
  gameEngineHmacSecret.length<32)
  throw Error('SECTION9_ENGINE_CLOCK_SIGNING_SECRET_NOT_CONFIGURED');
 const secret=Buffer.from(gameEngineHmacSecret,'utf8');
 return Object.freeze({
  async acceptEngineTick({worldId,gameDate,eventId,signature}={}){
   return acceptSigned({worldId,gameDate,eventId,signature},false);
  },
  async acceptScheduledEngineTick({worldId,gameDate,eventId,signature}={}){
   return acceptSigned({worldId,gameDate,eventId,signature},true);
  },
  async readiness(){
   const client=await database.connect();
   try{
    const r=await runSingle(client,SECTION9_CLOCK_SQL.readiness,[]);
    if(r.readOnly!==true||r.worldId!==1||
      r.automaticPayrollEnabled!==false||
      r.actualFlightBookingsEnabled!==false)
     throw Error('SECTION9_UNSAFE_CLOCK_READINESS_RESPONSE');
    return r;
   }finally{client.release();}
  }
 });
 async function acceptSigned({worldId,gameDate,eventId,signature},scheduled){
   if(worldId!==1||!dateValid(gameDate)||!EVENT.test(eventId||'')||
     !HEX.test(signature||''))
    throw Error('SECTION9_INVALID_SIGNED_GAME_DAY');
   const expected=createHmac('sha256',secret).update(
    eventPayload({worldId,gameDate,eventId}),'utf8').digest();
   const received=Buffer.from(signature,'hex');
   if(received.length!==32||!timingSafeEqual(expected,received))
    throw Error('SECTION9_UNTRUSTED_GAME_ENGINE_EVENT');
   // Signature never travels to player clients. DB receives the verified
   // digest for exact immutable idempotency, not the HMAC secret.
   const client=await database.connect();
   try{
    const result=await runSingle(client,scheduled?
     SECTION9_CLOCK_SQL.scheduled:SECTION9_CLOCK_SQL.accept,
     [worldId,gameDate,eventId,signature]);
    if(!legitimateResult(result))
     throw Error('SECTION9_UNSAFE_GAME_CLOCK_RESPONSE');
    if(result.status!=='blocked_world_not_open'&&
       (result.gameDate!==gameDate||result.engineEventId!==eventId))
     throw Error('SECTION9_CLOCK_EVENT_MISMATCH');
    return result;
   }finally{client.release();}
  }
}
