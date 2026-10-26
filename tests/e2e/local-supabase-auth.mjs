/**
 * TRUE local-stack Auth integration: GoTrue + Mailpit via real HTTP.
 * Never contacts Supabase Cloud, sends real email, or creates public players.
 * Runs only in a disposable GitHub runner with Supabase CLI local services.
 */
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { parseAuthCallback, createAuthService } from '../../website/auth-service.mjs';

const API='http://127.0.0.1:54321';
const MAIL='http://127.0.0.1:54324';
const ORIGIN='http://localhost:5187';
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const RESEARCH_REF='hwllkabgzaynalahvkpz';
const getJson=async(response,context)=>{
  let value;
  try { value=await response.json(); }
  catch { throw new Error(context+': invalid JSON ('+response.status+')'); }
  if (!response.ok) {
    // Never report passwords, verification hashes, JWTs or full provider responses.
    throw new Error(context+': HTTP '+response.status+' '+String(value?.error_code||value?.code||''));
  }
  return value;
};
function localCredentials(){
  const raw=execFileSync('supabase',['status','-o','json'],{
    encoding:'utf8',timeout:20000,stdio:['ignore','pipe','pipe']
  });
  const data=JSON.parse(raw);
  const entries=Object.entries(data).map(([key,value])=>[key.toLowerCase(),value]);
  const pick=(...keys)=>entries.find(([k])=>keys.some(x=>x===k))?.[1];
  const key=pick('publishable_key','anon_key','publishablekey');
  if (typeof key!=='string'||!key.startsWith('sb_publishable_')) {
    throw new Error('Local CLI did not expose a publishable API key.');
  }
  const url=pick('api_url','apiurl');
  if (url!==API) throw new Error('Refusing nonlocal Supabase API endpoint.');
  if (JSON.stringify(data).includes(RESEARCH_REF)) throw new Error('Research project forbidden.');
  return {key};
}
async function rest(url,route,key,body,{method='POST',accessToken}={}){
  if (url!==API) throw new Error('Only local Supabase is permitted.');
  const res=await fetch(url+'/auth/v1/'+route,{
    method,signal:AbortSignal.timeout(12000),
    headers:{'content-type':'application/json',apikey:key,
      ...(accessToken?{authorization:'Bearer '+accessToken}:{})},
    ...(body===undefined?{}:{body:JSON.stringify(body)})
  });
  if(!res.ok){
    const payload=await res.json().catch(()=>({}));
    return {data:null,error:{status:res.status,code:payload.error_code||payload.code||'auth_error'}};
  }
  const data=res.status===204?{}:await getJson(res,'Auth '+route);
  return {data,error:null};
}
function authAdapter(key){
  let session=null;
  const hold=result=>{
    if(result.data?.access_token){
      const obj=result.data;
      session={access_token:obj.access_token,refresh_token:obj.refresh_token,
        user:obj.user};
    }
    return result;
  };
  return Object.freeze({
    signUp:async({email,password,options})=>{
      return rest(API,'signup?redirect_to='+encodeURIComponent(options.emailRedirectTo),key,{
        email,password,data:options.data
      });
    },
    signInWithPassword:async({email,password})=>{
      const result=hold(await rest(API,'token?grant_type=password',key,{email,password}));
      return {error:result.error,data:result.data?{user:result.data.user,session}:null};
    },
    resetPasswordForEmail:async(email,options)=>{
      return rest(API,'recover?redirect_to='+encodeURIComponent(options.redirectTo),key,{email});
    },
    verifyOtp:async({token_hash,type})=>{
      const result=hold(await rest(API,'verify',key,{token_hash,type}));
      return {error:result.error,data:result.data?{session,user:result.data.user}:null};
    },
    getUser:async()=>{
      if(!session?.access_token)return {data:{user:null},error:{code:'no_session'}};
      const result=await rest(API,'user',key,undefined,{
        method:'GET',accessToken:session.access_token
      });
      return {data:{user:result.data},error:result.error};
    },
    updateUser:async({password})=>{
      if(!session?.access_token)return {error:{code:'no_session'}};
      return rest(API,'user',key,{password},{
        method:'PUT',accessToken:session.access_token
      });
    },
    signOut:async({scope})=>{
      if(!session?.access_token)return {error:null};
      const result=await rest(API,'logout?scope='+encodeURIComponent(scope||'local'),
        key,undefined,{accessToken:session.access_token});
      session=null;
      return {error:result.error};
    }
  });
}
async function mailFor(email,marker,seen=new Set()){
  const stop=Date.now()+95000;
  while(Date.now()<stop){
    let listing;
    try{
      const response=await fetch(MAIL+'/api/v1/messages',{signal:AbortSignal.timeout(3500)});
      if(response.ok)listing=await response.json();
    }catch{}
    for(const item of listing?.messages||[]){
      if(!item.ID||seen.has(item.ID))continue;
      const recipients=JSON.stringify(item.To||[]).toLowerCase();
      if(!recipients.includes(email.toLowerCase()))continue;
      if(!String(item.Subject||'').toLowerCase().includes(marker.toLowerCase()))continue;
      const message=await getJson(await fetch(MAIL+'/api/v1/message/'+
        encodeURIComponent(item.ID),{signal:AbortSignal.timeout(3500)}),'Mailpit message');
      const html=message.HTML||message.Html||message.html||'';
      const link=html.match(/href=["']([^"']+)["']/i)?.[1]
        ?.replace(/&amp;/g,'&');
      assert.ok(link,'Email template must contain a usable callback link.');
      const url=new URL(link);
      assert.equal(url.origin,ORIGIN,'No email link may lead to public app');
      seen.add(item.ID);
      return {url,seen};
    }
    await delay(1200);
  }
  throw new Error('Mailpit did not deliver '+marker+' message to synthetic test inbox');
}
async function run(){
  const {key}=localCredentials();
  const email='airlinerra-ci-'+randomBytes(7).toString('hex')+'@example.test';
  const originalPassword='A1-'+randomBytes(18).toString('hex');
  const nextPassword='B2-'+randomBytes(18).toString('hex');
  const auth=authAdapter(key);
  const client=createAuthService({supabase:{auth},origin:ORIGIN,enabled:true});
  const signup=await client.register({
    email,password:originalPassword,displayName:'CI Synthetic Manager',termsAccepted:true
  });
  assert.match(signup.message,/check your email/i);
  let {url,seen}=await mailFor(email,'confirm');
  const verification=parseAuthCallback(url.search,'verify');
  assert.equal(verification.kind,'otp');
  assert.equal(verification.type,'email');
  await client.completeCallback(verification);
  const firstUser=await client.getUser();
  assert.equal(firstUser?.email,email);
  assert.ok(firstUser.email_confirmed_at,'Local Auth must require real verification');
  console.log('PASS: real signup and Mailpit confirmation (synthetic account).');

  const signedIn=await client.signIn({email,password:originalPassword});
  assert.equal(signedIn.user.id,firstUser.id);
  console.log('PASS: real verified password login.');

  await delay(1500);
  await client.requestPasswordReset(email);
  ({url,seen}=await mailFor(email,'reset',seen));
  const recovery=parseAuthCallback(url.search,'reset');
  assert.equal(recovery.kind,'otp');
  assert.equal(recovery.type,'recovery');
  await client.completeCallback(recovery);
  await client.updatePassword(nextPassword);
  await assert.rejects(client.updatePassword(nextPassword),/verified password recovery/);
  console.log('PASS: real recovery OTP and one-use password update.');

  const denied=await auth.signInWithPassword({email,password:originalPassword});
  assert.ok(denied.error,'Old password must be invalid');
  const fresh=await client.signIn({email,password:nextPassword});
  assert.equal(fresh.user.id,firstUser.id);
  await client.signOut();
  console.log('PASS: old password denied, new password accepted.');
  console.log('All local Supabase Auth + Mailpit stages passed. No cloud services used.');
}
run().catch(error=>{
  console.error('LOCAL AUTH E2E FAILED: '+String(error.message).slice(0,350));
  process.exitCode=1;
});
