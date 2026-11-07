/** Airlinerra airport office - real HQ + private hub and station proposals.
 * Airport data source is only the authenticated, approved World 1 catalog.
 * No simulation of fees, salaries, slots, demand, routes or flights.
 */
import {renderAirportLocationMap} from './route-map.mjs';
import {createAirportAirlineLogo,createAirportNetworkTabs} from './airport-network-tabs.mjs';
import {summarizeAirportRestrictions,safeEvidenceUrl} from './airport-restriction-display.mjs';
const AIRPORT_KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/;
const currency=v=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0}).format(v);
const safeLocalValue=(v)=>typeof v==='string'?v.trim():'';
const textValue=(v)=>typeof v==='string'&&v.trim()?v.trim():'Data pending';
export const compactAnnual=value=>{
 if(typeof value!=='number'||!Number.isFinite(value)||value<0)return 'Data pending';
 return new Intl.NumberFormat('en-US',{notation:'compact',compactDisplay:'short',
  maximumFractionDigits:value<1000000?0:1}).format(value);
};
export const simpleAirportHours=value=>{
 const raw=typeof value==='string'?value.trim():'';
 if(!raw)return 'Not specified';
 if(/^24\/7\b/i.test(raw))return 'Open 24 hours in game';
 return raw.replace(/\s*\([^)]*\)/g,'').trim()||'Not specified';
};
export const simpleAirportCurfew=profile=>{
 const simple=profile?.operations?.simpleNightNoise;
 if(simple&&typeof simple.nighttimeBan==='boolean')return simple.nighttimeBan?'Yes':'No';
 const r=profile?.operations?.restrictionResearch;
 if(Number(r?.enforcedTimeRules||0)+Number(r?.enforcedRunwayRules||0)>0)
  return 'Mandatory rules recorded — see operating restrictions';
 if(r?.status==='RESEARCH_CONDITIONS_REQUIRE_SPECIFIC_RULE_REVIEW')
  return 'Airport conditions identified — exact game rules under review';
 if(['PROVISIONAL_GAME_DEFAULT_NO_EXTRA_BAN','SOURCE_SCREENED_GAME_DEFAULT_NO_EXTRA_BAN'].includes(r?.status))
  return 'No additional enforced game curfew recorded';
 const windows=profile?.operations?.timeRestrictions;
 if(Array.isArray(windows)&&windows.length)
  return 'Time or permission conditions recorded — see operating restrictions';
 return 'Curfew not fully verified';
};
export const simpleAirportNoise=profile=>{
 const simple=profile?.operations?.simpleNightNoise;
 if(simple&&typeof simple.noiseRestrictions==='boolean'){
  if(!simple.noiseRestrictions)return 'No';
  const chapters=Array.isArray(simple.permittedChapters)?
   simple.permittedChapters.filter(n=>Number.isInteger(n)&&[2,3,4,14].includes(n)):[];
  const roman={2:'II',3:'III',4:'IV',14:'14'};
  return 'Yes'+(chapters.length?' — Restricted to Chapter '+
   chapters.map(n=>roman[n]).join(' and ')+' aircraft':'');
 }
 const r=profile?.operations?.restrictionResearch;
 if(r?.noiseScreen==='YES')return 'Local aircraft noise conditions — see operating restrictions';
 const policy=profile?.operations?.icaoNoiseRules;
 const prohibited=Array.isArray(policy?.prohibitedChapters)?
   policy.prohibitedChapters.filter(x=>Number.isInteger(x)&&x>=2&&x<=14):[];
 if(prohibited.length)return 'Chapter '+[...new Set(prohibited)].sort((a,b)=>a-b).join(', ')+' restricted when certificate matched';
 if(r?.noiseScreen==='NO')return 'No additional local noise ban recorded in game';
 return 'Not fully verified';
};
export const airportWeatherType=symbol=>{
 const s=String(symbol||'').toLowerCase();
 if(/thunder/.test(s))return 'thunder';
 if(/snow|sleet/.test(s))return 'snow';
 if(/rain|showers|drizzle/.test(s))return 'rain';
 if(/fog|mist/.test(s))return 'fog';
 if(/partlycloudy|fair/.test(s))return 'partlycloudy';
 if(/cloudy/.test(s))return 'cloudy';
 if(/clearsky/.test(s))return 'sunny';
 return 'cloudy';
};
function makeAirportWeatherIcon(doc,symbol){
 const ns='http://www.w3.org/2000/svg',svg=doc.createElementNS(ns,'svg');
 for(const [k,v] of Object.entries({viewBox:'0 0 48 48',fill:'none',stroke:'currentColor',
  'stroke-width':'2.4','stroke-linecap':'round','stroke-linejoin':'round',
  'aria-hidden':'true',class:'airport-weather-icon'}))svg.setAttribute(k,v);
 const add=(tag,attrs)=>{
  const el=doc.createElementNS(ns,tag);
  for(const [k,v] of Object.entries(attrs))el.setAttribute(k,String(v));
  svg.append(el);
 };
 const sun=(cx,cy,r)=>{
  add('circle',{cx,cy,r,stroke:'#e9a52d'});
  for(let i=0;i<8;i++){
   const a=i*Math.PI/4;
   add('line',{x1:cx+Math.cos(a)*(r+4),y1:cy+Math.sin(a)*(r+4),
    x2:cx+Math.cos(a)*(r+7),y2:cy+Math.sin(a)*(r+7),stroke:'#e9a52d'});
  }
 };
 const type=airportWeatherType(symbol);
 if(type==='sunny')sun(24,24,9);
 else{
  if(type==='partlycloudy')sun(17,16,6);
  add('path',{d:'M15 36h19a8 8 0 0 0 1-16 11 11 0 0 0-20-2 9 9 0 0 0 0 18Z'});
  if(type==='rain')for(const x of [17,25,33])add('line',{x1:x,y1:39,x2:x-2,y2:44});
  if(type==='snow')for(const x of [18,26,34])add('path',{d:'M'+x+' 39v6m-3-3h6'});
  if(type==='fog')for(const y of [41,45])add('line',{x1:13,y1:y,x2:37,y2:y});
  if(type==='thunder')add('path',{d:'M25 36l-5 7h6l-2 5 10-10h-7'});
 }
 return svg;
}

// UI-only sample data: all ten flights are fictional, never actual bookings.
export const DEMO_AIRPORT_FLIGHTS=Object.freeze([
 {time:'06:35',airline:'Panonian',flight:'PN 104',route:'Departure · Vienna',status:'Boarding'},
 {time:'07:10',airline:'Aurora Connect',flight:'AC 218',route:'Arrival · Frankfurt',status:'Landed'},
 {time:'08:25',airline:'Silver Atlas Air',flight:'SA 462',route:'Departure · Paris',status:'On time'},
 {time:'09:40',airline:'Danube Sky',flight:'DS 307',route:'Arrival · Athens',status:'Approaching'},
 {time:'10:55',airline:'Northwind Air',flight:'NW 511',route:'Departure · Copenhagen',status:'On time'},
 {time:'12:20',airline:'Blue Meridian',flight:'BM 082',route:'Arrival · Zurich',status:'On time'},
 {time:'13:45',airline:'Panonian',flight:'PN 205',route:'Departure · Barcelona',status:'Scheduled'},
 {time:'15:15',airline:'Cloudpath Aviation',flight:'CP 166',route:'Arrival · Madrid',status:'Scheduled'},
 {time:'17:05',airline:'Alpine Star',flight:'AS 730',route:'Departure · Munich',status:'Scheduled'},
 {time:'19:30',airline:'Eastline Air',flight:'EL 428',route:'Arrival · Istanbul',status:'Scheduled'}
]);

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
export function createAirportOffice({doc,session,identity,goTo,getAirlineLogoUrl}={}){
 if(!doc||typeof identity!=='string'||!/^[\w-]{3,128}$/.test(identity))
  throw Error('Verified account required for airport office');
 const key='airlinerra.local.workplan.v1.'+identity;
 const $=id=>doc.getElementById(id);
 const host=$('workspace-hubs'),profileHost=$('workspace-airport-profile');
 let live={connected:false,airline:null,countries:[],reader:null};
 let ownLogoUrl=null,logoLoadSerial=0;
 let activeAirport=null;
 const OFFICE_PAGE_SIZE=10;
 const listPages={hub:0,station:0};
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
   panel('NETWORK LOCATIONS','My hubs',
    '<div class="airport-office-summary"><span>Active additional hubs</span><strong>Not connected</strong></div>'+
    '<div id="office-hub-list" class="operations-route-table"></div>'+
    '<div id="office-hub-pagination" class="airport-office-pagination"></div>')+
   panel('AIRPORT REPRESENTATION','My stations',
    '<p class="hint">Stations will open automatically when a real route is activated. Until then, airport-profile actions create draft requests only.</p>'+
    '<div class="airport-office-summary"><span>Active stations</span><strong>Not connected</strong></div>'+
    '<div id="office-station-list" class="operations-route-table"></div>'+
    '<div id="office-station-pagination" class="airport-office-pagination"></div>');
 }
 if(profileHost){
  profileHost.innerHTML=panel('AIRPORT DIRECTORY','Airport profile',
   '<div class="airport-profile-head"><div class="airport-profile-identity">'+
   '<h3 id="airport-profile-name">Select an airport</h3><p id="airport-profile-location" class="hint"></p>'+
   '<div class="airport-profile-office-actions">'+
   '<div class="airport-profile-office-buttons">'+
   '<button type="button" class="secondary" data-office-action="plan-station" disabled>Open station</button>'+
   '<button type="button" class="secondary" data-office-action="plan-hub" disabled>Request hub</button></div>'+
   '<p id="airport-profile-office-feedback" class="hint" role="status" aria-live="polite">Draft requests only. No office is activated.</p></div></div>'+
   '<div class="airport-profile-weather-summary" role="status" aria-live="polite">'+
   '<span class="airport-weather-summary-label">AIRPORT WEATHER · FORECAST</span>'+
   '<div class="airport-weather-summary-main"><span id="airport-weather-summary-icon"></span>'+
    '<strong id="airport-weather-summary-temperature">—</strong></div>'+
   '<div class="airport-weather-summary-details">'+
   '<span id="airport-weather-summary-conditions">Loading airport weather...</span>'+
   '<span id="airport-weather-summary-wind"></span></div></div></div>'+
   '<div class="airport-profile-main"><div id="airport-profile-facts" class="airport-profile-facts"></div>'+
   '<div class="airport-location-map-pane"><div class="airport-location-map-heading">AIRPORT LOCATION</div>'+
   '<div id="airport-profile-map" class="airport-location-map-canvas"></div></div></div>')+
   panel('AIRPORT INFRASTRUCTURE','Runways, terminals and slots',
    '<div id="airport-profile-infrastructure" class="airport-profile-facts"></div>')+
   panel('AIRPORT OPERATING RULES','Curfews, runway access and noise',
    '<p class="hint">All times are local to this airport. Research findings are not always complete airport closures; game rules are not real-world flight clearance.</p>'+
    '<div id="airport-profile-operating-rules" class="airport-profile-facts"></div>'+
    '<div id="airport-profile-restriction-sources" class="airport-profile-evidence-links"></div>')+
   panel('LAND CONNECTIONS','Nearby airports within 100 km',
    '<p class="hint">Straight-line distance, not driving distance. Only approved game airports are listed.</p>'+
    '<div id="airport-nearby-airports" class="airport-nearby-list"></div>')+
   panel('AIRPORT WEATHER','Current conditions and forecast',
    '<div id="airport-profile-weather" class="airport-profile-facts"></div>'+
    '<p id="airport-profile-weather-credit" class="hint">Forecast data by MET Norway, CC BY 4.0. Flight delays not modelled yet.</p>')+
   panel('MARKET DEMAND','Passenger and cargo demand',
    '<p class="hint">Demand is shown in five traffic groups; annual outbound traffic is rounded from game baselines.</p>'+
    '<div id="airport-profile-demand" class="airport-profile-facts"></div>')+
   panel('AIRLINE ACTIVITY','Airlines and airport presence',
    '<div id="airport-profile-airlines" class="airport-profile-facts"></div>')+
   panel('FLIGHT BOARD','Departures and arrivals',
    '<p class="airport-flight-preview-notice">Fictional preview — 10 example flights. No real flight schedule or booking.</p>'+
    '<div class="airport-flight-board"><div class="airport-flight-columns"><span>Time</span><span>Flight</span><span>Airline</span><span>Logo</span><span>Origin / destination</span><span>Status</span></div>'+
    '<div id="airport-flight-preview-rows"></div></div>')+
   panel('AIRPORT STATISTICS','Airlines, flights and destinations',
    '<div id="airport-network-tabs"></div>');
 }
 const networkTabs=createAirportNetworkTabs({doc,host:$('airport-network-tabs'),
  flights:DEMO_AIRPORT_FLIGHTS});
 const feedback=t=>{if($('airport-profile-office-feedback'))$('airport-profile-office-feedback').textContent=t};
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
 function renderList(type){
  const target=$(type==='hub'?'office-hub-list':'office-station-list');
  const pagination=$(type==='hub'?'office-hub-pagination':'office-station-pagination');
  if(!target)return;
  target.replaceChildren();
  pagination?.replaceChildren();
  const home=live.connected&&live.airline?.homeAirportKey?
   known.get(live.airline.homeAirportKey):null;
  const pinned=home?{...home,type,home:true,status:'registered'}:null;
  const items=[...(pinned?[pinned]:[]),
   ...entries().filter(e=>e.type===type&&e.key!==live.airline?.homeAirportKey)];
  if(!items.length){
   listPages[type]=0;
   target.append(createText(doc,'p','No '+(type==='hub'?'hubs':'stations')+' are available.','hint'));
   return;
  }
  const pages=Math.ceil(items.length/OFFICE_PAGE_SIZE);
  listPages[type]=Math.min(Math.max(0,listPages[type]),pages-1);
  const page=listPages[type],first=page*OFFICE_PAGE_SIZE;
  for(const office of items.slice(first,first+OFFICE_PAGE_SIZE)){
   const line=doc.createElement('div');line.className='airport-office-list-row';
   line.append(createText(doc,'span',office.name,'airport-office-list-name'),
    createText(doc,'span',office.code||'—','airport-office-list-code'),
    createText(doc,'span',office.home?(type==='hub'?'Main hub · headquarters':'Main station · headquarters'):
     type==='hub'?'Hub request · draft':'Station request · draft','airport-office-list-status'));
   const actions=doc.createElement('div');actions.className='airport-office-row-actions';
   const profileLink=button(doc,'Airport profile','view',office.key);
   profileLink.classList.add('airport-office-profile-text-link');
   actions.append(profileLink);
   if(!office.home)actions.append(button(doc,'Remove draft','remove',office.key));
   line.append(actions);target.append(line);remember(office);
  }
  if(pagination){
   const label=createText(doc,'span','Page '+(page+1)+' of '+pages+
    ' · '+items.length+' '+(type==='hub'?'hub':'station')+' requests','airport-office-page-caption');
   const previous=button(doc,'Previous','page'),next=button(doc,'Next','page');
   previous.dataset.officeType=next.dataset.officeType=type;
   previous.dataset.officePage=String(page-1);
   next.dataset.officePage=String(page+1);
   previous.disabled=page===0;next.disabled=page===pages-1;
   pagination.append(label,previous,next);
  }
 }
 function profileField(id,items){
  const root=$(id);if(!root)return;root.replaceChildren();
  for(const [label,value] of items)row(doc,label,String(value??'Data pending'),root);
 }
 let profileLoadSerial=0;
 const knownNumber=n=>typeof n==='number'&&Number.isFinite(n);
 const num=n=>knownNumber(n)?new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n):'Data pending';
 const count=n=>Number.isInteger(n)&&n>=0?String(n):'Data pending';
 const textOrPending=v=>typeof v==='string'&&v.trim()?v:'Data pending';
 function refreshOfficeActions(airport,loading=false){
  const request=entries().find(x=>x.key===airport?.key);
  const home=airport?.key===live.airline?.homeAirportKey;
  const permitted=Boolean(live.connected&&live.airline?.id&&airport?.countryIso&&!home&&!request);
  for(const action of ['plan-station','plan-hub']){
   const control=profileHost?.querySelector('[data-office-action="'+action+'"]');
   if(control)control.disabled=!permitted;
  }
  const note=$('airport-profile-office-feedback');
  if(!note)return;
  note.textContent=!live.connected||!live.airline?.id?
   'Connect your registered airline before requesting an airport office.':
   home?'This airport is already your registered headquarters.':
   loading&&!airport?.countryIso?'Checking airport details before allowing requests...':
   !airport?.countryIso?'Airport country is unavailable. Requests cannot be created here.':
   request?'An '+(request.type==='hub'?'additional hub':'station')+
    ' draft is already saved for this airport. No office is active.':
   'Open station and Request hub save draft requests in this browser only. No airport office is activated yet.';
 }
 function renderAirportProfile(airport,detail=null,loading=false){
  const p=detail;
  const name=p?.name||airport.name;
  if($('airport-profile-name'))$('airport-profile-name').textContent=name;
  const iso=p?.countryIso||airport.countryIso;
  const municipality=p?.municipality||airport.municipality;
  const effective=iso?remember({...airport,name,countryIso:iso,municipality}):airport;
  if(activeAirport?.key===airport.key)activeAirport=effective;
  refreshOfficeActions(effective,loading);
  const location=$('airport-profile-location');
  if(location){
   const locationText=[municipality,iso?countryLabel(iso):''].filter(Boolean).join(', ')||
    (loading?'Loading airport location...':'Location not reported');
   location.replaceChildren(doc.createTextNode(locationText));
   if(/^[A-Z]{2}$/.test(iso||'')){
    const flag=doc.createElement('img');
    flag.className='country-flag airport-profile-country-flag';
    flag.src='https://flagcdn.com/w40/'+iso.toLowerCase()+'.png';
    flag.alt=countryLabel(iso)+' flag';
    flag.width=21;flag.height=14;flag.loading='lazy';
    location.append(flag);
   }
  }
  const fallback=loading?'Loading airport data...':'Data pending';
  const coordinates=p&&knownNumber(p.latitude)&&knownNumber(p.longitude)
   ?p.latitude.toFixed(6)+', '+p.longitude.toFixed(6):fallback;
  const icao=p?(p.icao||'Not reported'):fallback;
  const iata=p?(p.iata||'Not reported'):fallback;
  const category=p?.category||fallback;
  const tz=p?.timezone||fallback;
  const elevation=p&&knownNumber(p.elevationFt)?num(p.elevationFt)+' ft':fallback;
  profileField('airport-profile-facts',[
   ['Airport name',name],
   ['ICAO code',icao],
   ['IATA code',iata],
   ['Country',iso?countryLabel(iso):fallback],
   ['Municipality',textOrPending(municipality)||fallback],
   ['Airport category',category],
   ['Time zone',tz],
   ['Latitude / longitude',coordinates],
   ['Elevation',elevation]
  ]);
  renderAirportLocationMap($('airport-profile-map'),p?{...p,name}:{name},{doc});
  const runways=p?.runways;
  const hasRunways=Array.isArray(runways)&&runways.length>0;
  const knownRunways=hasRunways?runways.filter(r=>knownNumber(r.lengthM)):[];
  const longest=knownRunways.length?Math.max(...knownRunways.map(r=>r.lengthM)):null;

  const runwayInfo=hasRunways
   ?runways.map(r=>(r.name||'?')+': '+(knownNumber(r.lengthM)?num(r.lengthM)+'m':'length unknown')+
      (r.surface?' / '+r.surface:'')).join('; '):fallback;
  profileField('airport-profile-infrastructure',[
   ['Runway records',hasRunways?String(runways.length):fallback],
   ['Longest recorded runway',longest!==null?num(longest)+' m':fallback],
   ['Runway designators / surfaces',runwayInfo],
   ['Passenger terminals',p?count(p.facilities?.terminals):fallback],
   ['Passenger gates',p?count(p.facilities?.gates):fallback],
   ['Aircraft stands',p?count(p.facilities?.stands):fallback],
   ['Available operating slots','Data pending'],
   ['Aerodrome operating hours',p?simpleAirportHours(p.facilities?.operatingHours):fallback],
   ['Nighttime ban (game)',p?simpleAirportCurfew(p):fallback],
   ['Noise restrictions (game)',p?simpleAirportNoise(p):fallback],
   ['Airport operational status','Not independently confirmed']
  ]);
  const restrictionView=p?summarizeAirportRestrictions(p):null;
  const sourceKind=p?.operations?.simpleNightNoise?.sourceStatus;
  const simplifiedSource=sourceKind==='AIRLINESIM_PAGE_OBSERVED'?
   'AirlineSim airport page checked':
   sourceKind==='USER_AIRLINESIM_SCREENSHOT'?
    'AirlineSim screenshot checked':'Airlinerra game default — not independently checked';
  const restrictionRows=[
    ['Simplified nighttime ban',p?simpleAirportCurfew(p):fallback],
    ['Simplified noise restrictions',p?simpleAirportNoise(p):fallback],
    ['Simplified game data source',p?simplifiedSource:fallback],
    ['Detailed operating rules',restrictionView?.status||fallback],
    ['Airport local time zone',restrictionView?.timezone||fallback],
    ['Mandatory time / runway rules',restrictionView?String(restrictionView.hardCount):fallback],
    ['Permission and review rules',restrictionView?String(restrictionView.reviewCount):fallback],
    ['Operating restrictions research',restrictionView?.researchOperating||fallback],
    ['Noise restrictions research',restrictionView?.researchNoise||fallback]
  ];
  if(restrictionView?.researchPending)restrictionRows.push([
    'Further rule verification',
    'Research exists but exact machine-readable restrictions are not yet complete.'
  ]);
  if(restrictionView)for(const rule of restrictionView.rules)
   restrictionRows.push([rule.title,rule.detail+(rule.note?' — '+rule.note:'')]);
  profileField('airport-profile-operating-rules',restrictionRows);
  const restrictionSources=$('airport-profile-restriction-sources');
  if(restrictionSources){
   restrictionSources.replaceChildren();
   if(restrictionView)for(const evidence of restrictionView.sources){
    const href=safeEvidenceUrl(evidence.url);
    if(!href)continue;
    const link=doc.createElement('a');
    link.href=href;link.target='_blank';link.rel='noopener noreferrer';
    link.textContent=evidence.label;
    link.className='airport-profile-evidence-link';
    restrictionSources.append(link);
   }
  }
  const nearRoot=$('airport-nearby-airports');
  if(nearRoot){
   nearRoot.replaceChildren();
   const nearby=p?.nearbyAirports;
   if(Array.isArray(nearby)){
    if(!nearby.length)nearRoot.append(createText(doc,'p',
     'No other approved airports within 100 km.','hint'));
    for(const near of nearby){
     if(!near?.key||!near?.name||!knownNumber(near.distanceKm))continue;
     const nameButton=button(doc,near.name,'nearby',near.key);
     nameButton.className='airport-nearby-airport-link';
     const info=doc.createElement('div');info.className='airport-nearby-identity';
     info.append(nameButton);
     // All listed airports are approved; hide internal fictional/real catalog labels.
     const line=doc.createElement('div');line.className='airport-nearby-row';
     line.append(info,createText(doc,'strong',num(near.distanceKm)+' km','airport-nearby-distance'));
     nearRoot.append(line);
     remember({key:near.key,name:near.name,code:near.iata||'',countryIso:null,municipality:''});
    }
   }else nearRoot.append(createText(doc,'p',loading?'Loading nearby airports...':
    'Nearby airport data unavailable.','hint'));
  }
  const wx=p?.weather||null;
  const weatherReady=Boolean(wx?.isCurrent&&knownNumber(wx?.temperatureC));
  const weatherName=code=>typeof code==='string'&&code?
    code.replace(/_day|_night|_polartwilight/g,'').replace(/_/g,' ').
      replace(/(rain|snow|cloudy|thunder|fog)/gi,' $1').replace(/ +/g,' ').trim():'Unavailable';
  const headerIcon=$('airport-weather-summary-icon');
  if(headerIcon)headerIcon.replaceChildren(makeAirportWeatherIcon(doc,weatherReady?wx.symbol:null));
  const headerTemperature=$('airport-weather-summary-temperature');
  if(headerTemperature)headerTemperature.textContent=weatherReady?num(wx.temperatureC)+' °C':'—';
  const headerConditions=$('airport-weather-summary-conditions');
  if(headerConditions)headerConditions.textContent=weatherReady?
   weatherName(wx.symbol).replace(/^./,c=>c.toUpperCase()):
   loading?'Loading airport weather...':'Forecast unavailable';
  const headerWind=$('airport-weather-summary-wind');
  if(headerWind)headerWind.textContent=weatherReady&&knownNumber(wx.windKmh)?
   'Wind '+num(wx.windKmh)+' km/h':'';
  profileField('airport-profile-weather',[
   ['Temperature',weatherReady?num(wx.temperatureC)+' °C':fallback],
   ['Conditions',weatherReady?weatherName(wx.symbol):fallback],
   ['Wind',weatherReady&&knownNumber(wx.windKmh)?num(wx.windKmh)+' km/h':fallback],
   ['Precipitation (forecast)',weatherReady&&knownNumber(wx.precipitationMm)?num(wx.precipitationMm)+' mm':fallback]
  ]);
  const credit=$('airport-profile-weather-credit');
  if(credit){
   const sourceLink=doc.createElement('a');
   sourceLink.href='https://api.met.no/weatherapi/locationforecast/2.0/documentation';
   sourceLink.target='_blank';sourceLink.rel='noopener noreferrer';
   sourceLink.textContent='MET Norway';
   const licenseLink=doc.createElement('a');
   licenseLink.href='https://creativecommons.org/licenses/by/4.0/';
   licenseLink.target='_blank';licenseLink.rel='noopener noreferrer';
   licenseLink.textContent='CC BY 4.0';
   credit.replaceChildren(doc.createTextNode('Forecast source: '),sourceLink,
     doc.createTextNode(' · Licence: '),licenseLink,
     doc.createTextNode(' · Flight delays are not simulated yet.'));
  }
  const demand=p?.demand;
  const groupLabel=value=>Number.isInteger(value)&&value>=1&&value<=5?
   'Group '+value+' of 5':fallback;
  const demandBars=(label,value)=>{
   const root=$('airport-profile-demand');
   if(!root||!Number.isInteger(value)||value<1||value>5)return;
   for(const line of root.querySelectorAll('.airport-profile-fact')){
    if(line.querySelector('span')?.textContent!==label)continue;
    const figure=line.querySelector('strong');if(!figure)return;
    const bars=doc.createElement('span');bars.className='airport-demand-bars';
    bars.setAttribute('role','img');bars.setAttribute('aria-label',label+': group '+value+' of 5');
    for(let index=1;index<=5;index++){
     const segment=doc.createElement('span');
     segment.className='airport-demand-segment'+(index<=value?' is-active':'');
     segment.setAttribute('aria-hidden','true');
     bars.append(segment);
    }
    figure.replaceChildren(bars);break;
   }
  };
  profileField('airport-profile-demand',[
   ['Passenger demand',groupLabel(demand?.passengerGroup)],
   ['Cargo demand',groupLabel(demand?.cargoGroup)],
   ['Annual departing passengers',compactAnnual(demand?.annualDepartingPassengers)],
   ['Annual outbound cargo',typeof demand?.annualOutboundCargoTonnes==='number'?
    compactAnnual(demand.annualOutboundCargoTonnes)+' tonnes':fallback]
  ]);
  demandBars('Passenger demand',demand?.passengerGroup);
  demandBars('Cargo demand',demand?.cargoGroup);
  networkTabs.setAirport({...airport,name,timezone:tz},p);
  const activity=p?.airportActivity;
  const shownCount=v=>Number.isInteger(v)&&v>=0?String(v):'—';
  profileField('airport-profile-airlines',[
   ['Airline headquarters',shownCount(activity?.registeredHeadquarters)],
   ['Active hubs',shownCount(activity?.activeHubs)],
   ['Active stations',shownCount(activity?.activeStations)],
   ['Operating airlines',shownCount(activity?.operatingAirlines)],
   ['Flights per day',shownCount(activity?.dailyFlights)]
  ]);
 }
 function renderDemoFlightBoard(){
  const root=$('airport-flight-preview-rows');if(!root)return;
  root.replaceChildren();
  for(const flight of DEMO_AIRPORT_FLIGHTS){
   const line=doc.createElement('div');line.className='airport-flight-sample-row';
   line.append(createText(doc,'span',flight.time,'airport-flight-time'),
    createText(doc,'span',flight.flight,'airport-flight-number'),
    createText(doc,'span',flight.airline,'airport-flight-carrier'),
    createAirportAirlineLogo(doc,flight.airline,live.airline?.name===flight.airline?ownLogoUrl:null),
    createText(doc,'span',flight.route,'airport-flight-route'),
    createText(doc,'span',flight.status,'airport-flight-sample-status'));
   root.append(line);
  }
 }
 function refreshOwnLogo(){
  const airline=live.airline,serial=++logoLoadSerial;
  const name=airline?.name||'';
  if(!live.connected||!airline?.id||typeof getAirlineLogoUrl!=='function'){
   ownLogoUrl=null;networkTabs.setOwnerLogo(name,null);return;
  }
  Promise.resolve().then(()=>getAirlineLogoUrl(airline.id)).then(url=>{
   if(serial!==logoLoadSerial||!live.connected||live.airline?.id!==airline.id)return;
   ownLogoUrl=typeof url==='string'?url+(url.includes('?')?'&':'?')+'logo_refresh='+Date.now():null;
   networkTabs.setOwnerLogo(name,ownLogoUrl);
   renderDemoFlightBoard();
  }).catch(()=>{
   if(serial!==logoLoadSerial)return;
   ownLogoUrl=null;networkTabs.setOwnerLogo(name,null);renderDemoFlightBoard();
  });
 }
 function showProfile(a){
  const airport=remember(a);if(!airport)return;
  activeAirport=airport;
  const serial=++profileLoadSerial;
  renderAirportProfile(airport,null,live.connected&&typeof live.reader?.airportProfile==='function');
  renderDemoFlightBoard();
  refreshOwnLogo();
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
  if(action==='view'||action==='nearby'){
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
  if(action==='page'){
   const type=target.dataset.officeType,requested=Number(target.dataset.officePage);
   if(!['hub','station'].includes(type)||!Number.isInteger(requested))return;
   listPages[type]=requested;
   renderList(type);return;
  }
  if(action==='plan-station'||action==='plan-hub'){
   if(!live.connected||!live.airline?.id){
    feedback('You need a verified airline to submit an office request.');return;
   }
   const airport=activeAirport,type=action==='plan-hub'?'hub':'station';
   const proposed=proposeAirportOffice({type,airport,
    homeAirportKey:live.airline.homeAirportKey,existing:entries()});
   if(!proposed.ok){feedback(proposed.reason);return;}
   if(!saveSession(session,keyForAccount(),[...entries(),proposed.entry])){
    feedback('Unable to save this draft in your browser. No airport office was opened.');return;
   }
   renderList('hub');renderList('station');
   refreshOfficeActions(airport);
   feedback((type==='hub'?'Hub request':'Station request')+
    ' saved as a local draft. No airport office, staffing, fees or slots have been activated.');
   return;
  }
 });
 // Keep the private account draft key aligned with Route/Staff planning.
 function keyForAccount(){return key}
 function updateData(value){
  if(value?.airline?.id!==undefined&&value.airline.id!==live.airline?.id){
   ++logoLoadSerial;ownLogoUrl=null;
  }
  if(value?.connected===false){++logoLoadSerial;ownLogoUrl=null;}
  live={...live,...value};
  headquarters();renderList('hub');renderList('station');
  if(activeAirport)refreshOfficeActions(activeAirport);
 }
 function openAirport(airport){
  const a=remember(airport);if(!a)return false;
  showProfile(a);return true;
 }
 updateData({});
 return Object.freeze({updateData,openAirport,refreshAirlineLogo:refreshOwnLogo,getActiveAirport:()=>activeAirport});
}
