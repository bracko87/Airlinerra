/**
 * PRIVATE future authorities for trusted execution and commercial finance.
 *
 * NOT deployable as a release or API. Their positive SQL proof producers are
 * deliberately NOT installed; while the World 1 release is paused this
 * module can only report the existing read-only blocked preflight.
 * The production certification sink separately rejects these two types.
 * Never use a client request, arbitrary JSON, or the blocked preflight as
 * a positive source proof. Each authority needs a DIFFERENT private HMAC key.
 */
import {createHmac} from 'node:crypto';
import {section9CertificationPayload}
 from './section9-signed-certification-ingress.mjs';
import {SECTION9_UNRELEASED_SOURCE_SQL}
 from './section9-unreleased-certificate-source-reader.mjs';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH=/^[a-f0-9]{32}$/;
const CATEGORIES=Object.freeze({
 trusted_flight_execution:Object.freeze({
  status:'verified_independent_trusted_flight_execution_source',
  sourceKind:'trusted_flight_operations_engine',
  prefix:'game-trusted-flight-execution-v1-',
  reviewer:'independent-trusted-flight-execution-authority-v1',
  eventPrefix:'flight-exec-cert-v1'
 }),
 commercial_finance:Object.freeze({
  status:'verified_independent_commercial_finance_source',
  sourceKind:'verified_commercial_settlement_engine',
  prefix:'game-commercial-finance-v1-',
  reviewer:'independent-commercial-finance-authority-v1',
  eventPrefix:'commercial-finance-cert-v1'
 })
});
const validDay=d=>typeof d==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(d)&&
 !Number.isNaN(Date.parse(d+'T00:00:00Z'))&&
 new Date(d+'T00:00:00Z').toISOString().slice(0,10)===d&&
 d>='2000-01-01'&&d<='2199-12-01';
const plus28=d=>new Date(Date.parse(d+'T00:00:00Z')+28*86400000)
 .toISOString().slice(0,10);
const BLOCKED='blocked_unreleased_execution_finance_source';
const PREPARED='source_preflight_complete_not_certifiable';
const safeBlocked=(p,r,type)=>p&&p.worldId===1&&
 p.airlineId===r.airlineId&&p.scheduleId===r.scheduleId&&
 p.scheduleVersion===r.scheduleVersion&&p.gameDate===r.gameDate&&
 p.clearanceType===type&&p.readOnly===true&&p.verified===false&&
 p.certificateIssued===false&&p.sourceAuthorityReleased===false&&
 p.flightActivated===false&&p.movementRecorded===false&&
 p.bookingsCreated===false&&p.ledgerPosted===false&&
 [BLOCKED,PREPARED].includes(p.status)&&Array.isArray(p.blockers);
export const SECTION9_FUTURE_CERTIFICATION_SOURCE_SQL=
 Object.freeze({preflight:SECTION9_UNRELEASED_SOURCE_SQL});
// The future source functions must be distinct and have their own
// independently audited SQL rechecks in the certification sink.
// No positive source lookup is implemented or called by this class.
export function createSection9FutureCertificationAuthority({
 database,clearanceType,authoritySecret,certificationIngress
}={}){
 if(typeof database?.connect!=='function')
  throw Error('SECTION9_FUTURE_CERTIFICATION_PRIVATE_DB_REQUIRED');
 if(!Object.hasOwn(CATEGORIES,clearanceType||''))
  throw Error('SECTION9_FUTURE_CERTIFICATION_UNSUPPORTED_TYPE');
 if(typeof authoritySecret!=='string'||authoritySecret.length<32)
  throw Error('SECTION9_FUTURE_CERTIFICATION_INDEPENDENT_KEY_REQUIRED');
 if(certificationIngress?.clearanceType!==clearanceType||
  typeof certificationIngress?.acceptSignedDecision!=='function')
  throw Error('SECTION9_FUTURE_CERTIFICATION_MATCHING_INGRESS_REQUIRED');
 // Retain the key in an isolated instance for eventual independently
 // evidenced issuance. NEVER use it to sign a preflight-only result.
 const secret=Buffer.from(authoritySecret,'utf8');
 const authority=CATEGORIES[clearanceType];
 return Object.freeze({
  clearanceType,
  async inspectForCertification({
   airlineId,scheduleId,scheduleVersion,gameDate
  }={}){
   if(!UUID.test(airlineId||'')||!UUID.test(scheduleId||'')||
    !Number.isInteger(scheduleVersion)||scheduleVersion<1||
    !validDay(gameDate)||gameDate>'2199-12-01')
    throw Error('SECTION9_FUTURE_CERTIFICATION_INVALID_REQUEST');
   const request={airlineId,scheduleId,scheduleVersion,gameDate};
   const client=await database.connect();
   let proof;
   try{
    const query=await client.query(SECTION9_FUTURE_CERTIFICATION_SOURCE_SQL.preflight,
     [airlineId,scheduleId,scheduleVersion,gameDate,clearanceType]);
    if(query?.rowCount!==1||!query.rows?.[0]?.result)
     throw Error('SECTION9_FUTURE_CERTIFICATION_SOURCE_NOT_AVAILABLE');
    proof=query.rows[0].result;
   }finally{client.release();}
   if(!safeBlocked(proof,request,clearanceType))
    throw Error('SECTION9_FUTURE_CERTIFICATION_SOURCE_NOT_INDEPENDENTLY_RELEASED');
   return Object.freeze({
    status:proof.status,clearanceType,scheduleId,
    blockers:Object.freeze([...proof.blockers]),
    certificateIssued:false,sourceAuthorityReleased:false,
    flightActivated:false,bookingsCreated:false,ledgerPosted:false
   });
  }
 });
}
export const SECTION9_FUTURE_CERTIFICATION_TYPES=Object.freeze(Object.keys(CATEGORIES));
