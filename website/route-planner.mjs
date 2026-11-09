/** Full route planning workspace, not commercial flight activation.
 * Only approved authenticated airport reads and account-local draft writes.
 */
import {createAirportCountryPicker,populateAirportCountries,airportFlag,airportCountryName} from './airport-country-picker.mjs';
import {renderRouteMap} from './route-map.mjs';
import {buildAircraftWeeklyTimeline,renderAircraftWeeklyTimeline} from './aircraft-weekly-timeline.mjs';
import {assessAircraftRouteRunways} from './route-aircraft-runway-screen.mjs';
const section=(eyebrow,title,body)=>
 '<article class="panel route-planner-panel"><span class="panel-kicker">'+eyebrow+'</span><h2>'+title+'</h2>'+body+'</article>';
const field=(id,label,el)=>'<label class="workspace-label" for="'+id+'">'+label+'</label>'+el;
const picker=(side,title)=>'<fieldset class="route-planner-airport"><legend>'+title+'</legend>'+
 field('route-'+side+'-hub','Quick airport (your active hubs first)',
  '<select id="route-'+side+'-hub"><option value="">Choose airport or search below</option></select>')+
 '<label class="workspace-label" id="route-'+side+'-country-label" for="route-'+side+'-country-trigger">Country (optional)</label>'+
 '<div class="route-country-picker">'+
 '<select class="route-native-country" id="route-'+side+'-country" tabindex="-1" aria-hidden="true">'+
 '<option value="">All countries</option></select>'+
 '<button type="button" id="route-'+side+'-country-trigger" class="route-country-trigger" '+
 'aria-haspopup="listbox" aria-expanded="false" aria-controls="route-'+side+'-country-list" '+
 'data-route-country-trigger="'+side+'">'+
 '<img id="route-'+side+'-country-flag" class="route-country-flag" alt="" hidden>'+
 '<span id="route-'+side+'-country-text">All countries — search anywhere</span>'+
 '<span aria-hidden="true" class="route-chevron">⌄</span></button>'+
 '<div id="route-'+side+'-country-list" class="route-country-list" role="listbox" '+
 'aria-label="'+title+' country" hidden></div></div>'+
 field('route-'+side+'-search','Airport or city',
  '<div class="route-airport-combobox">'+
  '<input type="search" id="route-'+side+'-search" maxlength="40" '+
  'placeholder="Type a city or airport name, or browse results" role="combobox" '+
  'aria-autocomplete="list" aria-expanded="false" aria-controls="route-'+side+'-suggestions">'+
  '<div id="route-'+side+'-suggestions" class="route-airport-suggestions" '+
  'role="listbox" aria-label="'+title+' airports" hidden></div></div>')+
 '<select id="route-'+side+'-airport" class="route-native-airport" '+
 'aria-hidden="true" tabindex="-1" disabled><option value="">Select approved airport</option></select>'+
 '<p id="route-'+side+'-count" class="hint" role="status">Choose a country or search all approved airports.</p>'+
 '<div id="route-'+side+'-summary" class="route-selection-summary">Select an airport.</div></fieldset>';
const dayNames=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const dayShort=['Mo','Tu','We','Th','Fr','Sa','Su'];
const weekRow=(label,render)=>'<div class="route-week-row-label">'+label+'</div>'+dayNames.map((day,i)=>
 '<div class="route-week-cell">'+render(day,i)+'</div>').join('');
const weekTable=()=>'<div class="route-week-scroll"><div class="route-week-grid" role="group" aria-label="Weekly flight assignments">'+
 weekRow('Day',day=>'<span class="route-week-heading">'+day+'</span>')+
 weekRow('Fly',(_,i)=>'<input type="checkbox" data-route-day="'+i+'" id="route-day-'+i+'" aria-label="Fly on '+dayNames[i]+'">')+
 weekRow('Departure',(_,i)=>'<input type="time" data-route-time="'+i+'" value="09:00" disabled aria-label="'+dayNames[i]+' departure time">')+
 weekRow('Departure stand',(_,i)=>'<output id="route-stand-'+i+'" class="route-week-estimate">—</output>')+
 weekRow('Arrival stand',(_,i)=>'<output id="route-arrival-stand-'+i+'" class="route-week-estimate">—</output>')+
 weekRow('Estimated arrival',(_,i)=>'<output id="route-arrival-'+i+'" class="route-week-estimate">Pending</output>')+
 weekRow('Slot availability',()=>'<span class="route-week-pending">Unverified</span>')+
 weekRow('Next possible departure',(_,i)=>'<output id="route-next-departure-'+i+'" class="route-week-estimate">—</output>')+
 '</div></div>';
const routeSetupField=(id,label,input)=>'<label class="route-setup-field" for="'+id+'"><span>'+label+'</span>'+input+'</label>';
const optionalFare=(id,label)=>routeSetupField(id,label,
 '<div class="route-fare-input"><span>$</span><input id="'+id+'" type="number" min="0" max="100000" step="1" inputmode="decimal" placeholder="Not set"></div>');
const routeCheckDetails =
  '<p class="hint">This is a factual preview, not a departure authorization. Unknown or unconnected checks never count as passed.</p>'+
  '<div class="route-check-grid">'+
   '<div class="route-check-item"><span>Distance</span><strong id="route-distance">Select airports</strong></div>'+
   '<div class="route-check-item"><span>Estimated flight duration</span><strong id="route-block-time">Aircraft required</strong></div>'+
   '<div class="route-check-item"><span>Market</span><strong id="route-market">Select airports</strong></div>'+
   '<div class="route-check-item"><span>Route status</span><strong id="route-status">Draft only</strong></div>'+
   '<div class="route-check-item"><span>Weather forecast (example times)</span><strong id="route-weather-check">Select times to check forecast</strong></div>'+
   '<div class="route-check-item"><span>Origin runway / noise / curfew</span><strong id="route-origin-restrictions">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Destination runway / noise / curfew</span><strong id="route-destination-restrictions">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Origin passenger / cargo demand</span><strong id="route-origin-demand">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Destination passenger / cargo demand</span><strong id="route-destination-demand">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Departure / arrival slots</span><strong id="route-slot-check">Not yet connected</strong></div>'+
   '<div class="route-check-item"><span>Aircraft / runway suitability</span><strong id="route-aircraft-check">No aircraft assigned</strong></div>'+
   '<div class="route-check-item"><span>Passenger / cargo traffic rights</span><strong id="route-traffic-rights">Not yet connected</strong></div>'+
  '</div>'+
  '<p id="route-check-message" class="route-check-message" role="status">Select a route and aircraft to begin checking feasibility.</p>';
export function routePlannerMarkup(){
 return '<div class="route-planner-grid route-planner-first-step">'+
  section('STEP 1','Define your flight',
   '<p class="hint">Choose your flight number, origin and destination. Approved airport data is read-only until real scheduling is connected.</p>'+
   '<div class="route-flight-number-entry">'+
   field('route-plan-number','Flight number',
    '<div class="route-number-input"><span id="route-number-prefix">—</span>'+
    '<input id="route-plan-number" inputmode="numeric" type="text" autocomplete="off" pattern="[0-9]{1,4}" maxlength="4" placeholder="101"></div>')+
   '<p id="route-prefix-note" class="hint">Checking registered airline code...</p></div>'+
   '<div class="route-planner-airports">'+picker('from','Origin')+picker('to','Destination')+'</div>'+
   '<div class="workspace-actions"><button type="button" id="route-plan-swap" class="secondary">Swap airports</button>'+
   '<button type="button" id="route-plan-preview" class="primary">Preview route</button></div>'+
   '<p id="route-feedback" class="hint" role="status"></p>')+
  section('ROUTE MAP','Geographic route preview',
   '<h3 id="route-map-heading" class="route-map-heading">Select two airports</h3>'+
   '<div id="route-map-canvas" class="route-map-canvas"></div>'+
   '<p id="route-map-feedback" class="hint">The map uses verified airport coordinates where available.</p>'+
   '<div class="route-map-facts"><h3>Route information and limitations</h3>'+routeCheckDetails+
   '<div class="route-inline-restrictions"><strong>Airport restrictions</strong><p id="route-preflight-status" class="hint" role="status" aria-live="polite">Not verified. Select an aircraft and planned times.</p>'+ 
   '<details class="route-restriction-details"><summary>Exact UTC times for automatic airport checks</summary>'+ 
   '<p class="hint">Restrictions are checked automatically using these example UTC times. Weekly local times and flight duration still require verification.</p>'+ 
   '<div class="route-step2-top">'+ 
   routeSetupField('route-preflight-departure-utc','Example departure (UTC)', '<input id="route-preflight-departure-utc" type="datetime-local" step="60">')+ 
   routeSetupField('route-preflight-arrival-utc','Example arrival (UTC)', '<input id="route-preflight-arrival-utc" type="datetime-local" step="60">')+ 
   '</div></details></div></div>')+
 '</div>'+
 section('STEP 2','Aircraft and weekly departures',
  '<div class="route-step2-top">'+
   routeSetupField('route-aircraft','Aircraft','<select id="route-aircraft"><option value="">Choose aircraft</option></select>')+
   routeSetupField('route-arrival-stand','Arrival stand at destination','<select id="route-arrival-stand"><option value="terminal">Terminal</option><option value="remote">Remote stand (lower fees)</option><option value="cargo">Cargo stand</option></select>')+
   routeSetupField('route-turnaround','Target turnaround (minutes)','<input id="route-turnaround" type="number" min="45" max="360" step="15" value="45">')+
  '</div>'+
  '<p class="route-subtle-note" id="route-aircraft-feedback">Aircraft availability is not connected.</p>'+
  '<div class="route-position-bar"><span>Departure stand follows previous arrival</span><strong id="route-departure-stand-derived">Initial stand not verified</strong></div>'+
  '<p id="route-aircraft-position-status" class="route-position-status" role="status"></p>'+
  weekTable()+
  '<details class="route-aircraft-timeline-panel" id="route-aircraft-timeline"><summary>Aircraft weekly timeline and locations</summary><div id="route-aircraft-timeline-content"></div></details>'+
  '<div class="route-week-footer"><span id="route-flights" class="route-week-count">0 departures/week</span>'+
  '<span>Example next departures use entered UTC times; actual local arrival, slots and aircraft position are not yet verified.</span></div>'+
  '<div class="route-flight-calculations">'+
   '<div><span>Aircraft cruise speed</span><strong id="route-cruise-speed">Pending verified data</strong></div>'+
   '<div><span>Estimated airborne time</span><strong id="route-airborne-time">Pending verified performance</strong></div>'+
   '<div><span>Required minimum turnaround</span><strong id="route-min-turnaround">Unverified · 45 min planning floor</strong></div>'+
   '<div><span>Arrival / rotation checks</span><strong id="route-rotation-check">Pending aircraft and slot rules</strong></div>'+
  '</div>')+
 section('STEP 3','Ticket prices and onboard services',
  '<div class="route-pricing-grid">'+
   optionalFare('route-fare-economy','Economy fare')+
   optionalFare('route-fare-premium','Premium Economy fare')+
   optionalFare('route-fare-business','Business fare')+
   optionalFare('route-fare-first','First Class fare')+
  '</div>'+
  '<div class="route-service-grid">'+
   routeSetupField('route-onboard-service','Onboard service','<select id="route-onboard-service"><option value="standard">Standard</option><option value="basic">Basic</option><option value="enhanced">Enhanced</option></select>')+
   routeSetupField('route-baggage-service','Baggage package','<select id="route-baggage-service"><option value="standard">Standard</option><option value="hand-only">Hand baggage only</option><option value="checked">Checked baggage included</option></select>')+
   routeSetupField('route-cargo-service','Cargo on this flight','<select id="route-cargo-service"><option value="none">No cargo</option><option value="requested">Request belly cargo (unverified)</option></select>')+
  '</div>'+
  '<p class="route-subtle-note">Draft settings only. Pricing, cargo capacity and services are not yet operationally enforced.</p>'+
  '<div class="workspace-actions route-apply-actions">'+
   '<button type="button" id="route-plan-save" class="primary">Apply route draft</button>'+
   '<button type="button" id="route-plan-new" class="secondary">Create new route</button>'+
   '<button type="button" class="route-text-action" data-workspace-go="route-list">My routes</button></div>'+
  '<p id="route-plan-status" class="hint" role="status" aria-live="polite"></p>'+
  '<div id="route-plan-review" class="workspace-detail"></div>')+
 section('SERVER-OWNED SCHEDULE DRAFTS','Schedules saved to your airline',
  '<p class="hint">Only aircraft actually owned or leased by your airline can be saved on the protected server. These schedules are drafts, not active flights.</p>'+
  '<div id="route-server-draft-list" class="workspace-detail"></div>'+
  '<p id="route-server-draft-status" class="hint" role="status" aria-live="polite"></p>')+
 '';
}
export const flightPrefixFor=airline=>{
 const code=String(airline?.iataCode||'').trim().toUpperCase();
 if(/^[A-Z0-9]{2}$/.test(code)&&/[A-Z]/.test(code))
  return {prefix:code,provisional:false};
 if(String(airline?.name||'').trim().toLocaleLowerCase('en')==='panonian')
  return {prefix:'PA',provisional:true};
 return {prefix:null,provisional:true};
};
export const flightNumberFor=(prefix,number)=>{
 const digits=String(number??'').trim();
 return /^[A-Z0-9]{2}$/.test(String(prefix||''))&&/^[0-9]{1,4}$/.test(digits)?
  prefix+digits:null;
};
/** An example only: no flight performance, destination time zone or dispatch approval is inferred. */
export function exampleNextDepartureUtc(departureUtc,arrivalUtc,turnaroundMinutes){
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(String(departureUtc||''))||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(String(arrivalUtc||''))||
    !Number.isInteger(turnaroundMinutes)||turnaroundMinutes<45||turnaroundMinutes>360)
  return null;
 const departure=Date.parse(departureUtc),arrival=Date.parse(arrivalUtc);
 if(!Number.isFinite(departure)||!Number.isFinite(arrival)||
    arrival<=departure||arrival-departure>72*3600000)return null;
 const release=new Date(arrival+turnaroundMinutes*60000);
 if(!Number.isFinite(release.valueOf()))return null;
 return Object.freeze({iso:release.toISOString(),clock:release.toISOString().slice(11,16)+' UTC',
  arrivalClock:new Date(arrival).toISOString().slice(11,16)+' UTC'});
}
export const validLocalDeparture=time=>/^([01]\d|2[0-3]):[0-5]\d$/.test(String(time||''));
// Arrival stands are player choices. Departure stands come from prior aircraft arrivals
// where known; a first-flight terminal fallback remains provisional and server-gated.
export const validateFlightDraftOptions=({departureStand='terminal',arrivalStand,turnaroundMinutes,fares,onboard,baggage,cargo}={})=>{
 if(!['terminal','remote','cargo'].includes(departureStand)||
    !['terminal','remote','cargo'].includes(arrivalStand)||
  !Number.isInteger(turnaroundMinutes)||turnaroundMinutes<45||turnaroundMinutes>360||
  !['standard','basic','enhanced'].includes(onboard)||
  !['standard','hand-only','checked'].includes(baggage)||
  !['none','requested'].includes(cargo))return null;
 const prices={};
 for(const key of ['economy','premium','business','first']){
  const raw=fares?.[key];
  if(raw===null||raw===undefined||String(raw).trim()===''){prices[key]=null;continue;}
  const amount=Number(raw);
  if(!Number.isSafeInteger(amount)||amount<0||amount>100000)return null;
  prices[key]=amount;
 }
 return {departureStand,arrivalStand,turnaroundMinutes,fares:prices,
  service:{onboard,baggage,cargo},operationallyVerified:false};
};
export const routeWeekdays=schedule=>{
 const rows=Array.isArray(schedule)?schedule:[];
 return dayShort.map((label,day)=>({label,active:rows.some(row=>row?.day===day)}));
};
/** Brief game flags in the route planner; a simple 'No' never cancels precise rules. */
export function airportRouteRestrictionSummary(profile){
 if(!profile)return 'Data pending';
 const runways=Array.isArray(profile.runways)?profile.runways.filter(
  r=>Number.isFinite(r?.lengthM)&&r.lengthM>0).map(r=>r.lengthM):[];
 const longest=runways.length?Math.max(...runways).toLocaleString('en-US')+' m runway':'Runway unverified';
 const ops=profile.operations||{},simple=ops.simpleNightNoise||{};
 const flag=value=>typeof value==='boolean'?(value?'Yes':'No'):'Not loaded';
 const nightWindow=typeof simple.nighttimeWindow==='string'&&simple.nighttimeWindow.trim()?
  ' ('+simple.nighttimeWindow.trim().replace(/-/g,'–')+' airport local time)':'';
 const night='Nighttime ban: '+flag(simple.nighttimeBan)+
  (simple.nighttimeBan===true?nightWindow:'');
 const chapters=Array.isArray(simple.permittedChapters)?
  simple.permittedChapters.filter(x=>Number.isInteger(x)&&x>0):[];
 const noise='Noise restrictions: '+flag(simple.noiseRestrictions)+
  (simple.noiseRestrictions===true?
   (chapters.length?' (permitted Chapters '+chapters.join(', ')+')':
    ' (Chapters not specified)'):'');
 const extra=[];
 if(['AIRLINESIM_NOT_FOUND','GAME_DEFAULT_NOT_CHECKED'].includes(simple.sourceStatus))
  extra.push('Game default, not source-verified');
 const research=ops.restrictionResearch||{};
 if(Number(research.enforcedTimeRules||0)+Number(research.enforcedRunwayRules||0)>0)
  extra.push('Other mandatory airport rules recorded');
 else if(research.status==='RESEARCH_CONDITIONS_REQUIRE_SPECIFIC_RULE_REVIEW')
  extra.push('Operating conditions need rule verification');
 return [longest,night,noise,...extra].join(' · ');
}
/** Display forecast information without converting it into dispatch clearance. */
export function formatRouteWeatherPreview(preview){
 if(!preview||typeof preview!=='object')
  return 'Forecast unavailable — no weather authorization';
 const describe=(name,leg)=>{
  if(leg?.status!=='FORECAST_REFERENCE_AVAILABLE'){
   const explanation={
    OUTSIDE_FORECAST_HORIZON:'Outside forecast horizon',
    FORECAST_SOURCE_STALE:'Forecast source stale',
    FORECAST_MISSING:'No forecast',
    NO_MATCHING_FORECAST_HOUR:'Hourly forecast unavailable'
   }[leg?.status]||'Forecast unavailable';
   return name+': '+explanation;
  }
  const details=[];
  if(typeof leg.weatherSymbol==='string'&&leg.weatherSymbol)
   details.push(leg.weatherSymbol.replace(/_/g,' '));
  if(Number.isFinite(leg.temperatureC))
   details.push(leg.temperatureC+'°C');
  if(Number.isFinite(leg.windSpeedKmh))
   details.push('wind '+leg.windSpeedKmh+' km/h');
  if(Number.isFinite(leg.precipitationMm))
   details.push('rain '+leg.precipitationMm+' mm');
  return name+': '+(details.join(', ')||'Forecast available');
 };
 return describe('Departure',preview.origin)+' · '+
  describe('Arrival',preview.destination)+
  ' · Forecast only; aviation weather clearance not provided';
}
export function createRoutePlanner({doc,getData,loadDraft,draftWrite}={}){
 if(!doc||typeof getData!=='function'||typeof draftWrite!=='function')
  throw Error('Verified route planner data required');
 const $=id=>doc.getElementById(id);
 const days=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
 let homeKey=null,homeLocation=null,currentAirlineId=null,homeTicket=0,detailTicket=0;
 let lastKeys='',airportProfiles={},editingFlightNumber=null,editingLegacyIndex=null,editSerial=0;
 let preflightCatalogFor=null,preflightLoadToken=0,preflightRequest=0;
 let catalogAircraft=[],preflightCache=null,preflightPromise=null;
 let ownedFleet=[],serverDrafts=[],fleetTicket=0,fleetReadState='unavailable';
 const pickers={},selected=side=>pickers[side]?.selected()||null;
 // The country-picker constructor calls onSelect synchronously. Defer route
 // rendering until all planner callbacks, including preflight, are initialized.
 let plannerInitialized=false;
 const message=(id,value)=>{if($(id))$(id).textContent=value;};
 const selectedConfigurationId=()=>{
  const key=$('route-aircraft')?.value||'';
  if(/^catalog:[1-9][0-9]*$/.test(key))return Number(key.slice(8));
  if(key.startsWith('owned:')){
   const owned=ownedFleet.find(a=>'owned:'+a.id===key);
   return Number.isSafeInteger(owned?.configurationId)&&owned.configurationId>0?
    owned.configurationId:null;
  }
  const sample=(getData()?.airline?.testAircraft||[]).find(a=>a?.id===key);
  return Number.isSafeInteger(sample?.configurationId)&&sample.configurationId>0?sample.configurationId:null;
 };
 const catalogChoice=()=>catalogAircraft.find(a=>a.id===selectedConfigurationId())||null;
 const runwayAssessment=aircraft=>assessAircraftRouteRunways({
  aircraft,
  origin:airportProfiles.from?.key===selected('from')?.key?airportProfiles.from:null,
  destination:airportProfiles.to?.key===selected('to')?.key?airportProfiles.to:null
 });
 const clearPreflight=()=>{
  ++preflightRequest;preflightCache=null;preflightPromise=null;
  message('route-slot-check','Select times to check arrival and departure availability');
  message('route-weather-check','Select departure and arrival times to check forecast');
  $('route-slot-check')?.classList?.remove('has-conflict','has-available');
 };
 const countryFlag=side=>{
  const iso=$('route-'+side+'-country')?.value||'';
  const img=$('route-'+side+'-country-flag');
  const label=$('route-'+side+'-country-text');
  if(label)label.textContent=/^[A-Z]{2}$/.test(iso)?
   airportCountryName(iso):'All countries — search anywhere';
  for(const option of $('route-'+side+'-country-list')?.querySelectorAll('[data-route-country-choice]')||[])
   option.setAttribute('aria-selected',String(option.dataset.countryIso===iso));
  if(!img)return;
  if(/^[A-Z]{2}$/.test(iso)){
   img.src='https://flagcdn.com/w40/'+iso.toLowerCase()+'.png';
   img.alt=airportCountryName(iso)+' flag';img.hidden=false;
  }else{img.removeAttribute('src');img.hidden=true;}
 };
 const hideCountryMenus=()=>{
  for(const side of ['from','to']){
   const list=$('route-'+side+'-country-list');
   const trigger=$('route-'+side+'-country-trigger');
   if(list)list.hidden=true;
   if(trigger)trigger.setAttribute('aria-expanded','false');
  }
 };
 const renderCountryMenus=countries=>{
  const countriesSorted=[...(countries||[])].filter(c=>/^[A-Z]{2}$/.test(c.countryIso||''))
   .sort((a,b)=>airportCountryName(a.countryIso).localeCompare(airportCountryName(b.countryIso),'en'));
  for(const side of ['from','to']){
   const root=$('route-'+side+'-country-list');
   if(!root)continue;
   root.replaceChildren();
   for(const c of [{countryIso:'',airportCount:null},...countriesSorted]){
    const button=doc.createElement('button');
    button.type='button';button.className='route-country-option';
    button.setAttribute('role','option');
    button.dataset.routeCountryChoice=side;button.dataset.countryIso=c.countryIso;
    button.setAttribute('aria-selected',String($('route-'+side+'-country')?.value===c.countryIso));
    if(c.countryIso){
     const img=doc.createElement('img');img.src='https://flagcdn.com/w40/'+c.countryIso.toLowerCase()+'.png';
     img.alt='';img.width=20;img.height=13;img.loading='lazy';img.className='route-summary-flag';
     button.append(img);
    }
    const label=doc.createElement('span');
    label.textContent=c.countryIso?airportCountryName(c.countryIso)+
     ' ('+Number(c.airportCount||0)+' airports)':'All countries — search anywhere';
    button.append(label);root.append(button);
   }
  }
 };
 const hideSuggestions=side=>{
  const list=$('route-'+side+'-suggestions'),input=$('route-'+side+'-search');
  if(list)list.hidden=true;
  if(input)input.setAttribute('aria-expanded','false');
 };
 const renderSuggestions=(side,results,ready=true)=>{
  const list=$('route-'+side+'-suggestions'),input=$('route-'+side+'-search');
  if(!list||!input)return;
  list.replaceChildren();
  if(!ready||!Array.isArray(results)||!results.length){hideSuggestions(side);return;}
  for(const a of results.slice(0,30)){
   const button=doc.createElement('button');
   button.type='button';button.className='route-airport-option';
   button.setAttribute('role','option');button.dataset.routeAirportKey=a.key;
   button.dataset.routeAirportSide=side;
   const flag=doc.createElement('img');
   flag.src='https://flagcdn.com/w40/'+a.countryIso.toLowerCase()+'.png';
   flag.alt='';flag.width=20;flag.height=13;flag.className='route-summary-flag';
   button.append(flag);
   const name=doc.createElement('span');
   name.textContent=a.name+(a.code?' ('+a.code+')':'')+(a.municipality?' · '+a.municipality:'');
   button.append(name);list.append(button);
  }
  list.hidden=false;input.setAttribute('aria-expanded','true');
 };
 const availableSchedule=()=>{
  const result=[];
  for(let day=0;day<7;day++){
   const check=doc.querySelector('[data-route-day="'+day+'"]');
   const time=doc.querySelector('[data-route-time="'+day+'"]');
   if(check?.checked)result.push({day,time:time?.value||''});
  }
  return result;
 };
 const updateWeek=()=>{
  const schedule=availableSchedule(),chosenDays=new Set(schedule.map(x=>x.day));
  for(let day=0;day<7;day++){
   const check=doc.querySelector('[data-route-day="'+day+'"]');
   const time=doc.querySelector('[data-route-time="'+day+'"]');
   if(time)time.disabled=!check?.checked;
  }
  message('route-flights',schedule.length+' '+(schedule.length===1?'departure':'departures')+'/week');
  const target=Number($('route-turnaround')?.value);
  // Only calculate from user-entered UTC reference times. No aircraft
  // speed, local time zone, actual arrival or future slot is invented.
  const estimate=exampleNextDepartureUtc(
   utcFromInput($('route-preflight-departure-utc')?.value),
   utcFromInput($('route-preflight-arrival-utc')?.value),target);
  for(let day=0;day<7;day++){
   message('route-arrival-'+day,chosenDays.has(day)?
    (estimate?'Example '+estimate.arrivalClock:'Pending verified duration'):'—');
   message('route-next-departure-'+day,chosenDays.has(day)?
    (estimate?'Example '+estimate.clock:'Pending arrival time'):'—');
  }
  message('route-rotation-check',Number.isInteger(target)&&target>=45&&target<=360?
   (estimate?'Example next ground departure '+estimate.clock+' · not an approved slot':
    'Target '+target+' min · flight duration and slots unverified'):
   'Choose a turnaround between 45 and 360 minutes');
 };
 const scheduledRoutesForAircraft=aircraftId=>{
  const saved=loadDraft?.()||{};
  const local=Array.isArray(saved.routes)?saved.routes:[];
  if(!aircraftId?.startsWith('owned:'))return local;
  const inventoryId=aircraftId.slice('owned:'.length);
  const seen=new Set(local.filter(x=>x?.aircraftId===aircraftId).map(x=>x.flightNumber));
  const resolveAirport=key=>{
   for(const side of ['from','to']){
    const airport=selected(side);
    if(airport?.key===key)return airport;
   }
   return {key,name:key};
  };
  const server=[];
  for(const d of serverDrafts){
   if(d?.status!=='draft'||d.aircraftInventoryId!==inventoryId||
      !d.originAirportKey||!d.destinationAirportKey||
      typeof d.flightNumber!=='string'||seen.has(d.flightNumber))continue;
   seen.add(d.flightNumber);
   server.push({flightNumber:d.flightNumber,aircraftId,
    from:resolveAirport(d.originAirportKey),to:resolveAirport(d.destinationAirportKey),
    schedule:Array.isArray(d.weeklySchedule)?d.weeklySchedule:[],
    operation:{departureStand:d.departureStand,arrivalStand:d.arrivalStand},
    referenceDepartureUtc:d.referenceDepartureUtc,referenceArrivalUtc:d.referenceArrivalUtc});
  }
  return [...local,...server];
 };
 const selectedAircraftTimeline=()=>{
  const selectedId=$('route-aircraft')?.value||null;
  const aircraftId=selectedId?.startsWith('catalog:')?null:selectedId;
  const from=selected('from'),to=selected('to');
  const rows=scheduledRoutesForAircraft(aircraftId);
  const flightNumber=flightNumberFor(flightPrefixFor(getData()?.airline).prefix,
   $('route-plan-number')?.value)||'Preview';
  const schedule=availableSchedule();
  const proposal=aircraftId&&from&&to&&from.key!==to.key&&schedule.length?
   {flightNumber,aircraftId,from,to,schedule,
    operation:{departureStand:null,
      arrivalStand:$('route-arrival-stand')?.value}}:null;
  return buildAircraftWeeklyTimeline({
   aircraftId,routes:rows,proposal,excludeFlightNumber:editingFlightNumber,
   homeAirportKey:getData()?.airline?.homeAirportKey||null
  });
 };
 const departureStandFromTimeline=timeline=>{
  const proposed=timeline.events.filter(x=>x.proposed);
  const initial=catalogChoice()?.useType==='cargo'?'cargo':'terminal';
  const stands=[...new Set(proposed.map(x=>x.departureStand||initial))];
  // Current server schedules accept one departure stand per route.
  return stands.length<=1?(stands[0]||initial):null;
 };
 const groundStopConflict=()=>{
  const aircraft=$('route-aircraft')?.value||'';
  const from=selected('from');
  const nextDeparture=utcFromInput($('route-preflight-departure-utc')?.value);
  const turnaround=Number($('route-turnaround')?.value);
  if(!aircraft||!from||!nextDeparture||!Number.isInteger(turnaround))return null;
  const planned=Date.parse(nextDeparture);
  for(const previous of scheduledRoutesForAircraft(aircraft)){
   if(!previous||previous.flightNumber===editingFlightNumber||
      previous.aircraftId!==aircraft||previous.to?.key!==from.key)continue;
   const arrival=Date.parse(previous.referenceArrivalUtc||'');
   if(!Number.isFinite(arrival)||arrival>planned||planned-arrival>24*3600000)continue;
   // These UTC dates are user-entered route examples, not actual flight
   // arrivals. Reject a known overlapping draft, never authorize a flight.
   const minutes=(planned-arrival)/60000;
   if(minutes<turnaround)return 'Previous '+String(previous.flightNumber||'flight')+
    ' example arrives at '+new Date(arrival).toISOString().slice(11,16)+' UTC. The next example departure must be at least '+
    turnaround+' minutes later; current gap is '+Math.floor(minutes)+' minutes.';
  }
  return null;
 };
 const refreshAircraftTimeline=()=>{
  const timeline=selectedAircraftTimeline();
  renderAircraftWeeklyTimeline(doc,$('route-aircraft-timeline-content'),timeline);
  const chosen=timeline.events.filter(x=>x.proposed);
  const derived=departureStandFromTimeline(timeline);
  const label=!chosen.length?'No flight days selected':
   !derived?'Different stands across weekdays — separate route drafts required':
   (derived==='terminal'?'Terminal':derived==='remote'?'Remote stand':'Cargo stand')+
    (chosen.some(x=>!x.departureStand)?' (provisional first stand)':' · inherited from previous arrival');
  message('route-departure-stand-derived',label);
  for(let day=0;day<7;day++){
   const e=chosen.find(x=>x.day===day);
   message('route-stand-'+day,!e?'—':e.departureStand?
    (e.departureStand==='terminal'?'Terminal':e.departureStand==='remote'?'Remote':'Cargo'):
    derived?'Initial stand unverified':'Stand varies');
   message('route-arrival-stand-'+day,!e?'—':
    e.arrivalStand==='terminal'?'Terminal':e.arrivalStand==='remote'?'Remote':
    e.arrivalStand==='cargo'?'Cargo':'Unverified');
  }
  const feedback=$('route-aircraft-position-status');
  if(feedback){
   const ground=groundStopConflict();
   const conflict=timeline.errors.length>0||Boolean(ground);
   feedback.textContent=timeline.errors[0]?.text||ground||'';
   feedback.hidden=!conflict;
   feedback.classList.toggle('has-conflict',conflict);
  }
  return timeline;
 };
 const flagNode=iso=>{
  if(!/^[A-Z]{2}$/.test(iso||''))return null;
  const img=doc.createElement('img');
  img.className='route-summary-flag';img.src='https://flagcdn.com/w40/'+iso.toLowerCase()+'.png';
  img.alt=airportCountryName(iso)+' flag';img.width=20;img.height=13;img.loading='lazy';
  return img;
 };
 const renderAirport=(side,airport)=>{
  const node=$('route-'+side+'-summary');
  if(!node)return;
  node.replaceChildren();
  if(!airport){node.textContent='Select an approved airport.';return;}
  const flag=flagNode(airport.countryIso);
  if(flag)node.append(flag);
  const title=doc.createElement('span');
  title.textContent=airport.name+(airport.code?' ('+airport.code+')':'');
  node.append(title);
 };
 const shortRestrictions=airportRouteRestrictionSummary;
 const shortDemand=profile=>{
  if(!profile)return 'Data pending';
  const p=profile.demand?.passengerGroup,c=profile.demand?.cargoGroup;
  return 'Passengers '+(Number.isInteger(p)?p+'/5':'unknown')+
   ' · Cargo '+(Number.isInteger(c)?c+'/5':'unknown');
 };
 const showDetails=()=>{
  message('route-origin-restrictions',shortRestrictions(airportProfiles.from));
  message('route-destination-restrictions',shortRestrictions(airportProfiles.to));
  message('route-origin-demand',shortDemand(airportProfiles.from));
  message('route-destination-demand',shortDemand(airportProfiles.to));
 };
 const syncAircraftCompatibility=()=>{
  const aircraft=catalogChoice(),assessment=aircraft?runwayAssessment(aircraft):null;
  const selection=$('route-aircraft')?.value||'';
  const button=$('route-plan-save');
  if(button)button.disabled=assessment?.status==='BLOCKED';
  const reason=assessment?.status==='BLOCKED'?
   'BLOCKED — This aircraft cannot be used on this route. '+assessment.blockingReasons.join(' '):
   assessment?.status==='REVIEW'?'Runway review: '+assessment.reviewReasons.join(' '):
   assessment?.status==='PASS'?'Runway length suitable for takeoff and landing (game screening only).':
   selection?'Aircraft configuration loading — not approved for flight.':
   'Choose an aircraft to check departure and arrival runway lengths.';
  message('route-aircraft-check',reason);
  message('route-aircraft-feedback',reason);
  const el=$('route-aircraft-feedback');
  if(el){el.dataset.runwayStatus=assessment?.status||'PENDING';el.setAttribute('role','status');}
  return assessment;
 };
 const refreshCatalogOptions=()=>{
  const select=$('route-aircraft');if(!select)return;
  const saved=select.value;
  select.replaceChildren(new Option('Choose a company aircraft',''));
  for(const aircraft of ownedFleet){
   if(typeof aircraft.id!=='string'||!Number.isSafeInteger(aircraft.configurationId))continue;
   // Owner-scoped list includes in-service aircraft only. Never show catalog
   // models or demonstration aircraft as company-owned flight assignments.
   if(!['owned','leased'].includes(aircraft.ownershipType))continue;
   const model=catalogAircraft.find(a=>a.id===aircraft.configurationId);
   const assessment=model?runwayAssessment(model):null;
   const suffix=assessment?.status==='BLOCKED'?' — RUNWAY TOO SHORT':'';
   select.add(new Option((aircraft.ownershipType==='leased'?'LEASED':'OWNED')+' · '+
    String(aircraft.registration||'Aircraft')+' · '+
    String(model?.model||'Model '+aircraft.configurationId)+suffix,'owned:'+aircraft.id));
  }
  if([...select.options].some(option=>option.value===saved))select.value=saved;
  select.disabled=select.options.length<2;
  syncAircraftCompatibility();
  if(select.disabled)message('route-aircraft-feedback',fleetReadState==='verified'?
   'No in-service aircraft owned or leased by this company. Acquire, deliver and inspect one before scheduling.':
   'Verified company fleet is not available yet. Aircraft cannot be selected until an owner-scoped fleet read succeeds.');
 };
 const renderServerScheduleList=()=>{
  const holder=$('route-server-draft-list');if(!holder)return;
  holder.replaceChildren();
  if(!getData()?.scheduler){
   holder.textContent='Protected airline schedule service is not connected in this preview.';
   return;
  }
  if(!serverDrafts.length){
   holder.textContent='No saved server-owned flight schedule drafts yet.';
   return;
  }
  for(const draft of serverDrafts.slice(0,50)){
   if(typeof draft?.id!=='string')continue;
   const row=doc.createElement('div');row.className='fleet-test-aircraft-row';
   const title=doc.createElement('strong');
   title.textContent=String(draft.flightNumber||'Draft')+' · '+String(draft.originAirportKey||'')+
    ' to '+String(draft.destinationAirportKey||'');
   const subtitle=doc.createElement('small');
   subtitle.textContent='Server draft · weekly airport slots held · not active · '+String(draft.weeklySchedule?.length||0)+' departures per week';
   const inspect=doc.createElement('button');
   inspect.type='button';inspect.className='secondary';
   inspect.textContent='Check activation readiness';
   inspect.dataset.routeActivationReadinessId=draft.id;
   const remove=doc.createElement('button');
   remove.type='button';remove.className='secondary';
   remove.textContent='Delete and release slots';
   remove.dataset.routeServerDeleteId=draft.id;
   row.append(title,subtitle,inspect,remove);holder.append(row);
  }
 };
 const loadOwnedScheduleData=async airlineId=>{
  const ticket=++fleetTicket,scheduler=getData()?.scheduler;
  fleetReadState=airlineId&&typeof scheduler?.list==='function'?'loading':'unavailable';
  ownedFleet=[];serverDrafts=[];refreshCatalogOptions();renderServerScheduleList();
  if(!airlineId||typeof scheduler?.list!=='function')return;
  message('route-server-draft-status','Loading your registered operational aircraft and server drafts...');
  try{
   const response=await scheduler.list(airlineId);
   if(ticket!==fleetTicket)return;
   if(!Array.isArray(response?.fleet)||!Array.isArray(response?.drafts))
    throw Error('Unverified company fleet response');
   fleetReadState='verified';
   ownedFleet=Array.isArray(response?.fleet)?response.fleet.filter(a=>
    typeof a?.id==='string'&&Number.isSafeInteger(a.configurationId)&&a.configurationId>0):[];
   serverDrafts=Array.isArray(response?.drafts)?response.drafts:[];
   refreshCatalogOptions();renderServerScheduleList();refreshAircraftTimeline();
   message('route-server-draft-status',ownedFleet.length?
    ownedFleet.length+' operational aircraft connected. Server schedule drafts are separate from live flight activation.':
    'No company aircraft are in service. Purchase or lease one, complete delivery and inspection, then create a route.');
  }catch{
   if(ticket===fleetTicket){
    fleetReadState='unavailable';ownedFleet=[];serverDrafts=[];refreshCatalogOptions();renderServerScheduleList();
    message('route-server-draft-status','Server fleet/schedule service unavailable. No flight was activated.');
   }
  }
 };
 const loadAirportDetails=async(from,to)=>{
  const ticket=++detailTicket,reader=getData()?.reader;
  airportProfiles={};showDetails();
  if(!getData()?.connected||typeof reader?.airportProfile!=='function')return;
  const airports=[from,to];
  const result=await Promise.all(airports.map(async airport=>{
   if(!airport)return null;
   try{
    const response=await reader.airportProfile(airport.key);
    return response?.airport?.key===airport.key?response.airport:null;
   }catch{return null}
  }));
  if(ticket!==detailTicket)return;
  airportProfiles={from:result[0],to:result[1]};
  showDetails();
  drawMap();
  refreshCatalogOptions();
  void automaticPreflight();
 };
 const drawMap=()=>{
  const verified=(side,a)=>{
   if(!a)return null;
   const p=airportProfiles[side];
   return p?.key===a.key&&typeof p.latitude==='number'&&typeof p.longitude==='number'?
    {...a,latitude:p.latitude,longitude:p.longitude}:a;
  };
  const from=verified('from',selected('from'));
  const to=verified('to',selected('to'));
  const map=renderRouteMap($('route-map-canvas'),from,to,{doc});
  message('route-map-feedback',map?
   'Orange line: geographic distance between verified airports (not an approved flight path).':
   'Checking airport coordinates from the approved directory and airport profiles...');
  message('route-distance',map?
   Math.round(map.distanceKm).toLocaleString('en-US')+' km':'Data pending');
 };
 const show=()=>{
  const from=selected('from'),to=selected('to');
  renderAirport('from',from);renderAirport('to',to);
  for(const side of ['from','to'])countryFlag(side);
  const title=$('route-map-heading');
  if(title)title.textContent=from&&to?
   (from.code||from.name)+' – '+(to.code||to.name):'Select two airports';
  drawMap();
  message('route-block-time','Pending verified aircraft performance');
  message('route-market',from&&to?
   (from.countryIso===to.countryIso?'Domestic route':'International route'):'Select airports');
  const validPair=Boolean(from&&to&&from.key!==to.key);
  const validOrigin=Boolean(from&&from.key===homeKey);
  const demoAircraft=(Array.isArray(getData()?.airline?.testAircraft)?
   getData().airline.testAircraft:[]).find(a=>a.id===$('route-aircraft')?.value&&
    a.testOnly===true&&a.operationallyAllowed===false);
  syncAircraftCompatibility();
  message('route-slot-check','Select aircraft and flight times to check slots');
  message('route-traffic-rights','Not connected — rights not verified');
  message('route-status','Draft only');
  message('route-check-message',!validPair?'Choose two different approved airports.':
   !validOrigin?'Draft only: origin is not a confirmed active hub. Only your main hub is currently verified.':
   'Route geography available. Aircraft, crew, airport slots and traffic rights require verification before activation.');
  const keys=[from?.key||'',to?.key||''].join('|');
  if(keys!==lastKeys){lastKeys=keys;clearPreflight();void loadAirportDetails(from,to);}
  updateWeek();
  refreshAircraftTimeline();
  doc.dispatchEvent?.(new Event('airlinerra:refresh-game-select-menus'));
  void automaticPreflight();
 };
 for(const side of ['from','to']){
  pickers[side]=createAirportCountryPicker({
   country:$('route-'+side+'-country'),search:$('route-'+side+'-search'),
   airport:$('route-'+side+'-airport'),
   getReader:()=>getData()?.connected?getData()?.reader:null,
   onStatus:status=>message('route-'+side+'-count',status),
   onResults:(results,ready)=>renderSuggestions(side,results,ready),
   onSelect:airport=>{
    const quick=$('route-'+side+'-hub');
    if(quick)quick.value=airport?.key===homeKey&&homeLocation?homeKey:'';
    if(plannerInitialized)show();
   }
  });
  $('route-'+side+'-country')?.addEventListener('change',()=>countryFlag(side));
 }
 const renderQuickOptions=()=>{
  const home=homeLocation;
  for(const side of ['from','to']){
   const dropdown=$('route-'+side+'-hub');
   if(!dropdown)continue;
   const chosen=dropdown.value;
   dropdown.replaceChildren(new Option('Choose airport or browse country below',''));
   if(home){
    dropdown.add(new Option('★ Main hub · '+home.name+(home.code?' ('+home.code+')':''),home.key));
    if(chosen===home.key)dropdown.value=home.key;
   }
  }
 };
 const selectHome=async(side)=>{
  const home=homeLocation;
  if(!home||!pickers[side])return;
  const country=$('route-'+side+'-country');
  if(country.value!==home.countryIso){
   country.value=home.countryIso;
   countryFlag(side);
   await pickers[side].load();
  }
  if(pickers[side].choose(home.key))$('route-'+side+'-hub').value=home.key;
  show();
 };
 const updatePrefix=airline=>{
  const result=flightPrefixFor(airline);
  message('route-number-prefix',result.prefix||'—');
  message('route-prefix-note',result.prefix?
   result.provisional?'PA is a temporary Panonian game prefix; the database has no assigned airline code.':
   result.prefix+' is the airline’s stored IATA code.':
   'A valid two-character airline flight prefix must be registered before this flight can be numbered.');
 };
 const activateHome=async(data)=>{
  const ticket=++homeTicket,airline=data.airline,reader=data.reader;
  homeKey=airline?.homeAirportKey||null;homeLocation=null;
  renderQuickOptions();
  if(!homeKey||!data.connected||typeof reader?.airportProfile!=='function')return;
  try{
   const response=await reader.airportProfile(homeKey);
   if(ticket!==homeTicket||response?.airport?.key!==homeKey)return;
   const a=response.airport;
   if(!/^[A-Z]{2}$/.test(a.countryIso||''))return;
   homeLocation={
    key:homeKey,name:a.name||airline.homeAirportName||'Home airport',
    code:a.icao||airline.homeAirportCode||'',
    countryIso:a.countryIso,municipality:a.municipality||'',
    latitude:a.latitude,longitude:a.longitude
   };
   renderQuickOptions();
   if(!selected('from'))await selectHome('from');
  }catch{message('route-feedback','Home airport could not be preselected. Choose an approved origin manually.');}
 };
 const resetRouteForm=async()=>{
  const serial=++editSerial;
  editingFlightNumber=null;editingLegacyIndex=null;++detailTicket;lastKeys='';airportProfiles={};
  showDetails();
  if($('route-plan-number'))$('route-plan-number').value='';
  if($('route-aircraft'))$('route-aircraft').value='';
  for(const id of ['route-preflight-departure-utc','route-preflight-arrival-utc'])
   if($(id))$(id).value='';
  clearPreflight();
  if($('route-arrival-stand'))$('route-arrival-stand').value='terminal';
  if($('route-turnaround'))$('route-turnaround').value='45';
  for(const label of ['economy','premium','business','first'])
   if($('route-fare-'+label))$('route-fare-'+label).value='';
  for(const id of ['route-onboard-service','route-baggage-service'])
   if($(id))$(id).value='standard';
  if($('route-cargo-service'))$('route-cargo-service').value='none';
  for(let day=0;day<7;day++){
   const check=doc.querySelector('[data-route-day="'+day+'"]');
   const time=doc.querySelector('[data-route-time="'+day+'"]');
   if(check)check.checked=false;
   if(time)time.value='09:00';
  }
  for(const side of ['from','to']){
   const country=$('route-'+side+'-country'),search=$('route-'+side+'-search');
   if(country)country.value='';
   if(search)search.value='';
   pickers[side].invalidate();
   hideSuggestions(side);countryFlag(side);
   const quick=$('route-'+side+'-hub');if(quick)quick.value='';
  }
  message('route-feedback','');message('route-plan-review','');message('route-plan-status','');
  show();
  if(homeLocation&&serial===editSerial)await selectHome('from');
 };
 const selectStoredAirport=async(side,airport,serial)=>{
  if(!airport||typeof airport.key!=='string'||typeof airport.name!=='string')return false;
  const country=$('route-'+side+'-country'),search=$('route-'+side+'-search');
  if(!country||!search)return false;
  country.value='';
  search.value=String(airport.code||airport.name).slice(0,40);
  await pickers[side].load();
  if(serial!==editSerial)return false;
  if(pickers[side].choose(airport.key))return true;
  if(!/^[A-Z]{2}$/.test(airport.countryIso||''))return false;
  country.value=airport.countryIso;search.value='';
  await pickers[side].load();
  if(serial!==editSerial)return false;
  return pickers[side].choose(airport.key);
 };
 const editRouteDraft=async index=>{
  const stored=loadDraft?.()||{};
  const routes=Array.isArray(stored.routes)&&stored.routes.length?stored.routes:
   stored.route?[stored.route]:[];
  const route=routes[index];
  if(!route?.from||!route?.to)return;
  const serial=++editSerial;editingFlightNumber=route.flightNumber||null;
  editingLegacyIndex=route.flightNumber?null:index;
  message('route-plan-status','Loading saved route draft for editing...');
  for(const [side,airport] of [['from',route.from],['to',route.to]]){
   if(!await selectStoredAirport(side,airport,serial)){
    if(serial===editSerial)message('route-plan-status','Airport could not be verified. Select it again.');
    return;
   }
  }
  if(serial!==editSerial)return;
  const prefix=flightPrefixFor(getData()?.airline).prefix;
  const flight=String(route.flightNumber||'');
  if(prefix&&flight.startsWith(prefix)){
   const number=flight.slice(prefix.length);
   if(/^[0-9]{1,4}$/.test(number))$('route-plan-number').value=number;
  }
  $('route-aircraft').value=route.aircraftId||
   (Number.isSafeInteger(route.aircraftConfigurationId)?'catalog:'+route.aircraftConfigurationId:'');
  if($('route-preflight-departure-utc'))$('route-preflight-departure-utc').value=route.referenceDepartureUtc?.slice(0,16)||'';
  if($('route-preflight-arrival-utc'))$('route-preflight-arrival-utc').value=route.referenceArrivalUtc?.slice(0,16)||'';
  const arrivalStand=route.operation?.arrivalStand;
  if($('route-arrival-stand'))$('route-arrival-stand').value=
   ['remote','terminal','cargo'].includes(arrivalStand)?arrivalStand:'terminal';
  $('route-turnaround').value=String(route.operation?.turnaroundMinutes||45);
  for(let day=0;day<7;day++){
   const row=(Array.isArray(route.schedule)?route.schedule:[]).find(x=>x.day===day);
   const check=doc.querySelector('[data-route-day="'+day+'"]');
   const time=doc.querySelector('[data-route-time="'+day+'"]');
   if(check)check.checked=Boolean(row);
   if(time)time.value=row&&validLocalDeparture(row.time)?row.time:'09:00';
  }
  for(const label of ['economy','premium','business','first']){
   const value=route.operation?.fares?.[label];
   $('route-fare-'+label).value=value===null||value===undefined?'':String(value);
  }
  for(const [id,field,values,def] of [
   ['route-onboard-service','onboard',['standard','basic','enhanced'],'standard'],
   ['route-baggage-service','baggage',['standard','hand-only','checked'],'standard'],
   ['route-cargo-service','cargo',['none','requested'],'none']]){
   const value=route.operation?.service?.[field];
   $(id).value=values.includes(value)?value:def;
  }
  show();
  message('route-plan-status',route.flightNumber?
   'Editing '+route.flightNumber+' · changes will update this local draft only.':
   'Previous route idea loaded. Enter a flight number and choose days to save it as a draft.');
 };
 doc.addEventListener('airlinerra:edit-route-draft',event=>{
  const index=event.detail?.index;
  if(Number.isInteger(index)&&index>=0&&index<25)void editRouteDraft(index);
 });
 const main=$('player-main');
 main?.addEventListener('change',async event=>{
  const el=event.target;
  if(el?.matches?.('[data-route-day]')||el?.matches?.('[data-route-time]')){
   updateWeek();clearPreflight();show();void automaticPreflight();return;
  }
  if(['route-preflight-departure-utc','route-preflight-arrival-utc'].includes(el?.id)){
   clearPreflight();updateWeek();refreshAircraftTimeline();void automaticPreflight();return;
  }
  if(el?.id==='route-aircraft'){
   const type=catalogChoice()?.useType;
   if(type==='cargo')$('route-arrival-stand').value='cargo';
   else if(type==='passenger'&&$('route-arrival-stand')?.value==='cargo')
    $('route-arrival-stand').value='terminal';
   clearPreflight();show();void automaticPreflight();return;
  }
  if(el?.id==='route-arrival-stand'){
   clearPreflight();refreshAircraftTimeline();updateWeek();void automaticPreflight();return;
  }
  if(el?.id==='route-turnaround'){updateWeek();refreshAircraftTimeline();return;}
  if(el?.id==='route-from-hub'||el?.id==='route-to-hub'){
   const side=el.id==='route-from-hub'?'from':'to';
   if(el.value===homeKey&&homeLocation)await selectHome(side);
  }
 });
 main?.addEventListener('input',event=>{
  if(event.target?.id==='route-plan-number'){
   const el=event.target;
   el.value=el.value.replace(/\D/g,'').slice(0,4);
  }
 });
 main?.addEventListener('focusin',event=>{
  for(const side of ['from','to']){
   if(event.target?.id==='route-'+side+'-search'){
    hideCountryMenus();
    renderSuggestions(side,pickers[side].getAirports(),true);
   }
  }
 });
 main?.addEventListener('keydown',event=>{
  for(const side of ['from','to']){
   if(event.target?.id==='route-'+side+'-search'){
    if(event.key==='Escape'){hideSuggestions(side);return;}
    if(event.key==='ArrowDown'){
     const list=$('route-'+side+'-suggestions');
     if(list?.hidden)renderSuggestions(side,pickers[side].getAirports(),true);
     const first=list?.querySelector('button');
     if(first){event.preventDefault();first.focus();}
    }
   }
   if(event.target?.dataset?.routeAirportSide===side&&
      ['ArrowUp','ArrowDown'].includes(event.key)){
    const buttons=[...($('route-'+side+'-suggestions')?.querySelectorAll('button')||[])];
    const index=buttons.indexOf(event.target);
    const next=buttons[(index+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length];
    if(next){event.preventDefault();next.focus();}
   }
  }
 });
 doc.addEventListener('click',event=>{
  if(!event.target?.closest?.('.route-country-picker'))hideCountryMenus();
  for(const side of ['from','to']){
   if(!event.target?.closest?.('#route-'+side+'-suggestions')&&
      event.target?.id!=='route-'+side+'-search')hideSuggestions(side);
  }
 });
 const utcFromInput=value=>{
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(value))return null;
  const date=new Date(value+':00Z');
  return Number.isFinite(date.valueOf())&&date.toISOString().slice(0,16)===value?
   date.toISOString().slice(0,19)+'Z':null;
 };
 const loadPreflightCatalog=async()=>{
  const reader=getData()?.reader,ticket=++preflightLoadToken;
  catalogAircraft=[];refreshCatalogOptions();
  if(!getData()?.connected||typeof reader?.aircraftLibrary!=='function'){
   message('route-preflight-status','Aircraft catalog not connected. No flight can be activated.');
   return;
  }
  try{
   const data=await reader.aircraftLibrary();
   if(ticket!==preflightLoadToken)return;
   catalogAircraft=Array.isArray(data?.aircraft)?data.aircraft.filter(a=>
    Number.isSafeInteger(a?.id)&&a.id>0):[];
   refreshCatalogOptions();
   void automaticPreflight();
  }catch{
   if(ticket===preflightLoadToken){
    catalogAircraft=[];refreshCatalogOptions();
    message('route-preflight-status','Unable to load aircraft catalog. Cannot verify aircraft for this route.');
   }
  }
 };
 const automaticPreflight=async({force=false}={})=>{
  const reader=getData()?.reader,from=selected('from'),to=selected('to');
  const configurationId=selectedConfigurationId(),aircraft=catalogChoice();
  const assessment=aircraft?runwayAssessment(aircraft):null;
  const departureUtc=utcFromInput($('route-preflight-departure-utc')?.value);
  const arrivalUtc=utcFromInput($('route-preflight-arrival-utc')?.value);
  const weeklySchedule=availableSchedule().map(row=>({day:row.day,time:row.time}));
  if(assessment?.status==='BLOCKED'){
   message('route-preflight-status','BLOCKED — '+assessment.blockingReasons.join(' '));
   return {gameHardBlocked:true,reason:'runway'};
  }
  if(!from||!to||from.key===to.key||!configurationId){
   message('route-preflight-status','Select two different airports and an aircraft. Runway length is checked immediately.');
   return null;
  }
  if(!departureUtc||!arrivalUtc){
   message('route-preflight-status','Enter a departure and arrival UTC example. The game checks every selected weekday over four weeks automatically.');
   return null;
  }
  if(!weeklySchedule.length||weeklySchedule.some(x=>!validLocalDeparture(x.time))){
   message('route-preflight-status','Select weekdays and valid local departure times to check each flight in the weekly timetable.');
   return null;
  }
  if(Date.parse(arrivalUtc)<=Date.parse(departureUtc)||
   Date.parse(arrivalUtc)-Date.parse(departureUtc)>72*3600*1000){
   message('route-preflight-status','Arrival must be after departure and not more than 72 hours later.');
   return null;
  }
  if(!getData()?.connected||typeof reader?.noiseCurfewCheck!=='function'){
   message('route-preflight-status','Airport restriction service unavailable — cannot verify this route.');
   return null;
  }
  const ownedChoice=ownedFleet.find(a=>'owned:'+a.id===$('route-aircraft')?.value)||null;
  const departureStand=departureStandFromTimeline(selectedAircraftTimeline());
  if(!departureStand){
   message('route-preflight-status','Different departure stands across weekdays; split this schedule into separate route drafts.');
   return null;
  }
  const arrivalStand=$('route-arrival-stand')?.value||'terminal';
  const signature=[from.key,to.key,configurationId,departureUtc,arrivalUtc,
   JSON.stringify(weeklySchedule),departureStand,arrivalStand,ownedChoice?.id||'',
   editingFlightNumber||''].join('|');
  if(!force&&preflightCache?.signature===signature)return preflightCache.result;
  if(!force&&preflightPromise?.signature===signature)return preflightPromise.promise;
  const ticket=++preflightRequest;
  message('route-preflight-status','Checking each selected weekday across four weeks for runway, curfew and confirmed noise restrictions...');
  const promise=(async()=>{
   try{
    const result=await reader.noiseCurfewCheck({
     originAirportKey:from.key,destinationAirportKey:to.key,configurationId,
     departureUtc,arrivalUtc,weeklySchedule
    });
    if(ticket!==preflightRequest)return null;
    if(!result||typeof result.gameHardBlocked!=='boolean')throw Error('Invalid restriction result');
    let slotAvailability=null;
    const scheduler=getData()?.scheduler;
    if(!result.gameHardBlocked&&ownedChoice&&typeof scheduler?.slotCheck==='function'){
     try{
      slotAvailability=await scheduler.slotCheck({
       airlineId:getData().airline.id,aircraftInventoryId:ownedChoice.id,
       originAirportKey:from.key,destinationAirportKey:to.key,
       referenceDepartureUtc:departureUtc,referenceArrivalUtc:arrivalUtc,
       weeklySchedule,departureStand,arrivalStand,
       ...(loadDraft?.()?.routes?.find(d=>d?.flightNumber===editingFlightNumber)?.serverScheduleId?
        {existingId:loadDraft().routes.find(d=>d?.flightNumber===editingFlightNumber).serverScheduleId}:
        serverDrafts.find(d=>d.flightNumber===flightNumberFor(
         flightPrefixFor(getData().airline).prefix,$('route-plan-number')?.value))?.id?
         {existingId:serverDrafts.find(d=>d.flightNumber===flightNumberFor(
          flightPrefixFor(getData().airline).prefix,$('route-plan-number')?.value)).id}:{})
      });
     }catch{slotAvailability=null;}
    }
    if(ticket!==preflightRequest)return null;
    const checkedResult={...result,slotAvailability};
    message('route-weather-check',formatRouteWeatherPreview(result.weatherPreview));
    preflightCache={signature,result:checkedResult};
    if(ownedChoice){
     const available=slotAvailability?.available===true;
     const originOk=slotAvailability?.departureAvailable===true;
     const destinationOk=slotAvailability?.arrivalAvailable===true;
     message('route-slot-check',
      (originOk?'✓ Departure available':'✕ Departure unavailable')+' · '+
      (destinationOk?'✓ Arrival available':'✕ Arrival unavailable'));
     const display=$('route-slot-check');
     if(display){display.classList.toggle('has-conflict',!available);
      display.classList.toggle('has-available',available);}
    }else{
     message('route-slot-check','Owned aircraft required to check or reserve game slots');
    }
    const failures=[];
    for(const [place,leg] of [['Origin',result.origin],['Destination',result.destination]]){
     if(!leg)continue;
     if(leg.runwayBlocked){
      const available=typeof leg.availableRunwayM==='number'?Math.floor(leg.availableRunwayM):null;
      const required=typeof leg.requiredRunwayM==='number'?Math.ceil(leg.requiredRunwayM):null;
      failures.push(place+': runway not suitable'+(available!==null&&required!==null?
       ' ('+available.toLocaleString('en-US')+' m available; '+required.toLocaleString('en-US')+' m needed)':''));
     }
     if(leg.curfewBlocked)failures.push(place+': departure or arrival prohibited by airport hours');
     if(leg.verifiedNoiseBlocked)failures.push(place+': confirmed aircraft noise restriction');
    }
    const weeklyBlocks=Array.isArray(result.blockedWeeklyOccurrences)?result.blockedWeeklyOccurrences:[];
    const blockedDetail=weeklyBlocks.slice(0,3).map(x=>
     String(x.departureUtc||'Unknown time')+' UTC ('+
      [x.originOutcome,x.destinationOutcome].filter(Boolean).join(' / ').replace(/_/g,' ')+')').join('; ');
    const checked=result.weeklyOccurrencesChecked||weeklySchedule.length;
    const status=result.gameHardBlocked?'BLOCKED — '+(blockedDetail||failures.join(' ')||String(result.gameScheduleOutcome||'Airport restriction applies')):
     result.needsReview?'No confirmed airport ban for '+checked+' checked departures, but operating restrictions are not fully verified.':
      'No confirmed runway, nighttime or noise restrictions for '+checked+' checked departures. Other flight permissions still apply.';
    message('route-preflight-status',status);
    const save=$('route-plan-save');
    if(save)save.disabled=result.gameHardBlocked||runwayAssessment(aircraft).status==='BLOCKED'||
      (Boolean(ownedChoice)&&slotAvailability?.available!==true);
    return checkedResult;
   }catch{
    if(ticket===preflightRequest){
     preflightCache=null;
     message('route-preflight-status','Airport restriction check unavailable — no verified flight permission.');
     message('route-weather-check','Forecast unavailable — no weather authorization');
    }
    return null;
   }finally{
    if(preflightPromise?.signature===signature)preflightPromise=null;
   }
  })();
  preflightPromise={signature,promise};
  return promise;
 };
 main?.addEventListener('click',async event=>{
  const target=event.target?.closest?.('button');
  if(!target)return;
  if(target.dataset.routeServerDeleteId){
   const id=target.dataset.routeServerDeleteId;
   const airlineId=getData()?.airline?.id,scheduler=getData()?.scheduler;
   if(!airlineId||typeof scheduler?.delete!=='function'){
    message('route-server-draft-status','Schedule deletion service unavailable. Slots remain reserved.');
    return;
   }
   target.disabled=true;
   try{
    const result=await scheduler.delete({airlineId,scheduleId:id});
    if(result.deleted!==true)throw Error('Deletion not confirmed');
    serverDrafts=serverDrafts.filter(d=>d.id!==id);
    renderServerScheduleList();
    const current=loadDraft?.()||{};
    const cleaned=r=>r?.serverScheduleId===id?
      {...r,serverScheduleId:null,slotsReserved:false}:r;
    if(Array.isArray(current.routes))draftWrite('routes',current.routes.map(cleaned));
    if(current.route?.serverScheduleId===id)draftWrite('route',cleaned(current.route));
    doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved'));
    message('route-server-draft-status','Schedule deleted. Reserved airport slots released.');
    clearPreflight();
   }catch{
    target.disabled=false;
    message('route-server-draft-status','Deletion not confirmed. Slot reservations have not been released.');
   }
   return;
  }
  if(target.dataset.routeActivationReadinessId){
   const id=target.dataset.routeActivationReadinessId;
   const airlineId=getData()?.airline?.id,scheduler=getData()?.scheduler;
   if(!airlineId||typeof scheduler?.activationCheck!=='function'){
    message('route-server-draft-status','Flight activation service is unavailable.');
    return;
   }
   message('route-server-draft-status','Checking restrictions and operational readiness...');
   try{
    const result=await scheduler.activationCheck({airlineId,scheduleId:id});
    const missing=Array.isArray(result.reasons)?result.reasons.slice(0,6)
      .map(x=>String(x).replace(/_/g,' ').toLowerCase()).join('; '):'';
    message('route-server-draft-status',String(result.status||'Activation unavailable').replace(/_/g,' ')+
     (missing?' · '+missing:'')+'. No flight activated.');
   }catch{
    message('route-server-draft-status','Activation readiness check failed. No flight activated.');
   }
   return;
  }
  if(target.dataset.routeCountryTrigger){
   const side=target.dataset.routeCountryTrigger;
   const list=$('route-'+side+'-country-list'),open=Boolean(list?.hidden);
   hideCountryMenus();
   if(list&&open){list.hidden=false;target.setAttribute('aria-expanded','true');}
   return;
  }
  if(target.dataset.routeCountryChoice){
   const side=target.dataset.routeCountryChoice;
   const select=$('route-'+side+'-country');
   if(select){
    select.value=target.dataset.countryIso||'';
    select.dispatchEvent(new Event('change',{bubbles:true}));
    countryFlag(side);
   }
   hideCountryMenus();return;
  }
  if(target.dataset.routeAirportSide&&target.dataset.routeAirportKey){
   const side=target.dataset.routeAirportSide;
   pickers[side].choose(target.dataset.routeAirportKey);
   hideSuggestions(side);return;
  }
  if(target.id==='route-plan-swap'){
   const from=selected('from'),to=selected('to');
   if(!from||!to){message('route-feedback','Select two airports before swapping.');return;}
   for(const [side,a] of [['from',to],['to',from]]){
    $('route-'+side+'-country').value=a.countryIso;countryFlag(side);
   }
   await Promise.all([pickers.from.load(),pickers.to.load()]);
   pickers.from.choose(to.key);pickers.to.choose(from.key);
   message('route-feedback','Origin and destination exchanged.');show();return;
  }
  if(target.id==='route-plan-preview'){
   const from=selected('from'),to=selected('to');
   if(!from||!to||from.key===to.key){
    message('route-feedback','Choose two different approved airports before previewing.');return;
   }
   show();
   message('route-feedback','Route preview ready. Select an aircraft and weekday departures below.');
   return;
  }
  if(target.id==='route-plan-new'){
   await resetRouteForm();
   message('route-plan-status','Ready to create another route draft.');
   return;
  }
  if(target.id!=='route-plan-save')return;
  const data=getData(),from=selected('from'),to=selected('to');
  const flightNumber=flightNumberFor(flightPrefixFor(data?.airline).prefix,
   $('route-plan-number')?.value);
  const schedule=availableSchedule();
  if(!data?.connected||!data.airline?.id){
   message('route-plan-status','Sign in with a verified airline before saving a draft.');return;
  }
  if(!from||!to||from.key===to.key){
   message('route-plan-status','Select two different approved airports.');return;
  }
  if(!flightNumber){
   message('route-plan-status','Enter 1–4 digits after a valid airline flight prefix.');return;
  }
  if(!schedule.length||schedule.some(row=>!validLocalDeparture(row.time))){
   message('route-plan-status','Select at least one weekday and a valid local departure time.');return;
  }
  const operation=validateFlightDraftOptions({
   departureStand:departureStandFromTimeline(selectedAircraftTimeline()),
   arrivalStand:$('route-arrival-stand')?.value,
   turnaroundMinutes:Number($('route-turnaround')?.value),
   fares:Object.fromEntries(['economy','premium','business','first'].map(label=>
    [label,$('route-fare-'+label)?.value||''])),
   onboard:$('route-onboard-service')?.value,
   baggage:$('route-baggage-service')?.value,
   cargo:$('route-cargo-service')?.value
  });
  if(!operation){
   message('route-plan-status','Check turnaround (45–360 minutes), fares ($0–100,000), stand and service choices.');
   return;
  }
  const flightAircraft=$('route-aircraft')?.value||null;
  const ownedChoice=ownedFleet.find(a=>'owned:'+a.id===flightAircraft)||null;
  const selectedCatalog=catalogChoice(),selectedRunway=selectedCatalog?runwayAssessment(selectedCatalog):null;
  if(selectedRunway?.status==='BLOCKED'){
   message('route-plan-status','BLOCKED — This aircraft cannot use the route. '+selectedRunway.blockingReasons.join(' '));
   return;
  }
  if(!selectedCatalog){
   message('route-plan-status','A valid aircraft model from the game catalog is required to check this route.');
   return;
  }
  if(!airportProfiles.from||!airportProfiles.to){
   message('route-plan-status','Airport runway data unavailable. Cannot verify aircraft compatibility.');
   return;
  }
  const preflight=await automaticPreflight({force:true});
  if(!preflight||preflight.gameHardBlocked===true){
   message('route-plan-status',preflight?.gameHardBlocked===true?
    'BLOCKED — The selected aircraft or times violate an airport rule. See details above.':
    'Enter exact UTC times and complete automatic restrictions checking before saving this aircraft route.');
   return;
  }
  if(!ownedChoice){
   message('route-plan-status','Select an in-service aircraft owned or leased by this company. Test and catalogue aircraft cannot be scheduled.');
   return;
  }
  const timeline=selectedAircraftTimeline();
  if(timeline.errors.length){
   message('route-plan-status','Aircraft schedule conflict: '+timeline.errors[0].text);
   const details=$('route-aircraft-timeline');if(details)details.open=true;
   return;
  }
  if(!departureStandFromTimeline(timeline)){
   message('route-plan-status','This route needs different departure stands on different weekdays. Split the draft into separate routes.');
   return;
  }
  const groundConflict=groundStopConflict();
  if(groundConflict){
   message('route-plan-status','Aircraft turnaround conflict: '+groundConflict);
   return;
  }
  // Other flight durations, time zones and slots are still not verified.
  // No live financial, schedule or aircraft mutations: local browser-session draft only.
  const draft={from,to,flightNumber,flights:schedule.length,schedule,
   aircraftId:flightAircraft,
   aircraftConfigurationId:selectedCatalog.id,
   aircraftLabel:[selectedCatalog.manufacturer,selectedCatalog.model,selectedCatalog.configuration].filter(Boolean).join(' '),
   catalogPreviewOnly:false,testAircraft:false,
   serverScheduleId:null,
   referenceDepartureUtc:utcFromInput($('route-preflight-departure-utc')?.value),
   referenceArrivalUtc:utcFromInput($('route-preflight-arrival-utc')?.value),
   airportRuleScreen:{gameHardBlocked:false,needsReview:preflight.needsReview===true,
    checkedAt:new Date().toISOString(),notFlightActivation:true},
   operation,status:'draft',operationallyVerified:false};
  const latest=loadDraft?.()||{},routes=Array.isArray(latest.routes)?latest.routes:[];
  if(routes.some(x=>x?.flightNumber===flightNumber&&x?.flightNumber!==editingFlightNumber)){
   message('route-plan-status','Flight number already exists. Open that draft from My routes to edit it.');
   return;
  }
  const filtered=routes.filter((x,i)=>i!==editingLegacyIndex&&x?.flightNumber!==editingFlightNumber&&x?.flightNumber!==flightNumber);
  if(filtered.length>=25){
   message('route-plan-status','Maximum 25 route drafts. Remove another draft in My routes.');
   return;
  }
  const previousServerDraft=routes.find(x=>x?.flightNumber===editingFlightNumber);
  if(previousServerDraft?.serverScheduleId&&!ownedChoice){
   message('route-plan-status','This server schedule must stay linked to your registered fleet aircraft. Choose an owned/leased aircraft.');
   return;
  }
  if(ownedChoice){
   if(preflight.slotAvailability?.available!==true){
    message('route-plan-status','Departure or arrival slot is unavailable. Choose another time or stand type.');
    return;
   }
   const scheduler=data?.scheduler;
   if(typeof scheduler?.save!=='function'){
    message('route-plan-status','Secure schedule service not connected. Cannot save an operational-fleet schedule.');
    return;
   }
   message('route-plan-status','Saving checked owned-aircraft schedule to your airline server...');
   try{
    const result=await scheduler.save({
     airlineId:data.airline.id,aircraftInventoryId:ownedChoice.id,
     flightNumber,originAirportKey:from.key,destinationAirportKey:to.key,
     referenceDepartureUtc:draft.referenceDepartureUtc,
     referenceArrivalUtc:draft.referenceArrivalUtc,
     weeklySchedule:schedule,
     departureStand:operation.departureStand,arrivalStand:operation.arrivalStand,
     ...(previousServerDraft?.serverScheduleId?{existingId:previousServerDraft.serverScheduleId}:{})
    });
    if(result?.status!=='draft'||typeof result.scheduleId!=='string'||
       result.canActivateNormalFlight!==false||result.slotsReserved!==true)
     throw Error('Invalid schedule draft confirmation');
    draft.serverScheduleId=result.scheduleId;
    draft.slotsReserved=true;
    draft.operationallyVerified=false;
    // Refresh list without altering the already checked form.
    serverDrafts=[{id:result.scheduleId,status:'draft',flightNumber,
      aircraftInventoryId:ownedChoice.id,originAirportKey:from.key,
      destinationAirportKey:to.key,weeklySchedule:schedule,
      referenceDepartureUtc:draft.referenceDepartureUtc,
      referenceArrivalUtc:draft.referenceArrivalUtc,
      departureStand:operation.departureStand,arrivalStand:operation.arrivalStand},
     ...serverDrafts.filter(x=>x.id!==result.scheduleId&&x.flightNumber!==flightNumber)];
    renderServerScheduleList();
   }catch{
    message('route-plan-status','Server rejected or could not save this aircraft schedule. No active flight created.');
    return;
   }
  }
  if(!draftWrite('routes',[...filtered,draft])||!draftWrite('route',draft)){
   message('route-plan-status',draft.serverScheduleId?
    'Schedule saved to your airline server, but this browser could not cache the draft. See the server schedule list.':
    'Browser storage unavailable. Local route draft was not saved.');
   return;
  }
  doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved'));
  await resetRouteForm();
  message('route-plan-status',flightNumber+
   (draft.serverScheduleId?' saved with protected weekly airport slot reservations.':
     ' saved as a local catalog route preview without airport slot reservations.')+
    ' No commercial flight was activated.');

 });
 function updateData(data){
  for(const side of ['from','to'])
   populateAirportCountries($('route-'+side+'-country'),data?.countries||[],doc);
  renderCountryMenus(data?.countries||[]);
  refreshCatalogOptions();
  updatePrefix(data?.airline);
  const id=data?.connected?data?.airline?.id||null:null;
  if(id!==preflightCatalogFor){
   preflightCatalogFor=id;
   void loadPreflightCatalog();
  }
  if(id!==currentAirlineId){
   currentAirlineId=id;homeKey=null;homeLocation=null;
   void loadOwnedScheduleData(id);
   for(const side of ['from','to'])pickers[side].invalidate();
   void activateHome(data);
  }
  show();
 }
 plannerInitialized=true;
 updateWeek();show();
 return Object.freeze({updateData,preview:show,selected});
}
