/** Airlinerra holding/treasury CONTRACT: pure server-side validation only.
 * No database writes, user-level authority or actual company creation are provided
 * by this module. Production formation and treasury posting are still hard-disabled.
 */
const MONEY=/^(?:0|[1-9][0-9]{0,13})(?:\.([0-9]{1,2}))?$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const UTC_INSTANT=/^(20|21|22)[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-2][0-9]:[0-5][0-9]:[0-5][0-9](?:\.[0-9]{1,3})?Z$/u;
const DAY_MS=86_400_000;
const KINDS=new Set(['equity_contribution','intercompany_loan','loan_repayment','dividend','service_payment']);

export function parseUsdCents(value){
 if(typeof value!=='string'||!MONEY.test(value))throw Error('Exact positive-or-zero USD decimal required');
 const [d,c='']=value.split('.');
 return BigInt(d)*100n+BigInt((c+'00').slice(0,2));
}
export function centsToUsd(cents){
 if(typeof cents!=='bigint'||cents<0n)throw Error('Invalid USD cents');
 return (cents/100n).toString()+'.'+(cents%100n).toString().padStart(2,'0');
}
function registeredTimestamp(value){
 if(typeof value!=='string'||!UTC_INSTANT.test(value))return null;
 const ms=Date.parse(value);
 return Number.isFinite(ms)&&new Date(ms).toISOString().startsWith(value.slice(0,19))?ms:null;
}
/** Elapsed 24-hour calendar days from *original airline registration*.
 * Both registeredAtUtc and nowUtc must be supplied by the authoritative server;
 * never trust player input or browser clock for entitlement.
 * The waiting period can run while a world is planned, but a company cannot
 * be created until the feature and world are actually enabled.
 */
export function evaluateHoldingEligibility({
 worldState,registeredAtUtc,nowUtc,minimumDays=60,formationEnabled=false
}={}){
 const pending=reason=>Object.freeze({
  reason,completedDays:null,remainingDays:null,earliestDate:null,
  ageThresholdMet:false,canApply:false
 });
 if(minimumDays!==60)throw Error('Current holding waiting period must equal 60 days');
 const registered=registeredTimestamp(registeredAtUtc);
 const now=registeredTimestamp(nowUtc);
 if(registered===null||now===null)return pending('registration_timestamp_unverified');
 if(now<registered)return pending('clock_before_registration');
 const eligibleAt=registered+minimumDays*DAY_MS;
 const completedDays=Math.floor((now-registered)/DAY_MS);
 const remainingDays=Math.max(0,Math.ceil((eligibleAt-now)/DAY_MS));
 const ageThresholdMet=now>=eligibleAt;
 const canApply=ageThresholdMet&&worldState==='active'&&formationEnabled===true;
 return Object.freeze({
  reason:!ageThresholdMet?'waiting_for_60_registration_days':
   !formationEnabled?'holding_registration_not_released':
   worldState!=='active'?'world_not_active':'eligible_for_application',
  completedDays,remainingDays,
  earliestDate:new Date(eligibleAt).toISOString().slice(0,10),
  ageThresholdMet,canApply
 });
}
/** Game finance fee preview in *integer cents*; not a legal/bank quote.
 * Incomplete price settings must not silently create free transfers.
 */
export function calculateHoldingTransferFee({amountUsd,fixedFeeUsd,basisPoints,capFeeUsd}={}){
 const amount=parseUsdCents(amountUsd);
 const fixed=parseUsdCents(fixedFeeUsd);
 const cap=parseUsdCents(capFeeUsd);
 if(amount<=0n)throw Error('Transfer amount must be positive');
 if(!Number.isInteger(basisPoints)||basisPoints<0||basisPoints>500)
  throw Error('Unverified or invalid transfer fee rate');
 if(cap===0n||(fixed===0n&&basisPoints===0))
  throw Error('Every transfer requires a positive configured game banking fee');
 const percentage=(amount*BigInt(basisPoints)+9999n)/10000n;
 const total=fixed+percentage;
 return centsToUsd(total<cap?total:cap);
}
/** Returns a plan only. Never modifies holding, airline or subsidiary balances. */
export function previewHoldingTransfer({
 holdingId,worldId,source,target,transferKind,idempotencyKey,
 amountUsd,feePolicy
}={}){
 if(!UUID.test(holdingId||'')||!UUID.test(idempotencyKey||'')||
  !Number.isInteger(worldId)||worldId<1||worldId>3)throw Error('Invalid holding context');
 if(!source||!target||!UUID.test(source.id||'')||!UUID.test(target.id||'')||
  source.id===target.id||source.holdingId!==holdingId||target.holdingId!==holdingId||
  source.worldId!==worldId||target.worldId!==worldId)throw Error('Cross-holding, cross-world or self-transfer denied');
 if(!['holding','subsidiary'].includes(source.accountScope)||!['holding','subsidiary'].includes(target.accountScope)||
  source.accountScope===target.accountScope)
  throw Error('Transfers must pass through the parent holding');
 if(!KINDS.has(transferKind))throw Error('Unknown transfer purpose');
 if(transferKind==='equity_contribution'&&!(source.accountScope==='holding'&&target.accountScope==='subsidiary')||
    transferKind==='dividend'&&!(source.accountScope==='subsidiary'&&target.accountScope==='holding')||
    transferKind==='loan_repayment'&&!(source.accountScope==='subsidiary'&&target.accountScope==='holding'))
  throw Error('Transfer direction is not valid for this purpose');
 const amount=parseUsdCents(amountUsd);
 const fee=parseUsdCents(calculateHoldingTransferFee({amountUsd,...feePolicy}));
 const available=parseUsdCents(source.availableUsd);
 const reserved=parseUsdCents(source.reservedUsd);
 if(amount+fee>available-reserved)throw Error('Insufficient unreserved funds');
 return Object.freeze({
  previewOnly:true,holdingId,worldId,transferKind,idempotencyKey,
  sourceAccountId:source.id,targetAccountId:target.id,
  amountUsd:centsToUsd(amount),feeUsd:centsToUsd(fee),
  debitUsd:centsToUsd(amount+fee),recipientCreditUsd:centsToUsd(amount),
  noTransactionPosted:true
 });
}
