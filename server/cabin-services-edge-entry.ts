/** Separate cabin service API. No flight dispatch or settlement. */
import {Pool} from 'npm:pg@8.16.3';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {createCabinServicesHandler} from './cabin-services-service.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings}
 from '../website/invited-tester-public-settings.mjs';
const url=Deno.env.get('SUPABASE_DB_URL');
let pool:any=null;
const database={async connect(){
 if(!url)throw Error('Private game database unavailable');
 if(!pool)pool=new Pool({connectionString:url,ssl:{rejectUnauthorized:true},
  max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
 return pool.connect();
}};
const handler=createCabinServicesHandler({
 verifyUserToken:createHostedAuthVerifier({publishableKey:settings.publishableKey}),database});
Deno.serve(async(req:Request)=>handler(req));
