import test from 'node:test';
import assert from 'node:assert/strict';
import {
  validateAircraftOperatingScenario, calculateReviewedAircraftPerformance
} from '../server/private-aircraft-performance-reference.mjs';

const conditions=Object.freeze({
  pressureAltitudeFt:0,outsideAirTemperatureC:15,
  headwindComponentKt:0,runwaySlopePct:0,runwayCondition:'DRY'
});
const scenario=(overrides={})=>({
  aircraftVariantKey:'SYNTHETIC-01',
  aircraftConfigurationCode:'FLAPS-TEST',phase:'TAKEOFF',
  operatingMassKg:55000,asOfDate:'2026-10-27',conditions,
  ...overrides
});
const reference=(overrides={})=>({
  aircraftVariantKey:'SYNTHETIC-01',maxTakeoffMassKg:80000,
  maxLandingMassKg:65000,minReferenceMassKg:45000,wingspanM:32,
  sourceAuthority:'SYNTHETIC TEST MANUAL NOT REAL',
  sourceDocumentRef:'SYNTHETIC-TEST-REFERENCE',
  sourceRevision:'00',sourceEffectiveDate:'2026-01-01',
  reviewStatus:'PRIMARY_SOURCE_REVIEWED',
  allowConservativeMassUpperEnvelope:true,...overrides
});
const point=(weight,tora,toda,asda,overrides={})=>({
  phase:'TAKEOFF',aircraftConfigurationCode:'FLAPS-TEST',
  operatingMassKg:weight,...conditions,
  toraM:tora,todaM:toda,asdaM:asda,ldaM:null,
  sourceTableReference:'SYNTHETIC GRID ROW',
  reviewStatus:'PRIMARY_SOURCE_REVIEWED',...overrides
});
const points=()=>[point(50000,1500,1700,1600),point(60000,2000,2200,2100)];
const calculate=(s=scenario(),r=reference(),p=points())=>
  calculateReviewedAircraftPerformance({scenario:s,reference:r,points:p});

test('requires valid phase, variant, configuration and all sourced conditions',()=>{
  assert.ok(Object.isFrozen(validateAircraftOperatingScenario(scenario())));
  for(const invalid of [
    scenario({operatingMassKg:0}),scenario({phase:'CLIMB'}),
    scenario({aircraftVariantKey:'bad lower'}),
    scenario({asOfDate:'2026-02-30'}),
    scenario({conditions:{...conditions,runwayCondition:'CONTAMINATED'}}),
    scenario({conditions:{...conditions,headwindComponentKt:Infinity}}),
    scenario({conditions:{pressureAltitudeFt:0}})
  ])assert.throws(()=>validateAircraftOperatingScenario(invalid));
});
test('exact reviewed mass returns only manufacturer-row synthetic requirements',()=>{
  const r=calculate(scenario({operatingMassKg:60000}));
  assert.equal(r.status,'REVIEWED_REFERENCE_POINT_SELECTED');
  assert.equal(r.calculationMethod,'EXACT_GRID_POINT');
  assert.deepEqual(r.requiredDistancesM,{toraM:2000,todaM:2200,asdaM:2100});
  assert.equal(r.schedulingAllowed,false);
});
test('approved mass envelope conservatively selects higher reviewed weight',()=>{
  const r=calculate();
  assert.equal(r.status,'REVIEWED_REFERENCE_POINT_SELECTED');
  assert.equal(r.referencePointMassKg,60000);
  assert.equal(r.actualOperatingMassKg,55000);
  assert.equal(r.calculationMethod,'SOURCE_APPROVED_NEXT_HIGHER_MASS');
  assert.equal(r.requiredDistancesM.toraM,2000);
  assert.equal(r.schedulingAllowed,false);
});
test('off-grid weight rejected if upper-envelope use not reviewed',()=>{
  const r=calculate(scenario(),reference({allowConservativeMassUpperEnvelope:false}));
  assert.equal(r.status,'OFF_GRID_MASS_REQUIRES_REVIEWED_ENVELOPE');
  assert.equal(r.requiredDistancesM,null);
});
test('weather, elevation, wind, slope, and wet runway require exact source data',()=>{
  for(const update of [
    {pressureAltitudeFt:1000},
    {outsideAirTemperatureC:25},
    {headwindComponentKt:5},
    {runwaySlopePct:0.5},
    {runwayCondition:'WET'}
  ]){
    const r=calculate(scenario({conditions:{...conditions,...update}}));
    assert.equal(r.status,'CONDITIONS_NOT_COVERED');
  }
});
test('prohibits extrapolation and maximum takeoff/landing mass exceedance',()=>{
  assert.equal(calculate(scenario({operatingMassKg:49000})).status,'WEIGHT_OUTSIDE_SOURCE_GRID');
  assert.equal(calculate(scenario({operatingMassKg:72000})).status,'WEIGHT_OUTSIDE_SOURCE_GRID');
  assert.equal(calculate(scenario({operatingMassKg:81000})).status,'AIRCRAFT_MASS_OUTSIDE_REFERENCE_LIMITS');
});
test('unreviewed or future manufacturer sources never yield a performance number',()=>{
  assert.equal(calculate(scenario(),reference({reviewStatus:'UNVERIFIED'})).status,'REVIEWED_REFERENCE_NOT_AVAILABLE');
  assert.equal(calculate(scenario(),reference({sourceEffectiveDate:'2026-11-01'})).status,'REVIEWED_REFERENCE_NOT_AVAILABLE');
  assert.equal(calculate(scenario(),null).status,'REVIEWED_REFERENCE_NOT_AVAILABLE');
  assert.equal(calculate(scenario(),reference(),[]).status,'CONDITIONS_NOT_COVERED');
});
test('duplicate, non-monotone, incomplete source grid does not pass',()=>{
  assert.throws(()=>calculate(scenario(),reference(),[...points(),point(60000,2000,2200,2100)]),/duplicate/);
  assert.throws(()=>calculate(scenario(),reference(),[point(50000,2100,2300,2200),point(60000,2000,2200,2100)]),/Non-monotonic/);
  assert.throws(()=>calculate(scenario(),reference(),[point(50000,1500,1700,1600),point(60000,2000,2200,null)]),/Incomplete/);
});
test('landing requires independent LDA reference and landing mass limit',()=>{
  const s=scenario({phase:'LANDING',operatingMassKg:60000});
  const landing=[point(55000,null,null,null,{phase:'LANDING',ldaM:1400}),
    point(60000,null,null,null,{phase:'LANDING',ldaM:1600})];
  const result=calculate(s,reference(),landing);
  assert.deepEqual(result.requiredDistancesM,{ldaM:1600});
  assert.equal(calculate(scenario({phase:'LANDING',operatingMassKg:67000}),reference(),landing).status,
    'AIRCRAFT_MASS_OUTSIDE_REFERENCE_LIMITS');
});
