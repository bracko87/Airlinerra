import test from 'node:test';
import assert from 'node:assert/strict';
import {installGameTimePickers} from '../website/game-time-pickers.mjs';

// Small browser-event harness: event paths are fixed before bubbling, exactly
// as in the browser. Catches a picker that destroys its clicked option while
// the outside-click document listener is still processing the same click.
class Element {
 constructor(tag,owner=null){
  this.tagName=tag.toUpperCase();
  this.owner=owner;this.parent=null;this.children=[];this.nodeType=1;
  this.type=tag==='input'?'time':undefined;
  this.value=tag==='input'?'09:00':'';
  this.disabled=false;this.hidden=false;this.readOnly=false;
  this.dataset={};this.style={};this.attributes=new Map();this.events=new Map();
  this.classes=new Set();
  this.classList={
   add:(...names)=>names.forEach(n=>this.classes.add(n)),
   remove:(...names)=>names.forEach(n=>this.classes.delete(n)),
   contains:name=>this.classes.has(name)
  };
 }
 setAttribute(k,v){this.attributes.set(k,String(v))}
 getAttribute(k){return this.attributes.get(k)??null}
 hasAttribute(k){return this.attributes.has(k)}
 get isConnected(){let n=this;while(n){if(n===this.owner)return true;n=n.parent}return false}
 getBoundingClientRect(){return {left:100,top:100,bottom:133,right:250,width:150,height:33}}
 focus(){this.owner.activeElement=this}
 append(...nodes){
  for(const node of nodes){
   node.remove();node.parent=this;this.children.push(node);
  }
 }
 before(node){
  const parent=this.parent;
  if(!parent)throw Error('Cannot insert before unattached node');
  node.remove();
  parent.children.splice(parent.children.indexOf(this),0,node);
  node.parent=parent;
 }
 remove(){
  if(!this.parent)return;
  const p=this.parent,i=p.children.indexOf(this);
  if(i>=0)p.children.splice(i,1);
  this.parent=null;
 }
 replaceChildren(...nodes){
  for(const node of [...this.children])node.remove();
  this.append(...nodes);
 }
 contains(node){
  while(node){if(node===this)return true;node=node.parent}
  return false;
 }
 matches(selector){
  const hasClass=name=>this.classes.has(name)||
   String(this.className||'').split(/\s+/).includes(name);
  if(selector==='input[type="time"]')return this.tagName==='INPUT'&&this.type==='time';
  if(selector==='.game-time-option')return hasClass('game-time-option');
  if(selector==='.game-time-option[aria-pressed="true"]')
   return hasClass('game-time-option')&&this.getAttribute('aria-pressed')==='true';
  if(selector==='.game-time-popup')return hasClass('game-time-popup');
  if(selector==='.game-time-trigger')return hasClass('game-time-trigger');
  return false;
 }
 querySelectorAll(selector){
  const results=[];
  const visit=root=>{
   for(const node of root.children){
    if(node.matches(selector))results.push(node);
    visit(node);
   }
  };
  visit(this);return results;
 }
 querySelector(selector){return this.querySelectorAll(selector)[0]||null}
 addEventListener(type,fn){
  const handlers=this.events.get(type)||[];
  handlers.push(fn);this.events.set(type,handlers);
 }
 removeEventListener(type,fn){
  this.events.set(type,(this.events.get(type)||[]).filter(x=>x!==fn));
 }
 dispatchEvent(event){
  const path=[];let current=this;
  while(current){path.push(current);current=current.parent}
  event.target=this;event.composedPath=()=>path;
  event.preventDefault=()=>{event.defaultPrevented=true};
  event.stopPropagation=()=>{event.stopped=true};
  for(const node of path){
   for(const listener of node.events.get(event.type)||[])listener(event);
   if(event.stopped)break;
  }
  return !event.defaultPrevented;
 }
 click(){this.dispatchEvent({type:'click'})}
}
class Document {
 constructor(){
  this.events=new Map();this.children=[];this.activeElement=null;
  this.root=this.createElement('div');this.root.parent=this;
  this.children.push(this.root);
 }
 createElement(tag){return new Element(tag,this)}
 querySelectorAll(selector){return this.root.querySelectorAll(selector)}
 addEventListener(type,fn){const v=this.events.get(type)||[];v.push(fn);this.events.set(type,v)}
 removeEventListener(type,fn){this.events.set(type,(this.events.get(type)||[]).filter(x=>x!==fn))}
}
class FakeObserver {
 constructor(){this.disconnected=false}
 observe(){}
 disconnect(){this.disconnected=true}
}
const eventValue=(type,extras={})=>({type,...extras});

test('click hour and minute, keep menu open, Apply commits exact HH:MM and fires change once',()=>{
 const original={Event:globalThis.Event,MutationObserver:globalThis.MutationObserver,window:globalThis.window};
 globalThis.Event=class{constructor(type,opts={}){this.type=type;this.bubbles=opts.bubbles}};
 globalThis.MutationObserver=FakeObserver;
 globalThis.window={innerWidth:1100,innerHeight:800};
 try{
  const doc=new Document(),input=doc.createElement('input');
  input.value='09:00';doc.root.append(input);
  let changes=0;input.addEventListener('change',()=>{changes++});
  const picker=installGameTimePickers({doc,root:doc.root});
  assert.equal(input.type,'text','native picker must not open');
  const trigger=doc.root.querySelector('.game-time-trigger');
  const popup=doc.root.querySelector('.game-time-popup');
  trigger.click();
  assert.equal(popup.hidden,false);
  const hour=popup.querySelectorAll('.game-time-option')
   .find(x=>x.dataset.gameTimePart==='hour'&&x.dataset.gameTimeValue==='14');
  const minute=popup.querySelectorAll('.game-time-option')
   .find(x=>x.dataset.gameTimePart==='minute'&&x.dataset.gameTimeValue==='25');
  assert.ok(hour&&minute,'hour and minute options must exist');
  hour.click();
  assert.equal(popup.hidden,false,'choosing hour must not close menu');
  assert.equal(hour.isConnected,true,'selecting an option must not detach it during click bubbling');
  assert.equal(hour.getAttribute('aria-pressed'),'true');
  assert.equal(popup.children[0].textContent,'Departure time · 14:00');
  minute.click();
  assert.equal(popup.hidden,false,'choosing minute must not close menu');
  assert.equal(minute.isConnected,true);
  assert.equal(minute.getAttribute('aria-pressed'),'true');
  assert.equal(popup.children[0].textContent,'Departure time · 14:25');
  assert.equal(input.value,'09:00','do not modify flight schedule until Apply');
  const apply=popup.children[2].children.find(x=>x.dataset.gameTimeAction==='apply');
  apply.click();
  assert.equal(input.value,'14:25');
  assert.equal(popup.hidden,true);
  assert.equal(changes,1,'route planner change handler must receive exactly one change');
  assert.equal(trigger.getAttribute('aria-expanded'),'false');

  trigger.click();
  const hour16=popup.querySelectorAll('.game-time-option')
   .find(x=>x.dataset.gameTimePart==='hour'&&x.dataset.gameTimeValue==='16');
  hour16.click();
  const cancel=popup.children[2].children.find(x=>x.dataset.gameTimeAction==='cancel');
  cancel.click();
  assert.equal(input.value,'14:25','Cancel must not edit the timetable');
  assert.equal(changes,1);

  trigger.click();
  doc.root.click();
  assert.equal(popup.hidden,true,'outside click should still close the menu');
  picker.destroy();
  assert.equal(input.type,'time','cleanup restores native input');
 }finally{
  globalThis.Event=original.Event;
  globalThis.MutationObserver=original.MutationObserver;
  globalThis.window=original.window;
 }
});
