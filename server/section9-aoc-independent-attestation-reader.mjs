/**
 * Private read-only adapter for independent AOC safety attestations.
 * No signer, no completion writer, no submission endpoint, and no producer.
 * The independent game safety engine must eventually create real signed
 * records only after completed work; this reader never synthesizes them.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REF=/^[A-Za-z0-9._:-]{12,160}$/;
export const AOC_INDEPENDENT_ATTESTATION_SQL=Object.freeze({
 read:`SELECT world_id::int AS "worldId", airline_id::text AS "airlineId",
  task_id::text AS "taskId",event_id AS "eventId",
  work_kind AS "workKind",receipt_reference AS "receiptReference",
  to_char(completed_game_day,'YYYY-MM-DD') AS "completedGameDay",
  paid_ledger_entry_id::text AS "paidLedgerEntryId",
  paid_amount_usd_cents::text AS "amountCentsText",
  producer_event_id AS "producerEventId",
  producer_reference AS "producerReference",
  evidence_source AS "evidenceSource",signature
 FROM airlinerra_game.section9_aoc_independent_correction_attestations_v1
 WHERE world_id=1 AND airline_id=$1::uuid AND task_id=$2::uuid
  AND receipt_reference=$3::text LIMIT 2`
});
export function createAocIndependentAttestationReader({database}={}){
 if(typeof database?.connect!=='function')
  throw Error('AOC_PRIVATE_INDEPENDENT_ATTESTATION_DB_REQUIRED');
 return Object.freeze({
  async readSignedCorrectionReceipt({worldId,airlineId,taskId,receiptReference}={}){
   if(worldId!==1||!UUID.test(airlineId||'')||
    !UUID.test(taskId||'')||!REF.test(receiptReference||''))
    throw Error('AOC_INVALID_INDEPENDENT_ATTESTATION_LOOKUP');
   const db=await database.connect();
   try{
    const result=await db.query(AOC_INDEPENDENT_ATTESTATION_SQL.read,
     [airlineId,taskId,receiptReference]);
    if(result.rowCount===0)return null;
    if(result.rowCount!==1||!result.rows?.[0])
     throw Error('AOC_AMBIGUOUS_INDEPENDENT_ATTESTATION');
    const row=result.rows[0];
    const cents=Number(row.amountCentsText);
    if(row.worldId!==1||row.airlineId!==airlineId||
     row.taskId!==taskId||row.receiptReference!==receiptReference||
     !Number.isSafeInteger(cents)||cents<=0)
     throw Error('AOC_INCONSISTENT_INDEPENDENT_ATTESTATION');
    const {amountCentsText,...fields}=row;
    return Object.freeze({...fields,paidAmountUsdCents:cents});
   }finally{db.release();}
  }
 });
}
