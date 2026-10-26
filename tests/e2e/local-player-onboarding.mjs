/**
 * Isolated real-game onboarding E2E:
 * actual local Supabase Auth + Mailpit + PostgREST profile/RLS
 * + trusted PostgreSQL legal/airline services on one disposable local stack.
 * No hosted Supabase, no airport research edits, no production activation.
 */
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createClient } from '@supabase/supabase-js';
import pg from 'pg';
import { createAuthService, parseAuthCallback } from '../../website/auth-service.mjs';
import { createPlayerDataService } from '../../website/player-data-service.mjs';
import { createLegalConsentService } from '../../server/legal-consent-service.mjs';
import { createAirlineActivationService } from '../../server/airline-activation.mjs';

const { Pool } = pg;
const API='http://127.0.0.1:54321';
const MAIL='http://127.0.0.1:54324';
const ORIGIN='http://localhost:5187';
const LOCAL_PG={host:'127.0.0.1',port:54322,user:'postgres',
  password:'postgres',database:'postgres',max:3,connectionTimeoutMillis:7500};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const expectDenied=async(fn,reason)=>{
  let error;
  try{await fn();}catch(e){error=e;}
  assert.ok(error,reason);
};

function localPublicKey(){
  const raw=execFileSync('supabase',['status','-o','json'],{
    encoding:'utf8',timeout:25000,stdio:['ignore','pipe','pipe']
  });
  const status=JSON.parse(raw);
  const entries=Object.entries(status.env || status);
  const pick=(...names)=>entries.find(([name])=>names.includes(name))?.[1];
  const api=pick('API_URL','api_url');
  assert.equal(api,API,'Refuse nonlocal Auth target');
  assert.ok(!raw.includes('hwllkabgzaynalahvkpz'),'No research project');
  const modern=pick('PUBLISHABLE_KEY','publishable_key');
  const legacy=pick('ANON_KEY','anon_key');
  const key=typeof modern==='string'&&modern.startsWith('sb_publishable_')
    ?modern:typeof legacy==='string'&&/^eyJ[\w.-]+$/u.test(legacy)?legacy:null;
  assert.ok(key,'A local public Supabase API key is required');
  return key;
}

async function fetchMessage(email,fragment,seen=new Set()){
  const deadline=Date.now()+50000;
  while(Date.now()<deadline){
    const response=await fetch(MAIL+'/api/v1/messages',{signal:AbortSignal.timeout(3000)});
    if(response.ok){
      const listing=await response.json();
      for(const item of listing.messages || []){
        if(!item.ID||seen.has(item.ID)||
           !JSON.stringify(item.To || []).toLowerCase().includes(email.toLowerCase())||
           !String(item.Subject || '').toLowerCase().includes(fragment))continue;
        const response=await fetch(MAIL+'/api/v1/message/'+
          encodeURIComponent(item.ID),{signal:AbortSignal.timeout(3000)});
        assert.ok(response.ok,'Mailpit message must be readable');
        const message=await response.json();
        const link=String(message.HTML || message.Html || message.html || '')
          .match(/href=["']([^"']+)["']/i)?.[1]?.replace(/&amp;/g,'&');
        assert.ok(link,'Mailpit message must have a link');
        const url=new URL(link);
        assert.equal(url.origin,ORIGIN,'Only local Auth redirects');
        seen.add(item.ID);
        return {url,seen};
      }
    }
    await delay(1000);
  }
  throw Error('Local Mailpit did not receive expected '+fragment+' email');
}

async function main(){
  const key=localPublicKey();
  const supabase=createClient(API,key,{
    auth:{autoRefreshToken:false,persistSession:false,
      detectSessionInUrl:false,flowType:'pkce'}
  });
  const trustedVerifier=createClient(API,key,{
    auth:{autoRefreshToken:false,persistSession:false,
      detectSessionInUrl:false}
  });
  const verifyUserToken=async token=>{
    const {data,error}=await trustedVerifier.auth.getUser(token);
    return {user:data?.user,error};
  };
  const database=new Pool(LOCAL_PG);
  try{
    const env=await database.query(
      "select current_database() as db, inet_server_addr()::text as server_addr, to_regclass('auth.users')::text as auth_table"
    );
    assert.equal(env.rows[0].db,'postgres');
    assert.equal(env.rows[0].auth_table,'auth.users');
    // The separate research schema must not have been mirrored here.
    const privateResearch=await database.query(
      "select count(*)::integer as count from pg_namespace where nspname='airlinerra'");
    assert.equal(privateResearch.rows[0].count,0,'No research schema in local DB');
    console.log('PASS: local-only Auth PostgreSQL preflight (no research schema).');

    const email='airlinerra-full-'+randomBytes(8).toString('hex')+'@example.test';
    const password='Full-Ci-A1-'+randomBytes(16).toString('hex');
    const account=createAuthService({supabase,origin:ORIGIN,enabled:true});
    await account.register({email,password,displayName:'Synthetic Airline Manager',
      termsAccepted:true});
    let {url}=await fetchMessage(email,'confirm');
    assert.equal(url.searchParams.get('type'),'email');
    await account.completeCallback(parseAuthCallback(url.search,'verify'));
    const user=await account.getUser();
    assert.equal(user.email,email);
    assert.ok(user.email_confirmed_at);
    const signedIn=await account.signIn({email,password});
    assert.equal(signedIn.user.id,user.id);
    const {data:{session}}=await supabase.auth.getSession();
    assert.ok(session?.access_token);
    const verified=await verifyUserToken(session.access_token);
    assert.equal(verified.user?.id,user.id);
    console.log('PASS: real signup, Mailpit confirmation, login and server-side identity verification.');

    const profileService=createPlayerDataService({supabase,enabled:true});
    const before=await profileService.getMyProfile();
    assert.equal(before,null);
    const saved=await profileService.saveMyProfile({
      displayName:'CI Test Manager',locale:'de-DE'
    });
    assert.equal(saved.user_id,user.id);
    assert.equal(saved.locale,'de-DE');
    const again=await profileService.getMyProfile();
    assert.equal(again.display_name,'CI Test Manager');
    const worlds=await profileService.listWorlds();
    assert.deepEqual(worlds.map(w=>w.id),['01','02','03']);
    assert.ok(worlds.every(w=>w.state==='planned'));
    console.log('PASS: verified Auth account persists its profile through real PostgREST RLS.');

    const createAirline=createAirlineActivationService({
      verifyUserToken,database,enabled:true
    });
    const acceptPolicy=createLegalConsentService({
      verifyUserToken,database,enabled:true
    });
    const first={worldId:1,airlineName:'Synthetic Founding Air',
      homeAirportKey:'OURAIRPORTS:101'};
    await expectDenied(()=>createAirline.createAirline({
      accessToken:session.access_token,request:first
    }),'Closed release gate must deny airline creation');
    const empty=await database.query(
      'select count(*)::integer as n from airlinerra_game.airlines');
    assert.equal(empty.rows[0].n,0);
    console.log('PASS: game-world and platform release switches deny first creation.');

    // All operator test values below exist only in this disposable local DB.
    // Explicitly no research airport import or real legal publication.
    await database.query(
      "insert into airlinerra_game.legal_release_policy (id,terms_version,privacy_version,is_published,approved_at) values (true,'ci-synthetic-v1','ci-synthetic-v1',true,now())"
    );
    await expectDenied(()=>createAirline.createAirline({
      accessToken:session.access_token,request:first
    }),'No actual consent must prevent creation');
    await database.query(
      "update public.airlinerra_game_worlds set state='registration_open' where id in (1,2)"
    );
    await database.query(
      "insert into airlinerra_game.approved_game_airports(world_id,airport_key,approval_reference) values (1,'OURAIRPORTS:101','CI-SYNTHETIC-ONLY'),(2,'FICTIONAL:fictional:RS:LYAL','CI-SYNTHETIC-ONLY')"
    );
    await database.query(
      "update airlinerra_game.platform_release_gate set enabled=true where id=true"
    );
    await expectDenied(()=>createAirline.createAirline({
      accessToken:session.access_token,request:first
    }),'Published test terms still require verified consent');

    const consent=await acceptPolicy.acceptPublishedPolicy({
      accessToken:session.access_token,
      acceptance:{termsVersion:'ci-synthetic-v1',privacyVersion:'ci-synthetic-v1',
        acceptTerms:true,acceptPrivacy:true}
    });
    assert.equal(consent.termsVersion,'ci-synthetic-v1');
    const repeatedConsent=await acceptPolicy.acceptPublishedPolicy({
      accessToken:session.access_token,
      acceptance:{termsVersion:'ci-synthetic-v1',privacyVersion:'ci-synthetic-v1',
        acceptTerms:true,acceptPrivacy:true}
    });
    assert.equal(String(consent.acceptedAt),String(repeatedConsent.acceptedAt));
    await expectDenied(()=>createAirline.createAirline({
      accessToken:session.access_token,
      request:{...first,homeAirportKey:'OURAIRPORTS:202'}
    }),'Unapproved airport must be denied despite active test gate');
    console.log('PASS: real published-test-policy consent, replay and airport approval gates.');

    const a=await createAirline.createAirline({
      accessToken:session.access_token,request:first
    });
    assert.equal(a.newlyCreated,true);
    assert.equal(Number(a.cashUsd),5000000);
    assert.ok(a.trialEndsAt);
    const retry=await createAirline.createAirline({
      accessToken:session.access_token,request:first
    });
    assert.equal(retry.newlyCreated,false);
    assert.equal(retry.airlineId,a.airlineId);
    const second=await createAirline.createAirline({
      accessToken:session.access_token,
      request:{worldId:2,airlineName:'Synthetic Expansion Air',
        homeAirportKey:'FICTIONAL:fictional:RS:LYAL'}
    });
    assert.equal(second.newlyCreated,true);
    assert.notEqual(second.airlineId,a.airlineId);
    assert.equal(new Date(second.trialEndsAt).getTime(),
      new Date(a.trialEndsAt).getTime());
    const rows=await database.query(
      "select (select count(*)::integer from airlinerra_game.airlines where owner_player_id=$1) as airlines, (select count(*)::integer from airlinerra_game.airline_ledger where entry_kind='STARTING_CAPITAL' and airline_id in (select id from airlinerra_game.airlines where owner_player_id=$1)) as grants, (select count(*)::integer from airlinerra_game.account_entitlements where player_id=$1 and membership_state='trial' and trial_ends_at=trial_started_at+interval '168 hours') as trials, (select count(*)::integer from airlinerra_game.account_consents where player_id=$1) as consents",
      [user.id]
    );
    assert.deepEqual(rows.rows[0],{airlines:2,grants:2,trials:1,consents:1});
    const money=await database.query(
      "select array_agg(cash_usd order by world_id)::text as amounts from airlinerra_game.airlines where owner_player_id=$1",
      [user.id]
    );
    assert.match(money.rows[0].amounts,/5000000/);
    console.log('PASS: real SQL two-world airline activation, one trial, $5m per airline, safe retry.');

    const outsider=createClient(API,key,{
      auth:{autoRefreshToken:false,persistSession:false,detectSessionInUrl:false}
    });
    const leaked=await outsider.from('airlinerra_player_profiles')
      .select('user_id,display_name').eq('user_id',user.id);
    assert.ok(leaked.error || (Array.isArray(leaked.data)&&leaked.data.length===0),
      'Anonymous access must not read a private player profile');
    console.log('PASS: anonymous profile read denied by real Supabase RLS.');

    await account.signOut();
    console.log('ALL REAL LOCAL FULL ONBOARDING CHECKS PASSED; CI-only state discarded.');
  }finally{
    await database.end();
  }
}
main().catch(e=>{
  // Never print tokens, emails, usernames, passwords or raw DB errors.
  console.error('FULL LOCAL ONBOARDING FAILED: '+String(e?.message||'unknown').slice(0,280));
  process.exitCode=1;
});
