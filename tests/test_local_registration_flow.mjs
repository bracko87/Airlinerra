import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validTestEmail,validTestName,startAttempt,loadAttempt,confirmAttempt,completePasswordStep} from '../website/dev-only/state.mjs';
import {setLocalTestProfile,getLocalTestProfile} from '../website/local-demo-session.mjs';
const store=()=>{const m=new Map();return {setItem:(k,v)=>m.set(k,v),getItem:k=>m.get(k)||null,removeItem:k=>m.delete(k)}};
const origin=new URL('http://localhost:5188/__local_registration__/');
const token='f'.repeat(32);
test('registration rehearsal enforces synthetic email and local name',()=>{
 assert.equal(validTestEmail('tester@example.test'),true);
 assert.equal(validTestEmail('real@gmail.com'),false);
 assert.equal(validTestName('A Manager'),true);
 assert.equal(validTestName('<script>'),false);
 const s=store();
 assert.throws(()=>startAttempt(s,{name:'A Manager',email:'real@gmail.com',token}));
 const started=startAttempt(s,{name:'A Manager',email:'tester@example.test',token});
 assert.equal(started.emailConfirmed,false);
 assert.equal(confirmAttempt(s,'bad'),null);
 assert.equal(confirmAttempt(s,token).emailConfirmed,true);
 assert.throws(()=>completePasswordStep(s,'short','short'),/password/i);
 assert.throws(()=>completePasswordStep(s,'fake-password-123','mismatch'),/password/i);
 assert.equal(completePasswordStep(s,'fake-password-123','fake-password-123').passwordStepComplete,true);
 const raw=JSON.stringify(loadAttempt(s));
 assert.doesNotMatch(raw,/fake-password-123/);
});
test('registration profile is per-tab and local-only',()=>{
 const s=store();
 setLocalTestProfile(s,origin,{name:'A Manager',email:'tester@example.test'});
 assert.deepEqual(getLocalTestProfile(s,origin),{name:'A Manager',email:'tester@example.test'});
 assert.equal(getLocalTestProfile(s,new URL('https://airlinerra.com')),null);
 assert.throws(()=>setLocalTestProfile(s,new URL('https://airlinerra.com'),{name:'A Manager',email:'tester@example.test'}));
});
test('demo registration is not in production output or connected to real Auth',async()=>{
 const read=p=>readFile(new URL(p,import.meta.url),'utf8');
 const [build,dev,html,script]=await Promise.all([
  read('../website/dev-scripts/build.mjs'),read('../website/dev-scripts/dev.mjs'),
  read('../website/dev-only/registration.html'),read('../website/dev-only/registration.mjs')]);
 assert.doesNotMatch(build,/dev-only|local-registration.html/);
 assert.doesNotMatch(dev,/localRegistrationFiles/);
 assert.match(dev,/REAL_PLAYER_PATHS/);
 assert.match(dev,/process\.argv\.includes\('--built'\)/);
 assert.match(html,/LOCAL TEST ONLY/);
 assert.match(html,/Confirm test email/);
 assert.match(script,/completePasswordStep/);
 assert.match(script,/createLocalCatalogClient/);
 assert.match(script,/saveLocalDraft/);
 assert.doesNotMatch(script,/signUp\(|auth\.admin|service_role|supabase\.co|sendEmail/);
});
