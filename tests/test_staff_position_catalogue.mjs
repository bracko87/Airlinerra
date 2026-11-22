import test from 'node:test';
import assert from 'node:assert/strict';
import {STAFF_SECTIONS,STAFF_POSITION_GROUPS,staffCatalogueMarkup} from '../website/airline-workspace.mjs';
test('staff structure has exactly three sections and separates holding from airline management',()=>{
 assert.deepEqual(STAFF_SECTIONS.map(s=>s.id),['management','pilots','other']);
 assert.deepEqual(STAFF_SECTIONS[0].groups,['holding','airline']);
 assert.equal(STAFF_POSITION_GROUPS.find(g=>g.id==='holding').positions.length,8);
 assert.equal(STAFF_POSITION_GROUPS.find(g=>g.id==='airline').positions.length,5);
 assert.equal(STAFF_POSITION_GROUPS.find(g=>g.id==='pilots').positions.length,7);
 assert.equal(STAFF_SECTIONS[2].groups.length,10);
 const ids=STAFF_POSITION_GROUPS.flatMap(g=>g.positions.map(p=>p.id));
 assert.equal(ids.length,new Set(ids).size);
 assert.ok(ids.includes('flight_attendant')&&ids.includes('ramp_agent')&&ids.includes('station_manager'));
});
test('initial staff markup has three section selectors, a holding scope and no hiring action',()=>{
 const html=staffCatalogueMarkup();
 assert.equal((html.match(/data-staff-section="/g)||[]).length,3);
 assert.equal((html.match(/data-staff-section-panel="/g)||[]).length,3);
 assert.match(html,/aria-controls="staff-section-management"/);
 assert.match(html,/Holding level only/);
 assert.match(html,/Original airline and each airline subsidiary/);
 assert.match(html,/career progression/);
 assert.doesNotMatch(html,/data-hire|Hire now|Confirm salary/);
});
