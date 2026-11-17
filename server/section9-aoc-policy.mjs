/**
 * Airlinerra: game-only AOC decision rules.
 *
 * This module is pure: NO database writes, no money movements, no player
 * certificate issuance, no game-clock generation and no flight enforcement.
 * The trusted backend supplies independently verified game dates, individual
 * company identity and incident/corrective-action receipts.
 *
 * See docs/AIRLINERRA_AOC_LICENCE1_FINAL_SPEC_2026-11-17.md.
 */
export const AOC_RULES=Object.freeze({
 validityGameDays:365,
 reminderGameDays:90,
 renewalThreshold:70,
 startingSafetyRating:100,
 originalIssueFeeUsd:0,
 subsidiaryIssueFeeUsd:10000,
 subsidiaryProcessingGameDays:3,
 annualRenewalFeeUsd:0,
 incidentPenalties:Object.freeze({minor:5,serious:20,major:30}),
 eligibleKinds:Object.freeze(['passenger','regional','low_cost','cargo','charter','vip'])
});

const DAY_MS=86400000;
const DATE_RE=/^\d{4}-\d{2}-\d{2}$/;
const ID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Strict signed-world YYYY-MM-DD day -> UTC integer day (no local clock). */
export function aocDayNumber(day){
 if(typeof day!=='string'||!DATE_RE.test(day))throw Error('AOC_INVALID_GAME_DATE');
 const [y,m,d]=day.split('-').map(Number);
 const ms=Date.UTC(y,m-1,d);
 if(y<2000||y>2199||!Number.isFinite(ms)||
   new Date(ms).toISOString().slice(0,10)!==day)throw Error('AOC_INVALID_GAME_DATE');
 return Math.floor(ms/DAY_MS);
}
export function aocGameDate(dayIndex){
 if(!Number.isSafeInteger(dayIndex))throw Error('AOC_INVALID_DAY_INDEX');
 const s=new Date(dayIndex*DAY_MS).toISOString().slice(0,10);
 aocDayNumber(s);
 return s;
}
export function aocAddDays(day,days){
 if(!Number.isSafeInteger(days)||Math.abs(days)>1095)throw Error('AOC_INVALID_DAY_OFFSET');
 return aocGameDate(aocDayNumber(day)+days);
}
export function aocEligibleBusinessKind(kind){
 return AOC_RULES.eligibleKinds.includes(kind);
}
export function aocIssueEligibility({kind,companySource,verifiedOriginal=false,verifiedSubsidiary=false,
 releaseEnabled=false}={}){
 if(!aocEligibleBusinessKind(kind))return Object.freeze({status:'not_applicable',eligible:false});
 if(releaseEnabled!==true)return Object.freeze({status:'not_released',eligible:false});
 if(companySource==='original'&&verifiedOriginal===true)
  return Object.freeze({status:'issue_original_free',eligible:true,feeUsd:0,processingGameDays:0});
 if(companySource==='subsidiary'&&verifiedSubsidiary===true)
  return Object.freeze({status:'apply_subsidiary',eligible:true,feeUsd:10000,processingGameDays:3});
 return Object.freeze({status:'company_identity_not_verified',eligible:false});
}
function verifiedIncident(event){
 return event&&typeof event==='object'&&event.verified===true&&
  typeof event.eventId==='string'&&event.eventId.length>=12&&
  Object.hasOwn(AOC_RULES.incidentPenalties,event.severity)&&
  typeof event.airlineId==='string'&&ID_RE.test(event.airlineId);
}
/** A corrective action must have actual nonzero expense AND verified completion. */
export function aocCorrectionCompleted(action){
 if(!action||typeof action!=='object')return false;
 return action.status==='completed'&&action.verifiedCompletion===true&&
  typeof action.completionReceiptId==='string'&&action.completionReceiptId.length>=12&&
  typeof action.paidLedgerEntryId==='string'&&action.paidLedgerEntryId.length>=1&&
  Number.isSafeInteger(action.costUsd)&&action.costUsd>0&&
  Number.isSafeInteger(action.paidUsd)&&action.paidUsd===action.costUsd&&
  typeof action.incidentEventId==='string'&&action.incidentEventId.length>=12;
}
/**
 * Only separately server-verified incident rows can affect the score.
 * Resolved is accepted ONLY with verified, paid corrective proof(s).
 * The database layer also checks that receipt belongs to the same airline.
 */
export function aocSafetySnapshot({airlineId,incidents=[],gameDay}={}){
 if(typeof airlineId!=='string'||!ID_RE.test(airlineId))throw Error('AOC_INVALID_AIRLINE');
 if(!Array.isArray(incidents)||incidents.length>100000)throw Error('AOC_INVALID_INCIDENTS');
 const today=aocDayNumber(gameDay),seen=new Set();
 let lost=0,lifetime=0,lastYear=0,unresolved=0;
 const open=[];
 for(const incident of incidents){
  if(!verifiedIncident(incident))throw Error('AOC_UNVERIFIED_INCIDENT');
  // Sister companies never contribute to another company's score.
  if(incident.airlineId.toLowerCase()!==airlineId.toLowerCase())continue;
  if(seen.has(incident.eventId))throw Error('AOC_DUPLICATE_INCIDENT_EVENT');
  seen.add(incident.eventId);
  const occurred=aocDayNumber(incident.gameDay);
  if(occurred>today)throw Error('AOC_INCIDENT_FUTURE_DAY');
  lifetime++;
  if(occurred>today-365)lastYear++;
  const correction=incident.correction;
  const resolved=incident.status==='resolved'&&
    aocCorrectionCompleted(correction)&&
    correction.incidentEventId===incident.eventId;
  // A row claiming "resolved" without paid evidence is still unresolved.
  if(!resolved){
   const penalty=AOC_RULES.incidentPenalties[incident.severity];
   lost+=penalty;unresolved++;
   open.push(Object.freeze({eventId:incident.eventId,
    severity:incident.severity,penaltyPoints:penalty}));
  }
 }
 const rating=Math.max(0,AOC_RULES.startingSafetyRating-lost);
 return Object.freeze({airlineId,gameDay,rating,unresolved,
  last365GameDays:lastYear,lifetime,open:Object.freeze(open),initialBaseline:lifetime===0});
}
/**
 * Pure renewal decision. Certificate expiration has an EXCLUSIVE boundary:
 * issued D, expires D+365. A correction can reinstate an expired airline,
 * WITHOUT operating a flight.
 */
export function aocRenewalDecision({companyKind,companySource,airlineId,
 certificate,gameDay,safety,verifiedGameClock=false,releaseEnabled=false}={}){
 if(!aocEligibleBusinessKind(companyKind))
  return Object.freeze({status:'not_applicable',change:false});
 if(releaseEnabled!==true)return Object.freeze({status:'not_released',change:false});
 if(verifiedGameClock!==true)
  return Object.freeze({status:'blocked_unverified_game_clock',change:false});
 if(companySource!=='original'&&companySource!=='subsidiary')
  return Object.freeze({status:'blocked_unverified_company_kind',change:false});
 if(!certificate||certificate.airlineId!==airlineId||
    typeof airlineId!=='string'||!ID_RE.test(airlineId))
  return Object.freeze({status:'blocked_missing_company_certificate',change:false});
 const today=aocDayNumber(gameDay);
 const expires=aocDayNumber(certificate.expiresGameDay);
 const issued=aocDayNumber(certificate.issuedGameDay);
 if(expires!==issued+365||issued>today)
  return Object.freeze({status:'blocked_invalid_certificate_dates',change:false});
 if(!safety||safety.airlineId!==airlineId||
    safety.gameDay!==gameDay||!Number.isInteger(safety.rating)||
    safety.rating<0||safety.rating>100)
  return Object.freeze({status:'blocked_unverified_safety_score',change:false});
 const rating=safety.rating;
 if(certificate.status==='active'){
  if(today<expires){
   const reminderDue=today>=expires-AOC_RULES.reminderGameDays&&
    certificate.remindedForExpiry!==certificate.expiresGameDay;
   return Object.freeze({status:reminderDue?'reminder_due':'active',
    change:reminderDue,reminderDue,feeUsd:0,
    nextExpiryGameDay:certificate.expiresGameDay});
  }
  if(rating>=AOC_RULES.renewalThreshold){
   const next=aocGameDate(expires+365);
   return Object.freeze({status:'renew',change:true,feeUsd:0,
    issuedGameDay:certificate.expiresGameDay,expiresGameDay:next});
  }
  return Object.freeze({status:'expire',change:true,feeUsd:0,
   reason:'SAFETY_RATING_BELOW_70',rating,retainAssetsAndRoutes:true});
 }
 if(certificate.status==='expired'){
  if(rating>=AOC_RULES.renewalThreshold)
   return Object.freeze({status:'reinstate',change:true,feeUsd:0,
    issuedGameDay:gameDay,expiresGameDay:aocAddDays(gameDay,365)});
  return Object.freeze({status:'expired_waiting_for_paid_corrections',
    change:false,rating,feeUsd:0});
 }
 return Object.freeze({status:'blocked_invalid_certificate_status',change:false});
}
