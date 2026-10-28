import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {managerLandingView,playerViewUrl} from '../website/player-app-model.mjs';

const read=path=>readFile(new URL(path,import.meta.url),'utf8');
test('newly verified manager lands on Create airline even before player API finishes',()=>{
 assert.equal(managerLandingView({requestedView:'overview',hasAirline:null}),'onboarding');
 assert.equal(managerLandingView({requestedView:'overview',hasAirline:false}),'onboarding');
 assert.equal(managerLandingView({requestedView:'onboarding',hasAirline:null}),'onboarding');
 assert.equal(playerViewUrl(managerLandingView({requestedView:'overview',hasAirline:false})),'/player.html#onboarding');
});
test('returning manager with a real airline is routed to Overview',()=>{
 assert.equal(managerLandingView({requestedView:'onboarding',hasAirline:true}),'overview');
 assert.equal(managerLandingView({requestedView:'overview',hasAirline:true}),'overview');
 assert.equal(playerViewUrl(managerLandingView({requestedView:'onboarding',hasAirline:true})),'/player.html#overview');
});
test('explicit navigation to another page is not hijacked by onboarding',()=>{
 for(const target of ['profile','worlds','fleet','settings','airports']){
  assert.equal(managerLandingView({requestedView:target,hasAirline:null}),target);
  assert.equal(managerLandingView({requestedView:target,hasAirline:true}),target);
 }
});
test('email verification and password sign-in choose the onboarding URL',async()=>{
 const script=await read('../website/invited-tester-page.mjs');
 assert.match(script,/window\.location\.replace\('\/player\.html#onboarding'\)/);
 assert.doesNotMatch(script,/window\.location\.replace\('\/player\.html#overview'\)/);
});
test('player waits for verified Auth before routing; API errors never pretend an airline was created',async()=>{
 const [script,html]=await Promise.all([
  read('../website/player-app.mjs'),read('../website/private-player-app.html')
 ]);
 assert.match(script,/setManager\(session\.user\);[\s\S]*?initialManagerLanding=true;[\s\S]*?navigateTo\('onboarding'\)/);
 assert.match(script,/managerLandingView\(\{requestedView:'onboarding',hasAirline:hasRealAirline\}\)/);
 assert.match(script,/initialManagerLanding=false;/);
 assert.match(script,/setup-retry-loading/);
 assert.match(html,/id="setup-retry-loading"[^>]*hidden/);
 assert.match(script,/Unable to load airline setup. Please select Retry/);
 assert.match(script,/doc\.getElementById\('setup-create-airline'\)\.disabled=true/);
});
