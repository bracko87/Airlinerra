import test from 'node:test';
import assert from 'node:assert/strict';
import {createGamePermissionApplicationsView} from '../website/game-permission-applications-view.mjs';

const AIRLINE='22222222-2222-4222-8222-222222222222';
const OTHER='33333333-3333-4333-8333-333333333333';
const day='2026-11-17';
function element(tag){
 return {tag,children:[],className:'',textContent:'',value:'',hidden:false,
  listeners:{},attrs:{},
  append(...nodes){this.children.push(...nodes);},
  replaceChildren(...nodes){this.children=[...nodes];},
  addEventListener(name,fn){this.listeners[name]=fn;},
  setAttribute(name,value){this.attrs[name]=String(value);}
 };
}
function all(root,cls){
 const matches=[];
 function scan(node){
  if(node.className?.split(' ').includes(cls))matches.push(node);
  for(const child of node.children||[])scan(child);
 }scan(root);
 return matches;
}
const initial={
 airlineId:AIRLINE,worldId:1,status:'planned_not_released',
 verifiedCompanyRegistry:false,issued:false,safetyRating:null,readOnly:true
};
const response=aoc=>({
 status:'permission_applications_status',airlineId:AIRLINE,
 worldId:1,gameDay:day,canApply:false,policies:[],
 applications:[],approvalByPlayer:false,ledgerPosted:false,
 flightActivated:false,...(aoc===undefined?{}:{aocStatus:aoc})
});
function setup(aoc,airline=AIRLINE){
 const doc={createElement:element};
 const root=element('section');
 let selected=airline;
 const client={status:async()=>response(aoc),apply:async()=>{throw Error('disabled')}};
 const view=createGamePermissionApplicationsView({
  doc,root,getAirline:()=>selected?{id:selected}:null,
  getClient:()=>client,newRequestKey:()=>{throw Error('No application permitted')}
 });
 return {view,root,setAirline:id=>{selected=id}};
}
test('AOC page uses real owner-scoped status and does not invent first licence',async()=>{
 const x=setup(initial);
 await x.view.load();
 assert.equal(all(x.root,'game-aoc-status-text')[0].textContent,
  'AOC system planned — not yet enabled');
 assert.match(all(x.root,'game-aoc-status')[0].children[2].textContent,
  /No certificate has been issued/);
 assert.ok(all(x.root,'game-licence-panel').length);
 assert.ok(all(x.root,'game-licence-form').length);
});
test('an older server without AOC keeps the page usable without false issue',async()=>{
 const x=setup(undefined);
 await x.view.load();
 assert.match(all(x.root,'game-aoc-status-text')[0].textContent,
  /not connected to this server/);
 assert.match(all(x.root,'game-aoc-status')[0].children[2].textContent,
  /No issued AOC can be assumed/);
});
test('read-only active AOC displays only server-supplied dates and score',async()=>{
 const aoc={airlineId:AIRLINE,worldId:1,status:'active',issued:true,readOnly:true,
  issuedGameDay:day,expiresGameDay:'2027-11-17',
  safetyRating:{rating:80,airlineId:AIRLINE}};
 const x=setup(aoc);
 await x.view.load();
 assert.equal(all(x.root,'game-aoc-status-text')[0].textContent,
  'AOC active for this airline');
 assert.match(all(x.root,'game-aoc-status')[0].children[2].textContent,
  /Safety Rating 80\/100/);
});
test('missing verified airline hides any prior AOC',async()=>{
 const x=setup(initial);
 await x.view.load();
 x.setAirline(null);
 await x.view.load();
 assert.match(all(x.root,'game-aoc-status-text')[0].textContent,
  /unavailable for the selected airline/);
 assert.match(all(x.root,'game-aoc-status')[0].children[2].textContent,
  /No company licence is inferred/);
});
