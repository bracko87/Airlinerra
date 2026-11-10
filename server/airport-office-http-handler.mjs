/** Fail-closed HTTP bridge for authenticated private airport-office drafts.
 * This file does NOT deploy a route or enable the feature flag.
 */
export const AIRPORT_OFFICE_API_PATH='/api/v1/player/airport-offices';
const ORIGINS=new Set(['http://localhost:5188','https://airlinerra.com']);
const AIRPORT_KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const BEARER=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const HEADERS=Object.freeze({
 'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'content-security-policy':"default-src 'none'",
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'
});
const reply=(status,body)=>Object.freeze({status,headers:HEADERS,body:JSON.stringify(body)});
function header(headers,name){
 const key=Object.keys(headers||{}).find(k=>k.toLowerCase()===name);
 return key&&typeof headers[key]==='string'?headers[key]:null;
}
export function parseOfficeRequest(body){
 if(typeof body!=='string'||new TextEncoder().encode(body).byteLength>512)throw Error('Invalid or oversized request.');
 let value;
 try{value=JSON.parse(body)}catch{throw Error('Invalid JSON request.')}
 if(!value||Array.isArray(value)||typeof value!=='object')throw Error('Invalid request.');
 const fields=Object.keys(value),allowed=['operation','worldId','airportKey','type'];
 if(fields.some(k=>!allowed.includes(k))||typeof value.operation!=='string'||
  !['list','save','remove'].includes(value.operation)||!Number.isSafeInteger(value.worldId)||
  value.worldId<1||value.worldId>3)throw Error('Invalid office operation.');
 const expected=value.operation==='list'?['operation','worldId']:
  value.operation==='save'?['operation','worldId','airportKey','type']:
   ['operation','worldId','airportKey'];
 if(fields.length!==expected.length||expected.some(k=>!Object.hasOwn(value,k)))throw Error('Invalid office fields.');
 if(value.operation!=='list'&&(typeof value.airportKey!=='string'||!AIRPORT_KEY.test(value.airportKey)))
  throw Error('Invalid airport key.');
 if(value.operation==='save'&&!['hub','station'].includes(value.type))throw Error('Invalid office type.');
 return Object.freeze(value);
}
export function createAirportOfficeHttpHandler({officeService,origin,enabled=false}={}){
 if(!ORIGINS.has(origin)||!officeService||['list','save','remove'].some(k=>typeof officeService[k]!=='function'))
  throw Error('Private airport office service and approved origin required.');
 return async function handle(request={}){
  if(request.path!==AIRPORT_OFFICE_API_PATH)return reply(404,{error:'Not found.'});
  if(request.method!=='POST')return reply(405,{error:'Method not allowed.'});
  if(!enabled)return reply(503,{error:'Airport office drafts are not enabled.'});
  if(header(request.headers,'origin')!==origin)return reply(403,{error:'Origin not allowed.'});
  if(header(request.headers,'content-type')!=='application/json')return reply(415,{error:'JSON only.'});
  const token=BEARER.exec(header(request.headers,'authorization')||'')?.[1];
  if(!token)return reply(401,{error:'Verified session required.'});
  let input;
  try{input=parseOfficeRequest(request.body)}
  catch(error){return reply(error.message.includes('oversized')?413:400,{error:'Invalid office request.'})}
  try{
   if(input.operation==='list'){
    const offices=await officeService.list({accessToken:token,worldId:input.worldId});
    return reply(200,{offices});
   }
   if(input.operation==='save'){
    const office=await officeService.save({accessToken:token,worldId:input.worldId,
     airportKey:input.airportKey,type:input.type});
    return reply(office.newlyCreated?201:200,{office});
   }
   const result=await officeService.remove({accessToken:token,worldId:input.worldId,
    airportKey:input.airportKey});
   return reply(200,result);
  }catch(error){
   if(error?.code==='UNAUTHENTICATED'||/verified player authentication/i.test(error?.message||''))
    return reply(401,{error:'Verified session required.'});
   if(error?.code==='AIRLINE_NOT_FOUND')return reply(404,{error:'No registered airline in this world.'});
   if(['INVALID_OFFICE','OFFICE_CONFLICT','OFFICE_LIMIT','INVALID_AIRPORT','INVALID_TYPE','INVALID_WORLD'].includes(error?.code))
    return reply(409,{error:'Office proposal is not eligible.'});
   if(error?.code==='23505')return reply(409,{error:'Office already exists.'});
   return reply(503,{error:'Airport office service unavailable.'});
  }
 };
}
