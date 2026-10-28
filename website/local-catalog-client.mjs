/** Browser-only local snapshot adapter. Production domain can never activate this. */
import {isLocalDemoOrigin} from './local-demo-session.mjs';
export function createLocalCatalogClient({location,fetchImpl=(...args)=>fetch(...args)}={}){
 if(!isLocalDemoOrigin(location))throw Error('Local catalog requires loopback preview');
 const origin=location.origin;
 async function post(route,data){
  if(!['/__local_player__/overview','/__local_player__/airports'].includes(route))
    throw Error('Unknown local route');
  const response=await fetchImpl(origin+route,{
    method:'POST',mode:'same-origin',credentials:'omit',cache:'no-store',redirect:'error',
    headers:{'content-type':'application/json'},body:JSON.stringify(data)
  });
  if(!response.ok)throw Error('Local catalog unavailable');
  const result=await response.json();
  if(!result?.readOnly||result.mode!=='local-approved-airport-snapshot')
    throw Error('Unexpected local catalog mode');
  return result;
 }
 return Object.freeze({
  overview:()=>post('/__local_player__/overview',{}),
  airports:({countryIso,search='',offset=0,airportKey=null})=>post('/__local_player__/airports',{countryIso,search,offset,airportKey})
 });
}
