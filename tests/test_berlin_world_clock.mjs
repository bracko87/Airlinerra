import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 formatBerlinGameTime,verifyWorldTimeResponse,startBerlinGameClock,WORLD_TIME_URL
} from '../website/world-time-client.mjs';

const sample=(utcNow='2026-11-11T08:28:30.000Z')=>({
 worldId:1,utcNow,berlinDate:'2026-11-11',berlinTime:'09:28:30',
 timeZone:'Europe/Berlin',speed:'1:1',readOnly:true
});
test('World 1 uses exact real Berlin time, one second for one second',()=>{
 const t=verifyWorldTimeResponse(sample());
 assert.equal(t,Date.parse('2026-11-11T08:28:30.000Z'));
 assert.equal(formatBerlinGameTime(t),'11 Nov 2026 · 09:28:30 Berlin');
 assert.equal(formatBerlinGameTime(t+1000),'11 Nov 2026 · 09:28:31 Berlin');
});
test('Berlin summer and winter changes follow IANA timezone rules',()=>{
 assert.equal(formatBerlinGameTime(Date.parse('2026-03-29T00:59:59Z')),
 '29 Mar 2026 · 01:59:59 Berlin');
 assert.equal(formatBerlinGameTime(Date.parse('2026-03-29T01:00:00Z')),
 '29 Mar 2026 · 03:00:00 Berlin');
 assert.equal(formatBerlinGameTime(Date.parse('2026-10-25T00:59:59Z')),
 '25 Oct 2026 · 02:59:59 Berlin');
 assert.equal(formatBerlinGameTime(Date.parse('2026-10-25T01:00:00Z')),
 '25 Oct 2026 · 02:00:00 Berlin');
});
test('Client rejects forged, invalid or accelerated server time',()=>{
 for(const wrong of [
 {...sample(),worldId:2},{...sample(),speed:'10:1'},
 {...sample(),readOnly:false},{...sample(),timeZone:'UTC'},
 {...sample(),utcNow:'2026-11-11'}, {...sample(),utcNow:'not-a-date'},
 null,{}
 ])assert.equal(verifyWorldTimeResponse(wrong),null);
});
test('Live client calibrates from server time, not from user device wall clock',async()=>{
 const element={textContent:''},intervals=[],cleared=[];
 let monotonic=100;
 const client=startBerlinGameClock({element,
  fetchImpl:async(url,params)=>{
   assert.equal(url,WORLD_TIME_URL);assert.equal(params.method,'GET');
   assert.equal(params.credentials,'omit');
   return {ok:true,json:async()=>sample()};
  },
  nowMonotonic:()=>monotonic,
  setEvery:(fn,ms)=>{intervals.push({fn,ms});return intervals.length;},
  clearEvery:id=>cleared.push(id),
  doc:{addEventListener(){},removeEventListener(){}}
 });
 await new Promise(resolve=>setImmediate(resolve));
 assert.equal(element.textContent,'11 Nov 2026 · 09:28:30 Berlin');
 monotonic+=1000;client.render();
 assert.equal(element.textContent,'11 Nov 2026 · 09:28:31 Berlin');
 assert.deepEqual(intervals.map(x=>x.ms),[1000,60000]);
 client.stop();assert.deepEqual(cleared,[1,2]);
});
test('Server World 1 time is strictly read-only and private game operations remain off',async()=>{
 const [migration,edge,html,app,overlay]=await Promise.all([
  'supabase/migrations/20261111093000_section9_berlin_realtime_clock.sql',
  'server/section9-world-time-edge-entry.ts',
  'website/private-player-app.html','website/player-app.mjs',
  'website/dev-scripts/invited-overlay.mjs'
 ].map(path=>readFile(new URL('../'+path,import.meta.url),'utf8')));
 assert.match(migration,/AT TIME ZONE 'Europe\/Berlin'/);
 assert.match(migration,/section9_live_berlin_clock_v1/);
 assert.match(migration,/REVOKE EXECUTE ON FUNCTION/);
 assert.doesNotMatch(migration,/UPDATE airlinerra_game\.airlines/i);
 assert.doesNotMatch(migration,/INSERT INTO airlinerra_game\.airline_ledger/i);
 assert.match(edge,/SELECT airlinerra_game\.section9_live_berlin_clock_v1/);
 assert.doesNotMatch(edge,/service_role|SERVICE_ROLE/i);
 assert.match(html,/<footer class="footer">[^\n]*id="game-footer-time"/);
 assert.doesNotMatch(html,/id="top-game-time"/);
 assert.match(app,/getElementById\('game-footer-time'\)/);
 assert.match(app,/showRealBerlinGameTime\(\)/);
 assert.match(overlay,/'world-time-client\.mjs'/);
});

test('Game clock appears only as unboxed player footer text',async()=>{
 const [footerScript,footerCss,gameCss,html]=await Promise.all([
  '../website/studio-footer.js','../website/studio-footer.css',
  '../website/player-app.css','../website/private-player-app.html'
 ].map(path=>readFile(new URL(path,import.meta.url),'utf8')));
 assert.match(footerScript,/const gameFooterTime=footer\.querySelector/);
 assert.match(footerScript,/staticBottomNote\.replaceWith\(gameFooterTime\)/);
 assert.match(footerCss,/footer\.studio-footer #game-footer-time/);
 assert.match(footerCss,/background:transparent;border:0;box-shadow:none/);
 assert.doesNotMatch(gameCss,/\.header-game-time/);
 assert.doesNotMatch(html.split('<footer')[0],/game-footer-time/);
});
