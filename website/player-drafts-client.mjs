/** Owner-authenticated persistent game draft client.
 * Does not store game data in the browser or authorize gameplay actions.
 */
export const PLAYER_DRAFTS_ROUTE='/api/v1/player/workspace-drafts';
export function createPlayerDraftsClient({
 auth,origin,fetchImpl=globalThis.fetch
}={}){
 if(!['https://airlinerra.com','http://localhost:5188'].includes(origin)||
  typeof auth?.getAccessToken!=='function'||typeof fetchImpl!=='function')
  throw Error('Verified Airlinerra owner drafts client required');
 const call=async body=>{
  const token=await auth.getAccessToken();
  if(typeof token!=='string'||token.length<16)throw Error('WORKSPACE_AUTH_REQUIRED');
  const resp=await fetchImpl(origin+PLAYER_DRAFTS_ROUTE,{
   method:'POST',
   headers:{authorization:'Bearer '+token,'content-type':'application/json'},
   body:JSON.stringify(body),cache:'no-store',redirect:'error',
   credentials:'omit',mode:'same-origin',referrerPolicy:'no-referrer'
  });
  if(resp.status===409)throw Error('WORKSPACE_VERSION_CONFLICT');
  if(!resp.ok)throw Error('WORKSPACE_HTTP_'+resp.status);
  const data=await resp.json();
  if(data?.source!=='supabase'||data.operational!==false||
   data.kind!==body.kind||!Number.isInteger(data.version)||data.version<0||
   !data.state||typeof data.state!=='object'||Array.isArray(data.state))
   throw Error('Unverified workspace data');
  return data;
 };
 return Object.freeze({
  read:({airlineId,kind})=>call({action:'read',airlineId,kind}),
  save:({airlineId,kind,state,expectedVersion})=>
   call({action:'save',airlineId,kind,state,expectedVersion})
 });
}
