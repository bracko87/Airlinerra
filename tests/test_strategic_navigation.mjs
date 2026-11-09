import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PLAYER_VIEWS,safePlayerView} from '../website/player-app-model.mjs';
import {runInNewContext} from 'node:vm';

const read=path=>readFile(new URL(path,import.meta.url),'utf8');
const segment=(html,id,next)=>html.slice(html.indexOf('data-nav-group="'+id+'"'),next?html.indexOf('data-nav-group="'+next+'"'):html.indexOf('</nav>'));

test('all 45 player routes map to exactly one real section',async()=>{
 const html=await read('../website/private-player-app.html');
 const views=[...html.matchAll(/data-player-view="([^"]+)"/g)].map(x=>x[1]);
 assert.equal(PLAYER_VIEWS.length,45);
 assert.equal(new Set(PLAYER_VIEWS).size,45);
 assert.deepEqual([...views].sort(),[...PLAYER_VIEWS].sort());
 for(const route of PLAYER_VIEWS)assert.equal(safePlayerView('#'+route),route);
});

test('Holding page has one full-width registration counter, no costs, and future academy infrastructure',async()=>{
 const html=await read('../website/private-player-app.html');
 const nav=html.split('</nav>')[0];
 assert.match(nav,/<a class="nav-direct" href="#holding" data-view-link="holding">Holding<\/a>/);
 const holding=html.split('data-player-view="holding"')[1].split('</section>')[0];
 assert.match(holding,/60 calendar days after registration/);
 assert.match(holding,/holding-status-full/);
 assert.match(holding,/Earliest eligible date/);
 assert.match(holding,/Days remaining/);
 assert.match(holding,/No flights or daily logins are required/i);
 assert.match(holding,/holding-tracker/);
 assert.match(holding,/holding-tree/);
 assert.match(holding,/Parent holding company/);
 for(const company of ['Original airline','Regional airline','Cargo airline','Maintenance company','Charter / VIP airline'])
  assert.ok(holding.includes(company),'Missing example subsidiary: '+company);
 assert.match(holding,/flight academy — airline infrastructure/i);
 assert.match(holding,/ATO or DTO where applicable/);
 assert.match(holding,/own airline operating licence and AOC required/i);
 assert.match(holding,/Part-145 where applicable/);
 assert.match(holding,/Licences &amp; Permits/);
 assert.match(holding,/registration, subsidiary creation and money transfers are not available yet/i);
 assert.doesNotMatch(holding,/What will it cost\?|holding-cost-list|To be announced|holding-summary-grid|60 completed operating game days/i);
 assert.doesNotMatch(holding,/<button|<input|<form/);
 assert.equal((holding.match(/class="panel planning-panel holding-summary-panel holding-status-full"/g)||[]).length,1);
});

test('staff leaves Operations and Rankings leaves Settings',async()=>{
 const html=await read('../website/private-player-app.html');
 const names=[...html.matchAll(/data-nav-group="([^"]+)"/g)].map(x=>x[1]);
 assert.deepEqual(names,['operations','fleet','infrastructure','employees','marketing','finance','statistics','account','settings']);
 const ops=segment(html,'operations','fleet');
 const employees=segment(html,'employees','marketing');
 const statistics=segment(html,'statistics','account');
 const settings=segment(html,'settings');
 assert.doesNotMatch(ops,/data-view-link="staff"/);
 assert.match(employees,/data-view-link="staff"/);
 assert.match(statistics,/data-view-link="rankings"/);
 assert.doesNotMatch(settings,/data-view-link="rankings"/);
});

test('infrastructure, employees, marketing, statistics have informative non-operational pages',async()=>{
 const html=await read('../website/private-player-app.html');
 for(const part of ['infrastructure','infrastructure-hq','infrastructure-maintenance','infrastructure-facilities',
  'employees-pilots','employees-cabin','employees-ground','employees-technical','employees-board','employees-payroll',
  'marketing-reputation','marketing-campaigns','marketing-research','statistics','statistics-airlines','statistics-airports','statistics-aircraft']){
  const section=html.split('data-player-view="'+part+'"')[1]?.split('</section>')[0];
  assert.ok(section,'Missing '+part);
  assert.match(section,/planning-page-grid/);
  assert.match(section,/planning-state/);
  assert.doesNotMatch(section,/<button|<form|<input/);
 }
 assert.match(html,/50\/100 for a newly created company/);
 assert.match(html,/salary increases and decreases/);
 assert.match(html,/Total flight hours|total flight hours/i);
});

test('aircraft image is fully contained and internal release warning removed',async()=>{
 const [css,js]=await Promise.all([read('../website/aircraft-library.css'),read('../website/aircraft-library.mjs')]);
 assert.match(css,/object-fit:contain;object-position:center center;transform:none/);
 assert.match(css,/\.library-profile-image\{height:380px;min-height:380px/);
 assert.doesNotMatch(css,/object-fit:cover|translateY\(44px\) scale\(\.90\)/);
 assert.match(css,/library-fleet-count\{font-size:12px;font-weight:400/);
 assert.doesNotMatch(js,/Operating restriction: /);
 assert.match(js,/library-fleet-count/);
 assert.match(js,/noiseChapter/);
});

test('Holding tracker is populated from authenticated server registration age',async()=>{
 const [html,js,client,css]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs'),
  read('../website/player-read-client.mjs'),read('../website/player-app.css')
 ]);
 for(const id of ['holding-eligibility-status','holding-days-count','holding-earliest-date','holding-progress-fill'])
  assert.match(html,new RegExp('id="'+id+'"'));
 assert.match(js,/await playerData\.holdingStatus\(\)/);
 assert.match(js,/data\.ageBasis!=='elapsed_calendar_days_since_airline_registration'/);
 assert.match(js,/currentAirline\?\.id!==airlineId/);
 assert.match(js,/row\.registrationOpen!==false/);
 assert.match(js,/row\.earliestDate/);
 assert.match(js,/row\.remainingDays/);
 assert.doesNotMatch(js,/Date\.now\(\)[\s\S]{0,160}holding-earliest-date/);
 assert.match(client,/holdingStatus:\(\)=>post\('\/api\/v1\/player\/holding-status',\{\}\)/);
 assert.match(css,/\.holding-status-full\{/);
 assert.match(css,/@media\(max-width:480px\)\{[\s\S]*?\.holding-tracker-details,\.holding-tree-branches\{grid-template-columns:1fr\}/);
 const section=html.split('data-player-view="holding"')[1].split('</section>')[0];
 assert.doesNotMatch(section,/id="create-holding"|<form|type="submit"/i);
});

test('Licences & Permits page and operations menu remain read-only with no fake grants',async()=>{
 const [html,css,js]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.css'),
  read('../website/player-app.mjs')
 ]);
 const ops=segment(html,'operations','fleet');
 assert.match(ops,/data-view-link="licenses"/);
 assert.equal(ops.match(/data-view-link="licenses"/g)?.length,1);
 assert.match(html,/data-player-view="licenses"/);
 const section=html.split('data-player-view="licenses"')[1].split('</section>')[0];
 assert.match(section,/Reference only/);
 assert.match(section,/licenses-catalog-groups/);
 assert.match(section,/applications are not enabled/);
 assert.doesNotMatch(section,/<button|<input|<form|type="submit"/);
 assert.match(css,/\.license-card-grid\{/);
 assert.match(js,/await playerData\.licenses\(\)/);
 assert.match(js,/No permissions can be assumed/);
 assert.doesNotMatch(js,/from ['"]\.\/license-catalogue/);
});

test('new menu remains accessible and responsive',async()=>{
 const [html,css]=await Promise.all([read('../website/private-player-app.html'),read('../website/player-app.css')]);
 assert.match(html,/<nav class="app-navigation" aria-label="Player application">/);
 assert.match(css,/\.planning-page-grid/);
 assert.match(css,/@media\(max-width:850px\)/);
 assert.match(css,/justify-content:space-between;gap:clamp/);
 assert.match(css,/flex-wrap:nowrap/);
 assert.match(css,/@media\(max-width:1150px\)/);
 assert.doesNotMatch(html,/nav-locked-label|aria-disabled="true"[^>]*>Holding/);
 assert.doesNotMatch(html,/data-nav-group="manager"/);
});


test('Settings dropdown opens leftward and remains inside laptop and mobile viewport',async()=>{
 const [css,js,html]=await Promise.all([
  read('../website/player-app.css'),read('../website/player-app.mjs'),
  read('../website/private-player-app.html')
 ]);
 assert.match(html,/<details class="nav-group" data-nav-group="settings"/);
 assert.match(css,/\.nav-group\[data-nav-group="settings"\]\s*>\s*\.nav-links\s*\{[^}]*left:auto;[^}]*right:0;/);
 assert.match(css,/\.nav-group\[data-nav-group="settings"\]\s*>\s*\.nav-links a\s*\{[^}]*white-space:normal;/);
 assert.match(js,/settingsNavLinks\.getBoundingClientRect\(\)/);
 assert.match(js,/window\.addEventListener\('resize',fitSettingsDropdown\)/);
 assert.doesNotMatch(js,/from ['"]\.\/navigation-menu-geometry\.mjs['"]/,
  'Player must start without a separately downloaded menu-geometry module');
 const start=js.indexOf('function dropdownViewportShift(');
 const end=js.indexOf('\nconst settingsNavGroup=',start);
 assert.ok(start>=0&&end>start,'Missing in-file viewport geometry helper');
 const dropdownViewportShift=runInNewContext('('+js.slice(start,end).trim()+')');
 // A right-anchored Settings menu fits a laptop without shifting.
 assert.equal(dropdownViewportShift({left:1000,right:1264},1280),0);
 // If the navigation wraps near the left, move the dropdown inward.
 assert.equal(dropdownViewportShift({left:-180,right:84},375),192);
 // If the browser becomes narrower, the popup must not create page overflow.
 assert.equal(dropdownViewportShift({left:1030,right:1294},1280),-26);
 // Fixed and mobile-safe menus need no extra movement.
 assert.equal(dropdownViewportShift({left:12,right:276},320),0);
 assert.equal(dropdownViewportShift({left:40,right:260},320),0);
});

