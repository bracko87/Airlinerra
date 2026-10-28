import {addInviteOnlyAccount} from './invited-overlay.mjs';
import { cp, mkdir, readdir, rm, stat } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const siteDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const distDir = path.resolve(siteDir, '..', 'dist');
const required = ['index.html', 'styles.css', 'script.js', 'app.js', 'health.html', 'register.html', 'register.css', 'real-registration.mjs', 'assets', 'account.html', 'account.css', 'account.js', 'auth-rules.mjs', 'auth-service.mjs', 'recovery-intent.mjs', 'auth-client.mjs', 'player-data-service.mjs', 'onboarding-api-client.mjs'];
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
console.log(`Airlinerra static build created (invitation-only account; no public signup): ${distDir}`);
