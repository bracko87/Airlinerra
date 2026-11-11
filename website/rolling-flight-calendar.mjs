/** The timetable is a seven-day window anchored to the verified Berlin date.
 * One week = today + the following six dates. Recurring weekly flight
 * templates are projected into this window; no slot or flight is created.
 * Calendar arithmetic uses local *dates*, not a fixed number of seconds,
 * so the window remains correct on CET/CEST transition days.
 */
const PARTS=new Intl.DateTimeFormat('en-GB',{
 timeZone:'Europe/Berlin',year:'numeric',month:'2-digit',day:'2-digit'
});
const LABEL=new Intl.DateTimeFormat('en-GB',{
 timeZone:'UTC',weekday:'long',day:'2-digit',month:'short',year:'numeric'
});
export function berlinSevenDayWindow(epochMillis){
 if(!Number.isFinite(epochMillis))return [];
 const parts=Object.fromEntries(PARTS.formatToParts(new Date(epochMillis))
  .filter(p=>p.type!=='literal').map(p=>[p.type,Number(p.value)]));
 if(!parts.year||!parts.month||!parts.day)return [];
 const days=[];
 for(let offset=0;offset<7;offset++){
  const date=new Date(Date.UTC(parts.year,parts.month-1,parts.day+offset,12));
  const weekday=(date.getUTCDay()+6)%7;
  const iso=date.toISOString().slice(0,10);
  days.push(Object.freeze({
   offset,weekday,iso,
   label:LABEL.format(date),isToday:offset===0
  }));
 }
 return Object.freeze(days);
}
