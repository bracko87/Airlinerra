import test from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {createSection9IndependentGamePhaseAttestor,
 SECTION9_GAME_PHASE_ATTESTATION_SQL} from '../server/section9-independent-game-phase-attestor.mjs';
import {independentOperationAttestationPayload} from
 '../server/section9-independent-flight-operation-authorizer.mjs';
const airlineId='11111111-1111-4111-8111-111111111111';
const aircraftId='22222222-2222-4222-8222-222222222222';
const scheduleId='33333333-3333-4333-8333-333333333333';
const gameDate='2026-11-11';
const eventId='operate-v1.'+scheduleId.replaceAll('-','')+'.20261111.1.departed';
const request={airlineId,aircraftId,gameDate,eventId};
const secret='independent-attestation-test-secret-value-never-use-production';
const event={worldId:1,airlineId,aircraftInventoryId:aircraftId,
 scheduleId,scheduleVersion:1,flightOccurrenceId:scheduleId+':'+gameDate+':1',
 flightLocalDate:gameDate,weeklyEntry:1,phase:'departed',eventId,
 scheduledEventUtc:gameDate+'T10:00:00Z',activatedAndCapacityVerified:true};
const approval={status:'independent_game_phase_authorized',
 verified:true,readOnly:true,movementRecorded:false,bookingsCreated:false,
 ledgerPosted:false,worldId:1,approvedClearances:6,event,
 actualEventUtc:gameDate+'T10:00:04Z',
 operationReference:'game-exec-v1.'+'a'.repeat(32),
 certifiedClockReceiptId:'horizon-world1-day-2026-11-11'};
function harness(decision=approval,insertRows=[{event_id:eventId}]){
 const calls=[];let released=0;
 const database={async connect(){return{
  async query(sql,args=[]){calls.push({sql,args});
   if(sql==='BEGIN'||sql==='COMMIT'||sql==='ROLLBACK')
    return {rowCount:0,rows:[]};
   if(sql===SECTION9_GAME_PHASE_ATTESTATION_SQL.gate)
    return {rowCount:1,rows:[{result:decision}]};
   if(sql===SECTION9_GAME_PHASE_ATTESTATION_SQL.insert)
    return {rowCount:insertRows.length,rows:insertRows};
   throw Error('Unexpected SQL '+sql);
  },
  release(){released++;}
 };}};
 return {worker:createSection9IndependentGamePhaseAttestor({
  database,independentAttestationSecret:secret}),calls,released:()=>released};
}
test('due certified phase signs independently and stores one immutable proof',async()=>{
 const m=harness();const r=await m.worker.attestDuePhase(request);
 assert.equal(r.status,'independent_phase_attestation_recorded');
 assert.equal(r.movementRecorded,false);
 assert.equal(m.released(),1);
 assert.deepEqual(m.calls.map(x=>x.sql),['BEGIN',
  SECTION9_GAME_PHASE_ATTESTATION_SQL.gate,
  SECTION9_GAME_PHASE_ATTESTATION_SQL.insert,'COMMIT']);
 const args=m.calls[2].args;
 const expected={worldId:args[0],airlineId:args[1],aircraftInventoryId:args[2],
 scheduleId:args[3],scheduleVersion:args[4],flightOccurrenceId:args[5],
 flightLocalDate:args[6],weeklyEntry:args[7],phase:args[8],
 eventId:args[9],scheduledEventUtc:args[10],actualEventUtc:args[11],
 operationReference:args[12],certifiedClockReceiptId:args[13],
 evidenceSource:args[14]};
 const verified=createHmac('sha256',secret)
 .update(independentOperationAttestationPayload(expected)).digest('hex');
 assert.equal(args[15],verified);
});
test('disabled operational release never creates an attestation',async()=>{
 const m=harness({status:'flight_execution_not_released',verified:false,
  readOnly:true,movementRecorded:false,bookingsCreated:false,ledgerPosted:false});
 const r=await m.worker.attestDuePhase(request);
 assert.equal(r.attestationRecorded,false);
 assert.deepEqual(m.calls.map(x=>x.sql),['BEGIN',
  SECTION9_GAME_PHASE_ATTESTATION_SQL.gate,'ROLLBACK']);
});
test('future date, mismatched identity and false release rejected',async()=>{
 for(const decision of [
  {...approval,actualEventUtc:gameDate+'T09:59:59Z'},
  {...approval,approvedClearances:5},
  {...approval,event:{...event,airlineId:aircraftId}},
  {...approval,event:{...event,activatedAndCapacityVerified:false}},
  {...approval,event:{...event,phase:'arrived'}},
  {...approval,ledgerPosted:true}
 ]){
  const m=harness(decision);
  await assert.rejects(m.worker.attestDuePhase(request),/ATTESTATION_FAILED/);
  assert.equal(m.calls.some(x=>x.sql===SECTION9_GAME_PHASE_ATTESTATION_SQL.insert),false);
  assert.equal(m.calls.at(-1).sql,'ROLLBACK');
 }
});
test('invalid request never connects to database',async()=>{
 const m=harness();
 for(const bad of [{...request,eventId:'fake'}, {...request,aircraftId:'bad'},
  {...request,gameDate:'2026-11-12'}])
  await assert.rejects(m.worker.attestDuePhase(bad),/INVALID_GAME_PHASE_ATTEST_REQUEST/);
 assert.equal(m.calls.length,0);
});
