/** Authenticated purchase / lease market for individual airline-owned aircraft.
 * Prices are only those published on the private server, never client-computed.
 */
export const FLEET_ACQUISITION_API_ROUTE='/api/v1/player/fleet-acquisition';
export function createFleetAcquisitionClient({auth,origin,fetchImpl=(...a)=>fetch(...a)}={}){
 if(origin!=='https://airlinerra.com'||typeof auth?.getAccessToken!=='function'||
   typeof fetchImpl!=='function')throw Error('Verified production fleet client required');
 const pending=new Map();
 async function post(payload){
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)throw Error('Verified session required');
  const response=await fetchImpl(origin+FLEET_ACQUISITION_API_ROUTE,{
   method:'POST',
   headers:{'content-type':'application/json',authorization:'Bearer '+token},
   body:JSON.stringify(payload),cache:'no-store',redirect:'error',
   credentials:'omit',mode:'same-origin',referrerPolicy:'no-referrer'
  });
  if(response.status===401)throw Error('FLEET_AUTH_REQUIRED');
  if(response.status===403)throw Error('FLEET_AIRLINE_NOT_OWNED');
  if(response.status===409){
   const error=await response.json().catch(()=>({}));
   throw Error('FLEET_CONFLICT_'+String(error.reason||'ORDER_UNAVAILABLE').replace(/[^A-Z0-9_]/gi,'_').slice(0,100));
  }
  if(!response.ok)throw Error('FLEET_HTTP_'+response.status);
  const data=await response.json();
  if(!data||typeof data!=='object'||Array.isArray(data))throw Error('Invalid fleet response');
  return data;
 }
 return Object.freeze({
  list:airlineId=>post({action:'list',airlineId}),
  checkDelivery:({airlineId,orderId})=>post({action:'check-delivery',airlineId,orderId}),
  acquire:async({airlineId,offerId,registration,requestId})=>{
   const normalized=String(registration||'').trim().toUpperCase();
   const key=String(airlineId)+'|'+String(offerId)+'|'+normalized;
   const id=requestId||pending.get(key)||globalThis.crypto?.randomUUID?.();
   if(typeof id!=='string')throw Error('Secure request ID unavailable');
   pending.set(key,id);
   const reply=await post({action:'acquire',airlineId,offerId,registration:normalized,requestId:id});
   pending.delete(key);
   return reply;
  }
 });
}
