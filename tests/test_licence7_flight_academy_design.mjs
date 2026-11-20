import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';
const read=p=>readFile(new URL('../'+p,import.meta.url),'utf8');
test('Licence 7 is one academy company licence for internal and third-party training',async()=>{
 const entry=LICENCE_PLAN.find(v=>v.code==='FLIGHT_ACADEMY');
 assert.ok(entry);
 const txt=JSON.stringify(entry);
 assert.match(txt,/Licence 7/);
 assert.match(txt,/NO minimum academy-company age/);
 assert.match(txt,/external player-airline trainees/);
 assert.match(txt,/No additional licence/);
 assert.match(txt,/7 verified game days/);
 assert.match(txt,/40,000/);
});
test('academy publication is optional and pricing is set for each programme',async()=>{
 const txt=JSON.stringify(LICENCE_PLAN.find(v=>v.code==='FLIGHT_ACADEMY'));
 assert.match(txt,/OFF by default/);
 assert.match(txt,/own price for each programme/);
 const doc=await read('docs/AIRLINERRA_LICENCE7_FLIGHT_ACADEMY_REQUIREMENTS_2026-11-20.md');
 assert.match(doc,/no academy age waiting period/i);
 assert.match(doc,/price \*\*per programme\/course\*\*/);
 assert.match(doc,/private\/unlisted by default/);
 assert.match(doc,/40,000/);
});
test('academy infrastructure remains deferred and not represented as live or registered',async()=>{
 const doc=await read('docs/AIRLINERRA_LICENCE7_FLIGHT_ACADEMY_REQUIREMENTS_2026-11-20.md');
 assert.match(doc,/does not yet support|does not include flight_academy/i);
 assert.match(doc,/not live/i);
 assert.match(doc,/future prerequisites/i);
});
