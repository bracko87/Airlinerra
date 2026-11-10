import {routePlannerMarkup,createRoutePlanner} from './route-planner.mjs';
import {estimateFivePhaseFuel} from './flight-fuel-phase-engine.mjs';
import {aircraftDisplayName} from './aircraft-library.mjs';
import {buildAirlineWeeklyBoard,renderAirlineWeeklyBoard} from './aircraft-weekly-schedule-board.mjs';
import {createCabinServiceManager} from './cabin-services-manager.mjs';
import {createCabinConfigurationManager} from './cabin-configuration-manager.mjs';
import {createAircraftConfigurationDialog} from './aircraft-configuration-dialog.mjs';
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
 'overview','airline','fleet','fleet-aircraft','routes','route-details','schedule','finances','worlds',
 'airports','staff','rankings','service','cabin-configurations','aircraft-new-orders','aircraft-market','maintenance',
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
  'fleet':()=>card('Fleet inventory',"<div class=\"workspace-kpis fleet-summary-kpis\">\n<div><span>Owned aircraft</span><strong id=\"fleet-owned-count\">—</strong></div>\n<div><span>Leased aircraft</span><strong id=\"fleet-leased-count\">—</strong></div>\n<div><span>Fleet status</span><strong id=\"fleet-real-status\">Not loaded</strong></div></div>\n<div class=\"fleet-table-scroll\">\n<div class=\"fleet-inventory-table\" role=\"table\" aria-label=\"Owned and leased aircraft\">\n<div class=\"fleet-inventory-row fleet-inventory-head\" role=\"row\"><span role=\"columnheader\">Aircraft / registration</span><span role=\"columnheader\">Passenger seats</span><span role=\"columnheader\">Configuration</span><span role=\"columnheader\">Cargo</span><span role=\"columnheader\">Current location</span><span role=\"columnheader\">Status</span><span role=\"columnheader\">View</span></div>\n<div id=\"fleet-owned-aircraft\" class=\"fleet-inventory-body\" role=\"rowgroup\" aria-live=\"polite\">Loading verified fleet...</div>\n</div></div><p id=\"fleet-delivery-feedback\" class=\"hint\" role=\"status\" aria-live=\"polite\"></p>\n<div class=\"fleet-toolbar\"><button type=\"button\" class=\"secondary\" data-workspace-go=\"aircraft-market\">View market offers</button><button type=\"button\" class=\"secondary\" data-workspace-go=\"maintenance\">Maintenance planning</button></div>",'AIRCRAFT FLEET'),
 'fleet-aircraft':()=>card('Aircraft details',`<div class="fleet-detail-back"><button type="button" class="secondary" data-workspace-go="fleet">← Back to my fleet</button>
<button type="button" class="secondary" data-workspace-go="cabin-configurations">Edit cabin configuration</button></div>
<div class="fleet-aircraft-profile-top">
  <div class="fleet-aircraft-identity-panel">
    <h3 id="fleet-detail-name">Select an aircraft</h3>
    <p id="fleet-detail-subtitle" class="hint"></p>
    <section class="fleet-detail-section"><h4>Registration and status</h4><div class="fleet-detail-grid"><div class="fleet-detail-row"><span>Aircraft registration</span><strong id="fleet-detail-registration">—</strong></div>
<div class="fleet-detail-row"><span>Ownership</span><strong id="fleet-detail-ownership">—</strong></div>
<div class="fleet-detail-row"><span>Configuration</span><div class="fleet-configuration-value"><strong id="fleet-detail-configuration">—</strong><button id="fleet-configuration-change" type="button" class="secondary fleet-configuration-change-button" disabled>Change configuration</button></div></div>
<div class="fleet-detail-row"><span>Current verified location</span><strong id="fleet-detail-location">—</strong></div>
</div></section>
    <div class="fleet-nickname-editor">
      <label class="workspace-label" for="fleet-detail-nickname">Aircraft nickname (optional)</label>
      <div class="fleet-nickname-controls">
        <input id="fleet-detail-nickname" type="text" maxlength="40" autocomplete="off" placeholder="Give this aircraft a nickname">
        <button id="fleet-detail-save" type="button" class="primary">Save nickname</button>
      </div>
      <p class="hint">Nickname and image belong only to this aircraft. Its official model and registration do not change.</p>
      <p id="fleet-detail-feedback" class="hint" role="status" aria-live="polite"></p>
    </div>
  </div>
  <section class="fleet-aircraft-image-panel" aria-label="Aircraft photo or livery">
    <div class="fleet-aircraft-image-frame">
      <img id="fleet-aircraft-image" alt="Current aircraft photo or custom livery" hidden>
      <p id="fleet-aircraft-image-empty" class="hint">Aircraft image unavailable</p>
    </div>
    <div class="fleet-aircraft-image-actions">
      <label class="workspace-label" for="fleet-aircraft-image-file">Aircraft picture or livery (only this airplane)</label>
      <input id="fleet-aircraft-image-file" type="file" accept="image/png,image/jpeg,image/webp" aria-describedby="fleet-aircraft-image-help">
      <div class="fleet-aircraft-image-buttons">
        <button id="fleet-aircraft-image-save" type="button" class="primary" disabled>Save this aircraft image</button>
        <button id="fleet-aircraft-image-reset" type="button" class="secondary" disabled>Use standard picture</button>
      </div>
      <p id="fleet-aircraft-image-help" class="hint">PNG, JPG or WebP up to 6 MB. Your uploaded image is private and applies only to this registered aircraft.</p>
      <p id="fleet-aircraft-image-status" class="hint" role="status" aria-live="polite"></p>
    </div>
  </section>
</div>
<dialog id="fleet-configuration-dialog" class="fleet-configuration-dialog" aria-labelledby="fleet-configuration-dialog-heading">
  <div class="fleet-configuration-dialog-inner">
    <div class="fleet-configuration-dialog-title">
      <h3 id="fleet-configuration-dialog-heading">Change aircraft configuration</h3>
      <button type="button" class="secondary" id="fleet-configuration-close" aria-label="Close configuration options">Close</button>
    </div>
    <p id="fleet-configuration-aircraft-label" class="hint"></p>
    <p id="fleet-configuration-load-status" class="hint" role="status" aria-live="polite">Loading company configurations...</p>
    <label class="workspace-label" for="fleet-configuration-choice">Available company configurations for this aircraft model</label>
    <select id="fleet-configuration-choice" disabled><option value="">Loading...</option></select>
    <div id="fleet-configuration-preview" class="fleet-configuration-preview" aria-live="polite"></div>
    <label class="workspace-label" for="fleet-configuration-facility">Refit facility</label>
    <select id="fleet-configuration-facility" disabled><option value="">No confirmed refit appointment</option></select>
    <p id="fleet-configuration-slot-status" class="hint">Refit booking slots and confirmed installation dates are not available yet.</p>
    <div class="fleet-configuration-dialog-actions">
      <button type="button" class="secondary" id="fleet-configuration-create">Design new company layout</button>
      <button type="button" class="primary" id="fleet-configuration-save-draft" disabled>Save configuration proposal</button>
    </div>
    <p id="fleet-configuration-feedback" class="hint" role="status" aria-live="polite"></p>
    <p class="hint">Saving a proposal does not replace installed seats, ground the aircraft, reserve a maintenance slot, or charge the airline. Final refit cost and installation date need a verified booking.</p>
  </div>
</dialog>
<section class="fleet-detail-section"><h4>Airframe condition and usage</h4><div class="fleet-detail-grid"><div class="fleet-detail-row"><span>Individual aircraft manufacture year</span><strong id="fleet-detail-manufacture-year">—</strong></div>
<div class="fleet-detail-row"><span>Individual aircraft age</span><strong id="fleet-detail-aircraft-age">—</strong></div>
<div class="fleet-detail-row"><span>Verified condition</span><strong id="fleet-detail-condition">—</strong></div>
<div class="fleet-detail-row"><span>Tracked flight hours</span><strong id="fleet-detail-flight-hours">—</strong></div>
<div class="fleet-detail-row"><span>Tracked flight cycles</span><strong id="fleet-detail-flight-cycles">—</strong></div>
<div class="fleet-detail-row"><span>Tracking started</span><strong id="fleet-detail-tracking-start">—</strong></div>
<div class="fleet-detail-row"><span>Added to fleet</span><strong id="fleet-detail-fleet-added">—</strong></div></div></section>
<section class="fleet-detail-section"><h4>Aircraft technical specifications</h4><div class="fleet-detail-grid"><div class="fleet-detail-row"><span>Model family</span><strong id="fleet-detail-family">—</strong></div>
<div class="fleet-detail-row"><span>Passenger seats (model reference)</span><strong id="fleet-detail-seats">—</strong></div>
<div class="fleet-detail-row"><span>Cargo capacity (model reference)</span><strong id="fleet-detail-cargo">—</strong></div>
<div class="fleet-detail-row"><span>Model engine option</span><strong id="fleet-detail-engine">—</strong></div>
<div class="fleet-detail-row"><span>Model production years</span><strong id="fleet-detail-production-years">—</strong></div>
<div class="fleet-detail-row"><span>Reference crew required</span><strong id="fleet-detail-crew">—</strong></div>
<div class="fleet-detail-row"><span>Cruise speed (reference)</span><strong id="fleet-detail-cruise-speed">—</strong></div>
<div class="fleet-detail-row"><span>Estimated cruise fuel burn</span><strong id="fleet-detail-fuel-burn">—</strong></div>
<div class="fleet-detail-row"><span>Fuel tank capacity (game reference)</span><strong id="fleet-detail-fuel-tank">—</strong></div>
<div class="fleet-detail-row"><span>Fuel consumption evidence</span><strong id="fleet-detail-fuel-evidence">—</strong></div>
<div class="fleet-detail-row"><span>Fuel type</span><strong id="fleet-detail-fuel-type">—</strong></div>
<div class="fleet-detail-row"><span>Range (reference)</span><strong id="fleet-detail-range">—</strong></div>
<div class="fleet-detail-row"><span>Maximum takeoff weight</span><strong id="fleet-detail-mtow">—</strong></div>
<div class="fleet-detail-row"><span>Maximum landing weight</span><strong id="fleet-detail-mlw">—</strong></div>
<div class="fleet-detail-row"><span>Wingspan</span><strong id="fleet-detail-wingspan">—</strong></div>
<div class="fleet-detail-row"><span>Aircraft length</span><strong id="fleet-detail-length">—</strong></div>
<div class="fleet-detail-row"><span>Aircraft height</span><strong id="fleet-detail-height">—</strong></div>
<div class="fleet-detail-row"><span>Takeoff runway (reference)</span><strong id="fleet-detail-takeoff-runway">—</strong></div>
<div class="fleet-detail-row"><span>Landing runway (reference)</span><strong id="fleet-detail-landing-runway">—</strong></div>
<div class="fleet-detail-row"><span>Technical evidence status</span><strong id="fleet-detail-tech-evidence">—</strong></div></div></section>
<section class="fleet-detail-section"><h4>Aircraft acquisition and operating costs</h4><div class="fleet-detail-grid"><div class="fleet-detail-row"><span>Acquisition type</span><strong id="fleet-detail-acquisition-type">—</strong></div>
<div class="fleet-detail-row"><span>Recorded acquisition date</span><strong id="fleet-detail-acquisition-date">—</strong></div>
<div class="fleet-detail-row"><span>Recorded upfront payment</span><strong id="fleet-detail-upfront">—</strong></div>
<div class="fleet-detail-row"><span>Recorded monthly lease amount</span><strong id="fleet-detail-monthly-lease">—</strong></div>
<div class="fleet-detail-row"><span>Recorded lease contract</span><strong id="fleet-detail-contract-months">—</strong></div>
<div class="fleet-detail-row"><span>Current individual aircraft market value</span><strong id="fleet-detail-market-value">—</strong></div>
<div class="fleet-detail-row"><span>Verified operating cost per flight</span><strong id="fleet-detail-operating-cost">—</strong></div></div></section>
<p class="hint fleet-detail-disclaimer">Individual aircraft condition, build year, lifecycle and price stay “Not recorded” until verified values are available. Model specifications are reference data, not proof of an individual installed configuration. No invented age, valuation, flight hours or maintenance dates are displayed.</p>
<section id="fleet-maintenance-preview" class="fleet-maintenance-preview" aria-label="Aircraft maintenance cycle" aria-live="polite">Maintenance information loads when you open this aircraft.</section>`,'AIRCRAFT PROFILE'),
 'aircraft-new-orders':()=>card('New factory aircraft orders',"<p class=\"hint\">Select a current-production aircraft and its cabin or cargo configuration. Delivery depends on available factory stock and manufacturer orders.</p>\n<p id=\"market-state\" class=\"workspace-state\" role=\"status\">Loading factory catalog…</p>\n<div class=\"aircraft-market-filter-grid\" aria-label=\"Choose new aircraft\">\n<label>Manufacturer<select id=\"new-maker\"><option value=\"\">Choose manufacturer</option></select></label>\n<label>Family<select id=\"new-family\" disabled><option value=\"\">Choose family</option></select></label>\n<label>Model<select id=\"new-model\" disabled><option value=\"\">Choose model</option></select></label>\n<label>Configuration<select id=\"new-configuration\" disabled><option value=\"\">Choose configuration</option></select></label>\n</div>\n<div class=\"aircraft-market-finance-row\">\n<label>Payment<select id=\"new-payment\"><option value=\"cash\">Pay cash</option><option value=\"credit\">Buy on credit (not yet active)</option><option value=\"lease\">Lease (not yet active)</option></select></label>\n<label>Aircraft registration<input id=\"market-aircraft-registration\" maxlength=\"20\" autocomplete=\"off\" placeholder=\"e.g. D-ABCD\" aria-describedby=\"market-feedback\"></label>\n</div>\n<div id=\"new-aircraft-quote\" class=\"aircraft-market-quote\" role=\"status\" aria-live=\"polite\">Choose manufacturer, family, model and configuration to see prices and delivery.</div>\n<div id=\"factory-cabin-customizer\" class=\"factory-cabin-customizer\" aria-label=\"Factory cabin preview\"></div>\n<div class=\"workspace-actions aircraft-market-actionbar\">\n<button type=\"button\" class=\"primary aircraft-market-compact-button\" id=\"market-acquire\" disabled>Confirm cash order</button>\n<button type=\"button\" class=\"secondary aircraft-market-compact-button\" data-workspace-go=\"fleet\">My fleet</button>\n<button type=\"button\" class=\"secondary aircraft-market-compact-button\" data-workspace-go=\"aircraft-market\">Used aircraft market</button>\n</div>\n<p id=\"market-feedback\" class=\"hint\" role=\"status\" aria-live=\"polite\"></p>\n<p class=\"hint\">Aircraft prices are game estimates, not manufacturer offers. Credit and lease payment engines are not yet active. No payment or aircraft delivery happens before World 1 opens.</p>\n<div id=\"market-offers\" hidden></div><select id=\"market-offer-select\" hidden aria-label=\"Selected server offer\"><option value=\"\"></option></select>",'NEW AIRCRAFT'),
 'aircraft-market':()=>card('Used aircraft auctions',"<p class=\"hint\">Every offer represents one fictional game aircraft. You can filter by manufacturer, family, model and configuration. Sellers are fictional market companies until player-to-player trading is enabled.</p>\n<p id=\"used-market-state\" class=\"workspace-state\" role=\"status\" aria-live=\"polite\">Loading used-aircraft listings…</p>\n<div class=\"aircraft-market-filter-grid\" aria-label=\"Filter used aircraft\">\n<label>Manufacturer<select id=\"used-maker\"><option value=\"\">All manufacturers</option></select></label>\n<label>Family<select id=\"used-family\"><option value=\"\">All families</option></select></label>\n<label>Model<select id=\"used-model\"><option value=\"\">All models</option></select></label>\n<label>Configuration<select id=\"used-configuration\"><option value=\"\">All configurations</option></select></label>\n</div>\n<div class=\"aircraft-market-search-row\">\n<label>Search<input id=\"used-market-search\" type=\"search\" maxlength=\"60\" autocomplete=\"off\" placeholder=\"Aircraft or seller\"></label>\n<label>Offer type<select id=\"used-market-mode\"><option value=\"all\">All listings</option><option value=\"purchase\">Purchase</option><option value=\"lease\">Leasing</option></select></label>\n<label>Payment method<select id=\"used-market-payment\"><option value=\"cash\">Cash (purchase auction)</option><option value=\"credit\">Credit (not yet active)</option><option value=\"lease\">Leasing (not yet active)</option></select></label>\n<div class=\"aircraft-market-search-actions\">\n<button id=\"used-market-find\" type=\"button\" class=\"secondary aircraft-market-compact-button\">Search</button>\n<button id=\"used-market-refresh\" type=\"button\" class=\"secondary aircraft-market-compact-button\">Refresh</button>\n</div></div>\n<div id=\"used-market-lots\" class=\"used-market-list\" role=\"list\" aria-live=\"polite\"></div>\n<div class=\"used-market-pagination\">\n<button id=\"used-market-prev\" type=\"button\" class=\"secondary aircraft-market-compact-button\" disabled>Previous</button>\n<span id=\"used-market-page\">Page 1</span>\n<button id=\"used-market-next\" type=\"button\" class=\"secondary aircraft-market-compact-button\" disabled>Next</button></div>\n<section id=\"used-market-bid-panel\" class=\"used-market-bid-panel\" hidden>\n<h3 id=\"used-market-bid-title\">Bid on aircraft</h3><p id=\"used-market-bid-info\" class=\"hint\"></p>\n<div class=\"aircraft-market-finance-row\">\n<label>Your bid (USD)<input id=\"used-market-bid-amount\" type=\"number\" min=\"100\" step=\"0.01\" autocomplete=\"off\" inputmode=\"decimal\"></label>\n<label>Aircraft registration<input id=\"used-market-bid-registration\" type=\"text\" maxlength=\"20\" autocomplete=\"off\" placeholder=\"e.g. D-ABCD\"></label>\n</div><div class=\"workspace-actions aircraft-market-actionbar\">\n<button id=\"used-market-bid-confirm\" type=\"button\" class=\"primary aircraft-market-compact-button\" disabled>Confirm cash bid</button>\n<button id=\"used-market-bid-cancel\" type=\"button\" class=\"secondary aircraft-market-compact-button\">Cancel</button></div>\n<p id=\"used-market-bid-feedback\" class=\"hint\" role=\"status\" aria-live=\"polite\"></p></section>\n<p class=\"hint\">Unsold listings have no expiry. The first accepted bid starts 15 minutes; each higher bid restarts the countdown. A cash bid holds your funds and refunds the previous highest bidder. Real-money transactions do not occur.</p>\n<div class=\"workspace-actions aircraft-market-actionbar\">\n<button type=\"button\" class=\"secondary aircraft-market-compact-button\" data-workspace-go=\"aircraft-new-orders\">New aircraft orders</button>\n<button type=\"button\" class=\"secondary aircraft-market-compact-button\" data-workspace-go=\"fleet\">My fleet</button></div>",'SECOND-HAND AVIATION MARKET'),
 'maintenance':()=>card('Aircraft maintenance locations',
   '<p class="hint">Explore real maintenance providers across six continents. Daily and Weekly checks are available at every approved game airport. Heavy checks and cabin refits require a provider matched to your exact aircraft type.</p>'+
   '<div id="mro-directory" aria-label="Worldwide maintenance facilities" role="region"></div>'+
   '<p class="hint">Provider-supported does not mean every aircraft/check can be booked. Research-pending sites remain unavailable for bookings. No payment or flight is changed by browsing.</p>'+
   button('fleet','Return to my fleet'),'MAINTENANCE NETWORK'),
 'routes':()=>routePlannerMarkup(),
 'schedule':()=>card('Aircraft daily flight schedule',
   '<p class="hint">Choose one weekday. The full width shows that day only, from 00:00 to 24:00 UTC. Each row is a real aircraft owned or leased by your airline.</p>'+
   '<div class="schedule-board-toolbar">'+
    '<div class="schedule-day-switch" role="group" aria-label="Choose timetable weekday">'+
     '<button type="button" class="secondary" id="schedule-day-prev" aria-label="Previous day">◀</button>'+
     '<strong id="schedule-selected-day" aria-live="polite">Monday</strong>'+
     '<button type="button" class="secondary" id="schedule-day-next" aria-label="Next day">▶</button>'+
    '</div>'+
    '<div class="workspace-actions schedule-board-actions">'+
     '<button type="button" class="secondary" id="schedule-refresh">Refresh timetable</button>'+
     button('routes','Create a route')+'</div>'+
   '</div>'+
   '<div class="schedule-board-legend" aria-label="Schedule status legend">'+
    '<span><i class="schedule-board-legend-marker" aria-hidden="true"></i> Draft departure — no booked time</span>'+
    '<span><i class="schedule-board-legend-band" aria-hidden="true"></i> Verified airport-slot flight window</span>'+
    '</div>'+
   '<p id="schedule-status" role="status" class="hint">Loading the verified airline fleet and routes…</p>'+
   '<div id="schedule-aircraft-board" class="schedule-aircraft-board" aria-label="Airline aircraft 24-hour daily flight timetable"></div>'+
   small('Time bars match verified flight duration only. Planning departures without duration are markers, not aircraft bookings. Real flight activation and turnaround clearance are still separate.'),
   'AIRCRAFT × ONE DAY × 24 HOURS'),
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
 'service':()=>card('Flight services',
   '<p class="hint">Configure meals, drinks and other on-board flight services for each cabin class. These are independent of the installed seats.</p>'+
   '<div id="cabin-services-manager" aria-label="Flight services and passenger offers"></div>',
   'FLIGHT SERVICES'),
 'cabin-configurations':()=>card('Cabin configurations',
   '<p class="hint">Every registered aircraft has its own installed cabin. Design a proposed replacement and save a draft here. An actual refit needs approved maintenance downtime.</p>'+
   '<div id="cabin-configuration-manager" aria-label="Individual aircraft cabin editor"></div>',
   'AIRCRAFT CABIN'),
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
 let usedMarketSnapshot=null;
 let usedMarketFetchVersion=0;
 let usedMarketPage=0;
 let usedMarketFilter='all';
 let usedMarketSearch='';
 const usedMarketChoice={maker:'',family:'',model:'',configuration:'',payment:'cash'};
 let selectedUsedListingId=null;
 let selectedFleetAircraftId=null;
 let configurationDialogContext=null,configurationDialogVersion=0;
 let marketFetchVersion=0;
 let maintenanceFetchVersion=0;
 let maintenanceLast=null;
 let aircraftPhotoToken=0,aircraftPhotoId=null,aircraftCustomPhoto=false,photoBlob=null,photoPreviewUrl=null,photoPendingId=null;
 let scheduleSnapshot=null;
 let scheduleFetchVersion=0;
 let scheduleReadError=false;
 let cabinManager=null;
 let cabinConfigurationManager=null;
 let aircraftConfigurationDialog=null;
 let scheduleSelectedDay=0;
 const scheduleDays=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
 for(const [name,render] of Object.entries(pages)){
  const el=$('workspace-'+name);if(el)el.innerHTML=render();
 }
 // The cabin manager's DOM host is created by the service page renderer above.
 // Cabin services are optional UI: never reject a verified player's entire
 // account session if a secondary feature cannot initialize.
 const cabinHost=$('cabin-services-manager');
 if(cabinHost){
  try{
   cabinManager=createCabinServiceManager({doc,host:cabinHost,storage,identity});
  }catch{
   console.warn('Airlinerra cabin service interface unavailable');
  }
 }
 // Optional feature: constructed only after the page hosts exist.
 const configurationHost=$('cabin-configuration-manager');
 if(configurationHost){
  try{
   cabinConfigurationManager=createCabinConfigurationManager({
    doc,host:configurationHost,factoryHost:$('factory-cabin-customizer'),
    onDirectoryUpdate:()=>renderMroDirectory(),
    onFactoryLayoutChange:()=>{
     const buy=$('market-acquire'),offer=currentFactoryOffer();
     if(buy)buy.disabled=!(marketIsOpen()&&newAircraftChoice.payment==='cash'&&
      isReleasedFactoryOffer(offer)&&cabinConfigurationManager?.getFactoryPlan()?.standard===true&&
      typeof data.fleetClient?.acquire==='function');
    }
   });
  }catch{console.warn('Cabin configuration editor unavailable')}
 }
 // Configuration popup is optional; failures must never block airline login.
 try{
  aircraftConfigurationDialog=createAircraftConfigurationDialog({
   doc,
   getAirline:()=>data.airline,
   getAircraft:()=>marketSnapshot?.fleet?.find(a=>a.id===selectedFleetAircraftId)||null,
   getFleetClient:()=>data.fleetClient,
   onDesign:id=>{
    cabinConfigurationManager?.selectAircraft(id);
    if(typeof goTo==='function')goTo('cabin-configurations');
   },
   onSaved:()=>cabinConfigurationManager?.updateData(data)
  });
 }catch{console.warn('Aircraft configuration popup unavailable')}
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
  renderAirlineWeeklyBoard(doc,host,board,{day:scheduleSelectedDay});
  const selected=$('schedule-selected-day');
  if(selected)selected.textContent=scheduleDays[scheduleSelectedDay];
  const status=$('schedule-status');
  if(status){
   status.textContent=board.status==='unavailable'?
    'Verified aircraft data is not available. Cannot determine airline timetable.':
    board.status==='empty'?
    'No real owned or leased aircraft were returned for this airline.':
    String(board.rows.length)+' company aircraft · '+
    String(board.rows.reduce((n,row)=>n+row.days[scheduleSelectedDay].events.length,0))+
    ' departures on '+scheduleDays[scheduleSelectedDay]+' · '+
    String(board.rows.reduce((n,row)=>n+row.days[scheduleSelectedDay].bands
     .filter(b=>!b.continues).length,0))+
    ' verified flight windows that day.'+
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
  for(const key of ['economy','premium','business','first']){
   if($('cabin-'+key)&&draft.cabin?.[key]!==undefined)$('cabin-'+key).value=draft.cabin[key];
  }
  for(const key of ['revenue','leases','crew','fuel','maintenance','airportFees','services','marketing']){
   if($('budget-'+key)&&draft.budget?.[key]!==undefined)$('budget-'+key).value=draft.budget[key];
  }
  showRoute();renderSchedule();
 }
 const prettyFleetText=value=>String(value||'—').replace(/[-_]/gu,' ').replace(/\b\w/gu,m=>m.toUpperCase());
 const fleetSeatLabel=a=>a.useType==='cargo'?'—':
  Number.isInteger(Number(a.referenceSeats))&&a.referenceSeats!==null?
   new Intl.NumberFormat('en-US').format(Number(a.referenceSeats))+' ref.':'Not verified';
 const fleetConfigurationLabel=a=>{
  if(!a)return '—';
  const code=String(a.configuration||'').trim();
  return /^(?:PASSENGER|CARGO)[- _]BASE$/i.test(code)?'Default':
   code?prettyFleetText(code):'Not recorded';
 };
 const fleetCargoLabel=a=>a.cargoKg!==null&&a.cargoKg!==undefined&&
  Number.isFinite(Number(a.cargoKg))&&Number(a.cargoKg)>0?
  new Intl.NumberFormat('en-US').format(Number(a.cargoKg))+' kg max':'Not verified';
 const fleetLocationLabel=a=>{
  if(a.locationStatus==='in_flight')return 'In flight';
  if(a.locationStatus==='grounded'&&a.locationAirportKey)
   return (a.locationAirportCode||a.locationAirportName||a.locationAirportKey)+' · At airport';
  return 'Location not verified';
 };
 const fleetStateLabel=a=>prettyFleetText(a.fleetStatus||'Unknown')+' · '+
  prettyFleetText(a.ownershipType||'Fleet');
 const usd=n=>{
  const amount=Number(n);
  return n===null||n===undefined||!Number.isFinite(amount)?'Not available':
   new Intl.NumberFormat('en-US',{style:'currency',currency:'USD',
    maximumFractionDigits:0}).format(amount);
 };
 function resetPhotoDraft(){
  if(photoPreviewUrl){URL.revokeObjectURL(photoPreviewUrl);photoPreviewUrl=null;}
  photoBlob=null;photoPendingId=null;
  const field=$('fleet-aircraft-image-file');if(field)field.value='';
  const save=$('fleet-aircraft-image-save');if(save)save.disabled=true;
 }
 function catalogPhotoUrl(a){
  const p=a?.catalogImagePath;
  if(a?.catalogImageBucket!=='Admin'||typeof p!=='string'||
     p.length>300||p.includes('..')||/[?#\\\\]/.test(p))return null;
  return 'https://hwllkabgzaynalahvkpz.supabase.co/storage/v1/object/public/Admin/'+
   p.split('/').map(encodeURIComponent).join('/');
 }
 function setAircraftPhoto(url){
  const img=$('fleet-aircraft-image'),empty=$('fleet-aircraft-image-empty');
  if(!img||!empty)return;
  if(url){img.src=url;img.hidden=false;empty.hidden=true;}
  else{img.hidden=true;img.removeAttribute('src');empty.hidden=false;}
 }
 async function refreshAircraftPhoto(a,force=false){
  const id=a?.id||null,airlineId=data.airline?.id;
  if(!force&&aircraftPhotoId===id)return;
  const token=++aircraftPhotoToken;
  resetPhotoDraft();aircraftPhotoId=id;aircraftCustomPhoto=false;
  setAircraftPhoto(catalogPhotoUrl(a));
  const media=data.aircraftMedia,field=$('fleet-aircraft-image-file');
  const reset=$('fleet-aircraft-image-reset'),status=$('fleet-aircraft-image-status');
  if(status)status.textContent='';
  if(field)field.disabled=!id||!airlineId||typeof media?.uploadAircraftImage!=='function';
  if(reset)reset.disabled=true;
  if(!id||!airlineId||typeof media?.getAircraftImageUrl!=='function')return;
  try{
   const url=await media.getAircraftImageUrl({airlineId,aircraftInventoryId:id});
   if(token!==aircraftPhotoToken||selectedFleetAircraftId!==id||data.airline?.id!==airlineId)return;
   if(url){setAircraftPhoto(url);aircraftCustomPhoto=true;if(reset)reset.disabled=false;}
  }catch{
   if(token===aircraftPhotoToken&&status)status.textContent='Custom picture unavailable. The catalog picture is displayed.';
  }
 }
 async function processAircraftPhoto(file){
  if(!file||!['image/png','image/jpeg','image/webp'].includes(file.type)||
     file.size<1||file.size>6000000)throw Error('Select PNG, JPG or WebP up to 6 MB.');
  const source=URL.createObjectURL(file);
  try{
   const Img=doc.defaultView?.Image||Image,img=new Img();
   await new Promise((resolve,reject)=>{
    img.onload=resolve;img.onerror=()=>reject(Error('The image could not be read.'));
    img.src=source;
   });
   if(!img.naturalWidth||!img.naturalHeight||
      img.naturalWidth>10000||img.naturalHeight>10000)throw Error('Invalid image dimensions.');
   for(const [size,quality] of [[1700,.9],[1400,.84],[1050,.78]]){
    const ratio=Math.min(1,size/Math.max(img.naturalWidth,img.naturalHeight));
    const canvas=doc.createElement('canvas');
    canvas.width=Math.max(1,Math.round(img.naturalWidth*ratio));
    canvas.height=Math.max(1,Math.round(img.naturalHeight*ratio));
    const ctx=canvas.getContext('2d');
    if(!ctx)throw Error('Image processing is unavailable.');
    ctx.drawImage(img,0,0,canvas.width,canvas.height);
    const result=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',quality));
    if(result?.type==='image/webp'&&result.size>0&&result.size<=1048576)return result;
   }
   throw Error('The picture could not be compressed below 1 MB.');
  }finally{URL.revokeObjectURL(source);}
 }
 function fmtAircraftNumber(value,unit=''){
  if(value===null||value===undefined||value==='')return 'Not recorded';
  const n=Number(value);
  return Number.isFinite(n)&&n>=0?
   new Intl.NumberFormat('en-US',{maximumFractionDigits:2}).format(n)+unit:'Not recorded';
 }
 function fmtAircraftDate(v){
  if(!v)return 'Not recorded';
  const d=new Date(v);return Number.isNaN(d.getTime())?'Not recorded':d.toLocaleDateString('en-GB');
 }
 function updateAirframeDetails(entry){
  const year=Number(entry?.manufactureYear);
  const known=entry?.manufactureYear!==null&&entry?.manufactureYear!==undefined&&
   Number.isInteger(year)&&year>=1900&&year<=new Date().getFullYear();
  const values={
   'fleet-detail-manufacture-year':known?String(year):'Not recorded',
   'fleet-detail-aircraft-age':known?String(new Date().getFullYear()-year)+' years':'Not recorded',
   'fleet-detail-condition':fmtAircraftNumber(entry?.conditionPct,'%'),
   'fleet-detail-flight-hours':fmtAircraftNumber(entry?.trackedFlightHours,' h'),
   'fleet-detail-flight-cycles':fmtAircraftNumber(entry?.trackedFlightCycles),
   'fleet-detail-tracking-start':fmtAircraftDate(entry?.verifiedTrackingStartedUtc)
  };
  for(const [id,value] of Object.entries(values))if($(id))$(id).textContent=value;
 }
 function renderMroDirectory(){
  const host=$('mro-directory');if(!host)return;
  const catalog=cabinConfigurationManager?.getDirectory()||[];
  if(!catalog.length){host.textContent='Loading source-linked MRO directory…';return;}
  host.replaceChildren();
  const choose=doc.createElement('div');choose.className='mro-directory-controls';
  const label=doc.createElement('label');label.textContent='Continent';
  const select=doc.createElement('select');
  select.append(new Option('All continents',''));
  for(const continent of [...new Set(catalog.map(x=>x.continent))].sort())
   select.append(new Option(continent,continent));
  label.append(select);choose.append(label);host.append(choose);
  const count=doc.createElement('p');count.className='hint';host.append(count);
  const list=doc.createElement('div');list.className='mro-directory-list';host.append(list);
  const display=()=>{
   list.replaceChildren();
   const filtered=catalog.filter(x=>!select.value||x.continent===select.value);
   count.textContent=new Set(filtered.map(x=>x.airportKey)).size+' airports · '+
    filtered.length+' provider records. Model-specific approval still required.';
   for(const facility of filtered){
    const row=doc.createElement('div');row.className='mro-directory-line';
    const continent=doc.createElement('strong');continent.textContent=facility.continent;
    const airport=doc.createElement('span');
    airport.textContent=facility.airportName+' ('+facility.airportCode+')';
    const provider=doc.createElement('span');provider.textContent=facility.provider;
    const proof=doc.createElement('span');const status=doc.createElement('small');
    status.textContent=facility.researchStatus==='provider_supported'?
     'Source-supported provider · type approval required':'Research pending · no booking';
    proof.append(status);
    if(typeof facility.sourceUrl==='string'&&/^https:\/\//u.test(facility.sourceUrl)){
     const link=doc.createElement('a');link.textContent='Source';
     link.href=facility.sourceUrl;link.target='_blank';link.rel='noopener noreferrer';
     proof.append(doc.createTextNode(' · '),link);
    }
    row.append(continent,airport,provider,proof);list.append(row);
   }
  };
  select.addEventListener('change',display);display();
 }
 function renderMaintenancePreview(){
  const host=$('fleet-maintenance-preview');
  if(!host)return;
  const aircraft=marketSnapshot?.fleet?.find(x=>x.id===selectedFleetAircraftId);
  if(!aircraft){host.textContent='Select an aircraft from your fleet.';return;}
  if(!maintenanceLast||maintenanceLast.aircraftInventoryId!==aircraft.id){
   host.textContent='Maintenance data loading…';return;
  }
  host.replaceChildren();
  const heading=doc.createElement('h3');heading.textContent='Maintenance cycle';
  host.append(heading);
  const rows=maintenanceLast.checks||[];
  if(rows.length!==6){
   const msg=doc.createElement('p');msg.textContent='Maintenance cycle information is incomplete.';
   host.append(msg);return;
  }
  updateAirframeDetails(rows[0]);
   const details=doc.createElement('p');details.className='hint';
  const condition=rows[0].conditionPct;
  const year=rows[0].manufactureYear;
  details.textContent='Category: '+String(rows[0].groupName||'Unassigned')+
   ' · Overall condition: '+(condition===null||condition===undefined?'Not recorded':condition+'%')+
   ' · Build year: '+(year===null||year===undefined?'Not recorded':year)+
   ' · Tracked flight hours: '+
   (rows[0].trackedFlightHours===null||rows[0].trackedFlightHours===undefined?
    'Not started':rows[0].trackedFlightHours);
  host.append(details);
  const tableWrap=doc.createElement('div');tableWrap.className='fleet-maintenance-scroll';
  const table=doc.createElement('table');table.className='fleet-maintenance-table';
  const top=doc.createElement('thead'),header=doc.createElement('tr');
  for(const label of ['Check','Required interval','Downtime','Last completed','Base game cost']){
   const th=doc.createElement('th');th.textContent=label;header.append(th);
  }
  top.append(header);table.append(top);
  const body=doc.createElement('tbody');
  for(const check of rows){
   const tr=doc.createElement('tr');
   let interval='Not configured';
   if(check.calendarIntervalHours)interval=check.calendarIntervalHours===24?
    'Every 24 hours':check.calendarIntervalHours===168?
    'Every 7 days':check.calendarIntervalHours+' hours';
   if(check.flightHourInterval)interval=
    (check.calendarIntervalMonths?check.calendarIntervalMonths+' months OR ':'')+
    Number(check.flightHourInterval).toLocaleString('en-US')+' flight hours';
   if(!check.flightHourInterval&&check.calendarIntervalMonths)interval=
    check.calendarIntervalMonths===96?'Every 8 years':
    'Every '+check.calendarIntervalMonths+' months';
   const duration=check.durationHours===168?'7 days':
    check.durationHours===504?'21 days':
    check.durationHours===24?'24 hours':check.durationHours+' hour'+
     (check.durationHours===1?'':'s');
   const last=check.lastCompletedUtc?
    new Date(check.lastCompletedUtc).toLocaleDateString('en-GB'):'Not recorded';
   for(const label of [
    String(check.label||check.checkCode),interval,duration,last,
    usd(check.baseEstimateUsd)
   ]){
    const td=doc.createElement('td');td.textContent=label;tr.append(td);
   }
   body.append(tr);
  }
  table.append(body);tableWrap.append(table);host.append(tableWrap);
  const pricing=doc.createElement('p');pricing.className='hint';
  pricing.textContent='Provisional base prices only. Your final maintenance cost is adjusted for this individual aircraft\'s age when its manufacture year is verified. Missing check history means due dates are unknown, not completed.';
  host.append(pricing);
  const locationsTitle=doc.createElement('h4');locationsTitle.textContent='Eligible maintenance airports';
  host.append(locationsTitle);
  const line=doc.createElement('p');line.className='hint';
  line.textContent='Daily and Weekly: every approved game airport, after verified arrival and grounding.';
  host.append(line);
  const sites=Array.isArray(maintenanceLast.maintenanceSites)?maintenanceLast.maintenanceSites:[];
  const grouped=new Map();
  for(const site of sites){
   if(!site?.airportKey||!site?.checkCode)continue;
   const key=site.airportKey+'|'+site.provider;
   if(!grouped.has(key))grouped.set(key,{...site,codes:[]});
   grouped.get(key).codes.push(String(site.checkCode).toUpperCase());
  }
  if(!grouped.size){
   const none=doc.createElement('p');none.className='hint';
   none.textContent='No aircraft-type-approved base-maintenance facility has been loaded yet.';
   host.append(none);
  }else{
   const ul=doc.createElement('ul');ul.className='fleet-maintenance-location-list';
   for(const item of grouped.values()){
    const li=doc.createElement('li');
    li.textContent=String(item.airportName||item.airportKey)+
     ' ('+String(item.airportCode||'—')+') — '+item.codes.join(', ')+
     ' · '+String(item.provider||'Approved provider');
    ul.append(li);
   }
   host.append(ul);
  }
  const quotePanel=doc.createElement('div');quotePanel.className='fleet-maintenance-site-quote';
  const checkLabel=doc.createElement('label');checkLabel.textContent='Maintenance check';
  const checkSelect=doc.createElement('select');checkSelect.id='fleet-maintenance-check-choice';
  for(const check of rows.filter(c=>['a','b','c','d'].includes(c.checkCode))){
   checkSelect.append(new Option(check.label,check.checkCode));
  }
  checkSelect.value='c';checkLabel.append(checkSelect);
  const siteLabel=doc.createElement('label');siteLabel.textContent='Choose maintenance airport';
  const siteSelect=doc.createElement('select');siteSelect.id='fleet-maintenance-site-choice';
  siteLabel.append(siteSelect);
  const result=doc.createElement('p');result.className='hint';
  const renderQuote=()=>{
   const selectedCheck=rows.find(c=>c.checkCode===checkSelect.value);
   const old=siteSelect.value;siteSelect.replaceChildren(new Option('Choose approved airport',''));
   for(const site of sites.filter(x=>x.checkCode===checkSelect.value)){
    const o=new Option(site.airportName+' ('+site.airportCode+') · '+site.provider,
     site.airportKey+'|'+site.provider);
    siteSelect.append(o);
   }
   if([...siteSelect.options].some(o=>o.value===old))siteSelect.value=old;
   const chosen=sites.find(x=>x.checkCode===checkSelect.value&&
    x.airportKey+'|'+x.provider===siteSelect.value);
   if(!chosen){result.textContent='Select a model-approved maintenance airport to compare costs. Daily and Weekly checks remain available at every approved airport.';return}
   const base=Number(selectedCheck?.baseEstimateUsd);
   const multiplier=Number(chosen.siteMultiplier);
   const quote=Number.isFinite(base)&&Number.isFinite(multiplier)?usd(Math.round(base*multiplier)):'Not available';
   result.textContent='Estimated '+selectedCheck.label+' at '+chosen.provider+
    ' · '+quote+' base and location factor included · '+selectedCheck.durationHours+
    ' hours downtime. Aircraft age and additional repair costs are not included. '+
    'This is only a game estimate. No maintenance visit is reserved.';
  };
  checkSelect.addEventListener('change',renderQuote);
  siteSelect.addEventListener('change',renderQuote);
  quotePanel.append(checkLabel,siteLabel,result);host.append(quotePanel);renderQuote();
  const notice=doc.createElement('p');notice.className='hint';
  notice.textContent='A–D checks require flying this aircraft to an eligible facility and returning to its hub on verified flights. Booking, maintenance downtime and payment are not activated yet; no flight is automatically moved.';
  host.append(notice);
 }
 async function loadMaintenancePreview(aircraftId){
  const ticket=++maintenanceFetchVersion;
  const airlineId=data.airline?.id,client=data.fleetClient;
  maintenanceLast=null;renderMaintenancePreview();
  if(!data.connected||!airlineId||!client?.maintenancePreview){
   const host=$('fleet-maintenance-preview');
   if(host)host.textContent='Maintenance records are not connected.';return;
  }
  try{
   const result=await client.maintenancePreview({airlineId,aircraftInventoryId:aircraftId});
   if(ticket!==maintenanceFetchVersion||selectedFleetAircraftId!==aircraftId||
     data.airline?.id!==airlineId)return;
   if(result?.airlineId!==airlineId||result.aircraftInventoryId!==aircraftId||
      !Array.isArray(result.checks)||result.checks.length!==6||
      result.previewOnly!==true||result.canScheduleMaintenance!==false)
    throw Error('Invalid maintenance preview');
   maintenanceLast=result;renderMaintenancePreview();
  }catch{
   if(ticket!==maintenanceFetchVersion)return;
   const host=$('fleet-maintenance-preview');
   if(host)host.textContent='Maintenance cycle is temporarily unavailable. Your aircraft ownership and flight data are unchanged.';
  }
 }
 function renderAircraftDetail(){
  const aircraft=marketSnapshot?.fleet?.find(x=>x.id===selectedFleetAircraftId);
  const detail=$('fleet-detail-name');
  if(!detail)return;
  const fuelReference=aircraft?estimateFivePhaseFuel({
   distanceKm:1000,cruiseSpeedKmh:aircraft.cruiseSpeedKmh,
   cruiseFuelKgPerHour:aircraft.cruiseFuelKgPerHour,
   emptyFuelKgPer100Km:aircraft.emptyFuelKgPer100Km,
   halfFuelKgPer100Km:aircraft.halfFuelKgPer100Km,
   fullFuelKgPer100Km:aircraft.fullFuelKgPer100Km,
   fuelTankCapacityKg:aircraft.fuelTankCapacityKg,payloadFraction:.5
  }):null;
  const ids={
   'fleet-detail-name':aircraft?aircraftDisplayName(aircraft.manufacturer,aircraft.model):'Aircraft not available',
   'fleet-detail-subtitle':aircraft?
    String(aircraft.registration||'—')+(aircraft.nickname?' ('+aircraft.nickname+')':''):
    'Return to your fleet and choose an aircraft.',
   'fleet-detail-family':aircraft?.family||'Not recorded',
   'fleet-detail-registration':aircraft?.registration||'—',
   'fleet-detail-ownership':aircraft?prettyFleetText(aircraft.ownershipType):'—',
   'fleet-detail-seats':aircraft?fleetSeatLabel(aircraft):'—',
   'fleet-detail-configuration':aircraft?fleetConfigurationLabel(aircraft):'—',
   'fleet-detail-cargo':aircraft?fleetCargoLabel(aircraft):'—',
   'fleet-detail-location':aircraft?fleetLocationLabel(aircraft):'—',

   'fleet-detail-fleet-added':fmtAircraftDate(aircraft?.fleetAddedAt),
   'fleet-detail-engine':aircraft?.engineOption||'Not recorded',
   'fleet-detail-production-years':aircraft?.modelProductionStartYear?
    String(aircraft.modelProductionStartYear)+'–'+(aircraft.modelProductionEndYear||'present'):'Not recorded',
   'fleet-detail-crew':fmtAircraftNumber(aircraft?.referenceCrewRequired),
   'fleet-detail-cruise-speed':fmtAircraftNumber(aircraft?.cruiseSpeedKmh,' km/h'),
   'fleet-detail-fuel-burn':fuelReference?.status==='PLANNING_ESTIMATE'?
    fmtAircraftNumber(fuelReference.estimatedCruiseKgPerHour,' kg/h (estimate)'):'Not available',
   'fleet-detail-fuel-tank':fmtAircraftNumber(aircraft?.fuelTankCapacityKg,' kg'),
   'fleet-detail-fuel-evidence':aircraft?.fuelRateStatus==='DERIVED_PEER_AIRCRAFT_GAME_ESTIMATE'?
    'Estimated from '+String(aircraft.fuelPeerModel||'comparable model')+' ('+
    String(aircraft.fuelConfidenceClass||'unverified')+')':
    aircraft?.fuelRateStatus==='EXISTING_PROVISIONAL_DISTANCE_RATE'?
     'Existing provisional aircraft model estimate':
     'Not available',
   'fleet-detail-fuel-type':'Not verified (fuel type research pending)',
   'fleet-detail-range':fmtAircraftNumber(aircraft?.rangeKm,' km'),
   'fleet-detail-mtow':fmtAircraftNumber(aircraft?.mtowKg,' kg'),
   'fleet-detail-mlw':fmtAircraftNumber(aircraft?.mlwKg,' kg'),
   'fleet-detail-wingspan':fmtAircraftNumber(aircraft?.wingspanM,' m'),
   'fleet-detail-length':fmtAircraftNumber(aircraft?.lengthM,' m'),
   'fleet-detail-height':fmtAircraftNumber(aircraft?.heightM,' m'),
   'fleet-detail-takeoff-runway':fmtAircraftNumber(aircraft?.takeoffRunwayM,' m'),
   'fleet-detail-landing-runway':fmtAircraftNumber(aircraft?.landingRunwayM,' m'),
   'fleet-detail-tech-evidence':aircraft?.technicalReviewStatus?prettyFleetText(aircraft.technicalReviewStatus):'Not recorded',
   'fleet-detail-acquisition-type':aircraft?.acquisitionType?prettyFleetText(aircraft.acquisitionType):'Not recorded',
   'fleet-detail-acquisition-date':fmtAircraftDate(aircraft?.acquisitionDate),
   'fleet-detail-upfront':aircraft?.paidUpfrontUsd===null||aircraft?.paidUpfrontUsd===undefined?'Not recorded':usd(aircraft.paidUpfrontUsd),
   'fleet-detail-monthly-lease':aircraft?.recurringMonthlyUsd===null||aircraft?.recurringMonthlyUsd===undefined?'Not recorded':usd(aircraft.recurringMonthlyUsd),
   'fleet-detail-contract-months':fmtAircraftNumber(aircraft?.contractMonths,' months'),
   'fleet-detail-market-value':'Not available — no verified tail valuation',
   'fleet-detail-operating-cost':'Not calculated — no operated flights'
  };
  for(const [id,value] of Object.entries(ids))if($(id))$(id).textContent=value;
  const input=$('fleet-detail-nickname'),save=$('fleet-detail-save');
  if(input){input.value=aircraft?.nickname||'';input.disabled=!aircraft;}
  if(save)save.disabled=!aircraft||typeof data.fleetClient?.updateNickname!=='function';
  const change=$('fleet-configuration-change');
  if(change)change.disabled=!aircraft||!data.fleetClient?.cabinOverview;
  const currentMaintenance=maintenanceLast?.aircraftInventoryId===aircraft?.id?
   maintenanceLast?.checks?.[0]:null;
  updateAirframeDetails(currentMaintenance);
  if(aircraftPhotoId!==aircraft?.id)void refreshAircraftPhoto(aircraft);
 }
 function marketIsOpen(){
  return usedMarketSnapshot?.marketOpen===true;
 }
 const newAircraftChoice={maker:'',family:'',model:'',configuration:'',payment:'cash'};
 const isReleasedFactoryOffer=offer=>offer?.offerStatus==='published'&&
  offer.transactionType==='purchase'&&offer.configurationReviewStatus==='verified';
 function fillMarketSelect(id,options,chosen,placeholder){
  const select=$(id);
  if(!select)return '';
  const values=[...new Set(options.filter(x=>typeof x==='string'&&x.trim()))].sort((a,b)=>a.localeCompare(b));
  select.replaceChildren(new Option(placeholder,''));
  for(const value of values)select.append(new Option(value,value));
  const current=values.includes(chosen)?chosen:'';
  select.value=current;select.disabled=!values.length;
  return current;
 }
 function currentFactoryOffer(){
  const offers=Array.isArray(marketSnapshot?.offers)?marketSnapshot.offers:[];
  if(!newAircraftChoice.maker||!newAircraftChoice.family||
    !newAircraftChoice.model||!newAircraftChoice.configuration)return null;
  const available=offers.filter(o=>
   o.manufacturer===newAircraftChoice.maker&&o.family===newAircraftChoice.family&&
   o.model===newAircraftChoice.model&&o.configuration===newAircraftChoice.configuration);
  const payment=newAircraftChoice.payment==='lease'?'lease':'purchase';
  return available.find(o=>o.transactionType===payment&&isReleasedFactoryOffer(o))||
   available.find(o=>o.transactionType===payment)||null;
 }
 function renderFactorySelectors(){
  const offers=Array.isArray(marketSnapshot?.offers)?marketSnapshot.offers:[];
  const maker=newAircraftChoice.maker=fillMarketSelect('new-maker',
   offers.map(o=>o.manufacturer),newAircraftChoice.maker,'Choose manufacturer');
  const families=offers.filter(o=>o.manufacturer===maker);
  const family=newAircraftChoice.family=fillMarketSelect('new-family',
   families.map(o=>o.family),newAircraftChoice.family,'Choose family');
  const models=families.filter(o=>o.family===family);
  const model=newAircraftChoice.model=fillMarketSelect('new-model',
   models.map(o=>o.model),newAircraftChoice.model,'Choose model');
  const configs=models.filter(o=>o.model===model);
  newAircraftChoice.configuration=fillMarketSelect('new-configuration',
   configs.map(o=>o.configuration),newAircraftChoice.configuration,'Choose configuration');
  const payment=$('new-payment');
  if(payment)payment.value=newAircraftChoice.payment;
 }
 function updateNewOrderAvailability(){
  const offers=Array.isArray(marketSnapshot?.offers)?marketSnapshot.offers:[];
  const approved=offers.filter(isReleasedFactoryOffer);
  const offer=currentFactoryOffer();
  cabinConfigurationManager?.setFactoryAircraft(offer);
  const factoryPlan=cabinConfigurationManager?.getFactoryPlan();
  const payment=newAircraftChoice.payment;
  const enabled=marketIsOpen()&&payment==='cash'&&isReleasedFactoryOffer(offer)&&
   (!factoryPlan||factoryPlan.standard===true)&&typeof data.fleetClient?.acquire==='function';
  const select=$('market-offer-select'),buy=$('market-acquire'),quote=$('new-aircraft-quote');
  if(select)select.value=offer?.offerId||'';
  if(buy)buy.disabled=!enabled;
  if(quote){
   if(!offer)quote.textContent='Choose manufacturer, family, model and configuration to view a factory price.';
   else {
    const historical=offer.referencePriceUsd&&offer.priceEvidence==='manufacturer_list_2018'?
     ' · Historical '+offer.referencePriceYear+' list price '+usd(offer.referencePriceUsd):
     ' · Historical sale price not verified (model comparison uses an estimated reference value)';
    const stock=Number(offer.stockUnits||0);
    const date=offer.estimatedDeliveryUtc?new Date(offer.estimatedDeliveryUtc):null;
    const dateLabel=date&&!Number.isNaN(date.getTime())?
     date.toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}):'Not available';
    const price=payment==='lease'?
     usd(offer.recurringMonthlyUsd)+'/month, deposit '+usd(offer.upfrontPriceUsd):
     usd(offer.upfrontPriceUsd)+' cash game price';
    const readiness=payment==='credit'?
     'Credit financing is not available until loan repayments and ownership accounting are implemented.':
     payment==='lease'?'Lease contract and recurring billing are not available yet.':
     isReleasedFactoryOffer(offer)?'Approved cash purchase offer.':'Catalog preview only; this configuration cannot be ordered yet.';
    quote.textContent=offer.manufacturer+' '+offer.model+' · '+prettyFleetText(offer.configuration)+
     ' · '+price+historical+' · '+(stock>0?'In factory stock ('+stock+' available)':
     'Made to order ('+String(offer.manufacturerDailyCapacity||'—')+' aircraft/day manufacturer capacity)')+
     ' · Indicative delivery '+dateLabel+' · '+readiness;
   }
  }
  const info=$('market-state');
  if(info){
   if(!marketSnapshot)info.textContent='New-aircraft catalog unavailable until your verified airline is connected.';
   else if(!offers.length)info.textContent='No current-production aircraft offers found.';
   else info.textContent=String(new Set(offers.map(o=>o.configurationId)).size)+
    ' configurations · '+approved.length+' approved cash offers · '+
    (marketIsOpen()?'Market open for approved cash orders.':
     'World 1 market not yet open; all selections are preview only.');
  }
 }
 function renderUsedMarketSelectors(){
  const all=Array.isArray(usedMarketSnapshot?.catalog)?usedMarketSnapshot.catalog:[];
  usedMarketChoice.maker=fillMarketSelect('used-maker',all.map(x=>x.manufacturer),usedMarketChoice.maker,'All manufacturers');
  const families=all.filter(x=>!usedMarketChoice.maker||x.manufacturer===usedMarketChoice.maker);
  usedMarketChoice.family=fillMarketSelect('used-family',families.map(x=>x.family),usedMarketChoice.family,'All families');
  const models=families.filter(x=>!usedMarketChoice.family||x.family===usedMarketChoice.family);
  usedMarketChoice.model=fillMarketSelect('used-model',models.map(x=>x.model),usedMarketChoice.model,'All models');
  const configs=models.filter(x=>!usedMarketChoice.model||x.model===usedMarketChoice.model);
  usedMarketChoice.configuration=fillMarketSelect('used-configuration',configs.map(x=>x.configuration),usedMarketChoice.configuration,'All configurations');
  if($('used-market-payment'))$('used-market-payment').value=usedMarketChoice.payment;
 }
 function showUsedBidPanel(offer){
  const panel=$('used-market-bid-panel');
  if(!panel)return;
  const canBid=marketIsOpen()&&!!offer&&!offer.myHighestBid&&
   usedMarketChoice.payment==='cash'&&offer.offeringType==='purchase'&&
   typeof data.fleetClient?.bidUsed==='function'&&
   (offer.status==='available'||(offer.status==='bidding'&&
    Date.parse(offer.closeAfterUtc)>Date.now()));
  selectedUsedListingId=canBid?offer.listingId:null;
  panel.hidden=!canBid;
  if(!canBid)return;
  const next=Number(offer.highestBidUsd===null||offer.highestBidUsd===undefined?
    offer.openingBidUsd:Number(offer.highestBidUsd)+Number(offer.minIncrementUsd));
  if($('used-market-bid-title'))$('used-market-bid-title').textContent=
   'Bid: '+aircraftDisplayName(offer.manufacturer,offer.model);
  if($('used-market-bid-info'))$('used-market-bid-info').textContent=
   (offer.offeringType==='lease'?'Monthly lease bid. Fixed refundable deposit: '+
     usd(offer.leaseDepositUsd)+' · Lease term '+offer.leaseMonths+' months.':
     'Purchase bid. Full bid amount is reserved immediately.')+
   ' Minimum bid: '+usd(next)+'. Each valid higher bid restarts 15 minutes.';
  if($('used-market-bid-amount')){
   $('used-market-bid-amount').value=next.toFixed(2);
   $('used-market-bid-amount').min=next.toFixed(2);
  }
  if($('used-market-bid-registration'))$('used-market-bid-registration').value='';
  if($('used-market-bid-feedback'))$('used-market-bid-feedback').textContent='';
  if($('used-market-bid-confirm'))$('used-market-bid-confirm').disabled=false;
 }
 function renderUsedMarket(){
  const host=$('used-market-lots'),state=$('used-market-state');
  if(!host)return;
  host.replaceChildren();
  const result=usedMarketSnapshot;
  const entries=Array.isArray(result?.offers)?result.offers:[];
  renderUsedMarketSelectors();
  if(state)state.textContent=!data.connected?'Sign in to a verified airline to view the aircraft market.':
   !result?'Loading or unable to read used-aircraft auctions.':
   String(result.total)+' used listings match your filters · '+
   (result.marketOpen?'Bidding active. Highest bid after 15 minutes without a higher bid wins.':
    'Bidding not active. World 1 is still '+String(result.worldState||'not released')+'.')+
   (!result.leaseEnabled?' Lease offers are browse-only until billing is operational.':'');
  if(result&&!entries.length){
   const none=doc.createElement('p');none.className='hint';
   none.textContent='No matching aircraft on this page. Try another model or category.';
   host.append(none);
  }
  for(const aircraft of entries){
   const row=doc.createElement('article');row.className='used-market-aircraft';row.setAttribute('role','listitem');
   const identity=doc.createElement('div');identity.className='used-market-aircraft-identity';
   const title=doc.createElement('strong');
   title.textContent=aircraftDisplayName(aircraft.manufacturer,aircraft.model);
   const subtitle=doc.createElement('small');subtitle.textContent=
    'Seller: '+String(aircraft.sellerName||'Fictional seller')+
    ' (fictional) · '+(new Date().getFullYear()-Number(aircraft.manufactureYear))+
    ' years old · '+aircraft.conditionPct+'% condition · C check estimated in '+
    Number(aircraft.nextCCheckInHours).toLocaleString('en-US')+' h';
   identity.append(title,subtitle);
   const price=doc.createElement('div');price.className='used-market-aircraft-price';
   const priceLabel=doc.createElement('strong');priceLabel.textContent=
    usd(aircraft.highestBidUsd||aircraft.openingBidUsd)+
    (aircraft.offeringType==='lease'?'/month':' purchase');
   const secondary=doc.createElement('small');secondary.textContent=
    (aircraft.offeringType==='lease'?'Lease '+aircraft.leaseMonths+' mo · deposit '+usd(aircraft.leaseDepositUsd):
      'Cash auction · minimum rise '+usd(aircraft.minIncrementUsd))+
    ' · '+(aircraft.priceEvidence==='manufacturer_list_2018'?
      '2018 list '+usd(aircraft.referencePriceUsd):
      'New-value estimate '+usd(aircraft.provisionalNewValueUsd));
   price.append(priceLabel,secondary);
   const timer=doc.createElement('span');timer.className='used-market-auction-timer';
   const deadline=aircraft.closeAfterUtc?Date.parse(aircraft.closeAfterUtc):NaN;
   timer.textContent=aircraft.status!=='bidding'?'No bids · no expiry':
    Number.isFinite(deadline)&&deadline>Date.now()?
    'Ends '+new Date(deadline).toLocaleString('en-GB',{dateStyle:'short',timeStyle:'short'})+
     ' · '+aircraft.bidCount+' bid(s)':
    'Bid window ended · awaiting award';
   const action=doc.createElement('button');action.className='secondary';
   action.type='button';action.dataset.usedMarketSelect=aircraft.listingId;
   const canBid=result?.marketOpen===true&&typeof data.fleetClient?.bidUsed==='function'&&
    usedMarketChoice.payment==='cash'&&aircraft.offeringType==='purchase'&&
    !aircraft.myHighestBid&&
    (aircraft.status==='available'||(Number.isFinite(deadline)&&deadline>Date.now()));
   action.disabled=!canBid;
   action.className='route-text-action';
   action.textContent=aircraft.myHighestBid?'Your bid leads':
    canBid?'Place bid':usedMarketChoice.payment!=='cash'?'Financing not active':
     result?.marketOpen?'Unavailable':'Not open';
   row.append(identity,price,timer,action);
   host.append(row);
  }
  const page=$('used-market-page');
  if(page)page.textContent=result?'Page '+(usedMarketPage+1)+' of '+
   Math.max(1,Math.ceil(result.total/result.pageSize)):'Page 1';
  const previous=$('used-market-prev'),next=$('used-market-next');
  if(previous)previous.disabled=!result||usedMarketPage===0;
  if(next)next.disabled=!result||(usedMarketPage+1)*result.pageSize>=result.total;
  updateNewOrderAvailability();
 }
 async function loadUsedMarket(){
  const ticket=++usedMarketFetchVersion;
  const airlineId=data.airline?.id;
  const client=data.fleetClient;
  if(!data.connected||!airlineId||typeof client?.listUsed!=='function'){
   usedMarketSnapshot=null;renderUsedMarket();return;
  }
  try{
   const result=await client.listUsed({airlineId,page:usedMarketPage,
    filterMode:usedMarketFilter,search:usedMarketSearch,
    manufacturer:usedMarketChoice.maker,family:usedMarketChoice.family,
    model:usedMarketChoice.model,configuration:usedMarketChoice.configuration});
   if(ticket!==usedMarketFetchVersion||data.airline?.id!==airlineId)return;
   if(result?.airlineId!==airlineId||!Array.isArray(result.offers)||
     !Number.isInteger(result.total)||result.total<0||
     result.page!==usedMarketPage||typeof result.marketOpen!=='boolean'||
     !Array.isArray(result.catalog)||result.pageSize!==30)throw Error('Invalid used market response');
   usedMarketSnapshot=result;
   renderUsedMarket();
  }catch{
   if(ticket!==usedMarketFetchVersion)return;
   usedMarketSnapshot=null;renderUsedMarket();
   if($('used-market-state'))$('used-market-state').textContent=
    'Unable to load owner-verified used-market listings. No money or aircraft was changed.';
  }
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
    const msg=doc.createElement('p');msg.className='fleet-empty';
    msg.textContent=snapshot?'No owned or leased aircraft in this airline yet.':'Verified fleet data unavailable.';
    fleetList.append(msg);
   }
   for(const aircraft of fleet){
    const row=doc.createElement('div');row.className='fleet-inventory-row';row.setAttribute('role','row');
    const identity=doc.createElement('div');identity.className='fleet-identity';identity.setAttribute('role','cell');
    const title=doc.createElement('strong');
    title.textContent=(aircraftDisplayName(aircraft.manufacturer,aircraft.model)||'Aircraft')+
     ' · '+String(aircraft.registration||'Registration not available')+
     (aircraft.nickname?' ('+aircraft.nickname+')':'');
    identity.append(title);
    const cell=(value,css='')=>{
     const el=doc.createElement('span');el.setAttribute('role','cell');
     if(css)el.className=css;
     el.textContent=value;return el;
    };
    const seat=cell(fleetSeatLabel(aircraft));
    const configuration=cell(fleetConfigurationLabel(aircraft));
    const cargo=cell(fleetCargoLabel(aircraft));
    const location=cell(fleetLocationLabel(aircraft));
    const state=cell(fleetStateLabel(aircraft),'fleet-status-text');
    const action=doc.createElement('div');action.className='fleet-row-action';action.setAttribute('role','cell');
    const open=doc.createElement('button');open.type='button';open.className='secondary fleet-view-button';
    open.dataset.fleetAircraftOpen=String(aircraft.id||'');open.textContent='View';
    action.append(open);
    row.append(identity,seat,configuration,cargo,location,state,action);
    fleetList.append(row);
   }
  }
  renderAircraftDetail();
  if(selectedFleetAircraftId&&fleet.some(x=>x.id===selectedFleetAircraftId)){
   void loadMaintenancePreview(selectedFleetAircraftId);
  }
  const offerList=$('market-offers'),select=$('market-offer-select');
  if(offerList)offerList.replaceChildren();
  if(select){
   select.replaceChildren(new Option('Server-selected offer',''));
   for(const offer of offers)select.append(new Option(String(offer.offerId),String(offer.offerId)));
  }
  renderFactorySelectors();
  updateNewOrderAvailability();
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
   doc.dispatchEvent(new CustomEvent('airlinerra:fleet-fuel-updated',{detail:{airlineId}}));
  }catch(error){
   if(version!==marketFetchVersion)return;
   renderRealFleetMarket(null);
   doc.dispatchEvent(new CustomEvent('airlinerra:fleet-fuel-updated',{detail:{airlineId}}));
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
  const oldAirlineId=data.airline?.id||null;
  data={...data,...next};
  const airline=data.airline;
  try{cabinManager?.updateData(data)}catch{console.warn('Airlinerra flight services refresh unavailable')}
  try{cabinConfigurationManager?.updateData(data)}catch{
   console.warn('Cabin configuration refresh unavailable')
  }
  if((airline?.id||null)!==oldAirlineId){
   aircraftConfigurationDialog?.close();
   // Never present an earlier airline's inventory or bookings while the
   // new owner's asynchronous authenticated reads are still in progress.
   marketSnapshot=null;scheduleSnapshot=null;
   usedMarketSnapshot=null;usedMarketFetchVersion++;usedMarketPage=0;
   selectedUsedListingId=null;
   maintenanceLast=null;maintenanceFetchVersion++;
   aircraftPhotoId=null;aircraftPhotoToken++;resetPhotoDraft();
   selectedFleetAircraftId=/^#fleet-aircraft\/([0-9a-f-]{36})$/iu.exec(doc.defaultView?.location?.hash||'')?.[1]||null;
  }
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
  routePlannerController.updateData(data);
  void loadRealFleetMarket();
  void loadUsedMarket();
  void loadAirlineSchedule();
 }
 doc.getElementById('player-main')?.addEventListener('change',async event=>{
  if(event.target?.id!=='fleet-aircraft-image-file')return;
  const aircraft=marketSnapshot?.fleet?.find(a=>a.id===selectedFleetAircraftId);
  const file=event.target.files?.[0];
  if(!aircraft||!data.airline?.id||!data.aircraftMedia?.uploadAircraftImage||!file)return;
  const request=++aircraftPhotoToken;
  resetPhotoDraft();
  const status=$('fleet-aircraft-image-status');
  if(status)status.textContent='Preparing this aircraft picture…';
  try{
   const converted=await processAircraftPhoto(file);
   if(request!==aircraftPhotoToken||selectedFleetAircraftId!==aircraft.id)return;
   photoBlob=converted;photoPendingId=aircraft.id;
   photoPreviewUrl=URL.createObjectURL(converted);
   setAircraftPhoto(photoPreviewUrl);
   const save=$('fleet-aircraft-image-save');if(save)save.disabled=false;
   if(status)status.textContent='Preview only. Click Save this aircraft image to store it privately.';
  }catch(error){
   if(request!==aircraftPhotoToken)return;
   if(status)status.textContent=String(error?.message||'Unable to process the image.');
  }
 });
 for(const id of ['maker','family','model','configuration','payment']){
  $('new-'+id)?.addEventListener('change',()=>{
   if(id==='payment')newAircraftChoice.payment=$('new-payment').value;
   else {
    newAircraftChoice[id]=$('new-'+id).value;
    const steps=['maker','family','model','configuration'];
    for(const following of steps.slice(steps.indexOf(id)+1))newAircraftChoice[following]='';
   }
   renderFactorySelectors();updateNewOrderAvailability();
  });
 }
 for(const id of ['maker','family','model','configuration']){
  $('used-'+id)?.addEventListener('change',()=>{
   usedMarketChoice[id]=$('used-'+id).value;
   const hierarchy=['maker','family','model','configuration'];
   for(const later of hierarchy.slice(hierarchy.indexOf(id)+1))usedMarketChoice[later]='';
   renderUsedMarketSelectors();
  });
 }
 $('used-market-payment')?.addEventListener('change',()=>{
  usedMarketChoice.payment=$('used-market-payment').value;renderUsedMarket();
 });
 doc.getElementById('player-main')?.addEventListener('click',async event=>{
  const openAircraft=event.target.closest('[data-fleet-aircraft-open]');
  if(openAircraft){
   const aircraftId=openAircraft.dataset.fleetAircraftOpen;
   if(!marketSnapshot?.fleet?.some(a=>a.id===aircraftId))return;
   aircraftConfigurationDialog?.close();
   selectedFleetAircraftId=aircraftId;
   cabinConfigurationManager?.selectAircraft(aircraftId);
   renderAircraftDetail();
   void loadMaintenancePreview(aircraftId);
   if(typeof goTo==='function')goTo('fleet-aircraft/'+aircraftId);
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
  const selectedUsed=event.target.closest('[data-used-market-select]');
  if(selectedUsed){
   const offer=usedMarketSnapshot?.offers?.find(x=>x.listingId===selectedUsed.dataset.usedMarketSelect);
   showUsedBidPanel(offer);
   return;
  }
  const nav=event.target.closest('[data-workspace-go]');
  if(nav){const to=nav.dataset.workspaceGo;
   if(to==='cabin-configurations'&&selectedFleetAircraftId)
    cabinConfigurationManager?.selectAircraft(selectedFleetAircraftId);
   if(AIRLINE_UI_VIEWS.includes(to)&&typeof goTo==='function')goTo(to);
   if(to==='fleet'||to==='aircraft-new-orders')void loadRealFleetMarket();
   if(to==='aircraft-new-orders'||to==='aircraft-market')void loadUsedMarket();
   return;}
  const id=event.target.closest('button')?.id;
  if(!id)return;
  if(id==='fleet-configuration-change'){
   await aircraftConfigurationDialog?.open();
   return;
  }
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
  if(id==='used-market-find'||id==='used-market-refresh'||
     id==='used-market-prev'||id==='used-market-next'){
   if(id==='used-market-find'){
    usedMarketPage=0;
    usedMarketSearch=String($('used-market-search')?.value||'').trim().slice(0,60);
    usedMarketFilter=['all','purchase','lease'].includes($('used-market-mode')?.value)?
      $('used-market-mode').value:'all';
    for(const [key,id] of [['maker','used-maker'],['family','used-family'],
      ['model','used-model'],['configuration','used-configuration']])
     usedMarketChoice[key]=String($(id)?.value||'');
   }
   if(id==='used-market-prev')usedMarketPage=Math.max(0,usedMarketPage-1);
   if(id==='used-market-next'&&usedMarketSnapshot&&
       (usedMarketPage+1)*usedMarketSnapshot.pageSize<usedMarketSnapshot.total)
    usedMarketPage++;
   selectedUsedListingId=null;
   if($('used-market-bid-panel'))$('used-market-bid-panel').hidden=true;
   if($('used-market-state'))$('used-market-state').textContent='Refreshing approved auction listings…';
   await loadUsedMarket();
   return;
  }
  if(id==='used-market-bid-cancel'){
   selectedUsedListingId=null;
   if($('used-market-bid-panel'))$('used-market-bid-panel').hidden=true;
   return;
  }
  if(id==='used-market-bid-confirm'){
   const offer=usedMarketSnapshot?.offers?.find(x=>x.listingId===selectedUsedListingId);
   const feedback=$('used-market-bid-feedback');
   const button=$('used-market-bid-confirm');
   const amount=String($('used-market-bid-amount')?.value||'').trim();
   const registration=String($('used-market-bid-registration')?.value||'').trim().toUpperCase();
   if(!offer||!marketIsOpen()||!data.fleetClient?.bidUsed||
     usedMarketChoice.payment!=='cash'||offer.offeringType!=='purchase'){
    if(feedback)feedback.textContent='Bidding is not available for this listing.';
    return;
   }
   const minimum=Number(offer.highestBidUsd===null||offer.highestBidUsd===undefined?
    offer.openingBidUsd:Number(offer.highestBidUsd)+Number(offer.minIncrementUsd));
   if(!/^[1-9][0-9]{2,11}(?:\.[0-9]{1,2})?$/.test(amount)||
      !Number.isFinite(minimum)||Number(amount)<minimum){
    if(feedback)feedback.textContent='Bid must be at least '+usd(minimum)+' with no more than two decimal places.';
    return;
   }
   if(!/^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$/.test(registration)){
    if(feedback)feedback.textContent='Choose a unique registration with 4–20 letters, digits or hyphens.';
    return;
   }
   const requestId=doc.defaultView?.crypto?.randomUUID?.();
   if(!requestId){
    if(feedback)feedback.textContent='Secure request identifier unavailable. No money was reserved.';
    return;
   }
   const airlineId=data.airline?.id;
   if(!airlineId)return;
   button.disabled=true;
   if(feedback)feedback.textContent='Submitting owner-verified bid and reserving funds…';
   try{
    const result=await data.fleetClient.bidUsed({
     airlineId,listingId:offer.listingId,bidUsd:amount,registration,requestId
    });
    if(!['bid_accepted','accepted_replay'].includes(result?.status)||
       result.listingId!==offer.listingId||!result.bidId)
     throw Error('Bid not confirmed');
    if(feedback)feedback.textContent='Bid accepted by the server. '+
     (result.cashReservedAgain?'Funds reserved. ':'No additional funds reserved. ')+
     'Auction closes after 15 minutes without another higher bid.';
    selectedUsedListingId=null;
    await Promise.all([loadUsedMarket(),loadRealFleetMarket()]);
   }catch(error){
    const msg=String(error?.message||'');
    if(feedback)feedback.textContent=
     msg.includes('INSUFFICIENT_AIRLINE_CASH')?'Bid refused: insufficient airline cash.':
     msg.includes('AUCTION_BID_BELOW_REQUIRED_AMOUNT')?'A higher bid arrived first. Refresh to see the new minimum.':
     msg.includes('AIRCRAFT_MARKET_NOT_OPEN')?'The marketplace is not yet open. No funds were reserved.':
     'Bid could not be confirmed. Refresh the listing before trying again.';
   }finally{button.disabled=false;}
   return;
  }
  if(id==='market-acquire'){
   const select=$('market-offer-select'),entry=$('market-aircraft-registration');
   const feedback=$('market-feedback'),button=$('market-acquire');
   const offer=marketSnapshot?.offers?.find(item=>item.offerId===select?.value);
   const registration=String(entry?.value||'').trim().toUpperCase();
   if(newAircraftChoice.payment!=='cash'||cabinConfigurationManager?.getFactoryPlan()?.standard===false||
    !isReleasedFactoryOffer(offer)||
    offer?.offerId!==currentFactoryOffer()?.offerId||
    !data.airline?.id||!data.fleetClient?.acquire||!marketIsOpen()){
    if(feedback)feedback.textContent='Factory orders are not open yet. No funds were charged.';
    return;
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
   }finally{updateNewOrderAvailability();}
   return;
  }
  if(id==='fleet-aircraft-image-save'){
   const aircraft=marketSnapshot?.fleet?.find(a=>a.id===selectedFleetAircraftId);
   const status=$('fleet-aircraft-image-status'),save=$('fleet-aircraft-image-save');
   if(!aircraft||!photoBlob||photoPendingId!==aircraft.id||
      !data.airline?.id||!data.aircraftMedia?.uploadAircraftImage){
    if(status)status.textContent='Choose an image for this owned aircraft first.';return;
   }
   const airlineId=data.airline.id,aircraftId=aircraft.id;
   if(save)save.disabled=true;if(status)status.textContent='Saving this individual aircraft picture…';
   try{
    await data.aircraftMedia.uploadAircraftImage({airlineId,aircraftInventoryId:aircraftId,blob:photoBlob});
    if(data.airline?.id!==airlineId||selectedFleetAircraftId!==aircraftId)return;
    await refreshAircraftPhoto(aircraft,true);
    if(status)status.textContent='Aircraft picture saved. Other aircraft and catalog images were not changed.';
   }catch{
    if(status)status.textContent='Picture upload failed. No existing aircraft image was replaced.';
    if(save)save.disabled=!photoBlob;
   }
   return;
  }
  if(id==='fleet-aircraft-image-reset'){
   const aircraft=marketSnapshot?.fleet?.find(a=>a.id===selectedFleetAircraftId);
   const status=$('fleet-aircraft-image-status');
   if(!aircraft||!data.airline?.id||!data.aircraftMedia?.removeAircraftImage)return;
   if(doc.defaultView?.confirm?.('Remove the custom picture for this aircraft and show its standard model image?')===false)return;
   const airlineId=data.airline.id,id=aircraft.id;
   try{
    await data.aircraftMedia.removeAircraftImage({airlineId,aircraftInventoryId:id});
    if(data.airline?.id!==airlineId||selectedFleetAircraftId!==id)return;
    await refreshAircraftPhoto(aircraft,true);
    if(status)status.textContent='Standard model picture restored for this aircraft only.';
   }catch{
    if(status)status.textContent='Custom picture could not be removed. No other aircraft changed.';
   }
   return;
  }
  if(id==='fleet-detail-save'){
   const aircraft=marketSnapshot?.fleet?.find(a=>a.id===selectedFleetAircraftId);
   const input=$('fleet-detail-nickname'),feedback=$('fleet-detail-feedback');
   const nickname=String(input?.value||'').trim();
   if(!aircraft||!data.airline?.id||!data.fleetClient?.updateNickname){
    if(feedback)feedback.textContent='Aircraft nickname editing is unavailable.';return;
   }
   if(nickname.length>40||/[\u0000-\u001F\u007F]/u.test(nickname)){
    if(feedback)feedback.textContent='Use a nickname of up to 40 characters without control symbols.';return;
   }
   const save=$('fleet-detail-save');
   save.disabled=true;if(feedback)feedback.textContent='Saving aircraft nickname…';
   try{
    const updated=await data.fleetClient.updateNickname({
     airlineId:data.airline.id,aircraftInventoryId:aircraft.id,nickname
    });
    if(updated?.id!==aircraft.id)throw Error('Nickname response mismatch');
    marketSnapshot={...marketSnapshot,fleet:marketSnapshot.fleet.map(a=>
     a.id===aircraft.id?{...a,nickname:updated.nickname||null}:a)};
    renderRealFleetMarket(marketSnapshot);
    if(feedback)feedback.textContent='Aircraft nickname saved.';
   }catch{
    if(feedback)feedback.textContent='Could not save the nickname. Please try again.';
   }finally{save.disabled=false;}
   return;
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
  if(id==='schedule-day-prev'||id==='schedule-day-next'){
   scheduleSelectedDay=(scheduleSelectedDay+(id==='schedule-day-next'?1:6))%7;
   renderSchedule();
   return;
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
  doc,getData:()=>data,loadDraft:()=>safelyLoad(session,draftKey)||{},draftWrite,
  getCabinState:()=>({packages:cabinManager?.getPackages()||[],
   ready:cabinManager?.isReady()===true}),
  getFuelAircraft:aircraftId=>data.connected&&marketSnapshot?.airlineId===data.airline?.id?
   marketSnapshot.fleet?.find(a=>a.id===aircraftId)||null:null
 });
 doc.addEventListener('airlinerra:route-draft-saved',()=>{
  renderSchedule();
  void loadAirlineSchedule();
 });
 applyPreferences();loadDraftForms();
 return Object.freeze({updateData,
  openFleetAircraft:hash=>{
   const id=/^#fleet-aircraft\/([0-9a-f-]{36})$/iu.exec(String(hash||''))?.[1]||null;
   selectedFleetAircraftId=id;renderAircraftDetail();
  },
  getLandingView:()=>preferences.landing,formatDistance:km=>
  preferences.units==='mi'?(Number(km)*0.621371).toFixed(0)+' mi':Number(km).toFixed(0)+' km'});
}
