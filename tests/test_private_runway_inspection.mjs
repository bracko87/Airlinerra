import test from 'node:test';
import assert from 'node:assert/strict';
import {
  WORLD1_RUNWAY_INSPECTION_SQL,
  validateRunwayInspectionRequest,
  createPrivateRunwayInspectionService
} from '../server/private-runway-inspection.mjs';

const request={
  worldId:1,airportKey:'OURAIRPORTS:3471',asOfDate:'2026-10-27'
};
const runway={
  world_id:1,airport_key:request.airportKey,release_enabled:false,
  runway_pair:'09/27',source_effective_date:'2026-10-01',
  physical_length_m:'1957.0',normalized_surface:'ASPHALT',
  material_verification:'VERIFIED',runway_operational_status:'RESTRICTED',
  research_admission:'NOT_APPROVED',scheduled_permission:'UNVERIFIED',
  directions:[{
    direction:'09',tora_m:null,toda_m:null,asda_m:null,lda_m:null,
    takeoff_status:'UNVERIFIED',landing_status:'UNVERIFIED'
  }]
};
function makeService({rows=[runway],enabled=true}={}) {
  const calls=[];let releases=0;let connects=0;
  const service=createPrivateRunwayInspectionService({
    enabled,database:{async connect(){
      connects++;
      return {async query(sql,params){calls.push({sql,params});return {rows};},
        release(){releases++;}};
    }}
  });
  return {service,calls,get connects(){return connects;},get releases(){return releases;}};
}

test('disabled by default and validates request before connecting',async()=>{
  const obj=makeService({enabled:false});
  await assert.rejects(obj.service.inspect(request),/disabled/);
  assert.equal(obj.connects,0);
  assert.deepEqual(validateRunwayInspectionRequest(request),request);
});
test('rejects malformed airport, world, or date before database',async()=>{
  const obj=makeService();
  const bad=[
    {...request,worldId:2},{...request,worldId:'1'},
    {...request,airportKey:'OURAIRPORTS:0'},
    {...request,airportKey:"OURAIRPORTS:3471' OR 1=1 --"},
    {...request,asOfDate:'2026-02-30'},
    {...request,asOfDate:'2026-10-27T12:00:00Z'},
    {...request,asOfDate:'2030-13-01'}
  ];
  for(const req of bad) await assert.rejects(obj.service.inspect(req));
  assert.equal(obj.connects,0);
});
test('airport outside approved game catalog yields no runway facts',async()=>{
  const obj=makeService({rows:[]});
  const result=await obj.service.inspect({...request,airportKey:'OURAIRPORTS:4195'});
  assert.equal(result.inApprovedWorld,false);
  assert.equal(result.status,'NOT_IN_APPROVED_WORLD');
  assert.equal(result.mayScheduleFlights,false);
  assert.equal(result.runways.length,0);
  assert.deepEqual(obj.calls[0].params,[1,'OURAIRPORTS:4195','2026-10-27']);
  assert.equal(obj.releases,1);
});
test('prelaunch locks even physically verified airport; never authorizes flight',async()=>{
  const obj=makeService();
  const result=await obj.service.inspect(request);
  assert.equal(result.status,'PRELAUNCH_LOCKED');
  assert.equal(result.inApprovedWorld,true);
  assert.equal(result.releaseEnabled,false);
  assert.equal(result.mayScheduleFlights,false);
  assert.equal(result.runways[0].materialVerified,true);
  assert.equal(result.runways[0].mayScheduleFlights,false);
  assert.equal(result.runways[0].directions[0].toraM,null);
  assert.ok(Object.isFrozen(result));
  assert.ok(Object.isFrozen(result.runways));
  assert.equal(obj.releases,1);
});
test('even hypothetical release enabled never constitutes scheduling permission',async()=>{
  const obj=makeService({rows:[{...runway,release_enabled:true,
    runway_operational_status:'OPEN',research_admission:'APPROVED',
    scheduled_permission:'CIVIL_PUBLIC_ACCESS'}]});
  const result=await obj.service.inspect(request);
  assert.equal(result.status,'RESEARCH_ONLY');
  assert.equal(result.mayScheduleFlights,false);
  assert.equal(result.runways[0].mayScheduleFlights,false);
});
test('approved airport with no dated source has no effective runway',async()=>{
  const obj=makeService({rows:[{...runway,runway_pair:null,physical_length_m:null,
    directions:[],release_enabled:true}]});
  const result=await obj.service.inspect(request);
  assert.equal(result.status,'NO_EFFECTIVE_RUNWAY_SOURCES');
  assert.equal(result.runways.length,0);
  assert.equal(result.mayScheduleFlights,false);
});
test('unknown pavement remains technically unverified and scheduling disabled',async()=>{
  const obj=makeService({rows:[{...runway,normalized_surface:'MACADAM_UNRESOLVED',
    material_verification:'UNVERIFIED',physical_length_m:'2407'}]});
  const result=await obj.service.inspect(request);
  assert.equal(result.runways[0].materialVerified,false);
  assert.equal(result.mayScheduleFlights,false);
});
test('guards duplicate effective runways and malformed DB releases',async()=>{
  const duplicate=makeService({rows:[runway,runway]});
  await assert.rejects(duplicate.service.inspect(request),/Duplicate effective runway/);
  assert.equal(duplicate.releases,1);
  const mismatch=makeService({rows:[{...runway,airport_key:'OURAIRPORTS:3472'}]});
  await assert.rejects(mismatch.service.inspect(request),/Inconsistent private airport/);
  assert.equal(mismatch.releases,1);
  const badSurface=makeService({rows:[{...runway,physical_length_m:'bogus'}]});
  await assert.rejects(badSurface.service.inspect(request),/Invalid or incomplete runway/);
  assert.equal(badSurface.releases,1);
});
test('source query is strictly read-only and joins only approved World 1',()=>{
  assert.match(WORLD1_RUNWAY_INSPECTION_SQL,
    /FROM airlinerra_game\.approved_game_airports a/);
  assert.match(WORLD1_RUNWAY_INSPECTION_SQL,
    /JOIN airlinerra_game\.platform_release_gate g/);
  assert.match(WORLD1_RUNWAY_INSPECTION_SQL,
    /sv\.source_effective_date <= \$3::date/);
  assert.match(WORLD1_RUNWAY_INSPECTION_SQL,/sv\.source_effective_date IS NOT NULL/);
  assert.match(WORLD1_RUNWAY_INSPECTION_SQL,/sv\.airport_key = \$2::text/);
  assert.doesNotMatch(WORLD1_RUNWAY_INSPECTION_SQL,
    /\b(?:INSERT|UPDATE|DELETE|MERGE|CREATE|ALTER|DROP|GRANT|TRUNCATE)\b/i);
});
