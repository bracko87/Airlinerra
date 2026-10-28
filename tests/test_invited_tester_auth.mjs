import test from 'node:test';
import assert from 'node:assert/strict';
import {
  validatedInvitedTesterConfig,createInvitedTesterAuth,
  INVITED_TESTER_SDK_VERSION
} from '../website/invited-tester-auth.mjs';

const ORIGIN='https://airlinerra.com';
const PROJECT='https://hwllkabgzaynalahvkpz.supabase.co';
const KEY='sb_publishable_'+('A'.repeat(32));
const config=()=>({origin:ORIGIN,supabaseUrl:PROJECT,publishableKey:KEY});

test('invited tester Auth is pinned to existing official domain and Supabase project',()=>{
  assert.deepEqual(validatedInvitedTesterConfig(config()),config());
  assert.equal(INVITED_TESTER_SDK_VERSION,'2.118.0');
  for(const patch of [
    {origin:'http://airlinerra.com'},
    {origin:'https://www.airlinerra.com'},
    {origin:'https://evil.example'},
    {supabaseUrl:'https://other-project.supabase.co'},
    {supabaseUrl:PROJECT+'/'},
    {publishableKey:'sb_secret_unsafe'},
    {publishableKey:'eyJabc.service-role'},
    {publishableKey:''}
  ]){
    assert.throws(()=>validatedInvitedTesterConfig({...config(),...patch}),/Pinned Airlinerra/);
  }
});

test('invalid project or origin cannot load SDK or create a session',async()=>{
  let loads=0;
  await assert.rejects(createInvitedTesterAuth({
    ...config(),origin:'https://other.example',
    loadSdk:async()=>{loads++;return {};}
  }),/Pinned Airlinerra/);
  assert.equal(loads,0);
});

test('invited tester supports email-confirmed login, recovery and signout but exposes no signup',async()=>{
  const calls=[];
  const fakeAuth={
    signInWithPassword:async data=>{
      calls.push(['signin',data]);
      return {data:{user:{id:'one',email_confirmed_at:'2026-10-27T12:00:00Z'}},error:null};
    },
    getUser:async()=>({data:{user:{id:'one',email_confirmed_at:'2026-10-27T12:00:00Z'}},error:null}),
    signOut:async options=>{calls.push(['signout',options]);return {error:null};},
    resetPasswordForEmail:async (email,options)=>{
      calls.push(['reset',email,options]);return {error:null};
    }
  };
  const tester=await createInvitedTesterAuth({
    ...config(),
    loadSdk:async()=>({
      createClient:(url,key,options)=>{
        assert.equal(url,PROJECT);
        assert.equal(key,KEY);
        assert.equal(options.auth.flowType,'pkce');
        assert.equal(options.auth.detectSessionInUrl,false);
        assert.equal(options.auth.storageKey,'airlinerra-invited-tester-v1');
        return {auth:fakeAuth};
      }
    })
  });
  assert.equal(tester.register,undefined);
  assert.equal(tester.supabase,undefined);
  assert.equal(tester.signUp,undefined);
  await tester.signIn({email:'  Pilot@Example.COM ',password:'correct-horse-battery-123'});
  assert.deepEqual(calls[0],['signin',{email:'pilot@example.com',password:'correct-horse-battery-123'}]);
  assert.equal((await tester.getUser()).id,'one');
  await tester.requestPasswordReset('Pilot@Example.com');
  assert.deepEqual(calls[1],['reset','pilot@example.com',
    {redirectTo:'https://airlinerra.com/account.html?screen=reset'}]);
  await tester.signOut();
  assert.deepEqual(calls[2],['signout',{scope:'local'}]);
  assert.deepEqual(tester.parseAuthCallback('?screen=verify&token_hash=abcdefghABCDEFGH1234&type=email','verify'),{
    kind:'otp',token_hash:'abcdefghABCDEFGH1234',type:'email',purpose:'verify'
  });
});

test('standard website build includes invited login, not general signup',async()=>{
  const {readFile}=await import('node:fs/promises');
  const build=await readFile(new URL('../website/dev-scripts/build.mjs',import.meta.url),'utf8');
  assert.match(build,/addInviteOnlyAccount/);
  const overlay=await readFile(new URL('../website/dev-scripts/invited-overlay.mjs',import.meta.url),'utf8');
  assert.match(overlay,/invited-tester-auth\.mjs/);
  const account=await readFile(new URL('../website/account.js',import.meta.url),'utf8');
  assert.doesNotMatch(account,/invited-tester-auth/);
});

test('read API token adapter rechecks same verified manager and refuses switched sessions',async()=>{
  let sessionId='one';
  const fakeAuth={
    getUser:async()=>({data:{user:{id:'one',email_confirmed_at:'2026-10-28T12:00:00Z'}},error:null}),
    getSession:async()=>({data:{session:{user:{id:sessionId},access_token:'example.jwt.token'}},error:null})
  };
  const tester=await createInvitedTesterAuth({...config(),loadSdk:async()=>({
    createClient:()=>({auth:fakeAuth})
  })});
  assert.equal(await tester.getAccessToken(),'example.jwt.token');
  sessionId='another-account';
  await assert.rejects(tester.getAccessToken(),/Verified session unavailable/);
});

test('real invited Auth can run on exact localhost without accepting hostile domains',()=>{
 assert.deepEqual(validatedInvitedTesterConfig({...config(),origin:'http://localhost:5188'}),{
  ...config(),origin:'http://localhost:5188'
 });
 for(const origin of ['http://localhost:5187','https://localhost:5188','http://127.0.0.1:5188','http://localhost.evil:5188']){
  assert.throws(()=>validatedInvitedTesterConfig({...config(),origin}),/Pinned Airlinerra/);
 }
});

test('real localhost Auth uses localhost for callback requests, never a production-only redirect',async()=>{
 const calls=[];
 const local=await createInvitedTesterAuth({...config(),origin:'http://localhost:5188',loadSdk:async()=>({
   createClient:()=>({auth:{
     resetPasswordForEmail:async(email,opts)=>{calls.push({email,opts});return {error:null}}
   }})
 })});
 await local.requestPasswordReset('Pilot@example.com');
 assert.deepEqual(calls,[{email:'pilot@example.com',opts:{
   redirectTo:'http://localhost:5188/account.html?screen=reset'
 }}]);
});
