import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN,createLicensingPlanner} from '../website/licensing-planner.mjs';

const expectedCodes=[
 'HOLDING_FORMATION','SUBSIDIARY_FORMATION','AIR_OPERATOR_CERTIFICATE',
 'EU_AIRLINE_OPERATING_LICENCE','CARGO_OPERATIONS_SCOPE',
 'CHARTER_VIP_SCOPE','DANGEROUS_GOODS','DOMESTIC_TRAFFIC',
 'INTEGRATED_MARKET','THIRD_FOURTH_FREEDOM','FIFTH_FREEDOM',
 'SEVENTH_FREEDOM','CABOTAGE','FOREIGN_BASE_PERMIT',
 'PART145_MAINTENANCE','NON_EU_MAINTENANCE'
];

test('planner covers every installed reference type plus labelled future concepts',()=>{
 const codes=LICENCE_PLAN.map(x=>x.code);
 assert.equal(new Set(codes).size,codes.length,'no duplicated game permission codes');
 assert.equal(codes.length,18);
 for(const code of expectedCodes)assert.ok(codes.includes(code),code);
 for(const future of ['AIRPORT_SLOTS','FLIGHT_ACADEMY'])
  assert.ok(codes.includes(future),'future concept '+future);
 for(const entry of LICENCE_PLAN){
  assert.ok(entry.title&&entry.cost&&entry.validity&&entry.loss&&entry.recovery);
  assert.ok(entry.application.length>=2,entry.code);
  assert.ok(entry.approval.length>=1,entry.code);
  assert.ok(entry.operation.length>=1,entry.code);
 }
});

test('company formation and application do not demand an aircraft purchase',()=>{
 for(const code of ['HOLDING_FORMATION','SUBSIDIARY_FORMATION']){
  const entry=LICENCE_PLAN.find(x=>x.code===code);
  assert.match(entry.aircraft,/No aircraft required/);
 }
 for(const code of ['AIR_OPERATOR_CERTIFICATE','CARGO_OPERATIONS_SCOPE','CHARTER_VIP_SCOPE']){
  const entry=LICENCE_PLAN.find(x=>x.code===code);
  assert.match(entry.aircraft,/Apply: no/);
  assert.match(entry.aircraft,/Final approval:/);
 }
 assert.match(LICENCE_PLAN.find(x=>x.code==='HOLDING_FORMATION').notes,/calendar days/);
 assert.match(LICENCE_PLAN.find(x=>x.code==='CARGO_OPERATIONS_SCOPE').notes,/already has one/);
 assert.match(LICENCE_PLAN.find(x=>x.code==='CABOTAGE').limits,/Unavailable markets remain blocked/);
});

function fakeElement(tag){
 return {
  tag,children:[],textContent:'',className:'',dataset:{},attrs:{},listeners:{},
  value:'',disabled:false,hidden:false,
  append(...nodes){this.children.push(...nodes);},
  replaceChildren(...nodes){this.children=[...nodes];},
  setAttribute(name,value){this.attrs[name]=String(value);},
  addEventListener(name,callback){this.listeners[name]=callback;},
  querySelectorAll(name){
   const matches=[];
   function visit(node){
    for(const child of node.children){
     if(child.tag===name)matches.push(child);
     visit(child);
    }
   }
   visit(this);
   return matches;
  }
 };
}
const flatText=root=>String(root.textContent||'')+' '+(root.children||[]).map(flatText).join(' ');
const first=(root,tag,predicate)=>root.querySelectorAll(tag).find(predicate);

test('ticket-style licence planner uses selects, preserves checks, and remains read-only',()=>{
 const doc={createElement:fakeElement},root=fakeElement('main');
 let airlineName='Test Airline';
 const planner=createLicensingPlanner({doc,root,getAirline:()=>({name:airlineName})});
 planner.show();
 let text=flatText(root);
 assert.match(text,/LICENSING PLANNING/);
 assert.match(text,/Signed-in airline: Test Airline · requirements not evaluated/);
 assert.match(text,/For final approval/);
 assert.match(text,/1 suitable delivered and inspected aircraft/);
 assert.match(text,/Applications not yet available/);
 assert.match(text,/Included in original airline activation/);
 assert.equal(root.children.length,2,'ticket-price-style two-panel layout');
 assert.ok(root.children.every(x=>x.className.includes('panel workspace-panel')));
 assert.ok(root.querySelectorAll('button').every(x=>x.disabled),'only disabled application button');

 const scenario=first(root,'select',x=>x.attrs['aria-label']==='Cost scenario');
 scenario.value='subsidiary';scenario.listeners.change();
 assert.match(flatText(root),/\$150,000 for new airline subsidiary/);

 const licence=first(root,'select',x=>x.attrs['aria-label']==='Licence or permit');
 licence.value='CARGO_OPERATIONS_SCOPE';licence.listeners.change();
 text=flatText(root);
 assert.match(text,/Cargo operations approval/);
 assert.match(text,/At least 1 cargo-handling arrangement/);
 assert.match(text,/What stays restricted/);
 assert.match(text,/If suspended, expired or lost/);
 assert.match(text,/How to restore/);
 assert.match(text,/3 game days/);

 const category=first(root,'select',x=>x.attrs['aria-label']==='Permission category');
 category.value='market';category.listeners.change();
 assert.equal(licence.children.some(x=>x.value==='CARGO_OPERATIONS_SCOPE'),false);
 assert.ok(licence.children.some(x=>x.value==='FIFTH_FREEDOM'));
 const search=first(root,'input',x=>x.attrs['aria-label']==='Search licences and requirements');
 search.value='cabotage';search.listeners.input();
 assert.ok(licence.children.some(x=>x.value==='CABOTAGE'));
 assert.equal(licence.children.some(x=>x.value==='FIFTH_FREEDOM'),false);
 search.value='not-existing';search.listeners.input();
 assert.match(flatText(root),/No permission matches these filters/);
 search.value='';search.listeners.input();
 airlineName='New name';
 planner.show();
 assert.match(flatText(root),/New name/);
});

test('player UI wires preview without altering real permission gates or public site auth',async()=>{
 const read=path=>readFile(new URL(path,import.meta.url),'utf8');
 const [html,app,bundle,source,css]=await Promise.all([
  read('../website/private-player-app.html'),
  read('../website/player-app.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),
  read('../website/licensing-planner.mjs'),
  read('../website/player-app.css')
 ]);
 assert.match(html,/id="licences-planner-root"/);
 assert.match(html,/id="licenses-catalog-groups"/);
 assert.match(html,/class="panel workspace-panel lp-reference"/);
 assert.doesNotMatch(html,/license-page-notice" role="note"/);
 assert.match(app,/createLicensingPlanner/);
 assert.match(app,/licencePlanner\.show\(\)/);
 assert.match(app,/data\.applicationsAvailable!==false/);
 assert.match(bundle,/'licensing-planner\.mjs'/);
 assert.match(css,/\.lp-controls\{/);
 assert.doesNotMatch(css,/\.lp-result\[aria-pressed="true"\]/);
 for(const forbidden of ['fetch(', 'innerHTML', 'localStorage', 'sessionStorage', '.from('])
  assert.equal(source.includes(forbidden),false,forbidden);
});
