/**
 * Timetable for owned/leased aircraft. Show booked schedules and saved
 * planning routes in separate states. Never turn a plan into a booking.
 */
export const WEEK_DAYS=Object.freeze(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']);
const HHMM=/^(?:[01]\d|2[0-3]):[0-5]\d$/;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const idOf=a=>typeof a?.id==='string'&&UUID.test(a.id)?a.id:null;
const ownership=a=>['owned','leased'].includes(a?.ownershipType);
const clockToMinute=s=>HHMM.test(s||'')?Number(s.slice(0,2))*60+Number(s.slice(3)):null;
const minuteToClock=n=>String(Math.floor(n/60)%24).padStart(2,'0')+':'+String(n%60).padStart(2,'0');
const valueOf=x=>String(x||'').slice(0,96);
const airportCode=x=>typeof x==='string'&&/^[A-Z0-9]{3,5}$/.test(x)?x:null;
const turnaroundValue=x=>Number.isInteger(x)&&x>=45&&x<=360?x:null;
const sameRoute=(a,b)=>asAircraftId(a)===asAircraftId(b)&&
 (a.originAirportKey||a.from?.key)===(b.originAirportKey||b.from?.key)&&
 (a.destinationAirportKey||a.to?.key)===(b.destinationAirportKey||b.to?.key);
export function plannedRotationTiming(startMinute,flightMinutes,turnaroundMinutes){
 if(!Number.isInteger(startMinute)||startMinute<0||startMinute>=1440||
  !Number.isInteger(flightMinutes)||flightMinutes<=0||flightMinutes>72*60)return null;
 const turnaround=turnaroundValue(turnaroundMinutes);
 const total=flightMinutes+(turnaround??0);
 return {flightMinutes,turnaroundMinutes:turnaround,
  totalMinutes:turnaround===null?null:total,
  arrivalMinute:(startMinute+flightMinutes)%1440,
  availableMinute:turnaround===null?null:(startMinute+total)%1440,
  arrivalDayOffset:Math.floor((startMinute+flightMinutes)/1440),
  availableDayOffset:turnaround===null?null:Math.floor((startMinute+total)/1440)};
}
const clockOnDay=(minute,offset)=>minuteToClock(minute)+
 (offset>0?' (+'+offset+' day'+(offset===1?'':'s')+')':'');
export function flightScheduleTooltip(event,band=null){
 const flightNumber=event?.flightNumber||band?.flightNumber||'Flight';
 const code=(event?.fromCode&&event?.toCode)?
  ' · '+event.fromCode+' → '+event.toCode:'';
 const departure=event?.time||'Departure on previous day';
 const duration=event?.durationMinutes??event?.sampleDurationMinutes??null;
 const timing=event?.timing||(duration!==null&&event?.minute!==undefined?
  plannedRotationTiming(event.minute,duration,event?.turnaroundMinutes):null);
 const arrival=timing?clockOnDay(timing.arrivalMinute,timing.arrivalDayOffset):'unknown';
 const available=timing?.totalMinutes!==null&&timing?
  clockOnDay(timing.availableMinute,timing.availableDayOffset):'not verified';
 const ground=timing?.turnaroundMinutes??null;
 return flightNumber+code+' | Departure '+departure+' UTC | '+
  'Estimated arrival '+arrival+' UTC | '+
  'Flight '+(duration===null?'not calculated':duration+' min')+' | '+
  'Turnaround '+(ground===null?'not set':ground+' min')+' | '+
  'Available from '+available+' UTC';
}
const validDuration=(a,b)=>{
 if(!a||!b)return null;
 const start=Date.parse(a),end=Date.parse(b);
 const minutes=(end-start)/60000;
 return Number.isInteger(minutes)&&minutes>0&&minutes<=72*60?minutes:null;
};
const orderedStops=stops=>Array.isArray(stops)?stops.filter(
 x=>Number.isInteger(x?.day)&&x.day>=0&&x.day<7&&clockToMinute(x.time)!==null
):[];
const asAircraftId=route=>{
 if(typeof route?.aircraftInventoryId==='string')return route.aircraftInventoryId;
 if(typeof route?.aircraftId==='string'&&route.aircraftId.startsWith('owned:'))
  return route.aircraftId.slice(6);
 return null;
};
/** Pure data model. Never creates a booking or assumes a route is airborne. */
export function buildAirlineWeeklyBoard({fleet,serverFleet,plans=[],drafts=[],localRoutes=[],estimatedDurations=[]}={}){
 const verifiedFleet=Array.isArray(fleet)?fleet:Array.isArray(serverFleet)?serverFleet:null;
 if(verifiedFleet===null)return Object.freeze({status:'unavailable',rows:[],counts:{flights:0,held:0}});
 const aircraft=[...new Map(verifiedFleet.filter(a=>idOf(a)&&ownership(a)).map(a=>[a.id,a])).values()]
  .sort((a,b)=>String(a.registration||'').localeCompare(String(b.registration||'')));
 const rows=aircraft.map(a=>({
  id:a.id,registration:valueOf(a.registration)||'Unregistered',
  name:[a.manufacturer,a.model].filter(Boolean).join(' ')||valueOf(a.model)||'Aircraft',
  nickname:valueOf(a.nickname).trim(),
  ownership:a.ownershipType,
  fleetStatus:valueOf(a.fleetStatus)||'unverified',
  days:WEEK_DAYS.map((_,day)=>({day,events:[],bands:[],warnings:[]})),
  flights:0
 }));
 const byAircraft=new Map(rows.map(row=>[row.id,row]));
 const seen=new Set();
 const readFlight=(flight,source)=>{
  // Only independently confirmed slot-held server records are booked.
  if(source!=='schedule'||flight?.slotsReserved!==true)return;
  const aircraftId=asAircraftId(flight),row=byAircraft.get(aircraftId);
  const flightNumber=String(flight?.flightNumber||'');
  if(!row||!/^[A-Z0-9]{2}[0-9]{1,4}$/.test(flightNumber))return;
  const schedule=orderedStops(flight.weeklySchedule);
  const verifiedDuration=validDuration(flight.referenceDepartureUtc,flight.referenceArrivalUtc);
  // A departure-only marker cannot represent a booked flight window.
  if(!schedule.length||verifiedDuration===null)return;
  // Server planning takes precedence over browser duplicates. A reserved
  // server schedule has priority over planning data with the same number.
  // Flight number belongs to the airline, not to a particular aircraft.
  // A stale browser draft must not reappear on the previous aircraft after
  // the server has reassigned the same flight to another tail.
  const key=flightNumber;
  if(seen.has(key))return;
  seen.add(key);
  const status='slot-held';
  const turnaroundMinutes=turnaroundValue(flight.operation?.turnaroundMinutes)??
   turnaroundValue(flight.turnaroundMinutes);
  const fromCode=airportCode(flight?.from?.code)||
   airportCode(flight?.originAirportCode);
  const toCode=airportCode(flight?.to?.code)||
   airportCode(flight?.destinationAirportCode);
  const unique=new Set();
  for(const stop of schedule){
   const minute=clockToMinute(stop.time),eventKey=stop.day+'|'+minute;
   if(unique.has(eventKey))continue;
   unique.add(eventKey);
   const event={
    day:stop.day,minute,time:stop.time,flightNumber,
    from:fromCode||'',to:toCode||'',fromCode,toCode,
    status,durationMinutes:verifiedDuration,
    sampleDurationMinutes:verifiedDuration,
    turnaroundMinutes,
    timing:plannedRotationTiming(minute,verifiedDuration,turnaroundMinutes)
   };
   row.days[stop.day].events.push(event);
   row.flights++;
   // A single bar represents booked flight time only, not estimated
   // turnaround or a non-reserved aircraft-availability forecast.
   let pos=minute,left=verifiedDuration,index=stop.day;
   while(left>0){
    const length=Math.min(left,1440-pos);
    row.days[index].bands.push({
     start:pos,end:pos+length,flightNumber,
     kind:'slot-held',sourceDay:stop.day,continues:index!==stop.day,
     flightMinutes:verifiedDuration,turnaroundMinutes,
     totalMinutes:verifiedDuration, event
    });
    left-=length;index=(index+1)%7;pos=0;
   }
  }
 };
 // Booked schedules take precedence over server plans and local copies.
 for(const f of Array.isArray(drafts)?drafts:[])readFlight(f,'schedule');
 const readPlan=plan=>{
  const aircraftId=asAircraftId(plan),row=byAircraft.get(aircraftId);
  const flightNumber=String(plan?.flightNumber||'');
  if(!row||!/^[A-Z0-9]{2}[0-9]{1,4}$/.test(flightNumber)||
   seen.has(flightNumber))return;
  const schedule=orderedStops(plan.schedule||plan.weeklySchedule);
  if(!schedule.length)return;
  seen.add(flightNumber);
  const duration=Number.isInteger(plan.estimatedDurationMinutes)&&
   plan.estimatedDurationMinutes>0&&plan.estimatedDurationMinutes<=72*60?
   plan.estimatedDurationMinutes:
   validDuration(plan.referenceDepartureUtc,plan.referenceArrivalUtc);
  const ground=turnaroundValue(plan.operation?.turnaroundMinutes)??
   turnaroundValue(plan.turnaroundMinutes);
  const fromCode=airportCode(plan.from?.code)||airportCode(plan.originAirportCode);
  const toCode=airportCode(plan.to?.code)||airportCode(plan.destinationAirportCode);
  const unique=new Set();
  for(const stop of schedule){
   const minute=clockToMinute(stop.time),key=stop.day+'|'+minute;
   if(unique.has(key))continue;
   unique.add(key);
   const event={day:stop.day,minute,time:stop.time,flightNumber,
    status:'planning',fromCode,toCode,durationMinutes:null,
    sampleDurationMinutes:duration,turnaroundMinutes:ground,
    timing:duration===null?null:plannedRotationTiming(minute,duration,ground)};
   row.days[stop.day].events.push(event);
   const total=duration===null?null:duration+(ground??0);
   if(total===null){
    row.days[stop.day].bands.push({start:minute,end:minute,flightNumber,
     kind:'planned-departure',sourceDay:stop.day,continues:false,event});
    continue;
   }
   let pos=minute,left=total,index=stop.day;
   while(left>0){
    const length=Math.min(left,1440-pos);
    row.days[index].bands.push({
     start:pos,end:pos+length,flightNumber,kind:'planned-rotation',
     sourceDay:stop.day,continues:index!==stop.day,event
    });
    left-=length;index=(index+1)%7;pos=0;
   }
  }
 };
 for(const p of Array.isArray(plans)?plans:[])readPlan(p);
 for(const p of Array.isArray(localRoutes)?localRoutes:[])readPlan(p);
 for(const row of rows)for(const cell of row.days){
  cell.events.sort((a,b)=>a.minute-b.minute||a.flightNumber.localeCompare(b.flightNumber));
  cell.bands.sort((a,b)=>a.start-b.start);
  const events=cell.events;
  for(let i=1;i<events.length;i++)if(events[i-1].minute===events[i].minute)
   cell.warnings.push('Conflicting booked departures at '+events[i].time+'.');
  for(let i=1;i<cell.bands.length;i++)if(cell.bands[i-1].end>cell.bands[i].start)
   cell.warnings.push('Overlapping booked flight windows.');
 }
 const held=rows.flatMap(r=>r.days).reduce((n,c)=>n+c.bands.filter(b=>!b.continues&&b.kind==='slot-held').length,0);
 const flights=rows.reduce((n,r)=>n+r.flights,0);
 const planned=rows.flatMap(r=>r.days).reduce((n,c)=>n+
  c.events.filter(e=>e.status==='planning').length,0);
 return Object.freeze({status:rows.length?'ready':'empty',rows,
  counts:{flights,held,planned}});
}
const add=(doc,parent,tag,text,cls)=>{
 const el=doc.createElement(tag);
 if(cls)el.className=cls;
 if(text!==undefined&&text!==null)el.textContent=String(text);
 parent.append(el);
 return el;
};
const meta=(doc,el,label)=>el.setAttribute('aria-label',label);
const fullWeekDays=['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
const scaleTicks=Object.freeze(['00:00','03:00','06:00','09:00','12:00',
 '15:00','18:00','21:00','24:00']);
const pct=minute=>100*minute/1440;
const endClock=minute=>minute===1440?'24:00':minuteToClock(minute);
/**
 * Display ONE selected day and keep the registered aircraft visible.
 * Only booked flights have solid bars. Plans have dashed bars or markers.
 * If booking records were not received, show "unavailable", never "zero".
 */
export function renderAirlineWeeklyBoard(doc,host,board,{
 day=0,dateLabel=null,bookingsAvailable=true
}={}){
 if(!host)return;
 host.replaceChildren();
 if(!board||board.status==='unavailable'){
  add(doc,host,'p','Verified company fleet and scheduled routes are temporarily unavailable. No availability is assumed.','schedule-board-empty');
  return;
 }
 if(board.status==='empty'){
  add(doc,host,'p','This airline has no verified owned or leased aircraft in its connected fleet.','schedule-board-empty');
  return;
 }
 const selectedDay=Number.isInteger(day)&&day>=0&&day<7?day:0;
 // Show all verified owned/leased aircraft so missing bookings cannot hide
 // a real airplane. Do not draw any unreserved route or fake departure.
 const visibleRows=board.rows;
 const scroll=add(doc,host,'div',null,'schedule-board-scroll');
 const table=add(doc,scroll,'table',null,'schedule-board-table schedule-board-single-day');
 const head=add(doc,table,'thead'),heading=add(doc,head,'tr');
 const aircraftHeader=add(doc,heading,'th','Company aircraft');
 aircraftHeader.scope='col';aircraftHeader.className='schedule-board-aircraft-col';
 const dayHeader=add(doc,heading,'th');dayHeader.scope='col';
 add(doc,dayHeader,'strong',(dateLabel||fullWeekDays[selectedDay])+' · 24 hours (UTC)');
 const ticks=add(doc,dayHeader,'div',null,'schedule-board-hour-labels');
 for(const tick of scaleTicks)add(doc,ticks,'span',tick);
 const tbody=add(doc,table,'tbody');
 for(const aircraft of visibleRows){
  const tr=add(doc,tbody,'tr');
  const label=add(doc,tr,'th');label.scope='row';label.className='schedule-board-aircraft-col';
  const identity=add(doc,label,'div',null,'schedule-board-aircraft-identity');
  add(doc,identity,'strong',aircraft.registration);
  if(aircraft.nickname)add(doc,identity,'span',aircraft.nickname,'schedule-board-nickname');
  add(doc,label,'span',aircraft.name,'schedule-board-name');
  const td=add(doc,tr,'td');
  const cell=aircraft.days[selectedDay];
  const track=add(doc,td,'div',null,'schedule-board-day-track');
  meta(doc,track,(dateLabel||fullWeekDays[selectedDay])+', 00:00–24:00 UTC for '+aircraft.registration);
  // Separate lanes prevent a pair of close departures from obscuring
  // each other. Every lane still covers exactly one 24-hour day.
  const lanes=cell.bands.map(b=>({
   band:b,event:b.event||cell.events.find(e=>e.flightNumber===b.flightNumber)||null
  }));
  if(!lanes.length){
   const empty=add(doc,track,'div',null,'schedule-board-track-lane is-empty');
   add(doc,empty,'span',
    bookingsAvailable?'No booked flights on this date':'Booking records unavailable',
    'schedule-board-no-departures');
  }
  for(const {event,band} of lanes){
   const lane=add(doc,track,'div',null,'schedule-board-track-lane');
   const flightNumber=event?.flightNumber||band.flightNumber;
   const tooltip=flightScheduleTooltip(event,band);
   const isBooked=band.kind==='slot-held';
   if(band.kind==='planned-departure'){
    // No duration: retain the departure label, not a second orange stroke.
   }else{
    const filled=add(doc,lane,'div',null,
     'schedule-board-rotation-band '+(isBooked?'is-slot-held':'is-planning'));
    filled.style.left=pct(band.start)+'%';
    filled.style.width=pct(band.end-band.start)+'%';
    filled.title=tooltip+(isBooked?'':' | Saved route plan, not booked');
    meta(doc,filled,filled.title);
   }
   const route=(event?.fromCode&&event?.toCode)?
    ' · '+event.fromCode+' → '+event.toCode:'';
   const label=add(doc,lane,event?'button':'span',flightNumber+route,
    'schedule-board-inline-flight '+(isBooked?'is-slot-held':'is-planning'));
   if(event){
    label.type='button';
    label.setAttribute('data-schedule-flight',flightNumber);
    label.setAttribute('aria-label','Open '+flightNumber+route+
     (isBooked?' booked flight':' saved route plan')+' in My Routes. '+tooltip);
   }
   label.style.left=Math.min(pct(band.start),78)+'%';
   label.title=tooltip;
   if(!event)meta(doc,label,tooltip);
  }
 }
}
