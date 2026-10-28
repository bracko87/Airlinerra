import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,access} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const repoRoot=new URL('../',import.meta.url);
const rootPath=fileURLToPath(repoRoot);
const output=name=>new URL('../dist/'+name,import.meta.url);
const read=name=>readFile(output(name),'utf8');
const exists=async name=>{try{await access(output(name));return true;}catch{return false;}};

test('ordinary main build includes invite-only account, without registering players',async()=>{
  execFileSync(process.execPath,['website/dev-scripts/build.mjs'],{
    cwd:rootPath,stdio:'pipe',timeout:25000
  });
  const [html,js,publicRules,configuration]=await Promise.all([
    read('account.html'),read('invited-tester-page.mjs'),
    read('auth-rules.mjs'),read('invited-tester-config.js')
  ]);
  assert.match(html,/PRIVATE PRELAUNCH ACCESS/);
  assert.match(html,/id="sign-in"/);
  assert.match(html,/id="set-password"/);
  assert.match(html,/invited-tester-config\.js/);
  // Explicit homepage navigation is visible on the sign-in, invite and recovery views.
  assert.match(html,/<nav class="header-actions" aria-label="Account page navigation">/);
  assert.match(html,/<a class="public-home-link" href="\/">Home page<\/a>/);

  assert.doesNotMatch(html,/id="register"|id="airline-onboarding"/);
  assert.match(configuration,/operatorPrelaunchApproved":true/);
  assert.match(configuration,/sb_publishable_[A-Za-z0-9_-]{16,128}/);
  assert.doesNotMatch(configuration,/sb_secret_|service_role|postgres:|postgresql:/);
  assert.match(js,/Local visual preview only/);
  assert.match(js,/config\?\.operatorPrelaunchApproved!==true/);
  assert.doesNotMatch(js,/\.signUp\(/);
  assert.match(publicRules,/export const PUBLIC_AUTH_ENABLED = false;/);
  const [dashboardHtml,dashboardScript,accountPage]=await Promise.all([
    read('tester.html'),read('tester-dashboard.mjs'),read('invited-tester-page.mjs')
  ]);
  assert.match(dashboardHtml,/id="tester-dashboard" hidden/);
  const playerHtml=await read('player.html');
  assert.match(playerHtml,/id="player-app" hidden/);
  assert.match(playerHtml,/invited-tester-config\.js/);
  assert.match(playerHtml,/disabled>Create airline/);
  assert.doesNotMatch(playerHtml,/id="register"|service_role|sb_secret_/);

  assert.match(dashboardHtml,/invited-tester-config\.js/);
  assert.match(dashboardHtml,/PRIVATE PRELAUNCH ACCESS/);
  assert.doesNotMatch(dashboardHtml,/id="register"|id="airline-onboarding"/);
  assert.match(dashboardScript,/Local visual preview|LOCAL VISUAL PREVIEW|local preview|Local preview/i);
  assert.match(dashboardScript,/openPrivateTesterDashboard/);
  assert.match(accountPage,/location\.replace\(PRIVATE_TESTER_DASHBOARD_PATH\)/);
  for(const name of [
    'index.html','invited-tester-entry.mjs','invited-tester-auth.mjs',
    'invited-tester-page.css','tester-dashboard.css','tester-dashboard-state.mjs','player-app.mjs','player-app-model.mjs','player-app.css','assets/airlinerra-logo.png'
  ])assert.equal(await exists(name),true,name+' missing from normal build');
  for(const name of ['server','netlify/functions','apply-hosted-auth-templates.mjs']){
    assert.equal(await exists(name),false,name+' must not be published');
  }
});

test('build remains distinct from automatic Netlify deployment and local UI needs no live Auth',async()=>{
  const [netlify,packageJson,dev,source]=await Promise.all([
    readFile(new URL('../netlify.toml',import.meta.url),'utf8'),
    readFile(new URL('../website/package.json',import.meta.url),'utf8'),
    readFile(new URL('../website/dev-scripts/dev.mjs',import.meta.url),'utf8'),
    readFile(new URL('../website/invited-tester-page.mjs',import.meta.url),'utf8')
  ]);
  assert.match(netlify,/command = "npm run build"/);
  assert.match(netlify,/base = "website"/);
  assert.doesNotMatch(netlify,/\[functions\]/);
  assert.equal(JSON.parse(packageJson).scripts.preview,
    'npm run build && node dev-scripts/dev.mjs --built');
  assert.match(dev,/process\.argv\.includes\('--built'\)/);
  assert.match(dev,/--built'\) \? 5188 : 5187/);
  assert.match(dev,/process\.env\.PORT/);
  assert.match(source,/\['localhost','127\.0\.0\.1'\]/);
  assert.match(source,/input\.disabled=true/);
});
