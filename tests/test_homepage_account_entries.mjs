import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
test('public homepage exposes accessible sign-in and prelaunch registration links',async()=>{
 const [index,register,css,build]=await Promise.all([read('../website/index.html'),read('../website/register.html'),read('../website/styles.css'),read('../website/dev-scripts/build.mjs')]);
 assert.match(index,/<a class="header-signin" href="\/account\.html\?screen=sign-in">Sign in<\/a>/);
 assert.doesNotMatch(index,/class="header-register"/);
 assert.match(index,/<a class="button button-primary button-small desktop-cta" href="\/register\.html">7-Day Free Trial/);
 assert.match(index,/<a class="button button-primary button-large" href="\/register\.html">Explore the 7-Day Trial/);
 assert.doesNotMatch(index,/data-action="trial"/);
 assert.match(css,/header-signin/);
 assert.doesNotMatch(css,/header-register/);
 assert.match(register,/7-DAY TRIAL & REGISTRATION/);
 assert.match(register,/Public registration and the 7-day free trial will open together/);
 assert.match(register,/No public registration form is available yet/);
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
 assert.match(script,/data-airlinerra-legal-approved="true"/);
 assert.match(script,/sdkClient.auth.signUp/);
 assert.match(script,/emailRedirectTo:origin\+'\/account.html\?screen=verify'/);
 assert.match(script,/auth:\{/);
 assert.match(build,/real-registration.mjs/);
 assert.doesNotMatch(script,/example.test|mock|simulate|fakeAccount|service_role|sb_secret_/i);
});
