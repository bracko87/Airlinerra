import test from 'node:test';
import assert from 'node:assert/strict';
import {screenAircraftRunways,validatePerformanceScenario,createPrivateAircraftRunwayScreeningService} from '../server/private-aircraft-runway-screen.mjs';
const takeoff=(r={toraM:1900,todaM:2500,asdaM:1800})=>({
 aircraftCode:'SYNTH-1',phase:'TAKEOFF',operatingMassKg:45000,
 calculationReference:'SYNTHETIC-TEST-DATA',requiredDistancesM:r
});
const landing=(n=1400)=>({
 aircraftCode:'SYNTH-1',phase:'LANDING',operatingMassKg:42000,
 calculationReference:'SYNTHETIC-TEST-DATA',requiredDistancesM:{ldaM:n}
});
const direction=(direction,d={})=>({
 direction,toraM:null,todaM:null,asdaM:null,ldaM:null,
 takeoffStatus:'UNVERIFIED',landingStatus:'UNVERIFIED',...d
});
const runway=(opts={})=>({
 runwayPair:'10/28',physicalLengthM:1972,normalizedSurface:'ASPHALT',
 materialVerified:true,operationalStatus:'OPEN',
 researchAdmission:'NOT_APPROVED',scheduledPermission:'UNVERIFIED',
 directions:[direction('10',{toraM:1972,todaM:1972,asdaM:1972,ldaM:1972}),
 direction('28',{toraM:1972,todaM:2650,asdaM:1972,ldaM:1890})],...opts
});
const check=(scenario,runways,overrides={})=>screenAircraftRunways({
 scenario,inspection:{worldId:1,airportKey:'OURAIRPORTS:3471',
 inApprovedWorld:true,releaseEnabled:false,runways,...overrides}
});
test('requires explicit aircraft performance source and nonzero distances',()=>{
 assert.ok(Object.isFrozen(validatePerformanceScenario(takeoff())));
 for(const bad of [
  {...takeoff(),operatingMassKg:0},
  {...takeoff(),calculationReference:'x'},
  {...takeoff(),requiredDistancesM:{toraM:1000,todaM:2000}}
 ]) assert.throws(()=>validatePerformanceScenario(bad));
});

test('Melun: clearway extends TODA, never TORA',()=>{
 const r=check(takeoff(),[runway()]);
 const row=r.candidates.find(c=>c.direction==='28');
 assert.equal(row.numericStatus,'SUFFICIENT');
 assert.deepEqual(row.checks.map(c=>c.availableM),[1972,2650,1972]);
 const short=check(takeoff({toraM:2000,todaM:2500,asdaM:1900}),[runway()]);
 assert.equal(short.candidates.find(c=>c.direction==='28').numericStatus,'INSUFFICIENT');
 assert.equal(short.schedulingAllowed,false);
});

test('unapproved airport yields no aircraft candidates',()=>{
 const r=check(takeoff(),[runway()],{inApprovedWorld:false,airportKey:'OURAIRPORTS:4195'});
 assert.equal(r.candidates.length,0);
 assert.equal(r.schedulingAllowed,false);
});

test('directional landing distances are not interchangeable',()=>{
 const x=runway({runwayPair:'11/29',directions:[direction('11',{ldaM:1376}),direction('29',{ldaM:1463})]});
 const r=check(landing(1400),[x]);
 assert.deepEqual(r.candidates.map(c=>c.numericStatus),['INSUFFICIENT','SUFFICIENT']);
});

test('landing prohibited despite sufficient LDA',()=>{
 const x=runway({runwayPair:'09/27',scheduledPermission:'PROHIBITED',directions:[direction('09',{ldaM:1800,landingStatus:'PROHIBITED'})]});
 const r=check(landing(1500),[x]);
 assert.equal(r.candidates[0].numericStatus,'SUFFICIENT');
 assert.ok(r.candidates[0].blockers.includes('DIRECTION_OPERATION_PROHIBITED'));
 assert.equal(r.schedulingAllowed,false);
});
