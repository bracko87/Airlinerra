import {createReadonlyCabinViewer} from './aircraft-cabin-preview.mjs';
/** Airlinerra Settings -> Aircraft Library. Read-only, real catalog data.
 * No fabricated aircraft list, no HTML interpolation of database values.
 */
const format=n=>typeof n==='number'&&Number.isFinite(n)?new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n):'Not recorded';
/**
 * The table already displays manufacturer in its own column. Remove a matching
 * manufacturer prefix from the visible model name only; keep original records
 * untouched for searches, sorting, images, and aircraft identity.
 */
export function aircraftDisplayModel(manufacturer,model){
 const raw=typeof model==='string'?model.trim():'';
 const maker=typeof manufacturer==='string'?manufacturer.trim():'';
 if(!maker||!raw)return raw;
 let display=raw;
 while(display.length>maker.length&&
  display.slice(0,maker.length).toLocaleLowerCase('en')===maker.toLocaleLowerCase('en')&&
  /^\s/.test(display.slice(maker.length))){
  display=display.slice(maker.length).trimStart();
 }
 return display||raw;
}
export function aircraftDisplayName(manufacturer,model){
 const maker=typeof manufacturer==='string'?manufacturer.trim():'';
 return [maker,aircraftDisplayModel(maker,model)].filter(Boolean).join(' ');
}

/* Friendly names for distinct, source-backed configurations of the same model and role.
 * Do not alter model IDs, actual certification labels, or original database names.
 * F is used only where the documented configuration is explicitly a freighter.
 */
const catalogConfigurationLabels=new Map([
 ['Boeing|737-800|cargo|AIR-INUIT-CARGO','737-800 Cargo (Air Inuit)'],
 ['Boeing|737-800|cargo|MYINDO-737-800F','737-800F Cargo (My Indo)'],
 ['Boeing|Boeing 737-400|cargo|AEROSUCRE-CARGO-UNSPECIFIED','737-400 Cargo (Aerosucre)'],
 ['Boeing|Boeing 737-400|cargo|MYINDO-737-400F','737-400F Cargo (My Indo)'],
 ['British Aerospace|BAe 146-200|passenger|PASSENGER-BASE','BAe 146-200 (Standard)'],
 ['British Aerospace|BAe 146-200|passenger|DAP-ANTARCTIC-70','BAe 146-200 (DAP Antarctic 70 seats)'],
 ['De Havilland Canada|Dash 8-300|cargo|AIR-INUIT-CARGO','Dash 8-300 Cargo (Air Inuit)'],
 ['De Havilland Canada|Dash 8-300|cargo|AIR-INUIT-LARGE-DOOR-CARGO','Dash 8-300 Cargo (Large Freight Door)']
]);
export function aircraftCatalogModel(a){
 if(!a)return '';
 const key=[a.manufacturer,a.model,a.useType,a.configuration].join('|');
 return catalogConfigurationLabels.get(key)||aircraftDisplayModel(a.manufacturer,a.model);
}
export function aircraftCatalogName(a){
 return [a.manufacturer,aircraftCatalogModel(a)].filter(Boolean).join(' ');
}
/** A freight reference is not guaranteed free cargo capacity on a real flight. */
export function aircraftServiceSeats(a){
 return a.useType==='cargo'?null:(a.serviceSeats??a.seats??a.maxSeats);
}
/** Physical seats in the saved model factory cabin, not maximum seats or
 * the unchanged manufacturer/service reference. */
export function aircraftFactorySeats(a){
 if(a?.useType==='cargo')return null;
 const cabin=a?.cabinDefault;
 if(cabin&&['economy','premium','business','first'].every(k=>
  Number.isInteger(cabin[k])&&cabin[k]>=0)){
  return cabin.economy+cabin.premium+cabin.business+cabin.first;
 }
 return aircraftServiceSeats(a);
}
export function aircraftServiceCargoLabel(a){
 if(a.useType==='cargo')return typeof a.cargoKg==='number'?format(a.cargoKg):'Unverified';
 if(a.useType==='combi')return typeof a.serviceFreightKg==='number'
  ?format(a.serviceFreightKg)+'*':'Layout-dependent';
 return typeof a.bellyHoldReferenceKg==='number'
  ?format(a.bellyHoldReferenceKg)+'*':'Hold unverified';
}
export function aircraftServiceCargoDetail(a){
 if(a.useType==='cargo')return 'Freighter — cargo capacity subject to load and route limits';
 if(a.useType==='combi')return a.serviceFreightKg!==null&&a.serviceFreightKg!==undefined
  ?'Mixed-use freight reference; weight and baggage limits still apply'
  :'Mixed layout cargo needs separate certification/loading verification';
 return a.bellyHoldReferenceType==='operator_full_passenger_freight'
  ?'Passenger belly freight — operator reference with full passenger load'
  :a.bellyHoldReferenceType==='structural_hold_includes_baggage'
   ?'Rear hold structural limit includes all passenger baggage'
   :'Lower-hold freight eligibility and spare capacity are not yet verified';
}
export function aircraftCatalogConfigurationLabel(a){
 if(a?.manufacturer==='De Havilland Canada'&&a.model==='Dash 8-300'&&
   a.useType==='combi'&&a.configuration==='AIR-INUIT-PASSENGER')return 'AIR INUIT COMBI';
 return String(a?.configuration??'').replaceAll('-',' ');
}
const aircraftNaturalCollator=new Intl.Collator('en',{numeric:true,sensitivity:'base'});
const compareText=(a,b)=>aircraftNaturalCollator.compare(String(a??''),String(b??''));
/** Default and manufacturer/model sorting always group models by maker and family. */
export function compareAircraftCatalog(a,b,sortKey='manufacturer',direction='asc'){
 const dir=direction==='desc'?-1:1;
 const group=()=>compareText(a.manufacturer,b.manufacturer)||
  compareText(a.family,b.family)||
  compareText(aircraftDisplayModel(a.manufacturer,a.model),aircraftDisplayModel(b.manufacturer,b.model))||
  compareText(a.useType,b.useType)||
  compareText(a.configuration,b.configuration)||
  Number(a.id??0)-Number(b.id??0);
 if(sortKey==='manufacturer'||sortKey==='model')return dir*group();
 const sortValue=item=>sortKey==='seats'?aircraftFactorySeats(item):
  sortKey==='cargoKg'?(item.useType==='cargo'?item.cargoKg:
    item.useType==='combi'?item.serviceFreightKg:item.bellyHoldReferenceKg):
  item[sortKey];
 const av=sortValue(a),bv=sortValue(b);
 if(av==null&&bv!=null)return 1;
 if(bv==null&&av!=null)return -1;
 const result=typeof av==='number'&&typeof bv==='number'?av-bv:compareText(av,bv);
 return result?dir*result:group();
}
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
// Passenger appeal is a game-balancing preference, not a safety or certification score.
function popularityBars(score){
 const wrap=element('div','library-popularity-rating');
 if(!Number.isInteger(score)||score<1||score>6){
  wrap.append(element('span','library-popularity-na','Not applicable'));
  return wrap;
 }
 wrap.setAttribute('role','img');
 wrap.setAttribute('aria-label','Passenger popularity '+score+' out of 6');
 const bars=element('div','library-popularity-bars');
 bars.setAttribute('aria-hidden','true');
 for(let level=1;level<=6;level++)bars.append(element('span',
  level<=score?'library-popularity-on':'library-popularity-off'));
 wrap.append(bars,element('span','library-popularity-value',score+'/6'));
 return wrap;
}
// These are exact, approved image filenames; never guess a picture for other variants.
// Images are hosted in the public Admin/Airplanes Supabase Storage folder.
// Verified against public Supabase Storage objects and aircraft configuration model/role records.
const aircraftImages=new Map([
 ["Airbus|A330-200P2F|cargo","Airbus  A330-200P2F cargo.png"],
 ["Airbus|A300-600F|cargo","Airbus A300-600F cargo.png"],
 ["Airbus|A300-600R|passenger","Airbus A300-600R passanger fix.png"],
 ["Airbus|A310-300|cargo","Airbus A310-300 cargo.png"],
 ["Airbus|A310-300|passenger","Airbus A310-300 passenger.png"],
 ["Airbus|A319-100|passenger","Airbus A319-100 passanger fix.png"],
 ["Airbus|A319neo|passenger","Airbus A319neo passanger fix.png"],
 ["Airbus|A320-200|passenger","Airbus A320-200 passenger.png"],
 ["Airbus|A320neo|passenger","Airbus A320neo passenger.png"],
 ["Airbus|A321-100|passenger","Airbus A321-100 passenger.png"],
 ["Airbus|A321-200|cargo","Airbus A321-200 cargo.png"],
 ["Airbus|A321-200|passenger","Airbus A321-200 passenger.png"],
 ["Airbus|A321-200P2F|cargo","Airbus A321-200P2F Cargo fix.png"],
 ["Airbus|A321neo|passenger","Airbus A321neo Passanger fix.png"],
 ["Airbus|A321XLR|passenger","Airbus A321XLR passenger.png"],
 ["Airbus|A330-200|cargo","Airbus A330-200 cargo fix.png"],
 ["Airbus|A330-200|passenger","Airbus A330-200 passenger.png"],
 ["Airbus|A330-200F (factory freighter)|cargo","Airbus A330-200F (factory freighter) cargo.png"],
 ["Airbus|A330-300|passenger","Airbus A330-300 passenger.png"],
 ["Airbus|A330-300P2F|cargo","Airbus A330-300P2F cargo.png"],
 ["Airbus|A330-800neo|passenger","Airbus A330-800neo passenger.png"],
 ["Airbus|A330-900neo|passenger","Airbus A330-900neo passenger.png"],
 ["Airbus|A340-200|passenger","Airbus A340-200 Passenger fix 2.png"],
 ["Airbus|A340-300|passenger","Airbus A340-300 Passenger fix 2.png"],
 ["Airbus|A340-600|passenger","Airbus A340-600 Passenger fix 2.png"],
 ["Airbus|A350-1000|passenger","Airbus A350-1000 passenger.png"],
 ["Airbus|A350-900|passenger","Airbus A350-900 passenger fix.png"],
 ["Airbus|A380-800|passenger","Airbus A380-800 passenger fix.png"],
 ["Airbus Canada|A220-100|passenger","Airbus Canada A220-100 passanger fix.png"],
 ["Airbus Canada|A220-300|passenger","Airbus Canada A220-300 passenger.png"],
 ["Antonov|An-124-100|cargo","Antonov An-124-100 cargo.png"],
 ["Antonov|An-12BK|cargo","Antonov An-12BK cargo.png"],
 ["Antonov|An-12BP|cargo","Antonov An-12BP cargo.png"],
 ["Antonov|An-24|passenger","Antonov An-24 passenger.png"],
 ["Antonov|An-26B-100|combi","Antonov An-26B-100 combi.png"],
 ["Antonov|An-32|cargo","Antonov An-32 cargo.png"],
 ["Antonov|An-74TK-100|cargo","Antonov An-74TK-100 cargo.png"],
 ["Antonov|An-74TK-100|combi","Antonov An-74TK-100 combi.png"],
 ["Antonov|An-74TK-100|passenger","Antonov An-74TK-100 passenger.png"],
 ["ATR|ATR 42-300|passenger","ATR 42-300 passenger.png"],
 ["ATR|ATR 42-320|cargo","ATR 42-320 cargo.png"],
 ["ATR|ATR 42-320|passenger","ATR 42-320 passenger.png"],
 ["ATR|ATR 42-500|passenger","ATR 42-500 passenger.png"],
 ["ATR|ATR 42-600|passenger","ATR 42-600 passenger.png"],
 ["ATR|ATR 72-200|cargo","ATR 72-200 cargo.png"],
 ["ATR|ATR 72-500|cargo","ATR 72-500 cargo.png"],
 ["ATR|ATR 72-500|passenger","ATR 72-500 passenger.png"],
 ["ATR|ATR 72-600|passenger","ATR 72-600 passenger.png"],
 ["ATR|ATR 72-600F|cargo","ATR 72-600F cargo.png"],
 ["Avro|Avro RJ100|passenger","Avro RJ100 passenger.png"],
 ["Avro|Avro RJ85|passenger","Avro RJ85 passenger.png"],
 ["Beechcraft|Beechcraft 1900C|cargo","Beechcraft 1900C cargo.png"],
 ["Beechcraft|Beechcraft 1900D|passenger","Beechcraft 1900D passenger.png"],
 ["Beechcraft|Beechcraft Model 99|cargo","Beechcraft Model 99 cargo.png"],
 ["Boeing|737-600|passenger","Boeing  737-600 passenger.png"],
 ["Boeing|717-200|passenger","Boeing 717-200 passenger.png"],
 ["Boeing|Boeing 727-200 Freighter|cargo","Boeing 727-200 Freighter fix.png"],
 ["Boeing|737 MAX 8|passenger","Boeing 737 MAX 8 passenger.png"],
 ["Boeing|737 MAX 9|passenger","Boeing 737 MAX 9 passenger.png"],
 ["Boeing|737-200C|combi","Boeing 737-200C fix.png"],
 ["Boeing|737-300|cargo","Boeing 737-300 cargo.png"],
 ["Boeing|737-300|passenger","Boeing 737-300 passenger.png"],
 ["Boeing|737-300C|combi","Boeing 737-300C combi.png"],
 ["Boeing|Boeing 737-300SF|cargo","Boeing 737-300SF cargo.png"],
 ["Boeing|Boeing 737-400|cargo","Boeing 737-400 cargo.png"],
 ["Boeing|Boeing 737-400|combi","Boeing 737-400 combi.png"],
 ["Boeing|737-400SF|cargo","Boeing 737-400SF cargo.png"],
 ["Boeing|737-700|passenger","Boeing 737-700 passenger.png"],
 ["Boeing|737-700F (converted freighter)|cargo","Boeing 737-700F (converted freighter) cargo.png"],
 ["Boeing|737-800|cargo","Boeing 737-800 cargo.png"],
 ["Boeing|737-800|combi","Boeing 737-800 combi.png"],
 ["Boeing|737-800|passenger","Boeing 737-800 passenger.png"],
 ["Boeing|737-800BCF|cargo","Boeing 737-800BCF cargo.png"],
 ["Boeing|737-800SF|cargo","Boeing 737-800SF cargo.png"],
 ["Boeing|737-8200|passenger","Boeing 737-8200 passenger.png"],
 ["Boeing|737-900ER|passenger","Boeing 737-900ER passenge.png"],
 ["Boeing|737-900|passenger","Boeing 737-900 fix.png"],
 ["Boeing|747-200F|cargo","Boeing 747-200F fix.png"],
 ["Boeing|767-400ER|passenger","Boeing 767-400ER fix.png"],
 ["Boeing|777-200LR|passenger","Boeing 777-200LR Fix.png"],
 ["Boeing|777-300|passenger","Boeing 777-300 fix.png"],
 ["Boeing|777F|cargo","Boeing 777F fix.png"],
 ["Boeing|787-8|passenger","Boeing 787-8 fix.png"],
 ["Boeing|787-10|passenger","Boeing 787-10 fix.png"],
 ["Boeing|Boeing 737-500|passenger","Boeing 737-500 fix.png"],
 ["British Aerospace|BAe 146-200QT|cargo","British Aerospace BAe 146-200QT fix.png"],
 ["COMAC|C919-100|passenger","COMAC C919-100 fix.png"],
 ["Ilyushin|Il-96-400T|cargo","Ilyushin Il-96-400T fix.png"],
 ["Tupolev|Tu-204-100C|cargo","Tupolev Tu-204-100C fix.png"],
 ["Yakovlev|Yak-42D|passenger","Yakovlev Yak-42D fix.png"],
]);
export function aircraftImagePath(a){
 const configured=typeof a.imagePath==='string'&&
  /^Airplanes\/[^/\\\r\n]{1,180}\.(?:png|jpe?g|webp)$/iu.test(a.imagePath)
   ?a.imagePath.slice('Airplanes/'.length):null;
 const filename=configured||aircraftImages.get([a.manufacturer,a.model,a.useType].join('|'));
 return filename?'https://hwllkabgzaynalahvkpz.supabase.co/storage/v1/object/public/Admin/Airplanes/'+encodeURIComponent(filename):null;
}
/** Expand a truncated table only if the selected aircraft is outside the rendered rows. */
export const AIRCRAFT_LIBRARY_PAGE_SIZE=20;
export function libraryPageForSelection(records,selectedId,currentPage=0){
 const index=Array.isArray(records)?records.findIndex(a=>a?.id===selectedId):-1;
 return index<0?currentPage:Math.floor(index/AIRCRAFT_LIBRARY_PAGE_SIZE);
}

export function createAircraftLibrary({doc,getReader}={}){
 if(!doc||typeof getReader!=='function')throw Error('Aircraft library document and authenticated reader required');
 const $=id=>doc.getElementById(id);
 const status=$('aircraft-library-status'),list=$('aircraft-library-results');
 const detail=$('aircraft-library-detail'),more=$('aircraft-library-more');
 const previous=$('aircraft-library-previous'),pageInfo=$('aircraft-library-page');
 const search=$('aircraft-library-search'),maker=$('aircraft-library-manufacturer');
 const type=$('aircraft-library-type'),production=$('aircraft-library-production');
 if(![status,list,detail,more,previous,pageInfo,search,maker,type,production].every(Boolean))
  throw Error('Aircraft library page markup missing');
 let aircraft=null,pending=null,currentPage=0,sortKey='manufacturer',sortDirection='asc';
 let lastSelectedAircraftId=null;
 const warmPictures=new Map();
 const cabinViewer=createReadonlyCabinViewer({doc});
 const cabinNavButton=$('library-profile-cabin-button');
 if(!cabinNavButton)throw Error('Aircraft profile cabin navigation button missing');
 cabinNavButton.addEventListener('click',()=>{
  const a=aircraft?.find(x=>x.id===lastSelectedAircraftId);
  if(!a||a.useType==='cargo'||!a.cabinDefault)return;
  cabinViewer.show({title:aircraftCatalogName(a),useType:a.useType,
   cabin:a.cabinDefault,referenceUnits:a.cabinDefault.referenceUnits,
   geometry:a.cabinDefault.geometry,origin:'model_default'});
 });
 function warmAircraftPhoto(a){
  const url=aircraftImagePath(a);
  if(!url||warmPictures.has(url))return;
  // Only warm pictures that a player approaches; never download the entire catalog.
  const img=doc.createElement('img');
  img.decoding='async';
  img.loading='eager';
  // A failed warm request must not be reused later as a permanently broken image.
  img.addEventListener('error',()=>warmPictures.delete(url),{once:true});
  warmPictures.set(url,img);
  img.src=url;
  if(warmPictures.size>10)warmPictures.delete(warmPictures.keys().next().value);
 }
 function statusMessage(message){status.textContent=message}
 function filtered(){
  if(!aircraft)return [];
  const q=search.value.trim().toLocaleLowerCase('en');
  return aircraft.filter(a=>{
   if(maker.value && a.manufacturer!==maker.value)return false;
   if(type.value && a.useType!==type.value)return false;
   if(production.value && a.productionStatus!==production.value)return false;
   return !q || [a.manufacturer,a.family,a.model,a.configuration,aircraftCatalogModel(a)].some(t=>
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
 function liveFleetGroup(a){
  const group=element('section','library-profile-group library-profile-live-fleet');
  group.append(element('h3','','Aircraft in game'));
  const usage=element('div','library-fleet-total');
  const count=Number.isSafeInteger(a.fleetInUse)&&a.fleetInUse>=0?a.fleetInUse:null;
  usage.append(element('span','','Currently in use'),element('span','library-fleet-count',count===null?'—':format(count)));
  group.append(usage,element('h4','library-fleet-title','Top 3 airlines by quantity'));
  if(!Array.isArray(a.topAirlines)||a.topAirlines.length===0){
   group.append(element('p','library-fleet-empty',
    count===null?'Live fleet data is temporarily unavailable.':'No airlines currently use this aircraft configuration.'));
  }else{
   const operators=element('ol','library-fleet-operators');
   for(const operator of a.topAirlines.slice(0,3)){
    const row=element('li','library-fleet-operator');
    row.append(element('span','',operator.airlineName),
     element('strong','',format(operator.quantity)));
    operators.append(row);
   }
   group.append(operators);
  }
  return group;
 }
 function showDetail(a){
  if(!a)return;
  lastSelectedAircraftId=a.id;
  detail.replaceChildren();
  const sheet=element('div','library-profile-content');
  const header=element('div','library-profile-header');
  const heading=element('div','');
  const title=element('h2','',aircraftCatalogName(a));
  title.id='aircraft-library-profile-title';
  heading.append(title);
  header.append(heading);
  cabinNavButton.hidden=a.useType==='cargo'||!a.cabinDefault||
   !Number.isInteger(a.cabinDefault.economy);
  const hero=element('div','library-profile-hero');
  const image=element('div','library-profile-image');
  const path=aircraftImagePath(a);
  if(path){
   // Reuse an image warmed by hover/focus, or request it immediately at high priority.
   const picture=warmPictures.get(path)||element('img','library-profile-aircraft-photo');
   warmPictures.delete(path);
   picture.className='library-profile-aircraft-photo';
   picture.alt=aircraftCatalogName(a)+' '+a.useType+' aircraft, unbranded side profile';
   picture.loading='eager';
   picture.decoding='async';
   picture.fetchPriority='high';
   picture.addEventListener('error',()=>{
    picture.remove();
    image.append(element('span','library-profile-image-unavailable','Aircraft image unavailable'));
   },{once:true});
   image.append(picture);
   if(picture.src!==path)picture.src=path;
  }else{
   image.append(element('span','library-profile-image-unavailable','Aircraft image unavailable'));
  }
  const highlights=element('div','library-profile-highlights');
  const noiseChapter=a.icaoNoiseChapter??a.gameNoiseChapter;
  const summary=[
   ['Role',a.useType],
   ['Seats · factory layout',a.useType==='cargo'?'—':(aircraftFactorySeats(a)??'Not recorded')],
   ['Cargo · kg (reference)',aircraftServiceCargoLabel(a)],
   ['Range',a.rangeKm===null?'Not recorded':format(a.rangeKm)+' km'],
   ['Fuel tank',a.fuelKg===null?'Not recorded':format(a.fuelKg)+' kg'],
   ['Production',a.productionStatus?.replaceAll('_',' ')||'Unconfirmed'],
   ['Noise chapter',noiseChapter===null||noiseChapter===undefined?'—':'Chapter '+noiseChapter],
   ['Passenger popularity',a.passengerPopularityScore]
  ];
  for(const [name,value] of summary){
   const item=element('div','library-profile-highlight');
   item.append(element('span','',name));
   item.append(name==='Passenger popularity'?popularityBars(value):
    element('strong','',String(value??'Not recorded')));
   highlights.append(item);
  }
  hero.append(image,highlights);
  sheet.append(header,hero);
  // The route/game readiness gate is enforced server-side, not printed as a technical error on this page.
  // Evidence and qualification details remain available in the specification panels below.
  const groups=element('div','library-profile-groups');
  groups.append(
   specificationGroup('Identity & production',[
    ['Manufacturer',a.manufacturer],['Aircraft family',a.family],['Model',aircraftCatalogModel(a)],
    ['Configuration',a.configuration],['Role',a.useType],
    ['Civilian service status',a.serviceStatus],['New-aircraft production',a.productionStatus],
    ['First production year',a.productionStart,'year'],
    ['End production year'+(a.productionEndEstimated?' (estimated)':''),a.productionEnd,'year']
   ]),
   specificationGroup('Passenger, cargo & fuel',[
    ['Seats · factory layout',a.useType==='cargo'?'—':aircraftFactorySeats(a)],
    ['Service seating reference (not installed)',a.useType==='cargo'?'—':aircraftServiceSeats(a)],
    ['Passenger-only seating reference',a.useType==='combi'?(a.maxSeats??a.seats):'—'],
    ['Mixed-layout freight (kg)',a.useType==='combi'?(a.serviceFreightKg??'Not verified'):'—'],
    ['Passenger belly-hold reference (kg)',a.useType==='passenger'?(a.bellyHoldReferenceKg??'Not verified'):'—'],
    ['Cargo basis',aircraftServiceCargoDetail(a)],
    ['Advertised cargo-only ceiling (kg)',a.useType==='combi'?(a.cargoKg??'Not recorded'):'—'],
    ['Full freighter cargo (kg)',a.useType==='cargo'?(a.cargoKg??'Not recorded'):'—'],
    ['Service seat evidence',a.useType==='combi'?
      (a.serviceSeatBasis==='game_estimate'?'Game estimate':a.serviceSeatBasis==='operator_combi'?'Operator published':'Research'):
      'Not applicable'],
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
   specificationGroup('Noise & airport eligibility',[
     ['ICAO noise chapter',noiseChapter===null||noiseChapter===undefined?'—':'Chapter '+noiseChapter],
     ['Representative engine',a.representativeEngine],
     ['Airport access','Subject to applicable airport noise rules and curfews']
    ]),
    liveFleetGroup(a)
  );
  if(a.requiredEquipment==='AMPHIBIOUS_FLOATS_WITH_WHEELS'){
   groups.append(specificationGroup('Conditional amphibious-wheel reference',[
    ['Conditional takeoff (game estimate)',a.conditionalTakeoffM,'m'],
    ['Conditional landing (game estimate)',a.conditionalLandingM,'m']
   ]));
   sheet.append(element('p','library-disclaimer',
    'Airlinerra assumes retractable amphibious landing wheels are installed for these game configurations. These runway distances are fictional game estimates, not certified real-world performance.'));
  }
  sheet.append(groups);
  if(a.useType==='combi')sheet.append(element('p','library-disclaimer',
   'A combi uses one passenger-and-freight layout. Full-passenger seats and advertised cargo-only payload cannot be combined; a mixed-seat figure labeled game estimate is provisional.'));
  if(a.useType==='passenger')sheet.append(element('p','library-disclaimer',
   'Passenger aircraft may carry lower-hold freight alongside luggage. Freight marked with * is a reference, not guaranteed bookable capacity; baggage, fuel, gross weight and available airport handling must be checked.'));
  sheet.append(element('p','library-profile-footer',
   'Aircraft data is for planning and comparison. Operating clearance is handled separately.'));
  detail.append(sheet);
  detail.setAttribute('aria-labelledby','aircraft-library-profile-title');
  window.location.hash='aircraft-profile';
  window.scrollTo(0,0);
 }
 function sortRecords(records){
  return [...records].sort((a,b)=>compareAircraftCatalog(a,b,sortKey,sortDirection));
 }
 function draw(){
  const data=sortRecords(filtered());
  $('aircraft-library-count').textContent=String(data.length)+' of '+String(aircraft?.length||0)+' configurations';
  const totalPages=Math.max(1,Math.ceil(data.length/AIRCRAFT_LIBRARY_PAGE_SIZE));
  currentPage=Math.max(0,Math.min(currentPage,totalPages-1));
  list.replaceChildren();
  const table=element('table','library-table');
  const thead=element('thead','');
  const header=element('tr','');
  const columns=[
   ['manufacturer','Manufacturer'],['model','Model / family'],['useType','Role'],
   ['seats','Seats · factory'],['cargoKg','Cargo ref. (kg)'],['rangeKm','Range (km)'],
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
  for(const a of data.slice(currentPage*AIRCRAFT_LIBRARY_PAGE_SIZE,(currentPage+1)*AIRCRAFT_LIBRARY_PAGE_SIZE)){
   const row=element('tr','library-table-row');
   row.dataset.aircraftId=String(a.id);
   const values=[
    a.manufacturer,null,a.useType,
    aircraftFactorySeats(a),aircraftServiceCargoLabel(a),a.rangeKm,a.speedKmh,a.fuelKg,
    a.productionStatus?.replaceAll('_',' ')||'Unconfirmed'
   ];
   for(let i=0;i<values.length;i++){
    const td=element('td',i>=3&&i<=7?'library-numeric':'');
    if(i===1){
     const open=element('button','library-model-link',aircraftCatalogModel(a));
     open.type='button';open.setAttribute('aria-label','Open profile for '+aircraftCatalogName(a));
     td.append(open,element('span','library-table-family',a.family+' · '+aircraftCatalogConfigurationLabel(a)));
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
  const hasMultiplePages=totalPages>1;
  more.hidden=!hasMultiplePages;
  previous.hidden=!hasMultiplePages;
  more.disabled=currentPage>=totalPages-1;
  previous.disabled=currentPage<=0;
  pageInfo.textContent='Page '+(currentPage+1)+' of '+totalPages+' · 20 aircraft per page';
  statusMessage(aircraft?.length
   ?'Live read-only aircraft catalog loaded. '+aircraft.length+' configurations. Research and game estimates are provisional.'
   :'Aircraft library not connected.');
 }
 function restoreLastSelection(){
  if(!aircraft||lastSelectedAircraftId===null)return false;
  const ordered=sortRecords(filtered());
  if(!ordered.some(a=>a.id===lastSelectedAircraftId))return false;
  const selectedPage=libraryPageForSelection(ordered,lastSelectedAircraftId,currentPage);
  if(selectedPage!==currentPage){currentPage=selectedPage;draw();}
  const row=[...list.querySelectorAll('[data-aircraft-id]')]
   .find(node=>Number(node.dataset.aircraftId)===lastSelectedAircraftId);
  if(!row)return false;
  list.querySelectorAll('.library-return-selected').forEach(node=>
   node.classList.remove('library-return-selected'));
  row.classList.add('library-return-selected');
  row.querySelector('.library-model-link')?.focus({preventScroll:true});
  row.scrollIntoView({block:'center',inline:'nearest',behavior:'instant'});
  return true;
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
  currentPage=0;if(aircraft)draw();
 });
 // Start fetching when a user hovers or tabs toward an aircraft, before opening it.
 function warmRow(e){
  const row=e.target.closest?.('[data-aircraft-id]');
  if(!row||!aircraft)return;
  const selected=aircraft.find(a=>a.id===Number(row.dataset.aircraftId));
  if(selected)warmAircraftPhoto(selected);
 }
 list.addEventListener('pointerover',warmRow);
 list.addEventListener('focusin',warmRow);
 list.addEventListener('click',e=>{
  const sort=e.target.closest('[data-sort-key]');
  if(sort){
   const key=sort.dataset.sortKey;
   sortDirection=sortKey===key&&sortDirection==='asc'?'desc':'asc';
   sortKey=key;currentPage=0;if(aircraft)draw();return;
  }
  const row=e.target.closest('[data-aircraft-id]');
  if(!row||!aircraft)return;
  const match=aircraft.find(a=>a.id===Number(row.dataset.aircraftId));
  if(match)showDetail(match);
 });
 function changePage(delta){
  if(!aircraft)return;
  const totalPages=Math.max(1,Math.ceil(filtered().length/AIRCRAFT_LIBRARY_PAGE_SIZE));
  const next=Math.max(0,Math.min(totalPages-1,currentPage+delta));
  if(next===currentPage)return;
  currentPage=next;
  draw();
  list.scrollIntoView({block:'start',inline:'nearest',behavior:'instant'});
 }
 previous.addEventListener('click',()=>changePage(-1));
 more.addEventListener('click',()=>changePage(1));
 $('aircraft-library-retry').addEventListener('click',()=>{ $('aircraft-library-retry').hidden=true;void load() });
 return Object.freeze({load,restoreLastSelection});
}
