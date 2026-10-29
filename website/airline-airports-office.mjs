/** Airlinerra airport office - real HQ + private hub and station proposals.
 * Airport data source is only the authenticated, approved World 1 catalog.
 * No simulation of fees, salaries, slots, demand, routes or flights.
 */
import {createAirportCountryPicker,populateAirportCountries} from './airport-country-picker.mjs';
const AIRPORT_KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/;
const currency=v=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(v);
const safeLocalValue=(v)=>typeof v==='string'?v.trim():'';
const textValue=(v)=>typeof v==='string'&&v.trim()?v.trim():'Data pending';
export function normalizeApprovedAirport(a){
 if(!a||!AIRPORT_KEY.test(a.key||'')||typeof a.name!=='string'||!a.name.trim())return null;
 return Object.freeze({key:a.key,name:a.name.trim(),code:safeLocalValue(a.code),
  countryIso:/^[A-Z]{2}$/.test(a.countryIso||'')?a.countryIso:null,
  municipality:safeLocalValue(a.municipality)});
}
export function proposeAirportOffice({type,airport,homeAirportKey,existing=[]}={}){
 const a=normalizeApprovedAirport(airport);
 if(!a||!['hub','station'].includes(type))return {ok:false,reason:'Choose an approved airport.'};
 if(!a.countryIso)return {ok:false,reason:'Select an airport from a country first.'};
 if(a.key===homeAirportKey)return {ok:false,reason:'Headquarters is already your permanent home base.'};
 if(existing.some(x=>x?.key===a.key))return {ok:false,reason:'An office proposal already exists for this airport.'};
 if(existing.length>=20)return {ok:false,reason:'Maximum 20 combined office proposals per browser session.'};
 return {ok:true,entry:Object.freeze({...a,type,status:'draft',minimumStaff:type==='station'?1:null})};
}
const panel=(kicker,title,body)=>'<article class="panel airport-office-panel"><span class="panel-kicker">'+kicker+'</span><h2>'+title+'</h2>'+body+'</article>';
function createText(doc,tag,value,cls){
 const element=doc.createElement(tag);if(cls)element.className=cls;
 element.textContent=value;return element;
}
function row(doc,label,value,root){
 const div=doc.createElement('div');div.className='airport-profile-fact';
 div.append(createText(doc,'span',label),createText(doc,'strong',value));
 root.append(div);return div;
}
function button(doc,label,action,key){
 const b=doc.createElement('button');b.type='button';b.className='secondary';
 b.textContent=label;b.dataset.officeAction=action;
 if(key)b.dataset.airportKey=key;return b;
}
const readSession=(store,key)=>{try{return JSON.parse(store?.getItem(key)||'{}')||{}}catch{return {}}};
const saveSession=(store,key,entries)=>{
 try{const current=readSession(store,key);store?.setItem(key,JSON.stringify({...current,airportOffices:entries}));return !!store}
 catch{return false}
};
const countryLabel=code=>{
 if(!code)return 'Data pending';
 try{return new Intl.DisplayNames(['en'],{type:'region'}).of(code)||code}catch{return code}
};
export function createAirportOffice({doc,session,identity,goTo}={}){
 if(!doc||typeof identity!=='string'||!/^[\w-]{3,128}$/.test(identity))
  throw Error('Verified account required for airport office');
 const key='airlinerra.local.workplan.v1.'+identity;
 const $=id=>doc.getElementById(id);
 const host=$('workspace-hubs'),profileHost=$('workspace-airport-profile');
 let live={connected:false,airline:null,countries:[],reader:null};
 let selectedAirport=null,activeAirport=null,officePicker=null;
 const known=new Map();
 const entries=()=>{
  const current=readSession(session,key);
  if(Array.isArray(current.airportOffices))return current.airportOffices.filter(x=>x?.status==='draft'&&
   ['hub','station'].includes(x.type)&&normalizeApprovedAirport(x));
  // Backward compatibility: previously proposed hubs had no country.
  return Array.isArray(current.hubs)?current.hubs.filter(x=>normalizeApprovedAirport(x)).map(x=>({
   ...x,type:'hub',status:'draft',countryIso:x.countryIso||null
  })):[];
 };
 if(host){
  host.innerHTML=panel('HEADQUARTERS','Registered headquarters',
   '<p class="hint">This is the airport chosen when the airline was created. It is company identity, not an additional paid hub.</p>'+
   '<div class="airport-office-headquarters"><div><span class="hint">Home airport</span><h3 id="airport-office-hq-name">Checking...</h3>'+
   '<p id="airport-office-hq-code" class="hint"></p></div>'+
   '<button type="button" class="secondary" data-office-action="home-profile">Airport profile</button></div>')+
   panel('HUBS AND STATIONS','Plan an airport office',
    '<p class="hint">Hubs support aircraft and connecting operations. A station is a smaller local presence, normally requiring at least one representative. Both remain proposals until the airport fees, staffing and activation engine are ready.</p>'+
    '<div class="airport-office-form"><label for="office-location-type">Office type</label>'+
    '<select id="office-location-type"><option value="hub">Additional hub</option><option value="station">Station</option></select>'+
    '<label for="office-country">Country</label><select id="office-country"><option value="">Choose country</option></select>'+
    '<label for="office-search">Filter airport</label><input id="office-search" maxlength="40" placeholder="Filter airports in selected country">'+
    '<label for="office-result">Approved airport</label><select id="office-result" disabled><option value="">Choose country first</option></select>'+
    '<div class="airport-office-form-actions"><button type="button" class="primary" id="office-save">Save proposed location</button>'+
    '<button type="button" class="secondary" id="office-preview">Airport profile</button></div></div>'+
    '<p id="office-feedback" class="hint" role="status"></p>')+
   panel('NETWORK LOCATIONS','My hubs',
    '<div class="airport-office-summary"><span>Active additional hubs</span><strong>Not connected</strong></div>'+
    '<div id="office-hub-list" class="operations-route-table"></div>')+
   panel('AIRPORT REPRESENTATION','My stations',
    '<p class="hint">One proposed local representative per station is the minimum staffing concept. Salaries and airport desk fees will be configured before activation.</p>'+
    '<div class="airport-office-summary"><span>Active stations</span><strong>Not connected</strong></div>'+
    '<div id="office-station-list" class="operations-route-table"></div>')+
   panel('COST MODEL','Office costs - future activation',
    '<div class="airport-office-cost-grid"><div><strong>Hub opening charge</strong><span>Airport-dependent - not configured</span></div>'+
    '<div><strong>Hub recurring charge</strong><span>Size, slots, services and aircraft basing - data pending</span></div>'+
    '<div><strong>Station desk fee</strong><span>Airport-dependent recurring charge - not configured</span></div>'+
    '<div><strong>Station representative</strong><span>At least one employee; salary table pending integration</span></div></div>'+
    '<p class="hint">Saving an office proposal does not open a hub or station, reserve slots, hire staff or spend airline funds.</p>');
 }
 if(profileHost){
  profileHost.innerHTML=panel('AIRPORT DIRECTORY','Airport profile',
   '<div class="airport-profile-head"><div><p class="hint">World 1 approved airport</p>'+
   '<h3 id="airport-profile-name">Select an airport</h3><p id="airport-profile-location" class="hint"></p></div>'+
   '<button type="button" class="secondary" data-office-action="back">Back to hubs and stations</button></div>'+
   '<div id="airport-profile-facts" class="airport-profile-facts"></div>')+
   panel('AIRPORT INFRASTRUCTURE','Runways, terminals and slots',
    '<div id="airport-profile-infrastructure" class="airport-profile-facts"></div>')+
   panel('MARKET DEMAND','Passenger and cargo demand',
    '<p class="hint">Passenger/cargo demand, annual traffic and route potential will be populated from verified data. No artificial percentages.</p>'+
    '<div id="airport-profile-demand" class="airport-profile-facts"></div>')+
   panel('AIRLINE ACTIVITY','Airlines and airport presence',
    '<div id="airport-profile-airlines" class="airport-profile-facts"></div>'+
    '<p class="hint">Airlines with headquarters, hubs, stations and operations will be listed when a verified multi-airline operations read model exists.</p>')+
   panel('FLIGHT BOARD','Current departures and arrivals',
    '<div class="airport-flight-board"><div class="airport-flight-columns"><span>Time</span><span>Airline</span><span>Flight</span><span>Origin / destination</span><span>Status</span></div>'+
    '<p>Live airport flight movements are not connected yet.</p></div>')+
   panel('AIRPORT ROUTE NETWORK','Destinations and frequencies',
    '<p class="hint">Connections, operating airlines, flight frequency and passenger load statistics will appear when verified flight scheduling is connected.</p>');
 }
 const feedback=t=>{if($('office-feedback'))$('office-feedback').textContent=t};
 officePicker=createAirportCountryPicker({
  country:$('office-country'),search:$('office-search'),airport:$('office-result'),
  getReader:()=>live.connected?live.reader:null,
  onStatus:message=>feedback(message),
  onSelect:airport=>{selectedAirport=airport;if(airport)remember(airport);}
 });
 function remember(a){const normalized=normalizeApprovedAirport(a);if(normalized)known.set(normalized.key,normalized);return normalized}
 function headquarters(){
  const a=live.airline;
  const airport=a?.homeAirportKey?remember({key:a.homeAirportKey,name:a.homeAirportName||'Home airport',
   code:a.homeAirportCode||'',countryIso:a.homeAirportCountryIso||null,
   municipality:a.homeAirportMunicipality||''}):null;
  if($('airport-office-hq-name'))$('airport-office-hq-name').textContent=
   live.connected?airport?.name||'No headquarters assigned':'Not connected';
  if($('airport-office-hq-code'))$('airport-office-hq-code').textContent=
   airport?.code?'Airport code: '+airport.code:'Airport code unavailable';
 }
 function directories(){
  populateAirportCountries($('office-country'),live.countries,doc);
 }
 function renderList(type){
  const target=$(type==='hub'?'office-hub-list':'office-station-list');if(!target)return;
  target.replaceChildren();
  const items=entries().filter(e=>e.type===type);
  if(!items.length){target.append(createText(doc,'p',
   type==='hub'?'No additional hub proposals saved.':'No station proposals saved.','hint'));return}
  for(const office of items){
   const line=doc.createElement('div');line.className='airport-office-list-row';
   const text=doc.createElement('div');
   text.append(createText(doc,'strong',office.name+' ('+(office.code||'-')+')'),
    createText(doc,'span',type==='hub'?
      'Additional hub - proposal only':'Station - proposal only; 1 planned representative minimum','hint'));
   const actions=doc.createElement('div');actions.className='airport-office-row-actions';
   actions.append(button(doc,'Airport profile','view',office.key),button(doc,'Remove draft','remove',office.key));
   line.append(text,actions);target.append(line);remember(office);
  }
 }
 function selectAirport(){
  return officePicker.selected();
 }
 async function search(){await officePicker.load();}
 function profileField(id,items){
  const root=$(id);if(!root)return;root.replaceChildren();
  for(const [label,value] of items)row(doc,label,String(value??'Data pending'),root);
 }
 let profileLoadSerial=0;
 const knownNumber=n=>typeof n==='number'&&Number.isFinite(n);
 const num=n=>knownNumber(n)?new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n):'Data pending';
 const count=n=>Number.isInteger(n)&&n>=0?String(n):'Data pending';
 const textOrPending=v=>typeof v==='string'&&v.trim()?v:'Data pending';
 function renderAirportProfile(airport,detail=null,loading=false){
  const p=detail;
  const name=p?.name||airport.name;
  if($('airport-profile-name'))$('airport-profile-name').textContent=name;
  const iso=p?.countryIso||airport.countryIso;
  const municipality=p?.municipality||airport.municipality;
  if($('airport-profile-location'))$('airport-profile-location').textContent=
   [municipality,iso?countryLabel(iso):''].filter(Boolean).join(', ')||
    (loading?'Loading airport location...':'Location not reported');
  const fallback=loading?'Loading airport data...':'Data pending';
  const origin=p?.elevationStatus?.replaceAll('_',' ')||null;
  const coordinates=p&&knownNumber(p.latitude)&&knownNumber(p.longitude)
   ?p.latitude.toFixed(6)+', '+p.longitude.toFixed(6)+
    (p.coordinatesStatus==='verified'?' (site checked)':' (source-reported; unverified)'):fallback;
  const icao=p?(p.icao||'Not reported'):fallback;
  const iata=p?(p.iata||'Not reported'):fallback;
  const namesChecked=p?.nameChecked===true?'Source checked':'Source reported; not independently checked';
  const category=p?.category?
   p.category+(p.categoryStatus==='approved'?' (approved)':' (provisional)'):fallback;
  const tz=p?.timezone?p.timezone+(p.timezoneStatus==='checked'?' (checked)':' (candidate)'):fallback;
  const elevation=p&&knownNumber(p.elevationFt)?
   num(p.elevationFt)+' ft ('+(origin||'source status unknown')+')':fallback;
  profileField('airport-profile-facts',[
   ['Airport name',name],['Name verification',p?namesChecked:fallback],
   ['Airport code',airport.code||p?.code||fallback],
   ['ICAO code',icao],['IATA code',iata],
   ['Country',iso?countryLabel(iso):fallback],
   ['Municipality',textOrPending(municipality)||fallback],
   ['Region',p?textOrPending(p.region):fallback],
   ['Game world','Horizon (World 1)'],['Catalog key',airport.key],
   ['Airport category',category],['Time zone',tz],
   ['Latitude / longitude',coordinates],['Elevation',elevation]
  ]);
  const runways=p?.runways;
  const hasRunways=Array.isArray(runways)&&runways.length>0;
  const knownRunways=hasRunways?runways.filter(r=>knownNumber(r.lengthM)):[];
  const longest=knownRunways.length?Math.max(...knownRunways.map(r=>r.lengthM)):null;
  const allOperational=hasRunways&&runways.every(r=>r.operationalStatus==='operational');
  const lengthStatus=allOperational?'operational':'operational status unverified';
  const runwayInfo=hasRunways
   ?runways.map(r=>(r.name||'?')+': '+(knownNumber(r.lengthM)?num(r.lengthM)+'m':'length unknown')+
      (r.surface?' / '+r.surface:'')).join('; '):fallback;
  profileField('airport-profile-infrastructure',[
   ['Runway records',hasRunways?String(runways.length)+' ('+lengthStatus+')':fallback],
   ['Longest recorded runway',longest!==null?num(longest)+' m ('+lengthStatus+')':fallback],
   ['Runway designators / surfaces',runwayInfo],
   ['Passenger terminals',p?count(p.facilities?.terminals):fallback],
   ['Passenger gates',p?count(p.facilities?.gates):fallback],
   ['Aircraft stands',p?count(p.facilities?.stands):fallback],
   ['Available operating slots','Data pending'],
   ['Aerodrome operating hours',p?textOrPending(p.facilities?.operatingHours):fallback],
   ['Curfew restrictions',p?textOrPending(p.facilities?.curfew):fallback],
   ['Noise restrictions',p?textOrPending(p.facilities?.noise):fallback],
   ['Airport operational status','Not independently confirmed']
  ]);
  profileField('airport-profile-demand',[
   ['Passenger demand (0-100%)','Data pending'],['Cargo demand (0-100%)','Data pending'],
   ['Annual passengers','Data pending'],['Annual cargo','Data pending'],
   ['Daily departures / arrivals','Data pending'],['Peak operating periods','Data pending']]);
 }
 function showProfile(a){
  const airport=remember(a);if(!airport)return;
  activeAirport=airport;
  const serial=++profileLoadSerial;
  renderAirportProfile(airport,null,live.connected&&typeof live.reader?.airportProfile==='function');
  const isOwnHeadquarters=live.connected&&live.airline?.homeAirportKey===airport.key;
  const ownDraft=entries().find(x=>x.key===airport.key);
  profileField('airport-profile-airlines',[
   ['Your verified airline headquarters',isOwnHeadquarters?
    (live.airline.name||'Your airline')+' (registered HQ)':'Not your headquarters'],
   ['Your planned office',ownDraft?(ownDraft.type==='hub'?'Hub':'Station')+' - proposal only':
    isOwnHeadquarters?'Main home base':'No proposal'],
   ['Other airlines with headquarters','Not connected'],
   ['Airlines with active hubs','Not connected'],
   ['Airlines with active stations','Not connected'],['Operating airlines','Not connected'],
   ['Current commercial movements','Not connected']]);
  goTo?.('airport-profile');
  if(!live.connected||typeof live.reader?.airportProfile!=='function')return;
  // Per-airport authenticated lookup. Never infer missing values from a different airport.
  live.reader.airportProfile(airport.key).then(result=>{
   if(serial!==profileLoadSerial||activeAirport?.key!==airport.key)return;
   if(result?.airport?.key!==airport.key)throw Error('Airport identity mismatch');
   renderAirportProfile(airport,result.airport);
  }).catch(()=>{
   if(serial!==profileLoadSerial||activeAirport?.key!==airport.key)return;
   renderAirportProfile(airport);
   if($('airport-profile-location'))$('airport-profile-location').textContent=
    'Detailed airport data temporarily unavailable - reopen the profile to retry';
  });
 }
 const main=$('player-main');
 main?.addEventListener('click',async event=>{
  const target=event.target?.closest?.('button');if(!target)return;
  const action=target.dataset.officeAction;
  if(action==='back'){goTo?.('hubs');return;}
  if(action==='home-profile'){
   if(!live.airline?.homeAirportKey){feedback('No verified home airport.');return}
   const a=known.get(live.airline.homeAirportKey);if(a)showProfile(a);return;
  }
  if(action==='view'){
   const a=known.get(target.dataset.airportKey);if(a)showProfile(a);return;
  }
  if(action==='remove'){
   const key=target.dataset.airportKey;
   const rows=entries(),next=rows.filter(a=>a.key!==key);
   if(rows.length===next.length)return;
   if(!saveSession(session,keyForAccount(),next)){
    feedback('Unable to save removal. Browser session storage is unavailable.');return;
   }
   renderList('hub');renderList('station');feedback('Office proposal removed. No active airport office was changed.');
   return;
  }
  if(target.id==='office-find'){await search();return;}
  if(target.id==='office-preview'){
   const a=selectAirport();if(!a){feedback('Choose an approved airport first.');return;}showProfile(a);return;
  }
  if(target.id==='office-save'){
   if(!live.connected||!live.airline?.id){feedback('Your airline must be verified before planning an office.');return;}
   const a=selectAirport();
   const proposed=proposeAirportOffice({type:$('office-location-type')?.value,airport:a,
    homeAirportKey:live.airline.homeAirportKey,existing:entries()});
   if(!proposed.ok){feedback(proposed.reason);return;}
   if(!saveSession(session,keyForAccount(),[...entries(),proposed.entry])){
    feedback('Browser session storage is not available. Your proposal was not saved.');return;
   }
   renderList('hub');renderList('station');
   feedback((proposed.entry.type==='station'?'Station':'Hub')+
    ' proposal saved in this browser session. No fees or salaries were charged.');
  }
 });
 // Keep the private account draft key aligned with Route/Staff planning.
 function keyForAccount(){return key}
 function updateData(value){
  live={...live,...value};
  headquarters();directories();renderList('hub');renderList('station');
 }
 function openAirport(airport){
  const a=remember(airport);if(!a)return false;
  showProfile(a);return true;
 }
 updateData({});
 return Object.freeze({updateData,openAirport,getActiveAirport:()=>activeAirport});
}
