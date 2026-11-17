import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {AOC_STATUS_SQL,createSection9AocReadService}
 from '../server/section9-aoc-read-service.mjs';
const USER='22222222-2222-4222-8222-222222222222';
const AIRLINE='11111111-1111-4111-8111-111111111111';
function setup({result={airlineId:AIRLINE,worldId:1,status:'planned_not_released',
  issued:false,safetyRating:null,readOnly:true},
 source='verified_game_player_session',user=USER,clock='2026-11-17',
 allow=true}={}){
 const calls=[];
 let released=0;
 const database={
  connect:async()=>({
   query:async(sql,args)=>{
    calls.push({sql,args});
    return sql===AOC_STATUS_SQL.verifiedGameDay?
      {rowCount:1,rows:[{game_day:clock}]}:
      {rowCount:1,rows:[{result}]};
   },
   release:()=>{released++;}
  })
 };
 const identityAuthority={authorizeStatus:async request=>{
  calls.push({identityRequest:request});
  return {authorized:allow,source,ownerPlayerId:user,airlineId:request.airlineId};
 }};
 return {service:createSection9AocReadService({database,identityAuthority}),
 calls,releases:()=>released};
}
test('AOC owner read is private, read-only, and never invents an issued certificate',async()=>{
 const {service,calls,releases}=setup();
 const r=await service.getOwnedStatus({airlineId:AIRLINE,ownerPlayerId:USER,
  holdingId:'not-a-holding',playerId:'spoofed'});
 assert.deepEqual(r,{airlineId:AIRLINE,worldId:1,
  status:'planned_not_released',issued:false,safetyRating:null,readOnly:true});
 assert.deepEqual(calls[0],{identityRequest:{airlineId:AIRLINE}});
 assert.deepEqual(calls[2].args,[USER,AIRLINE,'2026-11-17']);
 assert.equal(releases(),1);
 assert.match(calls[1].sql,/section9_verified_permission_game_day_v1/);
 assert.match(calls[2].sql,/section9_aoc_owned_status_v1/);
 assert.equal(service.issueOriginal,undefined);
 assert.equal(service.payCorrective,undefined);
 assert.equal(service.renew,undefined);
});
test('unauthorised, forged player or invalid company IDs cannot query AOC state',async()=>{
 for(const k of [
  {source:'browser_supplied',user:USER},
  {source:'verified_game_player_session',user:'bad'},
  {source:'verified_game_player_session',user:USER,allow:false},
 ]){
  const {service,calls}=setup(k);
  await assert.rejects(()=>service.getOwnedStatus({airlineId:AIRLINE}),
   /AOC_READ_UNVERIFIED_PLAYER/);
  assert.equal(calls.length,1,'no private database read');
 }
 const {service}=setup();
 await assert.rejects(()=>service.getOwnedStatus({airlineId:'bad'}),
  /AOC_READ_INVALID_AIRLINE_ID/);
});
test('database ownership or malformed response fails closed',async()=>{
 const {service,releases}=setup({result:{airlineId:AIRLINE,status:'active',
  issued:true,worldId:2,readOnly:true}});
 await assert.rejects(()=>service.getOwnedStatus({airlineId:AIRLINE}),
  /AOC_READ_INVALID_RESPONSE/);
 assert.equal(releases(),1);
});
test('frozen/unverified clock remains read-only, not an issuance signal',async()=>{
 const {service}=setup({clock:null});
 const r=await service.getOwnedStatus({airlineId:AIRLINE});
 assert.equal(r.issued,false);
 assert.equal(r.status,'planned_not_released');
});
test('SQL foundation keeps all release controls disabled and financial permissions private',async()=>{
 const files=[
  '../docs/sql/AIRLINERRA_AOC_DORMANT_FOUNDATION_2026-11-17.sql',
  '../docs/sql/AIRLINERRA_AOC_DORMANT_PRIVATE_OPERATIONS_2026-11-17.sql',
  '../docs/sql/AIRLINERRA_AOC_CORRECTIVE_RECEIPT_HARDENING_2026-11-17.sql'
 ];
 const [foundation,procedures,repair]=await Promise.all(
  files.map(p=>readFile(new URL(p,import.meta.url),'utf8')));
 assert.match(foundation,/VALUES \(1,false,false,false,false,'INITIAL_DORMANT_AOC_FOUNDATION'\)/);
 assert.match(foundation,/section9_aoc_safety_score_v1/);
 assert.match(foundation,/ENABLE ROW LEVEL SECURITY/g);
 assert.match(procedures,/current_user IS DISTINCT FROM 'postgres'/);
 assert.match(procedures,/aoc_review_not_released/);
 assert.match(procedures,/aoc_not_released/);
 assert.match(procedures,/aoc_corrections_not_released/);
 assert.match(repair,/aoc_use_existing_paid_maintenance_job/);
 assert.match(repair,/section9_game_maintenance_service_receipts_v1/);
 assert.match(repair,/section9_aoc_compliance_receipts_v1/);
 assert.match(repair,/ledger_balance<work.quote_usd/);
 assert.doesNotMatch(procedures,/cron\.schedule|policy\s+SET\s+issuance_enabled\s*=\s*true/i);
 assert.doesNotMatch(repair,/cron\.schedule|policy\s+SET\s+issuance_enabled\s*=\s*true/i);
});
