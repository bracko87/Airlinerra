/**
 * Preview session ONLY. Never a Supabase login, bearer token or authorization.
 * This is intentionally limited to the existing loopback build preview on 5188.
 */
const LOCAL_DEMO_KEY='airlinerra-local-demo-v1';
export const LOCAL_DEMO_PLAYER_PATH='/player.html#overview';
export const LOCAL_DEMO_LOGIN_PATH='/account.html?screen=sign-in';
export function isLocalDemoOrigin(location){
  return Boolean(location && location.protocol==='http:' &&
    (location.hostname==='localhost'||location.hostname==='127.0.0.1') &&
    location.port==='5188');
}
export function beginLocalDemo(storage,location){
  if(!isLocalDemoOrigin(location)||typeof storage?.setItem!=='function')
    throw Error('Local dashboard demo is available only at localhost:5188');
  storage.setItem(LOCAL_DEMO_KEY,'demo-only');
  return LOCAL_DEMO_PLAYER_PATH;
}
export function hasLocalDemo(storage,location){
  return isLocalDemoOrigin(location)&&storage?.getItem?.(LOCAL_DEMO_KEY)==='demo-only';
}
export function endLocalDemo(storage,location){
  if(!isLocalDemoOrigin(location))return false;
  storage?.removeItem?.(LOCAL_DEMO_KEY);
  return true;
}
const PROFILE_KEY='airlinerra-local-test-profile-v1';
export function setLocalTestProfile(storage,location,profile){
 if(!isLocalDemoOrigin(location)||typeof profile?.name!=='string'||
   !/^[a-z0-9._%+-]+@example\.test$/iu.test(profile.email||'')||
   profile.name.trim().length<2||profile.name.trim().length>50)
   throw Error('Only local test profiles are allowed');
 storage.setItem(PROFILE_KEY,JSON.stringify({name:profile.name.trim(),email:profile.email.toLowerCase()}));
}
export function getLocalTestProfile(storage,location){
 if(!isLocalDemoOrigin(location))return null;
 try{const d=JSON.parse(storage.getItem(PROFILE_KEY)||'null');
  return typeof d?.name==='string'&&d.name.length>=2&&d.name.length<=50&&
   typeof d.email==='string'&&d.email.endsWith('@example.test')?d:null;
 }catch{return null}
}
export const LOCAL_DEMO_MANAGER=Object.freeze({
 name:'Local Demo Manager',email:'demo.manager@example.test'
});
