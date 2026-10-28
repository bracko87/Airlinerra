import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {evaluateRegistrationAccess} from '../website/registration-access.mjs';

const provider={signupEnabled:true,emailConfirmedRequired:true,anonymousDisabled:true};
const owner={registrationReady:false,privateOwnerPilotAvailable:true};

test('owner pilot can show real signup only with a guarded provider and draft acknowledgement',()=>{
  assert.equal(evaluateRegistrationAccess({provider,readiness:owner,terms:'draft',privacy:'draft'}).mode,'owner-pilot');
  for(const override of [
    {provider:{...provider,signupEnabled:false}},
    {provider:{...provider,emailConfirmedRequired:false}},
    {provider:{...provider,anonymousDisabled:false}},
    {provider:{...provider,anonymousDisabled:undefined}},
    {provider:null},
    {readiness:{...owner,privateOwnerPilotAvailable:false}},
    {readiness:null},
    {terms:'approved'},
    {privacy:'approved'},
    {terms:'missing'},
    {privacy:'missing'}
  ]){
    assert.equal(evaluateRegistrationAccess({
      provider,readiness:owner,terms:'draft',privacy:'draft',...override
    }).mode,'closed',JSON.stringify(override));
  }
});

test('public registration still requires independent backend and approved final policies',()=>{
  const ready={registrationReady:true,privateOwnerPilotAvailable:false};
  assert.equal(evaluateRegistrationAccess({provider,readiness:ready,terms:'approved',privacy:'approved'}).mode,'public');
  for(const override of [
    {readiness:{...ready,registrationReady:false}},
    {terms:'draft'},
    {privacy:'draft'},
    {provider:{...provider,signupEnabled:false}}
  ]){
    assert.equal(evaluateRegistrationAccess({
      provider,readiness:ready,terms:'approved',privacy:'approved',...override
    }).mode,'closed');
  }
});

test('SQL migration gives select only to Auth admin, not players or anonymous callers',async()=>{
  const sql=await readFile(new URL('../supabase/migrations/20261028183852_grant_owner_signup_gate_reserved_email_read_to_auth_admin.sql',import.meta.url),'utf8');
  const statement=sql.replace(/--[^\n]*/g,'').replace(/\s+/g,' ').trim();
  assert.match(statement,/^GRANT SELECT ON TABLE airlinerra_game\.owner_premium_email_reservations TO supabase_auth_admin;$/i);
  assert.doesNotMatch(statement,/\b(?:anon|authenticated|PUBLIC)\b/i);
});
