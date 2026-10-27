import test from 'node:test';
import assert from 'node:assert/strict';
import {parseHostedRuntimeConfig,AIRLINERRA_AUTH_API} from '../server/hosted-runtime-config.mjs';
import {createStagedNetlifyAccountHandler} from '../server/netlify-preview-template/airlinerra-accounts.mjs';
import {buildPrivatePreviewAccountApp} from '../server/preview-account-app.mjs';
import {PREVIEW_ACCESS_HEADER} from '../server/preview-access-guard.mjs';

const ORIGIN='https://airlinerra.com';
const SECRET='C'.repeat(43); // Synthetic CI-only value.
const TOKEN='synthetic-confirmed-user-token-for-closed-game';
const USER='11111111-1111-4111-8111-111111111111';
const PROJECT='hwllkabgzaynalahvkpz';
const PLATFORM=()=>({deploy:{context:'production',published:true},
  site:{name:'airlinerra',url:ORIGIN}});
const ENV=()=>({
  CONTEXT:'production',
  AIRLINERRA_HOSTED_BACKEND_ENABLED:'true',
  AIRLINERRA_HOSTED_RUNTIME_MODE:'canonical-prelaunch-test',
  AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED:'true',
  AIRLINERRA_CANONICAL_TEST_ORIGIN:ORIGIN,
  AIRLINERRA_CANONICAL_TEST_ACCESS_SECRET:SECRET,
  AIRLINERRA_SUPABASE_URL:AIRLINERRA_AUTH_API,
  AIRLINERRA_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_'+('A'.repeat(32)),
  AIRLINERRA_PRIVATE_DATABASE_URL:'postgresql://postgres.'+PROJECT+
    ':synthetic-only@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require',
  AIRLINERRA_TERMS_PATH:'/legal/terms-v1.html',
  AIRLINERRA_PRIVACY_PATH:'/legal/privacy-v1.html'
});
const request=(secret=SECRET,token=TOKEN,path='/api/v1/onboarding/context')=>
  new Request(ORIGIN+path,{method:'POST',headers:{
    origin:ORIGIN,'content-type':'application/json',
    [PREVIEW_ACCESS_HEADER]:secret,authorization:'Bearer '+token
  },body:'{}'});

test('production is disabled unless both independent canonical controls are set',()=>{
  const base=ENV();
  const good=parseHostedRuntimeConfig(base);
  assert.equal(good.enabled,true);
  assert.equal(good.mode,'canonical-prelaunch-test');
  assert.equal(good.context,'production');
  assert.equal(good.publicOrigin,ORIGIN);
  for(const key of ['AIRLINERRA_HOSTED_BACKEND_ENABLED','AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED']){
    assert.deepEqual(parseHostedRuntimeConfig({...base,[key]:'false'}),{enabled:false});
  }
  assert.deepEqual(parseHostedRuntimeConfig({...base,AIRLINERRA_HOSTED_RUNTIME_MODE:undefined}),{enabled:false});
  assert.throws(()=>parseHostedRuntimeConfig({...base,CONTEXT:'deploy-preview'}),/forbidden/);
  assert.throws(()=>parseHostedRuntimeConfig({...base,AIRLINERRA_CANONICAL_TEST_ORIGIN:'https://www.airlinerra.com'}));
  assert.throws(()=>parseHostedRuntimeConfig({...base,AIRLINERRA_CANONICAL_TEST_ORIGIN:'https://evil.example'}));
  assert.throws(()=>parseHostedRuntimeConfig({...base,AIRLINERRA_HOSTED_RUNTIME_MODE:'unexpected'}));
});

test('canonical access refuses untrusted context and missing opt-in before initializing app',async()=>{
  let builds=0,reads=0;
  const e=ENV();
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:()=>{reads++;return e;},
    buildApp:async()=>{builds++;return {enabled:true,handler:async()=>new Response('{}',{status:200})};}
  });
  const denied=[undefined,
    {...PLATFORM(),deploy:{context:'deploy-preview',published:false}},
    {...PLATFORM(),deploy:{context:'production',published:false}},
    {...PLATFORM(),site:{name:'airlinerra',url:'https://evil.example'}}
  ];
  for(const platform of denied){
    assert.equal((await handler(request(),platform)).status,503);
  }
  assert.equal(reads,1,
    'Legitimate deploy-preview metadata may read flags, but canonical runtime mode still rejects it');
  assert.equal(builds,0);
  e.AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED='false';
  assert.equal((await handler(request(),PLATFORM())).status,503);
  e.AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED='true';
  e.AIRLINERRA_HOSTED_RUNTIME_MODE='private-preview';
  e.AIRLINERRA_PRIVATE_PREVIEW_APPROVED='true';
  assert.equal((await handler(request(),PLATFORM())).status,503,
    'Private-preview authorization cannot unlock the public domain');
  assert.equal(builds,0);
});

test('canonical site operator secret is isolated from preview secret and forwarded headers',async()=>{
  let builds=0,forwarded=null,seen=null;
  const e={...ENV(),AIRLINERRA_PREVIEW_ACCESS_SECRET:'D'.repeat(43),CONTEXT:'dev'};
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:()=>e,
    buildApp:async({env:validated})=>{
      builds++;seen=validated;
      return {enabled:true,handler:async request=>{
        forwarded=request;
        return new Response('{}',{status:200});
      }};
    }
  });
  assert.equal((await handler(request(e.AIRLINERRA_PREVIEW_ACCESS_SECRET),PLATFORM())).status,503);
  assert.equal(builds,0);
  assert.equal((await handler(request(SECRET),PLATFORM())).status,200);
  assert.equal(builds,1);
  assert.equal(seen.CONTEXT,'production');
  assert.equal(seen.AIRLINERRA_HOSTED_RUNTIME_MODE,'canonical-prelaunch-test');
  assert.equal(forwarded.headers.get(PREVIEW_ACCESS_HEADER),null);
  assert.equal(forwarded.headers.get('authorization'),'Bearer '+TOKEN);
  assert.equal(e.CONTEXT,'dev');
});

test('denied operator requests never inspect server database credential values',async()=>{
  let dbReads=0;
  const e=ENV();
  Object.defineProperty(e,'AIRLINERRA_PRIVATE_DATABASE_URL',{enumerable:true,get(){
    dbReads++;return 'sensitive URL must not be read before operator admission';
  }});
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:()=>e,
    buildApp:async()=>{throw Error('No backend initialization expected');}
  });
  assert.equal((await handler(request('E'.repeat(43)),PLATFORM())).status,503);
  assert.equal((await handler(request('',TOKEN),PLATFORM())).status,503);
  assert.equal(dbReads,0);
});

test('confirmed synthetic user reaches exactly the closed release gate without exposing airports',async()=>{
  let dbQueries=0,dbConnections=0,authFetches=0;
  class Pool{
    constructor(options){
      assert.equal(options.ssl.rejectUnauthorized,true);
      assert.equal(options.max,2);
      assert.ok(options.connectionString.includes(PROJECT));
    }
    async connect(){
      dbConnections++;
      return {
        async query(sql){
          dbQueries++;
          assert.match(String(sql),/platform_release_gate/);
          return {rows:[{enabled:false,terms_version:null,privacy_version:null}]};
        },release(){}
      };
    }
    async end(){}
  }
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:ENV,
    buildApp:({env})=>buildPrivatePreviewAccountApp({
      env,loadPg:async()=>({Pool}),
      fetchImpl:async url=>{
        if(url.endsWith('/auth/v1/settings')){
          return new Response(JSON.stringify({
            disable_signup:true,mailer_autoconfirm:false,
            external:{email:true,anonymous_users:false}
          }),{status:200,headers:{'content-type':'application/json'}});
        }
        authFetches++;
        return new Response(JSON.stringify({
          id:USER,email_confirmed_at:'2026-10-27T00:00:00Z',is_anonymous:false
        }),{status:200,headers:{'content-type':'application/json'}});
      }
    })
  });
  const forbidden=await handler(request('X'.repeat(43)),PLATFORM());
  assert.equal(forbidden.status,503);
  assert.equal(authFetches,0);
  assert.equal(dbConnections,0);
  const closed=await handler(request(),PLATFORM());
  assert.equal(closed.status,503);
  assert.equal(authFetches,1);
  assert.equal(dbConnections,1);
  assert.equal(dbQueries,1,'No airport catalog query, no airline insert or write');
  assert.equal(closed.headers.get('cache-control'),'no-store');
  assert.doesNotMatch(await closed.text(),/postgres|password|airport_key|token/i);
});

test('unauthorized players receive 401 before any database connections',async()=>{
  let conn=0;
  class Pool{
    constructor(){}
    async connect(){conn++;throw Error('Never connect for invalid token');}
    async end(){}
  }
  const handler=createStagedNetlifyAccountHandler({
    getEnvironment:ENV,
    buildApp:({env})=>buildPrivatePreviewAccountApp({
      env,loadPg:async()=>({Pool}),
      fetchImpl:async url=>{
        if(url.endsWith('/auth/v1/settings'))return new Response(JSON.stringify({
          disable_signup:true,mailer_autoconfirm:false,
          external:{email:true,anonymous_users:false}
        }),{status:200,headers:{'content-type':'application/json'}});
        throw Error('Do not call Auth for rejected token syntax');
      }
    })
  });
  assert.equal((await handler(request(SECRET,'short'),PLATFORM())).status,401);
  assert.equal(conn,0);
});
