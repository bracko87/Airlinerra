/**
 * Private AOC GAME inspection processor. NOT an HTTP route or a signer exposed
 * to the browser. The game engine must have written a paid, completed inspection
 * receipt after a verified tick before this process can sign any evidence.
 * No release flags are changed here.
 */
import {createHmac} from 'node:crypto';
import {createIndependentAocCorrectionVerifier,aocCorrectionAttestationPayload} from './section9-independent-aoc-correction-verifier.mjs';
import {createAocSignedAttestationPublisher} from './section9-aoc-signed-attestation-publisher.mjs';
import {createAocIndependentAttestationReader} from './section9-aoc-independent-attestation-reader.mjs';
import {createAocVerifiedCorrectionCommitService} from './section9-aoc-verified-correction-commit-service.mjs';

export const AOC_INSPECTION_WORKER_SQL=Object.freeze({
 completeDue:'SELECT airlinerra_game.section9_complete_due_aoc_game_inspections_v1($1::integer) AS result',
 ready:`SELECT j.airline_id::text AS "airlineId",
 j.task_id::text AS "taskId",j.event_id AS "eventId",
 j.work_kind AS "workKind",
 'aoc-game-inspection-receipt-v1-'||j.task_id::text AS "receiptReference",
 to_char(s.completed_game_day,'YYYY-MM-DD') AS "completedGameDay",
 j.paid_ledger_entry_id::text AS "paidLedgerEntryId",
 (j.quote_usd*100)::bigint::text AS "amountCentsText",
 s.service_event_id AS "producerEventId",
 s.engine_completion_reference AS "producerReference"
 FROM airlinerra_game.section9_aoc_inspection_game_jobs_v1 j
 JOIN airlinerra_game.section9_aoc_game_inspection_service_receipts_v1 s
  ON s.task_id=j.task_id AND s.airline_id=j.airline_id
  AND s.event_id=j.event_id AND s.work_kind=j.work_kind
  AND s.paid_ledger_entry_id=j.paid_ledger_entry_id
  AND s.paid_amount_usd_cents=j.quote_usd*100
  AND s.completed_game_day=j.completed_game_day
 JOIN airlinerra_game.section9_aoc_corrective_tasks_v1 t
  ON t.task_id=j.task_id AND t.airline_id=j.airline_id
  AND t.status='paid' AND t.paid_ledger_entry_id=j.paid_ledger_entry_id
 JOIN airlinerra_game.section9_aoc_safety_incidents_v1 i
  ON i.event_id=j.event_id AND i.airline_id=j.airline_id
  AND i.resolved_game_day IS NULL
 JOIN airlinerra_game.airline_ledger l
  ON l.id=j.paid_ledger_entry_id AND l.airline_id=j.airline_id
  AND l.entry_kind='EXPENSE' AND l.amount_usd=-j.quote_usd
 WHERE j.status='completed'
  AND j.completed_engine_tick_ref IS NOT NULL
  AND s.completed_by='trusted_aoc_game_inspection_worker_v1'
  AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_verified_correction_proofs_v1 v
   WHERE v.task_id=j.task_id)
 ORDER BY j.completed_game_day,j.task_id LIMIT $1::integer`
});
function toRequest(row){
 const cents=Number(row?.amountCentsText);
 if(!Number.isSafeInteger(cents)||cents<=0)throw Error('AOC_GAME_INSPECTION_AMOUNT_NOT_SAFE');
 if(!row?.airlineId||!row?.taskId||!row?.eventId||
    !row?.workKind||!row?.receiptReference||!row?.completedGameDay||
    !row?.paidLedgerEntryId||!row?.producerEventId||!row?.producerReference)
  throw Error('AOC_GAME_INSPECTION_RECEIPT_MISSING_FIELDS');
 return {airlineId:row.airlineId,taskId:row.taskId,eventId:row.eventId,
  workKind:row.workKind,receiptReference:row.receiptReference,
  completedGameDay:row.completedGameDay,paidLedgerEntryId:row.paidLedgerEntryId,
  paidAmountUsdCents:cents};
}
export function createAocGameInspectionProcessor({database,signingSecret}={}){
 if(typeof database?.connect!=='function')throw Error('AOC_PRIVATE_DATABASE_REQUIRED');
 if(typeof signingSecret!=='string'||signingSecret.length<32)
  throw Error('AOC_GAME_INSPECTION_SIGNING_SECRET_REQUIRED');
 return Object.freeze({
  async run({limit=10}={}){
   if(!Number.isInteger(limit)||limit<1||limit>25)throw Error('AOC_INSPECTION_BATCH_LIMIT_INVALID');
   const client=await database.connect();
   let engineResult;
   let rows;
   try{
    const r=await client.query(AOC_INSPECTION_WORKER_SQL.completeDue,[limit]);
    engineResult=r.rows?.[0]?.result;
    if(r.rowCount!==1||!engineResult||
     !['AOC_INSPECTION_WORKER_NOT_RELEASED','AOC_INSPECTION_WORKER_CLOCK_NOT_VERIFIED',
       'AOC_INSPECTION_WORKER_TICK_NOT_VERIFIED','AOC_INSPECTION_WORKER_PROCESSED'].includes(engineResult.status)||
     engineResult.charged!==false||engineResult.flightActivated!==false||
     !Number.isInteger(engineResult.completed)||engineResult.completed<0)
      throw Error('AOC_INSPECTION_ENGINE_UNSAFE_RESULT');
    if(engineResult.status!=='AOC_INSPECTION_WORKER_PROCESSED')
     return Object.freeze({status:engineResult.status,completed:0,
      published:0,resolved:0,charged:false,licencesIssued:0,flightActivated:false});
    const q=await client.query(AOC_INSPECTION_WORKER_SQL.ready,[limit]);
    if(!Array.isArray(q.rows)||q.rows.length>limit)
     throw Error('AOC_INSPECTION_PENDING_RECEIPTS_UNVERIFIED');
    rows=q.rows;
   }finally{client.release();}
   const storedReader=createAocIndependentAttestationReader({database});
   const verifiedStored=createIndependentAocCorrectionVerifier({
    evidenceSource:storedReader,verificationSecret:signingSecret});
   const completer=createAocVerifiedCorrectionCommitService({
    verifier:verifiedStored,database});
   let published=0,resolved=0,blocked=0;
   for(const row of rows){
    const request=toRequest(row);
    const raw={worldId:1,...request,
     producerEventId:row.producerEventId,
     producerReference:row.producerReference,
     evidenceSource:'independent_trusted_game_safety_producer'};
    const signature=createHmac('sha256',signingSecret)
     .update(aocCorrectionAttestationPayload(raw),'utf8').digest('hex');
    const signed={...raw,signature};
    const verifier=createIndependentAocCorrectionVerifier({
     verificationSecret:signingSecret,
     evidenceSource:{readSignedCorrectionReceipt:async()=>signed}
    });
    const publisher=createAocSignedAttestationPublisher({verifier,database});
    const result=await publisher.publish(request);
    if(result.published)published++;
    if(!result.published&&result.status!=='AOC_ATTESTATION_REPLAY'){
     blocked++;continue;
    }
    const outcome=await completer.commit(request);
    if(outcome.staged)resolved++;
    else if(outcome.status!=='AOC_CORRECTION_PROOF_REPLAY')blocked++;
   }
   return Object.freeze({status:'AOC_INSPECTION_PRIVATE_BATCH_CHECKED',
    engineCompleted:engineResult.completed,published,resolved,blocked,
    charged:false,licencesIssued:0,flightActivated:false});
  }
 });
}
