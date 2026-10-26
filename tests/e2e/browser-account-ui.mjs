/**
 * Real Chromium UI integration: signup -> Mailpit confirmation -> login
 * -> save persistent owner-scoped profile -> recovery -> new password login.
 * Real Supabase local Auth/PostgREST, not mock objects; CI-only data.
 *
 * Deliberately does not claim browser airline creation: the airline wizard
 * UI and its production-grade server deployment do not exist yet.
 */
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { chromium } from 'playwright';
import { startLocalAuthPreview } from '../../website/dev-scripts/dev-local-auth.mjs';

const AUTH='http://127.0.0.1:54321';
const MAIL='http://127.0.0.1:54324';
const WEB='http://localhost:5187';

function readLocalKey(){
  const output=execFileSync('supabase',['status','-o','json'],{
    encoding:'utf8',timeout:20000,stdio:['ignore','pipe','pipe']
  });
  assert.ok(!output.includes('hwllkabgzaynalahvkpz'),
    'Refuse connection to the airport research project');
  const details=JSON.parse(output);
  const entries=Object.entries(details.env || details);
  const value=(...names)=>entries.find(([key])=>names.includes(key))?.[1];
  assert.equal(value('API_URL','api_url'),AUTH,'Only local Auth is allowed');
  const pub=value('PUBLISHABLE_KEY','publishable_key');
  const anon=value('ANON_KEY','anon_key');
  const key=typeof pub==='string'&&pub.startsWith('sb_publishable_')?
    pub:typeof anon==='string'&&/^eyJ[A-Za-z0-9._-]+$/u.test(anon)?anon:null;
  assert.ok(key,'Local public Auth API key is required');
  return key;
}
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function emailLink(email,subjectPart,seen){
  const deadline=Date.now()+50000;
  while(Date.now()<deadline){
    const response=await fetch(MAIL+'/api/v1/messages',{signal:AbortSignal.timeout(3500)});
    if(response.ok){
      const data=await response.json();
      for(const m of data.messages||[]){
        if(!m.ID||seen.has(m.ID)||
           !JSON.stringify(m.To||[]).toLowerCase().includes(email.toLowerCase())||
           !String(m.Subject||'').toLowerCase().includes(subjectPart))continue;
        const detail=await fetch(MAIL+'/api/v1/message/'+encodeURIComponent(m.ID),
          {signal:AbortSignal.timeout(3500)});
        assert.equal(detail.status,200,'Mailpit message can be read');
        const body=await detail.json();
        const href=String(body.HTML||body.Html||body.html||'')
          .match(/href=["']([^"']+)["']/i)?.[1]?.replace(/&amp;/g,'&');
        assert.ok(href,'Mailpit confirmation/reset message must contain a link');
        const url=new URL(href);
        assert.equal(url.origin,WEB,'Refuse browser callback outside localhost');
        seen.add(m.ID);
        return url.toString();
      }
    }
    await pause(1000);
  }
  throw Error('Mailpit '+subjectPart+' message not received');
}
async function main(){
  const key=readLocalKey();
  const preview=await startLocalAuthPreview({
    port:5187,env:{
      AIRLINERRA_LOCAL_AUTH_TEST:'1',
      AIRLINERRA_LOCAL_SUPABASE_URL:AUTH,
      AIRLINERRA_LOCAL_PUBLISHABLE_KEY:key
    }
  });
  let browser;
  try {
    assert.equal(preview.origin,WEB);
    browser=await chromium.launch({headless:true});
    const context=await browser.newContext({viewport:{width:1440,height:900}});
    const page=await context.newPage();
    page.setDefaultTimeout(18000);
    const errors=[];
    page.on('pageerror',()=>errors.push('browser module error'));

    const email='airlinerra-browser-'+randomBytes(7).toString('hex')+'@example.test';
    const password='UiTest-A1-'+randomBytes(15).toString('hex');
    const newer='UiReset-B2-'+randomBytes(15).toString('hex');
    const seen=new Set();

    await page.goto(WEB+'/account.html?screen=register');
    await page.locator('[data-panel="register"]').waitFor({state:'visible'});
    await page.locator('#register-name').fill('Browser CI Manager');
    await page.locator('#register-email').fill(email);
    await page.locator('#register-password').fill(password);
    await page.locator('[data-panel=register] input[type=checkbox]').check();
    await page.locator('[data-panel=register] button[type=submit]').click();
    await page.getByText('If registration succeeds, check your email', {exact:false})
      .waitFor({state:'visible'});
    console.log('PASS: registration form submitted through a real Chromium browser.');

    const confirm=await emailLink(email,'confirm',seen);
    await page.goto(confirm);
    await page.getByText('Email confirmed. You can now sign in.')
      .waitFor({state:'visible'});
    console.log('PASS: browser email-confirmation callback from real Mailpit link.');

    await page.locator('#login-email').fill(email);
    await page.locator('#login-password').fill(password);
    await page.locator('[data-panel="sign-in"] button[type=submit]').click();
    await page.locator('#player-profile-form fieldset:not([disabled])').waitFor();
    await page.locator('#profile-display-name').fill('Browser Verified Manager');
    await page.locator('#profile-locale').selectOption('de-DE');
    await page.locator('#player-profile-form button[type=submit]').click();
    await page.getByText('Manager profile saved.').waitFor();
    await page.reload();
    await page.locator('#player-profile-form fieldset:not([disabled])').waitFor();
    assert.equal(await page.locator('#profile-display-name').inputValue(),
      'Browser Verified Manager');
    assert.equal(await page.locator('#profile-locale').inputValue(),'de-DE');
    assert.match(await page.locator('#world-list').innerText(),/Founding World/);
    assert.ok(!(await page.locator('#world-list').innerText()).includes('Registration open'),
      'No real game world can be presented as open by default');
    console.log('PASS: verified player profile survives real browser refresh and RLS.');

    await page.locator('[data-screen="forgot"]').click();
    await page.locator('#forgot-email').fill(email);
    await page.locator('[data-panel=forgot] button[type=submit]').click();
    await page.getByText('If an account exists for this address').waitFor();
    const recovery=await emailLink(email,'reset',seen);
    await page.goto(recovery);
    await page.getByText('Recovery link verified. Choose a new password.').waitFor();
    await page.locator('#reset-password').fill(newer);
    await page.locator('#reset-confirm').fill(newer);
    await page.locator('[data-panel=reset] button[type=submit]').click();
    await page.getByText('Password updated. Please sign in').waitFor();
    console.log('PASS: real browser recovery callback and one-time password update.');

    await page.locator('#login-email').fill(email);
    await page.locator('#login-password').fill(password);
    await page.locator('[data-panel="sign-in"] button[type=submit]').click();
    await page.getByText('Unable to sign in. Check your credentials').waitFor();
    await page.locator('#login-password').fill(newer);
    await page.locator('[data-panel="sign-in"] button[type=submit]').click();
    await page.locator('#player-profile-form fieldset:not([disabled])').waitFor();
    assert.equal(await page.locator('#profile-display-name').inputValue(),
      'Browser Verified Manager');
    assert.equal(errors.length,0,'No unhandled browser JavaScript errors');
    console.log('PASS: previous password denied; new password signs into same saved profile.');
    console.log('ALL REAL CHROMIUM ACCOUNT UI CHECKS PASSED; no public deployment.');
    await context.close();
  } finally {
    if(browser)await browser.close();
    await preview.close();
  }
}
main().catch(e=>{
  // Never log synthetic emails, passwords, JWTs, token hashes or raw HTML.
  console.error('CHROMIUM ACCOUNT UI TEST FAILED: '+String(e?.message||'unknown')
    .replaceAll(/https?:\/\/\S+/g,'[local-url]').slice(0,340));
  process.exitCode=1;
});
