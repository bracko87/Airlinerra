/** Protected airline flight schedule drafts. No commercial flight activation. */
import {Pool} from 'npm:pg@8.16.3';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {createFlightScheduleHandler} from './flight-schedule-service.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings}
 from '../website/invited-tester-public-settings.mjs';

const DB_URL=Deno.env.get('SUPABASE_DB_URL');
let pool:any=null;
const verify=createHostedAuthVerifier({publishableKey:settings.publishableKey});
const database={
 async connect(){
  if(!DB_URL)throw Error('PRIVATE_SCHEDULE_DB_NOT_CONFIGURED');
  if(!pool)pool=new Pool({
    connectionString:DB_URL,ssl:{rejectUnauthorized:true},
    max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000
  });
  return pool.connect();
 }
};
const handler=createFlightScheduleHandler({verifyUserToken:verify,database});
Deno.serve(async(request:Request)=>handler(request));
