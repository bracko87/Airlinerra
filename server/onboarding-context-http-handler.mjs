/**
 * Private POST /api/v1/onboarding/context handler.
 * Auth is freshly verified; no research records or mutations are exposed.
 */
const PATH='/api/v1/onboarding/context';
const RESP_HEADERS=Object.freeze({
  'content-type':'application/json; charset=utf-8','cache-control':'no-store',
  'x-content-type-options':'nosniff'
});
const result=(status,value)=>Object.freeze({
  status,headers:RESP_HEADERS,body:JSON.stringify(value)
});
export function createOnboardingContextHttpHandler({
  contextService, allowedOrigins=[], enabled=false
}={}) {
  if(typeof contextService?.getContext!=='function'){
    throw new Error('Private context service required.');
  }
  const origins=new Set(allowedOrigins);
  return async request=>{
    if(request.path!==PATH)return result(404,{error:'Not found.'});
    if(request.method!=='POST')return result(405,{error:'Method not allowed.'});
    if(!enabled)return result(503,{error:'Onboarding is unavailable.'});
    if(!origins.has(request.headers?.origin))return result(403,{error:'Origin denied.'});
    if(request.headers?.['content-type']!=='application/json')return result(415,{error:'JSON required.'});
    if(request.body!=='{}')return result(400,{error:'Unexpected context request body.'});
    const bearer=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/.exec(
      request.headers?.authorization||'');
    if(!bearer)return result(401,{error:'Verified account required.'});
    try {
      const context=await contextService.getContext({accessToken:bearer[1]});
      return result(200,context);
    } catch {
      return result(503,{error:'Onboarding is unavailable.'});
    }
  };
}
