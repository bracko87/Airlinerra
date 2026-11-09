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

test('holding age counts from original airline registration even in planned worlds',()=>{
 const x=evaluateHoldingEligibility({worldState:'planned',
  registeredAtUtc:'2026-10-29T08:12:26Z',nowUtc:'2026-11-09T09:12:26Z'});
 assert.equal(x.reason,'waiting_for_60_registration_days');
 assert.equal(x.completedDays,11);
 assert.equal(x.remainingDays,49);
 assert.equal(x.earliestDate,'2026-12-28');
 assert.equal(x.canApply,false);
 const missing=evaluateHoldingEligibility({worldState:'active',
  registeredAtUtc:null,nowUtc:'2026-11-09T09:12:26Z'});
 assert.equal(missing.reason,'registration_timestamp_unverified');
 assert.equal(missing.earliestDate,null);
 assert.equal(evaluateHoldingEligibility({worldState:'active',
  registeredAtUtc:'2026-11-12T00:00:00Z',nowUtc:'2026-11-09T00:00:00Z'}).reason,
  'clock_before_registration');
});

test('holding 60-day countdown handles leap day and exact UTC cutoff',()=>{
 const base={worldState:'active',registeredAtUtc:'2028-02-01T12:00:00Z'};
 const a=evaluateHoldingEligibility({...base,nowUtc:'2028-03-31T11:59:59Z'});
 assert.equal(a.completedDays,58);
 assert.equal(a.remainingDays,2,'Remainder is rounded up to full 24-hour days');
 assert.equal(a.earliestDate,'2028-04-01');
 assert.equal(a.canApply,false);
 const b=evaluateHoldingEligibility({...base,nowUtc:'2028-04-01T11:59:59Z'});
 assert.equal(b.remainingDays,1);
 assert.equal(b.ageThresholdMet,false);
 const c=evaluateHoldingEligibility({...base,nowUtc:'2028-04-01T12:00:00Z'});
 assert.equal(c.completedDays,60);
 assert.equal(c.remainingDays,0);
 assert.equal(c.reason,'holding_registration_not_released');
 assert.equal(c.canApply,false);
 const d=evaluateHoldingEligibility({...base,nowUtc:'2028-04-01T12:00:00Z',formationEnabled:true});
 assert.equal(d.canApply,true);
 assert.equal(d.reason,'eligible_for_application');
 assert.equal(evaluateHoldingEligibility({...base,worldState:'planned',nowUtc:'2028-04-01T12:00:00Z',formationEnabled:true}).canApply,false);
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
 assert.throws(()=>calculateHoldingTransferFee({amountUsd:'100.00',fixedFeeUsd:'0.00',basisPoints:0,capFeeUsd:'1.00'}),/positive configured/);
 assert.throws(()=>calculateHoldingTransferFee({amountUsd:'100.00',fixedFeeUsd:'0.30',basisPoints:5,capFeeUsd:'0.00'}),/positive configured/);
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
