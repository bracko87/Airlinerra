import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';

const read=(path)=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('one MRO Licence 6; no subsidiary waiting period or second external-services licence',async()=>{
 const l=LICENCE_PLAN.filter(x=>x.code==='MAINTENANCE_ORGANIZATION_LICENCE_6');
 assert.equal(l.length,1);
 const spec=await read('docs/AIRLINERRA_LICENCE6_MRO_REQUIREMENTS_2026-11-20.md');
 assert.match(spec,/Minimum company age \| \*\*None\*\*/);
 assert.match(spec,/No 30-day subsidiary-age or holding-age waiting requirement/);
 assert.match(spec,/without buying any second external-service licence/);
 assert.match(spec,/as soon as.*meets those requirements/);
 const planner=JSON.stringify(l[0]);
 assert.match(planner,/NO minimum MRO company age/);
 assert.match(planner,/one company licence|One Licence 6/i);
 assert.doesNotMatch(planner,/at least 30 verified game days old/);
});

test('public offers are optional and each approved service can have its own player-set price',async()=>{
 const spec=await read('docs/AIRLINERRA_LICENCE6_MRO_REQUIREMENTS_2026-11-20.md');
 assert.match(spec,/Publish maintenance services.*off by default/i);
 assert.match(spec,/own price for each service/);
 assert.match(spec,/approved maintenance type, aircraft family\/model rating and service location/);
 assert.match(spec,/without losing Licence 6/);
 assert.match(spec,/must not be silently changed or cancelled/);
 const planner=JSON.stringify(LICENCE_PLAN.find(x=>x.code==='MAINTENANCE_ORGANIZATION_LICENCE_6'));
 assert.match(planner,/publication is OFF by default/);
 assert.match(planner,/separate player-defined price per service/);
});

test('MRO infrastructure and staff details remain explicitly deferred; no live issuance activated',async()=>{
 const spec=await read('docs/AIRLINERRA_LICENCE6_MRO_REQUIREMENTS_2026-11-20.md');
 assert.match(spec,/staff job titles, minimum numbers.*remain to be defined/i);
 assert.match(spec,/DESIGN SPECIFICATION ONLY/);
 const db=await read('supabase/migrations/20261120142500_licence6_mro_no_age_private_marketplace_policy.sql');
 assert.match(db,/enabled_in_game=false/);
 assert.match(db,/future optional public service listing/);
 assert.doesNotMatch(db,/CREATE TABLE|CREATE FUNCTION|issuance_enabled=true/i);
});
