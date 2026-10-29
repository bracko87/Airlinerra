import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {formatWholeUsd} from '../website/player-app-model.mjs';
const read=path=>readFile(new URL(path,import.meta.url),'utf8');

test('dashboard displays whole dollars with commas and no decimals',()=>{
 assert.equal(formatWholeUsd('5000000.00'),'$5,000,000');
 assert.equal(formatWholeUsd(5000000),'$5,000,000');
 assert.equal(formatWholeUsd('5000000.75'),'$5,000,001');
 assert.equal(formatWholeUsd('0'),'$0');
 assert.equal(formatWholeUsd('bad'),'-');
 assert.equal(formatWholeUsd(-1),'-');
});

test('successful signup uses green confirmation and failures use red feedback',async()=>{
 const [html,script,css]=await Promise.all([
  read('../website/register.html'),read('../website/real-registration.mjs'),
  read('../website/register.css')
 ]);
 assert.match(html,/id="registration-feedback" role="status" aria-live="polite"/);
 assert.match(script,/function registrationFeedback\(kind,message\)/);
 assert.match(script,/feedback\.dataset\.status=kind/);
 assert.match(script,/registrationFeedback\('success','Registration request accepted/);
 assert.match(script,/Please check your email for the Airlinerra confirmation link/);
 assert.match(script,/registrationFeedback\('error','Registration failed/);
 assert.match(script,/registrationErrorMessage\(error\)/);
 assert.match(script,/if\(error\)throw error/);
 assert.match(css,/#registration-feedback\[data-status="success"\]/);
 assert.match(css,/#registration-feedback\[data-status="error"\]/);
 assert.match(css,/color:#17663d/);
 assert.match(css,/color:#a12626/);
});

test('country flag picker lets users search by typed name without selecting a wrong country',async()=>{
 const [script,css]=await Promise.all([
  read('../website/setup-choice-menu.mjs'),read('../website/player-app.css')
 ]);
 assert.match(script,/if\(flags\)\{/);
 assert.match(script,/search\.type='search'/);
 assert.match(script,/search\.placeholder='Type a country name\.\.\.'/);
 assert.match(script,/search\.addEventListener\('input',filter\)/);
 assert.match(script,/\.normalize\('NFD'\)/);
 assert.match(script,/option\.dataset\.search/);
 assert.match(script,/option\.hidden=!match/);
 assert.match(script,/if\(first\)\{event\.preventDefault\(\);first\.click\(\);\}/);
 assert.match(script,/select\.value=option\.value;close\(\)/);
 assert.match(css,/\.down-menu-search-wrap\{/);
 assert.match(css,/\.down-menu-option\[hidden\]/);
 assert.match(css,/\.down-menu-options\{position:relative/);
});

test('Dashboard is a standalone first navigation link, not a Manager submenu entry',async()=>{
 const [html,script,css]=await Promise.all([
  read('../website/private-player-app.html'),read('../website/player-app.mjs'),
  read('../website/player-app.css')
 ]);
 const nav=html.slice(html.indexOf('<nav class="app-navigation"'),html.indexOf('</nav>')+6);
 assert.match(nav,/<a class="nav-direct" href="#overview" data-view-link="overview">Dashboard<\/a>/);
 assert.ok(nav.indexOf('>Dashboard</a>')<nav.indexOf('data-nav-group="manager"'));
 const manager=nav.slice(nav.indexOf('data-nav-group="manager"'),nav.indexOf('data-nav-group="operations"'));
 assert.doesNotMatch(manager,/data-view-link="overview"/);
 assert.match(manager,/data-view-link="profile"/);
 assert.equal([...nav.matchAll(/data-view-link="overview"/g)].length,1);
 assert.match(script,/renderOverviewState\(hasRealAirline\)/);
 assert.match(script,/formatWholeUsd\(first\.cashUsd\)/);
 assert.match(css,/\.nav-direct\[aria-current="page"\]/);
 for(const id of ['player-airline-note','player-cash-note','overview-progress-title',
  'overview-home-progress','overview-activation-progress'])assert.match(html,new RegExp('id="'+id+'"'));
});
