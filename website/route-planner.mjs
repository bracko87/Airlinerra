/** Full route planning workspace, not commercial flight activation.
 * Only approved authenticated airport reads and account-local draft writes.
 */
import {createAirportCountryPicker,populateAirportCountries,airportFlag,airportCountryName} from './airport-country-picker.mjs';
import {renderRouteMap} from './route-map.mjs';
const section=(eyebrow,title,body)=>
 '<article class="panel route-planner-panel"><span class="panel-kicker">'+eyebrow+'</span><h2>'+title+'</h2>'+body+'</article>';
const field=(id,label,el)=>'<label class="workspace-label" for="'+id+'">'+label+'</label>'+el;
const picker=(side,title)=>'<fieldset class="route-planner-airport"><legend>'+title+'</legend>'+
 field('route-'+side+'-country','Country',
  '<select id="route-'+side+'-country"><option value="">Choose country</option></select>')+
 field('route-'+side+'-search','Filter approved airports',
  '<input type="search" id="route-'+side+'-search" maxlength="40" placeholder="Filter by name, city or code">')+
 field('route-'+side+'-airport','Airport',
  '<select id="route-'+side+'-airport" disabled><option value="">Choose country first</option></select>')+
 '<p id="route-'+side+'-count" class="hint" role="status">Select a country to list its approved airports.</p></fieldset>';
export function routePlannerMarkup(){
 return '<div class="route-planner-grid">'+
  section('ROUTE DEFINITION','Define your route',
   '<p class="hint">Build an airport pair from the approved World 1 directory. No live route, slot or flight is created.</p>'+
   '<div class="route-planner-airports">'+picker('from','Origin')+picker('to','Destination')+'</div>'+
   '<div class="workspace-actions"><button type="button" id="route-plan-swap" class="secondary">Swap airports</button></div>'+
   field('route-flights','Proposed departures per week','<input type="number" id="route-flights" min="1" max="28" value="7">')+
   '<p id="route-feedback" class="hint" role="status"></p>')+
  section('ROUTE MAP','Geographic route preview',
   '<h3 id="route-map-heading" class="route-map-heading">Select two airports</h3>'+
   '<div id="route-map-canvas" class="route-map-canvas"></div>'+
   '<p id="route-map-feedback" class="hint">The map uses verified coordinates where available.</p>')+
  '</div><div class="route-planner-grid route-planner-details">'+
  section('AIRPORT OVERVIEW','Airport information',
   '<div class="route-airport-cards">'+
   '<div class="route-airport-info"><span>Origin airport</span><div id="route-from-summary">Select an origin airport.</div></div>'+
   '<div class="route-airport-info"><span>Destination airport</span><div id="route-to-summary">Select a destination airport.</div></div></div>'+
   '<p class="hint">Runway suitability, terminal slots and airport capacity are not operationally verified yet.</p>')+
  section('ROUTE METRICS','Key information',
   '<div class="route-metrics">'+
   '<div><span>Great-circle distance</span><strong id="route-distance">Select airports</strong></div>'+
   '<div><span>Estimated block time</span><strong id="route-block-time">Aircraft pending</strong></div>'+
   '<div><span>Market type</span><strong id="route-market">Select airports</strong></div>'+
   '<div><span>Route status</span><strong id="route-status">Draft only</strong></div></div>')+
  '</div>'+
  section('PLANNING AND SETUP','Prepare your route',
   '<div class="route-planner-prep">'+
   '<div>'+field('route-plan-number','Flight number idea (optional)',
    '<input id="route-plan-number" maxlength="12" placeholder="e.g. PN101">')+'</div>'+
   '<div><strong>Aircraft assignment</strong><p class="hint">No aircraft assigned. Fleet ownership and performance checks come later.</p></div>'+
   '<div><strong>7-day schedule</strong><p class="hint">Create timetable drafts without opening commercial flights.</p>'+
   '<button type="button" class="secondary" data-workspace-go="schedule">Open schedule planner</button></div></div>'+
   '<div class="workspace-actions"><button type="button" id="route-plan-save" class="primary">Save route draft</button>'+
   '<button type="button" class="secondary" data-workspace-go="route-list">My routes</button></div>'+
   '<div id="route-plan-review" class="workspace-detail"></div>',
   )+
  section('NETWORK REQUIREMENTS','Before opening a route',
   '<div class="workspace-task-list">'+
   '<div><strong>Passenger and cargo demand</strong><span>Real market forecasts are not connected.</span></div>'+
   '<div><strong>Aircraft, crew and runway</strong><span>Equipment eligibility and staff must be verified.</span></div>'+
   '<div><strong>Airspace, slots and restrictions</strong><span>Operating authorizations are not yet available.</span></div>'+
   '<div><strong>Revenue and operating costs</strong><span>Pricing and profitability need real route operations.</span></div></div>');
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
