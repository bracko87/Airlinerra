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
 assert.match(txt,/no extra public-training licence/);
 assert.match(txt,/7 verified game days/);
 assert.match(txt,/40,000/);
});
test('academy publication is optional and pricing is set for each programme',async()=>{
 const txt=JSON.stringify(LICENCE_PLAN.find(v=>v.code==='FLIGHT_ACADEMY'));
 assert.match(txt,/OFF by default/);
 assert.match(txt,/price per programme/);
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

test('Academy must own one eligible operational small training aircraft at Licence 7 approval',async()=>{
 const entry=JSON.stringify(LICENCE_PLAN.find(v=>v.code==='FLIGHT_ACADEMY'));
 const doc=await read('docs/AIRLINERRA_LICENCE7_FLIGHT_ACADEMY_REQUIREMENTS_2026-11-20.md');
 assert.match(entry,/At least ONE purchased and operational eligible small training aircraft/);
 assert.match(entry,/10–20 small training-aircraft models/);
 assert.match(doc,/Mandatory Licence 7 approval prerequisite/);
 assert.match(doc,/simulator alone or an ordinary passenger airline aircraft alone/i);
 assert.match(doc,/10–20 small dedicated training aircraft models/);
});
test('Optional holding airline aircraft use must reserve canonical aircraft calendar and bar flight conflicts',async()=>{
 const entry=JSON.stringify(LICENCE_PLAN.find(v=>v.code==='FLIGHT_ACADEMY'));
 const doc=await read('docs/AIRLINERRA_LICENCE7_FLIGHT_ACADEMY_REQUIREMENTS_2026-11-20.md');
 assert.match(entry,/ATR 72/);
 assert.match(entry,/SAME aircraft calendar/);
 assert.match(doc,/Atomic exclusivity/);
 assert.match(doc,/no commercial flight, maintenance job, transfer or other training reservation overlaps/);
 assert.match(doc,/does not allow reserving other users' aircraft without consent/);
});
test('Academy organisation and individual pilot qualification lifecycle are separate',async()=>{
 const entry=JSON.stringify(LICENCE_PLAN.find(v=>v.code==='FLIGHT_ACADEMY'));
 const doc=await read('docs/AIRLINERRA_LICENCE7_FLIGHT_ACADEMY_REQUIREMENTS_2026-11-20.md');
 assert.match(entry,/inspection\/revalidation every 365 verified game days/);
 assert.match(entry,/Pilot qualifications are separately renewed/);
 assert.match(doc,/company's Licence 7.*individual pilot's qualifications/);
 assert.match(doc,/not automatically erase\\*\\* already issued pilots/);
 assert.match(doc,/Temporary suspension/);
 assert.match(doc,/Revocation/);
});
