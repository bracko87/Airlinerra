import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
  PLAYER_APP_PATH,PLAYER_VIEWS,WORLD_LABELS,
  safePlayerView,playerViewUrl,verifiedManagerIdentity,onboardingReadiness,managerLandingView,
  AIRLINE_CREATION_ENABLED,GAME_READ_API_CONNECTED
} from '../website/player-app-model.mjs';
import {openPrivateTesterDashboard,PrivateTesterAccessDenied} from '../website/tester-dashboard-state.mjs';
import {TESTER_ORIGIN,TESTER_AUTH_URL} from '../website/invited-tester-entry.mjs';

test('player application has complete distinct navigation and bounded hash routes',()=>{
  assert.equal(PLAYER_APP_PATH,'/player.html');
  assert.deepEqual(PLAYER_VIEWS,['overview','onboarding','profile','worlds','airports','fleet','routes','schedule','finances','settings','airline','staff','rankings','service','aircraft-market','maintenance','interface','notifications','help']);
  assert.equal(new Set(PLAYER_VIEWS).size,19);
  assert.equal(safePlayerView('#fleet'),'fleet');
  assert.equal(safePlayerView('#unknown'),'overview');
  assert.equal(safePlayerView('#access_token=do-not-process'),'overview');
  assert.equal(playerViewUrl('profile'),'/player.html#profile');
  assert.equal(playerViewUrl('https://hostile.example'),'/player.html#overview');
  assert.equal(WORLD_LABELS.length,3);
  assert.deepEqual(WORLD_LABELS.map(w=>w.name),['Horizon','Atlas','Odyssey']);
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
  assert.match(html,/disabled>Create my airline/);
  assert.match(js,/openPrivateTesterDashboard/);
  assert.match(js,/local-preview-note/);
  assert.match(js,/\.createAirline\(/);
  assert.match(js,/\.acceptLegal\(/);
  assert.doesNotMatch(js,/signUp\(|updateUser\(|\.from\(|service_role|sb_secret_|fetch\(/);
  assert.match(overlay,/private-player-app\.html/);
  assert.match(overlay,/player-app-model\.mjs/);
});

test('grouped horizontal dropdowns keep all ten game routes accessible',async()=>{
  const [html,css]=await Promise.all([
    readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8'),
    readFile(new URL('../website/player-app.css',import.meta.url),'utf8')
  ]);
  assert.match(html,/<nav class="app-navigation" aria-label="Player application">/);
  assert.doesNotMatch(html,/class="sidebar"/);
  const order=['manager','operations','fleet','finance','account','settings'];
  const expected={manager:['airline','onboarding','profile','staff','rankings'],operations:['worlds','airports','routes','schedule','service'],
    fleet:['fleet','aircraft-market','maintenance'],finance:['finances'],account:[],
    settings:['settings','interface','notifications','help']};
  const dashboard='<a class="nav-direct" href="#overview" data-view-link="overview">Dashboard</a>';
  assert.ok(html.includes(dashboard),'Dashboard is a separate first navigation link');
  assert.ok(html.indexOf(dashboard)<html.indexOf('data-nav-group="manager"'));
  assert.equal([...html.matchAll(/data-view-link="overview"/g)].length,1);
  const indexes=order.map(name=>html.indexOf('data-nav-group="'+name+'"'));
  assert.ok(indexes.every((n,i)=>n>=0&&(i===0||n>indexes[i-1])));
  for(let i=0;i<order.length;i++){
    const segment=html.slice(indexes[i],i+1<order.length?indexes[i+1]:html.indexOf('</nav>',indexes[i]));
    assert.match(segment,/<summary class="nav-label">/);
    assert.match(segment,/class="chevron"/);
    assert.deepEqual([...segment.matchAll(/data-view-link="([^"]+)"/g)].map(x=>x[1]),expected[order[i]]);
  }
  assert.equal([...html.matchAll(/data-view-link="([^"]+)"/g)].length,PLAYER_VIEWS.length);
  assert.match(css,/\.app-navigation-inner\{[^}]*overflow:visible;/);
  assert.match(css,/\.nav-links a\[aria-current="page"\]/);
  assert.match(css,/#player-main\{max-width:1540px;/);
  assert.match(html,/href="\/tester.html"/);
  assert.match(html,/href="\/"[^>]*>Public website<\/a>/);
  assert.match(html,/id="player-sign-out"/);
});

test('real account onboarding does not re-open creation for an existing airline',async()=>{
 const js=await readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8');
 assert.match(js,/hasRealAirline=Boolean\(first\?\.name\)/);
 assert.match(js,/if\(hasRealAirline\)\{/);
 assert.match(js,/Your real airline already exists/);
 assert.match(js,/new Intl\.DisplayNames\(\['en'\],\{type:'region'\}\)/);
});

test('verified first-time account routes to real setup while a returning airline retains its dashboard',async()=>{
 const js=await readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8');
 assert.match(js,/managerLandingView\(\{requestedView:'onboarding',hasAirline:hasRealAirline\}\)/);
 assert.match(js,/navigateTo\('onboarding'\)/);
 assert.match(js,/if\(hasRealAirline\)\{/);
 assert.match(js,/Your real airline already exists/);
 assert.doesNotMatch(js,/if\(!local&&\(!auth\|\|!PLAYER_READ_API_ENABLED\)\)return/);
});

test('real airline persists visibly in dashboard header while no-airline users are directed to onboarding',async()=>{
 const [html,js]=await Promise.all([
  readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8'),
  readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8')
 ]);
 assert.match(html,/id="top-world"/);
 assert.match(html,/id="top-airline-state"/);
 assert.match(js,/first\.premiumUnlimited===true/);
 assert.match(js,/Premium Unlimited/);
 assert.match(js,/Registered airline/);
 assert.match(js,/renderOverviewState\(hasRealAirline\)/);
 assert.match(js,/doc\.getElementById\('player-cash'\)\.textContent=formatWholeUsd\(first\.cashUsd\)/);
 assert.match(js,/managerLandingView\(\{requestedView:'onboarding',hasAirline:hasRealAirline\}\)/);
});

test('real dashboard displays complimentary unlimited membership only when server confirms it',async()=>{
 const js=await readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8');
 assert.match(js,/first.premiumUnlimited===true/);
 assert.match(js,/Premium Unlimited/);
});
