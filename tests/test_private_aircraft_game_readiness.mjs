import test from 'node:test';
import assert from 'node:assert/strict';
import {AIRCRAFT_GAME_READINESS_SQL,assessAircraftGameReadiness,
  createPrivateAircraftGameReadinessService} from '../server/private-aircraft-game-readiness.mjs';
import {createPrivateAircraftPerformanceRunwayResearchService} from '../server/private-aircraft-performance-loader.mjs';

const configurationId=166;
const aircraftVariantKey='BOEING-747-200C';
const base={configuration_id:'166',aircraft_variant_key:aircraftVariantKey,
  route_game_gate:'PROVISIONAL_DATA_ONLY',essential_fields_populated:true,
  release_hold_reason:null,civilian_service_status:'active',
  runway_surface_mode:null,paved_runway_game_eligible:null,
  passenger_cargo_loading_mode:null};
const input={configurationId,aircraftVariantKey};
function mockService(rows=[base],{enabled=true,fail=false}={}){
  let connects=0,queries=0,releases=0,args;
  const database={async connect(){connects++;return {
    async query(sql,params){
      queries++;args=params;
      if(fail)throw Error('PRIVATE CONNECTION PASSWORD DO NOT LEAK');
      return {rows};
    },release(){releases++}
  }}};
  return {service:createPrivateAircraftGameReadinessService({database,enabled}),
    get connects(){return connects},get queries(){return queries},
    get releases(){return releases},get args(){return args}};
}
const operating={
  aircraftVariantKey,phase:'TAKEOFF',aircraftConfigurationCode:'GAME-TEST',
  operatingMassKg:55000,asOfDate:'2026-11-01',
  conditions:{pressureAltitudeFt:0,outsideAirTemperatureC:15,
    headwindComponentKt:0,runwaySlopePct:0,runwayCondition:'DRY'}
};

test('private read is keyed to exact config and variant; SQL is read only',()=>{
  assert.match(AIRCRAFT_GAME_READINESS_SQL,/airlinerra\.aircraft_configuration_game_readiness_v1/);
  assert.match(AIRCRAFT_GAME_READINESS_SQL,/configuration_id=\$1::bigint/);
  assert.match(AIRCRAFT_GAME_READINESS_SQL,/variant_key=\$2::text/);
  assert.doesNotMatch(AIRCRAFT_GAME_READINESS_SQL,/\b(?:INSERT|UPDATE|DELETE|GRANT|ALTER|DROP)\b/i);
});
test('disabled gate and invalid identifiers never reach PostgreSQL',async()=>{
  const x=mockService([base],{enabled:false});
  await assert.rejects(x.service.inspect(input),/disabled/);
  assert.equal(x.connects,0);
  const y=mockService();
  for(const request of [{configurationId:0,aircraftVariantKey},
    {configurationId:1.2,aircraftVariantKey},
    {configurationId,aircraftVariantKey:"BOEING';DROP"},
    {configurationId:'166',aircraftVariantKey}])
    await assert.rejects(y.service.inspect(request),/Valid catalog/);
  assert.equal(y.connects,0);
});
test('ordinary complete catalog row permits research, never game release',async()=>{
  const x=mockService();
  const r=await x.service.inspect(input);
  assert.equal(r.catalogStatus,'PROVISIONAL_DATA_ONLY');
  assert.equal(r.researchScreeningAllowed,true);
  assert.equal(r.schedulingAllowed,false);
  assert.ok(Object.isFrozen(r));
  assert.deepEqual(x.args,[configurationId,aircraftVariantKey]);
  assert.equal(x.releases,1);
});
test('all release holds fail closed, including an otherwise complete aircraft',async()=>{
  const gates=[
    ['HOLD_GAME_RULE_NOT_INTEGRATED','LOADING_MODE_ENGINE_NOT_INTEGRATED'],
    ['HOLD_GAME_RULE_NOT_INTEGRATED','PASSENGER_SEAT_CERTIFICATION_UNVERIFIED'],
    ['HOLD_PAVED_RUNWAY_UNVERIFIED','PAVED_SURFACE_GEAR_CONFIGURATION_UNVERIFIED'],
    ['HOLD_MAINTENANCE','TEMPORARILY_GROUNDED_HEAVY_MAINTENANCE'],
    ['HOLD_REQUIRED_FIELDS_MISSING',null],['HOLD_SERVICE_UNVERIFIED',null]
  ];
  for(const [gate,reason] of gates){
    const row={...base,route_game_gate:gate,release_hold_reason:reason};
    const r=assessAircraftGameReadiness(row,input);
    assert.equal(r.catalogStatus,gate);
    assert.equal(r.researchScreeningAllowed,false);
    assert.equal(r.schedulingAllowed,false);
  }
  const inconsistent=assessAircraftGameReadiness({
    ...base,release_hold_reason:'LOADING_MODE_ENGINE_NOT_INTEGRATED'},input);
  assert.equal(inconsistent.researchScreeningAllowed,false);
});
test('empty, ambiguous and broken catalog responses are blocked and release connections',async()=>{
  const missing=mockService([]);
  assert.equal((await missing.service.inspect(input)).catalogStatus,'CATALOG_CONFIGURATION_NOT_FOUND');
  const duplicated=mockService([base,base]);
  assert.equal((await duplicated.service.inspect(input)).catalogStatus,'CATALOG_DATA_INVALID');
  const failing=mockService([base],{fail:true});
  const result=await failing.service.inspect(input);
  assert.equal(result.catalogStatus,'CATALOG_UNAVAILABLE');
  assert.doesNotMatch(JSON.stringify(result),/PRIVATE CONNECTION PASSWORD/);
  for(const s of [missing,duplicated,failing])assert.equal(s.releases,1);
  const mismatch=assessAircraftGameReadiness({...base,aircraft_variant_key:'OTHER-01'},input);
  assert.equal(mismatch.researchScreeningAllowed,false);
});
test('private runway composition rejects a hold BEFORE checking performance or runways',async()=>{
  let references=0,runways=0;
  const readiness=mockService([{...base,
    route_game_gate:'HOLD_MAINTENANCE',
    release_hold_reason:'TEMPORARILY_GROUNDED_HEAVY_MAINTENANCE'}]);
  const service=createPrivateAircraftPerformanceRunwayResearchService({
    readinessService:readiness.service,enabled:true,
    referenceLoader:{async calculate(){references++;throw Error('should not run')}},
    runwayScreeningService:{async screen(){runways++;throw Error('should not run')}}
  });
  const result=await service.evaluate({
    configurationId,aircraftScenario:operating,request:{}
  });
  assert.equal(result.referenceStatus,'CATALOG_GAME_GATE_BLOCKED');
  assert.equal(result.runwayResearch,null);
  assert.equal(result.schedulingAllowed,false);
  assert.equal(references,0);
  assert.equal(runways,0);
  assert.equal(readiness.releases,1);
});
test('provisional research may reach source screening but never schedules a flight',async()=>{
  let called=0;
  const service=createPrivateAircraftPerformanceRunwayResearchService({
    readinessService:mockService().service,enabled:true,
    referenceLoader:{async calculate(){called++;return {
      status:'REVIEWED_REFERENCE_POINT_SELECTED',
      calculationReference:'RESEARCH REVIEW 1',
      requiredDistancesM:{toraM:1600,todaM:1800,asdaM:1750},
      referencePointMassKg:55000,calculationMethod:'EXACT_GRID_POINT'
    }}},
    runwayScreeningService:{async screen(){called++;return {schedulingAllowed:false}}}
  });
  const result=await service.evaluate({configurationId,aircraftScenario:operating,request:{}});
  assert.equal(called,2);
  assert.equal(result.catalogReadiness.catalogStatus,'PROVISIONAL_DATA_ONLY');
  assert.equal(result.catalogReadiness.schedulingAllowed,false);
  assert.equal(result.schedulingAllowed,false);
});
