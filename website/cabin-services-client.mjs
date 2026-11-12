/** Same owner-verified cabin settings API for production and trusted localhost preview.
 * Neither path purchases flights, changes aircraft or posts money.
 */
import {CABIN_DATA_SCHEMA_ID} from './cabin-services-manager.mjs';
export const CABIN_API_ROUTE='/api/v1/player/cabin-services';
export function createCabinServicesClient({auth,origin,fetchImpl=(...a)=>fetch(...a)}={}){
 if(!['https://airlinerra.com','http://localhost:5188'].includes(origin)||
    typeof auth?.getAccessToken!=='function'||
    typeof fetchImpl!=='function')throw Error('Verified trusted-origin cabin client required');
 const post=async body=>{
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)throw Error('CABIN_AUTH_REQUIRED');
  const res=await fetchImpl(origin+CABIN_API_ROUTE,{method:'POST',headers:{
   'content-type':'application/json',authorization:'Bearer '+token},
   body:JSON.stringify(body),cache:'no-store',redirect:'error',credentials:'omit',
   mode:'same-origin',referrerPolicy:'no-referrer'});
  if(res.status===409)throw Error('CABIN_VERSION_CONFLICT');
  if(res.status===401||res.status===403)throw Error('CABIN_AUTH_REQUIRED');
  if(!res.ok)throw Error('CABIN_HTTP_'+res.status);
  const data=await res.json();
  if(data?.schemaId!==CABIN_DATA_SCHEMA_ID)throw Error('CABIN_SCHEMA_MISMATCH');
  if(data?.source!=='supabase'||!Number.isInteger(data.version)||data.version<0||
     data.operational!==false||!data.state)throw Error('Invalid cabin response');
  return data;
 };
 return Object.freeze({
  read:airlineId=>post({action:'read',airlineId}),
  save:({airlineId,state,expectedVersion})=>post({action:'save',airlineId,state,expectedVersion})
 });
}
