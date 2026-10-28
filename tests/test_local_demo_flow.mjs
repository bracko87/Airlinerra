import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {
  isLocalDemoOrigin,beginLocalDemo,hasLocalDemo,endLocalDemo,
  LOCAL_DEMO_PLAYER_PATH,LOCAL_DEMO_LOGIN_PATH,LOCAL_DEMO_MANAGER
} from '../website/local-demo-session.mjs';

const loopback=new URL('http://localhost:5188/account.html?screen=sign-in');
const fakeStorage=()=>{
 const m=new Map();
 return {getItem:k=>m.get(k)||null,setItem:(k,v)=>m.set(k,v),removeItem:k=>m.delete(k)};
};
test('local preview is only available on the existing loopback preview server',()=>{
 assert.equal(isLocalDemoOrigin(loopback),true);
 assert.equal(isLocalDemoOrigin(new URL('http://127.0.0.1:5188/')),true);
 for(const origin of ['https://airlinerra.com','http://airlinerra.com:5188',
 'https://localhost:5188','http://localhost:5187','http://192.168.0.2:5188',
 'http://localhost.evil.test:5188']){
   assert.equal(isLocalDemoOrigin(new URL(origin)),false,origin);
 }
});
test('local demo is an ephemeral marker, not a credential or production session',()=>{
 const storage=fakeStorage();
 assert.equal(LOCAL_DEMO_PLAYER_PATH,'/player.html#overview');
 assert.equal(LOCAL_DEMO_LOGIN_PATH,'/account.html?screen=sign-in');
 assert.equal(hasLocalDemo(storage,loopback),false);
 assert.equal(beginLocalDemo(storage,loopback),LOCAL_DEMO_PLAYER_PATH);
 assert.equal(hasLocalDemo(storage,loopback),true);
 assert.equal(hasLocalDemo(storage,new URL('https://airlinerra.com')),false);
 assert.equal(endLocalDemo(storage,loopback),true);
 assert.equal(hasLocalDemo(storage,loopback),false);
 assert.throws(()=>beginLocalDemo(storage,new URL('https://airlinerra.com')),/only at localhost/);
 assert.equal(LOCAL_DEMO_MANAGER.email.endsWith('.test'),true);
});
test('local UI now requires real hosted authentication, never a synthetic login marker',async()=>{
 const read=p=>readFile(new URL(p,import.meta.url),'utf8');
 const [account,player,markup]=await Promise.all([
  read('../website/invited-tester-page.mjs'),read('../website/player-app.mjs'),
  read('../website/private-player-app.html')
 ]);
 assert.match(account,/await inspectInvitedTesterProvider/);
 assert.match(account,/activeAuth=await createInvitedTesterAuth/);
 assert.match(account,/await activeAuth\.signIn/);
 assert.doesNotMatch(account,/beginLocalDemo\(/);
 assert.match(player,/setManager\(await auth\.getUser\(\)\)/);
 assert.doesNotMatch(player,/showPreview\(\);/);
 assert.match(markup,/id="top-email"/);
});
