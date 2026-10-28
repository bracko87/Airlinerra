import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
  TESTER_ORIGIN,TESTER_AUTH_URL,consumeInvitedTesterEntry,
  inspectInvitedTesterProvider,openInvitedTesterEntry
} from '../website/invited-tester-entry.mjs';

const KEY='sb_publishable_'+('A'.repeat(32));
const safe={disable_signup:true,mailer_autoconfirm:false,
  external:{email:true,anonymous_users:false}};
const response=(body,status=200)=>new Response(JSON.stringify(body),{
  status,headers:{'content-type':'application/json'}
});
const secureFetch=async(url,request)=>{
  assert.equal(url,TESTER_AUTH_URL+'/auth/v1/settings');
  assert.equal(request.method,'GET');
  assert.equal(request.headers.apikey,KEY);
  assert.equal(request.cache,'no-store');
  assert.equal(request.redirect,'error');
  return response(safe);
};
const auth=()=>({
  signIn:async()=>{},completeCallback:async()=>({purpose:'invite'}),
  updatePassword:async()=>{},getUser:async()=>null,
  requestPasswordReset:async()=>{},signOut:async()=>{}
});

test('official-domain invitation OTP URL is scrubbed synchronously before any async work',()=>{
  const events=[];
  const hash='AbcdefghijklMNOP98765432';
  const path='/account.html?screen=verify&token_hash='+hash+'&type=invite';
  const result=consumeInvitedTesterEntry({
    href:TESTER_ORIGIN+path,
    replaceState:(_,__,url)=>events.push(url)
  });
  assert.deepEqual(events,['/account.html?screen=verify']);
  assert.deepEqual(result.callback,{kind:'otp',token_hash:hash,type:'invite',purpose:'verify'});
  assert.equal(result.screen,'verify');
});

test('email verification, recovery and invalid links use safe callback screens',()=>{
  let scrubbed;
  const recovery=consumeInvitedTesterEntry({
    href:TESTER_ORIGIN+'/account.html?screen=reset&token_hash=123456789ABCDEFGHIJK&type=recovery',
    replaceState:(_,__,path)=>{scrubbed=path;}
  });
  assert.equal(scrubbed,'/account.html?screen=reset');
  assert.equal(recovery.callback.type,'recovery');
  const missing=consumeInvitedTesterEntry({
    href:TESTER_ORIGIN+'/account.html?screen=reset',replaceState:()=>{}
  });
  assert.equal(missing.screen,'forgot');
  assert.equal(missing.needsRecoveryLink,true);
  for(const path of [
    '/account.html?screen=verify&token_hash=bad&type=invite',
    '/account.html?screen=reset&token_hash=123456789ABCDEFGHIJK&type=invite',
    '/account.html?screen=verify#access_token=fake',
    '/account.html?screen=verify&code=bad&token_hash=abcdefghijkl123456&type=invite'
  ]){
    let count=0;
    assert.throws(()=>consumeInvitedTesterEntry({
      href:TESTER_ORIGIN+path,replaceState:()=>{count++;}
    }));
    assert.equal(count,1);
  }
  assert.throws(()=>consumeInvitedTesterEntry({
    href:'https://www.airlinerra.com/account.html?screen=verify',replaceState:()=>{}
  }),/official domain/);
  assert.throws(()=>consumeInvitedTesterEntry({
    href:TESTER_ORIGIN+'/prelaunch-invited-account.html',replaceState:()=>{}
  }),/official domain/);
});

test('hosted provider must explicitly disable signup/anonymous and require email confirmation',async()=>{
  assert.equal((await inspectInvitedTesterProvider({publishableKey:KEY,fetchImpl:secureFetch})).inviteOnly,true);
  for(const data of [
    {...safe,disable_signup:false},{...safe,disable_signup:null},
    {...safe,mailer_autoconfirm:true},
    {...safe,external:{...safe.external,email:false}},
    {...safe,external:{email:true,anonymous_users:true}},
    {...safe,external:{email:true}}
  ]){
    await assert.rejects(
      inspectInvitedTesterProvider({publishableKey:KEY,fetchImpl:async()=>response(data)}),
      /not authorized/
    );
  }
  await assert.rejects(inspectInvitedTesterProvider({
    publishableKey:KEY,fetchImpl:async()=>response(safe,401)
  }),/Cannot verify/);
  await assert.rejects(inspectInvitedTesterProvider({
    publishableKey:'sb_secret_unsafe',fetchImpl:secureFetch
  }),/Pinned invite-only/);
});

test('unsafe hosted settings NEVER load an invited-tester SDK or client',async()=>{
  let touched=0;
  const hash='abcdefghijkl123456789';
  const url=TESTER_ORIGIN+'/account.html?screen=verify&token_hash='+hash+'&type=invite';
  await assert.rejects(openInvitedTesterEntry({
    href:url,replaceState:()=>{},
    publishableKey:KEY,
    fetchImpl:async()=>response({...safe,disable_signup:false}),
    createAuth:async()=>{touched++;return auth();}
  }),/not authorized/);
  assert.equal(touched,0);
});

test('verified invitation unlocks private password setup, without exposing signup',async()=>{
  const events=[];
  let receivedCallback;
  const sampleAuth={
    ...auth(),completeCallback:async callback=>{
      receivedCallback=callback;return {purpose:'invite'};
    }
  };
  const hash='abcdefghijklABCDEFGHIJKLM123';
  const result=await openInvitedTesterEntry({
    href:TESTER_ORIGIN+'/account.html?screen=verify&token_hash='+hash+'&type=invite',
    replaceState:(_,__,url)=>events.push(url),
    publishableKey:KEY,fetchImpl:secureFetch,
    createAuth:async conf=>{
      assert.equal(conf.origin,TESTER_ORIGIN);
      assert.equal(conf.supabaseUrl,TESTER_AUTH_URL);
      assert.equal(conf.publishableKey,KEY);
      return sampleAuth;
    }
  });
  assert.deepEqual(events,['/account.html?screen=verify']);
  assert.equal(receivedCallback.token_hash,hash);
  assert.equal(result.screen,'set-password');
  assert.equal(result.auth, sampleAuth);
});

test('main website ships ONLY invitation login; public player signup stays disabled',async()=>{
  const base=new URL('../',import.meta.url);
  const [build,overlay,rules,shell,page]=await Promise.all([
    readFile(new URL('website/dev-scripts/build.mjs',base),'utf8'),
    readFile(new URL('website/dev-scripts/invited-overlay.mjs',base),'utf8'),
    readFile(new URL('website/auth-rules.mjs',base),'utf8'),
    readFile(new URL('website/prelaunch-invited-account.html',base),'utf8'),
    readFile(new URL('website/invited-tester-page.mjs',base),'utf8')
  ]);
  assert.match(build,/addInviteOnlyAccount\(\{siteDir,distDir\}\)/);
  assert.match(overlay,/invited-tester-entry\.mjs/);
  assert.match(rules,/export const PUBLIC_AUTH_ENABLED = false;/);
  assert.match(shell,/PRIVATE PRELAUNCH ACCESS/);
  assert.match(shell,/id="set-password"/);
  assert.doesNotMatch(shell,/id="register"/);
  assert.match(page,/operatorPrelaunchApproved!==true/);
  assert.doesNotMatch(page,/\.signUp\(/);
});
