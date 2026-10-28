import test from 'node:test';import assert from 'node:assert/strict';import {readFile} from 'node:fs/promises';
const read=p=>readFile(new URL(p,import.meta.url),'utf8');
test('public homepage exposes accessible sign-in and prelaunch registration links',async()=>{
 const [index,register,css,build]=await Promise.all([read('../website/index.html'),read('../website/register.html'),read('../website/styles.css'),read('../website/dev-scripts/build.mjs')]);
 assert.match(index,/<a class="header-signin" href="\/account\.html\?screen=sign-in">Sign in<\/a>/);
 assert.match(index,/<a class="header-register" href="\/register\.html">Register<\/a>/);
 assert.match(css,/header-register/);
 assert.match(register,/Registration is currently available by administrator invitation only/);
 assert.match(register,/No registration form is available yet/);
 assert.match(register,/href="\/account\.html\?screen=sign-in"/);
 assert.doesNotMatch(register,/<form|signUp\(|service_role|sb_secret_/i);
 assert.match(build,/'register.html', 'register.css'/);
});