/**
 * Protected Licence 2 reviewer / approval bridge.
 * Only independently signed, purpose-separated GAME review decisions may
 * trigger the existing atomic database writer. This service never signs.
 * It has no public HTTP action and is not scheduled or deployed to approve.
 */
import {createHmac,timingSafeEqual} from 'node:crypto';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const REF=/^[a-zA-Z0-9._:-]{20,128}$/;
const EVENT=/^[a-zA-Z0-9._:-]{16,128}$/;
const HASH=/^[0-9a-f]{64}$/;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
const approvedMarkets=new Set(['L2-EU']);
const validDay=d=>typeof d==='string'&&DAY.test(d)&&
 Number.isFinite(Date.parse(d+'T00:00:00Z'))&&
 new Date(d+'T00:00:00Z').toISOString().slice(0,10)===d;
const denied=reason=>Object.freeze({status:'REVIEW_AUTHORIZATION_DENIED',
 reason,approvalCommitted:false,chargedNow:false,permitIssuedNow:false,
 flightActivated:false});
const FIELDS=Object.freeze([
 'worldId','applicationId','airlineId','marketCode','requestedLevel',
 'decision','reviewEventId','reviewReference','reviewedGameDay',
 'producerEventId','evidenceSource'
]);
export function licence2IndependentReviewPayload(proof){
 return ['airlinerra-licence2-independent-game-review-v1',
  ...FIELDS.map(name=>String(proof?.[name]??''))].join('\n');
}
export function createLicence2TrustedReviewCommitService({
 database,evidenceReader,verificationSecret
}={}){
 if(typeof database?.connect!=='function')
  throw Error('LICENCE2_PRIVATE_DATABASE_REQUIRED');
 if(typeof evidenceReader?.readSignedReview!=='function')
  throw Error('LICENCE2_INDEPENDENT_REVIEW_EVIDENCE_REQUIRED');
 if(typeof verificationSecret!=='string'||verificationSecret.length<32)
  throw Error('LICENCE2_REVIEW_SECRET_REQUIRED');
 const secret=Buffer.from(verificationSecret,'utf8');
 return Object.freeze({
  async approve({applicationId,airlineId,requestedLevel,reviewedGameDay}={}){
   if(!UUID.test(applicationId||'')||!UUID.test(airlineId||'')||
    !Number.isInteger(requestedLevel)||requestedLevel<1||requestedLevel>4||
    !validDay(reviewedGameDay))
    return denied('INVALID_REVIEW_SCOPE');
   const proof=await evidenceReader.readSignedReview(Object.freeze({
    worldId:1,applicationId,airlineId
   }));
   if(!proof)return denied('SIGNED_REVIEW_NOT_FOUND');
   if(proof.worldId!==1||proof.applicationId!==applicationId||
      proof.airlineId!==airlineId||proof.marketCode!=='L2-EU'||
      !approvedMarkets.has(proof.marketCode)||
      proof.requestedLevel!==requestedLevel||
      proof.reviewedGameDay!==reviewedGameDay||
      proof.decision!=='approve'||!EVENT.test(proof.reviewEventId||'')||
      !REF.test(proof.reviewReference||'')||
      !EVENT.test(proof.producerEventId||'')||
      proof.evidenceSource!=='independent_game_licence_review_v1'||
      !HASH.test(proof.signature||''))return denied('REVIEW_EVIDENCE_INVALID');
   const expected=createHmac('sha256',secret)
    .update(licence2IndependentReviewPayload(proof),'utf8').digest();
   const received=Buffer.from(proof.signature,'hex');
   if(received.length!==expected.length||!timingSafeEqual(received,expected))
    return denied('REVIEW_SIGNATURE_INVALID');
   // DB locks the airline and application, rechecks its own verified game day,
   // 3-day maturity, ownership, eligibility, fee, and cash/ledger.
   const client=await database.connect();
   try{
    const db=await client.query(
     'SELECT airlinerra_game.licence2_approve_application_atomic_v1($1::uuid,$2::text,$3::text) AS result',
     [applicationId,proof.reviewEventId,proof.reviewReference]);
    const result=db.rows?.[0]?.result;
    if(db.rowCount!==1||!result||
     !['LICENCE2_APPROVAL_NOT_RELEASED','LICENCE2_AIRLINE_NOT_FOUND',
       'ALREADY_APPROVED','SUBMITTED_OWNED_APPLICATION_REQUIRED',
       'APPROVAL_PREFLIGHT_BLOCKED','APPROVAL_GAME_DAY_UNVERIFIED',
       'ALREADY_HOLDS_LEVEL','APPROVAL_CASH_LEDGER_BLOCKED',
       'APPROVED_AND_CHARGED_ONCE'].includes(result.status)||
     typeof result.chargedNow!=='boolean'||
     typeof result.permitIssuedNow!=='boolean'||
     result.flightActivated===true||
     (result.status==='APPROVED_AND_CHARGED_ONCE'&&
      (result.chargedNow!==true||result.permitIssuedNow!==true||
       result.applicationId!==applicationId||
       result.reviewEventId!==proof.reviewEventId||
       !Number.isFinite(Number(result.chargedUsd))||
       Number(result.chargedUsd)<=0))||
     (result.status!=='APPROVED_AND_CHARGED_ONCE'&&
      (result.chargedNow!==false||result.permitIssuedNow!==false)))
     throw Error('LICENCE2_UNSAFE_REVIEW_WRITER_RESULT');
    return Object.freeze({
     status:result.status,approvalCommitted:result.status==='APPROVED_AND_CHARGED_ONCE',
     chargedNow:result.chargedNow,permitIssuedNow:result.permitIssuedNow,
     flightActivated:false,
     ...(result.status==='APPROVED_AND_CHARGED_ONCE'?
      {applicationId,chargedUsd:Number(result.chargedUsd)}:{})
    });
   }finally{client.release();}
  }
 });
}
