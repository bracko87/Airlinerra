/** Airlinerra Settings -> Aircraft Library. Read-only, real catalog data.
 * No fabricated aircraft list, no HTML interpolation of database values.
 */
const format=n=>typeof n==='number'&&Number.isFinite(n)?new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n):'Not recorded';
const label=(name,value,unit='')=>{
 const row=document.createElement('div');
 row.className='library-spec';
 const term=document.createElement('span');term.textContent=name;
 const val=document.createElement('strong');val.textContent=value===null||value===undefined?'Not recorded':
   typeof value==='number'?(unit==='year'?String(value):format(value)+(unit?' '+unit:'')):String(value);
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
 let aircraft=null,pending=null,visibleCount=40,sortKey='manufacturer',sortDirection='asc';
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
 function specificationGroup(name,fields){
  const group=element('section','library-profile-group');
  group.append(element('h3','',name));
  const specs=element('div','library-specs');
  for(const [title,value,unit] of fields)specs.append(label(title,value,unit||''));
  group.append(specs);return group;
 }
 function showDetail(a){
  if(!a)return;
  detail.replaceChildren();
  const sheet=element('div','library-profile-content');
  const header=element('div','library-profile-header');
  const heading=element('div','');
  heading.append(element('p','library-profile-kicker','AIRLINERRA · AIRCRAFT PROFILE'));
  const title=element('h2','',a.manufacturer+' '+a.model);
  title.id='aircraft-library-profile-title';
  heading.append(title,element('p','library-profile-subtitle',a.family+' · '+a.configuration.replaceAll('-',' ')+' · '+a.useType));
  header.append(heading);
  const hero=element('div','library-profile-hero');
  const image=element('div','library-profile-image');
  image.setAttribute('role','img');
  image.setAttribute('aria-label','Space reserved for a photograph of '+a.model);
  const icon=element('span','library-profile-plane','✈');
  icon.setAttribute('aria-hidden','true');
  image.append(icon,element('strong','','Aircraft photo'),element('span','','Image space reserved · no verified model photo yet'));
  const highlights=element('div','library-profile-highlights');
  const summary=[
   ['Role',a.useType],['Passenger seats',a.seats??a.maxSeats],
   ['Cargo payload',a.cargoKg===null?'Not recorded':format(a.cargoKg)+' kg'],
   ['Range',a.rangeKm===null?'Not recorded':format(a.rangeKm)+' km'],
   ['Fuel tank',a.fuelKg===null?'Not recorded':format(a.fuelKg)+' kg'],
   ['Production',a.productionStatus?.replaceAll('_',' ')||'Unconfirmed']
  ];
  for(const [name,value] of summary){
   const item=element('div','library-profile-highlight');
   item.append(element('span','',name),element('strong','',String(value??'Not recorded')));
   highlights.append(item);
  }
  hero.append(image,highlights);
  sheet.append(header,hero);
  if(a.readinessGate!=='PROVISIONAL_DATA_ONLY')
   sheet.append(element('p','library-disclaimer',
    'Operating restriction: '+(a.holdReason||a.readinessGate)+'. This catalog entry does not grant flight clearance.'));
  if(a.gameEstimate||a.productionEndEstimated)
   sheet.append(element('p','library-evidence',
    'Some figures are fictional game-planning estimates, not independently verified manufacturer specifications.'));
  else sheet.append(element('p','library-evidence',
    a.technicalReview==='verified'
     ?'Technical record marked verified; other data may still be provisional.'
     :'Technical data marked RESEARCH; treat specifications as provisional.'));
  const groups=element('div','library-profile-groups');
  groups.append(
   specificationGroup('Identity & production',[
    ['Manufacturer',a.manufacturer],['Aircraft family',a.family],['Model',a.model],
    ['Configuration',a.configuration],['Role',a.useType],
    ['Civilian service status',a.serviceStatus],['New-aircraft production',a.productionStatus],
    ['First production year',a.productionStart,'year'],
    ['End production year'+(a.productionEndEstimated?' (estimated)':''),a.productionEnd,'year']
   ]),
   specificationGroup('Passenger, cargo & fuel',[
    ['Typical seats',a.seats],['Maximum seats',a.maxSeats],
    ['Maximum cargo payload',a.cargoKg,'kg'],
    ['Fuel tank capacity',a.fuelKg,'kg']
   ]),
   specificationGroup('Flight performance & weights',[
    ['Flight range',a.rangeKm,'km'],['Cruise speed',a.speedKmh,'km/h'],
    ['Takeoff runway · published/reference',a.takeoffM,'m'],
    ['Landing runway · published/reference',a.landingM,'m'],
    ['Maximum takeoff weight',a.mtowKg,'kg'],
    ['Maximum landing weight',a.mlwKg,'kg']
   ]),
   specificationGroup('Dimensions',[
    ['Wingspan',a.wingspanM,'m'],['Aircraft length',a.lengthM,'m'],
    ['Aircraft height',a.heightM,'m']
   ]),
   specificationGroup('Source & operational qualifications',[
    ['Technical review',a.technicalReview],
    ['Fictional game estimate',a.gameEstimate?'Yes':'No'],
    ['Operational readiness gate',a.readinessGate],
    ['Restriction reason',a.holdReason],
    ['Required equipment',a.requiredEquipment]
   ])
  );
  if(a.requiredEquipment==='AMPHIBIOUS_FLOATS_WITH_WHEELS'){
   groups.append(specificationGroup('Conditional amphibious-wheel reference',[
    ['Conditional takeoff (game estimate)',a.conditionalTakeoffM,'m'],
    ['Conditional landing (game estimate)',a.conditionalLandingM,'m']
   ]));
   sheet.append(element('p','library-disclaimer',
    'Straight floats cannot use paved runways. These conditional figures require the specified equipment and do not remove the runway hold.'));
  }
  sheet.append(groups);
  if(a.useType==='combi')sheet.append(element('p','library-disclaimer',
   'Combi aircraft cannot necessarily carry maximum passenger seats and maximum cargo payload at the same time.'));
  sheet.append(element('p','library-profile-footer',
   'Read-only reference. Buying, assigning or dispatching aircraft is not available from this library.'));
  detail.append(sheet);
  detail.setAttribute('aria-labelledby','aircraft-library-profile-title');
  window.location.hash='aircraft-profile';
  window.scrollTo(0,0);
 }
 function sortRecords(records){
  const key=sortKey,dir=sortDirection==='asc'?1:-1;
  return [...records].sort((a,b)=>{
   const av=a[key],bv=b[key];
   if(av===null||av===undefined)return bv===null||bv===undefined?0:1;
   if(bv===null||bv===undefined)return -1;
   const result=typeof av==='number'&&typeof bv==='number'?av-bv:
    String(av).localeCompare(String(bv),'en',{numeric:true,sensitivity:'base'});
   return result?result*dir:a.manufacturer.localeCompare(b.manufacturer,'en')||
     a.model.localeCompare(b.model,'en',{numeric:true});
  });
 }
 function draw(){
  const data=sortRecords(filtered());
  $('aircraft-library-count').textContent=String(data.length)+' of '+String(aircraft?.length||0)+' configurations';
  list.replaceChildren();
  const table=element('table','library-table');
  const thead=element('thead','');
  const header=element('tr','');
  const columns=[
   ['manufacturer','Manufacturer'],['model','Model / family'],['useType','Role'],
   ['seats','Seats'],['cargoKg','Cargo (kg)'],['rangeKm','Range (km)'],
   ['speedKmh','Cruise (km/h)'],['fuelKg','Fuel (kg)'],
   ['productionStatus','Production']
  ];
  for(const [key,text] of columns){
   const th=element('th','');
   th.scope='col';th.setAttribute('aria-sort',key===sortKey?(sortDirection==='asc'?'ascending':'descending'):'none');
   const button=element('button','library-sort',text+(key===sortKey?(sortDirection==='asc'?' ↑':' ↓'):''));
   button.type='button';button.dataset.sortKey=key;
   button.title='Sort by '+text;
   th.append(button);header.append(th);
  }
  thead.append(header);table.append(thead);
  const body=element('tbody','');
  for(const a of data.slice(0,visibleCount)){
   const row=element('tr','library-table-row');
   row.dataset.aircraftId=String(a.id);
   const values=[
    a.manufacturer,null,a.useType,
    a.seats??a.maxSeats,a.cargoKg,a.rangeKm,a.speedKmh,a.fuelKg,
    a.productionStatus?.replaceAll('_',' ')||'Unconfirmed'
   ];
   for(let i=0;i<values.length;i++){
    const td=element('td',i>=3&&i<=7?'library-numeric':'');
    if(i===1){
     const open=element('button','library-model-link',a.model);
     open.type='button';open.setAttribute('aria-label','Open profile for '+a.manufacturer+' '+a.model);
     td.append(open,element('span','library-table-family',a.family+' · '+a.configuration.replaceAll('-',' ')));
    }else if(i===8){
     td.append(element('span','library-production-status',values[i]));
    }else td.textContent=(values[i]===null||values[i]===undefined)?'—':
      typeof values[i]==='number'?format(values[i]):String(values[i]);
    row.append(td);
   }
   body.append(row);
  }
  table.append(body);list.append(table);
  if(!data.length)list.append(element('p','library-no-results','No aircraft match these filters.'));
  more.hidden=data.length<=visibleCount;
  more.disabled=data.length<=visibleCount;
  statusMessage(aircraft?.length
   ?'Live read-only aircraft catalog loaded. '+aircraft.length+' configurations. Research and game estimates are provisional.'
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
  visibleCount=40;if(aircraft)draw();
 });
 list.addEventListener('click',e=>{
  const sort=e.target.closest('[data-sort-key]');
  if(sort){
   const key=sort.dataset.sortKey;
   sortDirection=sortKey===key&&sortDirection==='asc'?'desc':'asc';
   sortKey=key;if(aircraft)draw();return;
  }
  const row=e.target.closest('[data-aircraft-id]');
  if(!row||!aircraft)return;
  const match=aircraft.find(a=>a.id===Number(row.dataset.aircraftId));
  if(match)showDetail(match);
 });
 more.addEventListener('click',()=>{visibleCount+=40;if(aircraft)draw()});
 $('aircraft-library-retry').addEventListener('click',()=>{ $('aircraft-library-retry').hidden=true;void load() });
 return Object.freeze({load});
}
