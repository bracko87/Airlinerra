import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createSection9IndependentOperationEvidenceReader,
 SECTION9_INDEPENDENT_EVIDENCE_SQL}
 from '../server/section9-independent-operation-evidence-reader.mjs';
const read=path=>readFile(new URL('../'+path,import.meta.url),'utf8');
const airlineId='11111111-1111-4111-8111-111111111111',
 aircraftInventoryId='22222222-2222-4222-8222-222222222222',
 scheduleId='33333333-3333-4333-8333-333333333333';
const ids={
 worldId:1,airlineId,aircraftInventoryId,
 eventId:'operate-v1.'+scheduleId.replaceAll('-','')+'.20261111.3.arrived',
 flightOccurrenceId:scheduleId+':2026-11-11:3'
};
const row=()=>({
 ...ids,scheduleId,scheduleVersion:1,
 flightLocalDate:'2026-11-11',weeklyEntry:3,phase:'arrived',
 scheduledEventUtc:'2026-11-11T09:00:00Z',
 actualEventUtc:'2026-11-11T09:00:30Z',
 operationReference:'flight-engine-proof-123',
 certifiedClockReceiptId:'signed-world1-day-2026-11-11',
 evidenceSource:'independent_trusted_flight_engine',
 signature:'f'.repeat(64)
});
test('only owner-and-occurrence scoped SELECT, never source of flight evidence',async()=>{
 const sql=SECTION9_INDEPENDENT_EVIDENCE_SQL.read;
 assert.match(sql,/select world_id/i);
 assert.match(sql,/where world_id=1 and airline_id=\$1::uuid/);
 assert.match(sql,/aircraft_inventory_id=\$2::uuid/);
 assert.match(sql,/event_id=\$3::text and flight_occurrence_id=\$4::text/);
 assert.doesNotMatch(sql,/\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bTRUNCATE\b/i);
 const migration=await read('supabase/migrations/20261110235955_section9_independent_operated_flight_evidence_v1.sql');
 assert.match(migration,/row level security/);
 assert.match(migration,/unique\(airline_id,flight_occurrence_id,phase\)/);
 assert.match(migration,/primary key/);
 assert.match(migration,/revoke insert,update,delete,truncate,references,trigger/);
 assert.match(migration,/grant select/);
});
test('matching independent attestation can be read once; reader cannot sign it',async()=>{
 let calls=0,release=0;
 const database={connect:async()=>({
  query:async(sql,args)=>{
   calls++;
   assert.equal(sql,SECTION9_INDEPENDENT_EVIDENCE_SQL.read);
   assert.deepEqual(args,[
    airlineId,aircraftInventoryId,ids.eventId,ids.flightOccurrenceId
   ]);
   return {rowCount:1,rows:[row()]};
  },
  release(){release++}
 })};
 const reader=createSection9IndependentOperationEvidenceReader({database});
 const proof=await reader.readIndependentOperationAttestation(ids);
 assert.deepEqual(proof,row());
 assert.equal(calls,1);assert.equal(release,1);
 assert.equal(Object.isFrozen(proof),true);
});
test('missing proof returns null, cross-company rows are rejected',async()=>{
 const none=createSection9IndependentOperationEvidenceReader({
  database:{connect:async()=>({
   query:async()=>({rowCount:0,rows:[]}),release(){}
  })}
 });
 assert.equal(await none.readIndependentOperationAttestation(ids),null);
 const forged=createSection9IndependentOperationEvidenceReader({
  database:{connect:async()=>({
   query:async()=>({rowCount:1,rows:[{...row(),airlineId:'foreign'}]}),
   release(){}
  })}
 });
 await assert.rejects(()=>forged.readIndependentOperationAttestation(ids),
  /INCONSISTENT_PRIVATE_OPERATION_EVIDENCE/);
});
test('missing DB and invalid user-supplied identity both fail closed',async()=>{
 assert.throws(()=>createSection9IndependentOperationEvidenceReader(),
  /PRIVATE_OPERATION_EVIDENCE_DATABASE_REQUIRED/);
 const reader=createSection9IndependentOperationEvidenceReader({
  database:{connect:async()=>{throw Error('UNEXPECTED_DB_CONNECT')}}
 });
 await assert.rejects(
  ()=>reader.readIndependentOperationAttestation({...ids,worldId:2}),
  /INVALID_PRIVATE_OPERATION_EVIDENCE_IDENTITY/
 );
});
