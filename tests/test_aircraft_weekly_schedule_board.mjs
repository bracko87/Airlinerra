import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
 buildAirlineWeeklyBoard,renderAirlineWeeklyBoard,plannedRotationTiming,
 flightScheduleTooltip,WEEK_DAYS
} from '../website/aircraft-weekly-schedule-board.mjs';
import {SCHEDULE_SQL} from '../server/flight-schedule-service.mjs';

const A='a4547aef-e5a6-4362-8b2b-fbdf96d21907';
const B='b4547aef-e5a6-4362-8b2b-fbdf96d21907';
const fleet=[
 {id:A,registration:'YU-PAN01',manufacturer:'Airbus',model:'A319-100',
  ownershipType:'owned',fleetStatus:'in_service',nickname:'Aleksandrovo'},
 {id:B,registration:'YU-PAN02',manufacturer:'Airbus',model:'A320',
  ownershipType:'leased',fleetStatus:'in_service'},
 {id:'c4547aef-e5a6-4362-8b2b-fbdf96d21907',
  registration:'TEST',ownershipType:'simulation',fleetStatus:'in_service'}
];
const booked=(overrides={})=>({
 aircraftInventoryId:A,flightNumber:'PA444',
 originAirportKey:'OURAIRPORTS:4610',
 destinationAirportKey:'FICTIONAL:fictional:RS:LYAL',
 originAirportCode:'LYBE',destinationAirportCode:'LYAL',
 referenceDepartureUtc:'2026-11-09T09:00:00Z',
 referenceArrivalUtc:'2026-11-09T10:30:00Z',
 weeklySchedule:[{day:0,time:'09:00'},{day:4,time:'12:15'}],
 status:'draft',slotsReserved:true,turnaroundMinutes:45,...overrides
});
const local=(overrides={})=>({
 aircraftInventoryId:A,flightNumber:'PA445',
 from:{code:'LYBE',key:'OURAIRPORTS:4610'},
 to:{code:'LYAL',key:'FICTIONAL:fictional:RS:LYAL'},
 schedule:[{day:0,time:'09:00'}],
 estimatedDurationMinutes:65,estimatedDurationSource:'five_phase_game_estimate',
 ...overrides
});
const element=tag=>({
 tagName:tag.toUpperCase(),className:'',textContent:'',children:[],
 style:{},attributes:{},
 append(...items){this.children.push(...items)},
 replaceChildren(...items){this.children=[...items]},
 setAttribute(key,value){this.attributes[key]=value}
});
const render=(board,day=0,dateLabel='Monday, 9 Nov 2026')=>{
 const host=element('main');renderAirlineWeeklyBoard({createElement:element},host,board,{day,dateLabel});
 return host;
};

test('timetable uses real owned/leased aircraft but nothing is booked by default',()=>{
 const board=buildAirlineWeeklyBoard({fleet});
 assert.equal(board.status,'ready');
 assert.deepEqual(board.rows.map(r=>r.registration),['YU-PAN01','YU-PAN02']);
 assert.equal(board.counts.flights,0);
 assert.equal(board.counts.held,0);
 assert.deepEqual(WEEK_DAYS,['Mon','Tue','Wed','Thu','Fri','Sat','Sun']);
 assert.match(render(board).children[0].textContent,/No booked flights/);
});
test('no local draft, planning route, duration estimate or unreserved schedule is visible',()=>{
 const board=buildAirlineWeeklyBoard({
  fleet,plans:[local()],localRoutes:[local()],
  drafts:[booked({slotsReserved:false})],
  estimatedDurations:[{flightNumber:'PA444',aircraftInventoryId:A,
   originAirportKey:'OURAIRPORTS:4610',
   destinationAirportKey:'FICTIONAL:fictional:RS:LYAL',
   minutes:70,source:'aircraft_five_phase_estimate'}]
 });
 assert.equal(board.rows[0].days[0].events.length,0);
 assert.equal(board.rows[0].days[0].bands.length,0);
 assert.equal(board.counts.flights,0);
 assert.equal(board.counts.held,0);
 assert.equal(render(board).children[0].className,'schedule-board-empty');
});
test('booked server schedule is the ONLY displayed flight, with one solid flight-time bar',()=>{
 const board=buildAirlineWeeklyBoard({
  fleet,drafts:[
   booked(),
   booked({flightNumber:'PA446',slotsReserved:false}),
   booked({flightNumber:'PA447',referenceDepartureUtc:null}),
   booked({flightNumber:'PA448',weeklySchedule:[]})
  ],
  plans:[local({flightNumber:'PA445'})],
  localRoutes:[local({flightNumber:'PA449'})]
 });
 assert.equal(board.counts.flights,2);
 assert.equal(board.counts.held,2);
 const mon=board.rows[0].days[0];
 assert.deepEqual(mon.events.map(x=>x.flightNumber),['PA444']);
 assert.equal(mon.events[0].status,'slot-held');
 assert.equal(mon.bands.length,1);
 assert.equal(mon.bands[0].kind,'slot-held');
 assert.equal(mon.bands[0].start,540);
 assert.equal(mon.bands[0].end,630);
 assert.equal(mon.bands[0].end-mon.bands[0].start,90,
  'Only the reserved flight duration is rendered; turnaround is not an extra booking');
 const host=render(board);
 const table=host.children[0].children[0];
 assert.equal(table.children[1].children.length,1,
  'Only aircraft with booked flights on the chosen date are visible');
 const lane=table.children[1].children[0].children[1].children[0].children[0];
 assert.equal(lane.children.length,2,'One single bar and a flight-number link; no other markers');
 assert.equal(lane.children[0].className,'schedule-board-rotation-band is-slot-held');
 assert.equal(lane.children[0].style.left,'37.5%');
 assert.equal(lane.children[0].style.width,'6.25%');
 assert.equal(lane.children[1].tagName,'BUTTON');
 assert.equal(lane.children[1].attributes['data-schedule-flight'],'PA444');
 assert.equal(lane.children[1].textContent,'PA444 · LYBE → LYAL');
 assert.ok(!lane.children.some(x=>x.className==='schedule-board-time-marker'));
 assert.ok(!lane.children.some(x=>x.className==='schedule-board-flight-segment'));
});
test('tooltip shows useful booking details without planning or reservation disclaimer',()=>{
 const event=buildAirlineWeeklyBoard({fleet,drafts:[booked()]})
  .rows[0].days[0].events[0];
 const tooltip=flightScheduleTooltip(event);
 assert.match(tooltip,/PA444 · LYBE → LYAL/);
 assert.match(tooltip,/Departure 09:00 UTC/);
 assert.match(tooltip,/Estimated arrival 10:30 UTC/);
 assert.match(tooltip,/Flight 90 min/);
 assert.match(tooltip,/Turnaround 45 min/);
 assert.match(tooltip,/Total flight \+ turnaround 135 min/);
 assert.match(tooltip,/Estimated available from 11:15 UTC/);
 assert.doesNotMatch(tooltip,/planning only|time not reserved|airport slots reserved|not activated/i);
});
test('cross-midnight booked flights continue the exact remaining flight window',()=>{
 const board=buildAirlineWeeklyBoard({fleet,drafts:[booked({
  weeklySchedule:[{day:6,time:'23:30'}],
  referenceDepartureUtc:'2026-11-08T23:30:00Z',
  referenceArrivalUtc:'2026-11-09T02:30:00Z'
 })]});
 assert.deepEqual(board.rows[0].days[6].bands.map(x=>[x.start,x.end]),[[1410,1440]]);
 assert.deepEqual(board.rows[0].days[0].bands.map(x=>[x.start,x.end]),[[0,150]]);
 assert.equal(board.rows[0].days[0].bands[0].continues,true);
 assert.equal(board.rows[0].days[0].events.length,0);
});
test('invalid or unavailable fleet never creates a fake booking',()=>{
 assert.equal(buildAirlineWeeklyBoard().status,'unavailable');
 assert.equal(buildAirlineWeeklyBoard({fleet:[]}).status,'empty');
 const bad=buildAirlineWeeklyBoard({fleet,drafts:[booked({
  weeklySchedule:[{day:0,time:'25:90'}]
 })]});
 assert.equal(bad.counts.flights,0);
 assert.match(render(bad).children[0].textContent,/No booked flights/);
});
test('only the selected calendar day appears; other days have no hidden draft markers',()=>{
 const board=buildAirlineWeeklyBoard({fleet,drafts:[booked()]});
 const host=render(board,4,'Friday, 13 Nov 2026');
 const table=host.children[0].children[0];
 const dayHead=table.children[0].children[0].children[1];
 assert.equal(dayHead.children[0].textContent,'Friday, 13 Nov 2026 · 24 hours (UTC)');
 assert.deepEqual(dayHead.children[1].children.map(x=>x.textContent),
 ['00:00','03:00','06:00','09:00','12:00','15:00','18:00','21:00','24:00']);
 const lane=table.children[1].children[0].children[1].children[0].children[0];
 assert.equal(lane.children[1].textContent,'PA444 · LYBE → LYAL');
 assert.equal(lane.children[0].style.left,100*735/1440+'%');
});
test('no booked flight on a different day, even if the aircraft has a booking elsewhere',()=>{
 const board=buildAirlineWeeklyBoard({fleet,drafts:[booked({
  weeklySchedule:[{day:0,time:'09:00'}]
 })]});
 assert.match(render(board,2,'Wednesday, 11 Nov 2026').children[0].textContent,
 /No booked flights/);
});
test('plannedRotationTiming keeps correct arrival and available-from maths',()=>{
 assert.deepEqual(plannedRotationTiming(540,90,45),{
  flightMinutes:90,turnaroundMinutes:45,totalMinutes:135,
  arrivalMinute:630,availableMinute:675,
  arrivalDayOffset:0,availableDayOffset:0
 });
});
test('schedule page reads only server drafts and omits all planning legends',async()=>{
 const root=new URL('../website/',import.meta.url);
 const [view,css,bundle,boardSource]=await Promise.all([
  readFile(new URL('airline-workspace.mjs',root),'utf8'),
  readFile(new URL('player-app.css',root),'utf8'),
  readFile(new URL('dev-scripts/invited-overlay.mjs',root),'utf8'),
  readFile(new URL('aircraft-weekly-schedule-board.mjs',root),'utf8')
 ]);
 assert.match(view,/id="schedule-aircraft-board"/);
 assert.match(view,/id="schedule-day-prev"/);
 assert.match(view,/id="schedule-day-next"/);
 assert.match(view,/Booked flights only/);
 assert.match(view,/drafts:scheduleSnapshot\?\.drafts/);
 assert.doesNotMatch(view,/plans:scheduleSnapshot\?\.plans|localRoutes:local/);
 assert.doesNotMatch(view,/schedule-board-legend|Departure only:|planning, not reserved|verified airport-slot flight windows/i);
 assert.doesNotMatch(view,/refreshScheduleEstimates/);
 assert.match(boardSource,/slotsReserved!==true/);
 assert.doesNotMatch(boardSource,/Planning only; time not reserved/);
 assert.doesNotMatch(boardSource,/kind:'planned-rotation'/);
 assert.match(css,/\.schedule-board-rotation-band\.is-slot-held/);
 assert.match(bundle,/'aircraft-weekly-schedule-board\.mjs'/);
 assert.match(SCHEDULE_SQL.drafts,/count\(\*\) = 2\*jsonb_array_length\(s.weekly_schedule\)/);
});
