import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  createPlayerDataService, safeWorldDirectory, validatedLocale
} from '../website/player-data-service.mjs';
import {
  TRIAL_DAYS, TRIAL_DURATION_MS, STARTING_CAPITAL_USD,
  STARTING_AIRCRAFT_COUNT, plannedTrialFromActivation, previewEntitlement
} from '../server/account-trial-policy.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function fakeClient({ user = {id:'owned-id',email_confirmed_at:'2026-10-26T00:00:00.000Z'}, profile = null, worlds = [] } = {}) {
  const calls = [];
  const supabase = {
    auth: {
      async getUser() {
        calls.push({method:'auth.getUser'});
        return {data:{user},error:null};
      }
    },
    from(table) {
      calls.push({method:'from',table});
      let rows = null;
      return {
        select(cols) {
          calls.push({method:'select',table,cols});
          rows = table === 'airlinerra_game_worlds' ? worlds : profile;
          return this;
        },
        order(column,opts) {
          calls.push({method:'order',column,opts});
          return Promise.resolve({data:rows,error:null});
        },
        eq(column,id) {
          calls.push({method:'eq',column,id});
          return this;
        },
        maybeSingle() {
          return Promise.resolve({data:rows,error:null});
        },
        upsert(payload,opts) {
          calls.push({method:'upsert',table,payload,opts});
          profile = {...payload,created_at:'2026-10-26T00:00:00.000Z',updated_at:'2026-10-26T00:00:00.000Z'};
          return this;
        },
        single() {
          return Promise.resolve({data:profile,error:null});
        }
      };
    }
  };
  return {supabase,calls};
}

test('player data service is disabled by default and never calls Supabase', async () => {
  const {supabase,calls} = fakeClient();
  const repo = createPlayerDataService({supabase});
  await assert.rejects(repo.getMyProfile(),/not enabled/);
  await assert.rejects(repo.saveMyProfile({displayName:'Airline Boss'}),/not enabled/);
  await assert.rejects(repo.listWorlds(),/not enabled/);
  assert.equal(calls.length,0);
});

test('player can only read and change own profile; caller cannot inject user ID or timestamps', async () => {
  const {supabase,calls} = fakeClient();
  const repo = createPlayerDataService({supabase,enabled:true});
  assert.equal(await repo.getMyProfile(),null);
  const saved = await repo.saveMyProfile({
    user_id:'attacker-id',displayName:'  Pacific Pilot ',locale:'en-US',
    created_at:'1900-01-01T00:00:00Z'
  });
  assert.equal(saved.user_id,'owned-id');
  assert.equal(saved.display_name,'Pacific Pilot');
  assert.equal(saved.locale,'en-US');
  const write = calls.find(c=>c.method==='upsert');
  assert.deepEqual(write.payload,{user_id:'owned-id',display_name:'Pacific Pilot',locale:'en-US'});
  assert.deepEqual(write.opts,{onConflict:'user_id'});
  assert.ok(!('created_at' in write.payload));
  assert.equal((await repo.getMyProfile()).user_id,'owned-id');
  assert.ok(calls.some(c=>c.method==='eq'&&c.column==='user_id'&&c.id==='owned-id'));
});

test('unverified and anonymous users cannot access or mutate profiles', async () => {
  for (const user of [
    null, {id:'u'}, {id:'u',email_confirmed_at:null},
    {id:'u',email_confirmed_at:'2026-10-26',is_anonymous:true}
  ]) {
    const {supabase,calls} = fakeClient({user});
    const repo = createPlayerDataService({supabase,enabled:true});
    await assert.rejects(repo.getMyProfile(),/verified email/);
    await assert.rejects(repo.saveMyProfile({displayName:'Manager'}),/verified email/);
    assert.equal(calls.filter(c=>c.method==='from').length,0);
  }
});

test('invalid display names and locales are blocked before profile writes', async () => {
  const {supabase,calls} = fakeClient();
  const repo = createPlayerDataService({supabase,enabled:true});
  await assert.rejects(repo.saveMyProfile({displayName:'<admin>'}),/display name/);
  await assert.rejects(repo.saveMyProfile({displayName:'Manager',locale:'../../etc/passwd'}),/Unsupported/);
  assert.equal(validatedLocale(null),null);
  assert.equal(validatedLocale('sr-Latn-RS'),'sr-Latn-RS');
  assert.equal(validatedLocale('de-DE'),'de-DE');
  assert.throws(()=>validatedLocale('en_US'),/Unsupported/);
  assert.equal(calls.filter(c=>c.method==='upsert').length,0);
});

test('world metadata is strictly validated, sorted, and never authorizes game entry', async () => {
  const worlds = [
    {id:3,name:'Future World',state:'planned',opens_at:null},
    {id:1,name:'Founding World',state:'planned',opens_at:null},
    {id:2,name:'Expansion World',state:'planned',opens_at:null}
  ];
  const {supabase,calls} = fakeClient({worlds});
  const repo = createPlayerDataService({supabase,enabled:true});
  const directory = await repo.listWorlds();
  assert.deepEqual(directory.map(w=>w.id),['01','02','03']);
  assert.deepEqual(directory.map(w=>w.state),['planned','planned','planned']);
  assert.ok(calls.some(c=>c.method==='from'&&c.table==='airlinerra_game_worlds'));
  assert.throws(()=>safeWorldDirectory([{id:1,name:'A',state:'active'}]),/metadata/);
  assert.throws(()=>safeWorldDirectory([{id:1,name:'Founding World',state:'root'}]),/metadata/);
  assert.throws(()=>safeWorldDirectory([{id:1,name:'Founding World',state:'planned'},
    {id:1,name:'Duplicate World',state:'planned'}]),/ID/);
  assert.throws(()=>safeWorldDirectory([{id:4,name:'Fourth World',state:'planned'}]),/ID/);
});

test('trial policy has the fixed seven-day window and starting airline constants', () => {
  assert.equal(TRIAL_DAYS,7);
  assert.equal(TRIAL_DURATION_MS,604800000);
  assert.equal(STARTING_CAPITAL_USD,5000000);
  assert.equal(STARTING_AIRCRAFT_COUNT,0);
  assert.deepEqual(plannedTrialFromActivation('2026-10-26T08:00:00.000Z'),{
    trial_started_at:'2026-10-26T08:00:00.000Z',
    trial_ends_at:'2026-11-02T08:00:00.000Z'
  });
});

test('trial preview expires at exact boundary without extending for world changes', () => {
  const trial = {
    membership_state:'trial',
    ...plannedTrialFromActivation('2026-10-26T08:00:00.000Z')
  };
  const first = previewEntitlement(trial,'2026-10-26T08:00:00.000Z');
  assert.equal(first.state,'trial');
  assert.equal(first.millisecondsRemaining,TRIAL_DURATION_MS);
  const middle = previewEntitlement(trial,'2026-10-29T08:00:00.000Z');
  assert.equal(middle.millisecondsRemaining,TRIAL_DURATION_MS-3*86400000);
  const end = previewEntitlement(trial,'2026-11-02T08:00:00.000Z');
  assert.equal(end.state,'expired');
  assert.equal(end.millisecondsRemaining,0);
  const later = previewEntitlement(trial,'2027-01-01T00:00:00.000Z');
  assert.equal(later.state,'expired');
  assert.equal(later.trialEndsAt,trial.trial_ends_at);
});

test('paid, suspended and unstarted states never create extra trials', () => {
  assert.equal(previewEntitlement(null,'2026-10-26T08:00:00Z').state,'not_started');
  assert.equal(previewEntitlement({membership_state:'none'},'2026-10-26T08:00:00Z').state,'not_started');
  assert.equal(previewEntitlement({membership_state:'active'},'2026-10-26T08:00:00Z').state,'paid');
  assert.equal(previewEntitlement({membership_state:'suspended'},'2026-10-26T08:00:00Z').state,'suspended');
  assert.equal(previewEntitlement({membership_state:'past_due'},'2026-10-26T08:00:00Z').state,'past_due');
  assert.throws(()=>previewEntitlement({membership_state:'trial',trial_started_at:'2026-10-26',
    trial_ends_at:'2026-10-28'},'2026-10-26'),/seven-day/);
  assert.throws(()=>plannedTrialFromActivation('invalid'),/Invalid/);
});

test('SQL is still review-only with a closed-world trigger, airport FK and idempotent trial', async () => {
  const sql=await readFile(path.join(root,'docs/sql/airlinerra_game_identity_schema_prelaunch.sql'),'utf8');
  assert.match(sql,/REVIEW ONLY, NOT APPLIED/);
  assert.match(sql,/approved_game_airports/);
  assert.match(sql,/references airlinerra_game\.approved_game_airports\(world_id,source_airport_id\)/);
  assert.match(sql,/airlinerra_airline_world_gate/);
  assert.match(sql,/w\.state in \('registration_open','active'\)/);
  assert.match(sql,/start_account_trial_once/);
  assert.match(sql,/on conflict \(player_id\) do update/);
  assert.match(sql,/e\.trial_started_at is null and e\.membership_state = 'none'/);
  assert.match(sql,/security invoker/);
  assert.match(sql,/revoke all on function airlinerra_game\.start_account_trial_once\(uuid\)/);
  assert.match(sql,/entry_kind <> 'STARTING_CAPITAL' or amount_usd = 5000000\.00/);
  assert.match(sql,/grant insert \(user_id, display_name, locale\)/);
  assert.match(sql,/grant update \(display_name, locale\)/);
  assert.doesNotMatch(sql,/grant select, insert, update \(display_name, locale, updated_at\)/);
});
