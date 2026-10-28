import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {TERRITORY_COUNTRY,UN_COUNTRY_CODES,UN_COUNTRY_SET,GAME_COUNTRY_CODES,GAME_COUNTRY_SET,parentCountryIso,countrySqlExpression} from '../server/country-policy.mjs';
import {PLAYER_READ_SQL} from '../server/player-read-service.mjs';
const read=relative=>readFile(new URL(relative,import.meta.url),'utf8');
test('UN members and observers remain tracked, with owner-approved Kosovo exception',()=>{
 assert.equal(UN_COUNTRY_CODES.length,195);
 assert.equal(new Set(UN_COUNTRY_CODES).size,195);
 for(const code of ['RS','DK','GB','FI','FR','US','CN','MA','VA','PS'])
  assert.equal(UN_COUNTRY_SET.has(code),true);
 for(const code of ['FO','IM','GG','JE','XK','TW','HK','PR','EH','AX'])
  assert.equal(UN_COUNTRY_SET.has(code),false);
 assert.equal(parentCountryIso('FO'),'DK');
 assert.equal(parentCountryIso('AX'),'FI');
 assert.equal(parentCountryIso('IM'),'GB');
 assert.equal(parentCountryIso('GF'),'FR');
 assert.equal(parentCountryIso('PR'),'US');
 assert.equal(parentCountryIso('XK'),'XK');
 assert.equal(GAME_COUNTRY_CODES.length,196);
 assert.equal(GAME_COUNTRY_SET.has('XK'),true);
 assert.equal(UN_COUNTRY_SET.has('XK'),false);
 assert.equal(parentCountryIso('TW'),'CN');
 assert.equal(parentCountryIso('AB'),null);
 assert.equal(countrySqlExpression('country_iso').includes("when 'FO' then 'DK'"),true);
 assert.throws(()=>countrySqlExpression('country_iso; drop table nope'));
});
test('read API remaps territory airports and filters non-country codes before delivering choices',()=>{
 assert.match(PLAYER_READ_SQL.countries,/case country_iso/);
 assert.match(PLAYER_READ_SQL.airports,/case country_iso/);
 assert.match(PLAYER_READ_SQL.airports,/limit 51 offset \$3::integer/);
 assert.match(PLAYER_READ_SQL.airports,/country_iso\s*,?municipality/);
 for(const code of Object.keys(TERRITORY_COUNTRY))
  assert.equal(parentCountryIso(code),TERRITORY_COUNTRY[code]);
});
test('onboarding uses downward flags, protected full airport choices, logo upload and final summary',async()=>{
 const [html,css,js,menu,overlay,auth]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.css'),
  read('../website/player-app.mjs'),read('../website/setup-choice-menu.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs'),read('../website/invited-tester-auth.mjs')]);
 assert.match(html,/id="setup-country"/);
 assert.match(html,/id="setup-airport-results"/);
 assert.match(html,/id="setup-airline-logo"/);
 assert.match(html,/id="summary-airline-logo"/);
 assert.match(html,/id="summary-country"/);
 assert.match(html,/id="summary-airport"/);
 assert.match(html,/id="summary-world"/);
 assert.match(html,/id="summary-airline-name"/);
 assert.match(html,/id="setup-confirm-dialog"/);
 assert.doesNotMatch(html,/Development preview:|PRIVATE PRELAUNCH|What happens before creation/);
 assert.match(css,/\.down-menu-options\{position:relative/);
 assert.match(css,/\.down-menu-category/);
 assert.match(html,/id="airport-details-category"/);
 assert.match(html,/id="airport-passenger-demand"/);
 assert.match(html,/id="airport-cargo-demand"/);
 assert.match(js,/demandScale\('passenger',airport.passengerDemandPct\)/);
 assert.match(js,/demandScale\('cargo',airport.cargoDemandPct\)/);
 assert.match(menu,/option.dataset.category/);
 assert.match(menu,/flagcdn\.com\/w40/);
 assert.match(menu,/aria-expanded/);
 assert.match(js,/Intl\.Collator/);
 assert.match(js,/loadSetupAirports/);
 assert.match(js,/fillSetupCountries/);
 assert.match(js,/onboardingContext\?\.worlds/);
 assert.match(js,/loadRealOnboarding\(\)/);
 assert.match(js,/airports\.sort/);
 assert.match(js,/auth\.uploadAirlineLogo/);
 assert.match(auth,/airlinerra-airline-logos/);
 assert.match(overlay,/setup-choice-menu\.mjs/);
});
