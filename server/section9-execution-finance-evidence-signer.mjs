/**
 * PRIVATE, NOT PUBLICLY ROUTED, independently keyed source-fingerprint
 * certification signers. Evidence comes only from the canonical PostgreSQL
 * snapshot function, never a browser request or unsigned caller JSON.
 *
 * The live certification sink still rejects BOTH types until an independent
 * same-transaction verification is installed and accepted. Consequently
 * a production call cannot issue a certificate merely by holding a key.
 */
import {createHmac} from 'node:crypto';
import {section9CertificationPayload} from './section9-signed-certification-ingress.mjs';
import {SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL}
 from './section9-execution-finance-snapshot-reader.mjs';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HEX=/^[a-f0-9]{32}$/;
const TYPES=Object.freeze({
 trusted_flight_execution:Object.freeze({
  sourceKind:'trusted_flight_operations_engine',
  reviewer:'independent-trusted-flight-execution-authority-v1',
  eventPrefix:'flight-exec-cert-v1'
 }),
 commercial_finance:Object.freeze({
  sourceKind:'verified_commercial_settlement_engine',
  reviewer:'independent-commercial-finance-authority-v1',
  eventPrefix:'commercial-finance-cert-v1'
 })
});
const validDay=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&
 Number.isFinite(Date.parse(s+'T00:00:00Z'))&&
 new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s&&
 s>='2000-01-01'&&s<='2199-12-01';
const plus28=s=>new Date(Date.parse(s+'T00:00:00Z')+28*86400000)
 .toISOString().slice(0,10);
const nonMutating=p=>p?.flightActivated===false&&
 p?.movementRecorded===false&&p?.bookingsCreated===false&&
 p?.ledgerPosted===false&&p?.certificateIssued===false&&
 p?.sourceAuthorityReleased===false&&p?.verified===false&&p?.readOnly===true;
export function createSection9ExecutionFinanceEvidenceSigner({
 database,clearanceType,authoritySecret,certificationIngress
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_EVIDENCE_SIGNER_PRIVATE_DATABASE_REQUIRED');
 if(!Object.hasOwn(TYPES,clearanceType||''))
  throw Error('SECTION9_EVIDENCE_SIGNER_INVALID_TYPE');
 if(typeof authoritySecret!=='string'||authoritySecret.length<32)
  throw Error('SECTION9_EVIDENCE_SIGNER_PRIVATE_KEY_REQUIRED');
 if(certificationIngress?.clearanceType!==clearanceType||
  typeof certificationIngress?.acceptSignedDecision!=='function')
  throw Error('SECTION9_EVIDENCE_SIGNER_MATCHING_INGRESS_REQUIRED');
 const secret=Buffer.from(authoritySecret,'utf8');
 const config=TYPES[clearanceType];
 return Object.freeze({
  clearanceType,
  async verifyAndCertify({airlineId,scheduleId,scheduleVersion,gameDate}={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
    !Number.isInteger(scheduleVersion)||scheduleVersion<1||!validDay(gameDate)||
    gameDate>'2199-12-01')
    throw Error('SECTION9_EVIDENCE_SIGNER_INVALID_REQUEST');
   const client=await database.connect();
   let proof;
   try{
    const r=await client.query(SECTION9_EXECUTION_FINANCE_SNAPSHOT_SQL,
      [airlineId,scheduleId,scheduleVersion,gameDate,clearanceType]);
    if(r?.rowCount!==1||!r.rows?.[0]?.result)
     throw Error('SECTION9_EVIDENCE_SIGNER_SOURCE_UNAVAILABLE');
    proof=r.rows[0].result;
   }finally{client.release();}
   // The source snapshot is a CANDIDATE. Never sign blocked / stale scope.
   if(!nonMutating(proof)||proof.worldId!==1||
    proof.airlineId!==airlineId||proof.scheduleId!==scheduleId||
    proof.scheduleVersion!==scheduleVersion||proof.gameDate!==gameDate||
    proof.clearanceType!==clearanceType||
    proof.snapshotVersion!=='SECTION9_INDEPENDENT_SOURCE_SNAPSHOT_CANDIDATE_V1'||
    !Array.isArray(proof.blockers))
    throw Error('SECTION9_EVIDENCE_SIGNER_UNTRUSTED_SOURCE');
   if(proof.status==='blocked_unreleased_execution_finance_source_snapshot'&&
    proof.candidateReady===false&&proof.sourceFingerprint===null&&
    proof.sourceReference===null){
    return Object.freeze({
     status:'blocked_unreleased_execution_finance_source_snapshot',
     scheduleId,clearanceType,blockers:[...proof.blockers],
     certificateIssued:false,flightActivated:false,ledgerPosted:false
    });
   }
   if(proof.status!=='source_snapshot_candidate_not_authorized'||
    proof.candidateReady!==true||proof.blockers.length!==0||
    !HEX.test(proof.sourceFingerprint||'')||
    proof.sourceReference!==
      'candidate-execution-finance-v1-'+proof.sourceFingerprint)
    throw Error('SECTION9_EVIDENCE_SIGNER_UNTRUSTED_SOURCE');
   const eventId=[
    config.eventPrefix,scheduleId.replaceAll('-',''),
    String(scheduleVersion),gameDate.replaceAll('-',''),
    proof.sourceFingerprint.slice(0,12)
   ].join('.');
   const event={
    worldId:1,airlineId,scheduleId,scheduleVersion,
    clearanceType,sourceKind:config.sourceKind,action:'certify',
    eventId,sourceReference:proof.sourceReference,
    reviewerReference:config.reviewer,
    validFromGameDate:gameDate,validToGameDate:plus28(gameDate)
   };
   const signature=createHmac('sha256',secret)
    .update(section9CertificationPayload(event),'utf8').digest('hex');
   // In live World 1 this database sink currently refuses both types.
   // It must never be bypassed or caught as a successful certificate.
   const receipt=await certificationIngress.acceptSignedDecision(
    Object.freeze({...event,signature}));
   if(!receipt||receipt.eventId!==eventId||
    receipt.scheduleId!==scheduleId||
    receipt.flightActivated!==false||receipt.movementRecorded!==false||
    receipt.bookingsCreated!==false||receipt.ledgerPosted!==false||
    !['certification_event_recorded','certification_event_replayed']
     .includes(receipt.status))
    throw Error('SECTION9_EVIDENCE_SIGNER_CERTIFICATE_NOT_CONFIRMED');
   return Object.freeze({
    status:receipt.status,clearanceType,scheduleId,
    certificateIssued:receipt.status==='certification_event_recorded',
    replayed:receipt.status==='certification_event_replayed',
    flightActivated:false,movementRecorded:false,
    bookingsCreated:false,ledgerPosted:false
   });
  }
 });
}
