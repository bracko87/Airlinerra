/** Time information from an owner-saved planning estimate, never ATC clearance.
 * Only read the modelled duration when the owner-scoped database workplan
 * and the authoritative planning route identify the exact same proposal.
 */
const CLOCK=/^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/;
const minuteOfDay=value=>{
 if(typeof value!=='string'||!CLOCK.test(value))return null;
 const [h,m]=value.split(':').map(Number);
 return h*60+m;
};
const clock=minutes=>{
 const normalized=((minutes%1440)+1440)%1440;
 return String(Math.floor(normalized/60)).padStart(2,'0')+':'+
  String(normalized%60).padStart(2,'0');
};
const weeklyShape=value=>Array.isArray(value)&&value.length>=1&&
 value.length<=7&&value.every(x=>Number.isInteger(x?.day)&&
 x.day>=0&&x.day<=6&&minuteOfDay(x.time)!==null)?
 value.map(x=>x.day+':'+x.time).sort().join('|'):null;
export function ownerPlanningEstimate(plan,savedRoutes){
 if(!plan||typeof plan.planId!=='string'||!Array.isArray(savedRoutes))return {};
 const saved=savedRoutes.find(p=>p?.serverPlanningId===plan.planId&&
  p.flightNumber===plan.flightNumber&&
  p.aircraftId==='owned:'+plan.aircraftInventoryId&&
  p.from?.key===plan.originAirportKey&&p.to?.key===plan.destinationAirportKey&&
  weeklyShape(p.schedule)!==null&&
  weeklyShape(p.schedule)===weeklyShape(plan.schedule));
 if(!saved||saved.estimatedDurationSource!=='five_phase_game_estimate'||
    !Number.isInteger(saved.estimatedDurationMinutes)||
    saved.estimatedDurationMinutes<25||saved.estimatedDurationMinutes>1440)return {};
 return Object.freeze({estimatedDurationMinutes:saved.estimatedDurationMinutes,
  estimatedDurationSource:'five_phase_game_estimate'});
}
export function planningClockEstimate(schedule,durationMinutes,turnaroundMinutes){
 if(!Number.isInteger(durationMinutes)||durationMinutes<25||durationMinutes>1440||
  !Number.isInteger(turnaroundMinutes)||turnaroundMinutes<45||
  turnaroundMinutes>360||weeklyShape(schedule)===null)return null;
 const rows=schedule.map(row=>{
  const start=minuteOfDay(row.time),arrival=start+durationMinutes;
  const ready=arrival+turnaroundMinutes;
  return Object.freeze({day:row.day,departureClock:row.time,
   arrivalClock:clock(arrival),arrivalDayOffset:Math.floor(arrival/1440),
   availableClock:clock(ready),availableDayOffset:Math.floor(ready/1440)});
 });
 return Object.freeze({durationMinutes,turnaroundMinutes,rows,
  sameDepartureTime:rows.every(x=>x.departureClock===rows[0].departureClock)});
}
