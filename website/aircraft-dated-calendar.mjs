// A dated, UTC aircraft calendar. Only confirmed server events are rendered.
const MINUTE=60000, DAY=1440*MINUTE, BASELINE=1080;
export function utilizationForMinutes(minutes){
 if(!Number.isFinite(minutes)||minutes<0)return null;
 return {percent:Math.min(100,Math.round(minutes/BASELINE*100)),overloaded:minutes>BASELINE,
 wearMultiplier:minutes<=BASELINE?1:1+2*Math.pow(Math.min(1,(minutes-BASELINE)/360),1.5)};
}
const time=x=>Date.parse(x);
const clip=(a,b,start,end)=>Math.max(0,Math.min(b,end)-Math.max(a,start))/MINUTE;
export function buildDatedCalendar(fleet,events,date){
 if(!Array.isArray(fleet)||!Array.isArray(events)||!/^\d{4}-\d{2}-\d{2}$/.test(date||''))return null;
 const start=time(date+'T00:00:00Z'),end=start+DAY;
 if(!Number.isFinite(start))return null;
 return fleet.filter(a=>['owned','leased'].includes(a.ownershipType)).map(a=>{
  const blocks=[];
  for(const e of events){
   if(e.aircraftInventoryId!==a.id||!['flight','maintenance','relocation'].includes(e.kind))continue;
   const s=time(e.startUtc),t=time(e.endUtc),arr=time(e.arrivalUtc);
   if(!Number.isFinite(s)||!Number.isFinite(t)||s>=t||s>=end||t<=start)continue;
   if(e.kind!=='maintenance'&&(!Number.isFinite(arr)||arr<=s||arr>t))continue;
   blocks.push({...e,begin:(Math.max(s,start)-start)/MINUTE,finish:(Math.min(t,end)-start)/MINUTE,flightMinutes:e.kind!=='maintenance'?clip(s,arr,start,end):0,flightEnd:e.kind!=='maintenance'?Math.max(0,Math.min(1440,(arr-start)/MINUTE)):null});
  }
  blocks.sort((a,b)=>a.begin-b.begin||a.finish-b.finish);
  // Union the operating intervals; overlapping records cannot inflate usage.
  const intervals=blocks.filter(b=>b.kind!=='maintenance'&&b.flightEnd>b.begin).map(b=>[b.begin,b.flightEnd]).sort((a,b)=>a[0]-b[0]);
  let total=0,last=0;for(const [a,b] of intervals){total+=Math.max(0,b-Math.max(a,last));last=Math.max(last,b);}
  let overlap=false,until=0;for(const b of blocks){if(b.begin<until)overlap=true;until=Math.max(until,b.finish);}
  return {...a,blocks,usage:utilizationForMinutes(total),overlap};
 });
}
const add=(doc,parent,tag,label,cls)=>{const x=doc.createElement(tag);if(cls)x.className=cls;if(label!=null)x.textContent=label;parent.append(x);return x;};
const dt=x=>{const n=time(x);return Number.isFinite(n)?new Date(n).toISOString().slice(0,16).replace('T',' ')+' UTC':'Unavailable';};
export function renderDatedCalendar(doc,host,rows,date){
 host.replaceChildren();
 if(!rows){add(doc,host,'p','Verified aircraft calendar unavailable. Refresh to retry.','hint');return;}
 if(!rows.length){add(doc,host,'p','No owned or leased aircraft.','hint');return;}
 const table=add(doc,add(doc,host,'div',null,'schedule-board-scroll'),'table',null,'schedule-board-table schedule-board-single-day');
 const header=add(doc,add(doc,table,'thead'),'tr');
 add(doc,header,'th','Aircraft','schedule-board-aircraft-col');
 const h=add(doc,header,'th',date+' - UTC');
 const ticks=add(doc,h,'div',null,'schedule-board-hour-labels');
 for(let n=0;n<=24;n+=3)add(doc,ticks,'span',String(n).padStart(2,'0')+':00');
 const body=add(doc,table,'tbody');
 for(const row of rows){
  const tr=add(doc,body,'tr'),id=add(doc,tr,'th',row.registration,'schedule-board-aircraft-col');
  if(row.nickname)add(doc,id,'div',row.nickname,'schedule-board-nickname');
  if(row.model)add(doc,id,'div',[row.manufacturer,row.model].filter(Boolean).join(' '),'schedule-board-name');
  add(doc,id,'div',row.usage.percent+'% scheduled utilization'+(row.usage.overloaded?' - overloaded':''),'hint');
  const track=add(doc,add(doc,tr,'td'),'div',null,'schedule-board-day-track');
  if(!row.blocks.length)add(doc,track,'p','No confirmed flights or maintenance on this date.','hint');
  for(const b of row.blocks){
   const lane=add(doc,track,'div',null,'schedule-board-track-lane');
   const title=b.kind!=='maintenance'?b.label+' '+b.fromCode+' - '+b.toCode:b.label+' - '+b.fromCode;
   const details=b.kind!=='maintenance'?title+' | Departure '+dt(b.startUtc)+' | Arrival '+dt(b.arrivalUtc)+' | Turnaround '+b.turnaroundMinutes+' min | Available '+dt(b.endUtc)+' | Status '+b.status+(b.kind==='relocation'&&b.costUsd!=null?' | USD '+Number(b.costUsd).toLocaleString('en-US'):''):title+' | Start '+dt(b.startUtc)+' | End/block until '+dt(b.endUtc)+' | '+b.status+(b.costUsd!=null?' | $'+Number(b.costUsd).toLocaleString('en-US'):'');
   const band=add(doc,lane,'div',null,'schedule-board-rotation-band is-slot-held');
   band.style.left=b.begin/14.4+'%';band.style.width=(b.finish-b.begin)/14.4+'%';
   band.style.background=b.kind==='maintenance'?'#8756b8':b.kind==='relocation'?'#298c84':'#2878c7';
   if(b.kind!=='maintenance'&&b.finish>b.flightEnd){const p=Math.max(0,Math.min(100,100*(b.flightEnd-b.begin)/(b.finish-b.begin)));band.style.background='linear-gradient(to right,'+(b.kind==='relocation'?'#298c84':'#2878c7')+' '+p+'%,'+(b.kind==='relocation'?'#1d605a':'#205993')+' '+p+'%)';}
   band.title=details;
   const label=add(doc,lane,'button',title,'schedule-board-inline-flight is-slot-held');
   label.type='button';label.style.left=Math.min(b.begin/14.4,75)+'%';label.title=details;label.setAttribute('aria-label',details);
   if(b.kind==='flight')label.dataset.scheduleFlight=b.label;
   else label.addEventListener('click',()=>{const info=lane.querySelector('.schedule-maintenance-detail');if(info)info.remove();else add(doc,lane,'p',details,'schedule-maintenance-detail');});
  }
  if(row.overlap)add(doc,track,'p','Schedule conflict: overlapping confirmed reservations.','hint');
 }
 add(doc,host,'p','Blue: commercial flight. Teal: empty relocation. Purple: maintenance. Darker flight portion: turnaround. Utilization includes all flying but excludes turnaround and maintenance.','hint');
}
