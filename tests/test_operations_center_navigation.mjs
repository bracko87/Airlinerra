import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {STAFF_DEPARTMENTS,payrollEstimate,ticketRevenueEstimate} from '../website/airline-operations-center.mjs';
import {PLAYER_VIEWS} from '../website/player-app-model.mjs';
import {verifiedCashMix,operatingMonthlyPoints} from '../website/airline-finance-charts.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');
test('all requested airline operation views navigate without a Manager dropdown',async()=>{
 const [html,model,app,overlay]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app-model.mjs'),
  read('../website/player-app.mjs'),read('../website/dev-scripts/invited-overlay.mjs')]);
 assert.equal(PLAYER_VIEWS.length,22);
 const ops=html.slice(html.indexOf('data-nav-group="operations"'),html.indexOf('data-nav-group="fleet"'));
 for(const view of ['routes','route-list','hubs','schedule','service','tickets','staff']){
  assert.match(ops,new RegExp('data-view-link="'+view+'"'));
  assert.match(html,new RegExp('data-player-view="'+view+'"'));
 }
 assert.doesNotMatch(ops,/data-view-link="worlds"|data-view-link="airports"/);
 assert.doesNotMatch(html,/data-nav-group="manager"/);
 const settings=html.slice(html.indexOf('data-nav-group="settings"'),html.indexOf('</nav>'));
 for(const view of ['worlds','airports','airline','profile'])assert.match(settings,new RegExp('data-view-link="'+view+'"'));
 assert.match(app,/createOperationsCenter/);
 assert.match(app,/operationsController\?\.updateData/);
 assert.match(overlay,/'airline-operations-center.mjs'/);
 assert.match(model,/'route-list','hubs','tickets'/);
});
test('current flights full width below authentic company news; cash uses game-colored donut',async()=>{
 const [html,css,finance,dashboard]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.css'),
  read('../website/airline-finance-charts.mjs'),read('../website/airline-dashboard.mjs')]);
 const view=html.split('<section data-player-view="overview">')[1].split('<section data-player-view="onboarding"')[0];
 const top=view.indexOf('dashboard-news-panel'),flights=view.indexOf('dashboard-full-flights');
 const graph=view.indexOf('dashboard-bottom-grid');
 assert.ok(top>=0&&flights>top&&graph>flights);
 assert.match(view,/id="dashboard-news-items"/);
 assert.match(view,/id="dashboard-flights-body"/);
 assert.match(view,/id="dashboard-cash-chart"/);
 assert.match(css,/dashboard-flights-full/);
 assert.match(css,/dashboard-donut-chart/);
 assert.match(finance,/stroke:'#ff6917'/);
 assert.match(finance,/stroke:'#092b57'/);
 assert.match(dashboard,/renderCompanyNews\(doc,airline,worlds,ledgerEntries\)/);
 assert.doesNotMatch(css,/\.nav-links a\[aria-current="page"\]\{[^}]*inset 3px 0 var\(--orange\)/);
});
test('financial donut only reports verifiable cash and known costs',()=>{
 const entries=[{kind:'STARTING_CAPITAL',amountUsd:'5000000.00',recordedAt:'2026-10-29T08:12:26Z'}];
 assert.deepEqual(verifiedCashMix('5000000.00',entries),
  {balance:5000000,costs:0,total:5000000,cashShare:1});
 assert.equal(verifiedCashMix(null,entries),null);
 assert.deepEqual(operatingMonthlyPoints(entries),[]);
 const extra=[...entries,{kind:'FUEL_COST',amountUsd:'-200',recordedAt:'2026-10-29T17:00:00Z'}];
 assert.equal(verifiedCashMix('4999800',extra).costs,200);
});
test('staff structure includes executive board, crew, engineering, ground, support with editable salary plan',async()=>{
 assert.ok(Object.keys(STAFF_DEPARTMENTS).length>=6);
 for(const group of ['Board and Executive','Flight Operations','Cabin Services','Maintenance and Engineering','Ground and Hub Operations','Commercial and Support'])
  assert.ok(STAFF_DEPARTMENTS[group]?.length>=3);
 const roles=Object.values(STAFF_DEPARTMENTS).flat();
 assert.ok(roles.length>=30);
 assert.ok(roles.some(([title])=>title==='Captain'));
 assert.ok(roles.some(([title])=>title==='Chief Executive Officer'));
 assert.deepEqual(payrollEstimate([{count:2,salary:6000},{count:3,salary:3000}]),{people:5,monthly:21000,yearly:252000});
 assert.equal(payrollEstimate([{count:-2,salary:1000}]),null);
 assert.deepEqual(ticketRevenueEstimate({seats:100,occupancy:80,price:200,flights:7,cost:5000}),
  {passengers:560,revenue:112000,costs:35000,net:77000});
 assert.equal(ticketRevenueEstimate({seats:100,occupancy:140,price:200,flights:7,cost:5000}),null);
 const workspace=await read('../website/airline-workspace.mjs');
 assert.match(workspace,/airlinerra:route-draft-saved/);
 assert.match(workspace,/freshest=safelyLoad\(session,draftKey\)/);
});
