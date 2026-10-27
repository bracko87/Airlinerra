import test from 'node:test';
import assert from 'node:assert/strict';
import {
  readTemplates,applyAirlinerraTemplates
} from '../server/apply-hosted-auth-templates.mjs';

const TOKEN='sbp_'+('x'.repeat(48));
const SAFE={
  disable_signup:true,
  external_anonymous_users_enabled:false,
  mailer_autoconfirm:false,
  external_email_enabled:true,
  smtp_host:'smtp.resend.com',
  smtp_admin_email:'noreply@nextqueststudio.net'
};
const API='https://api.supabase.com/v1/projects/hwllkabgzaynalahvkpz/config/auth';
const json=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'content-type':'application/json'}});

test('all three HTML email templates come from exact reviewed repository files',async()=>{
  const patch=await readTemplates();
  assert.equal(Object.keys(patch).length,6);
  for(const kind of ['invite','confirmation','recovery']){
    assert.ok(patch['mailer_subjects_'+kind]);
    assert.match(patch['mailer_templates_'+kind+'_content'],/\{\{ \.TokenHash \}\}/);
    assert.match(patch['mailer_templates_'+kind+'_content'],/\{\{ \.SiteURL \}\}/);
  }
  assert.match(patch.mailer_templates_invite_content,/type=invite/);
  assert.match(patch.mailer_templates_confirmation_content,/type=email/);
  assert.match(patch.mailer_templates_recovery_content,/type=recovery/);
  assert.doesNotMatch(JSON.stringify(patch),/ConfirmationURL/);
});

test('dry-run only GETs and verifies existing Auth safety gate',async()=>{
  const requests=[];
  const result=await applyAirlinerraTemplates({
    token:TOKEN,fetchImpl:async(url,opt)=>{
      assert.equal(url,API);
      requests.push(opt.method);
      assert.equal(opt.headers.authorization,'Bearer '+TOKEN);
      assert.equal(opt.redirect,'error');
      return json(SAFE);
    }
  });
  assert.deepEqual(requests,['GET']);
  assert.equal(result.mode,'dry-run');
});

test('apply writes ONLY six email-template fields, then re-reads persisted contents',async()=>{
  let patch;
  const verbs=[];
  const result=await applyAirlinerraTemplates({
    token:TOKEN,apply:true,
    fetchImpl:async(url,opt)=>{
      assert.equal(url,API);
      verbs.push(opt.method);
      if(opt.method==='PATCH'){
        patch=JSON.parse(opt.body);
        assert.deepEqual(Object.keys(patch).sort(),[
          'mailer_subjects_confirmation','mailer_subjects_invite','mailer_subjects_recovery',
          'mailer_templates_confirmation_content','mailer_templates_invite_content',
          'mailer_templates_recovery_content'
        ].sort());
        return json({});
      }
      return json({...SAFE,...(patch||{})});
    }
  });
  assert.deepEqual(verbs,['GET','PATCH','GET']);
  assert.deepEqual(result.templates,['invite','confirmation','recovery']);
  assert.equal(result.verified,true);
});

test('unsafe provider state prevents every PATCH',async()=>{
  for(const bad of [
    {disable_signup:false},
    {external_anonymous_users_enabled:true},
    {mailer_autoconfirm:true},
    {external_email_enabled:false},
    {smtp_host:'wrong.smtp.example'},
    {smtp_admin_email:'someone@example.net'}
  ]){
    const verbs=[];
    await assert.rejects(applyAirlinerraTemplates({
      token:TOKEN,apply:true,
      fetchImpl:async(_url,opt)=>{
        verbs.push(opt.method);
        return json({...SAFE,...bad});
      }
    }),/Refusing template update/);
    assert.deepEqual(verbs,['GET']);
  }
});

test('failed API permissions and missing persisted content do not claim success',async()=>{
  await assert.rejects(applyAirlinerraTemplates({
    token:TOKEN,apply:true,
    fetchImpl:async()=>json({message:'do not echo any secret'},403)
  }),/status 403/);
  let gets=0;
  await assert.rejects(applyAirlinerraTemplates({
    token:TOKEN,apply:true,
    fetchImpl:async(_url,opt)=>{
      if(opt.method==='PATCH')return json({});
      gets++;
      return json(SAFE);
    }
  }),/did not persist/);
  assert.equal(gets,2);
});

test('only --apply CLI is permitted; public build excludes writer entirely',async()=>{
  const {readFile}=await import('node:fs/promises');
  const build=await readFile(new URL('../website/dev-scripts/build.mjs',import.meta.url),'utf8');
  assert.doesNotMatch(build,/apply-hosted-auth-templates/);
  const site=await readFile(new URL('../netlify.toml',import.meta.url),'utf8');
  assert.doesNotMatch(site,/apply-hosted-auth-templates/);
});
