/**
 * Explicitly authorized one-off production bundle for INVITED TESTERS ONLY.
 * Never imported by the default public build, never deploys to Netlify.
 * No registration, public world, payments or server functions are included.
 */
import {cp,readFile,writeFile,stat,access} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as conf} from '../invited-tester-public-settings.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const dist=path.resolve(root,'..','dist');
const seal='I APPROVE PRIVATE TESTER BUILD';
if(process.env.AIRLINERRA_INVITED_TESTER_BUILD_APPROVED!==seal){
  throw new Error('Private invited-tester build requires explicit approval.');
}
if(conf.origin!=='https://airlinerra.com'||
  conf.supabaseUrl!=='https://hwllkabgzaynalahvkpz.supabase.co'||
  !/^sb_publishable_[A-Za-z0-9_-]{16,128}$/.test(conf.publishableKey||'')){
  throw new Error('Invalid pinned public-only Airlinerra Auth configuration.');
}
// Do not silently build a partial output. A standard site build must succeed first.
await stat(path.join(dist,'index.html'));
await stat(path.join(dist,'account.html'));
const preview=await readFile(path.join(dist,'auth-rules.mjs'),'utf8');
if(!preview.includes('export const PUBLIC_AUTH_ENABLED = false;')){
  throw new Error('Public signup front-end release gate must remain closed.');
}
const items=[
  'invited-tester-page.mjs','invited-tester-entry.mjs',
  'invited-tester-auth.mjs','invited-tester-page.css'
];
for(const name of items){
  await cp(path.join(root,name),path.join(dist,name),{errorOnExist:false});
}
const html=await readFile(path.join(root,'prelaunch-invited-account.html'),'utf8');
if(!html.includes('PRIVATE PRELAUNCH ACCESS')||
  !html.includes('<script type="module" src="invited-tester-page.mjs"></script>')||
  /id="register"|signUp\s*\(/i.test(html)){
  throw new Error('Rejected invite-only HTML shell.');
}
const injection='<script defer src="invited-tester-config.js"></script>\n  ';
const shell=html.replace(
  '<script type="module" src="invited-tester-page.mjs"></script>',
  injection+'<script type="module" src="invited-tester-page.mjs"></script>'
);
if(shell===html)throw new Error('Invited tester config script injection failed.');
const publicRuntime={
  operatorPrelaunchApproved:true,
  supabaseUrl:conf.supabaseUrl,
  publishableKey:conf.publishableKey
};
await writeFile(path.join(dist,'invited-tester-config.js'),
  'window.__AIRLINERRA_INVITED_TESTER_CONFIG__=Object.freeze('+JSON.stringify(publicRuntime)+');\n',
  {mode:0o644});
await writeFile(path.join(dist,'account.html'),shell);
// A source-only browser cannot offer general signup or the airline wizard.
const built=await readFile(path.join(dist,'account.html'),'utf8');
if(!built.includes('id="set-password"')||built.includes('id="register"')){
  throw new Error('Invited tester output did not pass the disabled-signup assertion.');
}
console.log('Airlinerra invitation-only static bundle prepared locally (not published).');
