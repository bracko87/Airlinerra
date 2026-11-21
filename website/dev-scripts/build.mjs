import {addInviteOnlyAccount} from './invited-overlay.mjs';
import {verifyBuiltPlayerModules} from './verify-built-player-modules.mjs';
import { cp, mkdir, readdir, rm, stat, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const siteDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const distDir = path.resolve(siteDir, '..', 'dist');
const required = ['index.html', 'styles.css', 'script.js', 'app.js', 'health.html', 'register.html', 'register.css', 'real-registration.mjs', 'registration-access.mjs', 'impressum.html', 'terms.html', 'privacy.html', 'legal.css', 'faq.html', 'pricing.html', 'studio-footer.js', 'studio-footer.css', 'assets', 'account.html', 'account.css', 'account.js', 'auth-rules.mjs', 'auth-service.mjs', 'recovery-intent.mjs', 'auth-client.mjs', 'player-data-service.mjs', 'onboarding-api-client.mjs'];
for (const item of required) await stat(path.join(siteDir, item));
await rm(distDir, { recursive: true, force: true });
await mkdir(distDir, { recursive: true });
for (const item of required) {
  await cp(path.join(siteDir, item), path.join(distDir, item), { recursive: true });
}
const assets = await readdir(path.join(distDir, 'assets'));
for (const asset of ['airlinerra-logo.png', 'airlinerra-aircraft.webp', 'airlinerra-airport.webp', 'route-map.svg', 'favicon.svg']) {
  if (!assets.includes(asset)) throw new Error(`Required artwork not found: ${asset}`);
}
await addInviteOnlyAccount({siteDir,distDir});
// Install the same presentation convention on ALL generated HTML pages,
 // including account, game, marketing and legal pages.
 await cp(path.join(siteDir,'ui-dash-normalizer.js'),path.join(distDir,'ui-dash-normalizer.js'));
 async function installDashConvention(directory){
  for(const item of await readdir(directory,{withFileTypes:true})){
   const target=path.join(directory,item.name);
   if(item.isDirectory()){await installDashConvention(target);continue;}
   if(!item.isFile()||!item.name.endsWith('.html'))continue;
   const html=await readFile(target,'utf8');
   if(html.includes('src="/ui-dash-normalizer.js"'))continue;
   const script='<script src="/ui-dash-normalizer.js"></script>';
   const updated=/<head(?:\s[^>]*)?>/i.test(html)?
    html.replace(/<head(?:\s[^>]*)?>/i,tag=>tag+'\n  '+script):
    script+'\n'+html;
   await writeFile(target,updated,'utf8');
  }
 }
 await installDashConvention(distDir);
 await verifyBuiltPlayerModules({distDir});
console.log(`Airlinerra static build created (invitation-only account; no public signup): ${distDir}`);
