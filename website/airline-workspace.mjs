import {routePlannerMarkup,createRoutePlanner} from './route-planner.mjs';
import {buildAircraftWeeklyTimeline,renderAircraftWeeklyTimeline} from './aircraft-weekly-timeline.mjs';
import {aircraftDisplayName} from './aircraft-library.mjs';
import {buildAirlineWeeklyBoard,renderAirlineWeeklyBoard} from './aircraft-weekly-schedule-board.mjs';
/** Airlinerra airline-management workspace.
 * Real server read models stay separate from local-only planning. All page
 * structure in this module is constant markup authored by the application.
 * Never interpolate untrusted names into innerHTML.
 */
export const AIRLINE_UI_DEFAULTS=Object.freeze({
 units:'km',time:'24',date:'dmy',timezone:'local',language:'en',
 density:'comfortable',motion:'normal',theme:'light',landing:'overview',
 hints:true
});
export const AIRLINE_UI_VIEWS=Object.freeze([
 'overview','airline','fleet','routes','route-details','schedule','finances','worlds',
 'airports','staff','rankings','service','aircraft-market','maintenance',
 'settings','interface','notifications','help'
]);
export function cleanUiPreferences(value){
 const v=value&&typeof value==='object'?value:{};
 const allowed={
  units:['km','mi'],time:['24','12'],date:['dmy','mdy','ymd'],
  timezone:['local','utc'],language:['en'],density:['comfortable','compact'],
  motion:['normal','reduced'],theme:['light','dark'],
  landing:['overview','airline','fleet','routes','schedule','finances'],
  hints:[true,false]
 };
 return Object.freeze(Object.fromEntries(Object.entries(allowed).map(([key,choices])=>[
  key,choices.includes(v[key])?v[key]:AIRLINE_UI_DEFAULTS[key]
 ])));
}
export function financialScenario(data){
 const num=key=>{
  const value=Number(data?.[key]);
  return Number.isFinite(value)&&value>=0&&value<=10000000000?value:0;
 };
 const income=num('revenue');
 const categories=['leases','crew','fuel','maintenance','airportFees','services','marketing'];
 const expenses=categories.reduce((sum,k)=>sum+num(k),0);
 const net=income-expenses;
 const cash=num('cash');
 return Object.freeze({income,expenses,net,cash,months:net<0?cash/(-net):null});
}
export function validateRouteIdea(idea){
 if(!idea||typeof idea!=='object')return false;
 const source=idea.from,destination=idea.to;
 return !!(source&&destination&&typeof source.key==='string'&&
  typeof destination.key==='string'&&source.key!==destination.key&&
  Number.isInteger(Number(idea.flights))&&Number(idea.flights)>=1&&Number(idea.flights)<=28);
}
const currency=value=>Number.isFinite(Number(value))
 ?new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',maximumFractionDigits:0,minimumFractionDigits:0}).format(Number(value)):'-';
const small=(text)=>'<p class="hint">'+text+'</p>';
const card=(title,content,kicker='WORKSPACE')=>'<article class="panel workspace-panel"><span class="panel-kicker">'+kicker+'</span><h2>'+title+'</h2>'+content+'</article>';
const button=(page,label)=>'<button type="button" class="secondary" data-workspace-go="'+page+'">'+label+'</button>';
const status=(text)=>'<p class="workspace-state">'+text+'</p>';
const field=(id,label,control)=>'<label class="workspace-label" for="'+id+'">'+label+'</label>'+control;
const optionSelect=(id,values)=>'<select id="'+id+'">'+values.map(o=>'<option value="'+o[0]+'">'+o[1]+'</option>').join('')+'</select>';
const navigation=()=>[
 '<div class="workspace-quick-links">',
 button('airline','Company'),button('fleet','Fleet'),button('aircraft-market','Aircraft market'),
 button('routes','Routes'),button('schedule','Schedule'),button('finances','Finances'),
 button('staff','Staff'),button('service','Passenger service')
 ,'</div>'].join('');
const pages=Object.freeze({
 'airline':()=>card('Company identity',
   '<div class="detail-row"><span>Airline</span><strong id="office-airline">Not created</strong></div>'+
   '<div class="detail-row"><span>ICAO airline code</span><strong id="office-icao">-</strong></div>'+
   '<div class="detail-row"><span>IATA airline code</span><strong id="office-iata">-</strong></div>'+
   '<div class="detail-row"><span>World</span><strong id="office-world">-</strong></div>'+
   '<div class="detail-row"><span>Home airport</span><strong id="office-home">-</strong></div>'+
   '<div class="detail-row"><span>Available cash</span><strong id="office-cash">-</strong></div>'+
   small('Airline name, ICAO/IATA codes and home airport remain fixed to protect company identity and existing game operations.'),
   'AIRLINE IDENTITY')+
   card('Airline logo',
    '<div class="manage-airline-logo-layout">'+
    '<div class="manage-airline-logo-frame"><img id="manage-airline-logo-preview" alt="Current airline logo" hidden>'+
    '<span id="manage-airline-logo-placeholder">No logo uploaded</span></div>'+
    '<div class="manage-airline-logo-control">'+
    '<label for="manage-airline-logo-file">Replace company logo</label>'+
    '<input id="manage-airline-logo-file" type="file" accept="image/png,image/jpeg,image/webp">'+
    '<p class="hint">PNG, JPG or WebP up to 6 MB. Converted to WebP (max 1 MB). The new logo replaces the old file.</p>'+
    '<button class="primary" type="button" id="manage-airline-logo-save" disabled>Save new logo</button>'+
    '<p id="manage-airline-logo-status" class="hint" role="status" aria-live="polite"></p>'+
    '</div></div>',
    'COMPANY BRANDING')+
   card('Public airline presentation',
    '<p>A future airline homepage will be visible to other players. This editor is not active yet.</p>'+
    '<div class="workspace-task-list">'+
    '<div><strong>Company profile</strong><span>Name, logo, headquarters, country and short description</span></div>'+
    '<div><strong>Operational overview</strong><span>Verified fleet, passenger totals, destinations and newest routes</span></div>'+
    '<div><strong>Optional gallery</strong><span>Aircraft photos managed by the airline owner</span></div></div>'+
    '<p class="hint">The public page will use actual game data. Manager hometown, email and other personal account information remain private.</p>',
    'FUTURE FEATURE'),
  'fleet':()=>card('Fleet inventory',
   '<div class="workspace-kpis"><div><span>Owned aircraft</span><strong id="fleet-owned-count">0</strong></div>'+
   '<div><span>Leased aircraft</span><strong id="fleet-leased-count">0</strong></div>'+
   '<div><span>Fleet status</span><strong id="fleet-real-status">Not loaded</strong></div>'+
   '<div><span>Simulation aircraft</span><strong id="fleet-test-count">0</strong></div></div>'+
   '<div id="fleet-owned-aircraft" class="fleet-test-aircraft" aria-live="polite">Loading your actual aircraft fleet...</div>'+ 
   '<p id="fleet-delivery-feedback" class="hint" role="status" aria-live="polite"></p>'+ 
   '<div id="fleet-test-aircraft" class="fleet-test-aircraft"></div>'+
   '<section id="fleet-aircraft-timeline" class="fleet-aircraft-timeline" hidden><h3 id="fleet-aircraft-timeline-heading">Aircraft weekly timeline</h3><p class="route-subtle-note">Local draft assignments are not live flights.</p><div id="fleet-aircraft-timeline-content"></div></section>'+
   status('Purchased and leased aircraft appear above once delivered by a server-verified acquisition. An aircraft awaiting delivery remains stored and cannot be scheduled.')+
   button('aircraft-market','View market offers')+button('maintenance','Maintenance planning'),
   'AIRCRAFT FLEET')+
  card('Fleet acquisition brief',
   '<p>Prepare aircraft requirements before the real marketplace is connected.</p>'+
   field('fleet-family','Aircraft type',optionSelect('fleet-family',[
    ['turboprop','Turboprop'],['regional','Regional jet'],['narrow','Narrow-body jet'],
    ['wide','Wide-body jet'],['cargo','Dedicated freighter']]))+
   field('fleet-seats','Target passenger seats','<input id="fleet-seats" type="number" min="0" max="1000" value="120">')+
   field('fleet-range','Minimum range (km)','<input id="fleet-range" type="number" min="0" max="30000" value="2000">')+
   field('fleet-acquisition','Preferred financing',optionSelect('fleet-acquisition',[
    ['lease','Lease'],['purchase','Purchase'],['compare','Compare both']]))+
   '<div class="workspace-actions"><button type="button" id="fleet-plan-save" class="primary">Save local fleet brief</button></div>'+
   '<p id="fleet-plan-status" class="hint" role="status"></p>'+
   small('A fleet brief is personal planning only. It does not purchase, lease, reserve or price an aircraft.'),
   'YOUR PROCUREMENT PLAN'),
 'aircraft-market':()=>card('Aircraft marketplace',
   '<p>Purchase or lease an individual aircraft from a published game-market offer. Only the airline owner can confirm an order.</p>'+
   '<p id="market-state" class="workspace-state" role="status">Loading approved offers...</p>'+
   '<div id="market-offers" class="fleet-test-aircraft"></div>'+
   field('market-offer-select','Published offer','<select id="market-offer-select" disabled><option value="">No offers loaded</option></select>')+
   field('market-aircraft-registration','Aircraft registration',
    '<input id="market-aircraft-registration" maxlength="20" autocomplete="off" placeholder="e.g. D-ABCD" aria-describedby="market-feedback">')+
   '<button type="button" class="primary" id="market-acquire" disabled>Confirm aircraft order</button>'+
   '<p id="market-feedback" class="hint" role="status" aria-live="polite"></p>'+
   small('The published upfront amount is deducted from your in-game airline cash when you confirm. Lease payments and delivery are tracked separately; aircraft cannot operate until delivery, inspection, and flight systems are ready. No transaction is possible without a published offer.')+
   button('fleet','Open my fleet'),'BUY AND LEASE')+
  card('Purchase readiness',
   '<p>Before ordering, confirm runway compatibility, technical range, seat demand, cash reserve and crew coverage. No aircraft can be dispatched without a real acquired airframe.</p>'+
   button('routes','Evaluate destinations')+button('finances','Check financing scenarios'),
   'OPERATING REQUIREMENTS'),
 'maintenance':()=>card('Maintenance control',
   '<div class="workspace-task-list">'+
   '<div><strong>Aircraft condition</strong><span>Hours, cycles and component status</span></div>'+
   '<div><strong>Routine service</strong><span>Turnaround checks and minor inspections</span></div>'+
   '<div><strong>Periodic inspections</strong><span>Scheduled A/C/D-level maintenance when applicable</span></div>'+
   '<div><strong>Grounding and return</strong><span>Aircraft availability and readiness checks</span></div></div>'+
   status('No live tail-level maintenance or airworthiness feed is available. Scheduling maintenance would require an acquired aircraft and a server-owned service record.')+
   button('fleet','Return to fleet'),'TECHNICAL OPERATIONS')+
  card('Maintenance decision guide',
   '<p>Inspect aircraft condition and maintenance deadlines before placing flights. Aircraft must remain unavailable while grounded or in a required inspection window.</p>',
   'SAFETY'),
 'routes':()=>routePlannerMarkup(),
 'schedule':()=>card('Aircraft weekly flight schedule',
   '<p class="hint">Each row is a real aircraft owned or leased by this airline. Each weekday spans 00:00–24:00 UTC. Departure times, route numbers and verified flight windows appear inside each day.</p>'+
   '<div class="workspace-actions schedule-board-actions">'+
    '<button type="button" class="secondary" id="schedule-refresh">Refresh timetable</button>'+
    button('routes','Create a route')+'</div>'+
   '<div class="schedule-board-legend" aria-label="Schedule status legend">'+
    '<span><i class="schedule-board-legend-marker" aria-hidden="true"></i> Planning departure — duration unverified</span>'+
    '<span><i class="schedule-board-legend-band" aria-hidden="true"></i> Airport slots held — flight window only</span>'+
    '</div>'+
   '<p id="schedule-status" role="status" class="hint">Loading the verified airline fleet and routes…</p>'+
   '<div id="schedule-aircraft-board" class="schedule-aircraft-board" aria-label="Airline aircraft seven-day flight timetable"></div>'+
   small('Planning drafts do not reserve an aircraft or airport slot. Slot-held flight windows are not activated flights; arrival ground handling, turnaround and crew checks still apply. An unverified duration is never shown as a booked window.'),
   'AIRCRAFT × 7 DAYS × 24 HOURS'),
 'finances':()=>card('Financial position',
   '<div class="workspace-kpis"><div><span>Available cash</span><strong id="finance-live-cash">-</strong></div>'+
   '<div><span>Transactions</span><strong>Not connected</strong></div>'+
   '<div><span>Operating profit</span><strong>Not connected</strong></div></div>'+
   '<p>The cash value comes from the verified airline record. Revenue, debts, loans, salaries and bank transactions require a secured financial ledger endpoint.</p>',
   'SERVER FINANCES')+
  card('Monthly budget scenario',
   '<p>Enter your own assumptions to estimate operating cash needs. All numbers here are hypothetical and do not change game finances.</p>'+
   '<div class="workspace-money-grid">'+
   [['revenue','Passenger and cargo revenue'],['leases','Aircraft leases'],
    ['crew','Salaries and crew'],['fuel','Fuel'],['maintenance','Maintenance'],
    ['airportFees','Airport handling and fees'],['services','Onboard and ground services'],
    ['marketing','Marketing']].map(([id,label])=>
    field('budget-'+id,label,'<input id="budget-'+id+'" type="number" min="0" step="100" max="10000000000" value="0">')).join('')+
   '</div><div class="workspace-actions"><button type="button" class="primary" id="budget-calc">Calculate scenario</button></div>'+
   '<div id="budget-result" class="workspace-detail" role="status"></div>'+
   small('The scenario uses user-entered monthly figures and latest displayed cash. It is not the actual income statement, balance sheet or cash flow.'),
   'PLANNING TOOL'),
 'staff':()=>card('Personnel office',
   '<p>Airline operations rely on sufficient qualified people. Crew, ground teams and engineering teams will be linked to aircraft and airport operations.</p>'+
   '<div class="workspace-kpis"><div><span>Employed staff</span><strong>Not connected</strong></div>'+
   '<div><span>Required crew</span><strong>Not calculated</strong></div>'+
   '<div><span>Payroll</span><strong>Not connected</strong></div></div>'+
   '<div class="workspace-task-list">'+
   '<div><strong>Pilots and flight deck</strong><span>Type ratings, crew rest and rotations</span></div>'+
   '<div><strong>Cabin crew</strong><span>Training, roster coverage and service</span></div>'+
   '<div><strong>Engineering</strong><span>Technical maintenance and inspections</span></div>'+
   '<div><strong>Ground handling</strong><span>Turnaround, baggage and airport services</span></div>'+
   '<div><strong>Dispatch and operations</strong><span>Flight release, monitoring and recovery</span></div>'+
   '<div><strong>Commercial and management</strong><span>Planning, sales and customer care</span></div></div>'+
   status('Hiring, employment contracts and payroll cannot be executed until the personnel backend is connected.'),
   'STAFF AND PAYROLL'),
 'rankings':()=>card('World rankings',
   '<p>Compete with airlines in the same world. When the live ranking engine is available, this page will show verified airline positions and performance.</p>'+
   '<div class="workspace-kpis"><div><span>Airlines ranked</span><strong>Not published</strong></div>'+
   '<div><span>Your position</span><strong>-</strong></div>'+
   '<div><span>World</span><strong>World 1</strong></div></div>'+
   '<div class="workspace-task-list">'+
   '<div><strong>Airline scale</strong><span>Active fleet, destinations and capacity</span></div>'+
   '<div><strong>Financial performance</strong><span>Revenue, profitability and cash</span></div>'+
   '<div><strong>Operational quality</strong><span>On-time performance and reliability</span></div>'+
   '<div><strong>Customer satisfaction</strong><span>Passenger service and reputation</span></div></div>'+
   status('No verified competitor rankings are available. Nothing in this view is an invented live leaderboard.'),
   'MULTIPLAYER'),
 'service':()=>card('Cabin and passenger service',
   '<p>Plan a four-class cabin and choose your product positioning. The final seat layout must be checked against the exact aircraft variant before activation.</p>'+
   '<div class="workspace-money-grid">'+
   [['economy','Economy'],['premium','Premium economy'],['business','Business'],['first','First']].map(([id,label])=>
    field('cabin-'+id,label,'<input id="cabin-'+id+'" type="number" min="0" max="1000" value="0">')).join('')+
   '</div>'+
   field('cabin-service','Passenger service level',optionSelect('cabin-service',[
    ['basic','Basic'],['standard','Standard'],['premium','Premium']]))+
   '<div class="workspace-actions"><button type="button" class="primary" id="cabin-save">Save local cabin brief</button></div>'+
   '<p id="cabin-feedback" class="hint" role="status"></p>'+
   small('No seat reservations, fare rules, service purchases or cabin modifications are sent to the game server.'),
   'CABIN PRODUCT')+
  card('Cargo and customer experience',
   '<div class="workspace-task-list">'+
   '<div><strong>Passenger services</strong><span>Check-in, baggage, catering, amenities and connections</span></div>'+
   '<div><strong>Cargo services</strong><span>Belly capacity, dedicated freighters and handling</span></div>'+
   '<div><strong>Service quality</strong><span>Fare/service competitiveness and passenger satisfaction</span></div>'+
   '<div><strong>Sales and distribution</strong><span>Booking availability, route pricing and ancillary income</span></div></div>'+
   status('Cargo capacity and passenger demand remain pending until the aircraft and demand engines are connected.'),
   'SERVICE STRATEGY'),
 'worlds':()=>card('World structure',
   '<div class="workspace-task-list">'+
   '<div><strong>Horizon - World 1</strong><span>Private owner testing, real-time world, independent airline ledger</span></div>'+
   '<div><strong>Atlas - World 2</strong><span>Separate economy, not open yet</span></div>'+
   '<div><strong>Odyssey - World 3</strong><span>Separate economy, not open yet</span></div></div>'+
   small('One real day equals one game day. Future worlds are not selectable until server authorization allows them.'),
   'SIMULATION STRUCTURE'),
 'airport-insights':()=>card('Understanding the airport catalog',
   '<p>Approved airports have a six-level category: Local, Regional, Medium, Large, Major Hub and Mega Hub. Check runway length, surface and route eligibility before selecting a home base.</p>'+
   '<div class="workspace-task-list"><div><strong>Runways</strong><span>Qualifying lengths and verified surfaces</span></div>'+
   '<div><strong>Traffic</strong><span>Passenger, cargo or both where the airport classification is approved</span></div>'+
   '<div><strong>Demand</strong><span>Calculated airport demand is not yet available</span></div></div>'+
   button('routes','Plan a route using approved airports'),'WORLD 1 DATA'),
 'interface':()=>card('Interface preferences',
   '<p>Change how your manager dashboard looks. Changes apply instantly on this browser.</p>'+
   field('pref-theme','Color theme',optionSelect('pref-theme',[['light','Light'],['dark','Dark']]))+
   field('pref-density','Information density',optionSelect('pref-density',[['comfortable','Comfortable'],['compact','Compact']]))+
   field('pref-motion','Animations',optionSelect('pref-motion',[['normal','Standard'],['reduced','Reduced motion']]))+
   field('pref-landing','Starting page',optionSelect('pref-landing',[
    ['overview','Dashboard'],['airline','Manage airline'],['fleet','Fleet'],['routes','Routes'],
    ['schedule','Flight schedule'],['finances','Finances']]))+
   '<div class="workspace-actions"><button class="primary" id="interface-save" type="button">Save interface</button>'+
   '<button class="secondary" type="button" id="interface-reset">Restore defaults</button></div>'+
   '<p class="hint" id="interface-status" role="status"></p>'+
   small('Default page applies to returning managers who have already created an airline. New accounts still start with airline setup.'),
   'PERSONAL DISPLAY')+
  card('Accessibility',
   '<p>Native keyboard navigation, clearly labeled form fields and the reduced-motion option are supported throughout this management interface.</p>'+
   '<p>Dark mode and compact density are local display settings. Airline activity and server records are unaffected.</p>',
   'USABILITY'),
 'notifications':()=>card('Notification preferences',
   '<p>Essential account and security emails are managed by the authentication service and cannot be disabled here.</p>'+
   '<div class="workspace-task-list">'+
   '<div><strong>Account verification and recovery</strong><span>Essential - always enabled</span></div>'+
   '<div><strong>Fleet and maintenance alerts</strong><span>Not connected</span></div>'+
   '<div><strong>Flight and route disruptions</strong><span>Not connected</span></div>'+
   '<div><strong>Finance and operations notices</strong><span>Not connected</span></div>'+
   '<div><strong>Messages from other managers</strong><span>Not connected</span></div></div>'+
   status('Game alert delivery, in-game inbox and email subscriptions require server-side notification policies. These switches will become available only when delivery filtering is implemented.'),
   'DELIVERY STATUS')+
  card('On-screen guidance',
   '<label class="workspace-checkbox"><input type="checkbox" id="pref-hints" checked> Show guidance notes on management pages</label>'+
   '<div class="workspace-actions"><button class="primary" id="notification-save" type="button">Save guidance preference</button></div>'+
   '<p id="notification-status" class="hint" role="status"></p>'+
   small('This only controls local guidance text, not email or in-game notification delivery.'),
   'LOCAL PREFERENCE'),
 'help':()=>card('First airline - start here',
   '<p>Airlinerra is a real-time multiplayer airline-management game. The right order is to register the company, secure aircraft, set routes, and create a reliable schedule.</p>'+
   '<div class="workspace-task-list">'+
   '<div><strong>1. Create your airline</strong><span>Pick World 1, your country, home airport and company identity</span></div>'+
   '<div><strong>2. Protect your opening cash</strong><span>Start with $5,000,000 and no aircraft</span></div>'+
   '<div><strong>3. Find an aircraft</strong><span>Compare range, runway, price, seats and service costs</span></div>'+
   '<div><strong>4. Build your network</strong><span>Find approved destinations and assess passenger/cargo demand</span></div>'+
   '<div><strong>5. Create a weekly timetable</strong><span>Plan routes, turnarounds and operating windows</span></div>'+
   '<div><strong>6. Operate and compete</strong><span>Monitor bookings, costs, quality and rankings as live systems launch</span></div></div>'+
   button('airline','Manage airline')+button('routes','Route workshop')+button('finances','Finance planning'),
   'GETTING STARTED')+
  card('Frequently asked questions',
   '<details class="workspace-faq"><summary>How does time work?</summary><p>One real day equals one in-game day. Each world has an independent economy.</p></details>'+
   '<details class="workspace-faq"><summary>Do I receive an aircraft when registering?</summary><p>No. Each new airline starts with exactly $5,000,000 and zero aircraft.</p></details>'+
   '<details class="workspace-faq"><summary>Are route drafts and financial scenarios real?</summary><p>No. Drafts are local planning data, not bookings, orders, or financial transactions.</p></details>'+
   '<details class="workspace-faq"><summary>What happens after the seven-day trial?</summary><p>There is no automatic charge or paid subscription. Paid membership is optional once billing is offered.</p></details>'+
   '<p class="workspace-support"><a href="/terms.html">Terms</a> <a href="/privacy.html">Privacy</a> <a href="mailto:contact@nextqueststudio.net">Contact support</a></p>',
   'HELP AND ACCOUNT')
});
const DRAFT_KEY='airlinerra.local.workplan.v1.';
const PREF_KEY='airlinerra.ui.preferences.v1.';
function safelyLoad(storage,key){
 try{const raw=storage?.getItem(key);return raw?JSON.parse(raw):null;}catch{return null;}
}
function safelySave(storage,key,val){
 try{storage?.setItem(key,JSON.stringify(val));return true;}catch{return false;}
}
export function createAirlineWorkspace({doc,identity,storage,session,goTo}={}){
 if(!doc||typeof identity!=='string'||!/^[\w-]{3,128}$/.test(identity))
  throw Error('A verified account is required for airline workspace');
 const prefKey=PREF_KEY+identity,draftKey=DRAFT_KEY+identity;
 let preferences=cleanUiPreferences(safelyLoad(storage,prefKey));
 let data={connected:false,airline:null,countries:[],worlds:[],reader:null},draft=safelyLoad(session,draftKey)||{};
 const $=id=>doc.getElementById(id);
 let marketSnapshot=null;
 let marketFetchVersion=0;
 let scheduleSnapshot=null;
 let scheduleFetchVersion=0;
 let scheduleReadError=false;
 for(const [name,render] of Object.entries(pages)){
  const el=$('workspace-'+name);if(el)el.innerHTML=render();
 }
 function applyPreferences(){
  doc.documentElement.dataset.uiTheme=preferences.theme;
  doc.documentElement.dataset.uiDensity=preferences.density;
  doc.documentElement.dataset.uiMotion=preferences.motion;
  for(const [id,key] of Object.entries({
   'settings-units':'units','settings-time':'time','settings-date':'date',
   'settings-timezone':'timezone','settings-language':'language',
   'pref-theme':'theme','pref-density':'density','pref-motion':'motion',
   'pref-landing':'landing'
  })){if($(id))$(id).value=preferences[key];}
  if($('pref-hints'))$('pref-hints').checked=preferences.hints;
  doc.documentElement.dataset.uiHints=preferences.hints?'show':'hide';
  examples();
 }
 function examples(){
  const field=(id)=>$(id)?.value;
  const units=field('settings-units')||preferences.units;
  if($('settings-distance-example'))$('settings-distance-example').textContent=units==='mi'?'746 mi':'1,200 km';
  if($('settings-clock-example'))$('settings-clock-example').textContent=field('settings-time')==='12'?'2:30 PM':'14:30';
  const dates={dmy:'29/10/2026',mdy:'10/29/2026',ymd:'2026-10-29'};
  if($('settings-date-example'))$('settings-date-example').textContent=dates[field('settings-date')]||dates.dmy;
 }
 function writePreferences(keys,statusId){
  const next={...preferences};
  for(const [id,key] of Object.entries(keys))next[key]=$(id).type==='checkbox'?$(id).checked:$(id).value;
  preferences=cleanUiPreferences(next);applyPreferences();
  $(statusId).textContent=safelySave(storage,prefKey,preferences)
   ?'Preferences saved for this account in this browser.'
   :'Preferences applied for this session. Browser storage is unavailable.';
 }
 function resetPreferences(statusId){
  preferences=cleanUiPreferences({});applyPreferences();
  $(statusId).textContent=safelySave(storage,prefKey,preferences)?'Defaults restored.':'Defaults applied for this session.';
 }
 function draftWrite(key,val){
  // Another operations panel may have changed a separate field in the same
  // account-local session draft. Refresh it before writing to avoid erasing it.
  draft={...(safelyLoad(session,draftKey)||draft),[key]:val};
  return safelySave(session,draftKey,draft);
 }
 function populateCountries(){
  for(const id of ['route-from-country','route-to-country']){
   const el=$(id);if(!el)continue;
   const previous=el.value;
   el.replaceChildren(new Option('Choose country',''));
   const names=new Intl.DisplayNames(['en'],{type:'region'});
   const sorted=data.countries.filter(c=>/^[A-Z]{2}$/.test(c.countryIso||''))
    .sort((a,b)=>names.of(a.countryIso).localeCompare(names.of(b.countryIso),'en'));
   for(const c of sorted)el.add(new Option(names.of(c.countryIso)+' ('+c.airportCount+')',c.countryIso));
   if([...el.options].some(o=>o.value===previous))el.value=previous;
  }
 }
 async function findAirport(side){
  const select=$('route-'+side+'-airport'),country=$('route-'+side+'-country').value;
  const query=$('route-'+side+'-search').value.trim(),feedback=$('route-feedback');
  select.replaceChildren(new Option('Search first',''));select.disabled=true;
  if(!/^[A-Z]{2}$/.test(country)){feedback.textContent='Choose a country first.';return;}
  if(!data.reader){feedback.textContent='Approved airport search is temporarily unavailable.';return;}
  feedback.textContent='Searching approved airports...';
  try{
   const response=await data.reader.airports({countryIso:country,search:query,offset:0});
   if(!Array.isArray(response.airports)||response.countryIso!==country)throw Error('Invalid airport response');
   const list=response.airports;
   select.replaceChildren(new Option('Select airport',''));
   for(const a of list){
    if(typeof a.key==='string'&&typeof a.name==='string'){
     const option=new Option(a.name+' ('+(a.code||'-')+')',a.key);
     option.dataset.code=a.code||'';
     option.dataset.airportName=a.name;
     select.append(option);
    }
   }
   select.disabled=list.length===0;
   feedback.textContent=list.length?'Select an airport from the results. Refine the search to see more.':'No matching airports.';
  }catch{feedback.textContent='Airport lookup failed. Check your connection and retry.';}
 }
 function selected(side){
  const item=$('route-'+side+'-airport');
  const opt=item?.selectedOptions?.[0];
  if(!item||item.disabled||!item.value||!opt)return null;
  return {key:item.value,name:opt.dataset.airportName,code:opt.dataset.code,
   countryIso:$('route-'+side+'-country').value};
 }
 function showRoute(){
  const el=$('route-draft-review');if(!el)return;
  el.replaceChildren();
  if(!draft.route?.from||!draft.route?.to)return;
  const title=doc.createElement('strong');title.textContent='Saved route idea';
  const line=doc.createElement('p');
  line.textContent=draft.route.from.name+' ('+draft.route.from.code+') - '+
   draft.route.to.name+' ('+draft.route.to.code+') - '+draft.route.flights+' departures/week';
  el.append(title,line);
 }
 function renderSchedule(){
  const host=$('schedule-aircraft-board');
  if(!host)return;
  const last=safelyLoad(session,draftKey)||{};
  const local=Array.isArray(last.routes)?last.routes:last.route?[last.route]:[];
  const board=buildAirlineWeeklyBoard({
   // Fleet-market inventory includes all real owned/leased aircraft, even
   // those not yet in service. A schedule-only read includes in-service ones.
   fleet:marketSnapshot?.fleet,serverFleet:scheduleSnapshot?.fleet,
   plans:scheduleSnapshot?.plans,drafts:scheduleSnapshot?.drafts,
   localRoutes:local
  });
  renderAirlineWeeklyBoard(doc,host,board);
  const status=$('schedule-status');
  if(status){
   status.textContent=board.status==='unavailable'?
    'Verified aircraft data is not available. Cannot determine airline timetable.':
    board.status==='empty'?
    'No real owned or leased aircraft were returned for this airline.':
    String(board.rows.length)+' company aircraft · '+String(board.counts.flights)+
    ' planned departures/week · '+String(board.counts.held)+
    ' departures with verified airport-slot flight windows.'+
    (scheduleReadError?' Some server routes could not be loaded; this timetable is incomplete.':'');
  }
 }
 async function loadAirlineSchedule(){
  const ticket=++scheduleFetchVersion;
  const airlineId=data.airline?.id,scheduler=data.scheduler;
  scheduleSnapshot=null;scheduleReadError=false;
  renderSchedule();
  if(!data.connected||!airlineId||typeof scheduler?.list!=='function'){
   scheduleReadError=true;renderSchedule();return;
  }
  try{
   const result=await scheduler.list(airlineId);
   if(ticket!==scheduleFetchVersion||data.airline?.id!==airlineId)return;
   if(!Array.isArray(result?.fleet)||!Array.isArray(result?.plans)||
      !Array.isArray(result?.drafts))throw Error('Invalid schedule response');
   scheduleSnapshot=result;scheduleReadError=false;renderSchedule();
  }catch{
   if(ticket!==scheduleFetchVersion)return;
   scheduleSnapshot=null;scheduleReadError=true;renderSchedule();
  }
 }
 function loadDraftForms(){
  for(const [field,key] of [['fleet-family','family'],['fleet-seats','seats'],['fleet-range','range'],['fleet-acquisition','acquisition']]){
   if($(field)&&draft.fleet?.[key]!==undefined)$(field).value=draft.fleet[key];
  }
  for(const key of ['economy','premium','business','first','service']){
   if($('cabin-'+key)&&draft.cabin?.[key]!==undefined)$('cabin-'+key).value=draft.cabin[key];
  }
  for(const key of ['revenue','leases','crew','fuel','maintenance','airportFees','services','marketing']){
   if($('budget-'+key)&&draft.budget?.[key]!==undefined)$('budget-'+key).value=draft.budget[key];
  }
  showRoute();renderSchedule();
 }
 function renderRealFleetMarket(snapshot){
  marketSnapshot=snapshot;
  renderSchedule();
  const fleet=Array.isArray(snapshot?.fleet)?snapshot.fleet:[];
  const offers=Array.isArray(snapshot?.offers)?snapshot.offers:[];
  const owned=fleet.filter(x=>x?.ownershipType==='owned');
  const leased=fleet.filter(x=>x?.ownershipType==='leased');
  // A failed read is UNKNOWN, never a verified count of zero aircraft.
  if($('fleet-owned-count'))$('fleet-owned-count').textContent=snapshot?String(owned.length):'—';
  if($('fleet-leased-count'))$('fleet-leased-count').textContent=snapshot?String(leased.length):'—';
  if($('fleet-real-status'))$('fleet-real-status').textContent=snapshot?
   (fleet.length?String(fleet.length)+' registered':'No aircraft'):'Not connected';
  const fleetList=$('fleet-owned-aircraft');
  if(fleetList){
   fleetList.replaceChildren();
   if(!fleet.length){
    const msg=doc.createElement('p');
    msg.textContent=snapshot?'No purchased or leased aircraft in your airline fleet.':'Fleet data unavailable.';
    fleetList.append(msg);
   }
   for(const aircraft of fleet){
    const row=doc.createElement('div');row.className='fleet-test-aircraft-row';
    const title=doc.createElement('strong');
    title.textContent=aircraftDisplayName(aircraft.manufacturer,aircraft.model)||'Aircraft';
    const registration=doc.createElement('span');
    registration.textContent=String(aircraft.registration||'—')+' · '+
      String(aircraft.ownershipType||'fleet')+' · '+String(aircraft.fleetStatus||'unknown');
    const note=doc.createElement('small');
    note.textContent=aircraft.deliveryStatus==='awaiting_delivery'
     ?'Delivery pending · not available for flight scheduling'
     :aircraft.deliveryStatus==='delivered_pending_inspection'
      ?'Delivered · inspection required before service'
      :aircraft.fleetStatus==='in_service'
       ?'In-service aircraft; actual flight activation still disabled'
       :'Not available for operational flight activation';
    row.append(title,registration,note);
    if(aircraft.orderId&&aircraft.deliveryStatus==='awaiting_delivery'){
     const check=doc.createElement('button');check.type='button';
     check.className='secondary';check.dataset.aircraftDelivery=aircraft.orderId;
     check.textContent='Check delivery';row.append(check);
    }
    fleetList.append(row);
   }
  }
  const marketState=$('market-state'),offerList=$('market-offers'),select=$('market-offer-select');
  if(offerList){
   offerList.replaceChildren();
   for(const offer of offers){
    const row=doc.createElement('div');row.className='fleet-test-aircraft-row';
    const name=doc.createElement('strong');
    name.textContent=aircraftDisplayName(offer.manufacturer,offer.model)+' · '+
      String(offer.transactionType||'order');
    const price=doc.createElement('span');
    price.textContent='Upfront '+currency(offer.upfrontPriceUsd)+
      (offer.transactionType==='lease'
       ?' · '+currency(offer.recurringMonthlyUsd)+'/month × '+String(offer.contractMonths)+' months'
       :'')+' · delivery '+String(offer.deliveryDays||0)+' days';
    row.append(name,price);offerList.append(row);
   }
  }
  if(select){
   const prior=select.value;
   select.replaceChildren(new Option(offers.length?'Choose an aircraft offer':'No published offers',''));
   for(const offer of offers){
    const label=aircraftDisplayName(offer.manufacturer,offer.model)+
      ' · '+String(offer.transactionType)+' · '+currency(offer.upfrontPriceUsd)+' upfront';
    select.append(new Option(label,String(offer.offerId||'')));
   }
   if(offers.some(x=>x.offerId===prior))select.value=prior;
   select.disabled=offers.length===0;
  }
  if($('market-acquire'))$('market-acquire').disabled=offers.length===0;
  if(marketState)marketState.textContent=!snapshot?'Fleet market unavailable. Retry when connected.':
    offers.length?String(offers.length)+' published offer(s) · in-game funds only':
    'No aircraft offers are published yet. Game-market prices must be approved first.';
 }
 async function loadRealFleetMarket(){
  const version=++marketFetchVersion;
  const client=data.fleetClient,airlineId=data.airline?.id;
  if(!data.connected||!airlineId||!client||typeof client.list!=='function'){
   renderRealFleetMarket(null);return;
  }
  try{
   const result=await client.list(airlineId);
   if(version!==marketFetchVersion||data.airline?.id!==airlineId)return;
   if(!result||!Array.isArray(result.fleet)||!Array.isArray(result.offers)||
     result.airlineId!==airlineId)throw Error('Invalid fleet list');
   renderRealFleetMarket(result);
  }catch(error){
   if(version!==marketFetchVersion)return;
   renderRealFleetMarket(null);
   // Expose only a safe status code; never tokens, SQL details or identities.
   const diagnostic=String(error?.message||'');
   const code=/^(?:LOCAL_AIRCRAFT_READ_HTTP_|FLEET_HTTP_)([1-5][0-9]{2})$/.exec(diagnostic)?.[1]||null;
   const status=code?'HTTP '+code:'Connection unavailable';
   if($('fleet-real-status'))$('fleet-real-status').textContent=status;
   const holder=$('fleet-owned-aircraft');
   if(holder)holder.textContent='Real company fleet could not be loaded ('+status+
    '). Your aircraft ownership has not been changed. Check the local API connection.';
   console.warn('Airlinerra fleet read',status);
  }
 }
 function updateData(next={}){
  data={...data,...next};
  const airline=data.airline;
  const connected=data.connected===true;
  const unknown='Game data not loaded';
  const home=airline?.homeAirportName?
   airline.homeAirportName+(airline.homeAirportCode?' ('+airline.homeAirportCode+')':''):
   (airline?.homeAirportKey||'-');
  const values={
   'office-airline':connected?(airline?.name||'Not created'):unknown,
   'office-icao':connected?(airline?.icaoCode||'Not assigned'):unknown,
   'office-iata':connected?(airline?.iataCode||'Not assigned'):unknown,
   'office-world':connected?(airline?.worldId?(data.worlds.find(w=>Number(w.id)===Number(airline.worldId))?.name||'World '+airline.worldId):'Not selected'):unknown,
   'office-home':connected?home:unknown,'office-cash':connected&&airline?.cashUsd!==undefined?currency(airline.cashUsd):'-',
   'office-premium':connected?(airline?.premiumUnlimited===true?'Premium Unlimited':airline?'Registered account':'Not registered'):unknown,
   'finance-live-cash':connected&&airline?.cashUsd!==undefined?currency(airline.cashUsd):'-'
  };
  for(const [id,value] of Object.entries(values)){if($(id))$(id).textContent=value;}
  const testAircraft=connected&&Array.isArray(airline?.testAircraft)?
   airline.testAircraft.filter(a=>a?.testOnly===true&&a.operationallyAllowed===false):[];
  if($('fleet-test-count'))$('fleet-test-count').textContent=String(testAircraft.length);
  const timelinePanel=$('fleet-aircraft-timeline');
  if(timelinePanel)timelinePanel.hidden=true;
  const holder=$('fleet-test-aircraft');
  if(holder){
   holder.replaceChildren();
   for(const aircraft of testAircraft){
    const row=doc.createElement('div');row.className='fleet-test-aircraft-row';
    const title=doc.createElement('strong');
    title.textContent='Airbus '+String(aircraft.model||'Aircraft');
    const registration=doc.createElement('span');
    registration.textContent=String(aircraft.registration||'TEST');
    const state=doc.createElement('small');
    state.textContent='Simulation only · not owned · cannot operate flights';
    const openTimeline=doc.createElement('button');
    openTimeline.type='button';openTimeline.className='fleet-aircraft-timeline-link';
    openTimeline.dataset.fleetAircraftTimeline=String(aircraft.id);
    openTimeline.textContent='Schedule timeline';
    row.append(title,registration,state,openTimeline);holder.append(row);
   }
  }
  routePlannerController.updateData(data);
  void loadRealFleetMarket();
  void loadAirlineSchedule();
 }
 doc.getElementById('player-main')?.addEventListener('click',async event=>{
  const timelineLink=event.target.closest('[data-fleet-aircraft-timeline]');
  if(timelineLink){
   const aircraftId=timelineLink.dataset.fleetAircraftTimeline;
   const allowed=Array.isArray(data.airline?.testAircraft)&&data.airline.testAircraft.some(
    a=>a?.id===aircraftId&&a.testOnly===true&&a.operationallyAllowed===false);
   const holder=$('fleet-aircraft-timeline'),heading=$('fleet-aircraft-timeline-heading');
   if(!allowed||!holder)return;
   const newest=safelyLoad(session,draftKey)||{};
   const routes=Array.isArray(newest.routes)?newest.routes:[];
   const timeline=buildAircraftWeeklyTimeline({aircraftId,routes,
    homeAirportKey:data.airline?.homeAirportKey||null});
   const record=data.airline.testAircraft.find(a=>a.id===aircraftId);
   if(heading)heading.textContent='Airbus '+String(record.model)+' · '+String(record.registration)+' — weekly timeline';
   renderAircraftWeeklyTimeline(doc,$('fleet-aircraft-timeline-content'),timeline);
   holder.hidden=false;
   return;
  }
  const deliveryButton=event.target.closest('[data-aircraft-delivery]');
  if(deliveryButton){
   const orderId=deliveryButton.dataset.aircraftDelivery;
   const airlineId=data.airline?.id;
   const notice=$('fleet-delivery-feedback');
   if(!marketSnapshot?.fleet?.some(x=>x.orderId===orderId &&
       x.deliveryStatus==='awaiting_delivery')||!data.fleetClient?.checkDelivery||!airlineId){
    if(notice)notice.textContent='This order is not available for delivery checking.';
    return;
   }
   deliveryButton.disabled=true;
   if(notice)notice.textContent='Checking game delivery status...';
   try{
    const result=await data.fleetClient.checkDelivery({airlineId,orderId});
    if(result?.deliveryStatus==='delivered_pending_inspection'){
     if(notice)notice.textContent='Aircraft delivered. Inspection is required before it can be scheduled.';
    }else if(result?.deliveryStatus==='awaiting_delivery'){
     if(notice)notice.textContent='Aircraft is awaiting delivery. Expected date: '+
       new Date(result.deliveryDueAt).toLocaleDateString('en-US')+'.';
    }else{
     if(notice)notice.textContent='Delivery status: '+String(result?.deliveryStatus||'unknown')+'.';
    }
    await loadRealFleetMarket();
   }catch{
    if(notice)notice.textContent='Could not confirm delivery status. Try again.';
   }finally{deliveryButton.disabled=false;}
   return;
  }
  const nav=event.target.closest('[data-workspace-go]');
  if(nav){const to=nav.dataset.workspaceGo;if(AIRLINE_UI_VIEWS.includes(to)&&typeof goTo==='function')goTo(to);
   if(to==='fleet'||to==='aircraft-market')void loadRealFleetMarket();return;}
  const id=event.target.closest('button')?.id;
  if(!id)return;
  const general={'settings-units':'units','settings-time':'time','settings-date':'date',
   'settings-timezone':'timezone','settings-language':'language'};
  const interfaceKeys={'pref-theme':'theme','pref-density':'density','pref-motion':'motion','pref-landing':'landing'};
  if(id==='settings-save')writePreferences(general,'settings-feedback');
  if(id==='settings-reset')resetPreferences('settings-feedback');
  if(id==='interface-save')writePreferences(interfaceKeys,'interface-status');
  if(id==='interface-reset')resetPreferences('interface-status');
  if(id==='notification-save')writePreferences({'pref-hints':'hints'},'notification-status');
  if(id==='route-from-find')await findAirport('from');
  if(id==='route-to-find')await findAirport('to');
  if(id==='route-save'){
   const idea={from:selected('from'),to:selected('to'),flights:Number($('route-flights').value)};
   if(!validateRouteIdea(idea)){$('route-feedback').textContent='Choose two different approved airports and 1-28 departures per week.';return;}
   const freshest=safelyLoad(session,draftKey)||draft;
   const saved=Array.isArray(freshest.routes)?freshest.routes:[];
   if(saved.length>=25){$('route-feedback').textContent='Route draft limit is 25. Remove old drafts in My routes.';return;}
   const next=[...saved.filter(route=>route?.from?.key!==idea.from.key||route?.to?.key!==idea.to.key),idea];
   draftWrite('route',idea);draftWrite('routes',next);
   showRoute();
   doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved'));
   $('route-feedback').textContent='Route draft saved in this browser tab under My routes. No live route was created.';
  }
  if(id==='market-acquire'){
   const select=$('market-offer-select'),entry=$('market-aircraft-registration');
   const feedback=$('market-feedback'),button=$('market-acquire');
   const offer=marketSnapshot?.offers?.find(item=>item.offerId===select?.value);
   const registration=String(entry?.value||'').trim().toUpperCase();
   if(!offer||!data.airline?.id||!data.fleetClient){
    feedback.textContent='Choose a published aircraft offer first.';return;
   }
   if(!/^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$/.test(registration)){
    feedback.textContent='Use a 4–20 character registration with letters, digits or hyphens.';return;
   }
   button.disabled=true;feedback.textContent='Checking offer and confirming the order with the server...';
   try{
    const result=await data.fleetClient.acquire({
      airlineId:data.airline.id,offerId:offer.offerId,registration
    });
    if(result?.deliveryStatus!=='awaiting_delivery'||!result.aircraftInventoryId)
     throw Error('Invalid acquisition response');
    feedback.textContent='Aircraft '+registration+
      (result.replayed?' already ordered.':' ordered successfully.')+
      ' Upfront cost '+currency(result.paidUpfrontUsd)+
      '. Stored until delivery and inspection; no flight activated.';
    if(entry)entry.value='';
    await loadRealFleetMarket();
    doc.dispatchEvent(new CustomEvent('airlinerra:fleet-updated'));
   }catch(error){
    const reason=String(error?.message||'');
    feedback.textContent=reason.includes('INSUFFICIENT_AIRLINE_CASH')?
      'Not enough airline cash to purchase or lease this aircraft.':
      reason.includes('AIRCRAFT_REGISTRATION_ALREADY_TAKEN')?
      'That aircraft registration is already in use.':
      reason.includes('AIRCRAFT_OFFER_NOT_AVAILABLE')?
      'This offer is no longer available. Refresh the market.':
      'The order was not confirmed. Check the offer and try again.';
   }finally{button.disabled=!(marketSnapshot?.offers?.length>0);}
   return;
  }
  if(id==='fleet-plan-save'){
   const fleet={family:$('fleet-family').value,seats:Number($('fleet-seats').value),
    range:Number($('fleet-range').value),acquisition:$('fleet-acquisition').value};
   if(!Number.isInteger(fleet.seats)||fleet.seats<0||fleet.seats>1000||
     !Number.isFinite(fleet.range)||fleet.range<0||fleet.range>30000){
     $('fleet-plan-status').textContent='Enter valid seat and range requirements.';return;
   }
   draftWrite('fleet',fleet);
   $('fleet-plan-status').textContent='Fleet brief saved locally. No aircraft was ordered.';
  }
  if(id==='cabin-save'){
   const cabin={service:$('cabin-service').value};let valid=true,total=0;
   for(const key of ['economy','premium','business','first']){
    const n=Number($('cabin-'+key).value);if(!Number.isInteger(n)||n<0||n>1000)valid=false;
    cabin[key]=n;total+=n;
   }
   if(!valid||total>1000){$('cabin-feedback').textContent='Enter a valid seat count for every class (up to 1,000 seats total).';return;}
   draftWrite('cabin',cabin);
   $('cabin-feedback').textContent='Cabin brief saved locally: '+total+' planned seats. No aircraft layout was changed.';
  }
  if(id==='budget-calc'){
   const budget={};for(const key of ['revenue','leases','crew','fuel','maintenance','airportFees','services','marketing']){
    budget[key]=Number($('budget-'+key).value);
    if(!Number.isFinite(budget[key])||budget[key]<0||budget[key]>10000000000){
     $('budget-result').textContent='Enter non-negative monthly amounts for every field.';return;
    }
   }
   draftWrite('budget',budget);
   const scenario=financialScenario({...budget,cash:Number(data.airline?.cashUsd||0)});
   const months=scenario.months===null?'Not decreasing with these assumptions':
    Number.isFinite(scenario.months)?scenario.months.toFixed(1)+' months':'Not available';
   $('budget-result').textContent='Monthly income: '+currency(scenario.income)+
    ' | Monthly expenses: '+currency(scenario.expenses)+' | Net: '+currency(scenario.net)+
    ' | Estimated cash runway: '+months+'. Scenario only - no server changes.';
  }
  if(id==='schedule-refresh'){
   $('schedule-status').textContent='Refreshing company fleet and airline routes…';
   void loadRealFleetMarket();
   void loadAirlineSchedule();
  }
 });
 for(const id of ['settings-time','settings-date','settings-units'])
  $(id)?.addEventListener('change',examples);
 const routePlannerController=createRoutePlanner({
  doc,getData:()=>data,loadDraft:()=>safelyLoad(session,draftKey)||{},draftWrite
 });
 doc.addEventListener('airlinerra:route-draft-saved',()=>{
  renderSchedule();
  void loadAirlineSchedule();
 });
 applyPreferences();loadDraftForms();
 return Object.freeze({updateData,getLandingView:()=>preferences.landing,formatDistance:km=>
  preferences.units==='mi'?(Number(km)*0.621371).toFixed(0)+' mi':Number(km).toFixed(0)+' km'});
}
