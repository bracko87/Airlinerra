import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
  PLAYER_APP_PATH,PLAYER_VIEWS,WORLD_LABELS,
  safePlayerView,playerViewUrl,verifiedManagerIdentity,onboardingReadiness,
  AIRLINE_CREATION_ENABLED,GAME_READ_API_CONNECTED
} from '../website/player-app-model.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from '../website/tester-dashboard-state.mjs';
import {TESTER_ORIGIN,TESTER_AUTH_URL} from '../website/invited-tester-entry.mjs';

test('player application has complete distinct navigation and bounded hash routes',()=>{
  assert.equal(PLAYER_APP_PATH,'/player.html');
  assert.deepEqual(PLAYER_VIEWS,['overview','onboarding','profile','worlds','airports','fleet','routes','schedule','finances','settings']);
  assert.equal(new Set(PLAYER_VIEWS).size,10);
  assert.equal(safePlayerView('#fleet'),'fleet');
  assert.equal(safePlayerView('#unknown'),'overview');
  assert.equal(safePlayerView('#access_token=do-not-process'),'overview');
  assert.equal(playerViewUrl('profile'),'/player.html#profile');
  assert.equal(playerViewUrl('https://hostile.example'),'/player.html#overview');
  assert.equal(WORLD_LABELS.length,3);
  assert.equal(WORLD_LABELS.every(w=>w.status==='Planned'),true);
});

test('profile is display only and requires verified invitation',()=>{
  const user={id:'111',email:'invited@example.com',email_confirmed_at:'2026-10-28T11:00:00Z',
    created_at:'2026-10-28T10:00:00Z',user_metadata:{display_name:'Captain Example'}};
  assert.deepEqual(verifiedManagerIdentity(user),{
    email:'invited@example.com',name:'Captain Example',joined:'2026-10-28',verified:true
  });
  assert.equal(verifiedManagerIdentity({...user,email_confirmed_at:null}),null);
  assert.equal(verifiedManagerIdentity({...user,is_anonymous:true}),null);
  assert.equal(verifiedManagerIdentity({...user,deleted_at:'2026-10-28T10:00:00Z'}),null);
  assert.equal(verifiedManagerIdentity(null),null);
  assert.equal(verifiedManagerIdentity({...user,user_metadata:{display_name:'<test>'}}).name,'test');
});

test('any provided game context cannot bypass disabled creation/backend gates',()=>{
  assert.equal(AIRLINE_CREATION_ENABLED,false);
  assert.equal(GAME_READ_API_CONNECTED,false);
  assert.equal(onboardingReadiness().canCreate,false);
  assert.equal(onboardingReadiness({
    gate:true,legal:{published:true},
    worlds:[{state:'registration_open'}],airports:[{key:'OURAIRPORTS:1'}]
  }).canCreate,false);
});

test('guarded player route requires live confirmed user, not just a static HTML page',async()=>{
  const key='sb_publishable_'+('C'.repeat(32));
  const config={operatorPrelaunchApproved:true,supabaseUrl:TESTER_AUTH_URL,publishableKey:key};
  let checks=0;
  const open=path=>openPrivateTesterDashboard({
    origin:TESTER_ORIGIN,pathname:path,config,
    inspectProvider:async()=>{checks++;},
    createAuth:async()=>({getUser:async()=>({id:'verified',email:'verified@example.com',email_confirmed_at:'today'}),signOut:async()=>{}})
  });
  assert.equal((await open('/player.html')).user.email,'verified@example.com');
  assert.equal(checks,1);
  await assert.rejects(open('/unsafe.html'),PrivateTesterAccessDenied);
  assert.equal(checks,1);
});

test('player page and build surface contain no write routes or exposed credentials',async()=>{
  const read=p=>readFile(new URL(p,import.meta.url),'utf8');
  const [html,js,overlay]=await Promise.all([
    read('../website/private-player-app.html'),
    read('../website/player-app.mjs'),
    read('../website/dev-scripts/invited-overlay.mjs')
  ]);
  assert.match(html,/id="player-app" hidden/);
  for(const view of PLAYER_VIEWS)assert.match(html,new RegExp('data-player-view="'+view+'"'));
  assert.match(html,/setup-country/);
  assert.match(html,/setup-airport/);
  assert.match(html,/setup-airline-name/);
  assert.match(html,/disabled>Create airline/);
  assert.match(js,/openPrivateTesterDashboard/);
  assert.match(js,/Local visual preview|local-preview-note/);
  assert.doesNotMatch(js,/signUp\(|updateUser\(|createAirline\(|\.from\(|service_role|sb_secret_|fetch\(/);
  assert.match(overlay,/private-player-app\.html/);
  assert.match(overlay,/player-app-model\.mjs/);
});
