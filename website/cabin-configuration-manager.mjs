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
  businessType:'business_standard',firstType:'first_standard',extraLegroomCm:0};
}
const ROUND2=n=>Math.round(n*100)/100;
const cabinRatingBase=Object.freeze({economy:49,premium:61,business:72,first:80});
/** Game-only capacity model; extra centimetres consume cabin length per row.
 * Exact certified LOPA and emergency exit geometry are not represented. */
export function evaluateCabinPlan(plan,seatTypes,referenceUnits){
 const defs=new Map((seatTypes||[]).map(seat=>[seat.code,seat]));
 const cap=Number(referenceUnits);
 const extraCm=plan?.extraLegroomCm??0;
 const validExtra=typeof extraCm==='number'&&Number.isFinite(extraCm)&&extraCm>=0&&
  extraCm<=20&&Math.abs(extraCm*10-Math.round(extraCm*10))<1e-8;
 if(!validExtra)return {valid:false,reason:'Extra legroom must be from 0 to 20 cm in steps of 0.1 cm.'};
 let used=0,equipment=0,count=0,scoreSum=0;
 const classes=[];
 for(const c of CLASSES){
  const n=plan?.[c.key],code=plan?.[c.key+'Type'],type=defs.get(code);
  if(!Number.isInteger(n)||n<0||n>850||!type||type.cabinClass!==c.key)
   return {valid:false,reason:'Select a valid seat type and seat count for each class.'};
  const pitch=Number(type.pitchInches);
  const seatSpace=Number(type.spaceUnits);
  const seatCost=Number(type.installUsd);
  if(!(pitch>0)||!(seatSpace>0)||!Number.isFinite(seatCost)||seatCost<0)
   return {valid:false,reason:'This seat type is missing its design reference.'};
  const perSeat=seatSpace*(1+extraCm/(pitch*2.54));
  const space=n*perSeat;
  used+=space;equipment+=n*seatCost;count+=n;
  const quality= Math.max(15,Math.min(96,
   cabinRatingBase[c.key]+(seatSpace-1)*3+extraCm*1.35));
  scoreSum+=n*quality;
  classes.push({key:c.key,label:c.label,color:c.color,seats:n,code,
   pitch:pitch+extraCm/2.54,space,perSeat,style:type.label});
 }
 const rating=count>0?Math.round(scoreSum/count):0;
 const base={count,used:ROUND2(used),available:cap,
  spacePct:cap>0?Math.round(used/cap*1000)/10:0,
  equipmentUsd:Math.round(equipment),classes,comfortRating:rating,
  // Proposed small demand effect only: NOT applied to real booking logic.
  bookingPreferencePreviewPct:Math.round((rating-50)/50*15)/10,
  extraLegroomCm:extraCm,
  refitHours:(plan.premium+plan.business+plan.first)>0?48:24};
 if(!(cap>0))return {...base,valid:false,reason:'Cabin reference capacity is unavailable.'};
 if(count===0)return {...base,valid:false,reason:'Add at least one passenger seat.'};
 if(used>cap+1e-8)return {...base,valid:false,reason:'NO SPACE — reduce seat count, seat size or extra legroom.'};
 return {...base,valid:true};
}
/** Replacement quote: new seats plus ONE combined removal/installation job.
 * Site cost factor only applies to labour; this does not debit any account. */
export function estimateCabinRefit(evaluation,installedSeatCount=0,siteMultiplier=1){
 if(!evaluation?.valid)return {valid:false};
 const existing=Number(installedSeatCount),factor=Number(siteMultiplier);
 if(!Number.isSafeInteger(existing)||existing<0||existing>850||
  !Number.isFinite(factor)||factor<0.6||factor>1.5)return {valid:false};
 const baseLabourUsd=5000+evaluation.count*150+existing*75;
 const labourUsd=Math.round(baseLabourUsd*factor);
 return {valid:true,seatEquipmentUsd:evaluation.equipmentUsd,
  removalAndInstallationUsd:labourUsd,totalUsd:evaluation.equipmentUsd+labourUsd,
  siteMultiplier:factor,priceStatus:'provisional_game_estimate',chargeTriggered:false};
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
/** Reference row widths are per aircraft configuration, not inferred from
 * total seats alone. Provisional family patterns require later manual review. */
export function cabinRowLayout(geometry,cabinClass,referenceUnits=0){
 const k={economy:'economyColumns',premium:'premiumColumns',
  business:'businessColumns',first:'firstColumns'}[cabinClass];
 const given=geometry?.[k];
 if(Array.isArray(given)&&given.length>=1&&given.length<=3&&
    given.every(x=>Number.isInteger(x)&&x>=1&&x<=5)&&
    given.reduce((sum,n)=>sum+n,0)<=12)return [...given];
 const n=Number(referenceUnits);
 if(n>400)return cabinClass==='economy'?[3,4,3]:cabinClass==='premium'?[2,3,2]:[1,2,1];
 if(n>240)return cabinClass==='economy'?[2,4,2]:cabinClass==='premium'?[2,2,2]:[1,2,1];
 if(n>145)return cabinClass==='economy'?[3,3]:[2,2];
 if(n>40)return cabinClass==='economy'?[2,2]:[1,1];
 return [1,1];
}
/** Straight-cut cabin cross-section. FRONT is at the top; passenger rows
 * always run First -> Business -> Premium -> Economy toward the rear. */
export function createCabinFloorplanModel(evaluation,referenceUnits,geometry){
 const defaultLayout=cabinRowLayout(geometry,'economy',referenceUnits);
 const across=defaultLayout.reduce((n,x)=>n+x,0);
 const interiorWidth=across<=2?128:across<=3?144:across===4?160:
  across===5?174:across===6?190:across===7?225:across===8?255:
  across===9?285:316;
 const center=190,left=center-interiorWidth/2,right=center+interiorWidth/2;
 const ordered=['first','business','premium','economy'];
 const classes=ordered.map(key=>(evaluation.classes||[]).find(c=>c.key===key))
  .filter(c=>c&&c.seats>0);
 let y=59;const seats=[],sections=[];
 for(const c of classes){
  const layout=cabinRowLayout(geometry,c.key,referenceUnits);
  const total=layout.reduce((sum,n)=>sum+n,0);
  const aisleGap=layout.length===3?14:layout.length===2?19:0;
  const padding=5,seatWidth=(interiorWidth-padding*2-aisleGap*(layout.length-1))/total;
  const pitch=Math.max(19,Math.min(85,c.pitch/30*21));
  const seatHeight=Math.max(14,pitch-4);
  const rows=Math.ceil(c.seats/total);
  sections.push({className:c.key,layout:[...layout],rows,seats:c.seats,
   firstSeatY:y,lastSeatY:y+(rows-1)*pitch});
  let remaining=c.seats;
  for(let r=0;r<rows;r++){
   for(let block=0;block<layout.length;block++){
    const prior=layout.slice(0,block).reduce((sum,n)=>sum+n,0);
    for(let col=0;col<layout[block]&&remaining>0;col++){
     const x=left+padding+(prior+col)*seatWidth+block*aisleGap;
     seats.push({x:x+1,y,width:seatWidth-2,height:seatHeight,
      color:c.color,className:c.key,row:r,block});
     remaining--;
    }
   }
   y+=pitch;
  }
  y+=9;
 }
 const defaultHeight=Math.ceil(Number(referenceUnits)/Math.max(1,across))*22+150;
 const height=Math.max(245,defaultHeight,y+58);
 return {seats,sections,center,left,right,interiorWidth,height,
  basePattern:defaultLayout,totalSeats:seats.length};
}
export function renderCabinFloorplan(doc,svg,plan,evaluation,referenceUnits,geometry=null){
 if(!svg||typeof svg.replaceChildren!=='function')return;
 svg.replaceChildren();
 svg.setAttribute('role','img');
 svg.setAttribute('aria-label',
  'Flat-ended top view, front to rear First, Business, Premium Economy, Economy. '+
  (evaluation?.valid?(evaluation.count+' seats. '):'No space for this cabin layout. ')+
  'Indicative game design, not certified.');
 const illustration=evaluation?.valid?evaluation:{valid:true,classes:[],count:0};
 const model=createCabinFloorplanModel(illustration,referenceUnits,geometry);
 const {center,left,interiorWidth,height}=model;
 svg.setAttribute('viewBox','0 0 380 '+height);
 svg.setAttribute('preserveAspectRatio','xMidYMin meet');
 // An internal cabin plan has CUT ends; the nose/tail curvature is deliberately absent.
 svg.append(svgNode(doc,'rect',{x:left,y:4,width:interiorWidth,height:height-8,
  rx:0,fill:'#f7f9fc',stroke:'#8aa6be','stroke-width':2}));
 const zones=[
  {y:10,label:'FRONT · GALLEY',fill:'#d8e9fb'},
  {y:height-45,label:'REAR · GALLEY / LAV',fill:'#eedfcd'}
 ];
 for(const zone of zones){
  svg.append(svgNode(doc,'rect',{x:left+5,y:zone.y,width:interiorWidth-10,
   height:30,rx:0,fill:zone.fill,stroke:'#bbcad7','stroke-width':.9}));
  const txt=svgNode(doc,'text',{x:center,y:zone.y+19,'font-size':10,
   'text-anchor':'middle',fill:'#37546d'});
  txt.textContent=zone.label;svg.append(txt);
 }
 if(!evaluation?.valid){
  const message=svgNode(doc,'text',{x:center,y:Math.round(height/2),
   'font-size':16,'font-weight':'700','text-anchor':'middle',fill:'#a34436'});
  message.textContent=String(evaluation?.reason||'NO SPACE').startsWith('NO SPACE')?
   'NO SPACE':'INVALID LAYOUT';svg.append(message);
  const advice=svgNode(doc,'text',{x:center,y:Math.round(height/2)+21,
   'font-size':10,'text-anchor':'middle',fill:'#566b80'});
  advice.textContent='Reduce seats or extra legroom';svg.append(advice);
  return;
 }
 for(const seat of model.seats)
  svg.append(svgNode(doc,'rect',{x:seat.x,y:seat.y,width:seat.width,
   height:seat.height,rx:Math.min(4,seat.width/6),fill:seat.color,
   stroke:'#3c5266','stroke-width':.45}));
}
function appendRow(doc,table,c,typeList,plan,onEdit){
 const row=create(doc,'div','cabin-designer-row');
 const label=create(doc,'strong','',c.label);
 const select=create(doc,'select');
 select.setAttribute('aria-label',c.label+' seat style');
 for(const seat of typeList.filter(s=>s.cabinClass===c.key)){
  const option=doc.createElement('option');option.value=seat.code;
  option.textContent=seat.label+' · '+seat.pitchInches+'″ pitch · '+
   seat.widthInches+'″ wide · '+seat.spaceUnits+'× space';
  select.append(option);
 }
 const styleField=create(doc,'div','cabin-seat-reference');
 const sourceLink=create(doc,'a','cabin-seat-source','Seat product source');
 sourceLink.target='_blank';sourceLink.rel='noopener noreferrer';
 const updateSource=()=>{
  const seat=typeList.find(s=>s.code===select.value);
  sourceLink.hidden=!(seat?.realProduct&&/^https:\/\//u.test(seat?.sourceUrl||''));
  if(!sourceLink.hidden)sourceLink.href=seat.sourceUrl;
  else sourceLink.removeAttribute('href');
 };
 select.value=plan[c.key+'Type'];styleField.append(select,sourceLink);updateSource();
 select.addEventListener('change',()=>{plan[c.key+'Type']=select.value;updateSource();onEdit()});
 const input=create(doc,'input');input.type='number';input.min='0';input.max='850';input.step='1';
 input.value=String(plan[c.key]);input.setAttribute('aria-label',c.label+' seat count');
 input.addEventListener('input',()=>{
  const n=Number(input.value);
  plan[c.key]=Number.isInteger(n)&&n>=0&&n<=850?n:-1;onEdit();
 });
 const indicator=create(doc,'span','cabin-designer-unit','—');
 row.append(label,styleField,input,indicator);table.append(row);
 return {indicator,input,select};
}
/** Editable planning input shared by owned-aircraft and factory previews. */
function appendLegroomControl(doc,container,plan,onEdit,scope){
 const field=create(doc,'label','cabin-legroom-field','Additional space between seat rows (cm)');
 const input=create(doc,'input');
 input.type='number';input.id=scope+'-extra-legroom';input.min='0';input.max='20';
 input.step='0.1';input.value=String(plan.extraLegroomCm??0);
 input.setAttribute('aria-label','Additional legroom in centimetres');
 input.addEventListener('input',()=>{
  const value=Number(input.value);
  plan.extraLegroomCm=Number.isFinite(value)&&input.value.trim()?value:NaN;
  onEdit();
 });
 const note=create(doc,'small','',
  'Added to each seat style’s standard pitch. More legroom reduces available space (0–20 cm).');
 field.append(input,note);container.append(field);
 return input;
}
export function createCabinConfigurationManager({doc,host,factoryHost,onDirectoryUpdate,onFactoryLayoutChange}={}){
 if(!doc||!host)throw Error('Cabin planner needs an existing page host');
 let current={connected:false,airline:null,fleetClient:null};
 let loaded=null,selectedId=null,plan=null,factoryPlan=null,factoryConfigurationId=null;
 let pendingFactoryOffer=null;
 let version=0;let renderedRows=[],factoryRows=[];
 let installedDisplay=null,usageLabel=null,statusLabel=null,previewSvg=null,siteSelect=null;
 let factoryUsage=null,factorySvg=null,factoryMessage=null;
 let comfortSummary=null,costSummary=null,factoryComfort=null,factoryCost=null;
 const currency=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);
 function selectedAircraft(){return loaded?.aircraft?.find(a=>a.aircraftInventoryId===selectedId)||null}
 function modelGeometry(configurationId){
  return loaded?.geometries?.find(g=>Number(g.configurationId)===Number(configurationId))||null;
 }
 function describeCabinPatterns(geometry,referenceUnits){
  if(!geometry)return 'Aircraft seating pattern awaiting verification';
  const groups=[['Economy','economy'],['Premium','premium'],
   ['Business','business'],['First','first']].map(([name,key])=>
   name+' '+cabinRowLayout(geometry,key,referenceUnits).join('–'));
  const review=geometry.manuallyVerified?'Reviewed':
   geometry.reviewStatus==='game_estimate_needs_review'?
    'Provisional — manual model review needed':
    'Published typical row pattern — individual aircraft review pending';
  return groups.join(' · ')+' · '+review;
 }
 function modelPlan(a){
  if(!a)return standardCabinPlan(0);
  if(a.draftEconomy!==null&&a.draftEconomy!==undefined)
   return {economy:a.draftEconomy,premium:a.draftPremium,business:a.draftBusiness,first:a.draftFirst,
    economyType:a.draftEconomyType,premiumType:a.draftPremiumType,
    businessType:a.draftBusinessType,firstType:a.draftFirstType,
    extraLegroomCm:Number(a.draftExtraLegroomCm||0)};
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
  ['Class','Seat style','Seats','Space %'].forEach(x=>header.append(create(doc,'span','',x)));
  controls.append(header);
  factoryRows=[];
  for(const c of CLASSES)factoryRows.push(appendRow(doc,controls,c,loaded.seatTypes,factoryPlan,updateFactory));
  appendLegroomControl(doc,controls,factoryPlan,updateFactory,'factory');
  factoryUsage=create(doc,'p','cabin-designer-status','');
  factoryComfort=create(doc,'p','cabin-designer-status','');
  factoryCost=create(doc,'p','cabin-designer-status','');
  const standard=create(doc,'button','secondary cabin-compact-action','Use standard layout');
  standard.type='button';standard.addEventListener('click',()=>{
   factoryPlan=standardCabinPlan(factory.referenceSeats);renderFactory();
  });
  controls.append(factoryUsage,factoryComfort,factoryCost,standard);
  const visual=create(doc,'div','cabin-designer-visual');
  factorySvg=svgNode(doc,'svg',{});visual.append(factorySvg);
  main.append(controls,visual);factoryHost.append(main);
  factoryMessage=create(doc,'p','hint','');factoryHost.append(factoryMessage);
  updateFactory();
 }
 function updateFactory(){
  const f=pendingFactoryOffer;if(!f||!factoryPlan||!factoryUsage)return;
  const geometry=modelGeometry(f.configurationId);
  const evaluation=evaluateCabinPlan(factoryPlan,loaded.seatTypes,f.referenceSeats);
  const standard=factoryPlan.economy===Number(f.referenceSeats)&&
   factoryPlan.economyType==='eco_standard'&&
   factoryPlan.premium===0&&factoryPlan.business===0&&factoryPlan.first===0&&
   factoryPlan.extraLegroomCm===0;
  factoryUsage.textContent=evaluation.valid?
   evaluation.count+' seats · '+evaluation.spacePct+'% of cabin space used · '+
    (standard?'Standard factory layout':'Custom factory design'):
   (evaluation.reason||'Invalid layout')+
    (Number.isFinite(evaluation.spacePct)?' · '+evaluation.spacePct+'% requested':'');
  for(let i=0;i<factoryRows.length;i++){
   const c=CLASSES[i],section=evaluation.classes?.find(row=>row.key===c.key);
   factoryRows[i].indicator.textContent=section&&evaluation.available>0?
    (section.space/evaluation.available*100).toFixed(1)+'%':'—';
  }
  if(factoryComfort)factoryComfort.textContent=evaluation.valid?
   'Cabin comfort rating '+evaluation.comfortRating+'/100 · '+
   'Potential passenger preference '+(evaluation.bookingPreferencePreviewPct>=0?'+':'')+
    evaluation.bookingPreferencePreviewPct+'% (future game rule; not active)':
   'No valid comfort rating until the layout fits.';
  if(factoryCost)factoryCost.textContent=evaluation.valid?
   'Seat equipment game value '+currency(evaluation.equipmentUsd)+
    (standard?' · Included in the factory aircraft offer.':
     ' · Custom factory fit-out pricing and ordering are not enabled.'):
   'No cost quote for an invalid cabin layout.';
  renderCabinFloorplan(doc,factorySvg,factoryPlan,evaluation,f.referenceSeats,geometry);
  factoryMessage.textContent=describeCabinPatterns(geometry,f.referenceSeats)+' · '+
   (standard?'Standard seats included in the aircraft price.':
   'Custom design is a preview only, not attached to a paid order.');
  try{onFactoryLayoutChange?.()}catch{console.warn('Factory layout order control unavailable')}
 }
 function getFactoryPlan(){
  const f=pendingFactoryOffer;
  if(!f||f.useType==='cargo')return {standard:true,valid:true};
  if(!loaded||!factoryPlan)return {standard:false,valid:false,reason:'Cabin preview not yet loaded'};
  const val=evaluateCabinPlan(factoryPlan,loaded.seatTypes,f.referenceSeats);
  return {...val,standard:val.valid&&factoryPlan.economy===Number(f.referenceSeats)&&
   factoryPlan.economyType==='eco_standard'&&
   factoryPlan.premium===0&&factoryPlan.business===0&&factoryPlan.first===0&&
   factoryPlan.extraLegroomCm===0};
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
  ['Class','Seat style','Seats','Space %'].forEach(x=>head.append(create(doc,'span','',x)));
  controls.append(head);renderedRows=[];
  for(const c of CLASSES)renderedRows.push(appendRow(doc,controls,c,loaded.seatTypes,plan,updateLayout));
  appendLegroomControl(doc,controls,plan,updateLayout,'owned');
  usageLabel=create(doc,'p','cabin-designer-status','');
  comfortSummary=create(doc,'p','cabin-designer-status','');
  costSummary=create(doc,'p','cabin-designer-status cabin-cost-breakdown','');
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
     draftBusinessType:plan.businessType,draftFirstType:plan.firstType,
     draftExtraLegroomCm:String(plan.extraLegroomCm)});
    statusLabel.textContent='Cabin design saved to your airline. The installed cabin has NOT changed. Estimated refit '+result.indicativeDowntimeHours+' hours. No payment or aircraft grounding.';
   }catch{
    statusLabel.textContent='Could not save this cabin draft. Installed seats remain unchanged.';
   }finally{save.disabled=false}
  });
  buttons.append(standard,save);controls.append(usageLabel,comfortSummary,costSummary,buttons);
  const visual=create(doc,'div','cabin-designer-visual'),legend=create(doc,'p','hint',
   'Seats use the selected aircraft family row arrangement and fill the usable cabin width. Galleys/lavatories are indicative; exit positions and certification are not yet verified.');
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
  usageLabel.textContent=result.valid?
   result.count+' seats · '+result.spacePct+'% of available cabin space used · '+
   (100-result.spacePct).toFixed(1)+'% remaining · '+
   describeCabinPatterns(modelGeometry(a.configurationId),a.referenceUnits):
   (result.reason||'Invalid layout')+
   (Number.isFinite(result.spacePct)?' · '+result.spacePct+'% of cabin space requested':'');
  for(let i=0;i<renderedRows.length;i++){
   const c=CLASSES[i],section=result.classes?.find(row=>row.key===c.key);
   renderedRows[i].indicator.textContent=section&&result.available>0?
    (section.space/result.available*100).toFixed(1)+'%':'—';
  }
  renderCabinFloorplan(doc,previewSvg,plan,result,a.referenceUnits,modelGeometry(a.configurationId));
  const chosen=(loaded.refitSites||[]).find(x=>x.aircraftInventoryId===selectedId&&
   x.airportKey===siteSelect?.value);
  if(comfortSummary)comfortSummary.textContent=result.valid?
   'Passenger cabin comfort: '+result.comfortRating+'/100 · Potential future booking '+
    'preference adjustment '+(result.bookingPreferencePreviewPct>=0?'+':'')+
    result.bookingPreferencePreviewPct+'% (game-design preview only; not active).':
   'Passenger comfort rating unavailable until the proposed layout fits.';
  const installedCount=['Economy','Premium','Business','First'].reduce((n,key)=>
   n+Number(a['installed'+key]||0),0);
  const quote=estimateCabinRefit(result,installedCount,Number(chosen?.siteMultiplier||1));
  if(costSummary)costSummary.textContent=quote.valid?
   'Estimated refit: New seats '+currency(quote.seatEquipmentUsd)+
   ' + removal and installation '+currency(quote.removalAndInstallationUsd)+
   ' = TOTAL '+currency(quote.totalUsd)+
   ' · Game estimate only. Replacement work included once. No payment.':
   'No refit cost quote until the design fits within available space.';
  if(chosen&&result.valid){
   statusLabel.textContent='Selected refit location: '+chosen.provider+' ('+chosen.airportCode+
    '). Estimated downtime '+result.refitHours+' hours. Site labour factor '+
    chosen.siteMultiplier+'× (game estimate). Not scheduled.';
  }else if(statusLabel?.textContent?.startsWith('Selected refit location:')){
   statusLabel.textContent='';
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
    !Array.isArray(response.aircraft)||!Array.isArray(response.geometries)||
    !Array.isArray(response.directory)||
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
