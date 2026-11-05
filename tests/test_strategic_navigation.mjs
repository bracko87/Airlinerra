import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PLAYER_VIEWS,safePlayerView} from '../website/player-app-model.mjs';

const read=path=>readFile(new URL(path,import.meta.url),'utf8');
const segment=(html,id,next)=>html.slice(html.indexOf('data-nav-group="'+id+'"'),next?html.indexOf('data-nav-group="'+next+'"'):html.indexOf('</nav>'));

test('all 43 player routes map to exactly one real section',async()=>{
 const html=await read('../website/private-player-app.html');
 const views=[...html.matchAll(/data-player-view="([^"]+)"/g)].map(x=>x[1]);
 assert.equal(PLAYER_VIEWS.length,43);
 assert.equal(new Set(PLAYER_VIEWS).size,43);
 assert.deepEqual([...views].sort(),[...PLAYER_VIEWS].sort());
 for(const route of PLAYER_VIEWS)assert.equal(safePlayerView('#'+route),route);
});

test('Holding is visible but locked and does not link to company creation',async()=>{
 const html=await read('../website/private-player-app.html');
 const nav=html.split('</nav>')[0];
 assert.match(nav,/class="nav-direct nav-disabled" aria-disabled="true"[^>]*>Holding/);
 assert.doesNotMatch(nav,/href="#holding"/);
 assert.match(html,/at least 60 in-game days/i);
 const holding=html.split('data-player-view="holding"')[1].split('</section>')[0];
 assert.match(holding,/No company can be created or charged|no company can be created or charged/i);
 assert.doesNotMatch(holding,/<button|<input|<form/);
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

test('aircraft illustration is lowered and internal release warning removed',async()=>{
 const [css,js]=await Promise.all([read('../website/aircraft-library.css'),read('../website/aircraft-library.mjs')]);
 assert.match(css,/translateY\(44px\) scale\(\.90\)/);
 assert.match(css,/library-fleet-count\{font-size:12px;font-weight:400/);
 assert.doesNotMatch(js,/Operating restriction: /);
 assert.match(js,/library-fleet-count/);
 assert.match(js,/noiseChapter/);
});

test('new menu remains accessible and responsive',async()=>{
 const [html,css]=await Promise.all([read('../website/private-player-app.html'),read('../website/player-app.css')]);
 assert.match(html,/<nav class="app-navigation" aria-label="Player application">/);
 assert.match(css,/\.planning-page-grid/);
 assert.match(css,/@media\(max-width:850px\)/);
 assert.match(css,/\.nav-locked-label/);
 assert.doesNotMatch(html,/data-nav-group="manager"/);
});
