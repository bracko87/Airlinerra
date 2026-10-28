import test from 'node:test';
import assert from 'node:assert/strict';
import {
  PRIVATE_TESTER_DASHBOARD_PATH,PRIVATE_TESTER_LOGIN_PATH,
  PrivateTesterAccessDenied,isVerifiedInvitedUser,openPrivateTesterDashboard
} from '../website/tester-dashboard-state.mjs';
import {TESTER_ORIGIN,TESTER_AUTH_URL} from '../website/invited-tester-entry.mjs';

const KEY='sb_publishable_'+('B'.repeat(32));
const config={operatorPrelaunchApproved:true,supabaseUrl:TESTER_AUTH_URL,publishableKey:KEY};
const user={id:'private-id',email:'invited@example.com',email_confirmed_at:'2026-10-28T10:00:00Z',is_anonymous:false};
const setup=(overrides={})=>{
  let created=0,checked=0,signedOut=0;
  const auth={getUser:async()=>user,signOut:async()=>{signedOut++;}};
  const params={
    origin:TESTER_ORIGIN,pathname:PRIVATE_TESTER_DASHBOARD_PATH,config,
    inspectProvider:async({publishableKey})=>{assert.equal(publishableKey,KEY);checked++;},
    createAuth:async(details)=>{created++;assert.equal(details.origin,TESTER_ORIGIN);return auth;},
    ...overrides
  };
  return {params,counts:()=>({created,checked,signedOut}),auth};
};

test('verified, invited email is necessary for dashboard user details',()=>{
  assert.equal(PRIVATE_TESTER_LOGIN_PATH,'/account.html?screen=sign-in');
  assert.equal(PRIVATE_TESTER_DASHBOARD_PATH,'/tester.html');
  assert.equal(isVerifiedInvitedUser(user),true);
  for(const candidate of [
    null,{}, {...user,id:''},{...user,email:''},
    {...user,email_confirmed_at:null},{...user,is_anonymous:true},
    {...user,deleted_at:'2026-10-28T10:00:00Z'}
  ])assert.equal(isVerifiedInvitedUser(candidate),false);
});

test('provider gate precedes client initialization and identity read',async()=>{
  const s=setup();const opened=await openPrivateTesterDashboard(s.params);
  assert.equal(opened.user,user);
  assert.equal(opened.auth,s.auth);
  assert.deepEqual(s.counts(),{created:1,checked:1,signedOut:0});
  const blocked=setup({inspectProvider:async()=>{throw Error('private signup guard closed');}});
  await assert.rejects(openPrivateTesterDashboard(blocked.params),/private signup guard/);
  assert.equal(blocked.counts().created,0);
});

test('foreign domain, wrong path or unsafe browser config fails before any provider request',async()=>{
  for(const input of [
    {origin:'https://www.airlinerra.com'},
    {origin:'https://malicious.example'},
    {pathname:'/account.html'},
    {config:{...config,operatorPrelaunchApproved:false}},
    {config:{...config,publishableKey:'sb_secret_unsafe'}},
    {config:{...config,supabaseUrl:'https://unrelated.supabase.co'}}
  ]){
    const s=setup(input);
    await assert.rejects(openPrivateTesterDashboard(s.params),PrivateTesterAccessDenied);
    assert.deepEqual(s.counts(),{created:0,checked:0,signedOut:0});
  }
});

test('missing, anonymous, unconfirmed or deleted identities cannot enter dashboard',async()=>{
  for(const bad of [
    null,{...user,email_confirmed_at:null},
    {...user,is_anonymous:true},{...user,deleted_at:'2026-10-28T10:00:00Z'}
  ]){
    const s=setup({createAuth:async()=>({
      getUser:async()=>bad,signOut:async()=>{}
    })});
    await assert.rejects(openPrivateTesterDashboard(s.params),PrivateTesterAccessDenied);
  }
});

test('client with registration capability is rejected',async()=>{
  const s=setup({createAuth:async()=>({
    getUser:async()=>user,signOut:async()=>{},signUp:async()=>{}
  })});
  await assert.rejects(openPrivateTesterDashboard(s.params),PrivateTesterAccessDenied);
});


test('missing Supabase session redirects through access denial, not service error',async()=>{
  const missing=new Error('Auth session missing');
  missing.name='AuthSessionMissingError';
  let signedOut=false;
  const s=setup({createAuth:async()=>({
    getUser:async()=>{throw missing;},
    signOut:async()=>{signedOut=true;}
  })});
  await assert.rejects(openPrivateTesterDashboard(s.params),PrivateTesterAccessDenied);
  assert.equal(signedOut,true);
});
