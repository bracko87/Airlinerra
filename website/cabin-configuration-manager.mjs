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
/** Fictional display brands and model numbers for the Airlinerra game.
 * Stored seat_code values are stable internal identifiers and remain unchanged.
 * Do not surface real-world commercial product labels or links in this UI.
 */
export const CABIN_SEAT_GAME_NAMES=Object.freeze({
 "eco_standard": "Aervio E100",
 "eco_safran_z85": "Veloran E110",
 "eco_recaro_r1": "Nuvella E120",
 "eco_recaro_r2": "Nuvella E130",
 "eco_extra": "Aervio E140",
 "eco_safran_z200": "Veloran E150",
 "eco_recaro_r3": "Nuvella E160",
 "eco_comfort": "Aervio E170",
 "eco_safran_z300": "Veloran E180",
 "eco_safran_z400": "Veloran E190",
 "premium_standard": "Aervio P100",
 "premium_recaro_pl3530": "Nuvella P120",
 "premium_recliner": "Aervio P130",
 "premium_zim_zp450": "Orvessa P140",
 "premium_safran_z535i": "Veloran P150",
 "premium_recaro_r4": "Nuvella P160",
 "premium_collins_miq": "Selyra P170",
 "premium_safran_airgo": "Veloran P180",
 "premium_zim_zp610": "Orvessa P190",
 "premium_geven_comoda": "Aeressa P200",
 "business_standard": "Aervio B100",
 "business_safran_z600": "Veloran B110",
 "business_recaro_r5": "Nuvella B120",
 "business_collins_miq": "Selyra B130",
 "business_flat": "Aervio B140",
 "business_suite": "Aervio B150",
 "business_collins_diamond": "Selyra B160",
 "business_recaro_r7": "Nuvella B170",
 "business_zim_luxury": "Orvessa B180",
 "business_safran_fusio": "Veloran B190",
 "first_standard": "Aervio F100",
 "first_suite": "Aervio F120",
 "first_private": "Aervio F130",
 "first_emirates_a380": "Orvessa F140",
 "first_ana_square": "Selyra F150",
 "first_ana_suite": "Selyra F160",
 "first_emirates_777": "Orvessa F170",
 "first_singapore_a380": "Aeressa F180",
 "first_lufthansa_allegris": "Nuvella F190",
 "first_airfrance_premiere": "Veloran F200"
});
export function cabinSeatDisplayName(seat){
 return CABIN_SEAT_GAME_NAMES[seat?.code]||
  (typeof seat?.code==='string'&&/^[a-z][a-z0-9_]*$/u.test(seat.code)?
   'Aervio '+seat.code.replace(/[^a-z0-9]/gu,'').slice(-10).toUpperCase():'Aervio seat');
}
const formatSeatUnitPrice=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(n);
const numericSeatPrice=seat=>{
 const raw=Number(seat?.installUsd);
 return Number.isSafeInteger(raw)&&raw>=0?raw:null;
};
export function cheapestCabinSeat(seatTypes,cabinClass,codeFallback){
 const available=(seatTypes||[]).filter(s=>s?.cabinClass===cabinClass&&
  numericSeatPrice(s)!==null).sort((a,b)=>
  numericSeatPrice(a)-numericSeatPrice(b)||String(a.code).localeCompare(String(b.code)));
 return available[0]?.code||codeFallback;
}
const seatValueBounds=(catalog,key)=>{
 const prices=(catalog||[]).filter(s=>s.cabinClass===key).map(numericSeatPrice)
  .filter(v=>v!==null);
 return {min:prices.length?Math.min(...prices):0,max:prices.length?Math.max(...prices):0};
}
export function seatQualityBonus(seat,seatTypes){
 const cost=numericSeatPrice(seat),range=seatValueBounds(seatTypes,seat?.cabinClass);
 if(cost===null||range.max<=range.min)return 0;
 // Pricing is the game's seat-tier proxy, not a manufacturer's actual rating.
 // Maximum incremental impact of moving from cheapest to most expensive: +6/100.
 return Math.round(60*Math.max(0,Math.min(1,
  (cost-range.min)/(range.max-range.min))))/10;
}
export function standardCabinPlan(seats,seatTypes=[]){
 const count=Math.max(0,Math.min(850,Math.floor(Number(seats)||0)));
 return {economy:count,premium:0,business:0,first:0,
  economyType:cheapestCabinSeat(seatTypes,'economy','eco_standard'),
  premiumType:cheapestCabinSeat(seatTypes,'premium','premium_standard'),
  businessType:cheapestCabinSeat(seatTypes,'business','business_standard'),
  firstType:cheapestCabinSeat(seatTypes,'first','first_standard'),extraLegroomCm:0};
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
   cabinRatingBase[c.key]+(seatSpace-1)*3+extraCm*1.35+
   seatQualityBonus(type,seatTypes)));
  scoreSum+=n*quality;
  classes.push({key:c.key,label:c.label,color:c.color,seats:n,code,
   pitch:pitch+extraCm/2.54,space,perSeat,style:cabinSeatDisplayName(type),
   unitPriceUsd:seatCost});
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
/** Whole-row rule for named model templates; no stray single seats. */
export function validateCabinModelRows(plan,geometry,referenceUnits){
 for(const c of CLASSES){
  const n=plan?.[c.key];
  const row=cabinRowLayout(geometry,c.key,referenceUnits);
  const perRow=row.reduce((sum,x)=>sum+x,0);
  if(Number.isInteger(n)&&n>0&&n%perRow!==0)
   return {valid:false,reason:c.label+' uses '+perRow+' seats per row ('+
    row.join('–')+'). Choose a multiple of '+perRow+'; '+n+' would leave a partial row.'};
 }
 return {valid:true};
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
 // Seat rows fill the usable length at 100% occupancy; spare space grows only
 // when the weighted game-space model says that cabin space remains.
 const occupancy=Math.max(.07,Math.min(1,Number(evaluation.spacePct||0)/100));
 const height=Math.max(245,Math.ceil(59+(y-59)/occupancy+48));
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
export function appendRow(doc,table,c,typeList,plan,onEdit){
 const row=create(doc,'div','cabin-designer-row');
 const label=create(doc,'strong','',c.label);
 const select=create(doc,'select');
 select.setAttribute('aria-label',c.label+' seat style');
 const options=typeList.filter(s=>s.cabinClass===c.key).sort((a,b)=>
  (numericSeatPrice(a)??Infinity)-(numericSeatPrice(b)??Infinity)||
   String(a.code).localeCompare(String(b.code)));
 for(const seat of options){
  const option=doc.createElement('option');option.value=seat.code;
  option.textContent=cabinSeatDisplayName(seat);
  option.title=seat.pitchInches+'″ pitch · '+seat.widthInches+'″ wide';
  select.append(option);
 }
 const styleField=create(doc,'div','cabin-seat-reference');
 const unitPrice=create(doc,'strong','cabin-seat-price','—');
 const updatePrice=()=>{
  const seat=options.find(s=>s.code===select.value);
  unitPrice.textContent=seat&&numericSeatPrice(seat)!==null?
   formatSeatUnitPrice(numericSeatPrice(seat)):'—';
 };
 select.value=plan[c.key+'Type'];styleField.append(select);updatePrice();
 select.addEventListener('change',()=>{
  plan[c.key+'Type']=select.value;updatePrice();onEdit();
 });
 const input=create(doc,'input');input.type='number';input.min='0';input.max='850';input.step='1';
 input.value=String(plan[c.key]);input.setAttribute('aria-label',c.label+' seat count');
 input.addEventListener('input',()=>{
  const n=Number(input.value);
  plan[c.key]=Number.isInteger(n)&&n>=0&&n<=850?n:-1;onEdit();
 });
 const indicator=create(doc,'span','cabin-designer-unit','—');
 row.append(label,styleField,input,indicator,unitPrice);table.append(row);
 return {indicator,input,select,unitPrice};
}
/** Model-design passenger appeal is a game estimate, not real passenger feedback. */
export function passengerRatingView(evaluation){
 const raw=Number(evaluation?.comfortRating);
 if(evaluation?.valid!==true||!Number.isFinite(raw))
  return {available:false,value:0,label:'— / 100'};
 const value=Math.max(0,Math.min(100,Math.round(raw)));
 return {available:true,value,label:value+' / 100'};
}
/** A read-only 0–100 indicator, updated when seats or legroom change. */
export function createPassengerRatingGauge(doc){
 const root=create(doc,'section','cabin-passenger-rating');
 const description=create(doc,'div','cabin-passenger-rating-description');
 description.append(create(doc,'strong','','Passenger rating'));
 const note=create(doc,'small','',
  'Estimated passenger appeal for this configuration (game rating, not real feedback).');
 description.append(note);
 const scale=create(doc,'div','cabin-passenger-rating-scale');
 const track=create(doc,'div','cabin-passenger-rating-track');
 track.setAttribute('role','meter');
 track.setAttribute('aria-label','Estimated passenger rating');
 track.setAttribute('aria-valuemin','0');
 track.setAttribute('aria-valuemax','100');
 const fill=create(doc,'div','cabin-passenger-rating-fill');
 const thumb=create(doc,'span','cabin-passenger-rating-thumb');
 const value=create(doc,'strong','cabin-passenger-rating-value','— / 100');
 track.append(fill,thumb,value);
 const endpoints=create(doc,'div','cabin-passenger-rating-ends');
 endpoints.append(create(doc,'span','','0'),create(doc,'span','','100'));
 scale.append(track,endpoints);root.append(description,scale);
 return {root,track,fill,thumb,value,note};
}
export function updatePassengerRatingGauge(gauge,evaluation){
 if(!gauge)return;
 const rating=passengerRatingView(evaluation);
 gauge.value.textContent=rating.label;
 gauge.fill.style.width=rating.value+'%';
 gauge.thumb.style.left=rating.value+'%';
 gauge.value.style.left=rating.value+'%';
 gauge.track.setAttribute('aria-valuenow',String(rating.value));
 gauge.track.setAttribute('aria-valuetext',
  rating.available?rating.label+' estimated game rating':'Rating unavailable until the layout fits');
 gauge.root.className='cabin-passenger-rating'+(rating.available?'':' cabin-rating-unavailable');
 gauge.note.textContent=rating.available?
  'Estimated passenger appeal for this configuration (game rating, not real feedback).':
  'Rating unavailable until the cabin layout fits.';
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
 let designName='',selectedDesignId='';
 let pendingFactoryOffer=null;
 let version=0;let renderedRows=[],factoryRows=[];
 let installedDisplay=null,usageLabel=null,statusLabel=null,previewSvg=null,siteSelect=null;
 let factoryUsage=null,factorySvg=null,factoryMessage=null;
 let ratingGauge=null,costSummary=null,factoryComfort=null,factoryCost=null;
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
  return standardCabinPlan(a.standardEconomy,loaded?.seatTypes);
 }
 function renderFactory(){
  if(!factoryHost)return;
  const factory=pendingFactoryOffer;
  if(!factory){factoryHost.textContent='Choose a passenger aircraft configuration to preview its seats.';return}
  if(factory.useType==='cargo'){factoryHost.textContent='Cargo aircraft: passenger cabin customization is not applicable.';return}
  if(!loaded?.seatTypes?.length){factoryHost.textContent='Loading seat catalog…';return}
  if(factoryConfigurationId!==factory.configurationId||!factoryPlan){
   factoryConfigurationId=factory.configurationId;factoryPlan=standardCabinPlan(factory.referenceSeats,loaded.seatTypes);
  }
  factoryHost.replaceChildren();
  factoryHost.append(create(doc,'h4','','Factory passenger cabin'));
  factoryHost.append(create(doc,'p','hint','Standard Economy seats are included. Customize a layout below to preview space. A nonstandard factory interior is not attached to an order yet.'));
  const main=create(doc,'div','cabin-designer-grid'),controls=create(doc,'div','cabin-designer-controls');
  const header=create(doc,'div','cabin-designer-row cabin-designer-head');
  ['Class','Seat style','Seats','Space %','Price / seat'].forEach(x=>header.append(create(doc,'span','',x)));
  controls.append(header);
  factoryRows=[];
  for(const c of CLASSES)factoryRows.push(appendRow(doc,controls,c,loaded.seatTypes,factoryPlan,updateFactory));
  appendLegroomControl(doc,controls,factoryPlan,updateFactory,'factory');
  factoryUsage=create(doc,'p','cabin-designer-status','');
  factoryComfort=create(doc,'p','cabin-designer-status','');
  factoryCost=create(doc,'p','cabin-designer-status','');
  const standard=create(doc,'button','secondary cabin-compact-action','Use standard layout');
  standard.type='button';standard.addEventListener('click',()=>{
   factoryPlan=standardCabinPlan(factory.referenceSeats,loaded.seatTypes);renderFactory();
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
   factoryPlan.economyType===cheapestCabinSeat(loaded?.seatTypes,'economy','eco_standard')&&
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
   factoryPlan.economyType===cheapestCabinSeat(loaded?.seatTypes,'economy','eco_standard')&&
   factoryPlan.premium===0&&factoryPlan.business===0&&factoryPlan.first===0&&
   factoryPlan.extraLegroomCm===0};
 }
 function currentModelDesigns(aircraft){
  return (loaded?.modelDesigns||[]).filter(d=>
   Number(d.configurationId)===Number(aircraft?.configurationId));
 }
 function designPlan(d){
  return {economy:d.economy,premium:d.premium,business:d.business,first:d.first,
   economyType:d.economyType,premiumType:d.premiumType,
   businessType:d.businessType,firstType:d.firstType,
   extraLegroomCm:Number(d.extraLegroomCm||0)};
 }
 function render(){
  host.replaceChildren();
  if(!current.connected||!current.airline?.id){
   host.textContent='Connect an airline to design cabin configurations.';return}
  if(!loaded){host.textContent='Loading cabin configuration database…';return}
  const aircraftList=(loaded.aircraft||[]).filter(a=>a.useType!=='cargo');
  const models=new Map();
  for(const a of aircraftList){
   const key=a.manufacturer+'|'+a.model;
   if(!models.has(key))models.set(key,a);
  }
  host.append(create(doc,'h3','','Your cabin configurations'));
  if(!models.size){
   host.append(create(doc,'p','hint','No passenger aircraft models are available in your fleet.'));return;
  }
  if(!aircraftList.some(a=>a.aircraftInventoryId===selectedId))
   selectedId=models.values().next().value.aircraftInventoryId;
  const aircraft=aircraftList.find(a=>a.aircraftInventoryId===selectedId);
  const choose=create(doc,'label','cabin-choose','Aircraft model');
  const chooseSelect=create(doc,'select');chooseSelect.id='cabin-owned-selector';
  for(const [key,representative] of models){
   const option=doc.createElement('option');option.value=key;
   option.textContent=representative.manufacturer+' '+representative.model;
   chooseSelect.append(option);
  }
  chooseSelect.value=aircraft.manufacturer+'|'+aircraft.model;
  chooseSelect.addEventListener('change',()=>{
   selectedId=models.get(chooseSelect.value).aircraftInventoryId;
   selectedDesignId='';designName='';plan=null;render();
  });
  choose.append(chooseSelect);host.append(choose);
  installedDisplay=create(doc,'p','cabin-installed-note',
   'Model reference: '+aircraft.referenceUnits+' game cabin-space units. '+
   'Designs can be reused for this model; no particular aircraft is changed.');
  host.append(installedDisplay);
  const geometry=modelGeometry(aircraft.configurationId);
  const designs=currentModelDesigns(aircraft);
  const savedLabel=create(doc,'label','cabin-choose','Saved model configurations');
  const savedSelect=create(doc,'select');savedSelect.id='cabin-saved-model-design';
  const newOption=doc.createElement('option');newOption.value='';
  newOption.textContent='Create a new configuration';savedSelect.append(newOption);
  for(const d of designs){
   const o=doc.createElement('option');o.value=d.designId;o.textContent=d.name;
   savedSelect.append(o);
  }
  if(!designs.some(d=>d.designId===selectedDesignId))selectedDesignId='';
  savedSelect.value=selectedDesignId;
  savedSelect.addEventListener('change',()=>{
   selectedDesignId=savedSelect.value;
   const existing=designs.find(d=>d.designId===selectedDesignId);
   plan=existing?designPlan(existing):standardCabinPlan(Number(aircraft.standardEconomy),loaded.seatTypes);
   designName=existing?.name||'';render();
  });
  savedLabel.append(savedSelect);host.append(savedLabel);
  if(!plan)plan=standardCabinPlan(Number(aircraft.standardEconomy),loaded.seatTypes);
  const grid=create(doc,'div','cabin-designer-grid');
  const controls=create(doc,'div','cabin-designer-controls');
  const head=create(doc,'div','cabin-designer-row cabin-designer-head');
  ['Class','Seat style','Seats','Space %','Price / seat'].forEach(x=>head.append(create(doc,'span','',x)));
  controls.append(head);renderedRows=[];
  for(const c of CLASSES){
   const row=appendRow(doc,controls,c,loaded.seatTypes,plan,updateLayout);
   const perRow=cabinRowLayout(geometry,c.key,aircraft.referenceUnits).reduce((n,x)=>n+x,0);
   row.input.step=String(perRow);
   row.input.title='Complete rows of '+perRow+' seats';
   renderedRows.push(row);
  }
  appendLegroomControl(doc,controls,plan,updateLayout,'owned');
  usageLabel=create(doc,'p','cabin-designer-status','');
  ratingGauge=createPassengerRatingGauge(doc);
  controls.append(usageLabel,ratingGauge.root);
  const costBox=create(doc,'section','cabin-model-cost');
  costBox.append(create(doc,'h4','','Estimated configuration cost'));
  costSummary=create(doc,'div','cabin-cost-breakdown','');
  costBox.append(costSummary);
  costBox.append(create(doc,'p','hint',
   'Game estimate using the model-standard seat count for replacement labour. '+
   'A real aircraft quote depends on its installed cabin and chosen MRO facility. '+
   'Saving a model design does not charge your airline.'));
  controls.append(costBox);
  const actions=create(doc,'div','cabin-designer-actions');
  const standard=create(doc,'button','secondary cabin-compact-action','Use standard');
  standard.type='button';standard.addEventListener('click',()=>{
   plan=standardCabinPlan(Number(aircraft.standardEconomy),loaded.seatTypes);render();
  });
  const nameField=create(doc,'label','cabin-model-name','Configuration name');
  const nameInput=create(doc,'input');nameInput.type='text';nameInput.maxLength=80;
  nameInput.placeholder='e.g. A319 Comfort 156';
  nameInput.id='cabin-configuration-name';
  nameInput.value=designName;
  nameInput.setAttribute('aria-label','Configuration name');
  nameInput.addEventListener('input',()=>{designName=nameInput.value;updateLayout()});
  nameField.append(nameInput);
  const save=create(doc,'button','primary cabin-compact-action','Save configuration');
  save.id='cabin-draft-save';save.type='button';
  save.addEventListener('click',async()=>{
   const value=evaluateCabinPlan(plan,loaded.seatTypes,aircraft.referenceUnits);
   const rows=validateCabinModelRows(plan,geometry,aircraft.referenceUnits);
   const name=designName.trim();
   if(!value.valid||!rows.valid||name.length<2||name.length>80||
    !current.fleetClient?.saveCabinModelDesign)return;
   save.disabled=true;statusLabel.textContent='Saving named model configuration…';
   try{
    const result=await current.fleetClient.saveCabinModelDesign({
     airlineId:current.airline.id,configurationId:aircraft.configurationId,
     name,...plan
    });
    if(result?.status!=='model_design_saved_not_installed'||
     Number(result.configurationId)!==Number(aircraft.configurationId)||!result.designId)
     throw Error('Named model design was not confirmed');
    const design={...plan,configurationId:aircraft.configurationId,
     designId:result.designId,name};
    loaded.modelDesigns=(loaded.modelDesigns||[]).filter(d=>d.designId!==design.designId);
    loaded.modelDesigns.unshift(design);
    selectedDesignId=design.designId;designName=name;
    statusLabel.textContent='Configuration "'+name+
     '" saved for '+aircraft.manufacturer+' '+aircraft.model+
     '. No aircraft seats, flights or airline funds changed.';
    // Keep the editor and confirmation visible while refreshing the saved list.
    const opt=doc.createElement('option');opt.value=design.designId;
    opt.textContent=name;savedSelect.append(opt);savedSelect.value=design.designId;
   }catch{
    statusLabel.textContent='Could not save this model configuration. No aircraft has changed.';
   }finally{updateLayout()}
  });
  actions.append(standard);controls.append(actions,nameField,save);
  const visual=create(doc,'div','cabin-designer-visual');
  const legend=create(doc,'p','hint',
   'Seats follow the model row pattern. Unused cabin length is shown proportionally. '+
   'Galleys/lavatories are indicative; exit positions and certification are not yet verified.');
  previewSvg=svgNode(doc,'svg');visual.append(previewSvg,legend);
  grid.append(controls,visual);host.append(grid);
  statusLabel=create(doc,'p','hint','');statusLabel.setAttribute('role','status');
  host.append(statusLabel);
  host.append(create(doc,'p','hint',
   'To apply a saved model design to a specific aircraft, use Change configuration '+
   'in that aircraft’s profile. Refit installation and payment are not active.'));
  updateLayout();
 }
 function updateLayout(){
  const a=selectedAircraft();if(!a||!plan||!usageLabel)return;
  const geometry=modelGeometry(a.configurationId);
  const result=evaluateCabinPlan(plan,loaded.seatTypes,a.referenceUnits);
  const rowCheck=validateCabinModelRows(plan,geometry,a.referenceUnits);
  const valid=result.valid&&rowCheck.valid;
  usageLabel.textContent=!result.valid?
   (result.reason||'Invalid layout')+
   (Number.isFinite(result.spacePct)?' · '+result.spacePct+'% requested':''):
   !rowCheck.valid?rowCheck.reason:
   result.count+' seats · '+result.spacePct+'% of available cabin space used · '+
   (100-result.spacePct).toFixed(1)+'% remaining';
  for(let i=0;i<renderedRows.length;i++){
   const c=CLASSES[i],section=result.classes?.find(row=>row.key===c.key);
   renderedRows[i].indicator.textContent=section&&result.available>0?
    (section.space/result.available*100).toFixed(1)+'%':'—';
  }
  renderCabinFloorplan(doc,previewSvg,plan,result,a.referenceUnits,geometry);
  updatePassengerRatingGauge(ratingGauge,valid?result:null);
  const quote=estimateCabinRefit(result,Number(a.standardEconomy||0));
  if(costSummary){
   costSummary.replaceChildren();
   if(quote.valid){
    for(const [label,amount,major] of [
     ['New seats',quote.seatEquipmentUsd,false],
     ['Removal and installation',quote.removalAndInstallationUsd,false],
     ['Estimated total',quote.totalUsd,true]]){
     const line=create(doc,'div',major?'cabin-cost-total':'cabin-cost-line');
     line.append(create(doc,'span','',label),create(doc,'strong','',currency(amount)));
     costSummary.append(line);
    }
   }else costSummary.append(create(doc,'p','','No quote until the design fits.'));
  }
  const save=doc.getElementById('cabin-draft-save');
  const validName=designName.trim().length>=2&&designName.trim().length<=80&&
   !/[\u0000-\u001F\u007F]/u.test(designName);
  if(save)save.disabled=!valid||!validName||!current.fleetClient?.saveCabinModelDesign;
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
   const old=current.airline?.id||null;
   current={...current,...next};
   const currentId=current.airline?.id||null;
   // Game clock/data refresh must not erase a manager's unsaved cabin design.
   if(old===currentId&&loaded)return;
   if(old!==currentId){selectedId=null;designName='';selectedDesignId='';}
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
