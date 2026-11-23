import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
test('confirmed calendar SQL carries schedule identity and all union rows remain aligned',async()=>{
 const server=await read('../server/flight-schedule-service.mjs');
 const start=server.indexOf(' aircraftCalendar:`WITH owner AS (');
 const end=server.indexOf(' routeForecast:`',start);
 assert.ok(start>=0&&end>start);
 const sql=server.slice(start,end);
 assert.match(sql,/o\.schedule_id::text AS "scheduleId"/);
 assert.match(sql,/s\.version=o\.schedule_version AND s\.status='active' AND s\.operationally_verified/);
 assert.match(sql,/a\.owner_player_id=\$2::uuid/);
 assert.equal((sql.match(/UNION ALL/g)||[]).length,3);
 assert.match(sql,/j\.quoted_cost_usd,NULL::text/);
 assert.match(sql,/\(r\.quote->l\.leg->>'totalUsd'\)::numeric,NULL::text/);
 assert.match(sql,/\(r\.quote#>>'\{maintenance,priceUsd\}'\)::numeric,NULL::text/);
});
test('calendar links send confirmed schedule ID, not only the flight number',async()=>{
 const calendar=await read('../website/aircraft-dated-calendar.mjs');
 const workspace=await read('../website/airline-workspace.mjs');
 const routes=await read('../website/airline-operations-center.mjs');
 assert.match(calendar,/label\.dataset\.scheduleId=b\.scheduleId/);
 assert.match(workspace,/scheduledFlight\.getAttribute\('data-schedule-id'\)/);
 assert.match(workspace,/detail:\{flightNumber,\.\.\.\(scheduleId\?\{scheduleId\}:\{\}\)\}/);
 assert.match(routes,/x\.serverScheduleId===scheduleId/);
 assert.match(routes,/has no matching registered route/);
 assert.match(routes,/Refresh My Routes before retrying/);
});
