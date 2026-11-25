// A dated, UTC aircraft calendar. Only confirmed server events are rendered.
const MINUTE=60000, DAY=1440*MINUTE;
export function utilizationForMinutes(minutes,windowMinutes=1440){
 if(!Number.isFinite(minutes)||minutes<0||!Number.isFinite(windowMinutes)||windowMinutes<=0)return null;
 return {percent:Math.min(100,Math.round(minutes/windowMinutes*100)),highUtilization:minutes>windowMinutes*.75,occupiedMinutes:Math.min(windowMinutes,minutes)};
}
const time=x=>Date.parse(x);
const clip=(a,b,start,end)=>Math.max(0,Math.min(b,end)-Math.max(a,start))/MINUTE;
function calendarRange(value){
 if(typeof value==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(value)){const start=time(value+'T00:00:00Z');return Number.isFinite(start)?{start,end:start+DAY,minutes:1440}:null;}
 if(!value||!Number.isFinite(value.start)||value.minutes!==720)return null;
 return {start:value.start,end:value.start+720*MINUTE,minutes:720};
}
export function buildDatedCalendar(fleet,events,date){
 if(!Array.isArray(fleet)||!Array.isArray(events))return null;
 const window=calendarRange(date);if(!window)return null;
 const {start,end,minutes}=window;
 return fleet.filter(a=>['owned','leased'].includes(a.ownershipType)).map(a=>{
  const blocks=[];
  for(const e of events){
   if(e.aircraftInventoryId!==a.id||!['flight','maintenance','relocation'].includes(e.kind))continue;
   const s=time(e.startUtc),t=time(e.endUtc),arr=time(e.arrivalUtc);
   if(!Number.isFinite(s)||!Number.isFinite(t)||s>=t||s>=end||t<=start)continue;
   if(e.kind!=='maintenance'&&(!Number.isFinite(arr)||arr<=s||arr>t))continue;
   blocks.push({...e,begin:(Math.max(s,start)-start)/MINUTE,finish:(Math.min(t,end)-start)/MINUTE,flightMinutes:e.kind!=='maintenance'?clip(s,arr,start,end):0,flightEnd:e.kind!=='maintenance'?Math.max(0,Math.min(minutes,(arr-start)/MINUTE)):null});
  }
  blocks.sort((a,b)=>a.begin-b.begin||a.finish-b.finish);
  // Union the operating intervals; overlapping records cannot inflate usage.
  const intervals=blocks.filter(b=>b.kind!=='maintenance'&&b.finish>b.begin).map(b=>[b.begin,b.finish]).sort((a,b)=>a[0]-b[0]);
  let total=0,last=0;for(const [a,b] of intervals){total+=Math.max(0,b-Math.max(a,last));last=Math.max(last,b);}
  let overlap=false,until=0;for(const b of blocks){if(b.begin<until)overlap=true;until=Math.max(until,b.finish);}
  return {...a,blocks,usage:utilizationForMinutes(total,minutes),overlap};
 });
}
const add=(doc,parent,tag,label,cls)=>{const x=doc.createElement(tag);if(cls)x.className=cls;if(label!=null)x.textContent=label;parent.append(x);return x;};
export function compactAircraftFamily(row){
 const source=String(row?.family||'').trim();
 const match=source.match(/\b(A\d{3}|B?7\d{2}|CRJ|ERJ|E-?Jets?|ATR\s*\d{2}|Dash\s*8|MD-?\d+|DC-?\d+)\b/i);
 if(match)return match[1].toUpperCase().replace(/\s+/g,'');
 return source.replace(/^(Airbus|Boeing|Embraer|Bombardier|De Havilland)\s+/i,'').replace(/\s+family$/i,'').slice(0,14);
}
const dt=x=>{const n=time(x);return Number.isFinite(n)?new Date(n).toISOString().slice(0,16).replace('T',' ')+' UTC':'Unavailable';};
export function renderDatedCalendar(doc,host,rows,date){
 host.replaceChildren();
 const range=calendarRange(date);
 if(!rows||!range){add(doc,host,'p','Verified aircraft calendar unavailable. Refresh to retry.','hint');return;}
 if(!rows.length){add(doc,host,'p','No owned or leased aircraft.','hint');return;}
 const table=add(doc,add(doc,host,'div',null,'schedule-board-scroll'),'table',null,'schedule-board-table schedule-board-single-day'+(range.minutes===720?' schedule-board-rolling-12h':''));
 const header=add(doc,add(doc,table,'thead'),'tr');
 add(doc,header,'th','Aircraft','schedule-board-aircraft-col');
 const rolling=range.minutes===720;
 const heading=rolling?dt(new Date(range.start).toISOString()).replace(' UTC','')+' → '+dt(new Date(range.end).toISOString()):date+' - UTC';
 const h=add(doc,header,'th',heading);
 const ticks=add(doc,h,'div',null,'schedule-board-hour-labels');
 for(let n=0;n<=range.minutes;n+=rolling?120:180){
  const tick=rolling?new Date(range.start+n*MINUTE).toISOString().slice(11,16):String(n/60).padStart(2,'0')+':00';
  add(doc,ticks,'span',tick);
 }
 const body=add(doc,table,'tbody');
 for(const row of rows){
  const tr=add(doc,body,'tr'),id=add(doc,tr,'th',null,'schedule-board-aircraft-col');
  const identity=add(doc,id,'div',null,'schedule-board-aircraft-identity');
  add(doc,identity,'strong',row.registration);
  const family=compactAircraftFamily(row);
  if(family)add(doc,identity,'span',family,'schedule-board-family-code');
  if(row.nickname)add(doc,id,'div',row.nickname,'schedule-board-nickname');
  const track=add(doc,add(doc,tr,'td'),'div',null,'schedule-board-day-track');
  // Reuse the same 24-hour lane for every non-overlapping reservation.
  // Extra lanes are only needed to expose an actual overlap, not a new flight.
  const lanes=[{element:add(doc,track,'div',null,'schedule-board-track-lane schedule-board-dated-lane'),until:0}];
  if(!row.blocks.length)add(doc,lanes[0].element,'p',rolling?'No confirmed flights or maintenance in this 12-hour period.':'No confirmed flights or maintenance on this date.','hint');
  for(const b of row.blocks){
   let slot=lanes.find(l=>l.until<=b.begin);
   if(!slot){slot={element:add(doc,track,'div',null,'schedule-board-track-lane schedule-board-dated-lane'),until:0};lanes.push(slot);}
   slot.until=b.finish;
   const lane=slot.element;
   const title=b.kind!=='maintenance'?b.label+' '+b.fromCode+' - '+b.toCode:b.label+' - '+b.fromCode;
   const details=b.kind!=='maintenance'?title+' | Departure '+dt(b.startUtc)+' | Arrival '+dt(b.arrivalUtc)+' | Turnaround '+b.turnaroundMinutes+' min | Available '+dt(b.endUtc)+' | Status '+b.status+(b.kind==='relocation'&&b.costUsd!=null?' | USD '+Number(b.costUsd).toLocaleString('en-US'):''):title+' | Start '+dt(b.startUtc)+' | End/block until '+dt(b.endUtc)+' | '+b.status+(b.costUsd!=null?' | $'+Number(b.costUsd).toLocaleString('en-US'):'');
   const band=add(doc,lane,'button',title,'schedule-board-dated-event');
   band.type='button';
   band.style.left=100*b.begin/range.minutes+'%';band.style.width=100*(b.finish-b.begin)/range.minutes+'%';
   band.style.background=b.kind==='maintenance'?'#8756b8':b.kind==='relocation'?'#298c84':'#2878c7';
   if(b.kind!=='maintenance'&&b.finish>b.flightEnd){const p=Math.max(0,Math.min(100,100*(b.flightEnd-b.begin)/(b.finish-b.begin)));band.style.background='linear-gradient(to right,'+(b.kind==='relocation'?'#298c84':'#2878c7')+' '+p+'%,'+(b.kind==='relocation'?'#1d605a':'#205993')+' '+p+'%)';}
   band.title=details;band.setAttribute('aria-label',details);
   if(b.kind==='flight')band.dataset.scheduleFlight=b.label;
   else band.addEventListener('click',()=>{const info=track.querySelector('.schedule-maintenance-detail');if(info)info.remove();else add(doc,track,'p',details,'schedule-maintenance-detail');});
  }
  if(row.overlap)add(doc,track,'p','Schedule conflict: overlapping confirmed reservations.','hint');
 }
 add(doc,host,'p','Blue: commercial flight. Teal: empty relocation. Purple: maintenance. Darker flight portion: turnaround.','hint');
}
