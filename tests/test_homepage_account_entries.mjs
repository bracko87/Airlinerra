import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
test('homepage announces development and blocks public registration while existing testers retain sign-in',async()=>{
 const [index,register,css,build]=await Promise.all([read('../website/index.html'),read('../website/register.html'),read('../website/styles.css'),read('../website/dev-scripts/build.mjs')]);
 assert.match(index,/<a class="header-signin" href="\/account\.html\?screen=sign-in">Sign in<\/a>/);
 assert.match(index,/role="note" aria-label="Important development notice"/);
 assert.match(index,/Airlinerra is still in development/);
 assert.match(index,/public registration is currently closed/i);
 assert.match(index,/Existing approved testers can still sign in/);
 assert.doesNotMatch(index,/<a[^>]+href="\/register\.html"[^>]*>\s*(?:Explore the 7-Day Trial|7-Day Free Trial|Trial registration details)/);
 assert.match(index,/registration-closed-button/);
 assert.doesNotMatch(index,/data-action="trial"/);
 assert.match(css,/\.development-notice\{/);
 assert.match(css,/\.button\.registration-closed-button\{/);
 assert.match(css,/header-signin/);
 assert.match(register,/UNDER DEVELOPMENT/);
 assert.match(register,/Registration is currently closed/);
 assert.match(register,/New account creation is paused/);
 assert.match(register,/href="\/account\.html\?screen=sign-in"/);
 assert.match(register,/id="real-registration-form" hidden/);
 assert.doesNotMatch(register,/service_role|sb_secret_/i);
 assert.match(build,/'register.html', 'register.css', 'real-registration.mjs'/);
 const authCss=await read('../website/invited-tester-page.css');
 const regCss=await read('../website/register.css');
 assert.match(authCss,/1220px/);
 assert.match(regCss,/1220px/);
 assert.match(regCss,/registration-layout/);
});
test('registration UI remains closed regardless of future backend readiness and no signup can run from form submission',async()=>{
 const [page,access,script]=await Promise.all([
  read('../website/register.html'),read('../website/registration-access.mjs'),
  read('../website/real-registration.mjs')
 ]);
 assert.match(access,/export const REGISTRATION_UI_PAUSED = true;/);
 assert.match(script,/if\(REGISTRATION_UI_PAUSED\)\{/);
 assert.match(script,/blocked\('Public registration is currently closed/);
 assert.match(script,/New registrations are not available/);
 assert.match(page,/id="registration-readiness" data-status="blocked"/);
 const {REGISTRATION_UI_PAUSED}=await import('../website/registration-access.mjs');
 assert.equal(REGISTRATION_UI_PAUSED,true);
});

test('real signup requires hosted signup enabled and approved legal pages',async()=>{
 const {readFile}=await import('node:fs/promises');
 const site=new URL('../website/',import.meta.url);
 const [register,script,build]=await Promise.all([
  readFile(new URL('register.html',site),'utf8'),
  readFile(new URL('real-registration.mjs',site),'utf8'),
  readFile(new URL('dev-scripts/build.mjs',site),'utf8')
 ]);
 assert.match(register,/id="real-registration-form" hidden/);
 assert.match(script,/provider.signupEnabled!==true/);
 assert.match(script,/api\/v1\/registration\/readiness/);
 const access=await read('../website/registration-access.mjs');
 assert.match(script,/evaluateRegistrationAccess\(\{provider,readiness,terms,privacy\}\)/);
 assert.match(access,/readiness\.privateOwnerPilotAvailable===true/);
 assert.match(script,/data-airlinerra-legal-approved="true"/);
 assert.match(script,/REVIEW DRAFT/);
 assert.match(script,/sdkClient.auth.signUp/);
 assert.match(script,/emailRedirectTo:origin\+'\/account.html\?screen=verify'/);
 assert.match(script,/auth:\{/);
 assert.match(build,/real-registration.mjs/);
 assert.doesNotMatch(script,/example.test|mock|simulate|fakeAccount|service_role|sb_secret_/i);
});

test('operator-supplied legal notice is included, while unfinished policies cannot authorize public signup',async()=>{
 const [legal,terms,privacy,build,register]=await Promise.all([
  read('../website/impressum.html'),read('../website/terms.html'),
  read('../website/privacy.html'),read('../website/dev-scripts/build.mjs'),
  read('../website/register.html')
 ]);
 assert.match(legal,/Next Quest Studio/);
 assert.match(legal,/Aleksandar Levnajic/);
 assert.match(legal,/22850 Norderstedt/);
 assert.match(legal,/mailto:contact@nextqueststudio.net/);
 assert.match(legal,/sole proprietorship/i);
 for(const draft of [terms,privacy]){
  assert.match(draft,/REVIEW DRAFT/);
  assert.match(draft,/contact@nextqueststudio.net/);
  assert.doesNotMatch(draft,/data-airlinerra-legal-approved="true"/);
 }
 for(const filename of ['impressum.html','terms.html','privacy.html','legal.css'])
  assert.ok(build.includes("'"+filename+"'"),filename);
 for(const href of ['/impressum.html','/terms.html','/privacy.html'])
  assert.ok(register.includes('href="'+href+'"'),href);
});

test('legal pages are reachable from the public homepage and account entry',async()=>{
 const [index,account]=await Promise.all([
  read('../website/index.html'),read('../website/prelaunch-invited-account.html')
 ]);
 for(const page of ['/impressum.html','/terms.html','/privacy.html']){
  assert.ok(index.includes('href="'+page+'"'),page+' home');
  assert.ok(account.includes('href="'+page+'"'),page+' account');
 }
});

test('owner-approved trial has no payment requirement or automatic conversion across all public copy',async()=>{
 const [home,register,terms,policy,legalDraft]=await Promise.all([
  read('../website/index.html'),
  read('../website/register.html'),
  read('../website/terms.html'),
  read('../server/account-trial-policy.mjs'),
  read('../docs/legal/AIRLINERRA_TERMS_DRAFT.md')
 ]);
 assert.match(home,/no card required/i);
 assert.match(home,/No automatic payment or upgrade/);
 assert.match(register,/No payment details required/);
 assert.match(register,/nothing is charged/);
 assert.match(terms,/no credit card or other payment details/i);
 assert.match(terms,/no automatic payment, no automatic upgrade and no charge/i);
 assert.match(legalDraft,/never automatically becomes a paid subscription/);
 assert.match(policy,/TRIAL_AUTO_CONVERTS_TO_PAID = false/);
 assert.match(policy,/TRIAL_AUTO_CHARGE_ENABLED = false/);
 assert.doesNotMatch(register,/name="(?:cardNumber|paymentMethod|iban)"/i);
 assert.doesNotMatch(terms,/data-airlinerra-legal-approved="true"/);
});

test('signup has repeat-password match, strength indicator, aligned consent and safe readiness failure',async()=>{
 const [html,script,style,account,page]=await Promise.all([
  read('../website/register.html'),read('../website/real-registration.mjs'),
  read('../website/register.css'),read('../website/prelaunch-invited-account.html'),
  read('../website/invited-tester-page.mjs')
 ]);
 assert.match(html,/id="new-manager-password"[^>]*minlength="8"/);
 assert.match(html,/id="new-manager-password-confirm"[^>]*minlength="8"/);
 assert.match(html,/id="password-strength-meter"/);
 assert.match(html,/class="consent-links"/);
 assert.match(script,/password!==confirmInput.value/);
 assert.match(script,/confirmInput\.setCustomValidity/);
 assert.match(script,/readinessResponse.status===503/);
 assert.match(style,/#real-registration-form\[hidden\]\{display:none!important\}/);
 assert.match(style,/grid-template-columns:18px minmax\(0,1fr\)/);
 assert.match(account,/New password \(8 to 128 characters\)/);
 assert.match(page,/password.length<8/);
});
