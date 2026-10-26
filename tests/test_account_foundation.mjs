import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  PUBLIC_AUTH_ENABLED, ALLOWED_AUTH_ORIGINS, WORLD_DIRECTORY,
  safeScreen, normalizedEmail, validatedPassword, validatedDisplayName,
  authRedirect, isWorldSelectable
} from '../website/auth-rules.mjs';
import {
  createAuthService, parseAuthCallback, FORGOT_REPLY
} from '../website/auth-service.mjs';
import { createBrowserAuthClient, SUPABASE_SDK_VERSION } from '../website/auth-client.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

test('prelaunch hard-stop, strict origin and three locked real-time worlds', () => {
  assert.equal(PUBLIC_AUTH_ENABLED, false);
  assert.deepEqual(ALLOWED_AUTH_ORIGINS, ['http://localhost:5187']);
  assert.equal(WORLD_DIRECTORY.length, 3);
  assert.deepEqual(WORLD_DIRECTORY.map(w => w.id), ['01','02','03']);
  WORLD_DIRECTORY.forEach(w => {
    assert.equal(w.state, 'planned');
    assert.equal(w.calendar, '1 real day = 1 game day');
    assert.equal(isWorldSelectable(w), false);
  });
  assert.equal(isWorldSelectable({ state:'registration_open' }), true);
  assert.equal(SUPABASE_SDK_VERSION, '2.118.0');
});

test('screens, input validation and fixed callback URLs', () => {
  for (const screen of ['sign-in','register','forgot','reset','verify','worlds']) {
    assert.equal(safeScreen(screen), screen);
  }
  assert.equal(safeScreen('//other.example'), 'sign-in');
  assert.equal(normalizedEmail('  Air@Example.COM  '), 'air@example.com');
  assert.throws(() => normalizedEmail('invalid'), /valid email/);
  assert.equal(validatedPassword('abcdefghijkl'), 'abcdefghijkl');
  assert.throws(() => validatedPassword('short'), /12 to 128/);
  assert.throws(() => validatedPassword('a'.repeat(129)), /12 to 128/);
  assert.equal(validatedDisplayName('  Sky Pilot '), 'Sky Pilot');
  assert.throws(() => validatedDisplayName('<script>'), /display name/i);
  assert.equal(authRedirect('http://localhost:5187','verify'),
    'http://localhost:5187/account.html?screen=verify');
  assert.equal(authRedirect('http://localhost:5187','reset'),
    'http://localhost:5187/account.html?screen=reset');
  assert.throws(() => authRedirect('https://other.example','verify'), /not authorized/);
  assert.throws(() => authRedirect('http://localhost:5187','//other.example'), /Invalid/);
});

test('PKCE and one-time recovery callback parsing blocks mixed/cross-screen input', () => {
  assert.deepEqual(parseAuthCallback('?screen=verify&code=abc-123', 'verify'),
    {kind:'pkce',code:'abc-123',purpose:'verify'});
  assert.throws(() => parseAuthCallback('?screen=reset&code=abc-123', 'reset'),
    /Recovery-specific verification/);
  const hash = 'abcABC1234567890';
  assert.deepEqual(parseAuthCallback('?token_hash='+hash+'&type=recovery','reset'),
    {kind:'otp',token_hash:hash,type:'recovery',purpose:'reset'});
  assert.deepEqual(parseAuthCallback('?token_hash='+hash+'&type=email','verify'),
    {kind:'otp',token_hash:hash,type:'email',purpose:'verify'});
  assert.equal(parseAuthCallback('?screen=worlds&code=abc-123','worlds'),null);
  assert.equal(parseAuthCallback('?screen=verify','verify'),null);
  assert.throws(() => parseAuthCallback('?code=abc123&token_hash='+hash+'&type=email','verify'), /Invalid/);
  assert.throws(() => parseAuthCallback('?token_hash='+hash+'&type=recovery','verify'), /Unexpected/);
  assert.throws(() => parseAuthCallback('?token_hash='+hash+'&type=email','reset'), /Unexpected/);
  assert.throws(() => parseAuthCallback('?token_hash=x&type=recovery','reset'), /Invalid|invalid/);
});

test('hard-off browser adapter does not fetch external SDK even if caller requests enabled', async () => {
  let sdkLoads = 0;
  await assert.rejects(
    createBrowserAuthClient({
      origin:'http://localhost:5187',enabled:true,
      loadSdk:async()=>{sdkLoads++;return {createClient:()=>({})};}
    }), /not yet open/
  );
  assert.equal(sdkLoads,0);
});

test('service defaults closed and does not transmit credentials, even with an Auth client', async () => {
  let calls = 0;
  const auth = {
    signUp:async()=>{calls++;return {error:null};},
    signInWithPassword:async()=>{calls++;return {data:{},error:null};},
    resetPasswordForEmail:async()=>{calls++;return {error:null};},
    exchangeCodeForSession:async()=>{calls++;return {data:{session:{}},error:null};},
    verifyOtp:async()=>{calls++;return {data:{session:{}},error:null};},
    updateUser:async()=>{calls++;return {error:null};},
    getUser:async()=>{calls++;return {data:{user:{}},error:null};},
    signOut:async()=>{calls++;return {error:null};}
  };
  const api=createAuthService({supabase:{auth},origin:'http://localhost:5187'});
  await assert.rejects(api.register({email:'x@example.com',password:'abcdefghijkl',displayName:'Pilot',termsAccepted:true}), /not yet open/);
  await assert.rejects(api.signIn({email:'x@example.com',password:'abcdefghijkl'}), /not yet open/);
  await assert.rejects(api.requestPasswordReset('x@example.com'), /not yet open/);
  await assert.rejects(api.completeCallback({kind:'pkce',code:'abc123',purpose:'verify'}), /not yet open/);
  await assert.rejects(api.updatePassword('abcdefghijkl'), /not yet open/);
  await assert.rejects(api.getUser(), /not yet open/);
  await assert.rejects(api.signOut(), /not yet open/);
  assert.equal(calls,0);
});

test('injected test client exercises signup, login, PKCE, recovery and session security', async () => {
  const calls = [];
  const auth = {
    signUp:async arg=>{calls.push(['signup',arg]);return {data:{},error:null};},
    signInWithPassword:async arg=>{calls.push(['login',arg]);return {data:{user:{id:'test'}},error:null};},
    resetPasswordForEmail:async (email,options)=>{calls.push(['forgot',email,options]);return {error:null};},
    exchangeCodeForSession:async code=>{calls.push(['exchange',code]);return {data:{session:{access_token:'test'}},error:null};},
    verifyOtp:async arg=>{calls.push(['otp',arg]);return {data:{session:{access_token:'test',user:{id:'test'}}},error:null};},
    updateUser:async arg=>{calls.push(['password',arg]);return {error:null};},
    getUser:async()=>({data:{user:{id:'test'}},error:null}),
    signOut:async arg=>{calls.push(['signout',arg]);return {error:null};}
  };
  const api=createAuthService({supabase:{auth},origin:'http://localhost:5187',enabled:true});
  await assert.rejects(api.register({email:'X@example.com',password:'abcdefghijkl',displayName:'Pilot',termsAccepted:false}), /Accept/);
  await api.register({email:' X@example.com ',password:'abcdefghijkl',displayName:'Pilot',termsAccepted:true});
  assert.equal(calls[0][1].email, 'x@example.com');
  assert.equal(calls[0][1].options.emailRedirectTo,'http://localhost:5187/account.html?screen=verify');
  await api.signIn({email:'X@example.com',password:'abcdefghijkl'});
  assert.equal(calls[1][1].email,'x@example.com');
  const message = await api.requestPasswordReset('X@example.com');
  assert.equal(message.message,FORGOT_REPLY);
  assert.equal(calls[2][2].redirectTo,'http://localhost:5187/account.html?screen=reset');
  await api.completeCallback({kind:'pkce',code:'abc123',purpose:'verify'});
  assert.deepEqual(calls[3],['exchange','abc123']);
  // An invalid callback clears any prior recovery intent, so reject it
  // BEFORE the successful one-time recovery verification.
  await assert.rejects(api.completeCallback({kind:'otp',token_hash:'abcABC1234567890',type:'email',purpose:'reset'}), /Invalid/);
  await api.completeCallback({kind:'otp',token_hash:'abcABC1234567890',type:'recovery',purpose:'reset'});
  assert.equal(calls[4][1].type,'recovery');
  assert.equal((await api.getUser()).id,'test');
  await api.updatePassword('new-secret-password');
  assert.deepEqual(calls[5],['password',{password:'new-secret-password'}]);
  assert.deepEqual(calls[6],['signout',{scope:'global'}]);
  await api.signOut();
  assert.deepEqual(calls[7],['signout',{scope:'local'}]);
});

test('PKCE verification must never grant recovery-screen password changes', async () => {
  let exchanges = 0, changes = 0;
  const auth = {
    exchangeCodeForSession:async()=>{exchanges++;return {
      data:{session:{user:{id:'test'}}},error:null};},
    updateUser:async()=>{changes++;return {error:null};},
    getUser:async()=>({data:{user:{id:'test'}},error:null})
  };
  const api=createAuthService({supabase:{auth},origin:'http://localhost:5187',enabled:true});
  await assert.rejects(api.completeCallback({kind:'pkce',code:'confirmation-code',purpose:'reset'}),
    /Recovery-specific verification/);
  assert.equal(exchanges,0);
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
  assert.equal(changes,0);
  await api.completeCallback({kind:'pkce',code:'confirmation-code',purpose:'verify'});
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
  assert.equal(changes,0);
});

test('recovery OTP is single-use, tied to same verified account, and cleared on login', async () => {
  let authId='owner';
  let updates=0;
  const auth={
    verifyOtp:async()=>({data:{session:{user:{id:'owner'}}},error:null}),
    getUser:async()=>({data:{user:{id:authId}},error:null}),
    updateUser:async()=>{updates++;return {error:null};},
    signOut:async()=>({error:null}),
    signInWithPassword:async()=>({data:{user:{id:'owner'}},error:null})
  };
  const api=createAuthService({supabase:{auth},origin:'http://localhost:5187',enabled:true});
  const callback={kind:'otp',token_hash:'abcABC1234567890',type:'recovery',purpose:'reset'};
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
  await api.completeCallback(callback);
  authId='other-account';
  await assert.rejects(api.updatePassword('a-safe-password-123'),/identity changed/);
  assert.equal(updates,0);
  authId='owner';
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
  await api.completeCallback(callback);
  await api.updatePassword('a-safe-password-123');
  assert.equal(updates,1);
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
  await api.completeCallback(callback);
  await api.signIn({email:'owner@example.com',password:'a-safe-password-123'});
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
  assert.equal(updates,1);
});

test('verified recovery OTP session must match fresh Auth user', async () => {
  const api=createAuthService({supabase:{auth:{
    verifyOtp:async()=>({data:{session:{user:{id:'owner'}}},error:null}),
    getUser:async()=>({data:{user:{id:'other-account'}},error:null})
  }},origin:'http://localhost:5187',enabled:true});
  await assert.rejects(api.completeCallback({
    kind:'otp',token_hash:'abcABC1234567890',type:'recovery',purpose:'reset'
  }),/Recovery identity could not be verified/);
  await assert.rejects(api.updatePassword('a-safe-password-123'),/verified password recovery/);
});

test('forgot-password response is neutral on provider errors', async () => {
  const svc=createAuthService({supabase:{auth:{
    resetPasswordForEmail:async()=>{throw new Error('User missing');}
  }},origin:'http://localhost:5187',enabled:true});
  assert.equal((await svc.requestPasswordReset('nobody@example.com')).message,FORGOT_REPLY);
});

test('static page remains a non-submitting preview and build includes new modules', async () => {
  const html=await readFile(path.join(root,'website/account.html'),'utf8');
  const js=await readFile(path.join(root,'website/account.js'),'utf8');
  const css=await readFile(path.join(root,'website/account.css'),'utf8');
  const build=await readFile(path.join(root,'website/dev-scripts/build.mjs'),'utf8');
  const server=await readFile(path.join(root,'website/dev-scripts/dev.mjs'),'utf8');
  const pkg=JSON.parse(await readFile(path.join(root,'website/package.json'),'utf8'));
  assert.match(html,/name="robots" content="noindex,nofollow"/);
  assert.match(html,/No information entered here is submitted or stored/);
  assert.equal((html.match(/<fieldset disabled>/g)||[]).length,6);
  assert.equal((html.match(/<form /g)||[]).length,6);
  assert.equal((html.match(/<form[^>]+action=/gi)||[]).length,0);
  assert.match(html,/id="account-feedback"/);
  assert.match(html,/id="player-profile-form"/);
  assert.match(html,/id="airline-onboarding-form"/);
  assert.match(html,/id="onboarding-world"/);
  assert.match(html,/id="onboarding-airport"/);
  assert.match(html,/id="onboarding-accept-terms"/);
  assert.match(html,/id="onboarding-accept-privacy"/);
  assert.match(js,/onboardingApi\.acceptLegal/);
  assert.match(js,/onboardingApi\.createAirline/);
  assert.ok(js.includes('Starting balance: '));
  assert.match(js,/Seven-day trial ends:/);
  assert.doesNotMatch(js,/Starting balance: [\r\n]/);
  assert.match(html,/id="profile-display-name"/);
  assert.match(html,/id="profile-locale"/);
  assert.match(js,/playerDataService\.saveMyProfile/);
  assert.match(js,/verifiedProfileReady/);
  assert.match(js,/devAuth\.supabaseUrl/);
  for (const screen of ['sign-in','register','forgot','reset','verify','worlds']) {
    assert.ok(html.includes('data-panel="'+screen+'"'));
  }
  assert.ok(js.includes('if (!PUBLIC_AUTH_ENABLED) return;'));
  assert.ok(js.includes('displayScreen(screen); // scrubs auth material immediately'));
  assert.match(css,/\.auth-feedback/);
  for (const file of ['account.html','account.css','account.js',
                      'auth-rules.mjs','auth-service.mjs','recovery-intent.mjs','auth-client.mjs',
                       'player-data-service.mjs','onboarding-api-client.mjs']) {
    assert.ok(build.includes("'"+file+"'"), 'missing build asset '+file);
  }
  assert.match(server,/\.mjs.*text\/javascript/);
  assert.ok(pkg.scripts.test.includes('test_account_foundation.mjs'));
});

test('SQL draft is private-by-default and seeds no active worlds or bankroll', async () => {
  const sql=await readFile(path.join(root,'docs/sql/airlinerra_game_identity_schema_prelaunch.sql'),'utf8');
  assert.match(sql,/REVIEW ONLY, NOT APPLIED/);
  assert.match(sql,/create schema if not exists airlinerra_game/i);
  assert.match(sql,/enable row level security/g);
  assert.match(sql,/unique \(world_id,owner_player_id\)/);
  assert.match(sql,/to authenticated\s+using \(\(select auth\.uid\(\)\) = user_id/);
  assert.match(sql,/\(1,'Founding World','planned'\)/);
  assert.match(sql,/\(2,'Expansion World','planned'\)/);
  assert.match(sql,/\(3,'Future World','planned'\)/);
  assert.ok(!sql.includes("granted to anon"));
});
