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
