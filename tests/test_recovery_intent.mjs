import test from 'node:test';
import assert from 'node:assert/strict';
import { createRecoveryIntentGate } from '../website/recovery-intent.mjs';

const auth = (id='alice') => ({
  getUser:async()=>({data:{user:{id}},error:null})
});
const session = id => ({user:{id}});

test('password updates require verified recovery intent', async()=>{
  const gate=createRecoveryIntentGate();
  await assert.rejects(gate.consumeForPasswordUpdate(auth()),/verified password recovery/);
});
test('recovery is consumed after the first update attempt', async()=>{
  const gate=createRecoveryIntentGate();
  await gate.markAfterVerifiedOtp(auth(),session('alice'));
  assert.equal(await gate.consumeForPasswordUpdate(auth()),'alice');
  await assert.rejects(gate.consumeForPasswordUpdate(auth()),/verified password recovery/);
});
test('new Auth session cannot inherit earlier account recovery', async()=>{
  const gate=createRecoveryIntentGate();
  await gate.markAfterVerifiedOtp(auth('alice'),session('alice'));
  await assert.rejects(gate.consumeForPasswordUpdate(auth('bob')),/identity changed/);
  await assert.rejects(gate.consumeForPasswordUpdate(auth('alice')),/verified password recovery/);
});
test('clear prevents delayed recovery replay', async()=>{
  const gate=createRecoveryIntentGate();
  await gate.markAfterVerifiedOtp(auth(),session('alice'));
  gate.clear();
  await assert.rejects(gate.consumeForPasswordUpdate(auth()),/verified password recovery/);
});
test('missing or rejected server user never grants recovery', async()=>{
  const gate=createRecoveryIntentGate();
  await assert.rejects(gate.markAfterVerifiedOtp({
    getUser:async()=>({data:{user:null},error:null})
  },session('alice')),/could not be verified/);
  await assert.rejects(gate.consumeForPasswordUpdate(auth()),/verified password recovery/);
});
test('OTP session ID must match server-verified user ID', async()=>{
  const gate=createRecoveryIntentGate();
  await assert.rejects(gate.markAfterVerifiedOtp(
    auth('bob'),session('alice')),/could not be verified/);
  await assert.rejects(gate.consumeForPasswordUpdate(auth('bob')),/verified password recovery/);
});
