import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRLINERRA_WORLD_NAMES,worldDisplayName,normalizeDashboardLedger,dashboardMoney} from '../website/airline-dashboard.mjs';
import {PLAYER_READ_SQL} from '../server/player-read-service.mjs';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
test('all worlds have human-readable names without changing IDs or availability',()=>{
 assert.deepEqual(Object.values(AIRLINERRA_WORLD_NAMES),['Horizon','Atlas','Odyssey']);
 assert.equal(worldDisplayName(1,[{id:1,name:'Horizon'}]),'Horizon');
 assert.equal(worldDisplayName(2),'Atlas');
});
test('finance activity can show real starting capital while absent statistics remain unavailable',()=>{
 assert.equal(dashboardMoney('5000000.00'),'$5,000,000');
 assert.deepEqual(normalizeDashboardLedger([{kind:'STARTING_CAPITAL',amountUsd:'5000000.00',recordedAt:'2026-10-29T08:12:26Z'}])[0].kind,'STARTING_CAPITAL');
 assert.equal(normalizeDashboardLedger(undefined),null);
 assert.equal(normalizeDashboardLedger([{kind:'BAD',amountUsd:'NaN',recordedAt:'yesterday'}]).length,0);
 assert.match(PLAYER_READ_SQL.ledger,/where airline_id=\$1::uuid/);
 assert.match(PLAYER_READ_SQL.ledger,/limit 5/);
 assert.doesNotMatch(PLAYER_READ_SQL.ledger,/\bupdate\b|\binsert\b/i);
});
test('overview no longer has onboarding checklist or command-center navigation card',async()=>{
 const [html,app,workspace,build]=await Promise.all([read('../website/private-player-app.html'),
  read('../website/player-app.mjs'),read('../website/airline-workspace.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs')]);
 const section=html.slice(html.indexOf('<section data-player-view="overview">'),html.indexOf('<section data-player-view="onboarding"'));
 for(const text of ['NEXT STEPS','GET STARTED','MANAGEMENT OVERVIEW','Your airline command center',
  'id="overview-progress-title"','id="workspace-overview"'])assert.ok(!section.includes(text),text);
 for(const id of ['dashboard-flights-body','dashboard-passengers','dashboard-cargo','dashboard-served-airports',
  'dashboard-active-routes','dashboard-completed-flights','dashboard-finance-cash','dashboard-cash-chart','dashboard-income-chart','dashboard-insights-items'])
  assert.ok(section.includes('id="'+id+'"'),id);
 assert.match(app,/renderAirlineDashboard\(doc,\{airline:first/);
 assert.match(build,/'airline-dashboard.mjs'/);
 assert.match(build,/'airline-finance-charts.mjs'/);
 assert.doesNotMatch(section,/Notifications and company news/);
 assert.doesNotMatch(workspace,/Your airline command center/);
});
