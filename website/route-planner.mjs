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
const goodNumber=s=>!s||/^[A-Z0-9-]{2,12}$/.test(s);
export function createRoutePlanner({doc,getData,loadDraft,draftWrite}={}){
 if(!doc||typeof getData!=='function'||typeof draftWrite!=='function')throw Error('Verified route planner data required');
 const $=id=>doc.getElementById(id);
 const pickers={};
 const selected=side=>pickers[side]?.selected()||null;
 const show=()=>{
  const from=selected('from'),to=selected('to');
  for(const [side,a] of [['from',from],['to',to]]){
   const node=$('route-'+side+'-summary');if(!node)continue;
   node.replaceChildren();
   if(!a){node.textContent='Select an approved airport.';continue}
   const name=doc.createElement('strong');name.textContent=airportFlag(a.countryIso)+' '+a.name+
    (a.code?' ('+a.code+')':'');
   const place=doc.createElement('p');place.className='hint';
   place.textContent=[a.municipality,airportCountryName(a.countryIso)].filter(Boolean).join(', ');
   node.append(name,place);
  }
  const title=$('route-map-heading');
  if(title)title.textContent=from&&to?
   (from.code||from.name)+' - '+(to.code||to.name):'Select two airports';
  const result=renderRouteMap($('route-map-canvas'),from,to,{doc});
  if($('route-map-feedback'))$('route-map-feedback').textContent=result?
   'Geographic planning line based on source coordinates - not an actual flight path.':
   'Airport coordinates pending, or select two airports to draw a route.';
  if($('route-distance'))$('route-distance').textContent=result?
   result.distanceKm.toLocaleString('en-US')+' km':'Data pending';
  if($('route-block-time'))$('route-block-time').textContent='Aircraft pending';
  if($('route-market'))$('route-market').textContent=from&&to?
   (from.countryIso===to.countryIso?'Domestic draft':'International draft'):'Select airports';
  if($('route-status'))$('route-status').textContent='Not scheduled';
 };
 for(const side of ['from','to']){
  pickers[side]=createAirportCountryPicker({
   country:$('route-'+side+'-country'),search:$('route-'+side+'-search'),
   airport:$('route-'+side+'-airport'),
   getReader:()=>getData()?.connected?getData()?.reader:null,
   onStatus:status=>{if($('route-'+side+'-count'))$('route-'+side+'-count').textContent=status;},
   onSelect:show
  });
 }
 const feedback=text=>{if($('route-feedback'))$('route-feedback').textContent=text};
 const main=$('player-main');
 main?.addEventListener('click',async(event)=>{
  const target=event.target?.closest?.('button');if(!target)return;
  if(target.id==='route-plan-swap'){
   const from=selected('from'),to=selected('to');
   if(!from||!to){feedback('Select two airports before swapping.');return}
   $('route-from-country').value=to.countryIso;
   $('route-to-country').value=from.countryIso;
   await Promise.all([pickers.from.load(),pickers.to.load()]);
   $('route-from-airport').value=to.key;$('route-to-airport').value=from.key;
   show();return;
  }
  if(target.id!=='route-plan-save')return;
  const from=selected('from'),to=selected('to');
  const flights=Number($('route-flights')?.value);
  const flightNumber=$('route-plan-number')?.value.trim().toUpperCase()||'';
  if(!from||!to||from.key===to.key||!Number.isSafeInteger(flights)||flights<1||flights>28||
   !goodNumber(flightNumber)){
   feedback('Select two different approved airports, 1-28 weekly departures and a valid optional flight number.');
   return;
  }
  const route={from,to,flights,flightNumber:flightNumber||null};
  const latest=loadDraft?.()||{},saved=Array.isArray(latest.routes)?latest.routes:[];
  const rest=saved.filter(a=>a?.from?.key!==from.key||a?.to?.key!==to.key);
  if(rest.length>=25){feedback('Maximum 25 saved routes. Remove a draft in My routes.');return;}
  if(!draftWrite('routes',[...rest,route])||!draftWrite('route',route)){
   feedback('Browser storage unavailable. Route draft was not saved.');return;
  }
  const review=$('route-plan-review');if(review){
   review.replaceChildren();
   const message=doc.createElement('p');
   message.textContent='Saved: '+from.name+' - '+to.name+'; '+flights+' proposed departures per week.';
   review.append(message);
  }
  doc.dispatchEvent(new CustomEvent('airlinerra:route-draft-saved'));
  feedback('Route idea saved in this browser session. No active flights or fees were created.');
 });
 function updateData(data){
  for(const side of ['from','to'])populateAirportCountries($('route-'+side+'-country'),data?.countries||[],doc);
  show();
 }
 show();
 return Object.freeze({updateData,preview:show,selected});
}
