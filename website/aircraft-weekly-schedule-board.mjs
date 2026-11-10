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
 return Number.isFinite(minutes)&&minutes>0&&minutes<=72*60?minutes:null;
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
export function renderAirlineWeeklyBoard(doc,host,board){
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
 const scroll=add(doc,host,'div',null,'schedule-board-scroll');
 const table=add(doc,scroll,'table',null,'schedule-board-table');
 const head=add(doc,table,'thead'),heading=add(doc,head,'tr');
 const aircraftHeader=add(doc,heading,'th','Company aircraft');
 aircraftHeader.scope='col';aircraftHeader.className='schedule-board-aircraft-col';
 for(const name of WEEK_DAYS){
  const cell=add(doc,heading,'th');cell.scope='col';
  add(doc,cell,'strong',name);
  const ticks=add(doc,cell,'div',null,'schedule-board-hour-labels');
  for(const tick of ['00','06','12','18','24'])add(doc,ticks,'span',tick);
 }
 const tbody=add(doc,table,'tbody');
 for(const aircraft of board.rows){
  const tr=add(doc,tbody,'tr');
  const label=add(doc,tr,'th');label.scope='row';label.className='schedule-board-aircraft-col';
  add(doc,label,'strong',aircraft.registration);
  add(doc,label,'span',aircraft.name,'schedule-board-name');
  add(doc,label,'small',aircraft.ownership+' · '+aircraft.fleetStatus);
  for(const cell of aircraft.days){
   const td=add(doc,tr,'td');
   const track=add(doc,td,'div',null,'schedule-board-track');
   meta(doc,track,WEEK_DAYS[cell.day]+' UTC, 00:00 to 24:00');
   for(const band of cell.bands){
    const el=add(doc,track,'div',null,'schedule-board-held-band');
    el.style.left=100*band.start/1440+'%';
    el.style.width=Math.max(0,100*(band.end-band.start)/1440)+'%';
    el.title=band.flightNumber+' · confirmed airport-slot flight window '+
     minuteToClock(band.start)+'–'+(band.end===1440?'24:00':minuteToClock(band.end))+
     ' UTC · no flight activation';
   }
   const used=new Set();
   for(const event of cell.events){
    if(used.has(event.minute))continue;used.add(event.minute);
    const pin=add(doc,track,'span',null,'schedule-board-time-marker');
    pin.style.left=100*event.minute/1440+'%';
    pin.title='Planned departure '+event.time+' UTC';
   }
   const list=add(doc,td,'div',null,'schedule-board-flights');
   for(const event of cell.events){
    const item=add(doc,list,'div',null,'schedule-board-flight '+event.status);
    add(doc,item,'strong',event.time+' · '+event.flightNumber);
    if(event.from||event.to)
     add(doc,item,'span',(event.from||'Origin')+' → '+(event.to||'Destination'));
    let text;
    if(event.status==='slot-held'&&event.durationMinutes!==null){
     const end=event.minute+event.durationMinutes;
     const dayOffset=Math.floor(end/1440);
     text='UTC window '+event.time+'–'+minuteToClock(end)+
      (dayOffset?' (+'+dayOffset+' day'+(dayOffset===1?'':'s')+')':'')+
      ' · '+event.durationMinutes+' min · airport slots held; turnaround not verified';
    }else if(event.sampleDurationMinutes!==null){
     text='Example flight duration '+event.sampleDurationMinutes+
      ' min · not verified or booked';
    }else{
     text='Flight duration pending · time not reserved';
    }
    add(doc,item,'small',text);
    meta(doc,item,event.flightNumber+', '+event.time+' UTC, '+event.statusLabel+'. '+text);
   }
   if(!cell.events.length&&!cell.bands.length)
    add(doc,list,'span','No departures · availability unverified','schedule-board-no-departures');
   for(const warning of cell.warnings)
    add(doc,list,'p',warning,'schedule-board-warning');
  }
 }
}
