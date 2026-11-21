import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AIRLINERRA_WORLD_NAMES,worldDisplayName,normalizeDashboardLedger,dashboardMoney,renderPassengerReputation} from '../website/airline-dashboard.mjs';
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

test('passenger reputation uses measured data and never invents satisfaction for a new airline',()=>{
 const ids=['dashboard-reputation','dashboard-satisfaction','dashboard-experience-count','dashboard-reputation-demand','dashboard-reputation-note','dashboard-reputation-meter'];
 const nodes=Object.fromEntries(ids.map(id=>[id,{}]));
 const doc={getElementById:id=>nodes[id]||null};
 renderPassengerReputation(doc,{passengerReputation:{reputation:70,averageSatisfaction:null,passengerExperiences:0,demandEffectEnabled:false,potentialDemandMultiplier:1}});
 assert.equal(nodes['dashboard-reputation'].textContent,'70 / 100');
 assert.equal(nodes['dashboard-satisfaction'].textContent,'No experiences yet');
 assert.equal(nodes['dashboard-reputation-demand'].textContent,'Not activated');
 assert.equal(nodes['dashboard-reputation-meter'].value,70);
 renderPassengerReputation(doc,{passengerReputation:{reputation:90,averageSatisfaction:92.5,passengerExperiences:2000,demandEffectEnabled:true,potentialDemandMultiplier:1.1}});
 assert.equal(nodes['dashboard-satisfaction'].textContent,'92.5 / 100');
 assert.equal(nodes['dashboard-experience-count'].textContent,'2,000');
 assert.equal(nodes['dashboard-reputation-demand'].textContent,'+10%');
 renderPassengerReputation(doc,{passengerReputation:{reputation:40,averageSatisfaction:25,passengerExperiences:1000,demandEffectEnabled:true,potentialDemandMultiplier:0.85}});
 assert.equal(nodes['dashboard-reputation-demand'].textContent,'-15%');
 renderPassengerReputation(doc,null);
 assert.equal(nodes['dashboard-reputation'].textContent,'Not available');
 assert.equal(nodes['dashboard-satisfaction'].textContent,'Not available');
 assert.equal(nodes['dashboard-reputation-meter'].hidden,true);
 assert.match(PLAYER_READ_SQL.airlines,/section9_airline_reputation_v1\(a\.id\)/);
 assert.match(PLAYER_READ_SQL.airlines,/a\.owner_player_id=\$1::uuid/);
});
