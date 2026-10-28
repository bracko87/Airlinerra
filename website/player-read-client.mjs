/** Read-only browser bridge. No direct database API or credential persistence. */
export const PLAYER_READ_API_ENABLED=false;
export function createPlayerReadClient({auth,origin,enabled=PLAYER_READ_API_ENABLED,local=false,
 fetchImpl=(...args)=>fetch(...args)}={}){
 if(!(origin==='https://airlinerra.com'||(local&&origin==='http://localhost:5188'))||typeof auth?.getAccessToken!=='function'||
   typeof fetchImpl!=='function')throw Error('Private player read client requires verified hosted Auth');
 async function post(path,payload){
   if(!enabled)throw Error('Player database API is not deployed.');
   if(!['/api/v1/player/overview','/api/v1/player/airports'].includes(path))
     throw Error('Invalid player data route');
   const token=await auth.getAccessToken();
   if(typeof token!=='string'||token.length<16)throw Error('Verified session required');
   const response=await fetchImpl(origin+path,{
     method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+token},
     body:JSON.stringify(payload),cache:'no-store',redirect:'error',credentials:'omit',
     mode:'same-origin',referrerPolicy:'no-referrer'
   });
   if(response.status===401)throw Error('Session expired');
   if(!response.ok)throw Error('Player database service unavailable');
   const data=await response.json();
   if(!data||typeof data!=='object'||Array.isArray(data))throw Error('Invalid player data response');
   return data;
 }
 return Object.freeze({
   overview:()=>post('/api/v1/player/overview',{}),
   airports:({countryIso,search='',offset=0})=>post('/api/v1/player/airports',{countryIso,search,offset})
 });
}
