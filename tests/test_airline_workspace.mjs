import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRLINE_UI_DEFAULTS,AIRLINE_UI_VIEWS,cleanUiPreferences,financialScenario,validateRouteIdea} from '../website/airline-workspace.mjs';
import {PLAYER_VIEWS} from '../website/player-app-model.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('expanded management pages and operations/settings navigation stay linked',async()=>{
 const html=await read('../website/private-player-app.html');
 assert.equal(PLAYER_VIEWS.length,48);
 assert.equal(new Set(PLAYER_VIEWS).size,PLAYER_VIEWS.length);
 for(const page of PLAYER_VIEWS)
  assert.match(html,new RegExp('data-player-view="'+page+'"'));
 // Aircraft profile and Route Details open contextually; neither needs a navigation item.
 assert.equal([...html.slice(html.indexOf('<nav class="app-navigation"'),html.indexOf('</nav>')+6).matchAll(/data-view-link="([^"]+)"/g)].length,PLAYER_VIEWS.length-4);
 assert.ok(html.indexOf('>Dashboard</a>')<html.indexOf('data-nav-group="operations"'));
 assert.match(html,/href="#holding" data-view-link="holding">Holding/);
 assert.doesNotMatch(html,/data-nav-group="manager"/);
 const operations=html.slice(html.indexOf('data-nav-group="operations"'),html.indexOf('data-nav-group="fleet"'));
 for(const name of ['routes','route-list','hubs','schedule','service','cabin-configurations'])
  assert.match(operations,new RegExp('data-view-link="'+name+'"'));
 assert.doesNotMatch(operations,/data-view-link="staff"|data-view-link="worlds"|data-view-link="airports"|data-view-link="tickets"/);
 const employees=html.slice(html.indexOf('data-nav-group="employees"'),html.indexOf('data-nav-group="marketing"'));
 assert.match(employees,/data-view-link="staff"/);
 const statistics=html.slice(html.indexOf('data-nav-group="statistics"'),html.indexOf('data-nav-group="account"'));
 assert.match(statistics,/data-view-link="rankings"/);
 const settings=html.slice(html.indexOf('data-nav-group="settings"'),html.indexOf('</nav>'));
 for(const name of ['airline','profile','worlds','airports','settings','interface','notifications','help'])
  assert.match(settings,new RegExp('data-view-link="'+name+'"'));
 assert.doesNotMatch(settings,/data-view-link="rankings"/);
 assert.equal(new Set(AIRLINE_UI_VIEWS).size,AIRLINE_UI_VIEWS.length);
});

test('real connected views remain while 16 richer section mounts render',async()=>{
 const [html,js,overlay,workspace]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),read('../website/airline-workspace.mjs')
 ]);
 for(const view of ['fleet','routes','schedule','finances','worlds','airport-insights',
  'airline','staff','rankings','service','aircraft-new-orders','aircraft-market','maintenance',
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

test('cabin service startup mounts its host before manager initialization and cannot block account access',async()=>{
 const [workspace,html,overlay]=await Promise.all([
  read('../website/airline-workspace.mjs'),
  read('../website/private-player-app.html'),
  read('../website/dev-scripts/invited-overlay.mjs')
 ]);
 const render=workspace.indexOf('for(const [name,render] of Object.entries(pages))');
 const cabin=workspace.indexOf('cabinManager=createCabinServiceManager(');
 assert.ok(render>=0&&cabin>render,'Cabin manager must start AFTER workspace markup renders');
 assert.match(workspace,/const cabinHost=\$\('cabin-services-manager'\)/);
 assert.match(workspace,/if\(cabinHost\)\{/);
 assert.match(workspace,/cabinManager\?\.updateData\(data\)/);
 assert.match(workspace,/Airlinerra cabin service interface unavailable/);
 assert.match(workspace,/id="cabin-services-manager"/);
 assert.match(html,/id="workspace-service"/);
 assert.match(overlay,/'cabin-services-manager\.mjs'/);
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

test('settings and local hypothetical briefs remain separate from owner-scoped planning routes',async()=>{
 const [workspace,html,model,client]=await Promise.all([
  read('../website/airline-workspace.mjs'),read('../website/private-player-app.html'),
  read('../website/player-app-model.mjs'),read('../website/player-read-client.mjs')
 ]);
 assert.match(workspace,/const DRAFT_KEY='airlinerra.local.workplan.v1.'/);
 assert.match(workspace,/const PREF_KEY='airlinerra.ui.preferences.v1.'/);
 assert.match(workspace,/getLandingView:\(\)=>preferences.landing/);
 assert.doesNotMatch(workspace,/YOUR PROCUREMENT PLAN|Simulation aircraft|Save local fleet brief/);
 assert.match(workspace,/fleet-owned-aircraft/);
 assert.match(workspace,/id="fleet-detail-nickname"/);
  assert.ok(workspace.includes('id="fleet-maintenance-preview"')||
    workspace.includes('id=\\\"fleet-maintenance-preview\\\"'));
 assert.match(workspace,/loadMaintenancePreview/);
 assert.match(workspace,/Maintenance data loading/);
 assert.match(workspace,/canScheduleMaintenance!==false/);
 assert.match(workspace,/Base game cost/);
 assert.match(workspace,/data-fleet-aircraft-open/);
 assert.match(workspace,/Location not verified/);
 assert.match(workspace,/fleet-detail-save/);
 assert.match(html,/data-player-view="fleet-aircraft"/);
 assert.match(workspace,/No live route was created/);
 assert.match(workspace,/Booked flights only/);
 assert.doesNotMatch(workspace,/schedule-board-legend|Departure only:/);
 assert.match(workspace,/cabinConfigurationManager\?\.updateData\(data\)/);
 assert.match(workspace,/factory-cabin-customizer/);
 assert.match(workspace,/Maintenance cycle/);
 assert.match(workspace,/fleet-owned-aircraft/);
 assert.match(workspace,/id=\\?"market-acquire\\?"/);
 assert.match(workspace,/role="status"/);
 assert.match(workspace,/id="schedule-aircraft-board"/);
 assert.match(workspace,/buildAirlineWeeklyBoard/);
 assert.match(workspace,/renderAirlineWeeklyBoard/);
 assert.doesNotMatch(workspace,/plans:scheduleSnapshot\?\.plans/);
 assert.match(workspace,/scheduleSnapshot\?\.drafts/);
 assert.match(workspace,/cabin-configuration-manager/);
 assert.match(workspace,/mro-directory/);
 assert.match(html,/data-player-view="cabin-configurations"/);
 assert.match(workspace,/Account verification and recovery/);
 assert.match(html,/settings-timezone/);
 assert.match(model,/AIRLINE_CREATION_ENABLED=false/);
 assert.match(client,/PLAYER_READ_API_ENABLED=false/);
});


test('Manage airline replaces membership and strategy with one owner-scoped logo editor and planned public page',async()=>{
 const [html,workspace,css,app]=await Promise.all([
  read('../website/private-player-app.html'),
  read('../website/airline-workspace.mjs'),
  read('../website/player-app.css'),
  read('../website/player-app.mjs')
 ]);
 assert.match(html,/data-view-link="airline">Manage airline<\/a>/);
 assert.match(html,/<h1>Manage airline<\/h1>/);
 const start=workspace.indexOf("'airline':()=>card('Company identity'");
 const end=workspace.indexOf("'fleet':()=>",start);
 assert.ok(start>=0&&end>start);
 const page=workspace.slice(start,end);
 assert.ok(!page.includes('<span>Membership</span>'));
 assert.ok(!page.includes('Build your company'));
 assert.ok(!page.includes('STRATEGY'));
 assert.match(page,/id="manage-airline-logo-file"/);
 assert.match(page,/id="manage-airline-logo-save" disabled/);
 assert.match(page,/id="manage-airline-logo-preview"/);
 assert.match(page,/Public airline presentation/);
 assert.match(page,/This editor is not active yet/);
 assert.match(page,/name, ICAO\/IATA codes and home airport remain fixed/);
 assert.match(app,/auth\.uploadAirlineLogo\(\{airlineId:id,blob:manageLogoBlob\}\)/);
 assert.match(app,/clearManageLogoSelection\(\)/);
 assert.match(app,/operationsController\?\.refreshAirlineLogo\?\.\(\)/);
 assert.match(css,/\.manage-airline-logo-layout\{display:grid/);
});
test('Manage account uses a full-width editable private profile with secure password reset flow',async()=>{
 const [html,app,css]=await Promise.all([
  read('../website/private-player-app.html'),
  read('../website/player-app.mjs'),
  read('../website/player-app.css')
 ]);
 assert.match(html,/data-view-link="profile">Manage account<\/a>/);
 const start=html.indexOf('data-player-view="profile"'),end=html.indexOf('data-player-view="worlds"',start);
 assert.ok(start>=0&&end>start);
 const page=html.slice(start,end);
 assert.match(page,/class="panel manager-account-panel"/);
 assert.doesNotMatch(page,/class="panel narrow"/);
 assert.doesNotMatch(page,/profile-avatar/);
 assert.match(page,/id="manager-profile-form"/);
 for(const id of ['manager-name','manager-hometown','manager-country','manager-email',
  'manager-joined','manager-change-password','manager-save'])assert.ok(page.includes('id="'+id+'"'),id);
 assert.match(page,/Hometown and country are optional and private/);
 assert.match(app,/auth\.updateManagerProfile\(/);
 assert.match(app,/auth\.requestPasswordReset\(user\.email\)/);
 assert.match(css,/#player-main \.manager-account-panel\{width:100%;max-width:none\}/);
});
