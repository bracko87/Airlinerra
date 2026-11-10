/** Secure World 1 aircraft purchase/lease market, server-side only.
 * Monetary price, airline ownership and registration checks live in PostgreSQL.
 * This service never activates live flights.
 */
export const FLEET_ACQUISITION_API_ROUTE='/api/v1/player/fleet-acquisition';
const ORIGIN='https://airlinerra.com';
const BEARER=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const REGISTRATION=/^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$/u;
const HEADERS={'content-type':'application/json; charset=utf-8','cache-control':'no-store',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
const respond=(status,value)=>Response.json(value,{status,headers:HEADERS});
const uuid=value=>typeof value==='string'&&UUID.test(value);
export function validateFleetAcquisitionRequest(body){
 if(!body||typeof body!=='object'||Array.isArray(body)||
    typeof body.action!=='string'||!uuid(body.airlineId))return false;
 if(body.action==='list')return Object.keys(body).length===2 &&
  Object.keys(body).every(k=>['action','airlineId'].includes(k));
 if(body.action==='check-delivery')return Object.keys(body).length===3 &&
  Object.keys(body).every(k=>['action','airlineId','orderId'].includes(k)) && uuid(body.orderId);
 if(body.action==='acquire')return Object.keys(body).length===5 &&
  Object.keys(body).every(k=>['action','airlineId','offerId','registration','requestId'].includes(k)) &&
  uuid(body.offerId)&&uuid(body.requestId)&&typeof body.registration==='string' &&
  REGISTRATION.test(body.registration.trim().toUpperCase());
 return false;
}
export const FLEET_SQL=Object.freeze({
 owner:"SELECT a.id,a.cash_usd::text AS \"cashUsd\" FROM airlinerra_game.airlines a "+
  "JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id "+
  "WHERE a.id=$1::uuid AND a.owner_player_id=$2::uuid AND a.world_id=1 AND w.state='active'",
 offers:"SELECT o.offer_id::text AS \"offerId\",o.configuration_id::int AS \"configurationId\", "+
  "o.transaction_type AS \"transactionType\",o.upfront_price_usd::text AS \"upfrontPriceUsd\", "+
  "o.recurring_monthly_usd::text AS \"recurringMonthlyUsd\",o.contract_months AS \"contractMonths\", "+
  "o.delivery_days AS \"deliveryDays\",c.manufacturer_name AS manufacturer,c.model_name AS model, "+
  "c.use_type AS \"useType\",c.reference_passenger_capacity AS \"referenceSeats\" "+
  "FROM airlinerra_game.aircraft_acquisition_offers_v1 o "+
  "JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=o.configuration_id "+
  "WHERE o.world_id=1 AND o.offer_status='published' "+
  "AND c.model_catalog_status='service_verified' AND c.civilian_service_status='active' "+
  "AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 x WHERE x.configuration_id=o.configuration_id) "+
  "ORDER BY c.manufacturer_name,c.model_name,o.transaction_type,o.offer_id LIMIT 150",
 fleet:"SELECT i.id::text AS id,i.configuration_id::int AS \"configurationId\", "+
  "i.registration,i.ownership_type AS \"ownershipType\",i.fleet_status AS \"fleetStatus\", "+
  "c.manufacturer_name AS manufacturer,c.model_name AS model,c.use_type AS \"useType\", "+
  "o.order_id::text AS \"orderId\",o.order_status AS \"deliveryStatus\",o.delivery_due_at AS \"deliveryDueAt\", "+
  "o.delivery_home_airport_key AS \"deliveryAirportKey\",o.transaction_type AS \"acquisitionType\" "+
  "FROM airlinerra_game.airline_aircraft_inventory i "+
  "LEFT JOIN airlinerra_game.aircraft_acquisition_orders_v1 o "+
  "ON o.aircraft_inventory_id=i.id AND o.airline_id=i.airline_id "+
  "LEFT JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=i.configuration_id "+
  "WHERE i.airline_id=$1::uuid ORDER BY i.created_at DESC,i.id LIMIT 250",
 delivery:"SELECT airlinerra_game.check_owned_aircraft_delivery_v1($1::uuid,$2::uuid,$3::uuid) AS result",
 acquire:"SELECT airlinerra_game.acquire_offered_aircraft_v1("+
  "$1::uuid,$2::uuid,$3::uuid,$4::text,$5::uuid) AS result"
});
export function createFleetAcquisitionHandler({verifyUserToken,database}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
  throw Error('Protected fleet dependencies required');
 return async function handleFleetAcquisition(request){
  if(!(request instanceof Request))return respond(400,{error:'Invalid request'});
  if(request.method!=='POST')return respond(405,{error:'POST required'});
  // The function is mounted at the fleet-acquisition slug by Supabase.
  // The Edge runtime may internally rewrite Request.url. Do not treat that
  // internal URL as a browser-origin security signal. Like the already-working
  // schedule service, require the pinned external origin and route header.
  // Auth, company ownership and every action are still checked below.
  const url=new URL(request.url);
  if(url.search||url.hash||request.headers.get('origin')!==ORIGIN||
     request.headers.get('x-airlinerra-route')!==FLEET_ACQUISITION_API_ROUTE)
    return respond(403,{error:'Forbidden'});
  if(request.headers.get('content-type')!=='application/json')
    return respond(415,{error:'JSON required'});
  const token=BEARER.exec(request.headers.get('authorization')||'')?.[1];
  if(!token)return respond(401,{error:'Verified session required'});
  let body;
  try{
   const raw=await request.arrayBuffer();
   if(raw.byteLength>1024)return respond(413,{error:'Request too large'});
   body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(raw));
  }catch{return respond(400,{error:'Invalid JSON request'});}
  if(!validateFleetAcquisitionRequest(body))
    return respond(400,{error:'Invalid aircraft request'});
  const verification=await verifyUserToken(token);
  const playerId=verification?.user?.id;
  if(verification?.error||!uuid(playerId))
    return respond(401,{error:'Verified session required'});
  let client;
  try{
   client=await database.connect();
   if(body.action==='list'){
    const owner=await client.query(FLEET_SQL.owner,[body.airlineId,playerId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const [offers,fleet]=await Promise.all([
     client.query(FLEET_SQL.offers),client.query(FLEET_SQL.fleet,[body.airlineId])
    ]);
    return respond(200,{airlineId:body.airlineId,cashUsd:owner.rows[0].cashUsd,
     offers:offers.rows,fleet:fleet.rows,liveFlightActivation:false});
   }
   if(body.action==='check-delivery'){
    const result=await client.query(FLEET_SQL.delivery,[playerId,body.airlineId,body.orderId]);
    if(result.rowCount!==1||!result.rows[0]?.result)
      return respond(503,{error:'Delivery status could not be confirmed'});
    return respond(200,result.rows[0].result);
   }
   const registration=body.registration.trim().toUpperCase();
   const result=await client.query(FLEET_SQL.acquire,[
    playerId,body.airlineId,body.offerId,registration,body.requestId
   ]);
   if(result.rowCount!==1||!result.rows[0]?.result)
    return respond(503,{error:'Aircraft order was not confirmed'});
   return respond(200,result.rows[0].result);
  }catch(err){
   const code=typeof err?.code==='string'?err.code:'';
   if(code==='42501')return respond(403,{error:'Airline not owned by verified player'});
   if(code==='22023')return respond(400,{error:'Invalid aircraft registration or request'});
   if(code==='23505')return respond(409,{reason:'AIRCRAFT_REGISTRATION_ALREADY_TAKEN'});
   if(code==='P0001'){
    const allowed=new Set([
     'AIRLINE_WORLD_NOT_ACTIVE_FOR_ACQUISITION',
     'ACQUISITION_IDEMPOTENCY_KEY_REUSED','AIRCRAFT_OFFER_NOT_AVAILABLE',
     'AIRCRAFT_CONFIGURATION_NOT_RELEASED_FOR_PLAYER_MARKET',
     'GROUP3_AIRCRAFT_NOT_RELEASED_FOR_FLEET',
     'AIRCRAFT_REGISTRATION_ALREADY_TAKEN','INSUFFICIENT_AIRLINE_CASH',
     'AIRLINE_WORLD_NOT_ACTIVE_FOR_DELIVERY'
    ]);
    return respond(409,{reason:allowed.has(err.message)?err.message:'AIRCRAFT_ACQUISITION_UNAVAILABLE'});
   }
   return respond(503,{error:'Fleet service temporarily unavailable'});
  }finally{try{client?.release()}catch{/* no sensitive DB details */}}
 };
}
