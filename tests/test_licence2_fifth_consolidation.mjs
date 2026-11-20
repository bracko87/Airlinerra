import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {LICENCE_PLAN} from '../website/licensing-planner.mjs';

const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');

test('Only Licence 2 is offered for foreign network and Fifth Freedom game coverage',async()=>{
 const codes=LICENCE_PLAN.map(x=>x.code);
 assert.ok(codes.includes('FOREIGN_NETWORK_LICENCE_2'));
 assert.ok(!codes.includes('FIFTH_FREEDOM'));
 const l2=LICENCE_PLAN.find(x=>x.code==='FOREIGN_NETWORK_LICENCE_2');
 assert.match(JSON.stringify(l2),/Fifth Freedom/);
 assert.match(JSON.stringify(l2),/no separate Licence 6/i);
 assert.match(JSON.stringify(l2),/traffic rights/i);
});
test('No standalone Licence 6 button, price or API endpoint survives',async()=>{
 const ui=await read('website/game-permission-applications-view.mjs');
 const api=await read('server/section9-permission-player-http.mjs');
 const client=await read('website/game-permission-applications-client.mjs');
 assert.match(ui,/Licence 2 — Foreign network expansion/);
 assert.match(ui,/there is no separate Licence 6 application or fee/);
 assert.doesNotMatch(ui,/game-licence-l6|Apply for Licence 6|licence6FifthFreedomPreview/);
 assert.doesNotMatch(api,/licence6_preview|licence6_submit|licence6_submit_fifth_application_v1/);
 assert.doesNotMatch(client,/licence6_preview|licence6_submit|licence6FifthFreedomPreview/);
 assert.doesNotMatch(api,/'FIFTH_FREEDOM'/);
});
test('Legacy Licence 6 application, reviewer and fee structures are retired under zero-data guard',async()=>{
 const src=await read('supabase/migrations/20261120140000_merge_fifth_freedom_into_licence2.sql');
 const retired=await read('supabase/migrations/20261120140500_retire_standalone_licence6_structures.sql');
 assert.match(src,/cron\.unschedule\('airlinerra-licence6-fifth-review-v1'\)/);
 assert.match(src,/game_fee_usd=NULL,processing_game_days=NULL/);
 assert.match(src,/WHERE permission_code='FIFTH_FREEDOM' AND enabled_in_game=false/);
 assert.match(retired,/CANNOT_RETIRE_LICENCE6_WITH_PLAYER_OR_MARKET_RECORDS/);
 assert.match(retired,/DROP FUNCTION IF EXISTS airlinerra_game\.licence6_submit_fifth_application_v1/);
 assert.match(retired,/DROP TABLE airlinerra_game\.licence6_fifth_applications_v1/);
 assert.match(retired,/DROP TABLE airlinerra_game\.licence6_fifth_approvals_v1/);
});
test('The replacement Licence 2 classifier checks three-country home connection and existing L2 market',async()=>{
 const src=await read('supabase/migrations/20261120140000_merge_fifth_freedom_into_licence2.sql');
 const enhancement=await read('supabase/migrations/20261120141000_l2_home_connected_route_no_extra_base.sql');
 assert.match(src,/licence2_home_connected_foreign_segment_v1/);
 assert.match(src,/licence2_foreign_route_preview_v1/);
 assert.match(src,/operator_country<>home_country/);
 assert.match(src,/stop_country=destination_country/);
 assert.match(src,/aviation_route_rights_preview_v1/);
 assert.match(src,/'canActivateFlights',false/);
 assert.match(src,/'ticketsAuthorized',false/);
 assert.match(src,/'cargoSalesAuthorized',false/);
 assert.match(enhancement,/L2_ACTIVE_FOREIGN_HUB_NOT_VERIFIED/);
 assert.match(enhancement,/requiresSameHomeConnectedServiceProof/);
});
