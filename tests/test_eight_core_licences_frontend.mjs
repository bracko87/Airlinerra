import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';
const file=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
const eight=[
 ['1','AIR_OPERATOR_CERTIFICATE'],['2','FOREIGN_NETWORK_LICENCE_2'],
 ['3','CARGO_OPERATIONS_SCOPE'],['4','CHARTER_VIP_SCOPE'],
 ['5','DANGEROUS_GOODS'],['6','MAINTENANCE_ORGANIZATION_LICENCE_6'],
 ['7','FLIGHT_ACADEMY'],['8','AIRCRAFT_LEASING']
];
test('Every agreed numbered licence is in the planning catalogue',()=>{
 for(const [number,code] of eight){
  const entries=LICENCE_PLAN.filter(l=>l.code===code);
  assert.equal(entries.length,1,'unique Licence '+number);
 }
 assert.equal(new Set(eight.map(e=>e[1])).size,8);
 assert.equal(LICENCE_PLAN.some(l=>l.title.includes('Air Ambulance')),false);
 assert.equal(LICENCE_PLAN.some(l=>l.title.includes('Ground Handling Services Licence')),false);
});
test('Player permission frontend always displays navigable entries 1–8 and clear locked company licences',async()=>{
 const src=await file('website/game-permission-applications-view.mjs');
 const pairs=[['1','Air Operator Certificate'],['2','Foreign Network Expansion'],
  ['3','Cargo Operations'],['4','Charter / VIP'],['5','Dangerous Goods'],
  ['6','Maintenance Organization'],['7','Flight Academy'],['8','Aircraft Leasing']];
 for(const [n,title] of pairs)
  assert.ok(src.includes("['"+n+"','"+title+"']"),'overview '+n);
 for(let n=1;n<=8;n++){
  if(n<=5)assert.ok(src.includes("id='game-licence-core-"+n+"'"),'panel '+n);
  else assert.ok(src.includes("number:'"+n+"'"),'future panel '+n);
 }
 assert.match(src,/scrollIntoView\?\./);
 assert.match(src,/Applications not available/);
 assert.match(src,/locked\.disabled=true/);
 assert.match(src,/Wet leasing \/ ACMI is not authorized by Licence 8/);
 assert.match(src,/At least one purchased, delivered and operational small training aircraft/);
 assert.match(src,/futureCompanyLicences/);
});
test('Eight licence overview is rectangular and responsive, no permissions are inferred from it',async()=>{
 const css=await file('website/player-app.css');
 const src=await file('website/game-permission-applications-view.mjs');
 assert.match(css,/\.game-licence-overview-grid/);
 assert.match(css,/\.game-licence-overview-item/);
 assert.match(css,/border-radius:4px/);
 assert.match(css,/@media\(max-width:520px\).*game-licence-overview-grid/);
 assert.match(src,/An information panel is not proof of approval/);
 assert.match(src,/status:'Under development — applications not available'/);
});
