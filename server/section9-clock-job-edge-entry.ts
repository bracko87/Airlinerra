/** Private World1 game-day scheduler endpoint. Deliberately DISABLED
 * unless the protected job token, game-engine HMAC and private DB URL
 * are all configured. Never a player API; no built-in cron schedule. */
import {Pool} from 'npm:pg@8.16.3';
import {createSection9ScheduledGameDayProducer}
 from './section9-scheduled-game-day-producer.mjs';
import {createSection9ClockJobHandler}
 from './section9-clock-job-handler.mjs';

const DB_URL=Deno.env.get('SUPABASE_DB_URL');
const SECRET=Deno.env.get('AIRLINERRA_GAME_ENGINE_HMAC_SECRET');
const JOB_TOKEN=Deno.env.get('AIRLINERRA_CLOCK_JOB_TOKEN');

if(!DB_URL||!SECRET||SECRET.length<32||!JOB_TOKEN||JOB_TOKEN.length<32){
 Deno.serve(()=>Response.json(
  {error:'Game clock producer not configured'},
  {status:503,headers:{'Cache-Control':'no-store'}}));
}else{
 let pool=null;
 const database={
  async connect(){
   if(!pool)pool=new Pool({
    connectionString:DB_URL,ssl:{rejectUnauthorized:true},
    max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000
   });
   return pool.connect();
  }
 };
 const producer=createSection9ScheduledGameDayProducer({
  database,gameEngineHmacSecret:SECRET
 });
 const handler=createSection9ClockJobHandler({producer,jobToken:JOB_TOKEN});
 Deno.serve(request=>handler(request));
}
