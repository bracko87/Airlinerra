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
 'overview','airline','fleet','routes','schedule','finances','worlds',
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
 'overview':()=>card('Your airline command center',
  '<p>Run your company through connected work areas: manage aircraft, evaluate routes, build a weekly timetable and monitor finances.</p>'+
  navigation()+
  '<div class="workspace-steps"><div><b>01</b><strong>Airline identity</strong><span>Company and home base</span></div>'+
  '<div><b>02</b><strong>Aircraft</strong><span>Fleet and acquisition</span></div>'+
  '<div><b>03</b><strong>Routes</strong><span>Airport and network planning</span></div>'+
  '<div><b>04</b><strong>Schedule</strong><span>7-day rotations and execution</span></div></div>'+
  small('Only the account, company, cash and airport catalog are connected to the game server today. Planning work is not submitted as live operations.'),
  'MANAGEMENT OVERVIEW'),
 'airline':()=>card('Company identity',
  '<div class="detail-row"><span>Airline</span><strong id="office-airline">Not created</strong></div>'+
  '<div class="detail-row"><span>World</span><strong id="office-world">-</strong></div>'+
  '<div class="detail-row"><span>Home airport</span><strong id="office-home">-</strong></div>'+
  '<div class="detail-row"><span>Available cash</span><strong id="office-cash">-</strong></div>'+
  '<div class="detail-row"><span>Membership</span><strong id="office-premium">-</strong></div>'+
  small('Company identity is read from the verified World 1 database; names, airports and finances are not editable here.')+
  button('profile','Open manager profile'),'YOUR AIRLINE')+
  card('Build your company',
  '<div class="workspace-task-list">'+
  '<div><strong>Network</strong><span>Pick a destination and estimate a draft route</span></div>'+
  '<div><strong>Fleet</strong><span>Review acquisition options and aircraft requirements</span></div>'+
  '<div><strong>Customer product</strong><span>Plan cabin mix and service levels</span></div>'+
  '<div><strong>Operations</strong><span>Build a 7-day planning timetable</span></div></div>'+
  button('routes','Plan a route')+button('service','Cabin and cargo'),
  'STRATEGY'),
 'fleet':()=>card('Fleet inventory',
   '<div class="workspace-kpis"><div><span>Owned aircraft</span><strong>Not connected</strong></div>'+
   '<div><span>Leased aircraft</span><strong>Not connected</strong></div>'+
   '<div><span>Available seats</span><strong>Not connected</strong></div></div>'+
   status('No authenticated aircraft-inventory endpoint is available yet. This page does not claim you own, lease or operate aircraft.')+
   button('aircraft-market','Explore acquisition')+button('maintenance','Maintenance planning'),
   'AIRCRAFT INVENTORY')+
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
   '<p>Airlinerra will distinguish aircraft models and variants from individual new and used airframes, with real condition, price, range, seat and maintenance data.</p>'+
   '<div class="workspace-task-list">'+
   '<div><strong>Model and variants</strong><span>Manufacturer, range, cabin and airport suitability</span></div>'+
   '<div><strong>New aircraft</strong><span>Production status, lead time and purchase options</span></div>'+
   '<div><strong>Used aircraft</strong><span>Age, cycles, hours, condition and seller details</span></div>'+
   '<div><strong>Lease proposals</strong><span>Monthly price, contract length and deposits</span></div></div>'+
   status('Live aircraft offers, leasing contracts and checkout are not connected. No fictional market listings or prices are shown.')+
   button('fleet','Open fleet requirements'),'BUY AND LEASE')+
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
 'routes':()=>card('Route workshop',
   '<p>Select approved airports from the actual World 1 directory to prepare a route idea. This does not create a commercial route, calculate passenger demand or reserve slots.</p>'+
   '<div class="workspace-route-form">'+
   '<fieldset><legend>Departure</legend>'+
   field('route-from-country','Country','<select id="route-from-country"><option value="">Choose country</option></select>')+
   field('route-from-search','Airport name or code','<input id="route-from-search" maxlength="40" placeholder="Search approved airports">')+
   '<button type="button" id="route-from-find" class="secondary">Find departures</button>'+
   field('route-from-airport','Airport','<select id="route-from-airport" disabled><option value="">Search first</option></select>')+'</fieldset>'+
   '<fieldset><legend>Destination</legend>'+
   field('route-to-country','Country','<select id="route-to-country"><option value="">Choose country</option></select>')+
   field('route-to-search','Airport name or code','<input id="route-to-search" maxlength="40" placeholder="Search approved airports">')+
   '<button type="button" id="route-to-find" class="secondary">Find destinations</button>'+
   field('route-to-airport','Airport','<select id="route-to-airport" disabled><option value="">Search first</option></select>')+'</fieldset></div>'+
   field('route-flights','Proposed departures per week','<input id="route-flights" type="number" min="1" max="28" value="7">')+
   '<div class="workspace-actions"><button type="button" class="primary" id="route-save">Save route draft</button>'+button('schedule','Open weekly timetable')+'</div>'+
   '<p id="route-feedback" class="hint" role="status"></p>'+
   '<div id="route-draft-review" class="workspace-detail"></div>',
   'APPROVED AIRPORTS')+
  card('Before opening a route',
   '<div class="workspace-task-list">'+
   '<div><strong>Demand</strong><span>Passenger and cargo forecasts are not yet calculated</span></div>'+
   '<div><strong>Aircraft</strong><span>Check range, payload, seats and runway access</span></div>'+
   '<div><strong>Slots</strong><span>Departure/arrival windows and turnaround capacity</span></div>'+
   '<div><strong>Economics</strong><span>Estimate fares, operating cost and break-even load</span></div></div>',
   'NETWORK REQUIREMENTS'),
 'schedule':()=>card('Seven-day flight planner',
   '<p>Plan a draft flight in a 24-hour weekly grid. All times are planning labels, not reserved slots or executed flights.</p>'+
   '<div class="workspace-schedule-controls">'+
   field('schedule-day','Day',optionSelect('schedule-day',[
    ['0','Monday'],['1','Tuesday'],['2','Wednesday'],['3','Thursday'],
    ['4','Friday'],['5','Saturday'],['6','Sunday']]))+
   field('schedule-time','Departure time','<input id="schedule-time" type="time" value="09:00">')+
   field('schedule-flight','Flight number (draft)','<input id="schedule-flight" maxlength="12" placeholder="e.g. PN101">')+
   '<button type="button" class="primary" id="schedule-add">Add draft departure</button>'+
   '<button type="button" class="secondary" id="schedule-clear">Clear draft timetable</button></div>'+
   '<p id="schedule-status" role="status" class="hint"></p>'+
   '<div class="workspace-table-scroll"><table class="workspace-week"><thead><tr><th>Hour</th>'+
   ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map(d=>'<th>'+d+'</th>').join('')+
   '</tr></thead><tbody id="schedule-hours"></tbody></table></div>'+
   small('The draft schedule is stored only in this browser tab. A real flight requires a live route, owned or leased aircraft, crew and available airport slots.'),
   '7 DAYS X 24 HOURS'),
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
   '<div><strong>World 1 - Founding World</strong><span>Private owner testing, real-time world, independent airline ledger</span></div>'+
   '<div><strong>World 2</strong><span>Separate economy, not open yet</span></div>'+
   '<div><strong>World 3</strong><span>Separate economy, not open yet</span></div></div>'+
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
    ['overview','Dashboard'],['airline','My airline'],['fleet','Fleet'],['routes','Routes'],
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
   button('airline','My airline')+button('routes','Route workshop')+button('finances','Finance planning'),
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
  draft={...draft,[key]:val};
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
  const tbody=$('schedule-hours');if(!tbody)return;
  tbody.replaceChildren();
  for(let hour=0;hour<24;hour++){
   const row=doc.createElement('tr'),label=doc.createElement('th');
   label.scope='row';label.textContent=String(hour).padStart(2,'0')+':00';
   row.append(label);
   for(let day=0;day<7;day++){
    const cell=doc.createElement('td');
    const flights=(draft.schedule||[]).filter(f=>f.day===day&&Number(f.time.slice(0,2))===hour);
    for(const flight of flights){
     const badge=doc.createElement('span');badge.className='workspace-flight-draft';
     badge.textContent=flight.time+' '+flight.number;cell.append(badge);
    }
    if(!flights.length){const empty=doc.createElement('span');empty.className='workspace-time-open';empty.textContent='-';cell.append(empty);}
    row.append(cell);
   }
   tbody.append(row);
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
   'office-world':connected?(airline?.worldId?'World '+airline.worldId:'Not selected'):unknown,
   'office-home':connected?home:unknown,'office-cash':connected&&airline?.cashUsd!==undefined?currency(airline.cashUsd):'-',
   'office-premium':connected?(airline?.premiumUnlimited===true?'Premium Unlimited':airline?'Registered account':'Not registered'):unknown,
   'finance-live-cash':connected&&airline?.cashUsd!==undefined?currency(airline.cashUsd):'-'
  };
  for(const [id,value] of Object.entries(values)){if($(id))$(id).textContent=value;}
  populateCountries();
 }
 doc.getElementById('player-main')?.addEventListener('click',async event=>{
  const nav=event.target.closest('[data-workspace-go]');
  if(nav){const to=nav.dataset.workspaceGo;if(AIRLINE_UI_VIEWS.includes(to)&&typeof goTo==='function')goTo(to);return;}
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
   draftWrite('route',idea);showRoute();
   $('route-feedback').textContent='Route draft saved in this browser tab. No live route was created.';
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
  if(id==='schedule-add'){
   const day=Number($('schedule-day').value),time=$('schedule-time').value.trim();
   const number=$('schedule-flight').value.trim().toUpperCase();
   if(!Number.isInteger(day)||day<0||day>6||!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time)||
     !/^[A-Z0-9-]{2,12}$/.test(number)){
     $('schedule-status').textContent='Select a day, valid departure time and 2-12 character flight number.';return;
   }
   const schedule=Array.isArray(draft.schedule)?draft.schedule:[];
   if(schedule.length>=100){$('schedule-status').textContent='Local draft limit is 100 departures.';return;}
   if(schedule.some(f=>f.day===day&&f.time===time&&f.number===number)){
    $('schedule-status').textContent='That draft departure is already included.';return;
   }
   draftWrite('schedule',[...schedule,{day,time,number}]);renderSchedule();
   $('schedule-status').textContent='Draft departure added. No flight was scheduled with the server.';
  }
  if(id==='schedule-clear'){
   draftWrite('schedule',[]);renderSchedule();
   $('schedule-status').textContent='Local draft timetable cleared.';
  }
 });
 for(const id of ['settings-time','settings-date','settings-units'])
  $(id)?.addEventListener('change',examples);
 applyPreferences();loadDraftForms();
 return Object.freeze({updateData,getLandingView:()=>preferences.landing,formatDistance:km=>
  preferences.units==='mi'?(Number(km)*0.621371).toFixed(0)+' mi':Number(km).toFixed(0)+' km'});
}
