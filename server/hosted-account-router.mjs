/**
 * Airlinerra hosted Web Request adapter — NO listener, credentials, database,
 * automatic Netlify registration, or production deployment.
 *
 * A future approved host injects three previously constructed private HTTP
 * handlers. This adapter NEVER enables those independent handler/SQL gates.
 */
export const HOSTED_ACCOUNT_PATHS = Object.freeze([
  '/api/v1/onboarding/context',
  '/api/v1/legal/consents',
  '/api/v1/airlines'
]);
const ROUTES = new Set(HOSTED_ACCOUNT_PATHS);
const MAX_BODY_BYTES = 2048;
const HEADERS = Object.freeze({
  'content-type':'application/json; charset=utf-8',
  'cache-control':'no-store',
  'content-security-policy':"default-src 'none'",
  'x-content-type-options':'nosniff',
  'referrer-policy':'no-referrer',
  'x-frame-options':'DENY'
});

function result(status, payload, other={}) {
  return new Response(JSON.stringify(payload),{
    status,
    headers:{...HEADERS,...other}
  });
}
function secureOrigin(value) {
  if(typeof value!=='string' || !/^https:\/\/[A-Za-z0-9.-]+(?::[0-9]{2,5})?$/.test(value)) {
    throw new Error('Explicit HTTPS hosting origin required.');
  }
  const url=new URL(value);
  if(url.username || url.password || url.pathname!=='/' || url.search || url.hash ||
     ['localhost','127.0.0.1'].includes(url.hostname)) {
    throw new Error('Public HTTPS origin required; local testing uses separate gateway.');
  }
  return url.origin;
}

/** Reject large streamed bodies before buffering the whole request. */
async function smallBody(request) {
  const length=request.headers.get('content-length');
  if(length!==null && (!/^\d+$/.test(length) || Number(length)>MAX_BODY_BYTES)) {
    return null;
  }
  if(!request.body) return '';
  const reader=request.body.getReader();
  const chunks=[];
  let lengthBytes=0;
  try {
    while(true) {
      const {done,value}=await reader.read();
      if(done)break;
      lengthBytes+=value.byteLength;
      if(lengthBytes>MAX_BODY_BYTES) {
        await reader.cancel().catch(()=>{});
        return null;
      }
      chunks.push(value);
    }
    const bytes=new Uint8Array(lengthBytes);
    let offset=0;
    for(const chunk of chunks) {bytes.set(chunk,offset);offset+=chunk.byteLength;}
    return new TextDecoder('utf-8',{fatal:true}).decode(bytes);
  } finally {
    reader.releaseLock();
  }
}

export function createHostedAccountRouter({
  enabled=false,
  publicOrigin=null,
  handlers=null
}={}) {
  // Do not inspect/instantiate sensitive service handlers when disabled.
  if(!enabled) {
    return async () => result(503,{error:'Airlinerra account hosting is not available.'});
  }
  const origin=secureOrigin(publicOrigin);
  if(!handlers || typeof handlers!=='object' ||
     HOSTED_ACCOUNT_PATHS.some(path=>typeof handlers[path]!=='function')) {
    throw new Error('All three trusted account handlers are required.');
  }
  return async request=>{
    try {
      if(!(request instanceof Request))return result(400,{error:'Invalid request.'});
      const url=new URL(request.url);
      if(!ROUTES.has(url.pathname)||url.search||url.hash) {
        return result(404,{error:'Not found.'});
      }
      if(request.method!=='POST') {
        return result(405,{error:'Method not allowed.'},{allow:'POST'});
      }
      if(url.origin!==origin || request.headers.get('origin')!==origin) {
        return result(403,{error:'Origin not approved.'});
      }
      if(request.headers.get('content-type')!=='application/json') {
        return result(415,{error:'JSON required.'});
      }
      const body=await smallBody(request);
      if(body===null)return result(413,{error:'Request body too large.'});
      // This adapter is transport-only: services must independently verify
      // Auth, legal publication, operator airports, open worlds and release.
      const upstream=await handlers[url.pathname]({
        path:url.pathname,
        method:request.method,
        headers:Object.fromEntries(request.headers.entries()),
        body
      });
      if(!upstream || !Number.isInteger(upstream.status) ||
         upstream.status<200 || upstream.status>599 ||
         typeof upstream.body!=='string' || upstream.body.length>32768) {
        throw new Error('Unexpected account handler result.');
      }
      // Allow-listed response headers only: never trust handler CORS headers.
      return new Response(upstream.body,{
        status:upstream.status,
        headers:{
          ...HEADERS,
          ...(upstream.status===405?{allow:'POST'}:{})
        }
      });
    }catch{
      return result(503,{error:'Airlinerra account service unavailable.'});
    }
  };
}
