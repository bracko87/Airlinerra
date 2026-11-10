/** Owner-scoped Airlinerra cabin planning UI.
 * Layouts use model reference capacity as GAME space units, never as certification.
 * Live aircraft installed layout, flight schedules and cash are immutable here.
 */
const CLASSES=[
 {key:'economy',label:'Economy',defaultCode:'eco_standard',color:'#4b86c7'},
 {key:'premium',label:'Premium Economy',defaultCode:'premium_standard',color:'#27a2a2'},
 {key:'business',label:'Business',defaultCode:'business_standard',color:'#bc874c'},
 {key:'first',label:'First Class',defaultCode:'first_standard',color:'#a06bb8'}
];
export const cabinClasses=Object.freeze(CLASSES.map(c=>Object.freeze({...c})));
export function standardCabinPlan(seats){
 const count=Math.max(0,Math.min(850,Math.floor(Number(seats)||0)));
 return {economy:count,premium:0,business:0,first:0,
  economyType:'eco_standard',premiumType:'premium_standard',
  businessType:'business_standard',firstType:'first_standard'};
}
export function evaluateCabinPlan(plan,seatTypes,referenceUnits){
 const defs=new Map((seatTypes||[]).map(s=>[s.code,s]));
 const cap=Number(referenceUnits);
 let used=0,cost=0,count=0;const classes=[];
 for(const c of CLASSES){
  const n=plan?.[c.key],code=plan?.[c.key+'Type'],type=defs.get(code);
  if(!Number.isInteger(n)||n<0||n>850||!type||type.cabinClass!==c.key)
   return {valid:false,reason:'Select a valid seat type and nonnegative seat count for each class.'};
  const space=n*Number(type.spaceUnits);
  used+=space;cost+=n*Number(type.installUsd);count+=n;
  classes.push({key:c.key,label:c.label,color:c.color,seats:n,code,
   pitch:Number(type.pitchInches),space,perSeat:Number(type.spaceUnits),
   style:type.label});
 }
 if(!(cap>0))return {valid:false,reason:'Aircraft passenger cabin reference is unavailable.'};
 if(count===0)return {valid:false,reason:'Add at least one passenger seat.'};
 if(used>cap+0.000001)return {valid:false,reason:'The chosen seats exceed this aircraft\'s available cabin space.',
  used:Math.round(used*100)/100,available:cap,count};
 return {valid:true,count,used:Math.round(used*100)/100,available:cap,
  equipmentUsd:Math.round(cost),classes,
  refitHours:(plan.premium+plan.business+plan.first)>0?48:24};
}
const create=(doc,tag,className,text)=>{
 const el=doc.createElement(tag);if(className)el.className=className;
 if(text!==undefined)el.textContent=String(text);return el;
};
const ns='http://www.w3.org/2000/svg';
function svgNode(doc,tag,attributes={}){
 const el=doc.createElementNS(ns,tag);
 for(const [name,value] of Object.entries(attributes))el.setAttribute(name,String(value));
 return el;
}
export function renderCabinFloorplan(doc,svg,plan,evaluation,referenceUnits){
 if(!svg||typeof svg.replaceChildren!=='function')return;
 svg.replaceChildren();
 svg.setAttribute('role','img');
 svg.setAttribute('aria-label','Illustrative top view of '+(evaluation.count||0)+' cabin seats. Not a certified aircraft floor plan.');
 if(!evaluation.valid)return;
 const cap=Number(referenceUnits),wide=cap>245,veryWide=cap>430;
 const interiorWidth=veryWide?280:wide?235:cap<55?126:172;
 const center=185,left=center-interiorWidth/2,right=center+interiorWidth/2;
 const aisle=wide?22:20;
 const profiles={
  economy:veryWide?[3,4,3]:wide?[2,4,2]:cap<55?[1,1]:[3,3],
  premium:wide?[2,3,2]:cap<55?[1,1]:[2,2],
  business:wide?[1,2,1]:[2,2],
  first:wide?[1,2,1]:[1,1]
 };
 let y=74;const shapes=[];
 for(const c of evaluation.classes){
  if(!c.seats)continue;
  const profile=profiles[c.key],perRow=profile.reduce((a,b)=>a+b,0);
  const rows=Math.ceil(c.seats/perRow),pitch=Math.max(17,(c.pitch/30)*19);
  const seatWidth=c.key==='first'?19:c.key==='business'?16:11;
  let remain=c.seats;
  for(let r=0;r<rows;r++){
   const n=Math.min(remain,perRow),gap=aisle;
   const totalSeats=perRow*seatWidth,spaces=(profile.length-1)*gap;
   const x0=center-(totalSeats+spaces)/2;
   let index=0;
   for(let section=0;section<profile.length;section++){
    for(let seat=0;seat<profile[section]&&index<n;seat++){
     const x=x0+(index+section*0)*seatWidth+section*gap;
     shapes.push(svgNode(doc,'rect',{x:x+1,y,width:seatWidth-2,height:Math.min(16,pitch-3),
      rx:3,fill:c.color,stroke:'#3c5266','stroke-width':0.45}));
     index++;
    }
   }
   remain-=n;y+=pitch;
  }
  y+=14;
 }
 const height=Math.max(270,y+75);
 svg.setAttribute('viewBox','0 0 370 '+height);
 svg.setAttribute('preserveAspectRatio','xMidYMin meet');
 svg.append(svgNode(doc,'path',{d:'M '+center+' 5 C '+(left-32)+' 35 '+left+' 68 '+left+' 115 L '+left+' '+(height-60)+
  ' Q '+left+' '+(height-12)+' '+center+' '+(height-9)+' Q '+right+' '+(height-12)+' '+right+' '+(height-60)+
  ' L '+right+' 115 C '+right+' 68 '+(right+32)+' 35 '+center+' 5 Z',
  fill:'#f4f8fc',stroke:'#9ab0c6','stroke-width':2}));
 // Front/back galley and lavatory zones are indicative reserved space.
 const zones=[[52,'GALLEY'],[height-57,'LAV / GALLEY']];
 for(const [zoneY,label] of zones){
  svg.append(svgNode(doc,'rect',{x:left+10,y:zoneY,width:interiorWidth-20,height:25,
   rx:4,fill:'#dce5ec',stroke:'#bbcbd9'}));
  const t=svgNode(doc,'text',{x:center,y:zoneY+16,'font-size':10,
   'text-anchor':'middle',fill:'#506980'});t.textContent=label;svg.append(t);
 }
 for(const seat of shapes)svg.append(seat);
 // Exit marks are intentionally NOT drawn: true aircraft exit locations and
 // obstruction zones must be imported from certified model-specific geometry.
 const note=svgNode(doc,'text',{x:center,y:height-21,'font-size':9,
  'text-anchor':'middle',fill:'#53677e'});
 note.textContent='Exit geometry not certified';svg.append(note);
}
function appendRow(doc,table,c,typeList,plan,onEdit){
 const row=create(doc,'div','cabin-designer-row');
 const label=create(doc,'strong','',c.label);
 const select=create(doc,'select');
 select.setAttribute('aria-label',c.label+' seat style');
 for(const seat of typeList.filter(s=>s.cabinClass===c.key)){
  const option=doc.createElement('option');option.value=seat.code;
  option.textContent=seat.label+' · '+seat.spaceUnits+'× space';
  select.append(option);
 }
 select.value=plan[c.key+'Type'];select.addEventListener('change',()=>{
  plan[c.key+'Type']=select.value;onEdit();
 });
 const input=create(doc,'input');input.type='number';input.min='0';input.max='850';input.step='1';
 input.value=String(plan[c.key]);input.setAttribute('aria-label',c.label+' seat count');
 input.addEventListener('input',()=>{
  const n=Number(input.value);
  plan[c.key]=Number.isInteger(n)&&n>=0&&n<=850?n:-1;onEdit();
 });
 const indicator=create(doc,'span','cabin-designer-unit','—');
 row.append(label,select,input,indicator);table.append(row);
 return {indicator,input,select};
}
export function createCabinConfigurationManager({doc,host,factoryHost,onDirectoryUpdate,onFactoryLayoutChange}={}){
 if(!doc||!host)throw Error('Cabin planner needs an existing page host');
 let current={connected:false,airline:null,fleetClient:null};
 let loaded=null,selectedId=null,plan=null,factoryPlan=null,factoryConfigurationId=null;
 let pendingFactoryOffer=null;
 let version=0;let renderedRows=[],factoryRows=[];
 let installedDisplay=null,usageLabel=null,statusLabel=null,previewSvg=null,siteSelect=null;
 let factoryUsage=null,factorySvg=null,factoryMessage=null;
 const currency=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);
 function selectedAircraft(){return loaded?.aircraft?.find(a=>a.aircraftInventoryId===selectedId)||null}
 function modelPlan(a){
  if(!a)return standardCabinPlan(0);
  if(a.draftEconomy!==null&&a.draftEconomy!==undefined)
   return {economy:a.draftEconomy,premium:a.draftPremium,business:a.draftBusiness,first:a.draftFirst,
    economyType:a.draftEconomyType,premiumType:a.draftPremiumType,
    businessType:a.draftBusinessType,firstType:a.draftFirstType};
  return standardCabinPlan(a.standardEconomy);
 }
 function renderFactory(){
  if(!factoryHost)return;
  const factory=pendingFactoryOffer;
  if(!factory){factoryHost.textContent='Choose a passenger aircraft configuration to preview its seats.';return}
  if(factory.useType==='cargo'){factoryHost.textContent='Cargo aircraft: passenger cabin customization is not applicable.';return}
  if(!loaded?.seatTypes?.length){factoryHost.textContent='Loading seat catalog…';return}
  if(factoryConfigurationId!==factory.configurationId||!factoryPlan){
   factoryConfigurationId=factory.configurationId;factoryPlan=standardCabinPlan(factory.referenceSeats);
  }
  factoryHost.replaceChildren();
  factoryHost.append(create(doc,'h4','','Factory passenger cabin'));
  factoryHost.append(create(doc,'p','hint','Standard Economy seats are included. Customize a layout below to preview space. A nonstandard factory interior is not attached to an order yet.'));
  const main=create(doc,'div','cabin-designer-grid'),controls=create(doc,'div','cabin-designer-controls');
  const header=create(doc,'div','cabin-designer-row cabin-designer-head');
  ['Class','Seat style','Seats','Units used'].forEach(x=>header.append(create(doc,'span','',x)));
  controls.append(header);
  factoryRows=[];
  for(const c of CLASSES)factoryRows.push(appendRow(doc,controls,c,loaded.seatTypes,factoryPlan,updateFactory));
  factoryUsage=create(doc,'p','cabin-designer-status','');
  const standard=create(doc,'button','secondary cabin-compact-action','Use standard layout');
  standard.type='button';standard.addEventListener('click',()=>{
   factoryPlan=standardCabinPlan(factory.referenceSeats);renderFactory();
  });
  controls.append(factoryUsage,standard);
  const visual=create(doc,'div','cabin-designer-visual');
  factorySvg=svgNode(doc,'svg',{});visual.append(factorySvg);
  main.append(controls,visual);factoryHost.append(main);
  factoryMessage=create(doc,'p','hint','');factoryHost.append(factoryMessage);
  updateFactory();
 }
 function updateFactory(){
  const f=pendingFactoryOffer;if(!f||!factoryPlan||!factoryUsage)return;
  const evaluation=evaluateCabinPlan(factoryPlan,loaded.seatTypes,f.referenceSeats);
  const standard=factoryPlan.economy===Number(f.referenceSeats)&&
   factoryPlan.economyType==='eco_standard'&&
   factoryPlan.premium===0&&factoryPlan.business===0&&factoryPlan.first===0;
  factoryUsage.textContent=evaluation.valid?
   evaluation.count+' seats · '+evaluation.used+'/'+evaluation.available+
    ' cabin units · '+(standard?'Standard factory cabin':'Custom factory draft'):
   evaluation.reason+' Used '+(evaluation.used??'—')+'/'+(evaluation.available??'—')+' units';
  for(const r of factoryRows){
   const c=CLASSES[factoryRows.indexOf(r)];const t=loaded.seatTypes.find(t=>t.code===factoryPlan[c.key+'Type']);
   r.indicator.textContent=t?(Number(factoryPlan[c.key])*Number(t.spaceUnits)).toFixed(1):'—';
  }
  if(evaluation.valid)renderCabinFloorplan(doc,factorySvg,factoryPlan,evaluation,f.referenceSeats);
  else factorySvg?.replaceChildren();
  factoryMessage.textContent=standard?'Standard seats will be included in the aircraft price.':
   'Custom seat orders need the future factory-installation contract. For now they are a design preview, not a paid order.';
  try{onFactoryLayoutChange?.()}catch{console.warn('Factory layout order control unavailable')}
 }
 function getFactoryPlan(){
  const f=pendingFactoryOffer;
  if(!f||f.useType==='cargo')return {standard:true,valid:true};
  if(!loaded||!factoryPlan)return {standard:false,valid:false,reason:'Cabin preview not yet loaded'};
  const val=evaluateCabinPlan(factoryPlan,loaded.seatTypes,f.referenceSeats);
  return {...val,standard:val.valid&&factoryPlan.economy===Number(f.referenceSeats)&&
   factoryPlan.economyType==='eco_standard'&&
   factoryPlan.premium===0&&factoryPlan.business===0&&factoryPlan.first===0};
 }
 function render(){
  host.replaceChildren();
  if(!current.connected||!current.airline?.id){
   host.textContent='Connect an airline to view its actual cabin configurations.';return}
  if(!loaded){host.textContent='Loading cabin configuration database…';return}
  const list=loaded.aircraft||[];
  const heading=create(doc,'h3','','Your aircraft cabins');host.append(heading);
  const choose=create(doc,'label','cabin-choose','Aircraft');
  const chooseSelect=create(doc,'select');chooseSelect.id='cabin-owned-selector';
  for(const aircraft of list){
   const option=doc.createElement('option');option.value=aircraft.aircraftInventoryId;
   option.textContent=aircraft.manufacturer+' '+aircraft.model+' · '+aircraft.registration;
   chooseSelect.append(option);
  }
  if(!list.length){host.append(create(doc,'p','hint','No registered aircraft yet.'));return}
  if(!list.some(a=>a.aircraftInventoryId===selectedId))selectedId=list[0].aircraftInventoryId;
  chooseSelect.value=selectedId;
  chooseSelect.addEventListener('change',()=>{
   selectedId=chooseSelect.value;plan=modelPlan(selectedAircraft());render()
  });
  choose.append(chooseSelect);host.append(choose);
  const aircraft=selectedAircraft();
  installedDisplay=create(doc,'p','cabin-installed-note','');
  host.append(installedDisplay);
  if(aircraft.useType==='cargo'){
   host.append(create(doc,'p','hint','Cargo airframe: no passenger seating layout.'));return;
  }
  if(!plan)plan=modelPlan(aircraft);
  const grid=create(doc,'div','cabin-designer-grid'),controls=create(doc,'div','cabin-designer-controls');
  const head=create(doc,'div','cabin-designer-row cabin-designer-head');
  ['Class','Seat style','Seats','Units used'].forEach(x=>head.append(create(doc,'span','',x)));
  controls.append(head);renderedRows=[];
  for(const c of CLASSES)renderedRows.push(appendRow(doc,controls,c,loaded.seatTypes,plan,updateLayout));
  usageLabel=create(doc,'p','cabin-designer-status','');
  const buttons=create(doc,'div','cabin-designer-actions');
  const standard=create(doc,'button','secondary cabin-compact-action','Use standard');
  standard.type='button';standard.addEventListener('click',()=>{
   plan=standardCabinPlan(aircraft.standardEconomy);render();
  });
  const save=create(doc,'button','primary cabin-compact-action','Save cabin design');
  save.id='cabin-draft-save';save.type='button';
  save.addEventListener('click',async()=>{
   const value=evaluateCabinPlan(plan,loaded.seatTypes,aircraft.referenceUnits);
   if(!value.valid||!current.fleetClient?.saveCabinDraft)return;
   save.disabled=true;statusLabel.textContent='Saving approved-space cabin draft…';
   const payload={airlineId:current.airline.id,aircraftInventoryId:aircraft.aircraftInventoryId,...plan};
   try{
    const result=await current.fleetClient.saveCabinDraft(payload);
    if(result?.status!=='draft_saved_not_installed'||result?.aircraftInventoryId!==aircraft.aircraftInventoryId)
     throw Error('Cabin draft was not confirmed');
    Object.assign(aircraft,{draftEconomy:plan.economy,draftPremium:plan.premium,
     draftBusiness:plan.business,draftFirst:plan.first,
     draftEconomyType:plan.economyType,draftPremiumType:plan.premiumType,
     draftBusinessType:plan.businessType,draftFirstType:plan.firstType});
    statusLabel.textContent='Cabin design saved to your airline. The installed cabin has NOT changed. Estimated refit '+result.indicativeDowntimeHours+' hours. No payment or aircraft grounding.';
   }catch{
    statusLabel.textContent='Could not save this cabin draft. Installed seats remain unchanged.';
   }finally{save.disabled=false}
  });
  buttons.append(standard,save);controls.append(usageLabel,buttons);
  const visual=create(doc,'div','cabin-designer-visual'),legend=create(doc,'p','hint',
   'Top-down cabin: seats use different pitch and spacing. Galley and lavatory areas are indicative. Exact exit positions, evacuation limits and certification are not modeled.');
  previewSvg=svgNode(doc,'svg');
  visual.append(previewSvg,legend);grid.append(controls,visual);host.append(grid);
  statusLabel=create(doc,'p','hint','');statusLabel.setAttribute('role','status');
  host.append(statusLabel);
  const siteTitle=create(doc,'h4','','Where a cabin refit can be planned');
  host.append(siteTitle);
  const approved=(loaded.refitSites||[]).filter(s=>s.aircraftInventoryId===selectedId);
  const refitLabel=create(doc,'label','cabin-choose','Maintenance / cabin refit facility');
  siteSelect=create(doc,'select');siteSelect.id='cabin-refit-site';
  siteSelect.append(new Option('Choose an aircraft-type-matched facility',''));
  for(const site of approved){
   const o=new Option(site.airportName+' ('+site.airportCode+') · '+site.provider,site.airportKey);
   siteSelect.append(o);
  }
  siteSelect.addEventListener('change',updateLayout);
  refitLabel.append(siteSelect);host.append(refitLabel);
  host.append(create(doc,'p','hint','Saving a design does not book a refit. A future operation will require a suitable airport, an actual flight to that airport, a 24–48 hour grounded refit and a booked return flight to the hub.'));
  updateLayout();
 }
 function updateLayout(){
  const a=selectedAircraft();if(!a||!plan||!usageLabel)return;
  const result=evaluateCabinPlan(plan,loaded.seatTypes,a.referenceUnits);
  installedDisplay.textContent='Installed: '+a.installedEconomy+' Economy, '+
   a.installedPremium+' Premium Economy, '+a.installedBusiness+
   ' Business, '+a.installedFirst+' First · Source: game standard until verified refit.';
  usageLabel.textContent=result.valid?result.count+' seats · '+result.used+
   ' / '+result.available+' cabin units used ('+
   Math.round(100*result.used/result.available)+'%) · '+
   'Indicative seat equipment '+currency(result.equipmentUsd):
   result.reason+(result.used!==undefined?' ('+result.used+'/'+result.available+' units)':'');
  for(let i=0;i<renderedRows.length;i++){
   const c=CLASSES[i],t=loaded.seatTypes.find(t=>t.code===plan[c.key+'Type']);
   renderedRows[i].indicator.textContent=t&&plan[c.key]>=0?
    (plan[c.key]*Number(t.spaceUnits)).toFixed(1):'—';
  }
  if(result.valid)renderCabinFloorplan(doc,previewSvg,plan,result,a.referenceUnits);
  else previewSvg?.replaceChildren();
  const chosen=(loaded.refitSites||[]).find(x=>x.aircraftInventoryId===selectedId&&x.airportKey===siteSelect?.value);
  if(chosen&&result.valid){
   statusLabel.textContent='Refit preview at '+chosen.provider+' ('+chosen.airportCode+
    '). Indicative '+result.refitHours+' hours downtime. Site labor factor: '+
    chosen.siteMultiplier+'× (game estimate). Not scheduled.';
  }
  const save=doc.getElementById('cabin-draft-save');
  if(save)save.disabled=!result.valid||!current.fleetClient?.saveCabinDraft;
 }
 async function reload(){
  const ticket=++version;
  loaded=null;plan=null;render();
  if(!current.connected||!current.airline?.id||!current.fleetClient?.cabinOverview)return;
  const airlineId=current.airline.id;
  try{
   const response=await current.fleetClient.cabinOverview(airlineId);
   if(ticket!==version||current.airline?.id!==airlineId)return;
   if(response?.airlineId!==airlineId||!Array.isArray(response.seatTypes)||
    !Array.isArray(response.aircraft)||!Array.isArray(response.directory)||
    response.previewOnly!==true||response.installedLayoutsImmutable!==true)
    throw Error('Unexpected cabin data');
   loaded=response;render();renderFactory();
   try{onDirectoryUpdate?.()}catch{console.warn('MRO directory view unavailable')}
  }catch{
   if(ticket!==version)return;
   host.textContent='Cabin configuration service is temporarily unavailable. Aircraft seats and flights have not changed.';
   if(factoryHost)factoryHost.textContent='Cabin seat types not available.';
  }
 }
 return Object.freeze({
  updateData(next){
   const old=current.airline?.id||null;current={...current,...next};
   if(old!==(current.airline?.id||null))selectedId=null;
   void reload();
  },
  selectAircraft(id){if(!loaded?.aircraft?.some(a=>a.aircraftInventoryId===id))return;
   selectedId=id;plan=null;render()},
  setFactoryAircraft(offer){
   pendingFactoryOffer=offer?{
    configurationId:offer.configurationId,referenceSeats:offer.referenceSeats,
    useType:offer.useType,manufacturer:offer.manufacturer,model:offer.model
   }:null;
   if(loaded)renderFactory();
  },
  getFactoryPlan,
  getDirectory:()=>loaded?.directory||[]
 });
}
