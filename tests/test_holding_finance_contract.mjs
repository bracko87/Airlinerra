import test from 'node:test';
import assert from 'node:assert/strict';
import {
 parseUsdCents,centsToUsd,evaluateHoldingEligibility,
 calculateHoldingTransferFee,previewHoldingTransfer
} from '../server/holding-finance-contract.mjs';

const H='550e8400-e29b-41d4-a716-446655440000';
const S='550e8400-e29b-41d4-a716-446655440001';
const T='550e8400-e29b-41d4-a716-446655440002';
const I='550e8400-e29b-41d4-a716-446655440003';
const source={id:S,holdingId:H,worldId:1,accountScope:'holding',availableUsd:'500.00',reservedUsd:'100.00'};
const target={id:T,holdingId:H,worldId:1,accountScope:'subsidiary',availableUsd:'0.00',reservedUsd:'0.00'};
const policy={fixedFeeUsd:'0.30',basisPoints:5,capFeeUsd:'2.00'};
const plan={holdingId:H,worldId:1,source,target,transferKind:'equity_contribution',idempotencyKey:I,
 amountUsd:'100.00',feePolicy:policy};

test('holding dates never fall back to airline registration or real time',()=>{
 const a=evaluateHoldingEligibility({worldState:'planned',gameDate:'2026-11-08',
  firstOperatingGameDate:'2026-10-01',gameClockVerified:true,firstFlightVerified:true});
 assert.equal(a.reason,'world_not_active');
 assert.equal(a.completedDays,null);
 assert.equal(a.canApply,false);
 const b=evaluateHoldingEligibility({worldState:'active',gameDate:'2026-11-08',
  firstOperatingGameDate:'2026-10-01',gameClockVerified:false,firstFlightVerified:true});
 assert.equal(b.reason,'game_clock_unverified');
 const c=evaluateHoldingEligibility({worldState:'active',gameDate:'2026-11-08',
  firstOperatingGameDate:'2026-10-01',gameClockVerified:true,firstFlightVerified:false});
 assert.equal(c.reason,'first_operating_flight_unverified');
 assert.equal(evaluateHoldingEligibility({worldState:'active',gameDate:'2026-10-01',
  firstOperatingGameDate:'2026-11-01',gameClockVerified:true,firstFlightVerified:true}).reason,
  'clock_before_first_operation');
});

test('holding 60-day countdown uses full calendar game dates including leap day',()=>{
 const base={worldState:'active',firstOperatingGameDate:'2028-02-01',
  gameClockVerified:true,firstFlightVerified:true};
 const a=evaluateHoldingEligibility({...base,gameDate:'2028-03-31'});
 assert.equal(a.completedDays,59);
 assert.equal(a.remainingDays,1);
 assert.equal(a.earliestGameDate,'2028-04-01');
 assert.equal(a.canApply,false);
 const b=evaluateHoldingEligibility({...base,gameDate:'2028-04-01'});
 assert.equal(b.completedDays,60);
 assert.equal(b.ageThresholdMet,true);
 assert.equal(b.remainingDays,0);
 assert.equal(b.reason,'holding_registration_not_released');
 assert.equal(b.canApply,false);
 const c=evaluateHoldingEligibility({...base,gameDate:'2028-04-01',formationEnabled:true});
 assert.equal(c.canApply,true);
 assert.equal(c.reason,'eligible_for_application');
});

test('money parsing is exact with two decimal places and never uses floating point',()=>{
 assert.equal(parseUsdCents('0.01'),1n);
 assert.equal(parseUsdCents('1234567.89'),123456789n);
 assert.equal(centsToUsd(123456789n),'1234567.89');
 for(const x of ['.50','1e4','-1.00','1.234','1,000.00','Infinity',' 100.00','01.00']){
  assert.throws(()=>parseUsdCents(x));
 }
});

test('transfer fees have fixed and percent components, ceil to cent, and enforce cap',()=>{
 assert.equal(calculateHoldingTransferFee({amountUsd:'1000.00',...policy}),'0.80');
 assert.equal(calculateHoldingTransferFee({amountUsd:'10000.00',...policy}),'2.00');
 assert.equal(calculateHoldingTransferFee({amountUsd:'0.01',...policy}),'0.31');
 assert.throws(()=>calculateHoldingTransferFee({amountUsd:'100.00',fixedFeeUsd:'0.30',basisPoints:5}),
  /Exact/,'Missing price must fail closed');
 assert.throws(()=>calculateHoldingTransferFee({amountUsd:'10.00',fixedFeeUsd:'0.30',basisPoints:-1,capFeeUsd:'2.00'}));
});

test('holding transfer preview debits fee only once and does not post transactions',()=>{
 const r=previewHoldingTransfer(plan);
 assert.equal(r.previewOnly,true);
 assert.equal(r.noTransactionPosted,true);
 assert.equal(r.amountUsd,'100.00');
 assert.equal(r.feeUsd,'0.35');
 assert.equal(r.debitUsd,'100.35');
 assert.equal(r.recipientCreditUsd,'100.00');
 assert.equal(source.availableUsd,'500.00','No source debit');
 assert.equal(target.availableUsd,'0.00','No recipient credit');
 assert.equal(r.idempotencyKey,I);
});

test('holding treasury denies cross-world, cross-holding and self-transfer',()=>{
 assert.throws(()=>previewHoldingTransfer({...plan,target:{...target,worldId:2}}),/Cross-holding/);
 assert.throws(()=>previewHoldingTransfer({...plan,target:{...target,holdingId:'550e8400-e29b-41d4-a716-446655440005'}}),/Cross-holding/);
 assert.throws(()=>previewHoldingTransfer({...plan,target:{...target,id:S}}),/Cross-holding/);
 assert.throws(()=>previewHoldingTransfer({...plan,target:{...target,accountScope:'holding'}}),/Transfers must/);
 assert.throws(()=>previewHoldingTransfer({...plan,transferKind:'dividend'}),/direction/);
 assert.throws(()=>previewHoldingTransfer({...plan,idempotencyKey:'bad'}),/Invalid holding/);
 assert.throws(()=>previewHoldingTransfer({...plan,transferKind:'evasion'}),/Unknown/);
});

test('fees and reserved cash prevent unfunded subsidiary capital injections',()=>{
 assert.throws(()=>previewHoldingTransfer({...plan,amountUsd:'400.00'}),/Insufficient unreserved funds/);
 assert.throws(()=>previewHoldingTransfer({...plan,source:{...source,availableUsd:'100.00',reservedUsd:'0.00'}}),
  /Insufficient unreserved funds/,'Fee must not be omitted');
 assert.throws(()=>previewHoldingTransfer({...plan,feePolicy:{...policy,fixedFeeUsd:null}}),/Exact/);
 const reverse=previewHoldingTransfer({...plan,source:{...target,availableUsd:'500.00'},target:source,
  transferKind:'dividend'});
 assert.equal(reverse.debitUsd,'100.35');
});
