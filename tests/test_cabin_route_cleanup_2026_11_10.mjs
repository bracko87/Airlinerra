import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {routePlannerMarkup} from '../website/route-planner.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('Flight Services no longer displays redundant cabin-class default assignments',async()=>{
 const source=await read('website/cabin-services-manager.mjs');
 const css=await read('website/player-app.css');
 assert.doesNotMatch(source,/Default package by cabin class/);
 assert.doesNotMatch(source,/Save class assignments/);
 assert.doesNotMatch(source,/data\.cabinClass=/);
 assert.doesNotMatch(css,/\.cabin-assignment-panel|\.cabin-assignment-grid/);
 assert.match(source,/getAssignments:\(\)=>/); // stored old settings retained for compatibility
});
test('package save confirmation is visible and only fires after successful persistence',async()=>{
 const manager=await read('website/cabin-services-manager.mjs');
 const css=await read('website/player-app.css');
 assert.match(manager,/const showSaveConfirmation=packageName=>/);
 assert.match(manager,/cabin-package-saved-toast/);
 assert.match(manager,/saved successfully\. You can now select it when creating a route/);
 assert.match(manager,/if\(!await persist\(\)\)\{state\.packages\[i\]=old;return;\}/);
 const saved=manager.indexOf('showSaveConfirmation(next.name)');
 const savedAfter=manager.lastIndexOf('if(!await persist()',saved);
 assert.ok(saved>savedAfter && savedAfter>0,'Notification follows successful remote/local save');
 assert.match(css,/\.cabin-package-saved-toast\{/);
 assert.match(css,/position:fixed/);
 assert.match(manager,/notifyRoutes\(\)/);
});
test('route creation keeps package selection but has no estimated passenger or flight-hours controls',async()=>{
 const ui=routePlannerMarkup(),src=await read('website/route-planner.mjs');
 assert.match(ui,/id="route-cabin-package"/);
 assert.match(ui,/No onboard service/);
 assert.match(ui,/selected cabin package is saved with your route/i);
 assert.match(src,/service:\{.*cabinPackageId|cabinPackageId/);
 assert.match(src,/airlinerra:cabin-packages-updated/);
 assert.match(ui,/id="route-fuel-summary"/); // independent fuel forecast remains
 for(const old of [
  'Estimated passengers (preview only)','route-cabin-passengers',
  'route-cabin-hours','route-cabin-service-note',
  'route-cabin-cost-preview','expected onboard sales','cabinCostPreviewPassengers',
  'cabinCostPreviewHours'
 ]){
  assert.ok(!ui.includes(old),'Stale route control in markup: '+old);
  assert.ok(!src.includes(old),'Stale route control in source: '+old);
 }
 assert.match(src,/const payload=\.5/);
 const css=await read('website/player-app.css');
 assert.doesNotMatch(css,/route-cabin-cost-preview/);
});
