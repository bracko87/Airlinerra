import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validatedActivationRequest,AIRLINE_ACTIVATION_SQL} from '../server/airline-activation.mjs';
import {parseOnboardingBody} from '../server/airline-http-handler.mjs';
const read=(p)=>readFile(new URL(p,import.meta.url),'utf8');

test('standard spacing uses the same card gutter between all dashboard rows',async()=>{
 const css=await read('../website/player-app.css');
 assert.match(css,/--manager-card-gap:20px/);
 assert.match(css,/#player-main \[data-player-view\] > \.kpi-grid/);
 assert.match(css,/#player-main \[data-player-view\] > \.two-cols/);
 assert.match(css,/#player-main \[data-player-view\] > \[id\^="workspace-"\]/);
 assert.match(css,/margin-bottom:var\(--manager-card-gap\)/);
 assert.match(css,/@media\(max-width:760px\)\{:root\{--manager-card-gap:16px\}/);
});

test('real airline logo is on the right; verified live disclaimer and setup actions are removed for existing airlines',async()=>{
 const [html,js]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs')
 ]);
 assert.match(html,/class="airline-identity-text"/);
 assert.match(html,/class="airline-identity-brand"><img id="player-existing-logo"/);
 assert.doesNotMatch(html,/>MANAGER CONSOLE</);
 assert.doesNotMatch(html,/Your home for airline operations once the first world opens/);
 assert.match(html,/data-view-link="onboarding" data-setup-only hidden/);
 assert.match(html,/data-go-view="onboarding" data-setup-only hidden/);
 assert.match(js,/element\.hidden=hasAirline/);
 assert.match(js,/selected==='onboarding'&&hasRealAirline\?'overview':selected/);
 assert.match(js,/name!==selected\)window\.history\.replaceState/);
 assert.match(js,/doc\.getElementById\('local-preview-note'\)\.hidden=true/);
 assert.match(js,/hasAirline\?'':'Awaiting onboarding'/);
 assert.match(js,/hasRealAirline=Boolean\(first\?\.name\)/);
});

test('ICAO is 3 letters; IATA is 2 alphanumeric with at least one letter',()=>{
 const source={worldId:1,airlineName:'New Example Air',homeAirportKey:'OURAIRPORTS:101',icaoCode:' exa ',iataCode:' e7 '};
 const valid=validatedActivationRequest(source);
 assert.equal(valid.icaoCode,'EXA');
 assert.equal(valid.iataCode,'E7');
 assert.deepEqual(parseOnboardingBody(JSON.stringify(source)),source);
 for(const invalid of [
  {...source,icaoCode:'EA'},
  {...source,icaoCode:'E7A'},
  {...source,iataCode:'77'},
  {...source,iataCode:'X'},
  {...source,iataCode:'x?a'},
  {...source,icaoCode:null},
  {...source,icaoCode:123},
  {...source,iataCode:2},
 ])assert.throws(()=>validatedActivationRequest(invalid));
 assert.throws(()=>parseOnboardingBody(JSON.stringify({...source,playerId:'attacker'})));
 assert.match(AIRLINE_ACTIVATION_SQL,/create_airline_with_codes/);
 assert.match(AIRLINE_ACTIVATION_SQL,/\$5::text,\$6::text/);
});

test('UI shows only actual code status and submits code-verified creation',async()=>{
 const [html,script,client,workspace,readService]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs'),
  read('../website/real-onboarding-client.mjs'),read('../website/airline-workspace.mjs'),
  read('../server/player-read-service.mjs')
 ]);
 for(const id of ['setup-airline-icao','setup-airline-iata',
  'summary-airline-icao','summary-airline-iata'])assert.match(html,new RegExp('id="'+id+'"'));
 assert.match(script,/const icaoCode=doc\.getElementById\('setup-airline-icao'\)/);
 assert.match(script,/const iataCode=doc\.getElementById\('setup-airline-iata'\)/);
 assert.match(script,/createAirline\(\{worldId,homeAirportKey:home,airlineName,icaoCode,iataCode\}\)/);
 assert.match(client,/post\('\/api\/v1\/airlines',\{worldId,airlineName,homeAirportKey,icaoCode,iataCode\}\)/);
 assert.match(readService,/icaoCode:typeof row\.icao_code/);
 assert.match(readService,/iataCode:typeof row\.iata_code/);
 assert.match(workspace,/office-icao/);
 assert.match(workspace,/office-iata/);
 assert.match(workspace,/Not assigned/);
});

test('new codes are unique in each world and old airline remains unchanged until owner assigns codes',async()=>{
 const sql=await read('../supabase/migrations/20261029110000_airlinerra_airline_identity_codes.sql');
 assert.match(sql,/ADD COLUMN IF NOT EXISTS icao_code text/);
 assert.match(sql,/ADD COLUMN IF NOT EXISTS iata_code text/);
 assert.match(sql,/CREATE UNIQUE INDEX IF NOT EXISTS airlinerra_icao_by_world/);
 assert.match(sql,/CREATE UNIQUE INDEX IF NOT EXISTS airlinerra_iata_by_world/);
 assert.match(sql,/where icao_code IS NOT NULL/i);
 assert.match(sql,/where iata_code IS NOT NULL/i);
 assert.match(sql,/NEWLY_CREATED|newly_created/);
 assert.match(sql,/Existing airline identity cannot be changed by registration/);
 assert.match(sql,/REVOKE ALL ON FUNCTION airlinerra_game\.create_airline_with_codes/);
 assert.doesNotMatch(sql,/UPDATE\s+airlinerra_game\.airlines\s+SET[^;]*WHERE\s+icao_code\s+IS\s+NULL/i);
});
