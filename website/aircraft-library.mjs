/** Airlinerra Settings -> Aircraft Library. Read-only, real catalog data.
 * No fabricated aircraft list, no HTML interpolation of database values.
 */
const format=n=>typeof n==='number'&&Number.isFinite(n)?new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n):'Not recorded';
const label=(name,value,unit='')=>{
 const row=document.createElement('div');
 row.className='library-spec';
 const term=document.createElement('span');term.textContent=name;
 const val=document.createElement('strong');val.textContent=value===null||value===undefined?'Not recorded':
   typeof value==='number'?format(value)+(unit?' '+unit:''):String(value);
 row.append(term,val);return row;
};
function element(tag,cls,text){
 const node=document.createElement(tag);
 if(cls)node.className=cls;
 if(text!==undefined)node.textContent=text;
 return node;
}
export function createAircraftLibrary({doc,getReader}={}){
 if(!doc||typeof getReader!=='function')throw Error('Aircraft library document and authenticated reader required');
 const $=id=>doc.getElementById(id);
 const status=$('aircraft-library-status'),list=$('aircraft-library-results');
 const detail=$('aircraft-library-detail'),more=$('aircraft-library-more');
 const search=$('aircraft-library-search'),maker=$('aircraft-library-manufacturer');
 const type=$('aircraft-library-type'),production=$('aircraft-library-production');
 if(![status,list,detail,more,search,maker,type,production].every(Boolean))
  throw Error('Aircraft library page markup missing');
 let aircraft=null,pending=null,visibleCount=18,selectedId=null;
 function statusMessage(message){status.textContent=message}
 function filtered(){
  if(!aircraft)return [];
  const q=search.value.trim().toLocaleLowerCase('en');
  return aircraft.filter(a=>{
   if(maker.value && a.manufacturer!==maker.value)return false;
   if(type.value && a.useType!==type.value)return false;
   if(production.value && a.productionStatus!==production.value)return false;
   return !q || [a.manufacturer,a.family,a.model,a.configuration].some(t=>
     String(t||'').toLocaleLowerCase('en').includes(q));
  });
 }
 function showDetail(a){
  detail.replaceChildren();
  if(!a){detail.hidden=true;return;}
  detail.hidden=false;
  const head=element('div','library-detail-heading');
  const title=element('h2','',a.manufacturer+' '+a.model);
  const subtype=element('p','muted',a.family+' family · '+a.configuration+' · '+a.useType);
  head.append(title,subtype);
  detail.append(head);
  const warnings=element('p','library-disclaimer',
   a.readinessGate!=='PROVISIONAL_DATA_ONLY'
    ?'Special restriction: '+(a.holdReason||a.readinessGate)+'. Not available for unrestricted game operations.'
    :'Planning reference only. The library does not authorize operations or claim aircraft ownership.');
  detail.append(warnings);
  const provenance=element('p','library-evidence',a.gameEstimate||a.productionEndEstimated
   ?'Includes fictional GAME ESTIMATES; see individual conditional fields.':
   a.technicalReview==='verified'
   ?'Technical record marked verified; other fields may still be provisional.'
   :'Technical data currently marked RESEARCH; values can include simplified game estimates.');
  detail.append(provenance);
  const specs=element('div','library-specs');
  const pairs=[
   ['Manufacturer',a.manufacturer],['Family',a.family],['Configuration',a.configuration],
   ['Service',a.serviceStatus||'Unknown'],['New aircraft production',a.productionStatus||'Unknown'],
   ['Original production start',a.productionStart,'year'],
   ['End of production'+(a.productionEndEstimated?' (game estimate)':''),a.productionEnd,'year'],
   ['Typical passenger seats',a.seats],['Maximum passenger seats',a.maxSeats],
   ['Cargo capacity (alternative configurations may apply)',a.cargoKg,'kg'],
   ['Fuel tank capacity',a.fuelKg,'kg'],['Flight range',a.rangeKm,'km'],
   ['Cruise speed',a.speedKmh,'km/h'],['Maximum takeoff weight',a.mtowKg,'kg'],
   ['Maximum landing weight',a.mlwKg,'kg'],
   ['Takeoff runway – published/reference',a.takeoffM,'m'],
   ['Landing runway – published/reference',a.landingM,'m'],
   ['Wingspan',a.wingspanM,'m'],['Aircraft length',a.lengthM,'m'],
   ['Aircraft height',a.heightM,'m']
  ];
  for(const [key,value,unit] of pairs)specs.append(label(key,value,unit==='year'?'':unit||''));
  if(a.requiredEquipment==='AMPHIBIOUS_FLOATS_WITH_WHEELS'){
   specs.append(label('Conditional game takeoff – only with amphibious wheels',a.conditionalTakeoffM,'m'));
   specs.append(label('Conditional game landing – only with amphibious wheels',a.conditionalLandingM,'m'));
   detail.append(element('p','library-disclaimer','Straight floats cannot operate on paved runways. Conditional game values are fictional and do not remove the runway hold.'));
  }
  if(a.useType==='combi')detail.append(element('p','library-disclaimer',
   'Passenger seats and maximum cargo capacity are not necessarily available simultaneously. The loading engine must enforce the selected layout.'));
  detail.append(specs);
 }
 function draw(){
  const data=filtered();
  $('aircraft-library-count').textContent=String(data.length)+' of '+String(aircraft?.length||0)+' configurations';
  list.replaceChildren();
  for(const a of data.slice(0,visibleCount)){
   const card=doc.createElement('button');
   card.type='button';card.className='library-aircraft-card';card.dataset.aircraftId=String(a.id);
   if(a.id===selectedId)card.setAttribute('aria-pressed','true');
   const top=element('span','library-aircraft-maker',a.manufacturer+' · '+a.family);
   const model=element('strong','library-aircraft-model',a.model);
   const config=element('span','library-aircraft-configuration',a.configuration.replaceAll('-',' '));
   const figures=element('span','library-aircraft-figures',
     (a.useType==='cargo'?'Cargo':a.useType==='combi'?'Combi':'Passenger')+
     ' · '+(a.useType==='cargo'?format(a.cargoKg)+' kg':
       format(a.seats??a.maxSeats)+' seats')+
     ' · '+format(a.rangeKm)+' km');
   const tag=element('span','library-aircraft-tag',a.readinessGate!=='PROVISIONAL_DATA_ONLY'
     ?'Special restriction':a.gameEstimate?'Game estimate':a.technicalReview==='verified'?'Reference data':'Research data');
   card.append(top,model,config,figures,tag);
   list.append(card);
  }
  if(!data.length)list.append(element('p','library-no-results','No aircraft match these filters.'));
  more.hidden=data.length<=visibleCount;
  more.disabled=data.length<=visibleCount;
  if(selectedId!==null){
   const selected=aircraft.find(a=>a.id===selectedId);
   showDetail(selected||null);
  }
  statusMessage(aircraft?.length
   ?'Live read-only aircraft catalog loaded. '+aircraft.length+' configurations. Values labelled research or game estimate are provisional.'
   :'Aircraft library not connected.');
 }
 function setupManufacturers(){
  const names=[...new Set(aircraft.map(a=>a.manufacturer))].sort((a,b)=>a.localeCompare(b,'en'));
  const chosen=maker.value;
  maker.replaceChildren(new Option('All manufacturers',''));
  for(const n of names)maker.add(new Option(n,n));
  maker.value=names.includes(chosen)?chosen:'';
 }
 async function load(){
  if(aircraft)return;
  if(pending)return pending;
  const reader=getReader();
  if(!reader||typeof reader.aircraftLibrary!=='function'){
   statusMessage('Sign in and connect to the secure game service to load the aircraft library.');
   return;
  }
  statusMessage('Loading aircraft configurations from the game database…');
  pending=(async()=>{
   try{
    const payload=await reader.aircraftLibrary();
    if(!Array.isArray(payload?.aircraft)||payload.aircraft.length===0||
       payload.aircraft.length>500||payload.aircraft.some(a=>
         !Number.isSafeInteger(a?.id)||typeof a.model!=='string'||typeof a.manufacturer!=='string'))
      throw Error('Invalid aircraft response');
    aircraft=payload.aircraft;
    setupManufacturers();draw();
   }catch{
    statusMessage('The live aircraft library is unavailable. Check the game API and try again.');
    $('aircraft-library-retry').hidden=false;
   }finally{pending=null}
  })();
  return pending;
 }
 for(const field of [search,maker,type,production])field.addEventListener('input',()=>{
  visibleCount=18;selectedId=null;showDetail(null);if(aircraft)draw();
 });
 list.addEventListener('click',e=>{
  const card=e.target.closest('[data-aircraft-id]');
  if(!card||!aircraft)return;
  const id=Number(card.dataset.aircraftId);
  const match=aircraft.find(a=>a.id===id);
  if(!match)return;
  selectedId=id;showDetail(match);
  for(const child of list.querySelectorAll('[data-aircraft-id]'))
   child.setAttribute('aria-pressed',String(Number(child.dataset.aircraftId)===id));
 });
 more.addEventListener('click',()=>{visibleCount+=18;if(aircraft)draw()});
 $('aircraft-library-retry').addEventListener('click',()=>{ $('aircraft-library-retry').hidden=true;void load() });
 return Object.freeze({load});
}
