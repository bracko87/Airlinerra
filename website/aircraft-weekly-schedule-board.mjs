/**
 * Seven-day aircraft rota for an airline's real owned/leased fleet.
 * All times are shown on the 00:00–24:00 UTC scale for each weekday.
 * IMPORTANT: A planning draft is a departure marker, NOT a booked aircraft
 * interval. Only explicitly slot-reserved, verified-duration schedule drafts
 * have a coloured flight window. Those windows are not live flights and do
 * not prove ground-turnaround availability.
 */
export const WEEK_DAYS=Object.freeze(['Mon','Tue','Wed','Thu','Fri','Sat','Sun']);
const HHMM=/^(?:[01]\d|2[0-3]):[0-5]\d$/;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const idOf=a=>typeof a?.id==='string'&&UUID.test(a.id)?a.id:null;
const ownership=a=>['owned','leased'].includes(a?.ownershipType);
const clockToMinute=s=>HHMM.test(s||'')?Number(s.slice(0,2))*60+Number(s.slice(3)):null;
const minuteToClock=n=>String(Math.floor(n/60)%24).padStart(2,'0')+':'+String(n%60).padStart(2,'0');
const valueOf=x=>String(x||'').slice(0,96);
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
const statusOf=(flight,source)=>{
 if(source==='schedule'&&flight?.slotsReserved===true)return 'slot-held';
 if(source==='schedule')return 'schedule-unverified';
 if(source==='plan')return 'airline-plan';
 return 'local-plan';
};
const slotStatusLabel={
 'slot-held':'Airport slots reserved · not activated',
 'schedule-unverified':'Server schedule draft · slots unverified',
 'airline-plan':'Airline planning route · no slots',
 'local-plan':'Local planning draft · no slots'
};
/** Pure data model. Never creates a booking or assumes a route is airborne. */
export function buildAirlineWeeklyBoard({fleet,serverFleet,plans=[],drafts=[],localRoutes=[]}={}){
 const verifiedFleet=Array.isArray(fleet)?fleet:Array.isArray(serverFleet)?serverFleet:null;
 if(verifiedFleet===null)return Object.freeze({status:'unavailable',rows:[],counts:{flights:0,held:0}});
 const aircraft=[...new Map(verifiedFleet.filter(a=>idOf(a)&&ownership(a)).map(a=>[a.id,a])).values()]
  .sort((a,b)=>String(a.registration||'').localeCompare(String(b.registration||'')));
 const rows=aircraft.map(a=>({
  id:a.id,registration:valueOf(a.registration)||'Unregistered',
  name:[a.manufacturer,a.model].filter(Boolean).join(' ')||valueOf(a.model)||'Aircraft',
  ownership:a.ownershipType,
  fleetStatus:valueOf(a.fleetStatus)||'unverified',
  days:WEEK_DAYS.map((_,day)=>({day,events:[],bands:[],warnings:[]})),
  flights:0
 }));
 const byAircraft=new Map(rows.map(row=>[row.id,row]));
 const seen=new Set();
 const readFlight=(flight,source)=>{
  const aircraftId=asAircraftId(flight),row=byAircraft.get(aircraftId);
  const flightNumber=String(flight?.flightNumber||'');
  if(!row||!/^[A-Z0-9]{2}[0-9]{1,4}$/.test(flightNumber))return;
  const schedule=orderedStops(source==='schedule'?flight.weeklySchedule:flight.schedule);
  if(!schedule.length)return;
  // Server planning takes precedence over browser duplicates. A reserved
  // server schedule has priority over planning data with the same number.
  // Flight number belongs to the airline, not to a particular aircraft.
  // A stale browser draft must not reappear on the previous aircraft after
  // the server has reassigned the same flight to another tail.
  const key=flightNumber;
  if(seen.has(key))return;
  seen.add(key);
  const status=statusOf(flight,source);
  const verifiedDuration=source==='schedule'&&status==='slot-held'?
   validDuration(flight.referenceDepartureUtc,flight.referenceArrivalUtc):null;
  const sampleDuration=source==='plan'?
   validDuration(flight.referenceDepartureUtc,flight.referenceArrivalUtc):null;
  const unique=new Set();
  for(const stop of schedule){
   const minute=clockToMinute(stop.time),eventKey=stop.day+'|'+minute;
   if(unique.has(eventKey))continue;
   unique.add(eventKey);
   const event={
    day:stop.day,minute,time:stop.time,flightNumber,
    from:valueOf(flight?.from?.code||flight?.originAirportKey),
    to:valueOf(flight?.to?.code||flight?.destinationAirportKey),
    status,statusLabel:slotStatusLabel[status],
    durationMinutes:verifiedDuration,
    sampleDurationMinutes:sampleDuration
   };
   row.days[stop.day].events.push(event);
   row.flights++;
   // Only verified airport-slot reservations can form booked-style windows.
   // Wrap flight air-time across midnight and the week boundary if needed.
   if(verifiedDuration!==null){
    let pos=minute,left=verifiedDuration,index=stop.day;
    while(left>0){
     const length=Math.min(left,1440-pos);
     row.days[index].bands.push({
      start:pos,end:pos+length,
      flightNumber,kind:'slot-held',sourceDay:stop.day,
      continues:index!==stop.day
     });
     left-=length;index=(index+1)%7;pos=0;
    }
   }
  }
 };
 // Server-backed schedule wins when the same flight appears in multiple
 // sources. Never double-count a server-backed route and its browser copy.
 for(const f of Array.isArray(drafts)?drafts:[])readFlight(f,'schedule');
 for(const f of Array.isArray(plans)?plans:[])readFlight(f,'plan');
 for(const f of Array.isArray(localRoutes)?localRoutes:[])readFlight(f,'local');
 for(const row of rows)for(const cell of row.days){
  cell.events.sort((a,b)=>a.minute-b.minute||a.flightNumber.localeCompare(b.flightNumber));
  cell.bands.sort((a,b)=>a.start-b.start);
  const events=cell.events;
  for(let i=1;i<events.length;i++)if(events[i-1].minute===events[i].minute)
   cell.warnings.push('Multiple departures at '+events[i].time+'; aircraft rotation not verified.');
  for(let i=1;i<cell.bands.length;i++)if(cell.bands[i-1].end>cell.bands[i].start)
   cell.warnings.push('Overlapping slot-held flight windows; investigate before activation.');
 }
 const held=rows.flatMap(r=>r.days).reduce((n,c)=>n+c.bands.filter(b=>!b.continues).length,0);
 const flights=rows.reduce((n,r)=>n+r.flights,0);
 return Object.freeze({status:rows.length?'ready':'empty',rows,counts:{flights,held}});
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
 * Display exactly ONE weekday, with all real company aircraft as rows.
 * Each lane keeps the entire 24-hour scale. One flight's blue interval
 * is exactly its verified air-time, never a fixed-width card.
 * Orange markers denote unreserved, unverified planning departures.
 */
export function renderAirlineWeeklyBoard(doc,host,board,{day=0}={}){
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
 const scroll=add(doc,host,'div',null,'schedule-board-scroll');
 const table=add(doc,scroll,'table',null,'schedule-board-table schedule-board-single-day');
 const head=add(doc,table,'thead'),heading=add(doc,head,'tr');
 const aircraftHeader=add(doc,heading,'th','Company aircraft');
 aircraftHeader.scope='col';aircraftHeader.className='schedule-board-aircraft-col';
 const dayHeader=add(doc,heading,'th');dayHeader.scope='col';
 add(doc,dayHeader,'strong',fullWeekDays[selectedDay]+' · 24 hours (UTC)');
 const ticks=add(doc,dayHeader,'div',null,'schedule-board-hour-labels');
 for(const tick of scaleTicks)add(doc,ticks,'span',tick);
 const tbody=add(doc,table,'tbody');
 for(const aircraft of board.rows){
  const tr=add(doc,tbody,'tr');
  const label=add(doc,tr,'th');label.scope='row';label.className='schedule-board-aircraft-col';
  add(doc,label,'strong',aircraft.registration);
  add(doc,label,'span',aircraft.name,'schedule-board-name');
  add(doc,label,'small',aircraft.ownership+' · '+aircraft.fleetStatus);
  const td=add(doc,tr,'td');
  const cell=aircraft.days[selectedDay];
  const track=add(doc,td,'div',null,'schedule-board-day-track');
  meta(doc,track,fullWeekDays[selectedDay]+', 00:00–24:00 UTC for '+aircraft.registration);
  // Separate lanes prevent a pair of close departures from obscuring
  // each other. Every lane still covers exactly one 24-hour day.
  const bands=cell.bands.map(b=>({
   ...b,event:cell.events.find(e=>e.flightNumber===b.flightNumber)||
    null
  }));
  const renderedFlights=new Set(bands.map(b=>b.flightNumber));
  const lanes=[...bands.map(b=>({band:b,event:b.event})),
   ...cell.events.filter(e=>!renderedFlights.has(e.flightNumber)).
    map(e=>({event:e,band:null}))];
  if(!lanes.length){
   const empty=add(doc,track,'div',null,'schedule-board-track-lane is-empty');
   add(doc,empty,'span','No departures · aircraft availability not verified','schedule-board-no-departures');
  }
  for(const {event,band} of lanes){
   const lane=add(doc,track,'div',null,'schedule-board-track-lane');
   const flightNumber=event?.flightNumber||band?.flightNumber||'Flight';
   const start=band?.start??event?.minute??0;
   const slotHeld=Boolean(band&&band.kind==='slot-held');
   const duration=event?.durationMinutes??null;
   const tooltip=slotHeld?
    flightNumber+' · verified slot-held flight window '+
    minuteToClock(band.start)+'–'+endClock(band.end)+
    ' UTC; actual turnaround and flight activation not verified':
    flightNumber+' · '+(event?.time||'Continuing flight')+
    ' UTC · planned departure; flight duration and aircraft reservation unverified';
   if(slotHeld){
    const filled=add(doc,lane,'div',null,'schedule-board-held-band');
    filled.style.left=pct(band.start)+'%';
    filled.style.width=pct(band.end-band.start)+'%';
    filled.title=tooltip;
    meta(doc,filled,tooltip);
   }else{
    const marker=add(doc,lane,'span',null,'schedule-board-time-marker');
    marker.style.left=pct(start)+'%';
    marker.title=tooltip;
   }
   const text=add(doc,lane,'span',
    flightNumber+(event?' · '+event.time:' · continues')+
    (slotHeld&&duration!==null?' · '+duration+' min':''),
    'schedule-board-inline-flight'+(slotHeld?' is-slot-held':' is-planning'));
   // A short flight interval must remain short; move its *label* to the
   // side when necessary without changing the occupied interval width.
   text.style.left=Math.min(pct(start),87)+'%';
   text.title=tooltip;
   meta(doc,text,tooltip);
  }
  for(const warning of cell.warnings)
   add(doc,td,'p',warning,'schedule-board-warning');
 }
}
