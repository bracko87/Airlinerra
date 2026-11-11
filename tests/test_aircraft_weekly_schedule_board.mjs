import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {buildAirlineWeeklyBoard,renderAirlineWeeklyBoard,plannedRotationTiming,flightScheduleTooltip,WEEK_DAYS} from '../website/aircraft-weekly-schedule-board.mjs';
import {SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';

const A='a4547aef-e5a6-4362-8b2b-fbdf96d21907';
const B='b4547aef-e5a6-4362-8b2b-fbdf96d21907';
const fleet=[
 {id:A,registration:'YU-PAN01',manufacturer:'Airbus',model:'A319-100',
  ownershipType:'owned',fleetStatus:'in_service'},
 {id:B,registration:'YU-PAN02',manufacturer:'Airbus',model:'A320',
  ownershipType:'leased',fleetStatus:'grounded'},
 {id:'c4547aef-e5a6-4362-8b2b-fbdf96d21907',registration:'TEST-A319',
  ownershipType:'simulation',fleetStatus:'in_service'}
];
const scheduled=(overrides={})=>({
 aircraftInventoryId:A,flightNumber:'PA444',
 originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'FICTIONAL:fictional:RS:LYAL',
 referenceDepartureUtc:'2026-11-09T09:00:00Z',
 referenceArrivalUtc:'2026-11-09T10:30:00Z',
 weeklySchedule:[{day:0,time:'09:00'},{day:4,time:'12:15'}],
 status:'draft',slotsReserved:true,...overrides
});
const planned=(overrides={})=>({
 aircraftInventoryId:A,flightNumber:'PA445',
 from:{code:'LYBE'},to:{code:'LYAL'},schedule:[
  {day:1,time:'14:25'},{day:5,time:'18:00'}],
 status:'planning',operation:{turnaroundMinutes:45},...overrides
});
test('aircraft, not 24 separate hour rows, are the vertical dimension',()=>{
 const board=buildAirlineWeeklyBoard({fleet});
 assert.equal(board.status,'ready');
 assert.deepEqual(board.rows.map(r=>r.registration),['YU-PAN01','YU-PAN02']);
 assert.equal(board.rows[0].days.length,7);
 assert.deepEqual(WEEK_DAYS,['Mon','Tue','Wed','Thu','Fri','Sat','Sun']);
 assert.equal(board.counts.flights,0);
 assert.equal(board.counts.held,0);
});
test('owner planning routes show departure time and number without falsely booking aircraft time',()=>{
 const result=buildAirlineWeeklyBoard({fleet,plans:[planned({
  referenceDepartureUtc:'2026-11-09T09:00:00Z',
  referenceArrivalUtc:'2026-11-09T10:30:00Z'
 })]});
 const mon=result.rows[0].days[0],tue=result.rows[0].days[1];
 assert.equal(mon.events.length,0);
 assert.equal(tue.events[0].time,'14:25');
 assert.equal(tue.events[0].flightNumber,'PA445');
 assert.equal(tue.events[0].sampleDurationMinutes,90);
 assert.equal(tue.events[0].durationMinutes,null);
 assert.equal(tue.events[0].status,'airline-plan');
 assert.equal(tue.bands.length,1);
 assert.equal(tue.bands[0].kind,'planned-rotation');
 assert.equal(tue.bands[0].end-tue.bands[0].start,135,
  '90-minute estimated flying plus 45-minute turnaround takes 135 planning minutes');
 assert.equal(result.counts.held,0);
});
test('only schedules with independently verified slot reservations show an occupied flight window',()=>{
 const rows=buildAirlineWeeklyBoard({fleet,
  drafts:[scheduled(),scheduled({flightNumber:'PA446',slotsReserved:false,weeklySchedule:[{day:2,time:'10:00'}]})],
  plans:[planned(),planned({flightNumber:'PA444',schedule:[{day:0,time:'09:00'}]})],
  localRoutes:[{...planned({flightNumber:'PA444'}),aircraftId:'owned:'+A}]
 });
 const mon=rows.rows[0].days[0],wed=rows.rows[0].days[2],fri=rows.rows[0].days[4];
 assert.equal(mon.events.length,1,'server schedule wins over duplicate planning/local route');
 assert.equal(mon.events[0].status,'slot-held');
 assert.equal(mon.events[0].durationMinutes,90);
 assert.equal(mon.bands.length,1);
 assert.equal(mon.bands[0].start,540);
 assert.equal(mon.bands[0].end,630);
 assert.equal(mon.bands[0].kind,'slot-held');
 assert.equal(mon.bands[0].totalMinutes,null,
  'airport reservation alone does not certify any turnaround time');
 assert.equal(fri.bands[0].start,735);
 assert.equal(fri.bands[0].end,825);
 assert.equal(wed.events[0].status,'schedule-unverified');
 assert.equal(wed.bands.length,0);
 assert.equal(rows.counts.held,2);
});
test('cross-midnight slot-held flight time continues on next day, including Sunday into Monday',()=>{
 const result=buildAirlineWeeklyBoard({fleet,drafts:[
  scheduled({referenceDepartureUtc:'2026-11-08T23:30:00Z',
   referenceArrivalUtc:'2026-11-09T02:30:00Z',weeklySchedule:[{day:6,time:'23:30'}]})
 ]});
 const row=result.rows[0];
 assert.deepEqual(row.days[6].bands.map(b=>[b.start,b.end]),[[1410,1440]]);
 assert.deepEqual(row.days[0].bands.map(b=>[b.start,b.end,b.continues]),[[0,150,true]]);
 assert.equal(row.days[0].events.length,0);
});
test('overlaps are flagged but do not imply that a planning departure was reserved',()=>{
 const result=buildAirlineWeeklyBoard({fleet,drafts:[
  scheduled({weeklySchedule:[{day:0,time:'09:00'}]}),
  scheduled({flightNumber:'PA446',weeklySchedule:[{day:0,time:'10:00'}]})
 ],plans:[planned({flightNumber:'PA447',schedule:[{day:0,time:'09:00'}]})]});
 const monday=result.rows[0].days[0];
 assert.equal(monday.events.length,3);
 assert.ok(monday.warnings.some(w=>w.includes('Overlapping')));
 assert.ok(monday.warnings.some(w=>w.includes('Multiple departures')));
});
test('unverified API fleet and invalid time are not mistaken for empty availability',()=>{
 assert.equal(buildAirlineWeeklyBoard().status,'unavailable');
 assert.equal(buildAirlineWeeklyBoard({fleet:[]}).status,'empty');
 const result=buildAirlineWeeklyBoard({fleet,plans:[
  planned({schedule:[{day:0,time:'25:90'},{day:0,time:'09:00'}]})]});
 assert.equal(result.rows[0].days[0].events.length,1);
 assert.equal(result.rows[0].days[0].bands.length,0);
});
test('only selected weekday is rendered at full 24-hour width with aircraft rows',()=>{
 const createElement=tag=>({
  tagName:tag.toUpperCase(),children:[],style:{},attributes:{},textContent:'',
  append(...items){this.children.push(...items)},
  replaceChildren(...items){this.children=[...items]},
  setAttribute(key,value){this.attributes[key]=value}
 });
 const doc={createElement},host=createElement('main');
 const board=buildAirlineWeeklyBoard({fleet,plans:[planned({flightNumber:'PA444',
  schedule:[{day:0,time:'09:00'},{day:1,time:'16:30'}]})]});
 renderAirlineWeeklyBoard(doc,host,board,{day:0});
 const table=host.children[0].children[0];
 assert.match(table.className,/schedule-board-single-day/);
 const header=table.children[0].children[0].children;
 assert.equal(header.length,2,'one aircraft column and ONE selected day, never a week of columns');
 assert.equal(header[1].children[0].textContent,'Monday · 24 hours (UTC)');
 assert.deepEqual(header[1].children[1].children.map(x=>x.textContent),
  ['00:00','03:00','06:00','09:00','12:00','15:00','18:00','21:00','24:00']);
 const body=table.children[1];
 assert.equal(body.children.length,2,'each verified airline aircraft has one row');
 const mon=body.children[0].children[1];
 const lane=mon.children[0].children[0];
 assert.equal(lane.className,'schedule-board-track-lane');
 assert.equal(lane.children.some(x=>x.className==='schedule-board-held-band'),false);
 assert.equal(lane.children[0].className,'schedule-board-time-marker');
 assert.equal(lane.children[0].style.left,'37.5%','09:00 appears 9/24 across one full-day grid');
 assert.equal(lane.children[1].textContent,'PA444 · LYBE → LYAL');
 assert.match(lane.children[1].title,/Departure 09:00 UTC/);
 assert.equal(mon.children.some(x=>x.className==='schedule-board-flights'),false,
  'large flight details cards must no longer appear below timeline');
 renderAirlineWeeklyBoard(doc,host,board,{day:1});
 const tueTable=host.children[0].children[0];
 assert.match(tueTable.children[0].children[0].children[1].children[0].textContent,/Tuesday/);
 const tueLane=tueTable.children[1].children[0].children[1].children[0].children[0];
 assert.equal(tueLane.children[1].textContent,'PA444 · LYBE → LYAL');
 assert.match(tueLane.children[1].title,/Departure 16:30 UTC/);
});
test('verified flight booking bar is exactly proportional to actual duration, not fixed-size card',()=>{
 const createElement=tag=>({
  tagName:tag.toUpperCase(),children:[],style:{},textContent:'',
  append(...items){this.children.push(...items)},
  replaceChildren(...items){this.children=[...items]},
  setAttribute(){}
 });
 const doc={createElement},host=createElement('main');
 const board=buildAirlineWeeklyBoard({fleet,drafts:[scheduled({
  weeklySchedule:[{day:0,time:'09:00'}]
 })]});
 renderAirlineWeeklyBoard(doc,host,board,{day:0});
 const lane=host.children[0].children[0].children[1].children[0].children[1].children[0].children[0];
 const band=lane.children[0];
 assert.equal(band.className,'schedule-board-rotation-band is-slot-held');
 assert.equal(band.style.left,'37.5%');
 assert.equal(band.style.width,'6.25%','90 minutes must occupy exactly 90/1440 of daily timeline');
 assert.equal(lane.children[1].textContent,'PA444');
 assert.match(lane.children[1].title,/Flight 90 min/);
 assert.match(lane.children[1].title,/Turnaround unknown/);
});
test('schedule page loads owner fleet and planning/schedule records, not fabricated hour-by-hour local departures',async()=>{
 const root=new URL('../website/',import.meta.url);
 const [view,css,bundle,planner]=await Promise.all([
  readFile(new URL('airline-workspace.mjs',root),'utf8'),
  readFile(new URL('player-app.css',root),'utf8'),
  readFile(new URL('dev-scripts/invited-overlay.mjs',root),'utf8'),
  readFile(new URL('aircraft-weekly-schedule-board.mjs',root),'utf8')
 ]);
 assert.match(view,/id="schedule-aircraft-board"/);
 assert.match(view,/id="schedule-day-prev"/);
 assert.match(view,/id="schedule-day-next"/);
 assert.match(view,/renderAirlineWeeklyBoard\(doc,host,board,\{/);
 assert.match(view,/scheduleSelectedOffset=Math.max\(0,Math.min\(6/);
 assert.match(view,/AIRCRAFT × ONE DAY × 24 HOURS/);
 assert.doesNotMatch(view,/AIRCRAFT × 7 DAYS × 24 HOURS/);
 assert.match(view,/buildAirlineWeeklyBoard\(/);
 assert.match(view,/void loadAirlineSchedule\(\)/);
 assert.match(view,/fleet:marketSnapshot\?\.fleet,serverFleet:scheduleSnapshot\?\.fleet/);
 assert.match(view,/plans:scheduleSnapshot\?\.plans,drafts:scheduleSnapshot\?\.drafts/);
 assert.doesNotMatch(view,/id="schedule-hours"/);
 assert.doesNotMatch(view,/id="schedule-add"/);
 assert.match(css,/\.schedule-board-aircraft-col/);
 assert.match(css,/\.schedule-board-hour-labels/);
 assert.match(css,/\.schedule-board-held-band/);
 assert.match(bundle,/'aircraft-weekly-schedule-board\.mjs'/);
 assert.match(planner,/slotStatusLabel/);
 assert.match(SCHEDULE_SQL.drafts,/count\(\*\) = 2\*jsonb_array_length\(s.weekly_schedule\)/);
});

test('verified date label and estimated-only timeline are never presented as a booked slot',()=>{
 const createElement=tag=>({tagName:tag.toUpperCase(),style:{},children:[],attributes:{},
  append(...x){this.children.push(...x)},replaceChildren(...x){this.children=[...x]},
  setAttribute(k,v){this.attributes[k]=v}
 });
 const doc={createElement},host=createElement('main');
 const result=buildAirlineWeeklyBoard({fleet,localRoutes:[planned({
  flightNumber:'PA445',aircraftId:'owned:'+A,
  estimatedDurationMinutes:66,estimatedDurationSource:'five_phase_game_estimate',
  schedule:[{day:2,time:'09:00'}]
 })]});
 renderAirlineWeeklyBoard(doc,host,result,{day:2,dateLabel:'Wednesday, 11 Nov 2026'});
 const table=host.children[0].children[0];
 assert.equal(table.children[0].children[0].children[1].children[0].textContent,
  'Wednesday, 11 Nov 2026 · 24 hours (UTC)');
 const lane=table.children[1].children[0].children[1].children[0].children[0];
 const estimated=lane.children.find(x=>x.className==='schedule-board-rotation-band is-planning');
 assert.ok(estimated);
 assert.equal(estimated.style.width,111/1440*100+'%',
  '66 min estimated flight plus saved 45 min turnaround');
 assert.ok(!lane.children.some(x=>x.className?.includes('is-slot-held')));
 assert.ok(!lane.children.some(x=>x.className==='schedule-board-estimated-band'));
 const button=lane.children.find(x=>x.attributes?.['data-schedule-flight']==='PA445');
 assert.ok(button);
 assert.equal(button.textContent,'PA445 · LYBE → LYAL');
 assert.match(button.title,/Estimated available from 10:51 UTC/);
 assert.match(button.title,/Planning only; time not reserved/);
 assert.equal(result.counts.held,0);
});

test('existing server route gets a non-booked estimate only from exactly matching trusted aircraft and airports',()=>{
 const flight=scheduled({slotsReserved:false,weeklySchedule:[{day:2,time:'09:00'}],
  referenceDepartureUtc:null,referenceArrivalUtc:null});
 const estimate={flightNumber:'PA444',aircraftInventoryId:A,
  originAirportKey:'OURAIRPORTS:4610',destinationAirportKey:'FICTIONAL:fictional:RS:LYAL',
  minutes:66,source:'aircraft_five_phase_estimate'};
 const result=buildAirlineWeeklyBoard({fleet,drafts:[flight],
  estimatedDurations:[estimate]});
 assert.equal(result.rows[0].days[2].events[0].sampleDurationMinutes,66);
 assert.equal(result.rows[0].days[2].events[0].durationMinutes,null);
 assert.equal(result.counts.held,0);
 assert.equal(result.rows[0].days[2].bands[0].kind,'planned-rotation');
 for(const wrong of [
  {...estimate,aircraftInventoryId:B},{...estimate,minutes:0},
  {...estimate,source:'caller_override'},
  {...estimate,destinationAirportKey:'OURAIRPORTS:incorrect'}
 ]){
  const blocked=buildAirlineWeeklyBoard({fleet,drafts:[flight],
   estimatedDurations:[wrong]});
  assert.equal(blocked.rows[0].days[2].events[0].sampleDurationMinutes,null);
 }
});

test('rotation scale reserves no server time: 60-minute flight plus 45-minute turnaround previews 105 minutes',()=>{
 const computed=plannedRotationTiming(9*60,60,45);
 assert.deepEqual(computed,{
  flightMinutes:60,turnaroundMinutes:45,totalMinutes:105,
  arrivalMinute:600,availableMinute:645,
  arrivalDayOffset:0,availableDayOffset:0
 });
 const event={flightNumber:'PA444',fromCode:'LYBE',toCode:'LYAL',
  time:'09:00',minute:540,durationMinutes:null,sampleDurationMinutes:60,
  turnaroundMinutes:45,status:'airline-plan',timing:computed};
 const tooltip=flightScheduleTooltip(event);
 assert.match(tooltip,/PA444 · LYBE → LYAL/);
 assert.match(tooltip,/Departure 09:00 UTC/);
 assert.match(tooltip,/Estimated arrival 10:00 UTC/);
 assert.match(tooltip,/Flight 60 min/);
 assert.match(tooltip,/Turnaround 45 min/);
 assert.match(tooltip,/Total planning window 105 min/);
 assert.match(tooltip,/Estimated available from 10:45 UTC/);
 assert.match(tooltip,/Planning only; time not reserved/);
 const nextDay=plannedRotationTiming(23*60+30,60,45);
 assert.equal(nextDay.availableMinute,75);
 assert.equal(nextDay.availableDayOffset,1);
 assert.match(flightScheduleTooltip({...event,time:'23:30',minute:1410,timing:nextDay}),
  /Estimated available from 01:15 \(\+1 day\) UTC/);
});

test('schedule aircraft row includes nickname, without ownership/service clutter',()=>{
 const make=tag=>({tagName:tag.toUpperCase(),className:'',textContent:'',style:{},
  children:[],attributes:{},append(...items){this.children.push(...items)},
  replaceChildren(...items){this.children=[...items]},
  setAttribute(key,value){this.attributes[key]=value}});
 const doc={createElement:make},host=make('main');
 const board=buildAirlineWeeklyBoard({fleet:[{...fleet[0],nickname:'Belgrade Star'}]});
 renderAirlineWeeklyBoard(doc,host,board,{day:0});
 const label=host.children[0].children[0].children[1].children[0].children[0];
 const identity=label.children[0];
 assert.equal(identity.className,'schedule-board-aircraft-identity');
 assert.equal(identity.children[0].textContent,'YU-PAN01');
 assert.equal(identity.children[1].textContent,'Belgrade Star');
 assert.equal(label.children[1].textContent,'Airbus A319-100');
 assert.equal(label.children.length,2,'no owned/in_service status row');
});

test('known duration without turnaround never invents an available-from time',()=>{
 const board=buildAirlineWeeklyBoard({fleet,drafts:[scheduled({slotsReserved:false,
  referenceDepartureUtc:null,referenceArrivalUtc:null,
  weeklySchedule:[{day:2,time:'09:00'}]})],estimatedDurations:[{
  flightNumber:'PA444',aircraftInventoryId:A,
  originAirportKey:'OURAIRPORTS:4610',
  destinationAirportKey:'FICTIONAL:fictional:RS:LYAL',
  originAirportCode:'LYBE',destinationAirportCode:'LYAL',
  minutes:60,source:'aircraft_five_phase_estimate'
 }]});
 const event=board.rows[0].days[2].events[0];
 assert.equal(event.fromCode,'LYBE');
 assert.equal(event.toCode,'LYAL');
 assert.equal(event.timing.totalMinutes,null);
 assert.match(flightScheduleTooltip(event),/Estimated available from not verified/);
 assert.equal(board.rows[0].days[2].bands[0].kind,'planned-rotation');
 assert.equal(board.rows[0].days[2].bands[0].totalMinutes,null);
 assert.equal(board.counts.held,0);
});
