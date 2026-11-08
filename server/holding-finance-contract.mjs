/** Airlinerra holding/treasury CONTRACT: pure server-side validation only.
 * No database writes, user-level authority or actual company creation are provided
 * by this module. Production formation and treasury posting are still hard-disabled.
 */
const MONEY=/^(?:0|[1-9][0-9]{0,13})(?:\.([0-9]{1,2}))?$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const ISO_DATE=/^(20|21|22)[0-9]{2}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])$/u;
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
function gameDateValue(value){
 if(typeof value!=='string'||!ISO_DATE.test(value))return null;
 const ms=Date.parse(value+'T00:00:00Z');
 return Number.isFinite(ms)&&new Date(ms).toISOString().slice(0,10)===value?ms:null;
}
/** Count *elapsed world days* since first settled commercial operation.
 * Operating date is sourced from a verified completed flight, not created_at.
 */
export function evaluateHoldingEligibility({
 worldState,gameDate,firstOperatingGameDate,
 gameClockVerified=false,firstFlightVerified=false,
 minimumDays=60,formationEnabled=false
}={}){
 const pending=(reason)=>Object.freeze({
  reason,completedDays:null,remainingDays:null,earliestGameDate:null,
  ageThresholdMet:false,canApply:false
 });
 if(worldState!=='active')return pending('world_not_active');
 if(!gameClockVerified||gameDateValue(gameDate)===null)return pending('game_clock_unverified');
 const start=gameDateValue(firstOperatingGameDate);
 if(!firstFlightVerified||start===null)return pending('first_operating_flight_unverified');
 const today=gameDateValue(gameDate);
 if(today<start)return pending('clock_before_first_operation');
 if(minimumDays!==60)throw Error('The world policy must use 60 days until release');
 const completedDays=Math.floor((today-start)/DAY_MS);
 const remainingDays=Math.max(0,minimumDays-completedDays);
 const earliestGameDate=new Date(start+minimumDays*DAY_MS).toISOString().slice(0,10);
 const ageThresholdMet=remainingDays===0;
 return Object.freeze({
  reason:remainingDays>0?'waiting_for_60_game_days':
    formationEnabled?'eligible_for_application':'holding_registration_not_released',
  completedDays,remainingDays,earliestGameDate,ageThresholdMet,
  canApply:ageThresholdMet&&formationEnabled===true
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
