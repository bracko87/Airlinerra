/** Full route planning workspace, not commercial flight activation.
 * Authenticated airport reads and owner-verified planning drafts; never activates flights.
 */
import {createAirportCountryPicker,populateAirportCountries,airportFlag,airportCountryName} from './airport-country-picker.mjs';
import {renderRouteMap,routeDistanceKm} from './route-map.mjs';
import {estimateFivePhaseFuel} from './flight-fuel-phase-engine.mjs';
import {renderTrafficRightIndicators} from './route-traffic-rights.mjs';
import {checkedRouteFeeBaseline} from './route-fee-preview.mjs';
import {previewAirportFuelPrice} from './airport-fuel-price-preview.mjs';
import {buildAircraftWeeklyTimeline,renderAircraftWeeklyTimeline} from './aircraft-weekly-timeline.mjs';
import {assessAircraftRouteRunways} from './route-aircraft-runway-screen.mjs';
import {createBasicCabinPackage} from './cabin-services-manager.mjs';
import {planningClockEstimate} from './route-planning-times.mjs';
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
 'aria-hidden="true" tabindex="-1" disabled><option value="">Select airport</option></select>'+
 '<p id="route-'+side+'-count" class="hint" role="status">Choose a country or search all airports.</p>'+
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
 weekRow('Arrival (estimate)',(_,i)=>'<output id="route-arrival-'+i+'" class="route-week-estimate">—</output>')+
 weekRow('Ready after turnaround (estimate)',(_,i)=>'<output id="route-next-departure-'+i+'" class="route-week-estimate">—</output>')+
 '</div></div>';
const routeSetupField=(id,label,input)=>'<label class="route-setup-field" for="'+id+'"><span>'+label+'</span>'+input+'</label>';
const optionalFare=(id,label)=>routeSetupField(id,label,
 '<div class="route-fare-input"><span>$</span><input id="'+id+'" type="number" min="0" max="100000" step="1" inputmode="decimal" placeholder="Not set"></div>');
/** Keep game-designed fictional runway lengths separate from observed runways. */
export function routeLongestRunwayLabel(profile){
 const longest=Array.isArray(profile?.runways)?
  profile.runways.filter(r=>Number.isFinite(r?.lengthM)&&r.lengthM>0)
   .reduce((m,r)=>Math.max(m,r.lengthM),0):0;
 if(longest>0)return Math.round(longest).toLocaleString('en-US')+' m';
 const designed=profile?.gameRunwayDesign;
 if(typeof profile?.key==='string'&&profile.key.startsWith('FICTIONAL:')&&
  designed?.status==='fictional_game_only'&&
  Number.isFinite(designed.lengthM)&&designed.lengthM>0)
  return Math.round(designed.lengthM).toLocaleString('en-US')+' m';
 return 'Unverified';
}
/** Match airport titles to ICAO-style codes used throughout route selection. */
export function routeAirportIcaoCode(profile,choice){
 const choices=[profile?.icao,profile?.code,choice?.icao,choice?.code,
  profile?.airportCode,choice?.airportCode];
 return choices.find(v=>typeof v==='string'&&/^[A-Z]{4}$/.test(v))||null;
}
/** Summarize the GAME rules stored for an airport without treating
 * missing third-party research as an active ban or inventing an ICAO chapter.
 * Hard operational restrictions remain enforced by their separate preflight. */
export function routeAirportGameRules(profile){
 const simple=profile?.operations?.simpleNightNoise||{};
 const full=profile?.operations?.icaoNoiseRules||{};
 const window=typeof simple.nighttimeWindow==='string'&&simple.nighttimeWindow.trim()?
  ' · '+simple.nighttimeWindow.trim().replace(/-/g,'–'):'';
 const curfew=simple.nighttimeBan===true?'Yes'+window:
  simple.nighttimeBan===false?'No':'—';
 const chapterNumbers=arr=>Array.isArray(arr)?
  [...new Set(arr.filter(x=>Number.isInteger(x)&&x>0))].sort((a,b)=>a-b):[];
 const prohibited=chapterNumbers(full.prohibitedChapters);
 const permitted=chapterNumbers(simple.permittedChapters);
 const specific=chapterNumbers((full.rules||[]).map(r=>r.chapter));
 const minimum=Number.isInteger(full.nationalCivilJetMinimumChapter)&&
  full.nationalCivilJetMinimumChapter>0?full.nationalCivilJetMinimumChapter:null;
 let noise='—';
 if(prohibited.length)noise='No Chapter '+prohibited.join(', ');
 else if(minimum)noise='Chapter '+minimum+' minimum';
 else if(specific.length)noise='Chapter '+specific.join(', ');
 else if(simple.noiseRestrictions===true&&permitted.length)
  noise='Chapter '+permitted.join(', ');
 else if(simple.noiseRestrictions===false)noise='No Chapter restriction';
 else if(simple.noiseRestrictions===true)noise='Chapter data pending';
 return {curfew,noise};
}
const routeAirportBlock=(side,title)=>
 '<section class="route-airport-block" aria-label="'+title+' airport facts">'+
  '<h4 id="route-'+side+'-title">'+title+' airport</h4>'+
  '<div id="route-'+side+'-restrictions" class="route-airport-rule-list" aria-live="polite">Airport rules loading…</div>'+
  '<div id="route-'+side+'-demand" class="route-airport-demand" aria-live="polite">Demand data pending</div>'+
 '</section>';
const routeCheckDetails =
 '<p class="hint">Airport facts and demand are planning references, not operating permission. Unknown or estimated values are not verified approvals.</p>'+
 '<div class="route-general-summary" aria-label="General route information">'+
  '<div class="route-check-item"><span>Distance</span><strong id="route-distance">Select airports</strong></div>'+
  '<div class="route-check-item"><span>Estimated flight duration</span><strong id="route-block-time">Aircraft required</strong></div>'+
  '<div class="route-check-item"><span>Market</span><strong id="route-market">Select airports</strong></div>'+
 '</div>'+
 '<div class="route-airport-columns">'+
  routeAirportBlock('origin','Origin')+
  routeAirportBlock('destination','Destination')+
 '</div>'+
 '<div class="route-rights-note"><div class="route-rights-heading">'+
  '<strong>Passenger / cargo traffic rights</strong>'+
  '<details class="route-rights-info" id="route-rights-info">'+
   '<summary aria-label="Information about the nine freedoms of the air" title="What do these rights mean?">i</summary>'+
   '<div class="route-rights-info-content"><h4>Nine freedoms of the air</h4>'+
    '<p>International traffic rights depend on the airline’s home country, full itinerary, bilateral rules and verified game grants. The categories do not authorize a flight.</p>'+
    '<div id="route-rights-legend"></div>'+
    '<p>Domestic home-country flights have domestic operating requirements. Passenger and cargo grants may differ.</p>'+
   '</div></details></div>'+
  '<div id="route-rights-icons" class="route-rights-icons" aria-label="Nine international aviation rights"></div></div>'+
 '<div class="route-hidden-readouts" hidden aria-hidden="true">'+
  '<span id="route-status">Draft only</span>'+
  '<span id="route-weather-check"></span>'+
  '<span id="route-slot-check"></span>'+
 '</div>';
const aircraftPerformanceDetails=
 '<div hidden aria-hidden="true"><span id="route-aircraft-check"></span><span id="route-fuel-summary"></span><span id="route-rotation-check"></span></div>'+
 '<div class="route-flight-calculations">'+
  '<div><span>Aircraft cruise speed</span><strong id="route-cruise-speed">Pending aircraft model</strong></div>'+
  '<div><span>Estimated airborne time</span><strong id="route-airborne-time">Pending aircraft model</strong></div>'+
  '<div><span>Minimum turnaround</span><strong id="route-min-turnaround">45 min (game minimum)</strong></div>'+
 '</div>'+
 '<div id="route-fuel-phases" class="route-fuel-phases" aria-live="polite"></div>';
export function routePlannerMarkup(){
 return '<div class="route-planner-grid route-planner-first-step">'+
  section('STEP 1','Define your flight',
   '<p class="hint">Choose your flight number, origin and destination. Airport information is available for route evaluation; flight scheduling requires separate approval.</p>'+
   '<div class="route-flight-number-entry">'+
   field('route-plan-number','Flight number',
    '<div class="route-number-input"><span id="route-number-prefix">—</span>'+
    '<input id="route-plan-number" inputmode="numeric" type="text" autocomplete="off" pattern="[0-9]{1,4}" maxlength="4" placeholder="101"></div>')+
   '<p id="route-prefix-note" class="hint">Checking registered airline code...</p></div>'+
   '<div class="route-planner-airports">'+picker('from','Origin')+picker('to','Destination')+'</div>'+
   '<div class="workspace-actions route-step1-actions"><button type="button" id="route-plan-swap" class="secondary">Swap airports</button>'+
   '<button type="button" id="route-plan-preview" class="primary">Preview route</button></div>'+
   '<p id="route-feedback" class="hint" role="status"></p>')+
  section('ROUTE MAP','Geographic route preview',
   '<h3 id="route-map-heading" class="route-map-heading">Select two airports</h3>'+
   '<div id="route-map-canvas" class="route-map-canvas"></div>'+
   '<p id="route-map-feedback" class="hint">The map uses verified airport coordinates where available.</p>'+
   '<div class="route-map-facts"><h3>Route information and limitations</h3>'+routeCheckDetails+'</div>')+
 '</div>'+
 section('STEP 2','Aircraft and weekly departures',
  '<div class="route-step2-top">'+
   routeSetupField('route-aircraft','Aircraft','<select id="route-aircraft"><option value="">Choose aircraft</option></select>')+
   routeSetupField('route-arrival-stand','Arrival stand at destination','<select id="route-arrival-stand"><option value="terminal">Terminal</option><option value="remote">Remote stand (lower fees)</option><option value="cargo">Cargo stand</option></select>')+
   routeSetupField('route-turnaround','Target turnaround (minutes)','<input id="route-turnaround" type="number" min="45" max="360" step="15" value="45">')+
  '</div>'+
  '<p class="route-subtle-note" id="route-aircraft-feedback">Aircraft availability is not connected.</p>'+
  '<div hidden aria-hidden="true"><strong id="route-departure-stand-derived"></strong></div>'+
  '<p id="route-aircraft-position-status" class="route-position-status" role="status"></p>'+
  '<p class="hint">Aircraft rotation means checking that the airplane lands, is at the right airport and has completed its turnaround before its next departure. The 45-minute minimum is a game planning rule, not proof of available airport slots.</p>'+
  weekTable()+
  '<details class="route-inline-restrictions route-operation-checks"><summary>Advanced airport schedule checks</summary>'+
   '<p id="route-preflight-status" class="hint" role="status" aria-live="polite">Automatic runway, curfew and noise checks are pending.</p>'+
   '<p class="hint">Airport restrictions are checked automatically using selected weekly departure times. Exact UTC example times add optional screening; neither step books a flight.</p>'+
   '<div class="route-step2-top">'+
   routeSetupField('route-preflight-departure-utc','Example departure (UTC)', '<input id="route-preflight-departure-utc" type="datetime-local" step="60">')+
   routeSetupField('route-preflight-arrival-utc','Example arrival (UTC)', '<input id="route-preflight-arrival-utc" type="datetime-local" step="60">')+
   '</div></details>'+
  '<details class="route-aircraft-timeline-panel" id="route-aircraft-timeline"><summary>Aircraft weekly timeline and locations</summary><div id="route-aircraft-timeline-content"></div></details>'+
  '<div class="route-week-footer"><span id="route-flights" class="route-week-count">0 departures/week</span>'+
  '<span>Example next departures use entered UTC times; actual local arrival, slots and aircraft position are not yet verified.</span></div>'+
  '<p id="route-cycle-warning" class="hint" role="status" aria-live="polite"></p>'+
  '')+
 section('AIRCRAFT PERFORMANCE','Aircraft performance and fuel estimate',aircraftPerformanceDetails)+
 section('STEP 3','Ticket prices and onboard services',
  '<div class="route-pricing-grid">'+
   optionalFare('route-fare-economy','Economy fare')+
   optionalFare('route-fare-premium','Premium Economy fare')+
   optionalFare('route-fare-business','Business fare')+
   optionalFare('route-fare-first','First Class fare')+
  '</div>'+
  '<div class="route-service-grid">'+
   routeSetupField('route-cabin-package','Cabin service package','<select id="route-cabin-package"><option value="none">No onboard service</option><option value="basic">Basic Cabin Service</option></select>')+
   routeSetupField('route-baggage-service','Baggage package','<select id="route-baggage-service"><option value="standard">Standard</option><option value="hand-only">Hand baggage only</option><option value="checked">Checked baggage included</option></select>')+
   routeSetupField('route-cargo-service','Cargo on this flight','<select id="route-cargo-service"><option value="none">No cargo</option><option value="requested">Request belly cargo (unverified)</option></select>')+
  '</div>'+
  '<p class="route-subtle-note">The selected cabin package is saved with your route. Actual flight services and costs depend on real flights; no charges are made when creating a route.</p>'+
  routeSetupField('route-launch-delay','Preferred route launch', 
   '<select id="route-launch-delay">'+
    '<option value="0">As soon as operationally ready</option>'+
    '<option value="3">After 3 game days</option>'+
    '<option value="7">After 7 game days</option></select>')+
  '<p class="route-subtle-note">This saves a launch preference only. Automatic flight activation and ticket sales are not connected yet.</p>'+
  '<div class="workspace-actions route-apply-actions">'+
   '<button type="button" id="route-plan-save" class="primary">Create new route</button>'+
   '<button type="button" id="route-plan-new" class="secondary">Clear form</button>'+
   '<button type="button" class="route-text-action" data-workspace-go="route-list">My routes</button></div>'+
  '<p id="route-plan-status" class="hint" role="status" aria-live="polite"></p>'+
  '<div id="route-plan-review" class="workspace-detail"></div>')+
 section('FLIGHT COSTS','Estimated operating costs per flight',
  '<p class="hint">Estimated game rates only. When no verified origin stand exists, a terminal stand (cargo stand for cargo aircraft) is used for pricing only; it is not reserved. Passenger/cargo quantities are unknown. No airline charges are made.</p>'+
  '<div id="route-cost-breakdown" class="route-cost-breakdown" aria-live="polite"></div>')+
 section('OPERATIONAL SCHEDULE CHECKS','Schedules with verified airport slot reservations',
  '<p class="hint">Planning routes saved to your airline appear in My Routes. This separate section shows schedules that have passed the airport slot checks. These are not active flights.</p>'+
  '<div id="route-server-draft-list" class="workspace-detail"></div>'+
  '<p id="route-server-draft-status" class="hint" role="status" aria-live="polite"></p>')+
 '';
}
/** An airline route must connect two distinct approved airport identities. */
export function routeAirportPairStatus(origin,destination){
 if(!origin?.key||!destination?.key)return 'INCOMPLETE';
 return origin.key===destination.key?'SAME_AIRPORT':'VALID';
}
/** Real schedule mutation is never implied by read-only list or slot checks. */
/** Promote only a server-owned planning route with explicit UTC timetable.
 * Nothing here activates an aircraft, sells a ticket or creates finances.
 * The owner-verified slot-reservation API independently rechecks all inputs.
 */
export function operationalScheduleFromPlanningRoute(plan,airlineId){
 const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
 if(!plan||plan.status!=='planning'||!uuid.test(plan.planId||'')||
    !uuid.test(airlineId||'')||!uuid.test(plan.aircraftInventoryId||''))
  throw Error('PLANNING_ROUTE_NOT_VERIFIED');
 const dep=plan.referenceDepartureUtc,arr=plan.referenceArrivalUtc;
 const normalizedUtc=input=>{
  if(typeof input!=='string'||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(input))
   return null;
  const time=Date.parse(input);
  return Number.isFinite(time)?new Date(time).toISOString().slice(0,19)+'Z':null;
 };
 const departure=normalizedUtc(dep),arrival=normalizedUtc(arr);
 if(!departure||!arrival||Date.parse(arrival)<=Date.parse(departure)||
    Date.parse(arrival)-Date.parse(departure)>72*60*60*1000)
  throw Error('PLANNING_ROUTE_EXPLICIT_UTC_TIMES_REQUIRED');
 if(!/^[A-Z0-9]{2}[0-9]{1,4}$/.test(plan.flightNumber||'')||
    !/^(OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/.test(plan.originAirportKey||'')||
    !/^(OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/.test(plan.destinationAirportKey||'')||
    plan.originAirportKey===plan.destinationAirportKey)
  throw Error('PLANNING_ROUTE_AIRPORTS_NOT_VALID');
 const weekly=plan.schedule;
 if(!Array.isArray(weekly)||weekly.length<1||weekly.length>7||
    new Set(weekly.map(x=>x?.day)).size!==weekly.length||
    weekly.some(x=>!x||!Number.isInteger(x.day)||x.day<0||x.day>6||
     typeof x.time!=='string'||!/^([01]\d|2[0-3]):[0-5]\d$/.test(x.time)))
  throw Error('PLANNING_ROUTE_WEEKLY_TIMETABLE_NOT_VERIFIED');
 const out=plan.operation?.departureStand,into=plan.operation?.arrivalStand;
 if(!['terminal','remote','cargo'].includes(out)||
    !['terminal','remote','cargo'].includes(into))
  throw Error('PLANNING_ROUTE_AIRPORT_STANDS_REQUIRED');
 return Object.freeze({
  airlineId,aircraftInventoryId:plan.aircraftInventoryId,
  flightNumber:plan.flightNumber,
  originAirportKey:plan.originAirportKey,
  destinationAirportKey:plan.destinationAirportKey,
  referenceDepartureUtc:departure,referenceArrivalUtc:arrival,
  weeklySchedule:weekly.map(x=>({day:x.day,time:x.time})),
  departureStand:out,arrivalStand:into
 });
}

export const routeDraftSaveMode=scheduler=>
 typeof scheduler?.planSave==='function'?'server-planning':'browser';
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
export const validateFlightDraftOptions=({departureStand='terminal',arrivalStand,turnaroundMinutes,fares,
 onboard,baggage,cargo,cabinPackageId}={})=>{
 if(!['terminal','remote','cargo'].includes(departureStand)||
    !['terminal','remote','cargo'].includes(arrivalStand)||
  !Number.isInteger(turnaroundMinutes)||turnaroundMinutes<45||turnaroundMinutes>360||
  !['standard','basic','enhanced'].includes(onboard)||
  !['standard','hand-only','checked'].includes(baggage)||
  !['none','requested'].includes(cargo)||
   (cabinPackageId!==undefined&&!/^(?:none|basic|pkg-[1-9][0-9]{0,5})$/.test(cabinPackageId)))return null;
 const prices={};
 for(const key of ['economy','premium','business','first']){
  const raw=fares?.[key];
  if(raw===null||raw===undefined||String(raw).trim()===''){prices[key]=null;continue;}
  const amount=Number(raw);
  if(!Number.isSafeInteger(amount)||amount<0||amount>100000)return null;
  prices[key]=amount;
 }
 return {departureStand,arrivalStand,turnaroundMinutes,fares:prices,
  service:{onboard,baggage,cargo,...(cabinPackageId!==undefined?{cabinPackageId}:{})},operationallyVerified:false};
};
export const routeWeekdays=schedule=>{
 const rows=Array.isArray(schedule)?schedule:[];
 return dayShort.map((label,day)=>({label,active:rows.some(row=>row?.day===day)}));
};
/** Brief game flags in the route planner; a simple 'No' never cancels precise rules. */
export function airportRouteRestrictionSummary(profile){
 if(!profile)return 'Data pending';
 const longest=routeLongestRunwayLabel(profile);
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
export function createRoutePlanner({doc,getData,loadDraft,draftWrite,getCabinState,getFuelAircraft}={}){
 if(!doc||typeof getData!=='function'||typeof draftWrite!=='function')
  throw Error('Verified route planner data required');
 const $=id=>doc.getElementById(id);
 let cabinOptionAirlineId=null;
 let lastFuelEstimate=null;
 const cabinSnapshot=()=>{
  const value=typeof getCabinState==='function'?getCabinState():null;
  return {packages:Array.isArray(value?.packages)?value.packages:[createBasicCabinPackage()],
   ready:value?.ready===true};
 };
 let feeBaseline=null,feeRequestKey=null,feeRequestSerial=0;
 let displayedFuel=null,displayedPrice=null,feeRequestStatus='Choose a route and airline aircraft';
 const renderCostBreakdown=()=>{
  const host=$('route-cost-breakdown');if(!host)return;
  host.replaceChildren();
  // After a successful route save the form resets for the next route.
  // Do not display a wall of missing costs against an empty form.
  if(!displayedFuel&&!feeBaseline&&feeRequestStatus.startsWith('Choose ')){
   const note=doc.createElement('p');note.className='hint';
   note.textContent='Select an aircraft and two airports to see the next route estimate.';
   host.append(note);return;
  }
  const money=value=>typeof value==='number'&&Number.isFinite(value)?
   '$'+value.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2}):
   'Rate unavailable';
  const fuel=displayedFuel,price=displayedPrice;
  const items=[
   ['Trip fuel (neutral 50% load)',fuel?.estimatedBurnCostUsd??null,
    fuel?.tripFuelKg&&price?.usdPerKg?
     Math.round(fuel.tripFuelKg).toLocaleString('en-US')+' kg × modelled $'+
     price.usdPerKg.toFixed(3)+'/kg':'Aircraft or fuel rate pending'],
   ...(feeBaseline?
    [...feeBaseline.fixedRows.map(x=>[x.label,x.amountUsd,x.evidence]),
     ...feeBaseline.unknownRows.map(x=>[x.label,null,x.evidence])]:
    [['Airport movement, landing, handling and navigation',null,feeRequestStatus],
     ['Passenger / cargo airport charges',null,'Real passenger/cargo quantities not available']]),
   ['Aircraft maintenance / wear',null,'Per-flight cost allocation not connected'],
   ['Onboard service / catering',null,'Final passengers and package costs pending'],
   ['Aircraft finance / leasing allocation',null,'Per-flight aircraft cost allocation not verified']
  ];
  for(const [name,amount,detail] of items){
   const row=doc.createElement('div');row.className='route-cost-line';
   const left=doc.createElement('div');
   const title=doc.createElement('strong');title.textContent=name;
   const note=doc.createElement('small');note.textContent=detail;
   left.append(title,note);
   const value=doc.createElement('span');value.textContent=money(amount);
   if(amount===null)value.className='is-pending';
   row.append(left,value);host.append(row);
  }
  const footer=doc.createElement('p');footer.className='route-cost-total';
  if(feeBaseline){
   const fixed=feeBaseline.fixedSubtotalUsd;
   const fuelAmount=fuel?.estimatedBurnCostUsd;
   footer.textContent='Known fixed airport/navigation fees: '+money(fixed)+
    (typeof fuelAmount==='number'?
     ' · Plus fuel forecast: '+money(fuelAmount):
     ' · Fuel forecast pending')+
    '. NOT the complete flight cost; passenger, cargo, maintenance and '+
    'other expenses are not included. Crew is excluded from Phase 1 calculations. Airport fees use the verified game '+
    'calculator with zero passengers/cargo ONLY to isolate fixed costs. No charge.';
  }else footer.textContent='Complete flight cost unavailable. '+
   'Airport fees will appear after the server verifies the chosen aircraft, '+
   'both airports and stand selections. No charge.';
  host.append(footer);
 };
 const updateCostBreakdown=(fuel=null,price=null)=>{
  displayedFuel=fuel;displayedPrice=price;renderCostBreakdown();
 };
 const syncFeeBaseline=()=>{
  const data=getData(),from=selected('from'),to=selected('to');
  const airframe=$('route-aircraft')?.value||'';
  const owned=ownedFleet.find(a=>'owned:'+a.id===airframe);
  const arrivalStand=$('route-arrival-stand')?.value||'terminal';
  const parkingMinutes=Number($('route-turnaround')?.value);
  // The origin stand may follow a previous flight. Never invent its position
  // or imply that an unsaved route has a verified stand reservation.
  const actualDepartureStand=owned?
   departureStandFromTimeline(selectedAircraftTimeline()):null;
  const departureStand=actualDepartureStand||
   (arrivalStand==='cargo'?'cargo':'terminal');
  const scheduler=data?.scheduler;
  const valid=data?.connected&&data?.airline?.id&&from?.key&&to?.key&&
   from.key!==to.key&&owned&&['terminal','remote','cargo'].includes(departureStand)&&
   ['terminal','remote','cargo'].includes(arrivalStand)&&
   Number.isInteger(parkingMinutes)&&parkingMinutes>=45&&parkingMinutes<=360&&
   typeof scheduler?.feePreview==='function';
  if(!valid){
   feeRequestSerial++;
   feeBaseline=null;feeRequestKey=null;
   feeRequestStatus='Choose owned aircraft, both airports and compatible stands';
   renderCostBreakdown();return;
  }
  const key=[data.airline.id,owned.id,from.key,to.key,departureStand,
   arrivalStand,parkingMinutes].join('|');
  if(key===feeRequestKey)return;
  feeRequestKey=key;feeBaseline=null;feeRequestStatus='Loading verified Section 8 game fees…';
  const ticket=++feeRequestSerial;renderCostBreakdown();
  void scheduler.feePreview({
   airlineId:data.airline.id,aircraftInventoryId:owned.id,
   originAirportKey:from.key,destinationAirportKey:to.key,
   departureStand,arrivalStand,parkingMinutes
  }).then(response=>{
   if(ticket!==feeRequestSerial||key!==feeRequestKey)return;
   const validated=checkedRouteFeeBaseline(response,{
    airlineId:data.airline.id,aircraftInventoryId:owned.id
   });
   feeBaseline=validated;
   feeRequestStatus=validated?'Available':'Fee calculator returned an unverified response';
   renderCostBreakdown();
  }).catch(()=>{
   if(ticket!==feeRequestSerial||key!==feeRequestKey)return;
   feeBaseline=null;
   feeRequestStatus='Airport fee preview unavailable; no amount was assumed';
   renderCostBreakdown();
  });
 };
 const updateFuelEstimate=()=>{
  const holder=$('route-fuel-phases'),from=selected('from'),to=selected('to');
  lastFuelEstimate=null;
  updateCostBreakdown();
  syncFeeBaseline();
  const id=$('route-aircraft')?.value||'';
  const owned=ownedFleet.find(a=>'owned:'+a.id===id);
  const aircraft=owned&&typeof getFuelAircraft==='function'?getFuelAircraft(owned.id):null;
  if(!holder)return;
  holder.replaceChildren();
  message('route-cruise-speed',
   Number.isFinite(aircraft?.cruiseSpeedKmh)&&aircraft.cruiseSpeedKmh>0?
    Math.round(aircraft.cruiseSpeedKmh)+' km/h (aircraft model reference)':
    'Aircraft cruise reference not available');
  message('route-airborne-time','Awaiting flight phase estimate');
  message('route-min-turnaround','45 min (game minimum)');
  const setSummary=value=>{const el=$('route-fuel-summary');if(el)el.textContent=value;};
  if(!from||!to||!owned){setSummary('Select two airports and an owned aircraft.');return;}
  if(aircraft?.id!==owned.id||Number(aircraft?.configurationId)!==owned.configurationId){
   setSummary('Owner-verified aircraft fuel reference is loading or unavailable.');return;
  }
  const km=routeDistanceKm(from,to);
  // Until actual passenger/cargo manifests exist, show neutral 50% load.
  // This is not a booked passenger count or verified flight payload.
  const payload=.5;
  const originProfile=airportProfiles.from?.key===from.key?airportProfiles.from:null;
  const price=previewAirportFuelPrice(originProfile,{fuelFamily:aircraft.fuelFamily});
  const fuel=estimateFivePhaseFuel({
   distanceKm:km,cruiseSpeedKmh:aircraft.cruiseSpeedKmh,
   cruiseFuelKgPerHour:aircraft.cruiseFuelKgPerHour,
   emptyFuelKgPer100Km:aircraft.emptyFuelKgPer100Km,
   halfFuelKgPer100Km:aircraft.halfFuelKgPer100Km,
   fullFuelKgPer100Km:aircraft.fullFuelKgPer100Km,
   fuelTankCapacityKg:aircraft.fuelTankCapacityKg,payloadFraction:payload,
   priceUsdPerKg:price.usdPerKg,
   originAirportCategory:originProfile?.category||null,
   destinationAirportCategory:airportProfiles.to?.key===to.key?
    airportProfiles.to.category:null,
   originAirportKey:from.key,destinationAirportKey:to.key
  });
  if(fuel.status!=='PLANNING_ESTIMATE'){
   setSummary('Fuel profile incomplete; no reliable estimate for this model.');return;
  }
  lastFuelEstimate={aircraftId:owned.id,fromKey:from.key,toKey:to.key,
   minutes:Math.round(fuel.totalMinutes)};
  const kg=n=>Math.round(n).toLocaleString('en-US')+' kg';
  const usd=n=>n===null?'Not priced':
   '$'+n.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
  const heading=doc.createElement('h4');
  heading.textContent='Five-phase flight and fuel forecast';
  const grid=doc.createElement('div');grid.className='route-fuel-phase-grid';
  for(const phase of fuel.phases){
   const line=doc.createElement('div');line.className='route-fuel-phase-row';
   for(const value of [phase.label,Math.round(phase.minutes)+' min',kg(phase.fuelKg)]){
    const span=doc.createElement('span');span.textContent=value;line.append(span);
   }
   grid.append(line);
  }
  holder.append(heading,grid);
  setSummary(kg(fuel.tripFuelKg)+' · '+usd(fuel.estimatedBurnCostUsd)+' (forecast)');
  message('route-airborne-time',Math.round(fuel.airborneMinutes)+' min (climb + cruise + descent)');
  updateCostBreakdown(fuel,price);
  message('route-block-time',Math.round(fuel.totalMinutes)+' min (phase estimate)');
  updateWeek();
 };
 doc.addEventListener('airlinerra:fleet-fuel-updated',event=>{
  if(event.detail?.airlineId===getData()?.airline?.id)updateFuelEstimate();
 });
 const refreshCabinPackages=(preferred=null)=>{
  const picker=$('route-cabin-package');if(!picker)return;
  const {packages,ready}=cabinSnapshot(),chosen=preferred??picker.value??'basic';
  picker.replaceChildren(new Option('No onboard service','none'));
  for(const pkg of packages){
   if(!pkg?.id||!/^(?:basic|pkg-[1-9][0-9]{0,5})$/.test(pkg.id))continue;
   picker.add(new Option(pkg.name,pkg.id));
  }
  if(![...picker.options].some(x=>x.value==='basic'))
   picker.add(new Option('Basic Cabin Service','basic'));
  if(chosen&&![...picker.options].some(x=>x.value===chosen)){
   const missing=new Option('Deleted package — select another',chosen);
   missing.disabled=true;picker.add(missing);
  }
  picker.value=chosen&&[...picker.options].some(x=>x.value===chosen)?chosen:'basic';
  picker.disabled=!ready;
  doc.dispatchEvent?.(new Event('airlinerra:refresh-game-select-menus'));
 };
 doc.addEventListener('airlinerra:cabin-packages-updated',event=>{
  if(event.detail?.airlineId===getData()?.airline?.id)refreshCabinPackages();
 });

 const days=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
 let homeKey=null,homeLocation=null,currentAirlineId=null,homeTicket=0,detailTicket=0;
 let lastKeys='',airportProfiles={},editingFlightNumber=null,editingLegacyIndex=null,editSerial=0;
 let preflightCatalogFor=null,preflightLoadToken=0,preflightRequest=0;
 let catalogAircraft=[],preflightCache=null,preflightPromise=null;
 let ownedFleet=[],serverDrafts=[],serverPlans=[],fleetTicket=0,fleetReadState='unavailable';
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
  const from=selected('from'),to=selected('to');
  const aircraftId=$('route-aircraft')?.value?.replace(/^owned:/,'');
  const modelMinutes=lastFuelEstimate?.aircraftId===aircraftId&&
   lastFuelEstimate?.fromKey===from?.key&&lastFuelEstimate?.toKey===to?.key?
    lastFuelEstimate.minutes:null;
  const model=planningClockEstimate(schedule,modelMinutes,target);
  for(let day=0;day<7;day++){
   const modelDay=model?.rows.find(x=>x.day===day);
   message('route-arrival-'+day,chosenDays.has(day)?
    (estimate?'Example '+estimate.arrivalClock:
     modelDay?'~'+modelDay.arrivalClock+' UTC':'—'):'—');
   message('route-next-departure-'+day,chosenDays.has(day)?
    (estimate?'Example '+estimate.clock:
     modelDay?'~'+modelDay.availableClock+' UTC':'—'):'—');
  }
  message('route-rotation-check',Number.isInteger(target)&&target>=45&&target<=360?
   (estimate?'Reference ground time '+estimate.clock+' · not an airport slot':
    model?'Aircraft ready time is a provisional model estimate, not an approved slot':
    'No flight-time model currently loaded; this is still only a weekly plan'):
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
  for(const p of serverPlans){
   if(p?.status!=='planning'||p.aircraftInventoryId!==inventoryId||
      !p.originAirportKey||!p.destinationAirportKey||
      typeof p.flightNumber!=='string'||seen.has(p.flightNumber))continue;
   seen.add(p.flightNumber);
   server.push({flightNumber:p.flightNumber,aircraftId,
    from:p.from||resolveAirport(p.originAirportKey),
    to:p.to||resolveAirport(p.destinationAirportKey),
    schedule:Array.isArray(p.schedule)?p.schedule:[],
    operation:p.operation||{},
    referenceDepartureUtc:p.referenceDepartureUtc,
    referenceArrivalUtc:p.referenceArrivalUtc});
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
   const priorDeparture=Date.parse(previous.referenceDepartureUtc||'');
   const arrival=Date.parse(previous.referenceArrivalUtc||'');
   if(!Number.isFinite(priorDeparture)||!Number.isFinite(arrival)||
      priorDeparture>planned||planned-priorDeparture>24*3600000)continue;
   // Use only date-matched UTC examples. This catches departures even BEFORE
   // the previous arrival; it never creates actual aircraft availability.
   const earliest=arrival+turnaround*60000;
   if(planned<earliest)return 'Previous '+String(previous.flightNumber||'flight')+
    ' example arrives at '+new Date(arrival).toISOString().slice(11,16)+' UTC. '+ 
    'With a '+turnaround+'-minute ground stop, the next departure cannot be before '+
    new Date(earliest).toISOString().slice(11,16)+' UTC on the example date.';
  }
  return null;
 };
 const refreshAircraftTimeline=()=>{
  const timeline=selectedAircraftTimeline();
  const cycleNotice=timeline.warnings.find(x=>x.startsWith('Weekly cycle is incomplete:'));
  message('route-cycle-warning',cycleNotice||'');
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
  if(!airport){node.textContent='Select an airport.';return;}
  const flag=flagNode(airport.countryIso);
  if(flag)node.append(flag);
  const title=doc.createElement('span');
  title.textContent=airport.name+(airport.code?' ('+airport.code+')':'');
  node.append(title);
 };
 const airportIataOrIcao=(side,profile)=>
  routeAirportIcaoCode(profile,selected(side==='origin'?'from':'to'));
 const airportRules=(side,profile)=>{
  const host=$('route-'+side+'-restrictions');
  const heading=$('route-'+side+'-title');
  if(!host)return;
  host.replaceChildren();
  const code=airportIataOrIcao(side,profile);
  if(heading)heading.textContent=(side==='origin'?'Origin airport':'Destination airport')+
   (code?': '+code:'');
  if(!profile){host.textContent='Airport data pending';return;}
  const {curfew,noise}=routeAirportGameRules(profile);
  const rules=[
   ['Longest runway',routeLongestRunwayLabel(profile)],
   ['Night curfew',curfew],
   ['Noise rules / procedures',noise]
  ];
  for(const [label,value] of rules){
   const row=doc.createElement('div');row.className='route-airport-rule';
   const name=doc.createElement('span');name.textContent=label;
   const result=doc.createElement('strong');result.textContent=value;
   row.append(name,result);host.append(row);
  }

 };
 const airportDemand=(side,profile)=>{
  const host=$('route-'+side+'-demand');if(!host)return;
  host.replaceChildren();
  for(const [title,key] of [['Passengers','passengerGroup'],['Cargo','cargoGroup']]){
   const raw=profile?.demand?.[key];
   const rating=Number.isInteger(raw)&&raw>=1&&raw<=5?raw:null;
   const row=doc.createElement('div');row.className='route-demand-line';
   const label=doc.createElement('span');label.textContent=title;
   const bars=doc.createElement('div');bars.className='route-demand-bars';
   bars.setAttribute('role','img');
   bars.setAttribute('aria-label',title+' demand: '+
    (rating===null?'not available':rating+' of 5')+
    '; game demand estimate, not booked passengers');
   for(let n=1;n<=5;n++){
    const bar=doc.createElement('span');
    bar.className='route-demand-bar'+(rating!==null&&n<=rating?' is-filled':'');
    bar.setAttribute('aria-hidden','true');bars.append(bar);
   }
   const value=doc.createElement('strong');value.textContent=rating===null?
    'Unverified':rating+'/5';
   row.append(label,bars,value);host.append(row);
  }

 };
 const updateRights=()=>{
  const from=selected('from'),to=selected('to');
  const fromProfile=airportProfiles.from?.key===from?.key?airportProfiles.from:null;
  const toProfile=airportProfiles.to?.key===to?.key?airportProfiles.to:null;
  const group2Blocked=[fromProfile,toProfile].some(profile=>
   profile?.sourceGroup==='GROUP_2'&&profile.canActivateFlights===false);
  renderTrafficRightIndicators(doc,$('route-rights-icons'),$('route-rights-legend'),{
   homeIso:homeLocation?.countryIso,
   originIso:from?.countryIso,destinationIso:to?.countryIso,
   // Prepared Group 2 airport data may be inspected but these airports are
   // not admitted for commercial flight activation. Not a traffic-right denial.
   routeBlockReason:group2Blocked?'Group 2 airport not admitted for commercial flights':null
  });
 };
 const showDetails=()=>{
  airportRules('origin',airportProfiles.from);
  airportRules('destination',airportProfiles.to);
  airportDemand('origin',airportProfiles.from);
  airportDemand('destination',airportProfiles.to);
  updateRights();
 };
 const syncAircraftCompatibility=()=>{
  const aircraft=catalogChoice(),assessment=aircraft?runwayAssessment(aircraft):null;
  const selection=$('route-aircraft')?.value||'';
  const button=$('route-plan-save');
  if(button)button.disabled=assessment?.status==='BLOCKED'||
   routeAirportPairStatus(selected('from'),selected('to'))==='SAME_AIRPORT';
  const reason=assessment?.status==='BLOCKED'?
   'BLOCKED — '+assessment.blockingReasons.join(' '):
   assessment?.status==='REVIEW'?'Runway review: '+assessment.reviewReasons.join(' '):
   assessment?.status==='PASS'?'':selection?
   'Aircraft configuration loading.':'Choose an aircraft.';
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
   const empty=doc.createElement('p');
   empty.textContent='No slot-reserved operational schedules yet. Planning routes need a separate slot-registration step before they can be certified.';
   holder.append(empty);
  }
  for(const plan of serverPlans.slice(0,50)){
   if(plan?.status!=='planning'||typeof plan.planId!=='string'||
      serverDrafts.some(d=>d.flightNumber===plan.flightNumber))continue;
   const row=doc.createElement('div');row.className='fleet-test-aircraft-row';
   const title=doc.createElement('strong');
   title.textContent=String(plan.flightNumber||'Planning route')+' · '+
     String(plan.from?.name||plan.originAirportKey||'')+' to '+
     String(plan.to?.name||plan.destinationAirportKey||'');
   const description=doc.createElement('small');
   const hasTimes=Boolean(plan.referenceDepartureUtc&&plan.referenceArrivalUtc);
   description.textContent=hasTimes?
     'Saved planning route · not a flight · airport slots not yet reserved':
     'Planning route only · enter explicit UTC departure and arrival times in Advanced airport schedule checks, then save your route again';
   row.append(title,description);
   if(hasTimes){
    const button=doc.createElement('button');
    button.type='button';button.className='secondary';
    button.dataset.routeRegisterPlanId=plan.planId;
    button.textContent='Reserve slots for operational draft';
    row.append(button);
   }
   holder.append(row);
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
  ownedFleet=[];serverDrafts=[];serverPlans=[];refreshCatalogOptions();renderServerScheduleList();
  if(!airlineId||typeof scheduler?.list!=='function')return;
  message('route-server-draft-status','Loading your registered operational aircraft and server drafts...');
  try{
   const response=await scheduler.list(airlineId);
   if(ticket!==fleetTicket)return;
   if(!Array.isArray(response?.fleet)||!Array.isArray(response?.drafts)||!Array.isArray(response?.plans))
    throw Error('Unverified company fleet response');
   fleetReadState='verified';
   ownedFleet=Array.isArray(response?.fleet)?response.fleet.filter(a=>
    typeof a?.id==='string'&&Number.isSafeInteger(a.configurationId)&&a.configurationId>0):[];
   serverDrafts=response.drafts;
   serverPlans=response.plans;
   refreshCatalogOptions();renderServerScheduleList();refreshAircraftTimeline();updateFuelEstimate();
   message('route-server-draft-status',ownedFleet.length?
    ownedFleet.length+' operational aircraft connected. Server schedule drafts are separate from live flight activation.':
    'No company aircraft are in service. Purchase or lease one, complete delivery and inspection, then create a route.');
  }catch{
   if(ticket===fleetTicket){
    fleetReadState='unavailable';ownedFleet=[];serverDrafts=[];serverPlans=[];refreshCatalogOptions();renderServerScheduleList();updateFuelEstimate();
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
  updateFuelEstimate();
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
  const equal=routeAirportPairStatus(from,to)==='SAME_AIRPORT';
  const map=renderRouteMap($('route-map-canvas'),equal?null:from,equal?null:to,{doc});
  message('route-map-feedback',equal?
   'BLOCKED — origin and destination are the same airport. Choose another destination.':
   map?'Orange line: geographic distance between verified airports (not an approved flight path).':
   'Checking airport coordinates from the airport directory and profiles...');
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
  message('route-block-time','Pending aircraft fuel reference');
  updateFuelEstimate();
  message('route-market',from&&to?
   (from.countryIso===to.countryIso?'Domestic route':'International route'):'Select airports');
  const pairStatus=routeAirportPairStatus(from,to);
  const validPair=pairStatus==='VALID';
  for(const id of ['route-plan-preview','route-plan-save']){
   const button=$(id);
   if(button)button.disabled=pairStatus==='SAME_AIRPORT';
  }
  const validOrigin=Boolean(from&&from.key===homeKey);
  const demoAircraft=(Array.isArray(getData()?.airline?.testAircraft)?
   getData().airline.testAircraft:[]).find(a=>a.id===$('route-aircraft')?.value&&
    a.testOnly===true&&a.operationallyAllowed===false);
  syncAircraftCompatibility();
  message('route-slot-check','Select aircraft and flight times to check slots');
  updateRights();
  message('route-status',pairStatus==='SAME_AIRPORT'?'Restricted — same airport':'Draft only');
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
  }catch{message('route-feedback','Home airport could not be preselected. Choose an origin manually.');}
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
  if($('route-launch-delay'))$('route-launch-delay').value='0';
  for(const label of ['economy','premium','business','first'])
   if($('route-fare-'+label))$('route-fare-'+label).value='';
  for(const id of ['route-baggage-service'])
   if($(id))$(id).value='standard';
  if($('route-cargo-service'))$('route-cargo-service').value='none';
  refreshCabinPackages('basic');
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
  $('route-plan-status')?.classList?.remove('is-success');
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
 const editRouteDraft=async ref=>{
  const stored=loadDraft?.()||{};
  const routes=Array.isArray(stored.routes)&&stored.routes.length?stored.routes:
   stored.route?[stored.route]:[];
  const index=Number.isInteger(ref)?ref:null;
  const route=index!==null?routes[index]:ref;
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
  if($('route-launch-delay'))$('route-launch-delay').value=
   [0,3,7].includes(route.launchDelayDays)?String(route.launchDelayDays):'0';
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
   ['route-baggage-service','baggage',['standard','hand-only','checked'],'standard'],
   ['route-cargo-service','cargo',['none','requested'],'none']]){
   const value=route.operation?.service?.[field];
   $(id).value=values.includes(value)?value:def;
  }
  refreshCabinPackages(route.operation?.service?.cabinPackageId||'basic');
  show();
  message('route-plan-status',route.flightNumber?
   'Editing '+route.flightNumber+' · Create new route will save the updated planning draft to your airline where connected.':
   'Previous route idea loaded. Enter a flight number and choose days to save it as a draft.');
 };
 doc.addEventListener('airlinerra:edit-route-draft',event=>{
  const ref=event.detail?.route||event.detail?.index;
  if(ref&&typeof ref==='object'&&ref.from&&ref.to)void editRouteDraft(ref);
  else if(Number.isInteger(ref)&&ref>=0&&ref<100)void editRouteDraft(ref);
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
   clearPreflight();refreshAircraftTimeline();updateWeek();syncFeeBaseline();
   void automaticPreflight();return;
  }
  if(el?.id==='route-turnaround'){
   updateWeek();refreshAircraftTimeline();syncFeeBaseline();return;
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
  if(routeAirportPairStatus(from,to)==='SAME_AIRPORT'){
   message('route-preflight-status','BLOCKED — same-airport flights are not valid routes.');
   return {gameHardBlocked:true,reason:'SAME_AIRPORT'};
  }
  if(!from||!to||!configurationId){
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
      (Boolean(ownedChoice)&&typeof getData()?.scheduler?.save==='function'&&
       slotAvailability?.available!==true)||
      routeAirportPairStatus(from,to)!=='VALID';
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
  if(target.dataset.routeRegisterPlanId){
   const id=target.dataset.routeRegisterPlanId;
   const data=getData(),scheduler=data?.scheduler,airlineId=data?.airline?.id;
   const plan=serverPlans.find(p=>p?.planId===id&&p.status==='planning');
   if(!plan||!airlineId||typeof scheduler?.slotCheck!=='function'||
      typeof scheduler?.save!=='function'){
    message('route-server-draft-status','Planning route or operational schedule service unavailable. Nothing saved.');
    return;
   }
   let draft;
   try{
    draft=operationalScheduleFromPlanningRoute(plan,airlineId);
   }catch(error){
    const reason=String(error?.message||'');
    message('route-server-draft-status',reason.includes('TIMES_REQUIRED')?
     'Enter explicit UTC departure and arrival times in Advanced airport schedule checks, then save the planning route again. No estimate will be substituted.':
     reason.includes('STANDS_REQUIRED')?
     'Select valid departure and arrival stands in the route, then save it again.':
     'Planning route is incomplete. Edit and save it before reserving slots.');
    return;
   }
   target.disabled=true;
   message('route-server-draft-status','Checking airport slots for '+draft.flightNumber+'...');
   try{
    const check=await scheduler.slotCheck(draft);
    if(check?.available!==true){
     message('route-server-draft-status','NOT REGISTERED — required airport slots are unavailable. Choose a different schedule or stands.');
     return;
    }
    const result=await scheduler.save(draft);
    if(result?.status!=='draft'||result.slotsReserved!==true||
       typeof result.scheduleId!=='string'||
       result.canActivateNormalFlight!==false||
       result.ledgerPosted===true||result.gameHardBlocked===true)
     throw Error('UNVERIFIED_OPERATIONAL_DRAFT_CONFIRMATION');
    // A successful write is confirmed by a fresh owner-scoped list.
    await loadOwnedScheduleData(airlineId);
    if(!serverDrafts.some(s=>s.id===result.scheduleId&&
       s.flightNumber===draft.flightNumber&&s.slotsReserved===true)){
     message('route-server-draft-status','Schedule submitted but list confirmation failed. Refresh the page before trying again; do not create duplicates.');
     return;
    }
    const local=loadDraft?.()||{};
    const updateRoute=r=>r?.flightNumber===draft.flightNumber?
      {...r,serverScheduleId:result.scheduleId,slotsReserved:true}:r;
    if(Array.isArray(local.routes))
     await draftWrite('routes',local.routes.map(updateRoute));
    if(local.route?.flightNumber===draft.flightNumber)
     await draftWrite('route',updateRoute(local.route));
    doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved'));
    message('route-server-draft-status',
      draft.flightNumber+' registered as an inactive draft with game slots reserved. Route rights and independent flight approvals are still required. Crew is excluded from Phase 1. No flight or charge was created.');
   }catch{
    message('route-server-draft-status',
      'Operational schedule registration was not confirmed. Refresh the server list before retrying. No flight was activated.');
   }finally{target.disabled=false;}
   return;
  }
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
    if(Array.isArray(current.routes))await draftWrite('routes',current.routes.map(cleaned));
    if(current.route?.serverScheduleId===id)await draftWrite('route',cleaned(current.route));
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
    message('route-feedback','Choose two different airports before previewing.');return;
   }
   show();
   message('route-feedback','Route preview ready. Select an aircraft and weekday departures below.');
   return;
  }
  if(target.id==='route-plan-new'){
   await resetRouteForm();
   message('route-plan-status','Form cleared. Nothing was saved. Enter a route and click Create new route to save a draft.');
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
  if(routeAirportPairStatus(from,to)!=='VALID'){
   message('route-plan-status','BLOCKED — choose two different airports.');return;
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
   onboard:'basic',cabinPackageId:$('route-cabin-package')?.value,
   baggage:$('route-baggage-service')?.value,
   cargo:$('route-cargo-service')?.value
  });
  if(!operation){
   message('route-plan-status','Check turnaround (45–360 minutes), fares ($0–100,000), stand and service choices.');
   return;
  }
  const selectedPackageId=operation.service.cabinPackageId;
  const availablePackages=cabinSnapshot();
  if(!availablePackages.ready||!selectedPackageId||
     (selectedPackageId!=='none'&&!availablePackages.packages.some(p=>p.id===selectedPackageId))){
   message('route-plan-status','Cabin packages unavailable or the selection was deleted. Choose an available package before saving.');return;
  }
  const flightAircraft=$('route-aircraft')?.value||null;
  const ownedChoice=ownedFleet.find(a=>'owned:'+a.id===flightAircraft)||null;
  const selectedCatalog=catalogChoice(),selectedRunway=selectedCatalog?runwayAssessment(selectedCatalog):null;
  if(selectedRunway?.status==='BLOCKED'){
   message('route-plan-status','BLOCKED — This aircraft cannot use the route. '+selectedRunway.blockingReasons.join(' '));
   return;
  }
  if(!ownedChoice){
   message('route-plan-status','Select an in-service aircraft owned or leased by this company. Test and catalogue aircraft cannot be scheduled.');
   return;
  }
  const canCreateOperational=typeof data?.scheduler?.operationalCreate==='function';
  if(!canCreateOperational){
   message('route-plan-status',
    'NOT CREATED — the operational flight service is not connected. No route or flight was saved.');
   return;
  }
  // Create route now means a fully verified operating route or no new record.
  // The backend must atomically confirm the real schedule, slots, clearance,
  // execution and booking gates. No fallback to a planning-only save.
  const preflight=await automaticPreflight({force:true});
  if(preflight?.gameHardBlocked===true){
   message('route-plan-status','BLOCKED — a verified airport restriction prevents saving this route.');
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
  // A local draft never mutates server finance, aircraft, schedules or live flights.
  const durationReference=lastFuelEstimate?.aircraftId===ownedChoice?.id&&
   lastFuelEstimate?.fromKey===from.key&&lastFuelEstimate?.toKey===to.key?
    lastFuelEstimate.minutes:null;
  const launchDelayDays=Number($('route-launch-delay')?.value??0);
  if(![0,3,7].includes(launchDelayDays)){
   message('route-plan-status','Select a valid route launch preference.');return;
  }
  const draft={from,to,flightNumber,flights:schedule.length,schedule,
   launchDelayDays,
   ...(Number.isInteger(durationReference)&&durationReference>=25?
    {estimatedDurationMinutes:durationReference,
     estimatedDurationSource:'five_phase_game_estimate'}:{}),
   storage:'server-planning',
   aircraftId:flightAircraft,
   aircraftConfigurationId:selectedCatalog?.id??ownedChoice.configurationId,
   aircraftLabel:[selectedCatalog?.manufacturer||ownedChoice.manufacturer,
    selectedCatalog?.model||ownedChoice.model,
    selectedCatalog?.configuration].filter(Boolean).join(' ')||ownedChoice.registration,
   catalogPreviewOnly:false,testAircraft:false,
   serverScheduleId:null,serverPlanningId:null,
   referenceDepartureUtc:utcFromInput($('route-preflight-departure-utc')?.value),
   referenceArrivalUtc:utcFromInput($('route-preflight-arrival-utc')?.value),
   airportRuleScreen:{gameHardBlocked:false,needsReview:preflight?.needsReview!==false,
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
  const scheduler=data.scheduler;
  message('route-plan-status','Checking the operating schedule and required approvals…');
  try{
   const result=await scheduler.operationalCreate({
    airlineId:data.airline.id,aircraftInventoryId:ownedChoice.id,
    flightNumber,originAirportKey:from.key,destinationAirportKey:to.key,
    weeklySchedule:schedule,launchDelayDays,
    departureStand:operation.departureStand,
    arrivalStand:operation.arrivalStand,
    turnaroundMinutes:operation.turnaroundMinutes,
    fares:operation.fares,service:operation.service,
    referenceDepartureUtc:draft.referenceDepartureUtc&&draft.referenceArrivalUtc?
     draft.referenceDepartureUtc:null,
    referenceArrivalUtc:draft.referenceDepartureUtc&&draft.referenceArrivalUtc?
     draft.referenceArrivalUtc:null
   });
   if(result?.routeCreated!==true||result?.status!=='active'||
      result.activated!==true||result.slotsReserved!==true||
      result.bookingEnabled!==true||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(result.scheduleId||''))
    throw Error('OPERATIONAL_ROUTE_NOT_CONFIRMED');
   draft.serverScheduleId=result.scheduleId;
   draft.serverPlanningId=result.planId||null;
   draft.storage='server-operational';
   draft.operationallyVerified=true;
   draft.status='active';
  }catch(error){
   const reason=String(error?.message||'');
   const blockers=Array.isArray(error?.operationalBlockers)?error.operationalBlockers:[];
   const specific=blockers.includes('AIRCRAFT_NOT_IN_AIRLINE_FLEET')?
    'The selected aircraft is not in this airline fleet.':
    blockers.includes('AIRCRAFT_NOT_IN_SERVICE')?
    'The selected aircraft is not in service.':
    blockers.includes('AIRCRAFT_STARTING_LOCATION_NOT_VERIFIED')?
    'The aircraft starting airport has not yet been verified.':
    blockers.includes('AIRCRAFT_NOT_VERIFIED_AT_ORIGIN')?
    'The aircraft has not been verified at the departure airport.':
    blockers.includes('AIRCRAFT_FUEL_DISPATCH_MODEL_NOT_APPROVED')&&
    blockers.includes('AIRCRAFT_MAINTENANCE_BASELINE_NOT_VERIFIED')?
    'Aircraft fuel and maintenance information must be verified before it can fly.':
    blockers.includes('AIRCRAFT_FUEL_DISPATCH_MODEL_NOT_APPROVED')?
    'The aircraft fuel model is not yet approved for flight operations.':
    blockers.includes('AIRCRAFT_MAINTENANCE_BASELINE_NOT_VERIFIED')?
    'Aircraft condition and maintenance tracking are not yet verified.':
    '';
   const airportEvidence=error?.operationalAirportFindings;
   const airportEvidenceNote=side=>{
    if(!side?.airportCode)return '';
    const needs=[];
    if(!side.runwayOperationalStatusVerified)needs.push('runway status');
    if(!side.aircraftChapterMatched)needs.push('aircraft noise certificate');
    return needs.length?side.airportCode+(side.runway?' ('+side.runway+')':'')+': '+needs.join(' and ')+' unverified':'';
   };
   const unresolvedAirports=blockers.includes('AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED')?
    [airportEvidenceNote(airportEvidence?.origin),
     airportEvidenceNote(airportEvidence?.destination)].filter(Boolean):[];
   const details=unresolvedAirports.length?
    ' Airport reviews needed — '+unresolvedAirports.join('; ')+'.':'';
   const statusText=specific?
    'NOT CREATED — '+specific+' The remaining flight systems are still being connected.':
    reason.includes('GAME_ENGINE_NOT_READY')?
     'NOT CREATED — automatic flight activation and bookings are not connected yet. No flight was created.':
    reason.includes('CABIN_PACKAGE_NOT_SAVED')?
     'NOT CREATED — save the selected cabin package in Flight Services first.':
    reason.includes('SCHEDULE_CONFLICT')?
     'NOT CREATED — the aircraft, airport slots or flight schedule failed verification.':
     'NOT CREATED — an operational flight could not be verified. No route was saved.';
   const gameOnlyNote=error?.gameModelPreliminarySuitable===true?
    ' The route passes preliminary GAME runway, restriction and slot-capacity checks. This is a game estimate, not an operating clearance.':'';
   message('route-plan-status',statusText+details+gameOnlyNote);
   return;
  }
  const copiedToDrafts=await draftWrite('routes',[...filtered,draft]);
  if(!copiedToDrafts){
   message('route-plan-status',
    'Route saved in the authoritative airline database, but the optional workplan mirror could not be confirmed. Open My Routes to check the saved server record.');
  }else{
   // Supporting editor details are database drafts, not browser state.
   await draftWrite('route',draft);
  }
  doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved',{
   detail:{flightNumber,serverSaved:Boolean(draft.serverPlanningId||draft.serverScheduleId)}
  }));
  await resetRouteForm();
  const text='Route '+flightNumber+' created.';
  const status=$('route-plan-status');
  if(status){status.classList.add('is-success');status.textContent=text;}

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
  if(id!==cabinOptionAirlineId){
   cabinOptionAirlineId=id;refreshCabinPackages('basic');
  }else refreshCabinPackages();
  if(id!==currentAirlineId){
   currentAirlineId=id;homeKey=null;homeLocation=null;
   void loadOwnedScheduleData(id);
   for(const side of ['from','to'])pickers[side].invalidate();
   void activateHome(data);
  }
  show();
 }
 plannerInitialized=true;
 updateWeek();refreshCabinPackages('basic');show();
 return Object.freeze({updateData,preview:show,selected});
}
