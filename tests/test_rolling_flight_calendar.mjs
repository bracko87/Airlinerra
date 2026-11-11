import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {berlinSevenDayWindow} from '../website/rolling-flight-calendar.mjs';
import {routePlannerMarkup} from '../website/route-planner.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
test('Berlin timetable starts today and shows exactly one seven-day window',()=>{
 const days=berlinSevenDayWindow(Date.parse('2026-11-11T08:28:30Z'));
 assert.equal(days.length,7);
 assert.equal(days[0].iso,'2026-11-11');
 assert.equal(days[0].label,'Wednesday, 11 Nov 2026');
 assert.equal(days[0].weekday,2);
 assert.equal(days[0].isToday,true);
 assert.equal(days[6].iso,'2026-11-17');
 assert.equal(days[6].label,'Tuesday, 17 Nov 2026');
 assert.equal(days[6].isToday,false);
 assert.deepEqual(days.map(x=>x.weekday),[2,3,4,5,6,0,1]);
});
test('Berlin dates always use actual local day, including DST midnight',()=>{
 const spring=berlinSevenDayWindow(Date.parse('2026-03-28T23:30:00Z'));
 assert.equal(spring[0].iso,'2026-03-29');
 assert.equal(spring[1].iso,'2026-03-30');
 const autumn=berlinSevenDayWindow(Date.parse('2026-10-25T00:45:00Z'));
 assert.equal(autumn[0].iso,'2026-10-25');
 const after=berlinSevenDayWindow(Date.parse('2026-10-25T23:15:00Z'));
 assert.equal(after[0].iso,'2026-10-26');
 assert.deepEqual(berlinSevenDayWindow(NaN),[]);
});
test('schedule uses server Berlin date, bounds navigation and links to route details',async()=>{
 const [workspace,board,operations,overlay]=await Promise.all([
  read('website/airline-workspace.mjs'),
  read('website/aircraft-weekly-schedule-board.mjs'),
  read('website/airline-operations-center.mjs'),
  read('website/dev-scripts/invited-overlay.mjs')
 ]);
 assert.match(workspace,/verifyWorldTimeResponse\(await response\.json\(\)\)/);
 assert.match(workspace,/berlinSevenDayWindow\(epoch\)/);
 assert.match(workspace,/scheduleSelectedOffset=Math\.max\(0,Math\.min\(6/);
 assert.match(workspace,/scheduleSelectedOffset=0/);
 assert.match(workspace,/dateLabel:selectedDate\.label/);
 assert.match(board,/data-schedule-flight/);
 assert.match(board,/schedule-board-estimated-band/);
 assert.match(operations,/airlinerra:schedule-open-flight/);
 assert.match(operations,/goTo\?\.\('route-details'\)/);
 assert.match(overlay,/'rolling-flight-calendar\.mjs'/);
});
test('route map shows general, origin and destination data before Step 2',async()=>{
 const markup=routePlannerMarkup();
 const general=markup.indexOf('route-general-summary');
 const destination=markup.indexOf('Destination airport</h4>');
 const origin=markup.indexOf('Origin airport</h4>');
 const step2=markup.indexOf('Aircraft and weekly departures');
 const performance=markup.indexOf('Aircraft performance and fuel estimate');
 const step3=markup.indexOf('Ticket prices and onboard services');
 assert.ok(general>=0&&origin>general&&destination>origin);
 assert.ok(step2>destination&&performance>step2&&step3>performance);
 assert.ok(markup.indexOf('id="route-aircraft-check"')>performance);
 assert.ok(markup.indexOf('id="route-fuel-phases"')>performance);
 assert.ok(markup.indexOf('id="route-fuel-summary"')>performance);
 assert.ok(markup.includes('id="route-origin-demand"'));
 assert.ok(markup.includes('id="route-destination-demand"'));
 assert.ok(markup.includes('route-hidden-readouts" hidden'));
 assert.match(markup,/Nine freedoms of the air/);
 assert.match(markup,/nine international aviation rights/i);
 assert.doesNotMatch(markup,/Weather forecast \(example times\)|Departure \/ arrival slots<\/span>|<span>Route status<\/span>/);
 const [src,css]=await Promise.all([
  read('website/route-planner.mjs'),read('website/player-app.css')
 ]);
 assert.match(src,/route-demand-bar/);
 assert.match(src,/route-airport-rule/);
 assert.match(src,/estimatedDurationSource:'five_phase_game_estimate'/);
 assert.match(css,/route-demand-bar\.is-filled/);
 assert.match(css,/route-right-icon.is-approved/);
 assert.match(src,/Full estimated operating cost: Not available/);
});
