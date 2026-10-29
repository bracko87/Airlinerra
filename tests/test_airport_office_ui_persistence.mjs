import test from 'node:test';
import assert from 'node:assert/strict';
import {createAirportOffice} from '../website/airline-airports-office.mjs';

const belgrade={key:'OURAIRPORTS:4343',name:'Belgrade Nikola Tesla Airport',code:'LYBE',countryIso:'RS'};
const sarajevo={key:'OURAIRPORTS:4344',name:'Sarajevo International Airport',code:'LQSA',countryIso:'BA'};
const zagreb={key:'OURAIRPORTS:4345',name:'Zagreb International Airport',code:'LDZA',countryIso:'HR'};
const owned={id:'airline-one',worldId:1,name:'Panonian',homeAirportKey:belgrade.key,homeAirportName:belgrade.name};
const legacyKey='airlinerra.local.workplan.v1.owner-one';
const copy=o=>JSON.parse(JSON.stringify(o));
class FakeNode {
 constructor(tag='div'){
  this.tag=tag;this.children=[];this.options=[];this.dataset={};this.hidden=false;
  this.disabled=false;this.value='';this.textContent='';this.className='';this.listeners={};
 }
 append(...children){this.children.push(...children)}
 replaceChildren(...children){
  this.children=children;
  if(this.tag==='select'){
   this.options=children;
   this.value=children[0]?.value||'';
  }
 }
 add(node){
  this.options.push(node);
  if(this.options.length===1)this.value=node.value;
 }
 addEventListener(event,handler){this.listeners[event]=handler}
 closest(selector){return selector==='button'&&this.tag==='button'?this:null}
}
function mockDoc(){
 const els=new Map();
 const doc={
  createElement:tag=>new FakeNode(tag),
  getElementById(id){
   if(!els.has(id)){
    const element=new FakeNode(id==='office-country'||id==='office-result'||id==='office-location-type'?'select':id==='office-find'||id==='office-save'||id==='office-import-local'?'button':'div');
    element.id=id;els.set(id,element);
   }
   return els.get(id);
  },
  click(button){
   const handler=this.getElementById('player-main').listeners.click;
   if(!handler)throw Error('Missing delegated click listener');
   return handler({target:button});
  }
 };
 return doc;
}
function storage(initial={}){
 const map=new Map(Object.entries(initial));
 return {getItem:k=>map.get(k)||null,setItem:(k,v)=>map.set(k,v),
  read:k=>JSON.parse(map.get(k)||'{}')};
}
const sleep=()=>new Promise(resolve=>setImmediate(resolve));
function backend({rejectKey=null}={}){
 const data=new Map(),calls=[];
 return {data,calls,client:{
  async list({worldId}){calls.push(['list',worldId]);return [...data.values()].map(copy)},
  async save({worldId,airportKey,type}){
   calls.push(['save',worldId,airportKey,type]);
   if(airportKey===rejectKey)throw Error('simulated backend refusal');
   if(data.has(airportKey))return {key:airportKey,type,status:'draft'};
   const airport=airportKey===sarajevo.key?sarajevo:zagreb;
   data.set(airportKey,{...airport,type,status:'draft'});
   return {key:airportKey,type,status:'draft'};
  },
  async remove({worldId,airportKey}){
   calls.push(['remove',worldId,airportKey]);
   return data.delete(airportKey);
  }
 }};
}
function connect(controller,db){
 controller.updateData({
  connected:true,airline:owned,officeClient:db.client,
  countries:[{countryIso:'BA',airportCount:1},{countryIso:'HR',airportCount:1}],
  reader:{airports:async({countryIso})=>({
   countryIso,airports:countryIso==='BA'?[sarajevo]:[zagreb]
  })}
 });
}
function hasText(node,fragment){
 return String(node.textContent||'').includes(fragment)||node.children.some(child=>hasText(child,fragment));
}
test('explicit import saves proposal permanently and survives a completely new browser session',async()=>{
 const originalOption=globalThis.Option;
 globalThis.Option=class extends FakeNode {
  constructor(label,value){super('option');this.textContent=label;this.value=value}
 };
 try{
  const local=storage({[legacyKey]:JSON.stringify({airportOffices:[{...sarajevo,status:'draft',type:'station'}],
   routes:[{origin:'LYBE',destination:'LQSA'}]})});
  const db=backend(),first=mockDoc();
  const firstUI=createAirportOffice({doc:first,identity:'owner-one',session:local});
  connect(firstUI,db);await sleep();
  assert.equal(db.data.size,0,'never silently upload old proposals on login');
  assert.equal(first.getElementById('office-import-local').hidden,false);
  assert.equal(local.read(legacyKey).airportOffices.length,1);
  await first.click(first.getElementById('office-import-local'));
  assert.equal(db.data.size,1,'user action saved first proposal');
  assert.equal(local.read(legacyKey).airportOffices.length,0,'confirmed browser copy removed');
  assert.equal(local.read(legacyKey).routes.length,1,'unrelated route planning retained');

  const newBrowser=mockDoc(),emptyBrowser=storage();
  const newUI=createAirportOffice({doc:newBrowser,identity:'owner-one',session:emptyBrowser});
  connect(newUI,db);await sleep();
  assert.ok(hasText(newBrowser.getElementById('office-station-list'),'Sarajevo'),
   'permanent station loaded after logout, reload and new browser session');
  assert.equal(newBrowser.getElementById('office-import-local').hidden,true);

  const actions=newBrowser.getElementById('office-station-list').children[0].children[1];
  const remove=actions.children[1];
  assert.equal(remove.dataset.officeAction,'remove');
  await newBrowser.click(remove);
  assert.equal(db.data.size,0,'delete saved draft uses the real client');
  assert.equal(emptyBrowser.getItem(legacyKey),null,'new browser never needs local storage for persistence');
 } finally{globalThis.Option=originalOption}
});
test('partial import preserves unsaved browser proposals and never charges money',async()=>{
 const oldOption=globalThis.Option;
 globalThis.Option=class extends FakeNode {
  constructor(label,value){super('option');this.textContent=label;this.value=value}
 };
 try{
  const local=storage({[legacyKey]:JSON.stringify({airportOffices:[
   {...sarajevo,type:'station',status:'draft'},
   {...zagreb,type:'hub',status:'draft'}
  ]})});
  const db=backend({rejectKey:zagreb.key}),doc=mockDoc();
  const ui=createAirportOffice({doc,identity:'owner-one',session:local});
  connect(ui,db);await sleep();
  await doc.click(doc.getElementById('office-import-local'));
  assert.equal(db.data.size,1,'successful draft saved');
  assert.deepEqual(local.read(legacyKey).airportOffices.map(x=>x.key),[zagreb.key],
   'only unverified proposal stays in local browser');
  assert.ok(doc.getElementById('office-feedback').textContent.includes('Import interrupted'));
  assert.equal(db.calls.some(x=>x[0]==='charge'||x[0]==='activate'),false);
 }finally{globalThis.Option=oldOption}
});
test('regular save from approved search is persisted then reloaded',async()=>{
 const oldOption=globalThis.Option;
 globalThis.Option=class extends FakeNode {
  constructor(label,value){super('option');this.textContent=label;this.value=value}
 };
 try{
  const db=backend(),doc=mockDoc();
  const ui=createAirportOffice({doc,identity:'owner-one',session:storage()});
  connect(ui,db);await sleep();
  doc.getElementById('office-country').value='BA';
  await doc.click(doc.getElementById('office-find'));
  doc.getElementById('office-result').value=sarajevo.key;
  doc.getElementById('office-location-type').value='station';
  const button=doc.getElementById('office-save');button.id='office-save';
  await doc.click(button);
  assert.equal(db.data.size,1);
  assert.equal(db.data.get(sarajevo.key).type,'station');
  assert.ok(doc.getElementById('office-feedback').textContent.includes('Permanent office draft saved'));
  assert.ok(hasText(doc.getElementById('office-station-list'),'Sarajevo'));
 }finally{globalThis.Option=oldOption}
});
