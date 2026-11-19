/**
 * Private game-engine Licence 2 EU reviewer.
 * It signs only applications that pass the independent, verified game-day
 * eligibility preflight. The atomic PostgreSQL writer still rechecks all
 * balances, application maturity, exact fee and permit state under locks.
 * No public endpoint, no client-supplied review, no release-policy updates.
 */
import {createHmac} from 'node:crypto';
import {createLicence2TrustedReviewCommitService,licence2IndependentReviewPayload}
 from './licence2-independent-review-commit-service.mjs';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DAY=/^\d{4}-\d{2}-\d{2}$/;
export const LICENCE2_PRIVATE_GAME_REVIEW_SQL=Object.freeze({
 queue:`WITH verified AS (
  SELECT airlinerra_game.section9_verified_permission_game_day_v1() AS game_day
 )
 SELECT a.application_id::text AS "applicationId",
  a.airline_id::text AS "airlineId",
  a.requested_level::int AS "requestedLevel",
  to_char(v.game_day,'YYYY-MM-DD') AS "reviewedGameDay",
  tick.engine_event_id AS "gameTickEventId",
  airlinerra_game.licence2_approval_preflight_v1(a.application_id) AS preflight
 FROM airlinerra_game.licence2_market_applications_v1 a
 JOIN verified v ON v.game_day IS NOT NULL
 JOIN airlinerra_game.section9_verified_game_tick_receipts_v1 tick
  ON tick.world_id=1 AND tick.game_date=v.game_day
 JOIN airlinerra_game.licence2_market_policy_v1 m
  ON m.market_code=a.market_code AND m.issuance_enabled=true
 JOIN airlinerra_game.licence2_approval_release_v1 r
  ON r.world_id=1 AND r.approval_enabled=true
  AND r.reviewer_integration_verified=true
  AND r.fee_ledger_integration_verified=true
 WHERE a.world_id=1 AND a.market_code='L2-EU'
  AND a.status='submitted' AND a.submitted_game_date IS NOT NULL
  AND a.submitted_game_date<=v.game_day-3
 ORDER BY a.submitted_game_date,a.application_id
 LIMIT $1::integer`
});
export function createLicence2GameReviewProcessor({database,signingSecret}={}){
 if(typeof database?.connect!=='function')throw Error('LICENCE2_PRIVATE_DATABASE_REQUIRED');
 if(typeof signingSecret!=='string'||signingSecret.length<32)
  throw Error('LICENCE2_PRIVATE_SIGNING_SECRET_REQUIRED');
 return Object.freeze({
  async run({limit=10}={}){
   if(!Number.isInteger(limit)||limit<1||limit>25)
    throw Error('LICENCE2_REVIEW_BATCH_LIMIT_INVALID');
   const client=await database.connect();
   let rows;
   try{
    const r=await client.query(LICENCE2_PRIVATE_GAME_REVIEW_SQL.queue,[limit]);
    if(!Array.isArray(r.rows)||r.rows.length>limit)
     throw Error('LICENCE2_INVALID_REVIEW_QUEUE');
    rows=r.rows;
   }finally{client.release();}
   let approved=0,blocked=0,skipped=0;
   for(const row of rows){
    if(!UUID.test(row?.applicationId||'')||
     !UUID.test(row?.airlineId||'')||
     !Number.isInteger(row?.requestedLevel)||row.requestedLevel<1||row.requestedLevel>4||
     typeof row.reviewedGameDay!=='string'||!DAY.test(row.reviewedGameDay)||
     typeof row.gameTickEventId!=='string'||row.gameTickEventId.length<12||
     row.preflight?.approvalReady!==true||
     row.preflight?.decision!=='REVIEW_READY_NOT_APPROVAL'||
     row.preflight?.applicationId!==row.applicationId||
     row.preflight?.market!=='L2-EU'||
     row.preflight?.level!==row.requestedLevel||
     row.preflight?.processingGameDays!==3||
     !['25000','75000','200000','500000'].includes(String(Number(row.preflight?.quotedFeeUsd)))||
     row.preflight?.cashChanged!==false||
     row.preflight?.permitIssued!==false||
     row.preflight?.flightsActivated!==false){
      skipped++;continue;
    }
    const proof={
     worldId:1,applicationId:row.applicationId,airlineId:row.airlineId,
     marketCode:'L2-EU',requestedLevel:row.requestedLevel,
     decision:'approve',
     reviewEventId:'l2-game-review-v1-'+row.applicationId+'-'+row.reviewedGameDay,
     reviewReference:'l2-verified-game-review-v1-'+row.applicationId+'-'+row.reviewedGameDay,
     reviewedGameDay:row.reviewedGameDay,
     producerEventId:row.gameTickEventId,
     evidenceSource:'independent_game_licence_review_v1'
    };
    const signed={...proof,signature:createHmac('sha256',signingSecret)
      .update(licence2IndependentReviewPayload(proof),'utf8').digest('hex')};
    const service=createLicence2TrustedReviewCommitService({
     database,verificationSecret:signingSecret,
     evidenceReader:{readSignedReview:async()=>signed}
    });
    const result=await service.approve({
     applicationId:row.applicationId,airlineId:row.airlineId,
     requestedLevel:row.requestedLevel,reviewedGameDay:row.reviewedGameDay
    });
    if(result.approvalCommitted===true)approved++;
    else blocked++;
   }
   return Object.freeze({status:'LICENCE2_PRIVATE_REVIEW_BATCH_CHECKED',
    queued:rows.length,approved,blocked,skipped,
    feesChargedOnlyOnAtomicApproval:true,
    flightsActivated:false});
  }
 });
}
