import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRLINE_UI_DEFAULTS,AIRLINE_UI_VIEWS,cleanUiPreferences,financialScenario,validateRouteIdea} from '../website/airline-workspace.mjs';
import {PLAYER_VIEWS} from '../website/player-app-model.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('19 safe management pages and dedicated settings menu stay linked',async()=>{
 const html=await read('../website/private-player-app.html');
 assert.equal(PLAYER_VIEWS.length,19);
 assert.equal(new Set(PLAYER_VIEWS).size,19);
 for(const page of PLAYER_VIEWS)
  assert.match(html,new RegExp('data-player-view="'+page+'"'));
 assert.equal([...html.matchAll(/data-view-link="([^"]+)"/g)].length,19);
 assert.ok(html.indexOf('>Dashboard</a>')<html.indexOf('data-nav-group="manager"'));
 const manager=html.slice(html.indexOf('data-nav-group="manager"'),html.indexOf('data-nav-group="operations"'));
 assert.doesNotMatch(manager,/data-view-link="overview"/);
 const settings=html.slice(html.indexOf('data-nav-group="settings"'),html.indexOf('</nav>'));
 for(const name of ['settings','interface','notifications','help'])
  assert.match(settings,new RegExp('data-view-link="'+name+'"'));
 assert.equal(new Set(AIRLINE_UI_VIEWS).size,17);
});

test('real connected views remain while 16 richer section mounts render',async()=>{
 const [html,js,overlay,workspace]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),read('../website/airline-workspace.mjs')
 ]);
 for(const view of ['overview','fleet','routes','schedule','finances','worlds','airport-insights',
  'airline','staff','rankings','service','aircraft-market','maintenance',
  'interface','notifications','help'])
  assert.match(html,new RegExp('id="workspace-'+view+'"'));
 assert.match(html,/id="world-directory"/);
 assert.match(html,/id="airport-results"/);
 assert.match(js,/createAirlineWorkspace/);
 assert.match(js,/workspaceController\?\.updateData/);
 assert.match(js,/getLandingView\(\)/);
 assert.match(overlay,/'airline-workspace.mjs'/);
 assert.doesNotMatch(workspace,/\.auth\.signUp|service_role|sb_secret_|fetch\(/);
});

test('settings validate choices and refuse unimplemented language and notification control',()=>{
 assert.deepEqual(cleanUiPreferences(null),AIRLINE_UI_DEFAULTS);
 const pref=cleanUiPreferences({units:'mi',time:'12',landing:'routes',density:'compact',
  theme:'dark',motion:'reduced',language:'de',unexpected:'unsafe',hints:false});
 assert.equal(pref.units,'mi');
 assert.equal(pref.time,'12');
 assert.equal(pref.landing,'routes');
 assert.equal(pref.theme,'dark');
 assert.equal(pref.density,'compact');
 assert.equal(pref.motion,'reduced');
 assert.equal(pref.language,'en');
 assert.equal(pref.hints,false);
 assert.equal('unexpected' in pref,false);
 assert.equal(Object.isFrozen(pref),true);
});

test('monthly scenario is user-provided only and does not mutate the game ledger',()=>{
 const positive=financialScenario({revenue:100000,leases:10000,crew:20000,fuel:15000,
  maintenance:5000,airportFees:10000,services:2000,marketing:3000,cash:5000000});
 assert.equal(positive.income,100000);
 assert.equal(positive.expenses,65000);
 assert.equal(positive.net,35000);
 assert.equal(positive.months,null);
 const deficit=financialScenario({revenue:0,leases:100000,crew:100000,cash:5000000});
 assert.equal(deficit.net,-200000);
 assert.equal(deficit.months,25);
 assert.equal(financialScenario({revenue:-5,leases:Infinity,cash:0}).expenses,0);
});

test('route draft cannot use identical or missing airports and never launches a flight',()=>{
 const a={key:'OURAIRPORTS:4610'},b={key:'OURAIRPORTS:4614'};
 assert.equal(validateRouteIdea({from:a,to:b,flights:7}),true);
 assert.equal(validateRouteIdea({from:a,to:a,flights:7}),false);
 assert.equal(validateRouteIdea({from:a,to:b,flights:0}),false);
 assert.equal(validateRouteIdea({from:a,to:b,flights:29}),false);
 assert.equal(validateRouteIdea({from:null,to:b,flights:7}),false);
});

test('settings and planning work remain local drafts until server-side execution exists',async()=>{
 const [workspace,html,model,client]=await Promise.all([
  read('../website/airline-workspace.mjs'),read('../website/private-player-app.html'),
  read('../website/player-app-model.mjs'),read('../website/player-read-client.mjs')
 ]);
 assert.match(workspace,/const DRAFT_KEY='airlinerra.local.workplan.v1.'/);
 assert.match(workspace,/const PREF_KEY='airlinerra.ui.preferences.v1.'/);
 assert.match(workspace,/getLandingView:\(\)=>preferences.landing/);
 assert.match(workspace,/No aircraft was ordered/);
 assert.match(workspace,/No live route was created/);
 assert.match(workspace,/No flight was scheduled with the server/);
 assert.match(workspace,/No aircraft layout was changed/);
 assert.match(workspace,/No authenticated aircraft-inventory endpoint/);
 assert.match(workspace,/role="status"/);
 assert.match(workspace,/id="schedule-hours"/);
 assert.match(workspace,/for\(let hour=0;hour<24;hour\+\+\)/);
 assert.match(workspace,/for\(let day=0;day<7;day\+\+\)/);
 assert.match(workspace,/cabin-economy/);
 assert.match(workspace,/cabin-premium/);
 assert.match(workspace,/cabin-business/);
 assert.match(workspace,/cabin-first/);
 assert.match(workspace,/Account verification and recovery/);
 assert.match(html,/settings-timezone/);
 assert.match(model,/AIRLINE_CREATION_ENABLED=false/);
 assert.match(client,/PLAYER_READ_API_ENABLED=false/);
});
