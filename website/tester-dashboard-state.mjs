/** Client-side view guard only. Real authorization remains with Supabase Auth. */
import {TESTER_ORIGIN,TESTER_AUTH_URL} from './invited-tester-entry.mjs';

export const PRIVATE_TESTER_DASHBOARD_PATH='/tester.html';
export const PRIVATE_TESTER_LOGIN_PATH='/account.html?screen=sign-in';

export class PrivateTesterAccessDenied extends Error {
  constructor(){super('A verified invited account is required.');this.name='PrivateTesterAccessDenied';}
}

export function isVerifiedInvitedUser(user){
  return Boolean(user && typeof user.id==='string' && user.id.length>0 &&
    typeof user.email==='string' && user.email.includes('@') &&
    typeof user.email_confirmed_at==='string' && user.email_confirmed_at.length>0 &&
    user.is_anonymous!==true && !user.deleted_at);
}

/** Never create a browser Auth client until the official host, public config,
 * and the hosted signup/anonymous/confirmation restrictions are checked.
 * Only return account details from Auth's freshly verified getUser() call.
 */
export async function openPrivateTesterDashboard({
  origin,pathname,config,inspectProvider,createAuth
}={}){
  if(origin!==TESTER_ORIGIN || pathname!==PRIVATE_TESTER_DASHBOARD_PATH ||
    config?.operatorPrelaunchApproved!==true ||
    config?.supabaseUrl!==TESTER_AUTH_URL ||
    !/^sb_publishable_[A-Za-z0-9_-]{16,128}$/.test(config?.publishableKey||'') ||
    typeof inspectProvider!=='function' || typeof createAuth!=='function'){
    throw new PrivateTesterAccessDenied();
  }
  await inspectProvider({publishableKey:config.publishableKey});
  const auth=await createAuth({
    origin:TESTER_ORIGIN,
    supabaseUrl:TESTER_AUTH_URL,
    publishableKey:config.publishableKey
  });
  if(typeof auth?.getUser!=='function'||typeof auth?.signOut!=='function'||
    auth.register!==undefined||auth.signUp!==undefined){
    throw new PrivateTesterAccessDenied();
  }
  const user=await auth.getUser();
  if(!isVerifiedInvitedUser(user)){
    await auth.signOut().catch(()=>{});
    throw new PrivateTesterAccessDenied();
  }
  return Object.freeze({auth,user});
}
