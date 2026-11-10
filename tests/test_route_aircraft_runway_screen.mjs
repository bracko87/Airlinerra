import test from 'node:test';
import assert from 'node:assert/strict';
import {assessAircraftRouteRunways,requiredAircraftRunwayM,screenAirportRunway} from '../website/route-aircraft-runway-screen.mjs';
import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
const runway=(lengthM,surface='ASP',operationalStatus='unknown')=>({lengthM,surface,operationalStatus});
const plane={id:999,model:'Example aircraft',fullWeightTakeoffReferenceM:1500,
 fullWeightLandingReferenceM:1400,takeoffM:1300,landingM:1200};
test('origin 1200m vs required takeoff 1500m is a visible hard blocker',()=>{
 const result=assessAircraftRouteRunways({aircraft:plane,
  origin:{runways:[runway(1200)]},destination:{runways:[runway(3200)]}});
 assert.equal(result.status,'BLOCKED');
 assert.equal(result.origin.status,'BLOCKED');
 assert.equal(result.origin.requiredM,1500);
 assert.equal(result.origin.availableM,1200);
 assert.equal(result.origin.deficitM,300);
 assert.match(result.blockingReasons[0],/Origin.*1,200 m.*1,500 m.*takeoff.*300 m/);
 assert.equal(result.officialDispatchApproved,false);
});
test('too-short runway at arrival alone rejects the selected aircraft',()=>{
 const result=assessAircraftRouteRunways({aircraft:plane,
  origin:{runways:[runway(2200)]},destination:{runways:[runway(1200)]}});
 assert.equal(result.status,'BLOCKED');
 assert.equal(result.destination.status,'BLOCKED');
 assert.equal(result.destination.deficitM,200);
 assert.match(result.blockingReasons[0],/Destination.*landing/);
});
test('longest suitable paved runway may satisfy another physically shorter runway',()=>{
 const result=assessAircraftRouteRunways({aircraft:plane,
  origin:{runways:[runway(1200),runway(1800,'CONC')]},
  destination:{runways:[runway(1200),runway(2500,'ASPH')]}});
 assert.equal(result.status,'PASS');
 assert.equal(result.origin.availableM,1800);
 assert.equal(result.destination.availableM,2500);
});
test('closed and unpaved runways are not considered suitable',()=>{
 const result=assessAircraftRouteRunways({aircraft:plane,
  origin:{runways:[runway(3000,'GRASS'),runway(1500,'ASP','closed'),runway(1200,'CON')]},
  destination:{runways:[runway(2500)]}});
 assert.equal(result.status,'BLOCKED');
 assert.equal(result.origin.availableM,1200);
});
test('unverified aircraft performance and unrecorded runways become REVIEW, not fictional bans',()=>{
 assert.equal(screenAirportRunway({airport:{runways:[runway(1200)]},aircraft:{},
  operation:'departure'}).status,'REVIEW');
 assert.equal(screenAirportRunway({airport:{runways:[]},aircraft:plane,
  operation:'arrival'}).status,'REVIEW');
 assert.equal(requiredAircraftRunwayM({takeoffM:1500},'departure'),1500);
 assert.equal(requiredAircraftRunwayM({landingM:1400},'arrival'),1400);
});
test('route UI automatically applies checks and server gate on every save without optional button',async()=>{
 const [source,markup,bundle]=await Promise.all([
  read('../website/route-planner.mjs'),
  read('../website/route-planner.mjs'),
  read('../website/dev-scripts/invited-overlay.mjs')]);
 assert.match(source,/const syncAircraftCompatibility=\(\)=>/);
 assert.match(source,/runwayAssessment\(model\)/);
 assert.match(source,/if\(button\)button\.disabled=assessment\?\.status==='BLOCKED'/);
 assert.match(source,/const automaticPreflight=async/);
 assert.match(source,/noiseCurfewCheck\(\{/);
 assert.match(source,/const preflight=await automaticPreflight\(\{force:true\}\)/);
 assert.match(source,/if\(preflight\?\.gameHardBlocked===true\)/);
 assert.match(source,/if\(preflight\?\.gameHardBlocked===true\)/);
 assert.match(source,/aircraftConfigurationId:selectedCatalog\?\.id\?\?ownedChoice\.configurationId/);
 assert.doesNotMatch(source,/if\(target\.id==='route-preflight-check'\)/);
 assert.match(bundle,/'route-aircraft-runway-screen\.mjs'/);
});
