/** Owner-only inert workspace planning settings; no gameplay release. */
import {Pool} from 'npm:pg@8.16.3';
import {createHostedAuthVerifier} from './hosted-auth-verifier.mjs';
import {createPlayerDraftsHandler} from './player-drafts-service.mjs';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as settings}
 from '../website/invited-tester-public-settings.mjs';
const dbUrl=Deno.env.get('SUPABASE_DB_URL');
let pool:any=null;
const database={async connect(){
 if(!dbUrl)throw Error('Private database not configured');
 if(!pool)pool=new Pool({connectionString:dbUrl,ssl:{rejectUnauthorized:true},
  max:2,idleTimeoutMillis:10000,connectionTimeoutMillis:5000});
 return pool.connect();
}};
const handler=createPlayerDraftsHandler({
 verifyUserToken:createHostedAuthVerifier({publishableKey:settings.publishableKey}),
 database
});
Deno.serve(async(request:Request)=>handler(request));
