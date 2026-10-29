import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {ledgerBalancePoints,operatingMonthlyPoints} from '../website/airline-finance-charts.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('cash chart uses only actual ledger records and never generates fake history',()=>{
 const only=[{kind:'STARTING_CAPITAL',amountUsd:'5000000.00',recordedAt:'2026-10-29T08:12:26.559Z'}];
 assert.deepEqual(ledgerBalancePoints('5000000.00',only),
  [{time:'2026-10-29T08:12:26.559Z',value:5000000}]);
 assert.deepEqual(ledgerBalancePoints('5000000.00',null),[]);
 assert.deepEqual(ledgerBalancePoints(null,[]),[]);
 assert.deepEqual(operatingMonthlyPoints(only),[]);
 const withActivity=[...only,
  {kind:'TICKET_REVENUE',amountUsd:'1500.00',recordedAt:'2026-10-30T11:00:00.000Z'},
  {kind:'FUEL_COST',amountUsd:'-300.00',recordedAt:'2026-10-30T12:00:00.000Z'},
  {kind:'DONATION',amountUsd:'200.00',recordedAt:'2026-10-30T13:00:00.000Z'}];
 assert.deepEqual(operatingMonthlyPoints(withActivity),
  [{period:'2026-10',income:1500,expense:300}]);
 assert.deepEqual(ledgerBalancePoints('5001400',withActivity).map(x=>x.value),
  [5000000,5001500,5001200,5001400]);
});

test('finance charts and management insights are placed below operations',async()=>{
 const [html,css,js,assets]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.css'),
  read('../website/airline-dashboard.mjs'),read('../website/dev-scripts/invited-overlay.mjs')]);
 const overview=html.split('<section data-player-view="overview">')[1].split('<section data-player-view="onboarding"')[0];
 const operation=overview.indexOf('dashboard-operations-grid');
 const finance=overview.indexOf('dashboard-charts-grid');
 const insights=overview.indexOf('dashboard-insights-panel');
 assert.ok(operation>=0&&finance>operation&&insights>finance);
 assert.ok(overview.includes('dashboard-cash-chart'));
 assert.ok(overview.includes('dashboard-income-chart'));
 assert.ok(overview.includes('dashboard-insights-items'));
 assert.ok(!overview.includes('dashboard-news-items'));
 assert.ok(!overview.includes('dashboard-ledger-activity'));
 for(const section of ['finance-chart-grid','dashboard-insights-grid','dashboard-chart-panel'])
  assert.ok(css.includes(section));
 assert.match(js,/renderFinancialCharts\(doc,\{cash:airline\?\.cashUsd\?\?null,ledgerEntries\}\)/);
 assert.match(assets,/'airline-finance-charts.mjs'/);
});

test('shared footer ships on game, public, registration and legal pages',async()=>{
 const pages=[
  '../website/index.html','../website/register.html','../website/account.html',
  '../website/private-player-app.html','../website/prelaunch-invited-account.html',
  '../website/private-tester-dashboard.html','../website/terms.html',
  '../website/privacy.html','../website/impressum.html','../website/faq.html',
  '../website/pricing.html'
 ];
 for(const path of pages){
  const source=await read(path);
  assert.match(source,/studio-footer\.css/,path);
  assert.match(source,/studio-footer\.js/,path);
  assert.match(source,/<footer\b/,path);
  if(/terms\.html|privacy\.html|impressum\.html|faq\.html|pricing\.html/.test(path))
   assert.match(source,/script-src 'self'/);
 }
 const [js,css,build]=await Promise.all([
  read('../website/studio-footer.js'),read('../website/studio-footer.css'),
  read('../website/dev-scripts/build.mjs')]);
 assert.match(js,/Europe\/Berlin/);
 assert.match(js,/setInterval\(updateClock,1000\)/);
 for(const url of ['https://nextqueststudio.net/','https://propelotonmanager.com/','https://tennislegacygame.com/'])
  assert.ok(js.includes(url));
 for(const path of ['/terms.html','/privacy.html','/impressum.html','/faq.html','/pricing.html'])
  assert.ok(js.includes(path));
 assert.match(js,/rel="noopener noreferrer"/);
 assert.match(js,/contact@nextqueststudio\.net/);
 assert.match(js,/const existingHealth=footer\.querySelector\('\.platform-health'\)/);
 assert.match(css,/footer\.studio-footer/);
 for(const file of ['studio-footer.js','studio-footer.css','faq.html','pricing.html'])
  assert.ok(build.includes("'"+file+"'"));
});

test('pricing and FAQ have truthful trial conditions and no fictional monthly fee',async()=>{
 const [pricing,faq]=await Promise.all([read('../website/pricing.html'),read('../website/faq.html')]);
 assert.match(pricing,/Pricing has not yet been announced/);
 assert.match(pricing,/no recurring charge begins automatically/);
 assert.match(faq,/No payment information is required/);
 assert.match(faq,/Horizon/);
 assert.doesNotMatch(pricing,/€[0-9]|\$[0-9]+\/month/);
});
