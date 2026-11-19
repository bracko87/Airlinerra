/**
 * Private AOC corrective completion boundary.
 * A signed external receipt is verified before the single trusted SQL
 * transaction validates payment, task identity and append-only provenance.
 * No signer, no public endpoint, no release switch changes.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const denied=reason=>Object.freeze({status:'AOC_CORRECTION_NOT_VERIFIED',reason,
 staged:false,charged:false,incidentResolved:false,
 certificateIssued:false,flightActivated:false});
export const AOC_VERIFIED_CORRECTION_COMMIT_SQL=
 'SELECT airlinerra_game.section9_stage_independently_verified_aoc_correction_v1('+
 '$1::uuid,$2::uuid,$3::text,$4::text,$5::text,$6::date,'+
 '$7::bigint,$8::numeric,$9::text,$10::text) AS result';
export function createAocVerifiedCorrectionCommitService({verifier,database}={}){
 if(typeof verifier?.verify!=='function'||typeof database?.connect!=='function')
  throw Error('AOC_PRIVATE_CORRECTION_AUTHORITIES_REQUIRED');
 return Object.freeze({
  async commit(request){
   const proof=await verifier.verify(request);
   if(proof?.verified!==true)return denied(proof?.reason??'INDEPENDENT_EVIDENCE_UNAVAILABLE');
   if(!UUID.test(proof.airlineId||'')||!UUID.test(proof.taskId||'')||
      proof.airlineId!==request?.airlineId||proof.taskId!==request?.taskId||
      proof.eventId!==request?.eventId||proof.receiptReference!==request?.receiptReference||
      proof.completedGameDay!==request?.completedGameDay||
      proof.paidLedgerEntryId!==String(request?.paidLedgerEntryId)||
      proof.paidAmountUsdCents!==request?.paidAmountUsdCents||
      !/^[a-zA-Z0-9._:-]{12,160}$/.test(proof.producerEventId||'')||
      !/^[a-f0-9]{64}$/.test(proof.signedPayloadSha256||'')||
      proof.evidenceSource!=='independent_trusted_game_safety_producer'||
      proof.feeCharged!==false||proof.incidentResolved!==false||
      proof.certificateIssued!==false||proof.flightActivated!==false)
    throw Error('AOC_UNSAFE_VERIFIED_CORRECTION_PROOF');
   const amountUsd=proof.paidAmountUsdCents/100;
   if(!Number.isSafeInteger(proof.paidAmountUsdCents)||
      proof.paidAmountUsdCents<=0||
      !Number.isSafeInteger(Math.round(amountUsd*100)))
    throw Error('AOC_UNSAFE_CORRECTION_AMOUNT');
   const db=await database.connect();
   try{
    const result=await db.query(AOC_VERIFIED_CORRECTION_COMMIT_SQL,[
     proof.airlineId,proof.taskId,proof.eventId,request.workKind,
     proof.receiptReference,proof.completedGameDay,proof.paidLedgerEntryId,
     amountUsd,proof.producerEventId,proof.signedPayloadSha256
    ]);
    const out=result.rows?.[0]?.result;
    if(result.rowCount!==1||!out||
       !['INDEPENDENT_AOC_PRODUCER_NOT_RELEASED',
         'AOC_CORRECTION_VERIFIED_GAME_DAY_MISSING',
         'AOC_CORRECTION_EVIDENCE_MISMATCH',
         'AOC_CORRECTION_PROOF_REPLAY',
         'INDEPENDENT_AOC_CORRECTION_STAGED'].includes(out.status)||
       typeof out.staged!=='boolean'||out.charged!==false||
       out.incidentResolved!==false||out.certificateIssued===true||
       out.flightActivated===true||
       (out.status==='INDEPENDENT_AOC_CORRECTION_STAGED')!==out.staged)
      throw Error('AOC_UNSAFE_CORRECTION_DB_RESULT');
    return Object.freeze({status:out.status,staged:out.staged,
     charged:false,incidentResolved:false,
     certificateIssued:false,flightActivated:false});
   }finally{db.release();}
  }
 });
}
