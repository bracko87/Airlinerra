/** Section 9 read-only Route Details renderer; never activates flights or sells tickets. */
import {createSection9CommercialPlanEditor} from './section9-commercial-plan-editor.mjs';
import {createSection9RotationReview} from './section9-rotation-review.mjs';
import {createSection9RouteFinancePanel} from './section9-route-finance-panel.mjs';
import {renderRouteMap,routeDistanceKm} from './route-map.mjs';
const MONTHS=['January','February','March','April','May','June','July','August',
 'September','October','November','December'];
const DAYS=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const num=value=>typeof value==='number'&&Number.isFinite(value)?
 value.toLocaleString('en-US',{maximumFractionDigits:2}):'Unknown';
const text=(doc,tag,value,className)=>{
 const el=doc.createElement(tag);el.textContent=String(value);
 if(className)el.className=className;
 return el;
};
const fact=(doc,host,label,value)=>{
 const row=doc.createElement('div');row.className='detail-row';
 row.append(text(doc,'span',label),text(doc,'strong',value));host.append(row);
};
const hint=(doc,host,message)=>{
 const el=text(doc,'p',message,'hint');host.append(el);return el;
};
export function createSection9RouteDetails({doc,host,getRoutes,getServer}={}){
 if(!doc||!host)return Object.freeze({open:async()=>{},index:()=>null,refresh:async()=>{}});
 let selectedIndex=null,selectedMonth=null,serial=0;
 async function open(index,month=null){
  const routes=getRoutes?.()||[];
  const route=routes[index];
  const mySerial=++serial;
  selectedIndex=index;
  host.replaceChildren();
  if(!route?.from?.key||!route?.to?.key){
   hint(doc,host,'Route not found in the current session.');return;
  }
  const timestamp=Date.parse(route.referenceDepartureUtc||'');
  const fallbackMonth=Number.isFinite(timestamp)?
   new Date(timestamp).getUTCMonth()+1:new Date().getUTCMonth()+1;
  selectedMonth=Number.isInteger(month)&&month>=1&&month<=12?month:fallbackMonth;
  host.append(text(doc,'h3',(route.flightNumber||'Draft')+' · '+
   (route.from.name||route.from.code||'Origin')+' → '+
   (route.to.name||route.to.code||'Destination')));
  const subtitle=text(doc,'p',
   route.serverScheduleId?'Protected schedule draft · not an active flight':
   route.serverPlanningId?'Saved airline planning route · no slots or active flights':
   'Local planning draft · not yet saved to airline database','route-details-state');
  host.append(subtitle);
  const top=doc.createElement('div');top.className='route-details-top';
  const mapPanel=doc.createElement('section');mapPanel.className='route-detail-section route-detail-map-panel';
  mapPanel.append(text(doc,'span','ROUTE GEOGRAPHY','panel-kicker'),
   text(doc,'h4','Route map'));
  const mapRoot=doc.createElement('div');mapRoot.className='route-map-canvas route-detail-map';
  mapPanel.append(mapRoot);
  const mapFeedback=text(doc,'p','Map uses verified geographic airport positions. No flight path is approved.',
   'hint route-detail-map-feedback');
  mapPanel.append(mapFeedback);
  const renderMap=(from,to)=>{
   const distance=renderRouteMap(mapRoot,from,to,{doc});
   const km=routeDistanceKm(from,to);
   mapFeedback.textContent=distance&&km!==null?
    km.toLocaleString('en-US')+' km · straight-line distance; not an operational flight path.':
    'Geographic map pending verified coordinates for both airports.';
  };
  renderMap(route.from,route.to);
  const overview=doc.createElement('section');overview.className='route-detail-section';
  overview.append(text(doc,'span','ROUTE OVERVIEW','panel-kicker'),
   text(doc,'h4','Aircraft and service'));
  fact(doc,overview,'Flight number',route.flightNumber||'Draft');
  fact(doc,overview,'Aircraft',route.aircraftLabel||'Not assigned');
  fact(doc,overview,'Origin',(route.from.name||route.from.key||'—')+
   (route.from.code?' ('+route.from.code+')':''));
  fact(doc,overview,'Destination',(route.to.name||route.to.key||'—')+
   (route.to.code?' ('+route.to.code+')':''));
  fact(doc,overview,'Flight status','Planning only · not activated');
  const launch=[0,3,7].includes(route.launchDelayDays)?route.launchDelayDays:0;
  fact(doc,overview,'Preferred launch',
   launch===0?'Next eligible departure after activation':
   'After '+launch+' game days (planning preference)');
  hint(doc,overview,'Launch preference does not activate flights or start ticket sales.');
  top.append(mapPanel,overview);
  host.append(top);

  const schedulePanel=doc.createElement('section');
  schedulePanel.className='route-detail-section route-detail-schedule-panel';
  schedulePanel.append(text(doc,'span','FLIGHT SCHEDULE','panel-kicker'),
   text(doc,'h4','Weekly timetable and aircraft position'));
  const weekly=Array.isArray(route.schedule)?route.schedule.filter(x=>
   DAYS[x?.day]&&/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x.time)):[];
  const days=doc.createElement('div');days.className='route-detail-days';
  for(let day=0;day<7;day++){
   const node=doc.createElement('div');
   const departure=weekly.find(w=>w.day===day);
   node.className='route-detail-day'+(departure?' is-active':'');
   node.append(text(doc,'strong',DAYS[day].slice(0,3)),
    text(doc,'span',departure?.time||'—'));
   days.append(node);
  }
  schedulePanel.append(days);
  const schedInfo=doc.createElement('div');schedInfo.className='route-detail-fact-grid';
  fact(doc,schedInfo,'Departure stand',route.operation?.departureStand||
   'Initial stand not verified');
  fact(doc,schedInfo,'Arrival stand',route.operation?.arrivalStand||'Unspecified');
  fact(doc,schedInfo,'Target turnaround',Number.isInteger(route.operation?.turnaroundMinutes)?
   route.operation.turnaroundMinutes+' minutes':'Not configured');
  fact(doc,schedInfo,'Estimated arrival',
   route.referenceArrivalUtc?'UTC example only · '+route.referenceArrivalUtc:
   'Pending verified aircraft performance');
  fact(doc,schedInfo,'Next possible departure',
   route.referenceArrivalUtc&&Number.isInteger(route.operation?.turnaroundMinutes)?
    new Date(Date.parse(route.referenceArrivalUtc)+route.operation.turnaroundMinutes*60000).toISOString().slice(11,16)+' UTC (example)':
    'Not calculated until arrival time is verified');
  fact(doc,schedInfo,'Airport slots','Not reserved for planning routes');
  schedulePanel.append(schedInfo);
  host.append(schedulePanel);

  const marketPanel=doc.createElement('section');
  marketPanel.className='route-detail-section';
  marketPanel.append(text(doc,'span','PASSENGER & CARGO MARKET','panel-kicker'),
   text(doc,'h4','Demand and connecting flights'));
  const monthLabel=text(doc,'label','Market forecast month','workspace-label');
  monthLabel.htmlFor='section9-route-month';
  const select=doc.createElement('select');select.id='section9-route-month';
  MONTHS.forEach((m,i)=>{const option=doc.createElement('option');
   option.value=String(i+1);option.textContent=m;select.append(option);});
  select.value=String(selectedMonth);marketPanel.append(monthLabel,select);
  const mct=doc.createElement('div');mct.className='route-detail-fact-grid';marketPanel.append(mct);
  const results=doc.createElement('div');results.className='section9-route-results';
  marketPanel.append(results);host.append(marketPanel);

  const servicePanel=doc.createElement('section');
  servicePanel.className='route-detail-section';
  servicePanel.append(text(doc,'span','TICKETS & SERVICES','panel-kicker'),
   text(doc,'h4','Saved pricing and onboard options'));
  const fares=route.operation?.fares||{};
  const savedFares=doc.createElement('div');savedFares.className='route-detail-fact-grid';
  for(const [code,label] of [['economy','Economy'],['premium','Premium Economy'],
    ['business','Business'],['first','First Class']]){
   const v=fares[code];
   fact(doc,savedFares,label+' fare',typeof v==='number'&&Number.isFinite(v)?
    '$'+v.toLocaleString('en-US'):'Not set');
  }
  const service=route.operation?.service||{};
  fact(doc,savedFares,'Onboard service',service.onboard||'Not configured');
  fact(doc,savedFares,'Baggage',service.baggage||'Not configured');
  fact(doc,savedFares,'Cargo',service.cargo||'Not configured');
  servicePanel.append(savedFares);host.append(servicePanel);

  const economicHeading=doc.createElement('section');
  economicHeading.className='route-detail-section route-detail-economics';
  economicHeading.append(text(doc,'span','ROUTE FINANCES','panel-kicker'),
   text(doc,'h4','Projected costs and actual profitability'));
  hint(doc,economicHeading,'Estimated income and itemized airport, ground handling, security and ATC costs are separate from verified settled flights. The last seven settled flights and older cumulative totals appear only when genuine ledger data exists.');
  host.append(economicHeading);
  const server=getServer?.()||{};
  const planHost=doc.createElement('section');
  planHost.className='section9-commercial-plan';
  host.append(planHost);
  const financeHost=doc.createElement('section');
  financeHost.className='section9-route-finances';
  host.append(financeHost);
  const financePanel=createSection9RouteFinancePanel({
   doc,host:financeHost,getServer
  });
  void financePanel.open(route,server.airline?.id);
  void createSection9CommercialPlanEditor({
   doc,host:planHost,getServer,onSaved:()=>financePanel.refresh()
  }).open(route,server.airline?.id);
  const rotationHost=doc.createElement('section');
  rotationHost.className='section9-aircraft-rotation';
  host.append(rotationHost);
  void createSection9RotationReview({
   doc,host:rotationHost,getServer
  }).open(route,server.airline?.id);
  if(server.connected&&typeof server.reader?.airportProfile==='function'){
   try{
    const [a,b]=await Promise.all([
     server.reader.airportProfile(route.from.key),server.reader.airportProfile(route.to.key)
    ]);
    if(mySerial!==serial)return;
    if(a?.airport?.key===route.from.key&&b?.airport?.key===route.to.key)
     renderMap({...route.from,latitude:a.airport.latitude,longitude:a.airport.longitude},
      {...route.to,latitude:b.airport.latitude,longitude:b.airport.longitude});
    const start=a?.airport?.connectionPolicy,end=b?.airport?.connectionPolicy;
    fact(doc,mct,'Origin minimum transfer',Number.isInteger(start?.minimumMinutes)?
     start.minimumMinutes+' minutes':'Unknown');
    fact(doc,mct,'Destination minimum transfer',Number.isInteger(end?.minimumMinutes)?
     end.minimumMinutes+' minutes':'Unknown');
    fact(doc,mct,'Maximum connection window','12 hours');
   }catch{
    if(mySerial===serial)hint(doc,mct,'Airport transfer rules unavailable.');
   }
  }
  if(mySerial!==serial)return;
  if(!route.serverScheduleId||!server.airline?.id||
     typeof server.scheduler?.demandPreview!=='function'){
   hint(doc,results,'Demand estimates and inbound/outbound connections (minimum airport transfer through 12 hours) become available only after verified scheduling. A planning route is not bookable.');
   return;
  }
  const state=hint(doc,results,'Loading protected market estimate...');
  try{
   const preview=await server.scheduler.demandPreview({
    airlineId:server.airline.id,scheduleId:route.serverScheduleId,month:selectedMonth
   });
   if(mySerial!==serial)return;
   const market=preview?.market,connections=preview?.connections;
   if(preview.status!=='draft_market_estimate'||!market||!connections)
    throw Error('Unrecognized demand preview');
   state.textContent='Planning preview only · flight operations and passenger allocations remain disabled.';
   results.append(text(doc,'h4','Route market demand'));
   fact(doc,results,'Market direct passengers per day',
    num(Number(market.directPassengersPerDay)));
   fact(doc,results,'Provisional route cargo demand per day',
    num(Number(market.cargoTonnesPerDay))+' tonnes');
   fact(doc,results,'Destination background',
    market.destinationBackground||'Unknown');
   fact(doc,results,'Destination seasonal index',
    num(Number(market.destinationSeasonIndex))+' / 100');
   hint(doc,results,'This is the entire route market, shared by competing airlines. These are not passengers booked on your flight. Fares, marketing, seats and competition are not yet applied.');
   for(const [title,candidates,minTime,total] of [
    ['Inbound connections',connections.inbound,connections.inboundMinimumMinutes,connections.inboundCount],
    ['Outbound connections',connections.outbound,connections.outboundMinimumMinutes,connections.outboundCount]
   ]){
    results.append(text(doc,'h4',title));
    hint(doc,results,'Minimum '+String(minTime??'unknown')+
     ' minutes · maximum 12 hours · '+String(total??0)+' eligible draft flights');
    if(!Array.isArray(candidates)||!candidates.length){
     hint(doc,results,'No eligible connecting flights in this four-week preview.');
     continue;
    }
    const ul=doc.createElement('ul');
    for(const c of candidates){
     ul.append(text(doc,'li',(c.flightNumber||'Flight')+' · '+
      (c.airlineName||'Airline')+' · '+
      String(c.shortestTransferMinutes||0)+' min transfer · '+
      String(c.matchesInFourWeeks||0)+' matching occurrences'));
    }
    results.append(ul);
   }
   hint(doc,results,'Connection candidates are not bookings. Aircraft seat availability and bilateral agreement rules must also pass before live passenger allocation.');
  }catch{
   if(mySerial===serial)state.textContent='Protected demand preview unavailable. No demand figures have been invented.';
  }
 }
 host.addEventListener('change',event=>{
  if(event.target?.id==='section9-route-month'&&selectedIndex!==null){
   const next=Number(event.target.value);
   if(Number.isInteger(next)&&next>=1&&next<=12)void open(selectedIndex,next);
  }
 });
 return Object.freeze({open,index:()=>selectedIndex,
  refresh:()=>selectedIndex===null?Promise.resolve():open(selectedIndex,selectedMonth)});
}
