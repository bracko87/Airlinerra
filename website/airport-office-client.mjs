/** Browser API for server-owned airport office drafts.
 * OFF by default. Never writes directly to Supabase, never moves local drafts.
 */
export const AIRPORT_OFFICE_DRAFT_API_ENABLED=false;
const ORIGINS=new Set(['https://airlinerra.com','http://localhost:5188']);
const KEY=/^(?:OURAIRPORTS:[1-9]\d{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
export function createAirportOfficeClient({auth,origin,enabled=AIRPORT_OFFICE_DRAFT_API_ENABLED,
 local=false,fetchImpl=(...args)=>fetch(...args)}={}){
 if(!ORIGINS.has(origin)||(origin==='http://localhost:5188'&&!local)||
  typeof auth?.getAccessToken!=='function'||typeof fetchImpl!=='function')
   throw Error('Verified private office API is required.');
 async function send(data){
  if(enabled!==true)throw Error('Airport office server drafts are not enabled.');
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)throw Error('Office session expired.');
  const response=await fetchImpl(origin+'/api/v1/player/airport-offices',{
   method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},
   body:JSON.stringify(data),cache:'no-store',credentials:'omit',
   mode:'same-origin',referrerPolicy:'no-referrer',redirect:'error'
  });
  if(!response.ok){
   if(response.status===401)throw Error('Your session expired. Please sign in again.');
   if(response.status===409)throw Error('The office proposal cannot be saved or has changed.');
   throw Error('Airport office server unavailable. Your local drafts were not changed.');
  }
  const value=await response.json();
  if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Invalid office server response.');
  return value;
 }
 function world(value){
  if(!Number.isSafeInteger(value)||value<1||value>3)throw Error('Invalid game world.');
  return value;
 }
 function airport(key){
  if(typeof key!=='string'||!KEY.test(key))throw Error('Invalid airport key.');
  return key;
 }
 return Object.freeze({
  async list({worldId}={}){
   const result=await send({operation:'list',worldId:world(worldId)});
   if(!Array.isArray(result.offices)||result.offices.length>20||
    result.offices.some(o=>!o||!KEY.test(o.key||'')||
     !['hub','station'].includes(o.type)||o.status!=='draft'||typeof o.name!=='string'))
     throw Error('Invalid office directory response.');
   return result.offices;
  },
  async save({worldId,airportKey,type}={}){
   if(!['hub','station'].includes(type))throw Error('Invalid office type.');
   const result=await send({operation:'save',worldId:world(worldId),airportKey:airport(airportKey),type});
   if(result.office?.key!==airportKey||result.office.type!==type||result.office.status!=='draft')
    throw Error('Invalid office save response.');
   return result.office;
  },
  async remove({worldId,airportKey}={}){
   const result=await send({operation:'remove',worldId:world(worldId),airportKey:airport(airportKey)});
   if(typeof result.removed!=='boolean')throw Error('Invalid office removal response.');
   return result.removed;
  }
 });
}
