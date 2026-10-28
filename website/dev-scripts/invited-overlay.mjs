/** Normal Airlinerra site build: invite-only account shell, no public registration.
 * This overlay copies PUBLIC browser assets only; it never includes server code,
 * service-role keys, email API keys, database credentials or game endpoints.
 */
import {cp,readFile,writeFile,stat} from 'node:fs/promises';
import path from 'node:path';
import {AIRLINERRA_INVITED_TESTER_PUBLIC_SETTINGS as conf} from '../invited-tester-public-settings.mjs';

export async function addInviteOnlyAccount({siteDir,distDir}={}){
  if(!siteDir||!distDir)throw new Error('Website build paths are required.');
  if(conf.origin!=='https://airlinerra.com'||
    conf.supabaseUrl!=='https://hwllkabgzaynalahvkpz.supabase.co'||
    !/^sb_publishable_[A-Za-z0-9_-]{16,128}$/.test(conf.publishableKey||'')){
    throw new Error('Refusing an unknown Airlinerra Auth project or non-public API key.');
  }
  await stat(path.join(distDir,'index.html'));
  const rules=await readFile(path.join(distDir,'auth-rules.mjs'),'utf8');
  if(!rules.includes('export const PUBLIC_AUTH_ENABLED = false;')){
    throw new Error('Public registration gate must remain disabled.');
  }
  const files=[
    'invited-tester-page.mjs','invited-tester-entry.mjs',
    'invited-tester-auth.mjs','invited-tester-page.css',
    'tester-dashboard.mjs','tester-dashboard-state.mjs','tester-dashboard.css',
    'player-app.mjs','player-app-model.mjs','player-app.css'
  ];
  for(const name of files){
    await cp(path.join(siteDir,name),path.join(distDir,name));
  }
  const source=await readFile(path.join(siteDir,'prelaunch-invited-account.html'),'utf8');
  const moduleTag='<script type="module" src="invited-tester-page.mjs"></script>';
  if(!source.includes(moduleTag)||
    !source.includes('PRIVATE PRELAUNCH ACCESS')||
    /id="register"|id="airline-onboarding"/.test(source)){
    throw new Error('Invite-only account page failed safety checks.');
  }
  // A publishable key is designed for browsers. No secret or service role key
  // may be included. The hosted Supabase provider must enforce signup OFF.
  const settings={
    operatorPrelaunchApproved:true,
    supabaseUrl:conf.supabaseUrl,
    publishableKey:conf.publishableKey
  };
  const built=source.replace(moduleTag,
    '<script defer src="invited-tester-config.js"></script>\n  '+moduleTag);
  if(built===source)throw new Error('Failed to add public-only Auth configuration.');
  await writeFile(path.join(distDir,'invited-tester-config.js'),
    'window.__AIRLINERRA_INVITED_TESTER_CONFIG__=Object.freeze('+
      JSON.stringify(settings)+');\n');
  await writeFile(path.join(distDir,'account.html'),built);
  if(!built.includes('id="set-password"')||
    built.includes('id="register"')||
    built.includes('id="airline-onboarding"')){
    throw new Error('Invited account page must not offer registration or airline creation.');
  }

  const dashboardSource=await readFile(path.join(siteDir,'private-tester-dashboard.html'),'utf8');
  const dashboardTag='<script type="module" src="tester-dashboard.mjs"></script>';
  if(!dashboardSource.includes(dashboardTag)||
    !dashboardSource.includes('id="tester-dashboard" hidden')||
    !dashboardSource.includes('PRIVATE PRELAUNCH ACCESS')||
    /id="register"|id="airline-onboarding"/.test(dashboardSource)){
    throw new Error('Private tester dashboard failed safety checks.');
  }
  const dashboardBuilt=dashboardSource.replace(dashboardTag,
    '<script defer src="invited-tester-config.js"></script>\n  '+dashboardTag);
  await writeFile(path.join(distDir,'tester.html'),dashboardBuilt);

  // Preview-only player application. The static shell contains no game records,
  // release flags or backend secrets. Protected Auth is verified client-side.
  const playerSource=await readFile(path.join(siteDir,'private-player-app.html'),'utf8');
  const playerTag='<script type="module" src="player-app.mjs"></script>';
  if(!playerSource.includes(playerTag)||
     !playerSource.includes('id="player-app" hidden')||
     !playerSource.includes('PRIVATE PRELAUNCH')||
     !playerSource.includes('disabled>Create airline')||
     /<script[^>]+src="https?:|id="register"|service_role|sb_secret_/u.test(playerSource)){
    throw new Error('Player application prelaunch safety checks failed.');
  }
  await writeFile(path.join(distDir,'player.html'),playerSource.replace(
    playerTag,'<script defer src="invited-tester-config.js"></script>\n  '+playerTag
  ));
}
