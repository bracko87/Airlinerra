import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {buildAirlineWeeklyBoard,renderAirlineWeeklyBoard,WEEK_DAYS} from '../website/aircraft-weekly-schedule-board.mjs';
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
 assert.deepEqual(tue.bands,[]);
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
 assert.deepEqual(mon.bands,[{
  start:540,end:630,flightNumber:'PA444',kind:'slot-held',sourceDay:0,continues:false
 }]);
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
 assert.match(lane.children[1].textContent,/PA444 · 09:00/);
 assert.equal(mon.children.some(x=>x.className==='schedule-board-flights'),false,
  'large flight details cards must no longer appear below timeline');
 renderAirlineWeeklyBoard(doc,host,board,{day:1});
 const tueTable=host.children[0].children[0];
 assert.match(tueTable.children[0].children[0].children[1].children[0].textContent,/Tuesday/);
 const tueLane=tueTable.children[1].children[0].children[1].children[0].children[0];
 assert.match(tueLane.children[1].textContent,/PA444 · 16:30/);
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
 assert.equal(band.className,'schedule-board-held-band');
 assert.equal(band.style.left,'37.5%');
 assert.equal(band.style.width,'6.25%','90 minutes must occupy exactly 90/1440 of daily timeline');
 assert.match(lane.children[1].textContent,/PA444 · 09:00 · 90 min/);
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
 assert.match(view,/renderAirlineWeeklyBoard\(doc,host,board,\{day:scheduleSelectedDay\}\)/);
 assert.match(view,/scheduleSelectedDay=\(scheduleSelectedDay\+/);
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
