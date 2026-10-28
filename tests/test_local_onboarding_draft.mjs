import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validDraft,saveLocalDraft,readLocalDraft,clearLocalDraft} from '../website/local-onboarding-draft.mjs';
const here=new URL('http://localhost:5188/player.html');
const store=()=>{const map=new Map();return {getItem:k=>map.get(k)||null,setItem:(k,v)=>map.set(k,v),removeItem:k=>map.delete(k)}};
const sample={worldId:1,countryIso:'DE',airportKey:'OURAIRPORTS:301881',airlineName:'Airlinerra Demo Airways'};
test('draft saves, resumes, clears and never activates an airline',()=>{
 const st=store();assert.equal(readLocalDraft(st,here),null);assert.equal(validDraft(sample),true);
 assert.equal(saveLocalDraft(st,here,sample).previewOnly,true);
 assert.equal(readLocalDraft(st,here).airlineName,sample.airlineName);
 assert.equal(clearLocalDraft(st,here),true);assert.equal(readLocalDraft(st,here),null);
});
test('draft rejects invalid world/country/airport/name and production origin',()=>{
 for(const o of [{worldId:4},{countryIso:'D'},{airportKey:'123'},{airlineName:'A'.repeat(61)},{airlineName:'<script>'}])
  assert.equal(validDraft({...sample,...o}),false);
 assert.throws(()=>saveLocalDraft(store(),new URL('https://airlinerra.com'),sample),/Local draft only/);
});
test('prelaunch operational pages offer controls without enabling game writes',async()=>{
 const read=p=>readFile(new URL(p,import.meta.url),'utf8');
 const [html,js,overlay]=await Promise.all([read('../website/private-player-app.html'),read('../website/player-app.mjs'),read('../website/dev-scripts/invited-overlay.mjs')]);
 for(const id of ['setup-save-draft','setup-clear-draft','setup-draft-summary','settings-save'])assert.match(html,new RegExp('id="'+id+'"'));
 assert.match(html,/class="week-grid"/);assert.match(js,/saveLocalDraft\(window\.sessionStorage/);
 assert.match(js,/clearLocalDraft\(window\.sessionStorage/);
 assert.match(overlay,/local-onboarding-draft\.mjs/);
 assert.match(html,/disabled>Create airline/);
 assert.match(js,/\.createAirline\(/);
 assert.match(js,/\.acceptLegal\(/);
 assert.match(js,/loadRealOnboarding/);
 assert.doesNotMatch(js,/\.signUp\(/);
});
