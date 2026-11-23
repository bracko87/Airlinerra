import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {section9RouteIdentity,findSection9RouteIndex} from '../website/section9-route-details.mjs';

const route=(number,scheduleId=null)=>({
 flightNumber:number,from:{key:'OURAIRPORTS:2218'},to:{key:'OURAIRPORTS:2212'},
 ...(scheduleId?{serverScheduleId:scheduleId}:{})
});
const a='11111111-1111-4111-8111-111111111111';
const b='22222222-2222-4222-8222-222222222222';

test('route detail selection follows schedule ID after refresh reorders rows',()=>{
 const first=[route('AL101',a),route('AL102',b)];
 const selected=section9RouteIdentity(first[1]);
 const reordered=[route('AL102',b),route('AL101',a)];
 assert.equal(findSection9RouteIndex(reordered,selected),0);
 assert.equal(findSection9RouteIndex(first,selected),1);
});
test('removed route selection never silently jumps to another flight',()=>{
 const selected=section9RouteIdentity(route('AL101',a));
 assert.equal(findSection9RouteIndex([route('AL102',b)],selected),-1);
 assert.equal(findSection9RouteIndex([],selected),-1);
});
test('planning route identity cannot be mistaken for an operating schedule',()=>{
 const planned={...route('AL101'),serverPlanningId:'planning-42'};
 assert.equal(section9RouteIdentity(planned),'plan:planning-42');
 assert.notEqual(section9RouteIdentity(planned),section9RouteIdentity(route('AL101',a)));
 assert.equal(findSection9RouteIndex([route('AL101',a)],section9RouteIdentity(planned)),-1);
});
test('local draft identities include airports to avoid same-flight-number collisions',()=>{
 const local=route('AL101');
 const alternative={...local,to:{key:'OURAIRPORTS:1234'}};
 assert.notEqual(section9RouteIdentity(local),section9RouteIdentity(alternative));
 assert.equal(findSection9RouteIndex([alternative],section9RouteIdentity(local)),-1);
});
test('invalid route is never selected using an unverified or empty identity',()=>{
 assert.equal(section9RouteIdentity(null),null);
 assert.equal(section9RouteIdentity({flightNumber:'AL101'}),null);
 assert.equal(findSection9RouteIndex([],null),-1);
});
test('verified route refresh reconciles details and cancellation reloads server calendar',async()=>{
 const read=p=>readFile(new URL(p,import.meta.url),'utf8');
 const [details,operations,workspace]=await Promise.all([
  read('../website/section9-route-details.mjs'),
  read('../website/airline-operations-center.mjs'),
  read('../website/airline-workspace.mjs')
 ]);
 assert.match(details,/findSection9RouteIndex\(getRoutes\?\.\(\)\|\|\[\],selectedIdentity\)/);
 assert.match(details,/This route is no longer in the current airline list/);
 assert.match(operations,/renderRoutes\(\);\s*\/\/ Reload details by schedule identity/);
 assert.match(operations,/void details\.refresh\(\)/);
 assert.match(operations,/Operational changes remain locked/);
 assert.match(operations,/scheduleChangeAssessment\(\{airlineId,scheduleId:id\}\)/);
 assert.match(workspace,/doc\.addEventListener\('airlinerra:route-draft-cancelled',[\s\S]{0,300}void loadAirlineSchedule\(\)/);
});
