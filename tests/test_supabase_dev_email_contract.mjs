import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { parseAuthCallback, createAuthService } from '../website/auth-service.mjs';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>readFile(path.join(ROOT,p),'utf8');
const TEMPLATE_DIR='supabase/templates/';
const ORIGIN='http://localhost:5187';
const HASH='abcdefghABCDEFGH1234567890';

function linkFromTemplate(html) {
  const href=html.match(/href="([^"]+)"/)?.[1];
  assert.ok(href,'one clickable email link required');
  return href.replaceAll('{{ .SiteURL }}',ORIGIN)
    .replaceAll('{{ .TokenHash }}',HASH)
    .replaceAll('&amp;','&');
}

test('local Supabase config is isolated and requires email confirmation',async()=>{
  const config=await read('supabase/config.toml');
  assert.match(config,/^project_id = "airlinerra-local-auth"/m);
  assert.match(config,/^site_url = "http:\/\/localhost:5187"/m);
  assert.match(config,/^enable_confirmations = true$/m);
  assert.match(config,/\[auth\.email\.template\.confirmation\]/);
  assert.match(config,/\[auth\.email\.template\.recovery\]/);
  assert.match(config,/content_path = "\.\/supabase\/templates\/confirmation\.html"/);
  assert.match(config,/content_path = "\.\/supabase\/templates\/recovery\.html"/);
  assert.doesNotMatch(config,/hwllkabgzaynalahvkpz|service_role|sb_secret_|db\.supabase\.co/i);
});

test('canonical Airlinerra email links resolve only to approved HTTPS verification and recovery routes',async()=>{
  const canonical='https://airlinerra.com';
  const confirmation=(await read(TEMPLATE_DIR+'confirmation.html'))
    .replaceAll('{{ .SiteURL }}',canonical).replaceAll('{{ .TokenHash }}',HASH)
    .replaceAll('&amp;','&');
  const recovery=(await read(TEMPLATE_DIR+'recovery.html'))
    .replaceAll('{{ .SiteURL }}',canonical).replaceAll('{{ .TokenHash }}',HASH)
    .replaceAll('&amp;','&');
  for(const [source,screen,type] of [[confirmation,'verify','email'],[recovery,'reset','recovery']]){
    const href=source.match(/href="([^"]+)"/)?.[1];
    assert.ok(href);
    const url=new URL(href);
    assert.equal(url.origin,canonical);
    assert.equal(url.pathname,'/account.html');
    assert.equal(url.searchParams.get('screen'),screen);
    assert.deepEqual(parseAuthCallback(url.search,screen),{
      kind:'otp',token_hash:HASH,type,purpose:screen
    });
  }
});

test('confirmation template yields only a verified email OTP callback',async()=>{
  const html=await read(TEMPLATE_DIR+'confirmation.html');
  const url=new URL(linkFromTemplate(html));
  assert.equal(url.origin,ORIGIN);
  assert.equal(url.pathname,'/account.html');
  assert.equal(url.searchParams.get('screen'),'verify');
  assert.equal(url.searchParams.get('type'),'email');
  assert.deepEqual(parseAuthCallback(url.search,'verify'),{
    kind:'otp',token_hash:HASH,type:'email',purpose:'verify'
  });
  assert.doesNotMatch(html,/\.ConfirmationURL|\?code=|type=recovery/);
});

test('recovery template yields only a recovery OTP callback',async()=>{
  const html=await read(TEMPLATE_DIR+'recovery.html');
  const url=new URL(linkFromTemplate(html));
  assert.equal(url.origin,ORIGIN);
  assert.equal(url.pathname,'/account.html');
  assert.equal(url.searchParams.get('screen'),'reset');
  assert.equal(url.searchParams.get('type'),'recovery');
  assert.deepEqual(parseAuthCallback(url.search,'reset'),{
    kind:'otp',token_hash:HASH,type:'recovery',purpose:'reset'
  });
  assert.doesNotMatch(html,/\.ConfirmationURL|\?code=|type=email/);
});

test('recovery token from email must not verify as ordinary signup',async()=>{
  const html=await read(TEMPLATE_DIR+'recovery.html');
  const url=new URL(linkFromTemplate(html));
  assert.throws(()=>parseAuthCallback(url.search,'verify'),/Unexpected verification link type/);
  assert.throws(()=>parseAuthCallback(
    '?screen=reset&code=ordinary-login-code','reset'),
    /Recovery-specific verification/);
});

test('synthetic email recovery can authorize exactly one matching-user password update',async()=>{
  const url=new URL(linkFromTemplate(await read(TEMPLATE_DIR+'recovery.html')));
  const calls=[];
  let userId='user-from-recovery';
  const auth={
    verifyOtp:async arg=>{
      calls.push(['verify',arg]);
      return {data:{session:{user:{id:'user-from-recovery'}}},error:null};
    },
    getUser:async()=>({data:{user:{id:userId}},error:null}),
    updateUser:async arg=>{calls.push(['update',arg]);return {error:null};},
    signOut:async opts=>{calls.push(['signout',opts]);return {error:null};}
  };
  const svc=createAuthService({supabase:{auth},origin:ORIGIN,enabled:true});
  await svc.completeCallback(parseAuthCallback(url.search,'reset'));
  await svc.updatePassword('safe-password-123');
  assert.equal(calls.filter(x=>x[0]==='update').length,1);
  assert.equal(calls.filter(x=>x[0]==='signout').length,1);
  await assert.rejects(svc.updatePassword('safe-password-123'),/verified password recovery/);
  assert.deepEqual(calls[0][1],{token_hash:HASH,type:'recovery'});
  userId='a-different-user';
});
