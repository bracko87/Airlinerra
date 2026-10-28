import test from 'node:test';
import assert from 'node:assert/strict';
import {createOnboardingContextService,ONBOARDING_CONTEXT_SQL,
  OWNER_PRIVATE_PILOT_SQL,OWNER_PRIVATE_PILOT_VERSION
} from '../server/onboarding-context-service.mjs';
import {createLegalConsentService,INSERT_PRIVATE_PILOT_ACK_SQL,
  READ_PRIVATE_PILOT_ACK_SQL,READ_PUBLISHED_POLICY_SQL
} from '../server/legal-consent-service.mjs';
import {readFile} from 'node:fs/promises';
const USER='11111111-1111-4111-8111-111111111111';
const TOKEN='private-owner-bearer-token-123456';
const verify=async()=>({user:{id:USER,email_confirmed_at:'2026-10-28T15:00:00Z',is_anonymous:false},error:null});
function pilotContext(eligible){
 const calls=[];
 const database={connect:async()=>({query:async(sql,params)=>{
  calls.push({sql,params});
  if(sql===ONBOARDING_CONTEXT_SQL.ready)
   return {rows:[{enabled:false,terms_version:null,privacy_version:null}]};
  if(sql===OWNER_PRIVATE_PILOT_SQL.eligibility)
   return {rows:[{is_eligible:eligible}]};
  if(sql===OWNER_PRIVATE_PILOT_SQL.worlds)return {rows:[{id:1,name:'World 01'}]};
  if(sql===OWNER_PRIVATE_PILOT_SQL.airports)return {rows:[{
   world_id:1,airport_key:'OURAIRPORTS:100',airport_name:'Approved Airport',
   airport_code:'EDAA',country_iso:'DE'
  }]};
  throw Error('Unknown SQL: '+sql);
 },release:()=>{}})};
 return {calls,service:createOnboardingContextService({
  verifyUserToken:verify,database,enabled:true,enablePrivatePilot:true,
  documentPaths:{terms:'/terms.html',privacy:'/privacy.html'}
 })};
}
test('only an eligible verified owner gets World 1 private-pilot context while public gates stay closed',async()=>{
 const good=pilotContext(true);
 const data=await good.service.getContext({accessToken:TOKEN});
 assert.equal(data.privatePilot,true);
 assert.equal(data.policy.termsVersion,OWNER_PRIVATE_PILOT_VERSION);
 assert.equal(data.policy.privacyVersion,OWNER_PRIVATE_PILOT_VERSION);
 assert.equal(data.worlds.length,1);
 assert.equal(data.worlds[0].airports[0].key,'OURAIRPORTS:100');
 assert.equal(data.worlds[0].airports[0].countryIso,'DE');
 assert.equal(data.worlds[0].airports[0].name,'Approved Airport');
 assert.equal(data.worlds[0].airports[0].code,'EDAA');
 assert.ok(good.calls.some(x=>x.sql===OWNER_PRIVATE_PILOT_SQL.eligibility&&x.params[0]===USER));
 const other=pilotContext(false);
 await assert.rejects(other.service.getContext({accessToken:TOKEN}),/approval required/);
 assert.ok(!other.calls.some(x=>x.sql===OWNER_PRIVATE_PILOT_SQL.airports));
});
test('private owner acknowledgement writes only private pilot consent, never public legal acceptance',async()=>{
 const seen=[];
 const db={connect:async()=>({query:async(sql,params)=>{
  seen.push({sql,params});
  if(sql==='BEGIN'||sql==='COMMIT')return {rows:[]};
  if(sql===INSERT_PRIVATE_PILOT_ACK_SQL)return {rows:[{acknowledged_at:'2026-10-28T15:00:00Z'}]};
  throw Error('Unexpected legal SQL');
 },release:()=>{}})};
 const service=createLegalConsentService({
  verifyUserToken:verify,database:db,enabled:true,enablePrivatePilot:true
 });
 const result=await service.acceptPublishedPolicy({accessToken:TOKEN,acceptance:{
  termsVersion:OWNER_PRIVATE_PILOT_VERSION,privacyVersion:OWNER_PRIVATE_PILOT_VERSION,
  acceptTerms:true,acceptPrivacy:true
 }});
 assert.ok(result.acceptedAt);
 assert.ok(seen.some(x=>x.sql===INSERT_PRIVATE_PILOT_ACK_SQL));
 assert.ok(!seen.some(x=>x.sql===READ_PUBLISHED_POLICY_SQL));
 assert.match(INSERT_PRIVATE_PILOT_ACK_SQL,/owner_premium_email_reservations/);
 assert.match(OWNER_PRIVATE_PILOT_SQL.eligibility,/email_confirmed_at is not null/);
 assert.match(INSERT_PRIVATE_PILOT_ACK_SQL,/email_confirmed_at is not null/);
 assert.match(READ_PRIVATE_PILOT_ACK_SQL,/owner_private_pilot_consents/);
});
test('browser discloses draft acknowledgement and never labels pilot drafts approved',async()=>{
 const read=p=>readFile(new URL(p,import.meta.url),'utf8');
 const [app,html,api]=await Promise.all([
  read('../website/player-app.mjs'),read('../website/private-player-app.html'),
  read('../server/canonical-game-api.mjs')
 ]);
 assert.match(app,/ctx\.privatePilot/);
 assert.match(app,/review draft/);
 assert.match(app,/setup-confirm-dialog/);
 assert.match(html,/id="setup-terms-description"/);
 assert.match(html,/id="setup-privacy-description"/);
 assert.match(api,/enablePrivatePilot:true/);
});

test('owner World 1 wizard is independent of the read-only planned world directory',async()=>{
 const [app,service,html]=await Promise.all([
  readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8'),
  readFile(new URL('../server/onboarding-context-service.mjs',import.meta.url),'utf8'),
  readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8')
 ]);
 assert.match(app,/await loadRealOnboarding\(\)/);
 assert.match(app,/const canSetup=Boolean\(onboardingContext\)/);
 assert.match(app,/function fillSetupCountries\(\)/);
 assert.match(app,/Number\(world\.worldId\)!==1/);
 assert.match(app,/options\.value='1'/);
 assert.match(app,/options\.disabled=options\.options\.length<=1/);
 assert.match(app,/new Option\('World 1 - '/);
 assert.match(service,/parentCountryIso\(row\.country_iso\)/);
 assert.match(service,/countryIso/);
 assert.match(html,/id="setup-world"/);
 assert.match(html,/id="setup-country"/);
 assert.match(html,/id="setup-airport-results"/);
 assert.doesNotMatch(app,/options\.append\(new Option\(name\+' — '\+world\.state/);
});

test('planned World 1 airline trigger exception is consented, owner-only and not a public gate',async()=>{
 const migration=await readFile(new URL('../supabase/migrations/20261028215500_airlinerra_owner_world1_airline_trigger_exception.sql',import.meta.url),'utf8');
 assert.match(migration,/CREATE OR REPLACE FUNCTION airlinerra_game\.require_open_world_for_airline\(\)/i);
 assert.match(migration,/NEW\.world_id = 1/);
 assert.match(migration,/w\.state = 'planned'/);
 assert.match(migration,/owner_premium_email_reservations/);
 assert.match(migration,/owner_private_pilot_consents/);
 assert.match(migration,/c\.version = 'owner_private_pilot_20261028'/);
 assert.match(migration,/u\.email_confirmed_at IS NOT NULL/);
 assert.match(migration,/coalesce\(u\.is_anonymous,false\) = false/);
 assert.match(migration,/u\.deleted_at IS NULL/);
 assert.match(migration,/u\.banned_until IS NULL OR u\.banned_until <= now\(\)/);
 assert.match(migration,/RAISE EXCEPTION 'Airlinerra world is not open for airline registration'/);
 assert.doesNotMatch(migration,/\bUPDATE\s+public\.airlinerra_game_worlds\b/i);
 assert.doesNotMatch(migration,/\bUPDATE\s+airlinerra_game\.platform_release_gate\b/i);
 assert.doesNotMatch(migration,/\bGRANT\s+(?:INSERT|ALL)\b/i);
});

test('airport details show the requested fields without crossed-out status, coordinates or type',async()=>{
 const html=await readFile(new URL('../website/private-player-app.html',import.meta.url),'utf8');
 const script=await readFile(new URL('../website/player-app.mjs',import.meta.url),'utf8');
 for(const id of ['airport-details-name','airport-details-code','airport-details-location',
   'airport-details-category','airport-details-runway','airport-details-surface',
   'airport-passenger-demand','airport-cargo-demand'])assert.match(html,new RegExp('id="'+id+'"'));
 for(const removed of ['airport-details-category-note','airport-details-coordinates','airport-details-type']){
   assert.doesNotMatch(html,new RegExp('id="'+removed+'"'));
   assert.doesNotMatch(script,new RegExp(removed));
 }
});
