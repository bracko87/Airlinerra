/**
 * Private AOC GAME inspection-evidence publishing bridge.
 * Expects a separately signed completed service attestation from a trusted
 * game worker. Verifies the signature before the postgres-only publisher
 * independently checks a paid task and completed game inspection receipt.
 * It NEVER manufactures events or signs anything.
 */
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REF=/^[A-Za-z0-9._:-]{12,160}$/;
const DIGEST=/^[a-f0-9]{64}$/;
export const AOC_SIGNED_ATTESTATION_PUBLISH_SQL=
 'SELECT airlinerra_game.section9_publish_verified_aoc_signed_attestation_v1('+
 '$1::uuid,$2::uuid,$3::text,$4::text,$5::text,$6::date,'+
 '$7::bigint,$8::bigint,$9::text,$10::text,$11::text,$12::text) AS result';
const denied=(reason)=>Object.freeze({status:'AOC_ATTESTATION_NOT_PUBLISHED',
 reason,published:false,charged:false,incidentResolved:false,
 certificateIssued:false,flightActivated:false});
export function createAocSignedAttestationPublisher({verifier,database}={}){
 if(typeof verifier?.verify!=='function'||typeof database?.connect!=='function')
  throw Error('AOC_SIGNED_PUBLISHER_PRIVATE_AUTHORITIES_REQUIRED');
 return Object.freeze({
  async publish(request){
   const proof=await verifier.verify(request);
   if(proof?.verified!==true)
    return denied(proof?.reason??'SIGNED_INSPECTION_NOT_VERIFIED');
   if(!UUID.test(proof.airlineId||'')||!UUID.test(proof.taskId||'')||
    proof.airlineId!==request?.airlineId||
    proof.taskId!==request?.taskId||
    proof.eventId!==request?.eventId||proof.workKind!==request?.workKind||
    proof.receiptReference!==request?.receiptReference||
    proof.completedGameDay!==request?.completedGameDay||
    proof.paidLedgerEntryId!==String(request?.paidLedgerEntryId)||
    proof.paidAmountUsdCents!==request?.paidAmountUsdCents||
    !Number.isSafeInteger(proof.paidAmountUsdCents)||proof.paidAmountUsdCents<=0||
    !REF.test(proof.producerEventId||'')||
    !REF.test(proof.producerReference||'')||
    !DIGEST.test(proof.signature||'')||
    !DIGEST.test(proof.signedPayloadSha256||'')||
    proof.evidenceSource!=='independent_trusted_game_safety_producer'||
    proof.feeCharged!==false||proof.incidentResolved!==false||
    proof.certificateIssued!==false||proof.flightActivated!==false)
    throw Error('AOC_UNSAFE_SIGNED_INSPECTION_PROOF');
   const db=await database.connect();
   try{
    const r=await db.query(AOC_SIGNED_ATTESTATION_PUBLISH_SQL,[
     proof.airlineId,proof.taskId,proof.eventId,proof.workKind,
     proof.receiptReference,proof.completedGameDay,proof.paidLedgerEntryId,
     proof.paidAmountUsdCents,proof.producerEventId,proof.producerReference,
     proof.signature,proof.signedPayloadSha256
    ]);
    const out=r.rows?.[0]?.result;
    if(r.rowCount!==1||!out||![
      'AOC_INDEPENDENT_PRODUCER_NOT_RELEASED',
      'AOC_VERIFIED_GAME_DAY_NOT_READY',
      'AOC_COMPLETED_GAME_INSPECTION_NOT_VERIFIED',
      'AOC_ATTESTATION_REPLAY','AOC_SIGNED_ATTESTATION_PUBLISHED'
     ].includes(out.status)||
     typeof out.published!=='boolean'||out.charged!==false||
     out.incidentResolved!==false||out.certificateIssued===true||
     out.flightActivated===true||
     (out.status==='AOC_SIGNED_ATTESTATION_PUBLISHED')!==out.published)
     throw Error('AOC_UNSAFE_ATTESTATION_PUBLISH_RESULT');
    return Object.freeze({
     status:out.status,published:out.published,
     charged:false,incidentResolved:false,certificateIssued:false,
     flightActivated:false
    });
   }finally{db.release();}
  }
 });
}
