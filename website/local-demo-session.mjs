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
export const LOCAL_DEMO_MANAGER=Object.freeze({
 name:'Local Demo Manager',email:'demo.manager@example.test'
});
