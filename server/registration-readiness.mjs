/** Same database as the production game; public response exposes ONLY release readiness.
 * This is a read-only preflight for NEW users who do not yet have an Auth token.
 * No identity, configuration secrets or player records are returned.
 */
export const REGISTRATION_READINESS_PATH='/api/v1/registration/readiness';
export const REGISTRATION_READINESS_SQL=[
  'select',
  '(select coalesce(bool_or(enabled),false) from airlinerra_game.platform_release_gate where id=true) as gate_on,',
  '(select exists(select 1 from airlinerra_game.legal_release_policy',
  'where id=true and is_published=true and approved_at is not null',
  'and nullif(terms_version,\'\') is not null and nullif(privacy_version,\'\') is not null)) as legal_on,',
  '(select exists(select 1 from public.airlinerra_game_worlds',
  'where id=1 and state in (\'registration_open\',\'active\'))) as world_on,',
  '(select exists(select 1 from airlinerra_game.approved_game_airports',
  'where world_id=1)) as airports_on,',
  '(select exists(select 1 from airlinerra_game.owner_premium_email_reservations)) as owner_pilot_on'
].join(' ');
const HEADERS={
 'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer',
 'content-security-policy':"default-src 'none'"
};
function respond(status,payload){return new Response(JSON.stringify(payload),{status,headers:HEADERS});}
export function createRegistrationReadinessHandler({database,origin='http://localhost:5188'}={}){
 if(!database||typeof database.connect!=='function')throw Error('Private DB pool required');
 return async function handle(request){
  if(!(request instanceof Request))return respond(400,{error:'Invalid request'});
  const url=new URL(request.url);
  if(url.origin!==origin)return respond(403,{error:'Forbidden'});
  if(url.pathname!==REGISTRATION_READINESS_PATH||url.search||url.hash)return respond(404,{error:'Not found'});
  if(request.method!=='GET')return respond(405,{error:'Method not allowed'});
  let connection;
  try{
   connection=await database.connect();
   const result=await connection.query(REGISTRATION_READINESS_SQL);
   if(!Array.isArray(result.rows)||result.rows.length!==1)throw Error('Missing release status');
   const p=result.rows[0];
   const flags=[p.gate_on,p.legal_on,p.world_on,p.airports_on];
   if(!flags.every(x=>typeof x==='boolean'))throw Error('Invalid release status');
   return respond(200,{
    registrationReady:flags.every(Boolean),
    privateOwnerPilotAvailable:p.owner_pilot_on===true && p.airports_on===true,
    requiresLegalApproval:!p.legal_on,
    world1RegistrationOpen:p.world_on,
    flightsEnabled:false
   });
  }catch{
   return respond(503,{error:'Registration readiness unavailable'});
  }finally{try{connection?.release();}catch{/* no credential logs */}}
 };
}
