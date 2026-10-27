import test from 'node:test';
import assert from 'node:assert/strict';
import {
  AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL,
  createPrivateAircraftPerformanceReferenceLoader,
  createPrivateAircraftPerformanceRunwayResearchService
} from '../server/private-aircraft-performance-loader.mjs';

const operating={
  aircraftVariantKey:'SYNTHETIC-01',phase:'TAKEOFF',
  aircraftConfigurationCode:'FLAPS-TEST',
  operatingMassKg:55000,asOfDate:'2026-10-27',
  conditions:{pressureAltitudeFt:0,outsideAirTemperatureC:15,
    headwindComponentKt:0,runwaySlopePct:0,runwayCondition:'DRY'}
};
const base={
  reference_set_id:41,aircraft_variant_key:'SYNTHETIC-01',
  max_takeoff_mass_kg:'80000.0',max_landing_mass_kg:'65000.0',
  min_reference_mass_kg:'45000.0',wingspan_m:'32.00',
  source_authority:'SYNTHETIC TEST ONLY',
  source_document_ref:'SYNTHETIC SOURCE REF',source_revision:'0',
  source_effective_date:'2026-01-01',
  reference_review_status:'PRIMARY_SOURCE_REVIEWED',
  allow_conservative_mass_upper_envelope:true,
  point_id:1,phase:'TAKEOFF',aircraft_configuration_code:'FLAPS-TEST',
  operating_mass_kg:'50000.0',pressure_altitude_ft:0,
  outside_air_temperature_c:'15.0',headwind_component_kt:'0.0',
  runway_slope_pct:'0.00',runway_condition:'DRY',
  required_tora_m:'1500.0',required_toda_m:'1700.0',required_asda_m:'1600.0',
  required_lda_m:null,source_table_reference:'SYNTHETIC ROW 1',
  point_review_status:'PRIMARY_SOURCE_REVIEWED'
};
const points=[base,{...base,point_id:2,operating_mass_kg:'60000.0',
  required_tora_m:'2000.0',required_toda_m:'2200.0',
  required_asda_m:'2100.0',source_table_reference:'SYNTHETIC ROW 2'}];
function mocked(rows,enabled=true){
  let queries=0,releases=0,connects=0,args=null;
  const database={async connect(){connects++;return {
    async query(sql,params){queries++;args=params;return {rows};},
    release(){releases++;}
  };}};
  const loader=createPrivateAircraftPerformanceReferenceLoader({database,enabled});
  return {loader,get queries(){return queries;},get releases(){return releases;},
    get connects(){return connects;},get args(){return args;}};
}

test('query uses explicitly bound aircraft variant, date and environment',()=>{
  assert.match(AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL,/aircraft_variant_key=\$1::text/);
  assert.match(AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL,/source_effective_date<=\$2::date/);
  assert.match(AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL,/runway_condition=\$9::text/);
  assert.doesNotMatch(AIRCRAFT_PERFORMANCE_REFERENCE_READ_SQL,/\b(?:INSERT|DELETE|UPDATE|DROP|ALTER)\b/i);
});
test('disabled loader never contacts private database',async()=>{
  const db=mocked(points,false);
  await assert.rejects(db.loader.calculate(operating),/disabled/);
  assert.equal(db.connects,0);
});
test('empty real-world reference catalog fails closed without fabricated distances',async()=>{
  const db=mocked([]);
  const result=await db.loader.calculate(operating);
  assert.equal(result.status,'REVIEWED_REFERENCE_NOT_AVAILABLE');
  assert.equal(result.requiredDistancesM,null);
  assert.equal(result.schedulingAllowed,false);
  assert.equal(db.queries,1);
  assert.equal(db.releases,1);
});
test('source-reviewed PostgreSQL numeric rows calculate conservative higher weight',async()=>{
  const db=mocked(points);
  const result=await db.loader.calculate(operating);
  assert.equal(result.status,'REVIEWED_REFERENCE_POINT_SELECTED');
  assert.deepEqual(result.requiredDistancesM,{toraM:2000,todaM:2200,asdaM:2100});
  assert.deepEqual(db.args,['SYNTHETIC-01','2026-10-27','TAKEOFF','FLAPS-TEST',0,15,0,0,'DRY']);
  assert.equal(result.schedulingAllowed,false);
  assert.equal(db.releases,1);
});
test('newer unreviewed source cannot silently be replaced with older approval',async()=>{
  const db=mocked(points.map(row=>({...row,reference_review_status:'UNVERIFIED'})));
  const result=await db.loader.calculate(operating);
  assert.equal(result.status,'REVIEWED_REFERENCE_NOT_AVAILABLE');
});
test('conflicting source IDs and failed queries release the DB client',async()=>{
  const inconsistent=mocked([points[0],{...points[1],reference_set_id:99}]);
  await assert.rejects(inconsistent.loader.calculate(operating),/Conflicting/);
  assert.equal(inconsistent.releases,1);
  let released=0;
  const db=createPrivateAircraftPerformanceReferenceLoader({enabled:true,database:{
    async connect(){return {async query(){throw Error('database offline');},
      release(){released++;}};}
  }});
  await assert.rejects(db.calculate(operating),/database offline/);
  assert.equal(released,1);
});
test('composition never calls runway evaluator if certified source unavailable',async()=>{
  let called=0;
  const service=createPrivateAircraftPerformanceRunwayResearchService({enabled:true,
    referenceLoader:{async calculate(){return {status:'CONDITIONS_NOT_COVERED',
      blockers:['NO_EXACT_SOURCE_GRID']};}},
    runwayScreeningService:{async screen(){called++;throw Error('must not call');}}
  });
  const result=await service.evaluate({request:{},aircraftScenario:operating});
  assert.equal(result.referenceStatus,'CONDITIONS_NOT_COVERED');
  assert.equal(result.runwayResearch,null);
  assert.equal(result.schedulingAllowed,false);
  assert.equal(called,0);
});
test('composition passes sourced requirements into screening but never grants flights',async()=>{
  let passed=null;
  const db=mocked(points);
  const service=createPrivateAircraftPerformanceRunwayResearchService({enabled:true,
    referenceLoader:db.loader,
    runwayScreeningService:{async screen(value){passed=value;return {schedulingAllowed:false};}}
  });
  const request={worldId:1,airportKey:'OURAIRPORTS:3471',asOfDate:'2026-10-27'};
  const result=await service.evaluate({request,aircraftScenario:operating});
  assert.deepEqual(passed.request,request);
  assert.deepEqual(passed.scenario.requiredDistancesM,{toraM:2000,todaM:2200,asdaM:2100});
  assert.equal(result.schedulingAllowed,false);
});
