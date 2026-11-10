/**
 * Airlinerra Cabin Services — airline-scoped PRODUCT PLANNING UI.
 * A local manager design: no server purchases, money movement, demand uplift,
 * supply contract, inventory, aircraft-fit or flight dispatch is asserted.
 * Only fixed, developer-defined catalog data may be shown as supplier costs.
 */
/** Cost model v2: illustrative aircraft-catering supplier cost, not an actual contract.
 * Base unit cost INCLUDES preparation/packing/handling. No online commerce.
 * Stock defaults are per 100 passengers; digital services have usage-based costs. */
export const CABIN_SERVICE_CATALOG=Object.freeze([
 {id:'water',name:'Drinking water',category:'Drinks',costCents:65,weight:0,stock:100,rate:.28,referencePrice:200,condition:'Basic complimentary supply'},
 {id:'coffee',name:'Coffee and tea',category:'Drinks',costCents:150,weight:5,stock:20,rate:.14,referencePrice:400},
 {id:'softdrink',name:'Soft drinks and juice',category:'Drinks',costCents:175,weight:6,stock:25,rate:.18,referencePrice:450},
 {id:'alcohol',name:'Beer and wine',category:'Drinks',costCents:375,weight:5,stock:10,rate:.09,referencePrice:850,condition:'Subject to country, route and age restrictions'},
 {id:'snack',name:'Small snack',category:'Food',costCents:225,weight:8,stock:20,rate:.15,referencePrice:550},
 {id:'sandwich',name:'Sandwich / light meal',category:'Food',costCents:525,weight:9,stock:12,rate:.10,referencePrice:1100},
 {id:'hotmeal',name:'Hot meal',category:'Food',costCents:950,weight:14,stock:10,rate:.07,referencePrice:1900,condition:'Aircraft galley and catering required'},
 {id:'specialmeal',name:'Special dietary meal',category:'Food',costCents:1100,weight:6,stock:3,rate:.018,referencePrice:2200,condition:'Pre-order, galley and catering required'},
 {id:'newspaper',name:'Digital newspapers',category:'Media',costCents:55,weight:3,digital:true,rate:.07,referencePrice:200},
 {id:'wifi',name:'Basic Wi-Fi',category:'Media',costCents:225,weight:10,digital:true,rate:.12,referencePrice:800,condition:'Onboard Wi-Fi equipment required'},
 {id:'fullwifi',name:'Full-speed Wi-Fi',category:'Media',costCents:550,weight:10,digital:true,rate:.055,referencePrice:1600,condition:'Onboard Wi-Fi equipment required'},
 {id:'entertainment',name:'Entertainment',category:'Media',costCents:200,weight:9,digital:true,rate:.10,referencePrice:600,condition:'Compatible aircraft/player devices required'},
 {id:'blanket',name:'Blanket / comfort kit',category:'Comfort',costCents:450,weight:4,stock:10,rate:.06,referencePrice:950},
 {id:'amenity',name:'Amenity kit',category:'Comfort',costCents:675,weight:5,stock:5,rate:.025,referencePrice:1500}
]);
export const CABIN_MODE_OPTIONS=Object.freeze([
 ['off','Not offered'],
 ['included','Included / free'],
 ['onboard','Paid onboard']
]);
export const CABIN_CLASSES=Object.freeze([
 ['economy','Economy'],['premium','Premium Economy'],
 ['business','Business'],['first','First Class']
]);
const CATALOG=new Map(CABIN_SERVICE_CATALOG.map(item=>[item.id,item]));
const MODES=new Set(CABIN_MODE_OPTIONS.map(item=>item[0]));
const CLASSES=new Set(CABIN_CLASSES.map(item=>item[0]));
const cents=num=>Number.isInteger(num)&&num>=0&&num<=100000?num:null;
const money=n=>(n<0?'-$':'$')+(Math.abs(n)/100).toFixed(2);
export const cabinDefaultItems=()=>Object.fromEntries(CABIN_SERVICE_CATALOG.map(item=>[
 item.id,{mode:item.id==='water'?'included':'off',
  freeQty:item.id==='water'?1:0,
  stockPer100:item.id==='water'?100:(item.digital?0:item.stock),
  onlineCents:item.referencePrice,onboardCents:item.referencePrice}
]));
export const createBasicCabinPackage=()=>({
 id:'basic',name:'Basic Cabin Service',locked:true,items:cabinDefaultItems()
});
const cleanItem=(value,id)=>{
 const v=value&&typeof value==='object'&&!Array.isArray(value)?value:{};
 const catalog=CATALOG.get(id);
 // Hybrid previously promised a free unit, so migrate it to Included / free.
 // Older online-only and online+onboard prices become onboard-only.
 const mode=v.mode==='hybrid'?'included':
  ['online','both'].includes(v.mode)?'onboard':
  MODES.has(v.mode)?v.mode:(id==='water'?'included':'off');
 const unitPrice=cents(v.onboardCents)??catalog.referencePrice;
 const stockPer100=mode==='included'?100:mode==='onboard'&&!catalog.digital?
  (Number.isSafeInteger(v.stockPer100)&&v.stockPer100>=0&&v.stockPer100<=200?
   v.stockPer100:catalog.stock):0;
 return {
  mode,freeQty:mode==='included'?1:0,
  stockPer100,
  // The unused v1 storage key is mirrored for backwards compatibility.
  onlineCents:unitPrice,onboardCents:unitPrice
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
/** A deterministic, inspectable forecast, not a passenger purchase or ledger.
 * Airlines pay for all physical items loaded (conservative no-carryover planning).
 * Digital access is licensed only on use and needs hardware on the real flight.
 * Flight length/reputation/price influence expected sales; no guaranteed revenue. */
export function forecastCabinServiceFlight(pkg,{passengers=100,durationMinutes=180,reputationScore=50}={}){
 if(!Number.isSafeInteger(passengers)||passengers<0||passengers>1000||
    !Number.isFinite(durationMinutes)||durationMinutes<15||durationMinutes>24*60||
    !Number.isFinite(reputationScore)||reputationScore<0||reputationScore>100)
  throw Error('Invalid cabin forecast assumptions');
 const reputationFactor=.7+.006*reputationScore;
 let includedScore=0,paidOfferCount=0;
 const rows=CABIN_SERVICE_CATALOG.map(item=>{
  const selection=cleanItem(pkg?.items?.[item.id],item.id);
  const offered=selection.mode!=='off',included=selection.mode==='included';
  const paid=selection.mode==='onboard',unitCost=item.costCents;
  const lengthHours=durationMinutes/60;
  const food=['hotmeal','specialmeal'].includes(item.id);
  // Short-haul hot meals have tiny demand; longer flights raise meal take-up.
  const lengthFactor=food?
   (lengthHours<=1?.04:lengthHours<=2?.38:lengthHours<=3?.9:
    Math.min(1.9,.9+(lengthHours-3)*.27)):
   item.id==='sandwich'?Math.min(1.65,Math.max(.35,lengthHours/2.6)):
   item.id==='snack'?Math.min(1.55,Math.max(.45,lengthHours/2.4)):
   Math.min(1.6,Math.max(.5,.65+lengthHours*.13));
  const priceFactor=paid?Math.min(1.35,Math.max(.25,
    Math.pow(item.referencePrice/Math.max(selection.onboardCents,100),.8))):1;
  const purchaseRate=paid?Math.min(.65,item.rate*lengthFactor*reputationFactor*priceFactor):0;
  const expectedWants=paid?Math.min(passengers,Math.round(passengers*purchaseRate)):0;
  const loadedUnits=included?(item.digital?0:passengers):
   paid&&!item.digital?Math.ceil(passengers*selection.stockPer100/100):0;
  const expectedSales=paid?(item.digital?expectedWants:Math.min(expectedWants,loadedUnits)):0;
  // Physical catering counts loaded units including unsold/expired products.
  const costUnits=item.digital?(included?passengers:expectedSales):loadedUnits;
  const airlineCostCents=offered?costUnits*unitCost:0;
  const onboardRevenueCents=paid?expectedSales*selection.onboardCents:0;
  const cannotServeShortMeal=food&&durationMinutes<80;
  if(included&&!cannotServeShortMeal)includedScore+=item.weight;
  if(paid&&expectedSales>0)paidOfferCount++;
  return {
   id:item.id,mode:selection.mode,unitCostCents:unitCost,
   loadedUnits,costUnits,expectedSales,purchaseRate,
   stockPer100:selection.stockPer100,passengerPriceCents:paid?selection.onboardCents:0,
   airlineCostCents,onboardRevenueCents,
   unsoldUnits:paid&&!item.digital?Math.max(0,loadedUnits-expectedSales):0,
   equipmentRequired:Boolean(item.condition),
   shortFlightIncompatible:cannotServeShortMeal&&included
  };
 });
 const paidBonus=Math.min(2,Math.round(paidOfferCount*.5));
 const attractiveness=Math.min(100,25+includedScore+paidBonus);
 const totalCostCents=rows.reduce((n,r)=>n+r.airlineCostCents,0);
 const onboardRevenueCents=rows.reduce((n,r)=>n+r.onboardRevenueCents,0);
 return {attractiveness,relativeToBasic:attractiveness-25,paidBonus,
  totalCostCents,onboardRevenueCents,netCostCents:totalCostCents-onboardRevenueCents,
  passengers,durationMinutes,reputationScore,rows,
  forecastOnly:true,ledgerPosted:false};
}
/** Legacy short summary for package directory and compatibility consumers. */
export function cabinPackageEstimate(pkg){
 const flight=forecastCabinServiceFlight(pkg);
 const unit=val=>Math.round(val/Math.max(1,flight.passengers));
 return {...flight,
  includedCents:unit(flight.rows.filter(r=>r.mode==='included')
   .reduce((s,r)=>s+r.airlineCostCents,0)),
  paidRevenueCents:unit(flight.onboardRevenueCents),
  indicativeMarginCents:unit(flight.onboardRevenueCents-
   flight.rows.filter(r=>r.mode==='onboard').reduce((s,r)=>s+r.airlineCostCents,0)),
  totalCostPerPassengerCents:unit(flight.totalCostCents),
  rows:flight.rows.map(r=>({...r,costCents:unit(r.airlineCostCents),
   paidRevenueCents:unit(r.onboardRevenueCents),
   paidMarginCents:unit(r.onboardRevenueCents-r.airlineCostCents)}))}
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
 let previewPassengers=100,previewMinutes=180,previewReputation=50;
 const status=text=>{const box=host.querySelector('#cabin-package-status');
  if(box)box.textContent=text;};
 const find=id=>state.packages.find(p=>p.id===id);
 const read=key=>{try{return storage?.getItem(key)}catch{return null}};
 const notifyRoutes=()=>{
  if(airlineId)doc.dispatchEvent(new CustomEvent('airlinerra:cabin-packages-updated',{detail:{airlineId}}));
 };
 const persist=async()=>{
  if(!savedKey||loading||saving)return false;
  if(remote){
   if(!ready)return false;
   const currentId=airlineId,api=remote,expectedVersion=revision;
   saving=true;
   try{
    const result=await api.save({airlineId:currentId,state,expectedVersion});
    if(currentId!==airlineId||api!==remote)return false;
    state=cleanCabinState(result.state);revision=result.version;notifyRoutes();return true;
   }catch(error){
    ready=false;
    status(error?.message==='CABIN_VERSION_CONFLICT'?
     'These cabin settings changed in another session. Reload before editing.':
     'Supabase could not save the change. No flight or money was changed.');
    return false;
   }finally{saving=false}
  }
  try{storage?.setItem(savedKey,JSON.stringify(state));notifyRoutes();return true}catch{return false}
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
  title.append(element(doc,'p','hint cabin-product-lead','Choose a package to edit its passenger offers and prices. '+(remote?'Settings are saved to your airline in Supabase; flights and money are not changed.':'Local preview: saved in this browser; no flight or cash effects.')));
  heading.append(title);
  const addBtn=element(doc,'button','primary cabin-compact-button','+ New package');
  addBtn.type='button';addBtn.dataset.cabinAction='new';
  addBtn.disabled=!airlineId||loading||saving||(remote&&!ready)||state.packages.length>=9;
  heading.append(addBtn);host.append(heading);
  const body=element(doc,'div','cabin-product-layout');
  const sidebar=element(doc,'aside','cabin-product-sidebar');
  sidebar.append(element(doc,'h3','','Your packages'));
  for(const pkg of state.packages){
   const entry=element(doc,'div','cabin-package-entry');
   const line=element(doc,'button','cabin-package-choice'+(pkg.id===activeId?' is-active':''));
   line.type='button';line.dataset.cabinChoose=pkg.id;
   line.append(element(doc,'strong','',pkg.name));
   const score=cabinPackageEstimate(pkg).attractiveness;
   line.append(element(doc,'small','',score+'/100 · '+(pkg.id==='basic'?'Default / protected':'Custom package')));
   entry.append(line);
   if(pkg.id!=='basic'){
    const remove=element(doc,'button','cabin-package-remove','Delete');
    remove.type='button';remove.dataset.cabinAction='delete';remove.dataset.cabinId=pkg.id;
    remove.setAttribute('aria-label','Delete '+pkg.name);entry.append(remove);
   }
   sidebar.append(entry);
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
  const assumptions=element(doc,'div','cabin-preview-assumptions');
  const pax=input(doc,{type:'number',value:previewPassengers,min:1,max:1000,step:1});
  pax.id='cabin-preview-passengers';
  textField(assumptions,'Passengers (example flight)',pax);
  const hours=input(doc,{type:'number',value:previewMinutes/60,min:.25,max:24,step:.25});
  hours.id='cabin-preview-hours';
  textField(assumptions,'Flight duration (hours)',hours);
  assumptions.append(element(doc,'p','hint',
   'Neutral reputation 50/100 until the real airline rating is connected. Figures are forecasts only.'));
  editor.append(assumptions);
  const summary=element(doc,'div','cabin-product-metrics');
  const score=element(doc,'div','cabin-product-metric');
  score.append(element(doc,'span','','Service attractiveness · 0–100'));
  const rating=element(doc,'strong','','25 / 100');rating.id='cabin-rating';score.append(rating);
  const bar=element(doc,'div','cabin-score-track');
  const fill=element(doc,'div','cabin-score-fill');fill.id='cabin-score-fill';
  bar.append(fill);score.append(bar);summary.append(score);
  for(const [id,title] of [['cost','Airline cost for example flight'],
   ['sales','Expected onboard sales · not guaranteed'],
   ['net','Net service cost for example flight']]){
   const card=element(doc,'div','cabin-product-metric');
   card.append(element(doc,'span','',title));
   const value=element(doc,'strong','','$0.00');value.id='cabin-'+id;card.append(value);
   summary.append(card);
  }
  editor.append(summary);
  const table=element(doc,'div','cabin-product-table');
  const header=element(doc,'div','cabin-product-row cabin-product-table-head');
  for(const title of ['Service · airline cost per unit','Offer to passengers',
   'Units loaded / 100 passengers','Passenger price onboard'])
   header.append(element(doc,'span','',title));
  table.append(header);
  let lastCategory=null;
  for(const item of CABIN_SERVICE_CATALOG){
   if(item.category!==lastCategory){
    table.append(element(doc,'h4','cabin-product-category',item.category));
    lastCategory=item.category;
   }
   const current=working.items[item.id],row=element(doc,'div','cabin-product-row');
   row.dataset.cabinItem=item.id;
   const appendField=(title,control)=>{
    const cell=element(doc,'label','cabin-product-cell');
    cell.append(element(doc,'span','cabin-mobile-label',title),control);
    row.append(cell);
   };
   const description=element(doc,'div','cabin-product-item-name');
   description.append(element(doc,'strong','',item.name),
    element(doc,'small','cabin-item-unit-cost',money(item.costCents)+' per unit · game cost estimate'));
   if(item.condition)description.append(element(doc,'small','',item.condition));
   const inventory=element(doc,'small','cabin-item-inventory','');
   inventory.dataset.cabinInventory=item.id;
   description.append(inventory);row.append(description);
   const mode=select(doc,CABIN_MODE_OPTIONS,current.mode,basic);
   mode.dataset.cabinField='mode';appendField('Offer to passengers',mode);
   const paid=current.mode==='onboard',included=current.mode==='included';
   const stock=input(doc,{type:'number',
    value:included?100:paid&&!item.digital?current.stockPer100:0,
    min:0,max:200,step:1,disabled:basic||!paid||item.digital});
   stock.dataset.cabinField='stockPer100';
   appendField(item.digital?'Digital on demand':'Units loaded / 100 passengers',stock);
   const onboard=input(doc,{type:'number',value:(paid?current.onboardCents/100:0).toFixed(2),
    min:0,max:1000,step:.01,disabled:basic||!paid});
   onboard.dataset.cabinField='onboardCents';
   appendField('Passenger price onboard (USD)',onboard);
   table.append(row);
  }
  editor.append(table);
  editor.append(element(doc,'p','hint',
   'Included / free: budget one unit for every passenger. Paid onboard: budget each physical unit loaded, including unsold stock. Digital access costs accrue per use. Flight duration, reputation and price affect estimated sales; paid offerings add at most two attractiveness points in total. This is not live revenue or a confirmed aircraft capability.'));
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
  const results=forecastCabinServiceFlight(working,{
   passengers:previewPassengers,durationMinutes:previewMinutes,reputationScore:previewReputation
  });
  const rating=host.querySelector('#cabin-rating');
  if(rating)rating.textContent=results.attractiveness+' / 100';
  const fill=host.querySelector('#cabin-score-fill');
  if(fill)fill.style.width=results.attractiveness+'%';
  const cost=host.querySelector('#cabin-cost');
  if(cost)cost.textContent=money(results.totalCostCents);
  const sales=host.querySelector('#cabin-sales');
  if(sales)sales.textContent=money(results.onboardRevenueCents);
  const net=host.querySelector('#cabin-net');
  if(net)net.textContent=money(results.netCostCents);
  for(const row of results.rows){
   const count=host.querySelector('[data-cabin-inventory="'+row.id+'"]');
   if(!count)continue;
   count.textContent=row.mode==='off'?'Not offered':
    row.mode==='included'?'Included · '+row.costUnits+' units budgeted':
    row.loadedUnits>0?row.loadedUnits+' loaded · '+row.expectedSales+' expected sold':
    row.expectedSales+' estimated digital uses';
  }
 };
 const onChange=event=>{
  const id=event.target?.id;
  if(id==='cabin-preview-passengers'||id==='cabin-preview-hours'){
   const value=Number(event.target.value);
   if(id==='cabin-preview-passengers'&&Number.isSafeInteger(value)&&value>=1&&value<=1000)
    previewPassengers=value;
   else if(id==='cabin-preview-hours'&&Number.isFinite(value)&&value>=.25&&value<=24)
    previewMinutes=Math.round(value*60);
   else{status('Enter 1–1,000 passengers and a duration of 0.25–24 hours.');return;}
   updateMetrics();return;
  }
  if(loading||saving||(remote&&!ready))return;
  const item=event.target.closest?.('[data-cabin-item]');
  const field=event.target.dataset?.cabinField;
  if(!item||!field||activeId==='basic')return;
  const rowId=item.dataset.cabinItem;
  if(!CATALOG.has(rowId)||!working.items[rowId])return;
  if(field==='mode'){
   working.name=String(host.querySelector('#cabin-package-name')?.value||working.name);
   const mode=event.target.value;
   if(!MODES.has(mode))return;
   working.items[rowId].mode=mode;
   working.items[rowId].freeQty=mode==='included'?1:0;
   working.items[rowId].stockPer100=mode==='included'?100:
    mode==='onboard'?(CATALOG.get(rowId).digital?0:
     (working.items[rowId].stockPer100||CATALOG.get(rowId).stock)):0;
   render();return;
  }
  if(field==='stockPer100'){
   const value=Number(event.target.value);
   if(!Number.isSafeInteger(value)||value<0||value>200){
    status('Enter 0–200 loaded units per 100 passengers.');return;
   }
   working.items[rowId].stockPer100=value;
  }else if(field==='onboardCents'){
   const value=Number(event.target.value);
   if(!/^\d{1,4}(?:\.\d{1,2})?$/.test(event.target.value)||
      !Number.isFinite(value)||value>1000){
    status('Passenger price must be $0–$1,000 with two decimals.');return;
   }
   working.items[rowId].onboardCents=Math.round(value*100);
   working.items[rowId].onlineCents=working.items[rowId].onboardCents;
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
   for(const price of host.querySelectorAll('[data-cabin-field="onboardCents"]')){
    if(price.disabled)continue;
    const value=String(price.value||'');
    if(!/^\d{1,4}(?:\.\d{1,2})?$/.test(value)||Number(value)>1000){
     status('A paid-item price is invalid. Use $0–$1,000 and up to two decimal places.');
     price.focus();return;
    }
   }
   for(const stock of host.querySelectorAll('[data-cabin-field="stockPer100"]')){
   if(stock.disabled)continue;
   const units=Number(stock.value);
   if(!Number.isSafeInteger(units)||units<0||units>200){
    status('Loaded stock must be 0–200 units per 100 passengers.');stock.focus();return;
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
   const deleteId=button.dataset.cabinId||activeId;
   if(deleteId==='basic'||!find(deleteId))return;
   if(typeof window!=='undefined'&&!window.confirm(
    'Delete this custom cabin service package? Existing planning routes retain their saved selection until edited.'))return;
   const oldState=structuredClone(state);
   state.packages=state.packages.filter(p=>p.id!==deleteId);
   for(const key of CLASSES)if(state.assignments[key]===deleteId)state.assignments[key]='basic';
   if(!await persist()){state=oldState;render();return;}
   choose(activeId===deleteId?'basic':activeId);
   status('Custom package deleted. Cabin class defaults returned to Basic where necessary.');
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
   if(!remote){notifyRoutes();return;}
   status('Loading cabin packages from Supabase…');
   void remote.read(id).then(result=>{
    if(ticket!==loadTicket||airlineId!==id)return;
    state=cleanCabinState(result.state);revision=result.version;
    ready=true;loading=false;activeId='basic';
    working=structuredClone(state.packages[0]);render();
    status('Cabin packages loaded from Supabase for this airline.');notifyRoutes();
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
   isReady:()=>Boolean(airlineId)&&!loading&&ready,
  destroy:()=>{host.removeEventListener('change',onChange);host.removeEventListener('click',onClick)}
 });
}
