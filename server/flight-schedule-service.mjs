/**
 * Protected Airlinerra server-owned flight schedule DRAFT API.
 * The owner/aircraft/curfew gate is executed atomically INSIDE PostgreSQL.
 * There is intentionally no flight activation write. Never trust browser owner IDs.
 */
export const FLIGHT_SCHEDULE_API_ROUTE='/api/v1/player/flight-schedule-drafts';
const ORIGIN='https://airlinerra.com';
const TOKEN=/^Bearer ([A-Za-z0-9._~-]{16,8192})$/u;
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu;
const AIRPORT=/^(?:OURAIRPORTS:[1-9][0-9]{0,18}|FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8})$/u;
const UTC=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/u;
const HHMM=/^([01]\d|2[0-3]):[0-5]\d$/u;
const BASE_FIELDS=new Set(['action','airlineId']);
const SAVE_FIELDS=new Set([...BASE_FIELDS,'aircraftInventoryId','flightNumber',
 'originAirportKey','destinationAirportKey','referenceDepartureUtc','referenceArrivalUtc',
 'weeklySchedule','existingId','departureStand','arrivalStand']);
const SLOT_FIELDS=new Set([...BASE_FIELDS,'aircraftInventoryId','originAirportKey',
 'destinationAirportKey','referenceDepartureUtc','referenceArrivalUtc','weeklySchedule',
 'existingId','departureStand','arrivalStand']);
const CHECK_FIELDS=new Set([...BASE_FIELDS,'scheduleId']);
const DEMAND_FIELDS=new Set([...CHECK_FIELDS,'month']);
const ROTATION_FIELDS=new Set([...CHECK_FIELDS,'startDate','days']);
const CREW_PLAN_FIELDS=new Set([...CHECK_FIELDS,'crewId','weeklyEntry','decision']);
const FARE_SAVE_FIELDS=new Set([...CHECK_FIELDS,'economyFareUsd',
 'cargoRateUsdPerTonne','marketingBudgetUsdPerDay']);
const PARTNER_PROPOSE_FIELDS=new Set([...BASE_FIELDS,'otherAirlineCode']);
const PARTNER_DECIDE_FIELDS=new Set([...BASE_FIELDS,'agreementId','decision']);
const RHEADERS={'cache-control':'no-store','content-type':'application/json; charset=utf-8',
 'x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
const respond=(status,payload)=>Response.json(payload,{status,headers:RHEADERS});
const utc=value=>typeof value==='string'&&UTC.test(value)&&
 Number.isFinite(Date.parse(value))&&new Date(value).toISOString().slice(0,19)+'Z'===value;
const uuid=value=>typeof value==='string'&&UUID.test(value);
const withinFields=(body,set)=>Object.keys(body).every(k=>set.has(k));
export function validWeeklyFlightSchedule(value){
 if(!Array.isArray(value)||value.length<1||value.length>7)return false;
 const dates=new Set();
 for(const row of value){
  if(!row||typeof row!=='object'||Array.isArray(row)||
     Object.keys(row).some(k=>!['day','time'].includes(k))||
     !Number.isInteger(row.day)||row.day<0||row.day>6||
     typeof row.time!=='string'||!HHMM.test(row.time)||dates.has(row.day))
   return false;
  dates.add(row.day);
 }
 return true;
}
export function validateFlightSchedulePayload(body){
 if(!body||typeof body!=='object'||Array.isArray(body)||
    !uuid(body.airlineId)||typeof body.action!=='string')return false;
 if(body.action==='list'||body.action==='partner-list')
  return withinFields(body,BASE_FIELDS);
 if(body.action==='partner-propose')return withinFields(body,PARTNER_PROPOSE_FIELDS)&&
   typeof body.otherAirlineCode==='string'&&
   /^[A-Z0-9]{2,3}$/.test(body.otherAirlineCode);
 if(body.action==='partner-decision')return withinFields(body,PARTNER_DECIDE_FIELDS)&&
   Number.isSafeInteger(body.agreementId)&&body.agreementId>0&&
   ['approve','terminate'].includes(body.decision);
 if(body.action==='commercial-save'){
  if(!withinFields(body,FARE_SAVE_FIELDS)||!uuid(body.scheduleId))return false;
  return [[body.economyFareUsd,1,100000],[body.cargoRateUsdPerTonne,0,1000000],
   [body.marketingBudgetUsdPerDay,0,100000]].every(([n,min,max])=>
    typeof n==='number'&&Number.isFinite(n)&&n>=min&&n<=max&&
    Math.round(n*100)/100===n);
 }
 if(body.action==='crew-roster')
  return withinFields(body,CHECK_FIELDS)&&uuid(body.scheduleId);
 if(body.action==='crew-plan')
  return withinFields(body,CREW_PLAN_FIELDS)&&uuid(body.scheduleId)&&
   uuid(body.crewId)&&Number.isInteger(body.weeklyEntry)&&
   body.weeklyEntry>=1&&body.weeklyEntry<=7&&
   ['plan','remove'].includes(body.decision);
 if(body.action==='commercial-read')
  return withinFields(body,CHECK_FIELDS)&&uuid(body.scheduleId);
 if(body.action==='delete'||body.action==='activation-check')
  return withinFields(body,CHECK_FIELDS)&&uuid(body.scheduleId);
 if(body.action==='rotation-preview'||body.action==='operations-preview'){
  if(!withinFields(body,ROTATION_FIELDS)||!uuid(body.scheduleId)||
     !Number.isInteger(body.days)||body.days<7||body.days>42||
     typeof body.startDate!=='string'||
     !/^(20|21)[0-9]{2}-[0-9]{2}-[0-9]{2}$/.test(body.startDate))return false;
  const parsed=Date.parse(body.startDate+'T00:00:00Z');
  return Number.isFinite(parsed)&&
   new Date(parsed).toISOString().slice(0,10)===body.startDate;
 }
 if(body.action==='demand-preview')
  return withinFields(body,DEMAND_FIELDS)&&uuid(body.scheduleId)&&
   Number.isInteger(body.month)&&body.month>=1&&body.month<=12;
 if(body.action!=='save'&&body.action!=='slot-check')return false;
 if(!withinFields(body,body.action==='save'?SAVE_FIELDS:SLOT_FIELDS))return false;
 if(!['terminal','remote','cargo'].includes(body.departureStand??'terminal')||
    !['terminal','remote','cargo'].includes(body.arrivalStand??'terminal'))return false;
 if(!uuid(body.aircraftInventoryId)||
   (body.existingId!==undefined&&!uuid(body.existingId))||
   (body.action==='save'&&!/^[A-Z0-9]{2}[0-9]{1,4}$/.test(body.flightNumber||''))||
   typeof body.originAirportKey!=='string'||!AIRPORT.test(body.originAirportKey)||
   typeof body.destinationAirportKey!=='string'||!AIRPORT.test(body.destinationAirportKey)||
   body.originAirportKey===body.destinationAirportKey||
   !utc(body.referenceDepartureUtc)||!utc(body.referenceArrivalUtc)||
   !validWeeklyFlightSchedule(body.weeklySchedule))return false;
 const delta=Date.parse(body.referenceArrivalUtc)-Date.parse(body.referenceDepartureUtc);
 return Number.isFinite(delta)&&delta>0&&delta<=72*3600*1000;
}
export const SCHEDULE_SQL=Object.freeze({
 owner:'SELECT id FROM airlinerra_game.airlines WHERE id=$1::uuid AND owner_player_id=$2::uuid AND world_id=1',
 fleet:`SELECT i.id::text AS id,i.configuration_id::int AS "configurationId",i.registration,
     i.ownership_type AS "ownershipType",i.fleet_status AS "fleetStatus"
   FROM airlinerra_game.airline_aircraft_inventory i
   WHERE i.airline_id=$1::uuid AND i.fleet_status='in_service'
   ORDER BY i.registration LIMIT 100`,
 drafts:`SELECT s.id::text AS id,s.flight_number AS "flightNumber",
   s.aircraft_inventory_id::text AS "aircraftInventoryId",
   s.configuration_id::int AS "configurationId",
   s.origin_airport_key AS "originAirportKey",
   s.destination_airport_key AS "destinationAirportKey",
   s.reference_departure_utc AS "referenceDepartureUtc",
   s.reference_arrival_utc AS "referenceArrivalUtc",
   s.weekly_schedule AS "weeklySchedule",
   s.departure_stand_type AS "departureStand",s.arrival_stand_type AS "arrivalStand",s.status,
   s.version,s.updated_at AS "updatedAt"
   FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
   WHERE s.airline_id=$1::uuid ORDER BY s.updated_at DESC,s.id LIMIT 50`,
 save:`SELECT airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   $1::uuid,$2::uuid,$3::uuid,$4::text,$5::text,$6::text,
   $7::timestamptz,$8::timestamptz,$9::jsonb,$10::uuid,$11::text,$12::text) AS result`,
 existingDraftOwner:`SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=$1::uuid AND airline_id=$2::uuid AND status='draft'`,
 fleetUse:`SELECT c.use_type AS "useType" FROM airlinerra_game.airline_aircraft_inventory i
  JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
  WHERE i.id=$1::uuid AND i.airline_id=$2::uuid AND i.fleet_status='in_service'`,
 slotCheck:`SELECT airlinerra_game.section6_weekly_slot_preflight_v1(
  1::smallint,$1::text,$2::text,$3::timestamptz,$4::timestamptz,
  $5::jsonb,$6::text,$7::text,$8::uuid) AS result`,
 demandPreview:`SELECT airlinerra_game.section9_owned_route_preview_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::smallint) AS result`,
 commercialSave:`SELECT airlinerra_game.section9_save_owned_commercial_plan_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::numeric,$5::numeric,$6::numeric) AS result`,
 commercialRead:`SELECT airlinerra_game.section9_get_owned_commercial_plan_v1(
  $1::uuid,$2::uuid,$3::uuid) AS result`,
 partnershipList:`SELECT airlinerra_game.section9_list_owned_partnerships_v1(
  $1::uuid,$2::uuid) AS result`,
 partnershipPropose:`SELECT airlinerra_game.section9_manage_partnership_v1(
  $1::uuid,$2::uuid,'propose'::text,$3::text,NULL::bigint) AS result`,
 partnershipDecision:`SELECT airlinerra_game.section9_manage_partnership_v1(
  $1::uuid,$2::uuid,$3::text,NULL::text,$4::bigint) AS result`,
 rotationPreview:`SELECT airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::date,$5::integer) AS result`,
 operationsPreview:`SELECT airlinerra_game.section9_owned_operations_with_crew_rights_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::date,$5::integer) AS result`,
 crewRoster:`SELECT airlinerra_game.section9_owned_crew_roster_preview_v1(
  $1::uuid,$2::uuid,$3::uuid) AS result`,
 crewPlan:`SELECT airlinerra_game.section9_plan_owned_crew_duty_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::uuid,$5::integer,$6::text) AS result`,
 check:`SELECT airlinerra_game.section5_schedule_activation_readiness_v1($1::uuid,$2::uuid) AS result`,
 delete:`DELETE FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
   USING airlinerra_game.airlines a
   WHERE s.id=$1::uuid AND a.id=s.airline_id AND a.id=$2::uuid
    AND a.owner_player_id=$3::uuid AND s.status='draft'
   RETURNING s.id::text AS id`
});
export function createFlightScheduleHandler({verifyUserToken,database}={}){
 if(typeof verifyUserToken!=='function'||typeof database?.connect!=='function')
  throw Error('Verified private flight schedule dependencies required');
 return async function handleFlightSchedule(request){
  if(!(request instanceof Request))return respond(400,{error:'Invalid request'});
  if(request.method!=='POST')return respond(405,{error:'POST required'});
  if(request.headers.get('origin')!==ORIGIN||
    request.headers.get('x-airlinerra-route')!==FLIGHT_SCHEDULE_API_ROUTE)
   return respond(403,{error:'Forbidden'});
  if(request.headers.get('content-type')!=='application/json')
   return respond(415,{error:'JSON required'});
  const token=TOKEN.exec(request.headers.get('authorization')||'')?.[1];
  if(!token)return respond(401,{error:'Verified session required'});
  let body;
  try{
   const raw=await request.arrayBuffer();
   if(raw.byteLength>2048)return respond(413,{error:'Request too large'});
   body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(raw));
  }catch{return respond(400,{error:'Invalid JSON body'});}
  if(!validateFlightSchedulePayload(body))return respond(400,{error:'Invalid schedule request'});
  const auth=await verifyUserToken(token);
  const userId=auth?.user?.id;
  if(auth?.error||!uuid(userId))return respond(401,{error:'Verified session required'});
  let client;
  try{
   client=await database.connect();
   if(body.action==='list'){
    const owner=await client.query(SCHEDULE_SQL.owner,[body.airlineId,userId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const [fleet,drafts]=await Promise.all([
      client.query(SCHEDULE_SQL.fleet,[body.airlineId]),
      client.query(SCHEDULE_SQL.drafts,[body.airlineId])
    ]);
    return respond(200,{readOnly:false,activationAvailable:false,
      fleet:fleet.rows,drafts:drafts.rows});
   }
   if(body.action==='save'){
    const response=await client.query(SCHEDULE_SQL.save,[
      userId,body.airlineId,body.aircraftInventoryId,body.flightNumber,
      body.originAirportKey,body.destinationAirportKey,
      body.referenceDepartureUtc,body.referenceArrivalUtc,
      JSON.stringify(body.weeklySchedule),body.existingId??null,
      body.departureStand??'terminal',body.arrivalStand??'terminal'
    ]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Schedule draft was not confirmed'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='slot-check'){
    const owner=await client.query(SCHEDULE_SQL.owner,[body.airlineId,userId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    if(body.existingId){
     const draft=await client.query(SCHEDULE_SQL.existingDraftOwner,
      [body.existingId,body.airlineId]);
     if(draft.rowCount!==1)return respond(403,{error:'Schedule not owned by this airline'});
    }
    const fleet=await client.query(SCHEDULE_SQL.fleetUse,[body.aircraftInventoryId,body.airlineId]);
    if(fleet.rowCount!==1)return respond(403,{error:'Aircraft not in owned service fleet'});
    const useType=fleet.rows[0].useType;
    if((useType==='cargo'&&(body.departureStand!=='cargo'||body.arrivalStand!=='cargo'))||
       (useType==='passenger'&&(body.departureStand==='cargo'||body.arrivalStand==='cargo')))
      return respond(200,{available:false,departureAvailable:false,arrivalAvailable:false,
        reason:'STAND_INCOMPATIBLE_WITH_AIRCRAFT'});
    const response=await client.query(SCHEDULE_SQL.slotCheck,[
      body.originAirportKey,body.destinationAirportKey,
      body.referenceDepartureUtc,body.referenceArrivalUtc,
      JSON.stringify(body.weeklySchedule),body.departureStand??'terminal',
      body.arrivalStand??'terminal',body.existingId??null
    ]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Slot check unavailable'});
    const v=response.rows[0].result;
    return respond(200,{available:v.available===true,
     departureAvailable:v.departureAvailable===true,arrivalAvailable:v.arrivalAvailable===true,
     slotModel:'weekly_stand_capacity_v1'});
   }
   if(body.action==='commercial-save'){
    const response=await client.query(SCHEDULE_SQL.commercialSave,
     [userId,body.airlineId,body.scheduleId,body.economyFareUsd,
      body.cargoRateUsdPerTonne,body.marketingBudgetUsdPerDay]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Commercial plan was not saved'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='commercial-read'){
    const response=await client.query(SCHEDULE_SQL.commercialRead,
     [userId,body.airlineId,body.scheduleId]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Commercial plan unavailable'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='partner-list'){
    const response=await client.query(SCHEDULE_SQL.partnershipList,
     [userId,body.airlineId]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Partnership list unavailable'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='partner-propose'||body.action==='partner-decision'){
    const query=body.action==='partner-propose'?
     SCHEDULE_SQL.partnershipPropose:SCHEDULE_SQL.partnershipDecision;
    const args=body.action==='partner-propose'?
     [userId,body.airlineId,body.otherAirlineCode]:
     [userId,body.airlineId,body.decision,body.agreementId];
    const response=await client.query(query,args);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Partnership update unavailable'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='demand-preview'){
    // Database function checks ownership again; only estimates are returned.
    const response=await client.query(SCHEDULE_SQL.demandPreview,
      [userId,body.airlineId,body.scheduleId,body.month]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Demand preview unavailable'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='rotation-preview'){
    const response=await client.query(SCHEDULE_SQL.rotationPreview,
      [userId,body.airlineId,body.scheduleId,body.startDate,body.days]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Aircraft rotation preflight unavailable'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='crew-roster'){
    const response=await client.query(SCHEDULE_SQL.crewRoster,
     [userId,body.airlineId,body.scheduleId]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Crew roster preview unavailable'});
    const result=response.rows[0].result;
    if(result.readOnly!==true||result.canActivateNormalFlight!==false)
     return respond(503,{error:'Crew roster evidence is not verified'});
    return respond(200,result);
   }
   if(body.action==='crew-plan'){
    const response=await client.query(SCHEDULE_SQL.crewPlan,
     [userId,body.airlineId,body.scheduleId,
      body.crewId,body.weeklyEntry,body.decision]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Crew duty proposal was not saved'});
    const result=response.rows[0].result;
    if(result.status!=='planned_not_verified'||result.canActivateNormalFlight!==false)
     return respond(503,{error:'Crew proposal safety check failed'});
    return respond(200,result);
   }
   if(body.action==='operations-preview'){
    const response=await client.query(SCHEDULE_SQL.operationsPreview,
      [userId,body.airlineId,body.scheduleId,body.startDate,body.days]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Operational evidence preflight unavailable'});
    const evidence=response.rows[0].result;
    if(evidence.canActivateNormalFlight!==false||evidence.readOnly!==true)
     return respond(503,{error:'Operational activation not verified'});
    return respond(200,evidence);
   }
   if(body.action==='activation-check'){
    const response=await client.query(SCHEDULE_SQL.check,[userId,body.scheduleId]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Flight activation check failed'});
    return respond(200,response.rows[0].result);
   }
   if(body.action==='delete'){
    const owner=await client.query(SCHEDULE_SQL.delete,[
     body.scheduleId,body.airlineId,userId
    ]);
    if(owner.rowCount!==1)return respond(404,{error:'Editable schedule draft not found'});
    return respond(200,{deleted:true,scheduleId:owner.rows[0].id,
      canActivateNormalFlight:false});
   }
   return respond(400,{error:'Unsupported action'});
  }catch(error){
   const code=typeof error?.code==='string'?error.code:'';
   if(code==='42501')return respond(403,{error:'Airline or schedule not owned by verified player'});
   if(code==='23505')return respond(409,{error:'Flight number already used by this airline'});
   if(code==='22023')return respond(400,{error:'Invalid flight schedule or airline code'});
   if(code==='P0001')return respond(409,{
    error:'Aircraft, airline or airport restrictions prevent saving this flight schedule',
    reason:['SCHEDULE_BLOCKED_BY_AIRPORT_OR_AIRCRAFT_RULE',
      'AIRCRAFT_NOT_OWNED_LEASED_OR_IN_SERVICE',
      'AIRLINE_WORLD_NOT_ACTIVE_FOR_SCHEDULING','SECTION6_SLOT_UNAVAILABLE',
      'SECTION6_INCOMPATIBLE_AIRCRAFT_STAND','SECTION6_AIRPORT_CAPACITY_NOT_CONFIGURED',
      'SECTION9_PARTNER_NOT_FOUND_OR_AMBIGUOUS',
      'SECTION9_TERMINATED_PROPOSAL_REQUIRES_RESTART'].includes(error.message)
      ?error.message:'SCHEDULE_REQUIRES_REVIEW'
   });
   // Do not print the database error, queries, secrets or submitted personal data.
   return respond(503,{error:'Protected scheduling service unavailable'});
  }finally{try{client?.release()}catch{/* ignore */}}
 };
}
