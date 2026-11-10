/**
 * Airlinerra Cabin Services — airline-scoped PRODUCT PLANNING UI.
 * A local manager design: no server purchases, money movement, demand uplift,
 * supply contract, inventory, aircraft-fit or flight dispatch is asserted.
 * Only fixed, developer-defined catalog data may be shown as supplier costs.
 */
export const CABIN_SERVICE_CATALOG=Object.freeze([
 {id:'water',name:'Drinking water',category:'Drinks',costCents:15,weight:0,condition:'Basic complimentary supply'},
 {id:'coffee',name:'Coffee and tea',category:'Drinks',costCents:35,weight:5},
 {id:'softdrink',name:'Soft drinks and juice',category:'Drinks',costCents:60,weight:6},
 {id:'alcohol',name:'Beer and wine',category:'Drinks',costCents:150,weight:5,condition:'Subject to country, route and age restrictions'},
 {id:'snack',name:'Small snack',category:'Food',costCents:70,weight:8},
 {id:'sandwich',name:'Sandwich / light meal',category:'Food',costCents:250,weight:9},
 {id:'hotmeal',name:'Hot meal',category:'Food',costCents:500,weight:14,condition:'Aircraft galley and catering required'},
 {id:'specialmeal',name:'Special dietary meal',category:'Food',costCents:600,weight:6,condition:'Pre-order, galley and catering required'},
 {id:'newspaper',name:'Digital newspapers',category:'Media',costCents:10,weight:3},
 {id:'wifi',name:'Basic Wi-Fi',category:'Media',costCents:60,weight:10,condition:'Onboard Wi-Fi equipment required'},
 {id:'fullwifi',name:'Full-speed Wi-Fi',category:'Media',costCents:200,weight:10,condition:'Onboard Wi-Fi equipment required'},
 {id:'entertainment',name:'Entertainment',category:'Media',costCents:35,weight:9,condition:'Compatible aircraft/player devices required'},
 {id:'blanket',name:'Blanket / comfort kit',category:'Comfort',costCents:200,weight:4},
 {id:'amenity',name:'Amenity kit',category:'Comfort',costCents:260,weight:5}
]);
export const CABIN_MODE_OPTIONS=Object.freeze([
 ['off','Not offered'],
 ['included','Included / free'],
 ['online','Paid online before flight'],
 ['onboard','Paid onboard'],
 ['both','Paid online and onboard'],
 ['hybrid','1–3 free, extras paid']
]);
export const CABIN_CLASSES=Object.freeze([
 ['economy','Economy'],['premium','Premium Economy'],
 ['business','Business'],['first','First Class']
]);
const CATALOG=new Map(CABIN_SERVICE_CATALOG.map(item=>[item.id,item]));
const MODES=new Set(CABIN_MODE_OPTIONS.map(item=>item[0]));
const CLASSES=new Set(CABIN_CLASSES.map(item=>item[0]));
const cents=num=>Number.isInteger(num)&&num>=0&&num<=100000?num:null;
const money=n=>'$'+(n/100).toFixed(2);
export const cabinDefaultItems=()=>Object.fromEntries(CABIN_SERVICE_CATALOG.map(item=>[
 item.id,{mode:item.id==='water'?'included':'off',freeQty:item.id==='water'?1:0,
  onlineCents:Math.round(item.costCents*3),onboardCents:Math.round(item.costCents*4)}
]));
export const createBasicCabinPackage=()=>({
 id:'basic',name:'Basic Cabin Service',locked:true,items:cabinDefaultItems()
});
const cleanItem=(value,id)=>{
 const v=value&&typeof value==='object'&&!Array.isArray(value)?value:{};
 const mode=MODES.has(v.mode)?v.mode:(id==='water'?'included':'off');
 return {
  mode,freeQty:mode==='included'||mode==='hybrid'?
   Math.max(1,Math.min(3,Number.isInteger(v.freeQty)?v.freeQty:1)):0,
  onlineCents:cents(v.onlineCents)??Math.round(CATALOG.get(id).costCents*3),
  onboardCents:cents(v.onboardCents)??Math.round(CATALOG.get(id).costCents*4)
 };
};
export function cleanCabinPackage(input){
 if(!input||typeof input!=='object'||Array.isArray(input))return null;
 const id=String(input.id||'');
 if(!/^(?:basic|pkg-[1-9][0-9]{0,5})$/.test(id))return null;
 if(id==='basic')return createBasicCabinPackage();
 const name=String(input.name||'').trim();
 if(name.length<2||name.length>45||/[\u0000-\u001f\u007f<>]/u.test(name))return null;
 const values=input.items&&typeof input.items==='object'?input.items:{};
 return {
  id,name,locked:false,
  items:Object.fromEntries(CABIN_SERVICE_CATALOG.map(i=>[i.id,cleanItem(values[i.id],i.id)]))
 };
}
export function initialCabinState(){
 return {version:1,packages:[createBasicCabinPackage()],assignments:{
  economy:'basic',premium:'basic',business:'basic',first:'basic'
 }};
}
export function cleanCabinState(value){
 const state=initialCabinState();
 if(!value||typeof value!=='object'||value.version!==1)return state;
 const entries=Array.isArray(value.packages)?value.packages:[];
 const seen=new Set(['basic']);
 for(const entry of entries){
  const pkg=cleanCabinPackage(entry);
  if(!pkg||seen.has(pkg.id)||state.packages.length>=9)continue;
  state.packages.push(pkg);seen.add(pkg.id);
 }
 for(const key of CLASSES)if(seen.has(value.assignments?.[key]))
  state.assignments[key]=value.assignments[key];
 return state;
}
/** GAME DESIGN estimate only; does not calculate or change real demand. */
export function cabinPackageEstimate(pkg){
 const rows=CABIN_SERVICE_CATALOG.map(item=>{
  const config=cleanItem(pkg?.items?.[item.id],item.id);
  // Standard assumptions: optional included services have 55% take-up;
  // drinking water is budgeted once for every passenger; paid take-up 20%.
  const included=config.mode==='included'||config.mode==='hybrid';
  const paid=['online','onboard','both','hybrid'].includes(config.mode);
  const uptake=item.id==='water'?1:.55;
  const cost=included?Math.round(item.costCents*uptake*config.freeQty):0;
  const avgPrice=config.mode==='online'?config.onlineCents:
   config.mode==='onboard'?config.onboardCents:
   Math.round((config.onlineCents+config.onboardCents)/2);
  const estimatedPaidMargin=paid?Math.round(.2*(avgPrice-item.costCents)):0;
  const satisfaction=config.mode==='included'?item.weight:
   config.mode==='hybrid'?Math.round(item.weight*.75):
   paid?Math.round(item.weight*.35):0;
  return {id:item.id,costCents:cost,paidMarginCents:estimatedPaidMargin,
   contribution:satisfaction};
 });
 const attractiveness=Math.min(100,25+rows.reduce((s,r)=>s+r.contribution,0));
 return {attractiveness,relativeToBasic:attractiveness-25,
  includedCents:rows.reduce((s,r)=>s+r.costCents,0),
  indicativeMarginCents:rows.reduce((s,r)=>s+r.paidMarginCents,0),
  rows};
}
const label=(doc,text,cls)=>{const node=doc.createElement('span');node.textContent=text;
 if(cls)node.className=cls;return node;};
const element=(doc,tag,cls,text)=>{
 const node=doc.createElement(tag);if(cls)node.className=cls;
 if(text!==undefined)node.textContent=text;return node;
};
const input=(doc,{type='text',value='',min,max,step,disabled=false,placeholder}={})=>{
 const node=doc.createElement('input');node.type=type;node.value=String(value);
 if(min!==undefined)node.min=String(min);
 if(max!==undefined)node.max=String(max);
 if(step!==undefined)node.step=String(step);
 if(placeholder)node.placeholder=placeholder;
 node.disabled=disabled;return node;
};
const select=(doc,options,value,disabled=false)=>{
 const node=doc.createElement('select');
 for(const [id,title] of options){
  const option=doc.createElement('option');option.value=id;option.textContent=title;node.append(option);
 }
 node.value=value;node.disabled=disabled;return node;
};
export function createCabinServiceManager({doc,host,storage,identity}={}){
 if(!doc?.createElement||!host||typeof identity!=='string'||
    !/^[\w-]{3,128}$/.test(identity))throw Error('Verified manager required');
 let airlineId=undefined,state=initialCabinState(),activeId='basic',working=null,savedKey=null;
 let remote=null,revision=0,ready=false,loading=false,saving=false,loadTicket=0;
 const status=text=>{const box=host.querySelector('#cabin-package-status');
  if(box)box.textContent=text;};
 const find=id=>state.packages.find(p=>p.id===id);
 const read=key=>{try{return storage?.getItem(key)}catch{return null}};
 const persist=async()=>{
  if(!savedKey||loading||saving)return false;
  if(remote){
   if(!ready)return false;
   const currentId=airlineId,api=remote,expectedVersion=revision;
   saving=true;
   try{
    const result=await api.save({airlineId:currentId,state,expectedVersion});
    if(currentId!==airlineId||api!==remote)return false;
    state=cleanCabinState(result.state);revision=result.version;return true;
   }catch(error){
    ready=false;
    status(error?.message==='CABIN_VERSION_CONFLICT'?
     'These cabin settings changed in another session. Reload before editing.':
     'Supabase could not save the change. No flight or money was changed.');
    return false;
   }finally{saving=false}
  }
  try{storage?.setItem(savedKey,JSON.stringify(state));return true}catch{return false}
 };
 const locationLabel=()=>remote?'Supabase for this airline':'this browser';
 const choose=id=>{const found=find(id);if(!found)return;
  activeId=id;working=structuredClone(found);render();
 };
 const textField=(parent,title,control)=>{
  const field=element(doc,'label','cabin-product-field');
  field.append(label(doc,title),control);parent.append(field);return control;
 };
 const render=()=>{
  host.replaceChildren();
  const heading=element(doc,'div','cabin-product-header');
  const title=element(doc,'div');
  title.append(element(doc,'h2','', 'Cabin Services Management'),
   element(doc,'p','hint','Create service packages and assign one to each cabin class. '+(remote?'Package settings are stored in Supabase for your airline; no cash settlement or actual flight changes.':'Local preview: settings are saved in this browser; no flight or cash effects.')));
  heading.append(title);
  const addBtn=element(doc,'button','primary cabin-compact-button','+ New package');
  addBtn.type='button';addBtn.dataset.cabinAction='new';
  addBtn.disabled=!airlineId||loading||saving||(remote&&!ready)||state.packages.length>=9;
  heading.append(addBtn);host.append(heading);
  const body=element(doc,'div','cabin-product-layout');
  const sidebar=element(doc,'aside','cabin-product-sidebar');
  sidebar.append(element(doc,'h3','','Your packages'));
  for(const pkg of state.packages){
   const line=element(doc,'button','cabin-package-choice'+(pkg.id===activeId?' is-active':''));
   line.type='button';line.dataset.cabinChoose=pkg.id;
   line.append(element(doc,'strong','',pkg.name));
   const score=cabinPackageEstimate(pkg).attractiveness;
   line.append(element(doc,'small','',score+'/100 · '+(pkg.id==='basic'?'Default / protected':'Custom package')));
   sidebar.append(line);
  }
  sidebar.append(element(doc,'p','hint','The Basic package is always available and cannot be deleted.'));
  body.append(sidebar);
  const editor=element(doc,'div','cabin-product-editor');
  if(!working)working=structuredClone(createBasicCabinPackage());
  const basic=activeId==='basic';
  const controls=element(doc,'div','cabin-product-titlebar');
  const details=element(doc,'div','cabin-product-title-fields');
  const name=textField(details,'Package name',input(doc,{value:working.name,disabled:basic}));
  name.id='cabin-package-name';name.maxLength=45;
  controls.append(details);
  const buttons=element(doc,'div','cabin-product-actions');
  const duplicate=element(doc,'button','secondary cabin-compact-button','Duplicate');
  duplicate.type='button';duplicate.dataset.cabinAction='duplicate';
  buttons.append(duplicate);
  if(!basic){
   const save=element(doc,'button','primary cabin-compact-button','Save package');
   save.type='button';save.dataset.cabinAction='save';buttons.append(save);
   const remove=element(doc,'button','secondary cabin-compact-button','Delete');
   remove.type='button';remove.dataset.cabinAction='delete';buttons.append(remove);
  }
  controls.append(buttons);editor.append(controls);
  const summary=element(doc,'div','cabin-product-metrics');
  const score=element(doc,'div','cabin-product-metric');
  score.append(element(doc,'span','','Service attractiveness'));
  const rating=element(doc,'strong','','25 / 100');rating.id='cabin-rating';score.append(rating);
  const bar=element(doc,'div','cabin-score-track');
  const fill=element(doc,'div','cabin-score-fill');fill.id='cabin-score-fill';
  bar.append(fill);score.append(bar);
  summary.append(score);
  for(const [id,title] of [['cost','Included-service cost / passenger'],['margin','Indicative paid-item margin / passenger']]){
   const card=element(doc,'div','cabin-product-metric');
   card.append(element(doc,'span','',title));
   const v=element(doc,'strong','','$0.00');v.id='cabin-'+id;card.append(v);
   summary.append(card);
  }
  editor.append(summary);
  const table=element(doc,'div','cabin-product-table');
  const header=element(doc,'div','cabin-product-row cabin-product-table-head');
  for(const t of ['Service / airline cost','Offer to passengers','Free units','Online price (USD)','Onboard price (USD)'])
   header.append(element(doc,'span','',t));
  table.append(header);
  let lastCategory=null;
  for(const item of CABIN_SERVICE_CATALOG){
   if(item.category!==lastCategory){
    const group=element(doc,'h4','cabin-product-category',item.category);
    table.append(group);lastCategory=item.category;
   }
   const current=working.items[item.id];
   const row=element(doc,'div','cabin-product-row');
   row.dataset.cabinItem=item.id;
   const description=element(doc,'div','cabin-product-item-name');
   description.append(element(doc,'strong','',item.name),
    element(doc,'small','',money(item.costCents)+' per unit · game estimate'));
   if(item.condition)description.append(element(doc,'small','',item.condition));
   row.append(description);
   const mode=select(doc,CABIN_MODE_OPTIONS,current.mode,basic);
   mode.dataset.cabinField='mode';row.append(mode);
   const included=['included','hybrid'].includes(current.mode);
   const priceOnline=['online','both','hybrid'].includes(current.mode);
   const priceOnboard=['onboard','both','hybrid'].includes(current.mode);
   const free=input(doc,{type:'number',value:current.freeQty,min:1,max:3,step:1,
    disabled:basic||!included});
   free.dataset.cabinField='freeQty';row.append(free);
   const online=input(doc,{type:'number',value:(current.onlineCents/100).toFixed(2),
    min:0,max:1000,step:.01,disabled:basic||!priceOnline});
   online.dataset.cabinField='onlineCents';row.append(online);
   const onboard=input(doc,{type:'number',value:(current.onboardCents/100).toFixed(2),
    min:0,max:1000,step:.01,disabled:basic||!priceOnboard});
   onboard.dataset.cabinField='onboardCents';row.append(onboard);
   table.append(row);
  }
  editor.append(table);
  editor.append(element(doc,'p','hint',
   'Rating and costs are illustrative game-design figures. Free services assume 55% optional take-up; paid services assume 20% take-up. Aircraft equipment, route rules and catering availability must be checked before operational use.'));
  body.append(editor);host.append(body);
  const classBox=element(doc,'section','cabin-assignment-panel');
  classBox.append(element(doc,'h3','','Default package by cabin class'),
   element(doc,'p','hint','These assignments are planning preferences. Actual aircraft configurations, route sales and passenger demand are not changed.'));
  const grid=element(doc,'div','cabin-assignment-grid');
  for(const [id,title] of CABIN_CLASSES){
   const dropdown=select(doc,state.packages.map(p=>[p.id,p.name]),state.assignments[id],!airlineId);
   dropdown.dataset.cabinClass=id;
   textField(grid,title,dropdown);
  }
  classBox.append(grid);
  const saveAssignments=element(doc,'button','primary cabin-compact-button','Save class assignments');
  saveAssignments.type='button';saveAssignments.dataset.cabinAction='assign';
  saveAssignments.disabled=!airlineId||loading||saving||(remote&&!ready);
  classBox.append(saveAssignments);host.append(classBox);
  const feedback=element(doc,'p','hint cabin-product-status');
  feedback.id='cabin-package-status';feedback.setAttribute('role','status');
  feedback.setAttribute('aria-live','polite');host.append(feedback);
  updateMetrics();
  doc.dispatchEvent(new CustomEvent('airlinerra:refresh-game-select-menus'));
 };
 const updateMetrics=()=>{
  const results=cabinPackageEstimate(working);
  const rating=host.querySelector('#cabin-rating');
  if(rating)rating.textContent=results.attractiveness+' / 100';
  const fill=host.querySelector('#cabin-score-fill');
  if(fill)fill.style.width=results.attractiveness+'%';
  const cost=host.querySelector('#cabin-cost');
  if(cost)cost.textContent=money(results.includedCents);
  const margin=host.querySelector('#cabin-margin');
  if(margin)margin.textContent=money(results.indicativeMarginCents);
 };
 const onChange=event=>{
  if(loading||saving||(remote&&!ready))return;
  const className=event.target.dataset?.cabinClass;
  if(className){return;}
  const item=event.target.closest?.('[data-cabin-item]');
  const field=event.target.dataset?.cabinField;
  if(!item||!field||activeId==='basic')return;
  const id=item.dataset.cabinItem;
  if(!CATALOG.has(id)||!working.items[id])return;
  if(field==='mode'){
   const mode=event.target.value;
   if(!MODES.has(mode))return;
   working.items[id].mode=mode;
   if(['included','hybrid'].includes(mode)&&working.items[id].freeQty===0)
    working.items[id].freeQty=1;
   render();return;
  }
  if(field==='freeQty'){
   const v=Number(event.target.value);
   if(!Number.isInteger(v)||v<1||v>3){status('Free units must be between 1 and 3.');return;}
   working.items[id].freeQty=v;
  }else{
   const value=Number(event.target.value);
   if(!/^\d{1,4}(?:\.\d{1,2})?$/.test(event.target.value)||
      !Number.isFinite(value)||value>1000){
    status('Enter a valid USD price between $0 and $1,000, with up to two decimals.');return;
   }
   working.items[id][field]=Math.round(value*100);
  }
  updateMetrics();
 };
 const onClick=async event=>{
  const button=event.target.closest?.('[data-cabin-action],[data-cabin-choose]');
  if(!button||!host.contains(button))return;
  if(loading||saving||(remote&&!ready)){
    status('Cabin packages are not ready. Check the connection and reload.');return;
   }
   const selected=button.dataset.cabinChoose;
  if(selected){choose(selected);return;}
  const action=button.dataset.cabinAction;
  if(!airlineId){status('Connect a verified airline first.');return;}
  if(action==='new'||action==='duplicate'){
   if(state.packages.length>=9){status('Maximum eight custom cabin packages.');return;}
   const used=new Set(state.packages.map(p=>p.id));
   let number=1;while(used.has('pkg-'+number))number++;
   const pkg=structuredClone(action==='duplicate'?working:createBasicCabinPackage());
   pkg.id='pkg-'+number;pkg.locked=false;
   pkg.name=action==='duplicate'?('Copy of '+working.name).slice(0,45):'New cabin package';
   state.packages.push(pkg);
   choose(pkg.id);
   status('New package created in the editor. Configure it and click Save package.');
   return;
  }
  if(action==='save'){
   if(activeId==='basic')return;
   for(const price of host.querySelectorAll('[data-cabin-field="onlineCents"],[data-cabin-field="onboardCents"]')){
    if(price.disabled)continue;
    const value=String(price.value||'');
    if(!/^\d{1,4}(?:\.\d{1,2})?$/.test(value)||Number(value)>1000){
     status('A paid-item price is invalid. Use $0–$1,000 and up to two decimal places.');
     price.focus();return;
    }
   }
   for(const allowance of host.querySelectorAll('[data-cabin-field="freeQty"]')){
    if(allowance.disabled)continue;
    const n=Number(allowance.value);
    if(!Number.isInteger(n)||n<1||n>3){
     status('Free allowance must be 1–3 units for each included service.');
     allowance.focus();return;
    }
   }
   working.name=String(host.querySelector('#cabin-package-name')?.value||'').trim();
   const next=cleanCabinPackage(working);
   if(!next){status('Name must have 2–45 characters. Review prices and allowances.');return;}
   const i=state.packages.findIndex(p=>p.id===activeId);
   if(i<1)return;
   const old=state.packages[i];state.packages[i]=next;
   if(!await persist()){state.packages[i]=old;return;}
   choose(activeId);status(next.name+' saved in '+locationLabel()+'.');
   return;
  }
  if(action==='delete'){
   if(activeId==='basic')return;
   if(typeof window!=='undefined'&&!window.confirm('Delete this custom cabin service package?'))return;
   const oldState=structuredClone(state);
   state.packages=state.packages.filter(p=>p.id!==activeId);
   for(const key of CLASSES)if(state.assignments[key]===activeId)state.assignments[key]='basic';
   if(!await persist()){state=oldState;return;}
   choose('basic');status('Package deleted. Cabin class assignments reverted to Basic where necessary.');
   return;
  }
  if(action==='assign'){
   const assignments={};
   for(const key of CLASSES){
    const node=host.querySelector('[data-cabin-class="'+key+'"]');
    const id=node?.value;
    if(!find(id)){status('Choose a valid package for all cabin classes.');return;}
    assignments[key]=id;
   }
   const prior=state.assignments;state.assignments=assignments;
   if(!await persist()){state.assignments=prior;return;}
   status('Class assignments saved in '+locationLabel()+'. No flight was modified.');
  }
 };
 host.addEventListener('change',onChange);
 host.addEventListener('click',onClick);
 const updateData=data=>{
   const id=data?.connected&&typeof data?.airline?.id==='string'?data.airline.id:null;
   const api=id&&typeof data?.cabinServiceClient?.read==='function'&&
    typeof data?.cabinServiceClient?.save==='function'?data.cabinServiceClient:null;
   if(id===airlineId&&api===remote)return;
   const ticket=++loadTicket;
   airlineId=id;remote=api;savedKey=id?'airlinerra.cabin.services.v1.'+identity+'.'+id:null;
   revision=0;ready=!remote;loading=Boolean(remote);saving=false;
   let parsed=null;
   if(savedKey&&!remote)try{parsed=JSON.parse(read(savedKey)||'null')}catch{}
   state=cleanCabinState(parsed);activeId='basic';
   working=structuredClone(state.packages[0]);render();
   if(!id){status('Sign in to an airline to save cabin-service designs.');return;}
   if(!remote)return;
   status('Loading cabin packages from Supabase…');
   void remote.read(id).then(result=>{
    if(ticket!==loadTicket||airlineId!==id)return;
    state=cleanCabinState(result.state);revision=result.version;
    ready=true;loading=false;activeId='basic';
    working=structuredClone(state.packages[0]);render();
    status('Cabin packages loaded from Supabase for this airline.');
   }).catch(()=>{
    if(ticket!==loadTicket||airlineId!==id)return;
    loading=false;ready=false;render();
    status('Cabin packages could not be loaded. Editing disabled to protect saved data.');
   });
  };
 updateData({connected:false,airline:null});
 return Object.freeze({
  updateData,
  getPackages:()=>structuredClone(state.packages),
  getAssignments:()=>({...state.assignments}),
  destroy:()=>{host.removeEventListener('change',onChange);host.removeEventListener('click',onClick)}
 });
}
