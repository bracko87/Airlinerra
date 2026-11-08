/** Section 9 read-only Route Details renderer; never activates flights or sells tickets. */
import {createSection9CommercialPlanEditor} from './section9-commercial-plan-editor.mjs';
import {createSection9RotationReview} from './section9-rotation-review.mjs';
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
  fact(doc,host,'Aircraft',route.aircraftLabel||'Not assigned');
  const weekly=Array.isArray(route.schedule)?route.schedule.map(x=>
   DAYS[x?.day]&&/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x.time)?
    DAYS[x.day]+' '+x.time:'').filter(Boolean).join(', '):'';
  fact(doc,host,'Weekly departures',weekly||'Not configured');
  fact(doc,host,'Departure stand',route.operation?.departureStand||'Unspecified');
  fact(doc,host,'Arrival stand',route.operation?.arrivalStand||'Unspecified');
  fact(doc,host,'Status','Schedule draft · no active commercial flight');
  const monthLabel=text(doc,'label','Market forecast month','workspace-label');
  monthLabel.htmlFor='section9-route-month';
  const select=doc.createElement('select');select.id='section9-route-month';
  MONTHS.forEach((m,i)=>{const option=doc.createElement('option');
   option.value=String(i+1);option.textContent=m;select.append(option);});
  select.value=String(selectedMonth);host.append(monthLabel,select);
  const mct=doc.createElement('div');host.append(mct);
  const results=doc.createElement('div');results.className='section9-route-results';
  host.append(results);
  const server=getServer?.()||{};
  const planHost=doc.createElement('section');
  planHost.className='section9-commercial-plan';
  host.append(planHost);
  void createSection9CommercialPlanEditor({
   doc,host:planHost,getServer
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
   hint(doc,results,'Market and connecting-flight previews require a protected, owned-aircraft schedule. Local route drafts are not bookable.');
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
