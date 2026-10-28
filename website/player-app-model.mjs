/** Airlinerra player application: prelaunch read model and navigation contracts.
 * This module performs no network, database, mutation or storage operations.
 * Game records must come from a future verified server API, never from static previews.
 */
export const PLAYER_APP_PATH='/player.html';
export const PLAYER_LOGIN_PATH='/account.html?screen=sign-in';
export const PLAYER_VIEWS=Object.freeze([
  'overview','onboarding','profile','worlds','airports','fleet',
  'routes','schedule','finances','settings'
]);
const VIEW_SET=new Set(PLAYER_VIEWS);
export const WORLD_LABELS=Object.freeze([
  Object.freeze({id:1,name:'World 01',status:'Planned'}),
  Object.freeze({id:2,name:'World 02',status:'Planned'}),
  Object.freeze({id:3,name:'World 03',status:'Planned'})
]);
export function safePlayerView(hash){
  const candidate=typeof hash==='string'?hash.replace(/^#/u,''):'';
  return VIEW_SET.has(candidate)?candidate:'overview';
}
export function playerViewUrl(view){
  return PLAYER_APP_PATH+'#'+safePlayerView('#'+view);
}
/**
 * A newly authenticated manager lands on the airline creation wizard while
 * backend airline ownership is checked. A confirmed existing airline goes to
 * Overview. Non-landing routes (profile, airports, etc.) remain unchanged.
 */
export function managerLandingView({requestedView='overview',hasAirline=null}={}){
  const view=safePlayerView('#'+requestedView);
  if(view!=='overview'&&view!=='onboarding')return view;
  return hasAirline===true?'overview':'onboarding';
}
export function verifiedManagerIdentity(user){
  if(!user||typeof user.id!=='string'||typeof user.email!=='string'||
    !user.email_confirmed_at||user.is_anonymous===true||user.deleted_at){
    return null;
  }
  // User metadata is display-only; never use it for permissions or airline access.
  const raw=user.user_metadata?.display_name;
  const name=typeof raw==='string'&&raw.trim().length<=40&&raw.trim().length>=2
    ?raw.trim().replace(/[<>]/gu,''):null;
  return Object.freeze({
    email:user.email,
    name:name||'Invited manager',
    joined:typeof user.created_at==='string' && !Number.isNaN(Date.parse(user.created_at))
      ?new Date(user.created_at).toISOString().slice(0,10):null,
    verified:true
  });
}
export const AIRLINE_CREATION_ENABLED=false;
export const GAME_READ_API_CONNECTED=false;
export function onboardingReadiness({worlds,airports,legal,gate}={}){
  // Additional release switches are mandatory; no static world labels grant access.
  return Object.freeze({
    canCreate:Boolean(AIRLINE_CREATION_ENABLED&&GAME_READ_API_CONNECTED&&gate===true&&
      legal?.published===true&&Array.isArray(worlds)&&worlds.some(w=>w.state==='registration_open')&&
      Array.isArray(airports)&&airports.length>0),
    reason:'Game registration is closed while secure database services and legal documents are prepared.'
  });
}
