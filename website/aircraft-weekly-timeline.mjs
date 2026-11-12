/** Read-only per-aircraft weekly planning timeline.
 * These may be owner-saved server routes, but are never proof of aircraft position.
 * A conflict prevents saving a contradictory draft, but a clean timeline does
 * not prove real flight feasibility, slot availability or turnaround clearance.
 */
export const WEEKDAYS=Object.freeze(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']);
const validTime=value=>/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(String(value||''));
const validStand=value=>['terminal','remote','cargo'].includes(value);
const name=airport=>String(airport?.code==='LYAL'||airport?.icao==='LYAL'?'Aleksandrovo':airport?.municipality||airport?.name||airport?.code||'Unknown airport');
const signature=event=>event.flightNumber+' '+WEEKDAYS[event.day]+' '+event.time;

/** Do not derive live location or arrival time from a local-only flight draft. */
export function buildAircraftWeeklyTimeline({
 aircraftId,routes=[],proposal=null,excludeFlightNumber=null,homeAirportKey=null
}={}){
 const events=[];
 if(!aircraftId||typeof aircraftId!=='string')
  return {aircraftId:null,events,errors:[],warnings:[],dayPositions:Array(7).fill(null)};
 const source=Array.isArray(routes)?routes.slice(0,100):[];
 if(proposal)source.push(proposal);
 for(const route of source){
  if(!route||route.aircraftId!==aircraftId||!route.from?.key||!route.to?.key)continue;
  if(route!==proposal&&excludeFlightNumber&&route.flightNumber===excludeFlightNumber)continue;
  for(const row of Array.isArray(route.schedule)?route.schedule.slice(0,7):[]){
   if(!Number.isInteger(row?.day)||row.day<0||row.day>6||!validTime(row.time))continue;
   events.push({
    day:row.day,time:row.time,flightNumber:String(route.flightNumber||'Unnumbered'),
    fromKey:String(route.from.key),toKey:String(route.to.key),
    from:name(route.from),to:name(route.to),
    arrivalStand:validStand(route.operation?.arrivalStand)?route.operation.arrivalStand:null,
    proposed:route===proposal,
    departureStand:validStand(route.operation?.departureStand)?route.operation.departureStand:null,
    priorLocation:null,
    timingVerified:false
   });
  }
 }
 events.sort((a,b)=>a.day-b.day||a.time.localeCompare(b.time)||
  a.flightNumber.localeCompare(b.flightNumber));
 const errors=[],warnings=[],dayPositions=Array(7).fill(null);
 let previous=null;
 for(const event of events){
  if(previous){
   event.priorLocation=previous.to;
   // A recurring draft describes one flight number, not a full rotation.
   // Treat repeated legs as unfinished drafts, not as operationally validated
   // repositioning. The missing return is highlighted below for every cycle.
   // Do not accuse the FIRST flight of being misplaced merely because
   // its next weekday occurrence is shown before a return leg is added.
   const sameRecurringRoute=previous.flightNumber===event.flightNumber&&
    previous.fromKey===event.fromKey&&previous.toKey===event.toKey;
   if(!sameRecurringRoute&&previous.toKey!==event.fromKey){
    errors.push({
     code:'AIRCRAFT_WRONG_AIRPORT',day:event.day,flightNumber:event.flightNumber,
     text:'Aircraft is in '+previous.to+' after '+signature(previous)+
      '; it cannot depart from '+event.from+' on '+signature(event)+
      '. Schedule a return/repositioning flight or select a different aircraft.'
    });
   }else if(!sameRecurringRoute&&previous.arrivalStand){
    // Stand follows the last arrival at the same airport, never the next
    // route's independently selected/guessed departure stand.
    event.departureStand=previous.arrivalStand;
   }
   if(previous.day===event.day&&previous.time===event.time){
    errors.push({
     code:'SAME_TIME',day:event.day,flightNumber:event.flightNumber,
     text:'Aircraft already has '+signature(previous)+
      '. Two departures at the same local time are not possible.'
    });
   }
  }else{
   // Headquarters is not proof of this exact aircraft's initial stand.
   event.priorLocation=null;
  }
  dayPositions[event.day]={airport:event.to,airportKey:event.toKey,
   stand:event.arrivalStand,flightNumber:event.flightNumber};
  previous=event;
 }
 if(events.length){
  const first=events[0],last=events.at(-1);
  const earlierRouteExists=Boolean(proposal)&&source.some(route=>route!==proposal&&
   route?.aircraftId===aircraftId&&
   Array.isArray(route.schedule)&&route.schedule.length>0);
  if(earlierRouteExists&&last.toKey!==first.fromKey){
   warnings.push('Weekly cycle is incomplete: after '+signature(last)+
    ' the aircraft is in '+last.to+
    ', but the recurring schedule next begins in '+first.from+
    '. A return or repositioning flight must be added before activation.');
  }
  warnings.push('Arrival times, airport time zones, flight duration, turnaround and actual aircraft parking are not verified. Draft sequence alone cannot authorize flights.');
  if(homeAirportKey&&first.fromKey!==homeAirportKey)
   warnings.push('First planned departure is not from the airline headquarters. The aircraft’s real initial position must be confirmed.');
 }
 return {aircraftId,events,errors,warnings,dayPositions};
}

/** Safe DOM-only timeline renderer; route/airport names are untrusted database text. */
export function renderAircraftWeeklyTimeline(doc,host,timeline,{compact=false}={}){
 if(!host)return;
 host.replaceChildren();
 const events=timeline?.events||[];
 if(!timeline?.aircraftId){
  const p=doc.createElement('p');p.className='route-subtle-note';
  p.textContent='Choose an aircraft to view its weekly schedule and planned locations.';
  host.append(p);return;
 }
 if(!events.length){
  const p=doc.createElement('p');p.className='route-subtle-note';
  p.textContent='No weekly flight drafts for this aircraft. Current real-world position and stand are not connected.';
  host.append(p);return;
 }
 const table=doc.createElement('div');table.className='aircraft-weekly-timeline-table';
 const heading=doc.createElement('div');heading.className='aircraft-weekly-timeline-row is-heading';
 for(const label of ['Day','Departure','Flight','From','To / position after flight','Departure stand','Arrival stand']){
  const cell=doc.createElement('span');cell.textContent=label;heading.append(cell);
 }
 table.append(heading);
 for(const e of events){
  const line=doc.createElement('div');line.className='aircraft-weekly-timeline-row';
  for(const value of [
   WEEKDAYS[e.day],e.time,e.flightNumber,e.from,e.to,
   e.departureStand==='remote'?'Remote stand':e.departureStand==='terminal'?'Terminal':e.departureStand==='cargo'?'Cargo stand':'Unverified',
   e.arrivalStand==='remote'?'Remote stand':e.arrivalStand==='terminal'?'Terminal':e.arrivalStand==='cargo'?'Cargo stand':'Unverified'
  ]){
   const cell=doc.createElement('span');cell.textContent=value;line.append(cell);
  }
  if(e.proposed)line.classList.add('is-proposed');
  table.append(line);
 }
 const scroller=doc.createElement('div');scroller.className='aircraft-weekly-timeline-scroll';
 scroller.append(table);host.append(scroller);
 for(const issue of timeline.errors||[]){
  const msg=doc.createElement('p');msg.className='aircraft-weekly-timeline-error';
  msg.textContent=issue.text;host.append(msg);
 }
 if(!compact)for(const warning of timeline.warnings||[]){
  const p=doc.createElement('p');p.className='route-subtle-note';
  p.textContent=warning;host.append(p);
 }
}
