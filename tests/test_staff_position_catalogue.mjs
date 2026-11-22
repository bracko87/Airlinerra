import test from 'node:test';
import assert from 'node:assert/strict';
import {STAFF_SECTIONS,STAFF_POSITION_GROUPS,staffCatalogueMarkup,previewStaffSalary,salaryManagementMarkup,AIRLINE_UI_VIEWS} from '../website/airline-workspace.mjs';
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

test('salary preview validates inputs and supports increases and reductions',()=>{
 assert.equal(previewStaffSalary(2200,5),2310);
 assert.equal(previewStaffSalary(2200,-10),1980);
 assert.equal(previewStaffSalary(2200,0),2200);
 assert.equal(previewStaffSalary('',5),null);
 assert.equal(previewStaffSalary(100,-101),null);
 assert.equal(previewStaffSalary(100,1001),null);
 assert.equal(previewStaffSalary(-1,5),null);
});
test('salary management is a separate view with one planning row per position',()=>{
 assert.ok(AIRLINE_UI_VIEWS.includes('salary-management'));
 const html=salaryManagementMarkup();
 assert.equal((html.match(/data-salary-row="/g)||[]).length,STAFF_POSITION_GROUPS.flatMap(g=>g.positions).length);
 assert.match(html,/id="salary-scope"/);
 assert.match(html,/id="salary-category"/);
 assert.match(html,/id="salary-apply-preview"/);
 assert.match(html,/preview only/);
 assert.match(html,/data-salary-row="captain"/);
 assert.match(html,/data-salary-row="flight_attendant"/);
 assert.doesNotMatch(html,/Save salaries|Confirm payroll/);
});
