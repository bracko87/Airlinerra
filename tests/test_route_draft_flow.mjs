import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {routeAirportPairStatus,routeDraftSaveMode,routePlannerMarkup}
 from '../website/route-planner.mjs';
import {gameTimeValue} from '../website/game-time-pickers.mjs';

const read=name=>readFile(new URL('../website/'+name,import.meta.url),'utf8');

test('identical airport key is blocked even if displayed under another name',()=>{
 const a={key:'OURAIRPORTS:4610',name:'Belgrade Nikola Tesla'};
 const renamed={key:'OURAIRPORTS:4610',name:'Another name'};
 const b={key:'OURAIRPORTS:4611',name:'Aleksandrovo'};
 assert.equal(routeAirportPairStatus(a,renamed),'SAME_AIRPORT');
 assert.equal(routeAirportPairStatus(a,b),'VALID');
 assert.equal(routeAirportPairStatus(null,b),'INCOMPLETE');
 assert.equal(routeAirportPairStatus(a,null),'INCOMPLETE');
});

test('read-only localhost schedule checks cannot be mistaken for server-save support',()=>{
 const readonly={list:async()=>({drafts:[]}),slotCheck:async()=>({available:true})};
 assert.equal(routeDraftSaveMode(readonly),'browser');
 assert.equal(routeDraftSaveMode(null),'browser');
 assert.equal(routeDraftSaveMode({save:null}),'browser');
 assert.equal(routeDraftSaveMode({...readonly,save:async()=>({status:'draft'})}),'server');
});

test('route creation is blocked for same airport in UI, preview and save; invalid 0-km map does not render',async()=>{
 const src=await read('route-planner.mjs');
 assert.match(src,/routeAirportPairStatus\(from,to\)==='SAME_AIRPORT'/);
 assert.match(src,/equal\?null:from,equal\?null:to/);
 assert.match(src,/routeAirportPairStatus\(from,to\)!=='VALID'/);
 assert.match(src,/button\.disabled=pairStatus==='SAME_AIRPORT'/);
 assert.match(src,/reason:'SAME_AIRPORT'/);
 assert.match(src,/Restricted — same airport/);
});

test('local route Save persists in the same account-session store as My Routes, with explicit confirmation',async()=>{
 const [route,workspace,directory]=await Promise.all([
  read('route-planner.mjs'),read('airline-workspace.mjs'),read('airline-operations-center.mjs')
 ]);
 assert.match(route,/const canSaveToServer=routeDraftSaveMode\(data\?\.scheduler\)==='server'/);
 assert.match(route,/if\(canSaveToServer\)\{/);
 assert.match(route,/if\(canSaveToServer&&!preflight\)/);
 assert.match(route,/if\(preflight\?\.gameHardBlocked===true\)/);
 assert.match(route,/if\(!draftWrite\('routes',\[\.\.\.filtered,draft\]\)\)/);
 assert.match(route,/airlinerra:route-draft-saved/);
 assert.match(route,/storage:canSaveToServer\?'server':'browser'/);
 assert.match(route,/saved as a LOCAL planning draft/);
 assert.match(route,/No server schedule or flight was created/);
 assert.match(workspace,/airlinerra\.local\.workplan\.v1\./);
 assert.match(directory,/airlinerra\.local\.workplan\.v1\./);
 assert.match(directory,/state=storageRead\(session,key\);renderRoutes\(\)/);
 assert.match(directory,/route\.serverScheduleId\?'Server draft · inactive':'Local draft · inactive'/);
 assert.match(directory,/airlinerra:route-draft-saved/);
 assert.match(directory,/saved as a local planning draft and listed above/);
});

test('weekday time picker uses in-game hours and minutes, not browser-native time popup',async()=>{
 assert.equal(gameTimeValue('09:00'),'09:00');
 assert.equal(gameTimeValue('23:59'),'23:59');
 assert.equal(gameTimeValue('00:00'),'00:00');
 for(const bad of ['24:00','00:60','9:30','10:05Z','',null])assert.equal(gameTimeValue(bad),null);
 const [picker,app,build,css]=await Promise.all([
  read('game-time-pickers.mjs'),read('player-app.mjs'),
  read('dev-scripts/invited-overlay.mjs'),read('player-app.css')
 ]);
 assert.match(picker,/input\.type='text';input\.readOnly=true/);
 assert.match(picker,/new Event\('change',\{bubbles:true\}\)/);
 assert.match(picker,/\['hour',24,/); // allow custom picker hour / minute range
 assert.match(picker,/input\.disabled/);
 assert.match(picker,/MutationObserver/);
 assert.match(app,/installGameTimePickers\(\{doc,root:doc\.getElementById\('player-main'\)\}\)/);
 assert.match(build,/'game-time-pickers\.mjs'/);
 assert.match(css,/\.game-time-popup/);
 assert.match(css,/\.route-apply-actions \.primary/);
 assert.match(routePlannerMarkup(),/data-route-time="0"/);
});
