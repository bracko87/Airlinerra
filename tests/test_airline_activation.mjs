import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  createAirlineActivationService, validatedActivationRequest, AIRLINE_ACTIVATION_SQL
} from '../server/airline-activation.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const USER='11111111-1111-4111-8111-111111111111';
const AIRLINE='22222222-2222-4222-8222-222222222222';
const request={worldId:1,airlineName:' North Star Airways ',homeAirportKey:'OURAIRPORTS:101'};
const validUser=()=>({user:{id:USER,email_confirmed_at:'2026-10-26T08:00:00.000Z',is_anonymous:false},error:null});

function createFakeDb({failAt=null,rows=null}={}) {
  const calls=[];
  const db={
    async connect() {
      calls.push(['connect']);
      return {
        async query(sql,params) {
          calls.push(['query',sql,params]);
          if(failAt==='BEGIN'&&sql==='BEGIN')throw Error('begin refused');
          if(failAt==='SELECT'&&sql===AIRLINE_ACTIVATION_SQL)throw Error('DB constraint');
          if(failAt==='COMMIT'&&sql==='COMMIT')throw Error('commit refused');
          if(sql===AIRLINE_ACTIVATION_SQL) return {rows:rows??[{
            airline_id:AIRLINE,newly_created:true,
            starting_balance_usd:'5000000.00',
            trial_ends_at:'2026-11-02T08:00:00.000Z'
          }]};
          return {rows:[]};
        },
        release(){calls.push(['release']);}
      };
    }
  };
  return {db,calls};
}

test('private adapter defaults closed and never checks token or calls database', async () => {
  const {db,calls}=createFakeDb();
  let authCalls=0;
  const service=createAirlineActivationService({
    database:db,verifyUserToken:async()=>{authCalls++;return validUser();}
  });
  await assert.rejects(service.createAirline({accessToken:'a'.repeat(32),request}),/disabled/);
  assert.equal(authCalls,0);
  assert.equal(calls.length,0);
  assert.deepEqual(service.rules,{startingCapitalUsd:5000000,startingAircraftCount:0});
});

test('invalid payloads are rejected without injecting unsafe SQL identifiers', () => {
  assert.deepEqual(validatedActivationRequest(request),{
    worldId:1,airlineName:'North Star Airways',homeAirportKey:'OURAIRPORTS:101'
  });
  for(const invalid of [
    null,{}, {worldId:0,airlineName:'ACME',homeAirportKey:'OURAIRPORTS:1'},
    {worldId:4,airlineName:'ACME',homeAirportKey:1},
    {worldId:1,airlineName:'<script>',homeAirportKey:1},
    {worldId:1,airlineName:'X',homeAirportKey:1},
    {worldId:1,airlineName:'ACME',homeAirportKey:'OURAIRPORTS:0'},
    {worldId:1,airlineName:'ACME',homeAirportKey:'OURAIRPORTS:1 OR 1=1'},
    {worldId:1,airlineName:'ACME',homeAirportKey:'OURAIRPORTS:12345678901234567890'}
  ]) assert.throws(()=>validatedActivationRequest(invalid));
  assert.deepEqual(validatedActivationRequest({
    worldId:1,airlineName:'Aleksandrovo Air',
    homeAirportKey:'FICTIONAL:fictional:RS:LYAL'
  }),{
    worldId:1,airlineName:'Aleksandrovo Air',
    homeAirportKey:'FICTIONAL:fictional:RS:LYAL'
  });
  assert.throws(()=>validatedActivationRequest({
    worldId:1,airlineName:'Old Numerical Airport',homeAirportKey:101
  }),/Invalid home airport key/);
  assert.ok(AIRLINE_ACTIVATION_SQL.includes('$1::uuid,$2::smallint,$3::text,$4::text'));
});

test('trusted verified Auth user ID overrides caller-supplied account identifiers', async () => {
  const {db,calls}=createFakeDb();
  const service=createAirlineActivationService({database:db,enabled:true,verifyUserToken:async()=>validUser()});
  const response=await service.createAirline({
    accessToken:'secret-bearer-token-test', request:{...request,playerId:'attacker',userId:'attacker'}
  });
  assert.equal(response.airlineId,AIRLINE);
  assert.equal(response.newlyCreated,true);
  assert.equal(response.cashUsd,'5000000.00');
  assert.deepEqual(calls.map(c=>c[0]==='query'?c[1]:c[0]),
    ['connect','BEGIN',AIRLINE_ACTIVATION_SQL,'COMMIT','release']);
  const values=calls.find(c=>c[1]===AIRLINE_ACTIVATION_SQL)[2];
  assert.deepEqual(values,[USER,1,'North Star Airways','OURAIRPORTS:101']);
});

test('unverified, anonymous or spoofed identities are rejected before connection', async () => {
  for (const data of [
    {user:null,error:null},
    {user:{id:'not-a-uuid',email_confirmed_at:'2026'},error:null},
    {user:{id:USER,email_confirmed_at:null},error:null},
    {user:{id:USER,email_confirmed_at:'2026',is_anonymous:true},error:null},
    {error:new Error('token expired')},
  ]) {
    const {db,calls}=createFakeDb();
    const service=createAirlineActivationService({
      database:db,enabled:true,verifyUserToken:async()=>data
    });
    await assert.rejects(service.createAirline({accessToken:'secret-bearer-token-test',request}),/Verified player/);
    assert.equal(calls.length,0);
  }
});

test('database rejection always rolls back and releases connection', async () => {
  const {db,calls}=createFakeDb({failAt:'SELECT'});
  const service=createAirlineActivationService({database:db,enabled:true,verifyUserToken:async()=>validUser()});
  await assert.rejects(service.createAirline({accessToken:'secret-bearer-token-test',request}),/DB constraint/);
  assert.deepEqual(calls.slice(-2).map(c=>c[0]==='query'?c[1]:c[0]),['ROLLBACK','release']);
  assert.ok(!calls.some(c=>c[1]==='COMMIT'));
});

test('commit failure is propagated; never returns an activation receipt', async () => {
  const {db,calls}=createFakeDb({failAt:'COMMIT'});
  const service=createAirlineActivationService({database:db,enabled:true,verifyUserToken:async()=>validUser()});
  await assert.rejects(service.createAirline({accessToken:'secret-bearer-token-test',request}),/commit refused/);
  assert.ok(calls.some(c=>c[1]==='ROLLBACK'));
  assert.equal(calls.at(-1)[0],'release');
});

test('backend rejects missing SQL rows and always rolls back', async () => {
  const {db,calls}=createFakeDb({rows:[]});
  const service=createAirlineActivationService({database:db,enabled:true,verifyUserToken:async()=>validUser()});
  await assert.rejects(service.createAirline({accessToken:'secret-bearer-token-test',request}),/invalid result/);
  assert.ok(calls.some(c=>c[1]==='ROLLBACK'));
});

test('identical replay accepts original existing airline, never credits via client',async()=>{
  const {db,calls}=createFakeDb({rows:[{
    airline_id:AIRLINE,newly_created:false,starting_balance_usd:'5000000.00',
    trial_ends_at:'2026-11-02T08:00:00.000Z'
  }]});
  const service=createAirlineActivationService({database:db,enabled:true,verifyUserToken:async()=>validUser()});
  const res=await service.createAirline({accessToken:'secret-bearer-token-test',request});
  assert.equal(res.newlyCreated,false);
  assert.equal(res.cashUsd,'5000000.00');
  assert.equal(calls.filter(c=>c[1]===AIRLINE_ACTIVATION_SQL).length,1);
});

test('SQL drafts have valid tagged delimiters and fail-closed operator gates',async()=>{
  const foundation=await readFile(path.join(ROOT,'docs/sql/airlinerra_game_identity_schema_prelaunch.sql'),'utf8');
  const activation=await readFile(path.join(ROOT,'docs/sql/airlinerra_game_activation_prelaunch.sql'),'utf8');
  assert.match(foundation,/REVIEW ONLY, NOT APPLIED/);
  assert.match(activation,/NOT APPLIED/);
  assert.doesNotMatch(foundation,/as \$(?:\r?\n)/);
  for (const text of [foundation,activation]){
    const tags=[...text.matchAll(/(?:as\s+)(\$[A-Za-z_][A-Za-z_0-9]*\$)/g)].map(x=>x[1]);
    assert.ok(tags.length>0);
    for(const tag of new Set(tags)){
      assert.equal(text.split(tag).length-1,2*tags.filter(t=>t===tag).length,
        'unbalanced SQL dollar delimiters '+tag);
    }
  }
  assert.match(activation,/values \(true,false\) on conflict \(id\) do nothing/);
  assert.match(activation,/where g\.id = true and g\.enabled = true for share/);
  assert.match(activation,/email_confirmed_at is not null/);
  assert.match(activation,/is_anonymous,false\) = false/);
  assert.match(activation,/account_consents c/);
  assert.match(activation,/l\.is_published = true/);
  assert.match(activation,/w\.state in \('registration_open','active'\)/);
  assert.match(activation,/approved_game_airports a/);
  assert.match(activation,/create_airline_once\(/);
  assert.match(activation,/for update/);
  assert.match(activation,/if found then\s+if v_existing_name <> v_airline_name/);
  assert.match(activation,/credit_starting_cash_once\(v_existing_airline\)/);
  assert.match(activation,/start_account_trial_once\(p_player_id\)/);
  assert.match(activation,/v_entitlement_state <> 'trial'/);
  assert.match(activation,/v_trial_end <> v_trial_start \+ interval '168 hours'/);
  assert.match(activation,/v_trial_end <= now\(\)/);

  assert.match(activation,/revoke all on function airlinerra_game\.create_airline_once/);
  assert.match(foundation,/airlinerra_one_startup_credit_per_airline/);
  assert.match(foundation,/interval '168 hours'/);
  assert.match(foundation,/unique \(world_id,owner_player_id\)/);
  assert.match(foundation,/references airlinerra_game\.approved_game_airports/);
});
