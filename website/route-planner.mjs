/** Full route planning workspace, not commercial flight activation.
 * Only approved authenticated airport reads and account-local draft writes.
 */
import {createAirportCountryPicker,populateAirportCountries,airportFlag,airportCountryName} from './airport-country-picker.mjs';
import {renderRouteMap} from './route-map.mjs';
const section=(eyebrow,title,body)=>
 '<article class="panel route-planner-panel"><span class="panel-kicker">'+eyebrow+'</span><h2>'+title+'</h2>'+body+'</article>';
const field=(id,label,el)=>'<label class="workspace-label" for="'+id+'">'+label+'</label>'+el;
const picker=(side,title)=>'<fieldset class="route-planner-airport"><legend>'+title+'</legend>'+
 field('route-'+side+'-hub','Quick airport (your active hubs first)',
  '<select id="route-'+side+'-hub"><option value="">Choose airport or country below</option></select>')+
 field('route-'+side+'-country','Country',
  '<div class="route-country-select"><img id="route-'+side+'-country-flag" class="route-country-flag" alt="" hidden>'+
  '<select id="route-'+side+'-country"><option value="">Choose country</option></select></div>')+
 field('route-'+side+'-search','Search airport (optional)',
  '<input type="search" id="route-'+side+'-search" maxlength="40" placeholder="Type airport name, city or code">')+
 field('route-'+side+'-airport','Airport',
  '<select id="route-'+side+'-airport" disabled><option value="">Choose country first</option></select>')+
 '<p id="route-'+side+'-count" class="hint" role="status">Choose a country to view all its approved airports, or type to filter.</p>'+
 '<div id="route-'+side+'-summary" class="route-selection-summary">Select an airport.</div></fieldset>';
const dayNames=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const dayControl=(label,i)=>
 '<div class="route-week-day"><label class="route-week-day-label" for="route-day-'+i+'">'+label+'</label>'+
 '<label class="route-week-check"><input type="checkbox" data-route-day="'+i+'" id="route-day-'+i+'">'+
 '<span>Fly</span></label><input type="time" data-route-time="'+i+'" aria-label="'+label+
 ' departure time" value="09:00" disabled></div>';
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
   '<p id="route-map-feedback" class="hint">The map uses verified airport coordinates where available.</p>')+
 '</div>'+
 section('STEP 2','Aircraft and weekly departures',
  '<p class="hint">Choose an aircraft and the weekday and local departure time for each flight. A schedule saved here is only a browser draft, never a reserved slot.</p>'+
  '<div class="route-aircraft-choice">'+field('route-aircraft','Aircraft for this flight',
   '<select id="route-aircraft"><option value="">No available owned aircraft (fleet not connected)</option></select>')+
  '<p id="route-aircraft-feedback" class="hint">Aircraft ownership and tail-specific assignments must be connected before any flight can be activated.</p></div>'+
  '<div class="route-week-grid" role="group" aria-label="Weekly departure days and local times">'+
  dayNames.map(dayControl).join('')+'</div>'+
  '<div class="route-week-footer"><span id="route-flights" class="route-week-count">0 departures/week</span>'+
  '<p class="hint">Departure times use the origin airport’s local time; timezone conflicts and arrival slots require server validation.</p></div>'+
  '<div class="workspace-actions"><button type="button" id="route-plan-save" class="primary">Save flight schedule draft</button>'+
  '<button type="button" class="secondary" data-workspace-go="route-list">My routes</button></div>'+
  '<p id="route-plan-status" class="hint" role="status"></p>'+
  '<div id="route-plan-review" class="workspace-detail"></div>')+
 section('ROUTE CHECK','Distance, demand and operational checks',
  '<p class="hint">This is a factual preview, not a departure authorization. Unknown or unconnected checks never count as passed.</p>'+
  '<div class="route-check-grid">'+
   '<div class="route-check-item"><span>Distance</span><strong id="route-distance">Select airports</strong></div>'+
   '<div class="route-check-item"><span>Estimated flight duration</span><strong id="route-block-time">Aircraft required</strong></div>'+
   '<div class="route-check-item"><span>Market</span><strong id="route-market">Select airports</strong></div>'+
   '<div class="route-check-item"><span>Route status</span><strong id="route-status">Draft only</strong></div>'+
   '<div class="route-check-item"><span>Origin runway / noise / curfew</span><strong id="route-origin-restrictions">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Destination runway / noise / curfew</span><strong id="route-destination-restrictions">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Origin passenger / cargo demand</span><strong id="route-origin-demand">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Destination passenger / cargo demand</span><strong id="route-destination-demand">Data pending</strong></div>'+
   '<div class="route-check-item"><span>Departure / arrival slots</span><strong id="route-slot-check">Not yet connected</strong></div>'+
   '<div class="route-check-item"><span>Aircraft / runway suitability</span><strong id="route-aircraft-check">No aircraft assigned</strong></div>'+
   '<div class="route-check-item"><span>Passenger / cargo traffic rights</span><strong id="route-traffic-rights">Not yet connected</strong></div>'+
  '</div>'+
  '<p id="route-check-message" class="route-check-message" role="status">Select a route and aircraft to begin checking feasibility.</p>');
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
export const validLocalDeparture=time=>/^([01]\d|2[0-3]):[0-5]\d$/.test(String(time||''));
export function createRoutePlanner({doc,getData,loadDraft,draftWrite}={}){
 if(!doc||typeof getData!=='function'||typeof draftWrite!=='function')
  throw Error('Verified route planner data required');
 const $=id=>doc.getElementById(id);
 const days=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
 let homeKey=null,homeLocation=null,currentAirlineId=null,homeTicket=0,detailTicket=0;
 let lastKeys='',airportProfiles={};
 const pickers={},selected=side=>pickers[side]?.selected()||null;
 const message=(id,value)=>{if($(id))$(id).textContent=value;};
 const countryFlag=side=>{
  const iso=$('route-'+side+'-country')?.value||'';
  const img=$('route-'+side+'-country-flag');
  if(!img)return;
  if(/^[A-Z]{2}$/.test(iso)){
   img.src='https://flagcdn.com/w40/'+iso.toLowerCase()+'.png';
   img.alt=airportCountryName(iso)+' flag';img.hidden=false;
  }else{img.removeAttribute('src');img.hidden=true;}
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
  const schedule=availableSchedule();
  for(let day=0;day<7;day++){
   const check=doc.querySelector('[data-route-day="'+day+'"]');
   const time=doc.querySelector('[data-route-time="'+day+'"]');
   if(time)time.disabled=!check?.checked;
  }
  message('route-flights',schedule.length+' '+(schedule.length===1?'departure':'departures')+'/week');
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
 const shortRestrictions=profile=>{
  if(!profile)return 'Data pending';
  const runway=Array.isArray(profile.runways)?profile.runways
   .filter(r=>typeof r.lengthM==='number'&&Number.isFinite(r.lengthM))
   .map(r=>r.lengthM):[];
  const longest=runway.length?Math.max(...runway).toLocaleString('en-US')+' m runway':'Runway unverified';
  const raw=String(profile.facilities?.curfew||'').replace(/\s*\([^)]*\)/g,'').trim();
  const restrictions=Array.isArray(profile.operations?.timeRestrictions)&&
   profile.operations.timeRestrictions.length?'Curfew restrictions apply':
   raw|| (profile.operations?.hoursBasis==='GAME_DEFAULT_24_7_UNLESS_DOCUMENTED_EXCEPTION'?
    'No game curfew reported':'Curfew unverified');
  const chapter=profile.operations?.icaoNoiseRules?.nationalCivilJetMinimumChapter;
  const noise=Number.isInteger(chapter)?'Noise Chapter '+chapter+'+':'Noise rules not verified';
  return longest+' · '+restrictions+' · '+noise;
 };
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
 };
 const show=()=>{
  const from=selected('from'),to=selected('to');
  renderAirport('from',from);renderAirport('to',to);
  for(const side of ['from','to'])countryFlag(side);
  const title=$('route-map-heading');
  if(title)title.textContent=from&&to?
   (from.code||from.name)+' – '+(to.code||to.name):'Select two airports';
  const map=renderRouteMap($('route-map-canvas'),from,to,{doc});
  message('route-map-feedback',map?
   'Great-circle planning line from approved airport coordinates. Not a commercial flight path.':
   'Select two airports with verified coordinates to display the route.');
  message('route-distance',map?
   Math.round(map.distanceKm).toLocaleString('en-US')+' km':'Data pending');
  message('route-block-time','Aircraft required');
  message('route-market',from&&to?
   (from.countryIso===to.countryIso?'Domestic route':'International route'):'Select airports');
  const validPair=Boolean(from&&to&&from.key!==to.key);
  const validOrigin=Boolean(from&&from.key===homeKey);
  message('route-aircraft-check','No owned aircraft assigned; suitability not verified');
  message('route-slot-check','Not connected — cannot reserve or verify slots');
  message('route-traffic-rights','Not connected — rights not verified');
  message('route-status','Draft only');
  message('route-check-message',!validPair?'Choose two different approved airports.':
   !validOrigin?'Draft only: origin is not a confirmed active hub. Only your main hub is currently verified.':
   'Route geography available. Aircraft, crew, airport slots and traffic rights require verification before activation.');
  const keys=[from?.key||'',to?.key||''].join('|');
  if(keys!==lastKeys){lastKeys=keys;void loadAirportDetails(from,to);}
  updateWeek();
 };
 for(const side of ['from','to']){
  pickers[side]=createAirportCountryPicker({
   country:$('route-'+side+'-country'),search:$('route-'+side+'-search'),
   airport:$('route-'+side+'-airport'),
   getReader:()=>getData()?.connected?getData()?.reader:null,
   onStatus:status=>message('route-'+side+'-count',status),
   onSelect:show
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
 const main=$('player-main');
 main?.addEventListener('change',async event=>{
  const el=event.target;
  if(el?.matches?.('[data-route-day]')||el?.matches?.('[data-route-time]')){
   updateWeek();show();return;
  }
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
 main?.addEventListener('click',async event=>{
  const target=event.target?.closest?.('button');
  if(!target)return;
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
  const flightAircraft=$('route-aircraft')?.value||null;
  // Aircraft and slots are NOT silently accepted: this creates a local browser draft.
  const draft={from,to,flightNumber,flights:schedule.length,schedule,
   aircraftId:flightAircraft,status:'draft',operationallyVerified:false};
  const latest=loadDraft?.()||{},routes=Array.isArray(latest.routes)?latest.routes:[];
  const filtered=routes.filter(x=>x?.flightNumber!==flightNumber);
  if(filtered.length>=25){
   message('route-plan-status','Maximum 25 local route drafts. Remove another draft in My routes.');return;
  }
  if(!draftWrite('routes',[...filtered,draft])||!draftWrite('route',draft)){
   message('route-plan-status','Browser storage unavailable. Flight draft was not saved.');return;
  }
  const review=$('route-plan-review');
  if(review){
   review.replaceChildren();
   const line=doc.createElement('p');
   line.textContent='Saved '+flightNumber+': '+from.name+' → '+to.name+
    ' · '+schedule.map(x=>days[x.day]+' '+x.time).join(', ')+
    '. Local draft only; no aircraft or slots reserved.';
   review.append(line);
  }
  doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved'));
  message('route-plan-status','Flight timetable draft saved. Activation is blocked until aircraft, slots, crew and traffic rights are verified.');
 });
 function updateData(data){
  for(const side of ['from','to'])
   populateAirportCountries($('route-'+side+'-country'),data?.countries||[],doc);
  updatePrefix(data?.airline);
  const id=data?.connected?data?.airline?.id||null:null;
  if(id!==currentAirlineId){
   currentAirlineId=id;homeKey=null;homeLocation=null;
   for(const side of ['from','to'])pickers[side].invalidate();
   void activateHome(data);
  }
  show();
 }
 updateWeek();show();
 return Object.freeze({updateData,preview:show,selected});
}
