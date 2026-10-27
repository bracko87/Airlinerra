/**
 * Operator-only preview API guard for staged Netlify Functions.
 *
 * The production website must remain public while an isolated, nonproduction
 * API endpoint is protected by a separate high-entropy secret header.
 * Never put the preview secret in static JS, a URL, GitHub, or netlify.toml.
 *
 * The in-memory request budget is a defense in depth, NOT a substitute
 * for a provider-wide edge/WAF rate limit: serverless instances are isolated.
 */
import {createHash,timingSafeEqual} from 'node:crypto';

const ALLOWED_PATHS=new Set([
  '/api/v1/onboarding/context',
  '/api/v1/legal/consents',
  '/api/v1/airlines'
]);
export const PREVIEW_ACCESS_HEADER='x-airlinerra-preview-access';
const KEY_PATTERN=/^[A-Za-z0-9_-]{43,128}$/u;
const INTERVAL_MS=60_000;
const MAX_PER_WINDOW=30;
const MAX_IN_FLIGHT=4;

function matchesSecret(provided,expected){
  if(typeof expected!=='string' || !KEY_PATTERN.test(expected) ||
     typeof provided!=='string' || !KEY_PATTERN.test(provided)){
    return false;
  }
  // SHA-256 gives a uniform, fixed-length comparison even if the strings
  // differ in length. Never log either string or its digest.
  const a=createHash('sha256').update(provided,'utf8').digest();
  const b=createHash('sha256').update(expected,'utf8').digest();
  return timingSafeEqual(a,b);
}

function validPreviewOrigin(env,request){
  const canonical=env.AIRLINERRA_HOSTED_RUNTIME_MODE==='canonical-prelaunch-test';
  const origin=canonical
    ? env.AIRLINERRA_CANONICAL_TEST_ORIGIN
    : env.AIRLINERRA_PREVIEW_ORIGIN;
  if(typeof origin!=='string' || !(request instanceof Request))return false;
  let target,source;
  try{
    target=new URL(origin);
    source=new URL(request.url);
  }catch{return false;}
  if(target.protocol!=='https:' || target.port || target.pathname!=='/' ||
     target.search || target.hash || target.username || target.password ||
     source.origin!==target.origin || request.headers.get('origin')!==target.origin ||
     !ALLOWED_PATHS.has(source.pathname) || source.search || source.hash ||
     request.method!=='POST' ||
     request.headers.get('content-type')!=='application/json'){
    return false;
  }
  const hostname=target.hostname;
  if(canonical){
    // Production requires a separate prelaunch operator opt-in AND key.
    // A private preview credential must never authorize the canonical site.
    return env.CONTEXT==='production' &&
      env.AIRLINERRA_CANONICAL_PRELAUNCH_TEST_APPROVED==='true' &&
      origin==='https://airlinerra.com';
  }
  if(env.CONTEXT==='deploy-preview'){
    return /^deploy-preview-[1-9][0-9]*--airlinerra\.netlify\.app$/u.test(hostname);
  }
  if(env.CONTEXT==='branch-deploy'){
    return /^[a-z0-9][a-z0-9-]*--airlinerra\.netlify\.app$/u.test(hostname) &&
      !hostname.startsWith('deploy-preview-') &&
      hostname!=='main--airlinerra.netlify.app';
  }
  return false;
}

/**
 * One state per warm Netlify instance. acquire() synchronously reserves
 * capacity before database initialization; callers MUST release in finally.
 */
export function createPreviewRequestGate({now=()=>Date.now()}={}){
  if(typeof now!=='function')throw new Error('A monotonic clock adapter is required.');
  let windowStart=null;
  let requests=0;
  let inFlight=0;

  function acquire(env,request){
    if(!env || !validPreviewOrigin(env,request) ||
       !matchesSecret(request.headers.get(PREVIEW_ACCESS_HEADER),
         env.AIRLINERRA_HOSTED_RUNTIME_MODE==='canonical-prelaunch-test'
           ? env.AIRLINERRA_CANONICAL_TEST_ACCESS_SECRET
           : env.AIRLINERRA_PREVIEW_ACCESS_SECRET)){
      return {allowed:false,status:503};
    }
    const stamp=now();
    if(!Number.isFinite(stamp))return {allowed:false,status:503};
    if(windowStart===null || stamp<windowStart || stamp-windowStart>=INTERVAL_MS){
      windowStart=stamp;
      requests=0;
    }
    if(requests>=MAX_PER_WINDOW || inFlight>=MAX_IN_FLIGHT){
      return {allowed:false,status:429};
    }
    requests++;
    inFlight++;
    const headers=new Headers(request.headers);
    headers.delete(PREVIEW_ACCESS_HEADER);
    let forwarded;
    try{
      // Strip the preview-only credential before trusted business services.
      forwarded=new Request(request,{headers});
    }catch{
      inFlight--;
      return {allowed:false,status:503};
    }
    let released=false;
    return {
      allowed:true,
      request:forwarded,
      release(){
        if(!released){released=true;inFlight--;}
      }
    };
  }
  return Object.freeze({acquire});
}
