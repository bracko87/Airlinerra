/** Simulated, per-tab registration rehearsal: no Supabase, no mail delivery, no password persistence. */
const KEY='airlinerra-local-registration-flow-v1';
export const DEMO_MAIL_DOMAIN='example.test';
export function validTestEmail(email){
 return typeof email==='string'&&email.length<=100&&
 /^[a-z0-9._%+-]+@example\.test$/iu.test(email);
}
export function validTestName(name){
 return typeof name==='string'&&name.trim().length>=2&&name.trim().length<=50&&
 /^[\p{L}\p{M}\p{N} .'\-]+$/u.test(name.trim());
}
export function loadAttempt(storage){
 try{
  const raw=JSON.parse(storage.getItem(KEY)||'null');
  if(raw?.version!==1||!validTestEmail(raw.email)||!validTestName(raw.name)||
    typeof raw.token!=='string'||!/^[a-f0-9]{32}$/u.test(raw.token)||
    typeof raw.emailConfirmed!=='boolean'||typeof raw.passwordStepComplete!=='boolean')return null;
  return raw;
 }catch{return null}
}
export function startAttempt(storage,{name,email,token}){
 const identity={name:name.trim(),email:email.trim().toLowerCase()};
 if(!validTestName(identity.name)||!validTestEmail(identity.email)||!(/^[a-f0-9]{32}$/u.test(token)))
  throw Error('Use a demo name and an @example.test address');
 const value={version:1,...identity,token,emailConfirmed:false,passwordStepComplete:false};
 storage.setItem(KEY,JSON.stringify(value));
 return value;
}
export function confirmAttempt(storage,token){
 const value=loadAttempt(storage);
 if(!value||token!==value.token)return null;
 const updated={...value,emailConfirmed:true};
 storage.setItem(KEY,JSON.stringify(updated));
 return updated;
}
export function completePasswordStep(storage,password,repeated){
 const value=loadAttempt(storage);
 if(!value?.emailConfirmed)throw Error('Confirm your simulated email first');
 if(typeof password!=='string'||password.length<8||password.length>128||
   password!==repeated)throw Error('Use matching sample passwords of 8–128 characters');
 // Password is NEVER returned or saved, even to sessionStorage.
 const updated={...value,passwordStepComplete:true};
 storage.setItem(KEY,JSON.stringify(updated));
 return updated;
}
export function clearAttempt(storage){storage.removeItem(KEY)}
