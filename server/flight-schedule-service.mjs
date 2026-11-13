/**
 * Protected Airlinerra server-owned flight schedule DRAFT API.
 * The owner/aircraft/curfew gate is executed atomically INSIDE PostgreSQL.
 * There is intentionally no flight activation write. Never trust browser owner IDs.
 */
import {SEVEN_DAY_WINDOW_SQL} from './section9-seven-day-window.mjs';
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
const PLAN_FIELDS=new Set([...BASE_FIELDS,'aircraftInventoryId','flightNumber',
 'originAirportKey','destinationAirportKey','weeklySchedule','departureStand',
 'arrivalStand','turnaroundMinutes','fares','service','launchDelayDays',
 'referenceDepartureUtc','referenceArrivalUtc']);
const PLAN_DELETE_FIELDS=new Set([...BASE_FIELDS,'planId']);
const SLOT_FIELDS=new Set([...BASE_FIELDS,'aircraftInventoryId','originAirportKey',
 'destinationAirportKey','referenceDepartureUtc','referenceArrivalUtc','weeklySchedule',
 'existingId','departureStand','arrivalStand']);
const CHECK_FIELDS=new Set([...BASE_FIELDS,'scheduleId']);
const COMMISSIONING_FIELDS=new Set([...BASE_FIELDS,'aircraftInventoryId']);
const MAINTENANCE_JOB_FIELDS=new Set([...COMMISSIONING_FIELDS,'checkCode']);
const DEMAND_FIELDS=new Set([...CHECK_FIELDS,'month']);
const FINANCIAL_FIELDS=new Set([...CHECK_FIELDS,'loadPercent','parkingMinutes']);
const FEE_PREVIEW_FIELDS=new Set([...BASE_FIELDS,'aircraftInventoryId','originAirportKey',
 'destinationAirportKey','departureStand','arrivalStand','parkingMinutes']);
const ROTATION_FIELDS=new Set([...CHECK_FIELDS,'startDate','days']);
const CREW_PLAN_FIELDS=new Set([...CHECK_FIELDS,'crewId','weeklyEntry','decision']);
const CREW_HIRE_FIELDS=new Set([...CHECK_FIELDS,'candidateSlot']);
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
 if(body.action==='plan-save'||body.action==='operational-create'){
  if(!withinFields(body,PLAN_FIELDS)||!uuid(body.aircraftInventoryId)||
     !/^[A-Z0-9]{2}[0-9]{1,4}$/.test(body.flightNumber||'')||
     !AIRPORT.test(body.originAirportKey||'')||
     !AIRPORT.test(body.destinationAirportKey||'')||
     body.originAirportKey===body.destinationAirportKey||
     !validWeeklyFlightSchedule(body.weeklySchedule)||
     !Number.isInteger(body.turnaroundMinutes)||
     body.turnaroundMinutes<45||body.turnaroundMinutes>360||
     ![undefined,0,3,7].includes(body.launchDelayDays)||
     (body.departureStand!==null&&body.departureStand!==undefined&&
      !['terminal','remote','cargo'].includes(body.departureStand))||
     !['terminal','remote','cargo'].includes(body.arrivalStand)||
     !body.fares||typeof body.fares!=='object'||Array.isArray(body.fares)||
     Object.keys(body.fares).some(k=>!['economy','premium','business','first'].includes(k))||
     !['economy','premium','business','first'].every(k=>
       Object.hasOwn(body.fares,k)&&
       (body.fares[k]===null||
        (Number.isSafeInteger(body.fares[k])&&body.fares[k]>=0&&body.fares[k]<=100000)))||
     !body.service||typeof body.service!=='object'||Array.isArray(body.service)||
     Object.keys(body.service).some(k=>!['onboard','baggage','cargo','cabinPackageId'].includes(k))||
     !['standard','basic','enhanced'].includes(body.service.onboard)||
     !['standard','hand-only','checked'].includes(body.service.baggage)||
     !['none','requested'].includes(body.service.cargo)||
     (body.service.cabinPackageId!==undefined&&
      (typeof body.service.cabinPackageId!=='string'||
       !/^(?:none|basic|pkg-[1-9][0-9]{0,5})$/.test(body.service.cabinPackageId)))||
     (body.referenceDepartureUtc!==null&&body.referenceDepartureUtc!==undefined&&
      !utc(body.referenceDepartureUtc))||
     (body.referenceArrivalUtc!==null&&body.referenceArrivalUtc!==undefined&&
      !utc(body.referenceArrivalUtc)))return false;
  const departure=body.referenceDepartureUtc??null,arrival=body.referenceArrivalUtc??null;
  if((departure===null)!==(arrival===null))return false;
  if(departure!==null){
   const minutes=Date.parse(arrival)-Date.parse(departure);
   if(minutes<=0||minutes>72*3600000)return false;
  }
  return true;
 }
 if(body.action==='list'||body.action==='partner-list')
  return withinFields(body,BASE_FIELDS);
 if(body.action==='commissioning-status'||body.action==='commissioning-request')
  return withinFields(body,COMMISSIONING_FIELDS)&&uuid(body.aircraftInventoryId);
 if(body.action==='maintenance-job-status'||body.action==='maintenance-job-cancel')
  return withinFields(body,COMMISSIONING_FIELDS)&&uuid(body.aircraftInventoryId);
 if(body.action==='maintenance-job-book')
  return withinFields(body,MAINTENANCE_JOB_FIELDS)&&uuid(body.aircraftInventoryId)&&
   ['daily','weekly','a','b','c','d'].includes(body.checkCode);
 if(body.action==='plan-delete')
  return withinFields(body,PLAN_DELETE_FIELDS)&&uuid(body.planId);
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
 if(body.action==='crew-offers')
  return withinFields(body,CHECK_FIELDS)&&uuid(body.scheduleId);
 if(body.action==='crew-salary')
  return withinFields(body,BASE_FIELDS);
 if(body.action==='crew-hire')
  return withinFields(body,CREW_HIRE_FIELDS)&&uuid(body.scheduleId)&&
   Number.isInteger(body.candidateSlot)&&body.candidateSlot>=1&&
   body.candidateSlot<=2000;
 if(body.action==='crew-roster')
  return withinFields(body,CHECK_FIELDS)&&uuid(body.scheduleId);
 if(body.action==='crew-plan')
  return withinFields(body,CREW_PLAN_FIELDS)&&uuid(body.scheduleId)&&
   uuid(body.crewId)&&Number.isInteger(body.weeklyEntry)&&
   body.weeklyEntry>=1&&body.weeklyEntry<=7&&
   ['plan','remove'].includes(body.decision);
 if(body.action==='commercial-read')
  return withinFields(body,CHECK_FIELDS)&&uuid(body.scheduleId);
 if(body.action==='fee-preview')
  return withinFields(body,FEE_PREVIEW_FIELDS)&&
   Object.keys(body).length===8&&uuid(body.aircraftInventoryId)&&
   AIRPORT.test(body.originAirportKey||'')&&AIRPORT.test(body.destinationAirportKey||'')&&
   body.originAirportKey!==body.destinationAirportKey&&
   ['terminal','remote','cargo'].includes(body.departureStand)&&
   ['terminal','remote','cargo'].includes(body.arrivalStand)&&
   Number.isInteger(body.parkingMinutes)&&body.parkingMinutes>=0&&
   body.parkingMinutes<=10080;
 if(body.action==='route-financials')
  return withinFields(body,FINANCIAL_FIELDS)&&uuid(body.scheduleId)&&
    Number.isInteger(body.loadPercent)&&body.loadPercent>=0&&body.loadPercent<=100&&
    Number.isInteger(body.parkingMinutes)&&body.parkingMinutes>=0&&
    body.parkingMinutes<=10080;
 if(body.action==='delete'||body.action==='activation-check'||
    body.action==='booking-window-preview')
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
/** First requested weekly operating date in the authoritative GAME calendar.
 * Day 0 is Monday. Date-only clock means time-of-day clearance remains blocked.
 */
export function nextWeeklyDepartureGameDate(gameDate,weeklySchedule,launchDelayDays=0){
 const canonical=gameDate instanceof Date&&Number.isFinite(gameDate.getTime())?
  gameDate.toISOString().slice(0,10):gameDate;
 if(typeof canonical!=='string'||!/^(20|21)[0-9]{2}-[0-9]{2}-[0-9]{2}$/.test(canonical)||
    !validWeeklyFlightSchedule(weeklySchedule)||
    ![0,3,7].includes(launchDelayDays))return null;
 const first=Date.parse(canonical+'T00:00:00Z');
 if(!Number.isFinite(first)||new Date(first).toISOString().slice(0,10)!==canonical)return null;
 for(let step=launchDelayDays;step<=launchDelayDays+6;step++){
  const day=new Date(first+step*86400000);
  const weekday=(day.getUTCDay()+6)%7;
  if(weeklySchedule.some(row=>row.day===weekday))
   return day.toISOString().slice(0,10);
 }
 return null;
}
export const SCHEDULE_SQL=Object.freeze({
 operationalReadiness:`SELECT world_id,world_state,confirmed_game_date,
  authoritative_clock_connected,clock_producer_enabled,
  operational_certification_records,aircraft_operation_jobs,
  verified_movement_records,automatic_flight_and_fuel_settlement_enabled
  FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
  WHERE world_id=1`,
 aircraftPrerequisites:`SELECT
  f.fleet_status='in_service' AS "aircraftInService",
  (location.position->>'verified')='true'
   AS "startingLocationVerified",
  (location.position->>'verified')='true'
   AND (location.position->>'atGroundAirport')='true'
   AND location.position->>'airportKey'=$4::text AS "atOrigin",
  location.position->>'status' AS "positionStatus",
  (location.position->>'initialOnly')='true' AS "originalStarterPosition",
  location.position->>'airportKey' AS "verifiedPositionAirport",
  EXISTS(SELECT 1 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 game_fuel
   WHERE game_fuel.configuration_id=f.configuration_id
     AND game_fuel.game_calculation_ready=true
     AND game_fuel.model_version='AIRLINERRA_FIVE_PHASE_FUEL_GAME_V1_2026_11_12')
     AS "gameFuelEstimateReady",
  EXISTS(SELECT 1 FROM airlinerra_game.aircraft_maintenance_state_v1 usage
   WHERE usage.aircraft_inventory_id=f.id AND usage.airline_id=f.airline_id
    AND usage.verified_tracking_started_utc IS NOT NULL
    AND usage.tracked_flight_hours IS NOT NULL
    AND usage.tracked_flight_cycles IS NOT NULL)
    AS "maintenanceUsageTrackingStarted",
  EXISTS(SELECT 1 FROM airlinerra_game.aircraft_fuel_planning_profiles_v1 fuel
   WHERE fuel.configuration_id=f.configuration_id
    AND fuel.approved_for_dispatch=true AND fuel.requires_further_evidence=false)
    AS "fuelDispatchModelApproved",
  EXISTS(SELECT 1 FROM airlinerra_game.aircraft_fuel_planning_profiles_v1 fuel
   WHERE fuel.configuration_id=f.configuration_id
    AND fuel.approved_for_accounting=true AND fuel.requires_further_evidence=false)
    AS "fuelAccountingModelApproved",
  EXISTS(SELECT 1 FROM airlinerra_game.aircraft_maintenance_state_v1 maintenance
   WHERE maintenance.aircraft_inventory_id=f.id
    AND maintenance.airline_id=f.airline_id
    AND maintenance.condition_pct IS NOT NULL
    AND maintenance.condition_basis NOT IN ('unverified','unknown')
    AND maintenance.verified_tracking_started_utc IS NOT NULL
    AND maintenance.tracked_flight_hours IS NOT NULL
    AND maintenance.tracked_flight_cycles IS NOT NULL)
    AS "maintenanceBaselineVerified"
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.world_id=1
 CROSS JOIN LATERAL
  airlinerra_game.section9_owned_aircraft_operational_position_v1(
   $1::uuid,$2::uuid,$3::uuid,
   (SELECT confirmed_game_date FROM airlinerra_game.holding_world_clock_v1
    WHERE world_id=1)) AS location(position)
 WHERE f.id=$3::uuid AND f.airline_id=$2::uuid
  AND a.owner_player_id=$1::uuid`,
 maintenanceReadiness:`SELECT airlinerra_game.section9_owned_aircraft_maintenance_readiness_v1(
   $1::uuid,$2::uuid,$3::uuid,$4::date) AS result`,
 commissioning:`SELECT airlinerra_game.section9_owned_starter_commissioning_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::text) AS result`,
 commissioningDataInspection:`SELECT airlinerra_game.section9_owned_starter_game_data_inspection_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::text) AS result`,
 commissioningGameAirframe:`SELECT airlinerra_game.section9_owned_starter_game_airframe_initialize_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::text) AS result`,
 maintenanceGameDue:`SELECT airlinerra_game.section9_owned_game_maintenance_due_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::date) AS result`,
 maintenanceGameJob:`SELECT airlinerra_game.section9_owned_game_maintenance_job_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::text,$5::text) AS result`,
 maintenanceFlightWindow:`SELECT airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::timestamptz,$5::timestamptz) AS result`,
 bookingWindowPreview:SEVEN_DAY_WINDOW_SQL,
 owner:'SELECT id FROM airlinerra_game.airlines WHERE id=$1::uuid AND owner_player_id=$2::uuid AND world_id=1',
 feeAircraft:`SELECT i.configuration_id::bigint AS "configurationId",
 c.use_type AS "useType"
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id
   AND w.player_id=a.owner_player_id AND w.state='active'
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.airline_id=a.id
 JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
 WHERE a.world_id=1 AND a.id=$2::uuid AND a.owner_player_id=$1::uuid
 AND i.id=$3::uuid AND i.fleet_status='in_service'
 AND i.ownership_type IN ('owned','leased')`,
 feePreview:`SELECT airlinerra_game.section8_quote_flight_operating_fees_v1(
  1::smallint,$1::text,$2::text,$3::bigint,$4::text,$5::text,
  0::integer,0::numeric,$6::integer) AS result`, 
 fleet:`SELECT i.id::text AS id,i.configuration_id::int AS "configurationId",i.registration,
     i.ownership_type AS "ownershipType",i.fleet_status AS "fleetStatus"
   FROM airlinerra_game.airline_aircraft_inventory i
   WHERE i.airline_id=$1::uuid AND i.fleet_status='in_service'
   ORDER BY i.registration LIMIT 100`,
 planList:`SELECT p.id::text AS "planId",p.flight_number AS "flightNumber",
 p.aircraft_inventory_id::text AS "aircraftInventoryId",
 p.origin_airport_key AS "originAirportKey",p.destination_airport_key AS "destinationAirportKey",
 jsonb_build_object('key',p.origin_airport_key,'name',coalesce(o.airport_name,p.origin_airport_key),
  'code',o.airport_code,'municipality',o.municipality,'countryIso',o.country_iso) AS "from",
 jsonb_build_object('key',p.destination_airport_key,'name',coalesce(d.airport_name,p.destination_airport_key),
  'code',d.airport_code,'municipality',d.municipality,'countryIso',d.country_iso) AS "to",
 p.weekly_schedule AS "schedule",
 CASE WHEN p.planning_options->>'launchDelayDays' IN ('0','3','7')
  THEN (p.planning_options->>'launchDelayDays')::int ELSE 0 END AS "launchDelayDays",
 jsonb_build_object('departureStand',p.departure_stand_type,
  'arrivalStand',p.arrival_stand_type,'turnaroundMinutes',p.turnaround_minutes,
  'fares',p.planning_options->'fares','service',p.planning_options->'service') AS "operation",
 p.reference_departure_utc AS "referenceDepartureUtc",
 p.reference_arrival_utc AS "referenceArrivalUtc",
 s.id::text AS "serverScheduleId",
 s.status AS "serverScheduleStatus",
 s.operationally_verified AS "serverScheduleOperationallyVerified",
 'owned:'||p.aircraft_inventory_id::text AS "aircraftId",
 p.status,p.version,p.updated_at AS "updatedAt",
 i.registration||' · '||c.configuration_code AS "aircraftLabel"
 FROM airlinerra_game.airline_route_planning_drafts_v1 p
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=p.aircraft_inventory_id
 JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
 JOIN airlinerra_game.approved_game_airports o ON o.world_id=1 AND o.airport_key=p.origin_airport_key
 JOIN airlinerra_game.approved_game_airports d ON d.world_id=1 AND d.airport_key=p.destination_airport_key
 LEFT JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.airline_id=p.airline_id
  AND s.flight_number=p.flight_number
  AND s.aircraft_inventory_id=p.aircraft_inventory_id
  AND s.origin_airport_key=p.origin_airport_key
  AND s.destination_airport_key=p.destination_airport_key
  AND s.weekly_schedule=p.weekly_schedule
 WHERE p.airline_id=$1::uuid ORDER BY p.updated_at DESC,p.id LIMIT 100`,
 planDelete:`DELETE FROM airlinerra_game.airline_route_planning_drafts_v1 p
 USING airlinerra_game.airlines a
 WHERE p.id=$3::uuid AND p.airline_id=$2::uuid
   AND a.id=p.airline_id AND a.owner_player_id=$1::uuid
   AND a.world_id=1 AND p.status='planning'
   AND p.slots_reserved=false AND p.activated=false
   AND NOT EXISTS (
    SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
    WHERE s.airline_id=p.airline_id AND s.flight_number=p.flight_number)
 RETURNING p.id::text AS "planId",p.flight_number AS "flightNumber"`,
 savedCabinPackage:`SELECT EXISTS (
  SELECT 1 FROM airlinerra_game.airlines a
  JOIN airlinerra_game.airline_cabin_service_settings_v1 c
   ON c.airline_id=a.id
  WHERE a.id=$2::uuid AND a.owner_player_id=$1::uuid AND a.world_id=1
   AND EXISTS (
    SELECT 1 FROM jsonb_array_elements(
     CASE WHEN jsonb_typeof(c.state->'packages')='array'
      THEN c.state->'packages' ELSE '[]'::jsonb END
    ) AS item WHERE item->>'id'=$3::text
   )
 ) AS "savedPackageExists"`,
 planSave:`INSERT INTO airlinerra_game.airline_route_planning_drafts_v1 AS p
 (world_id,airline_id,aircraft_inventory_id,flight_number,origin_airport_key,
 destination_airport_key,weekly_schedule,departure_stand_type,arrival_stand_type,
 turnaround_minutes,planning_options,reference_departure_utc,reference_arrival_utc,created_by_player_id)
 SELECT 1,a.id,i.id,$4::text,$5::text,$6::text,$7::jsonb,$8::text,$9::text,
 $10::integer,$11::jsonb,$12::timestamptz,$13::timestamptz,$1::uuid
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.airline_id=a.id
 JOIN airlinerra_game.approved_game_airports o ON o.world_id=a.world_id AND o.airport_key=$5::text
 JOIN airlinerra_game.approved_game_airports d ON d.world_id=a.world_id AND d.airport_key=$6::text
 WHERE a.id=$2::uuid AND a.owner_player_id=$1::uuid AND a.world_id=1
  AND w.state='active' AND a.iata_code IS NOT NULL AND left($4::text,2)=a.iata_code
  AND i.id=$3::uuid AND i.fleet_status='in_service'
  AND i.ownership_type IN ('owned','leased')
  AND $5::text<>$6::text
  AND NOT EXISTS (
   SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
   WHERE s.airline_id=a.id AND s.flight_number=$4::text)
  AND (
   coalesce($11::jsonb->'service'->>'cabinPackageId','basic') IN ('basic','none')
   OR EXISTS (
    SELECT 1 FROM airlinerra_game.airline_cabin_service_settings_v1 c
    CROSS JOIN LATERAL jsonb_array_elements(c.state->'packages') package
    WHERE c.airline_id=a.id
      AND package->>'id'=$11::jsonb->'service'->>'cabinPackageId'
   )
  )
 ON CONFLICT (airline_id,flight_number) DO UPDATE
 SET aircraft_inventory_id=excluded.aircraft_inventory_id,
  origin_airport_key=excluded.origin_airport_key,
  destination_airport_key=excluded.destination_airport_key,
  weekly_schedule=excluded.weekly_schedule,
  departure_stand_type=excluded.departure_stand_type,
  arrival_stand_type=excluded.arrival_stand_type,
  turnaround_minutes=excluded.turnaround_minutes,
  planning_options=excluded.planning_options,
  reference_departure_utc=excluded.reference_departure_utc,
  reference_arrival_utc=excluded.reference_arrival_utc,
  updated_at=now(),version=p.version+1
 RETURNING id::text AS "planId",flight_number AS "flightNumber",
 version,status,airline_id::text AS "airlineId"`,
 drafts:`SELECT s.id::text AS id,s.flight_number AS "flightNumber",
   s.aircraft_inventory_id::text AS "aircraftInventoryId",
   s.configuration_id::int AS "configurationId",
   s.origin_airport_key AS "originAirportKey",
   s.destination_airport_key AS "destinationAirportKey",
   s.reference_departure_utc AS "referenceDepartureUtc",
   s.reference_arrival_utc AS "referenceArrivalUtc",
   s.weekly_schedule AS "weeklySchedule",
   (SELECT count(*) = 2*jsonb_array_length(s.weekly_schedule)
     FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
     WHERE slot.schedule_id=s.id) AS "slotsReserved",
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
 routeFinancials:`SELECT airlinerra_game.section9_owned_route_financial_dashboard_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::integer,$5::integer) AS result`,
 partnershipList:`SELECT airlinerra_game.section9_list_owned_partnerships_v1(
  $1::uuid,$2::uuid) AS result`,
 partnershipPropose:`SELECT airlinerra_game.section9_manage_partnership_v1(
  $1::uuid,$2::uuid,'propose'::text,$3::text,NULL::bigint) AS result`,
 partnershipDecision:`SELECT airlinerra_game.section9_manage_partnership_v1(
  $1::uuid,$2::uuid,$3::text,NULL::text,$4::bigint) AS result`,
 rotationPreview:`SELECT airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::date,$5::integer) AS result`,
 operationsPreview:`SELECT airlinerra_game.section9_owned_commercial_activation_preflight_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::date,$5::integer) AS result`,
 crewRoster:`SELECT airlinerra_game.section9_owned_crew_roster_preview_v1(
  $1::uuid,$2::uuid,$3::uuid) AS result`,
 crewOffers:`SELECT airlinerra_game.section9_owned_crew_offers_v1(
  $1::uuid,$2::uuid,$3::uuid) AS result`,
 crewHire:`SELECT airlinerra_game.section9_hire_owned_game_crew_v1(
  $1::uuid,$2::uuid,$3::uuid,$4::integer) AS result`,
 crewSalary:`SELECT airlinerra_game.section9_owned_game_crew_salary_preview_v1(
  $1::uuid,$2::uuid) AS result`,
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
    const [fleet,drafts,plans]=await Promise.all([
      client.query(SCHEDULE_SQL.fleet,[body.airlineId]),
      client.query(SCHEDULE_SQL.drafts,[body.airlineId]),
      client.query(SCHEDULE_SQL.planList,[body.airlineId])
    ]);
    return respond(200,{readOnly:false,activationAvailable:false,
      fleet:fleet.rows,drafts:drafts.rows,plans:plans.rows});
   }
   if(body.action==='booking-window-preview'){
    const response=await client.query(SCHEDULE_SQL.bookingWindowPreview,[
     userId,body.airlineId,body.scheduleId
    ]);
    const result=response.rows[0]?.result;
    if(response.rowCount!==1||!result)
     return respond(404,{error:'OWNED_SCHEDULE_OR_GAME_CLOCK_NOT_AVAILABLE'});
    if(result.readOnly!==true||result.bookingEnabled!==false||
       result.passengerBookingsCreated!==false||result.ledgerPosted!==false||
       result.worldId!==1||result.scheduleId!==body.scheduleId||
       result.status!=='seven_day_preview_only'||
       result.windowDays!==7||!Array.isArray(result.occurrences)||
       result.occurrences.length>7||
       result.occurrences.some(x=>x.bookingEnabled!==false||
        x.status!=='not_saleable'||x.passengerBookings!==null))
     return respond(503,{error:'UNSAFE_BOOKING_PREVIEW_RESPONSE'});
    return respond(200,result);
   }
   if(body.action==='plan-delete'){
    const result=await client.query(SCHEDULE_SQL.planDelete,[
     userId,body.airlineId,body.planId
    ]);
    if(result.rowCount!==1)
     return respond(409,{error:'PLAN_NOT_CANCELLABLE',
      reason:'NOT_OWNED_OR_HAS_OPERATIONAL_SCHEDULE'});
    return respond(200,{deleted:true,...result.rows[0],
     passengerBookingsChanged:false,airportSlotsChanged:false,ledgerPosted:false,
     message:'Inactive planning route deleted. No flight or commercial booking changed.'});
   }
   if(body.action==='commissioning-status'||body.action==='commissioning-request'){
    // The authenticated owner can request/status a starter inspection once.
    // This never approves condition, age, maintenance or flight operations.
    const action=body.action==='commissioning-request'?'request':'status';
    const response=await client.query(SCHEDULE_SQL.commissioning,[
      userId,body.airlineId,body.aircraftInventoryId,action
    ]);
    const result=response.rows?.[0]?.result;
    if(response.rowCount!==1||!result||
       typeof result.status!=='string'||
       result.flightActivated!==false||
       result.inspectionCompleted!==false||
       result.created!==true&&result.created!==false||
       (result.ledgerPosted!==undefined&&result.ledgerPosted!==false))
      return respond(503,{error:'COMMISSIONING_STATUS_UNVERIFIED'});
    if(result.status.startsWith('blocked_'))
      return respond(409,{...result,commissioningPending:false});
    // Record only the six independently corroborated game-data checks.
    // This is NOT a physical inspection, maintenance sign-off, or clearance.
    let gameData=null;
    if(result.status!=='not_requested'){
     const follow=await client.query(SCHEDULE_SQL.commissioningDataInspection,[
      userId,body.airlineId,body.aircraftInventoryId,
      action==='request'?'run':'status'
     ]);
     gameData=follow.rows?.[0]?.result;
     if(follow.rowCount!==1||!gameData||
        typeof gameData.status!=='string'||
        gameData.flightActivated!==false||
        gameData.ledgerPosted!==false||
        gameData.maintenanceReady!==false||
        gameData.conditionVerified!==false||
        gameData.manufactureYearVerified!==false||
        gameData.maintenanceInspectionCompleted!==false||
        !Number.isInteger(gameData.dataChecksPassed??0)||
        (gameData.dataChecksPassed??0)>6)
      return respond(503,{error:'COMMISSIONING_GAME_DATA_EVIDENCE_UNAVAILABLE'});
     if(gameData.status==='game_data_inspection_blocked')
      return respond(409,{...result,
       status:gameData.status,gameDataInspectionComplete:false,
       blockingRequirements:gameData.blockingRequirements||[],
       commissioningPending:true});
    }
    // Game age and condition are separate from real aircraft records.
    // Initialize once only following an explicit owner request and six checks.
    let gameAirframe=null,gameMaintenance=null;
    if(gameData?.status==='in_review'){
     const gameInit=await client.query(SCHEDULE_SQL.commissioningGameAirframe,[
      userId,body.airlineId,body.aircraftInventoryId,
      action==='request'?'initialize':'status'
     ]);
     gameAirframe=gameInit.rows?.[0]?.result;
     if(gameInit.rowCount!==1||!gameAirframe||
        gameAirframe.dispatchApproved!==false||
        gameAirframe.flightActivated!==false||
        gameAirframe.ledgerPosted!==false||
        gameAirframe.physicalConditionVerified!==false||
        gameAirframe.realManufactureYearVerified!==false)
      return respond(503,{error:'GAME_AIRFRAME_BASELINE_UNVERIFIED'});
     if(gameAirframe.status==='not_initialized'&&action==='status'){
      return respond(200,{...result,status:gameData.status,
       gameDataInspectionComplete:gameData.gameDataInspectionComplete===true,
       gameDataChecksPassed:gameData.dataChecksPassed??0,
       gameDataChecksRequired:6,gameAgeYears:null,gameConditionPct:null,
       gameMaintenanceDue:null,gameMaintenanceGrounded:true,
       physicalConditionVerified:false,manufactureYearVerified:false,
       physicalInspectionCompleted:false,aircraftClearedForFlight:false,
       commissioningPending:true});
     }
     const gameDue=await client.query(SCHEDULE_SQL.maintenanceGameDue,[
      userId,body.airlineId,body.aircraftInventoryId,
      // Owner does not supply or choose the authoritative game day.
      // This read uses the same private clock that anchors the service model.
      // Readback is still guarded against incomplete/unsafe output.
      (await client.query(
       'SELECT confirmed_game_date FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1'
      )).rows?.[0]?.confirmed_game_date
     ]);
     gameMaintenance=gameDue.rows?.[0]?.result;
     if(gameDue.rowCount!==1||!gameMaintenance||
        gameMaintenance.readOnly!==true||
        gameMaintenance.maintenanceReady!==false||
        gameMaintenance.dispatchApproved!==false||
        gameMaintenance.flightActivated!==false||
        gameMaintenance.ledgerPosted!==false||
        gameMaintenance.gameDatePrecisionOnly!==true||
        !Array.isArray(gameMaintenance.checks)||
        gameMaintenance.checks.length!==6||
        typeof gameMaintenance.gameMaintenanceGrounded!=='boolean')
      return respond(503,{error:'GAME_MAINTENANCE_DUE_UNVERIFIED'});
    }
    return respond(200,{...result,
     status:gameData?.status??result.status,
     gameDataInspectionComplete:gameData?.gameDataInspectionComplete===true,
     gameDataChecksPassed:gameData?.dataChecksPassed??0,
     gameDataChecksRequired:gameData?.requiredDataChecks??6,
     gameAgeYears:gameMaintenance?.gameAgeYears??null,
     gameConditionPct:gameMaintenance?.gameConditionPct??null,
     gameMaintenanceDue:gameMaintenance?.checks??null,
     gameMaintenanceGrounded:gameMaintenance?.gameMaintenanceGrounded??true,
     gameMaintenanceDueCount:gameMaintenance?.dueCheckCount??null,
     gameMaintenanceDateOnly:true,
     physicalConditionVerified:false,manufactureYearVerified:false,
     physicalInspectionCompleted:false,aircraftClearedForFlight:false,
     commissioningPending:['requested','in_review'].includes(gameData?.status??result.status)});
   }
   if(['maintenance-job-status','maintenance-job-book','maintenance-job-cancel'].includes(body.action)){
    // New game maintenance job lifecycle: private owner/aircraft/clock/airport checks.
    // No real aircraft inspection, fleet activation, fuel charge or financial posting.
    const task=body.action==='maintenance-job-book'?'book':
      body.action==='maintenance-job-cancel'?'cancel':'status';
    const query=await client.query(SCHEDULE_SQL.maintenanceGameJob,[
      userId,body.airlineId,body.aircraftInventoryId,task,body.checkCode??null
    ]);
    const result=query.rows?.[0]?.result;
    if(query.rowCount!==1||!result||typeof result.status!=='string'||
       result.flightActivated!==false||result.ledgerPosted!==false||
       result.status==='scheduled'&&(
        result.created!==true||typeof result.jobId!=='string'||
        result.gameJobOnly!==true))
      return respond(503,{error:'GAME_MAINTENANCE_JOB_RESPONSE_UNVERIFIED'});
    if(result.status==='scheduled'||result.status==='game_maintenance_jobs'||
       result.status==='cancelled')return respond(200,result);
    return respond(409,{...result,created:false,aircraftClearedForFlight:false});
   }
   if(body.action==='operational-create'){
    // Create route never silently saves a planning-only record.
    // Owner-scoped, zero-write readiness check; no fabricated approvals.
    const owner=await client.query(SCHEDULE_SQL.owner,[body.airlineId,userId]);
    if(owner.rowCount!==1)return respond(403,{error:'Airline not owned by this account'});
    const live=await client.query(SCHEDULE_SQL.operationalReadiness);
    const state=live.rows?.[0];
    if(live.rowCount!==1||!state)return respond(503,{
     error:'OPERATIONAL_READINESS_UNAVAILABLE',routeCreated:false});
    const missing=[];
    if(state.world_state!=='active'||!state.authoritative_clock_connected||
       !state.clock_producer_enabled)
     missing.push('WORLD_CLOCK_NOT_READY');
    const physical=await client.query(SCHEDULE_SQL.aircraftPrerequisites,[
     userId,body.airlineId,body.aircraftInventoryId,body.originAirportKey
    ]);
    const aircraft=physical.rows?.[0];
    if(physical.rowCount!==1||!aircraft){
     missing.push('AIRCRAFT_NOT_IN_AIRLINE_FLEET');
    }else{
     if(aircraft.aircraftInService!==true)missing.push('AIRCRAFT_NOT_IN_SERVICE');
     if(aircraft.startingLocationVerified!==true)
      missing.push('AIRCRAFT_STARTING_LOCATION_NOT_VERIFIED');
     else if(aircraft.atOrigin!==true)
      missing.push('AIRCRAFT_NOT_VERIFIED_AT_ORIGIN');
     if(aircraft.gameFuelEstimateReady!==true)
      missing.push('AIRCRAFT_FUEL_GAME_INPUTS_INCOMPLETE');
     if(aircraft.fuelDispatchModelApproved!==true)
      missing.push('AIRCRAFT_FUEL_DISPATCH_MODEL_NOT_APPROVED');
     if(aircraft.fuelAccountingModelApproved!==true)
      missing.push('AIRCRAFT_FUEL_ACCOUNTING_MODEL_NOT_APPROVED');
     if(aircraft.maintenanceBaselineVerified!==true)
      missing.push('AIRCRAFT_MAINTENANCE_BASELINE_NOT_VERIFIED');
    }
    // Independent owner/clock-scoped maintenance verification. This is
    // read-only and can never manufacture condition, age, or completed checks.
    let maintenance=null;
    if(physical.rowCount===1&&aircraft){
     const receipt=await client.query(SCHEDULE_SQL.maintenanceReadiness,[
      userId,body.airlineId,body.aircraftInventoryId,state.confirmed_game_date
     ]);
     maintenance=receipt.rows?.[0]?.result;
     if(receipt.rowCount!==1||!maintenance||
        maintenance.readOnly!==true||maintenance.maintenanceReady!==false||
        maintenance.dispatchApproved!==false||
        maintenance.flightActivated!==false||
        maintenance.ledgerPosted!==false||
        !Array.isArray(maintenance.blockers)||
        maintenance.blockers.some(code=>typeof code!=='string'||code.length>128))
      return respond(503,{error:'MAINTENANCE_EVIDENCE_UNAVAILABLE',
       routeCreated:false});
     for(const reason of maintenance.blockers){
      if(!missing.includes(reason))missing.push(reason);
     }
    }
    // Separate game-day maintenance gate. Unlike unverified real inspection
    // it can evaluate explicit GAME dates, but does not release flights.
    let gameMaintenance=null;
    const firstFlightGameDate=nextWeeklyDepartureGameDate(
     state.confirmed_game_date,body.weeklySchedule,body.launchDelayDays??0
    );
    if(!firstFlightGameDate)return respond(503,{
      error:'MAINTENANCE_FLIGHT_GAME_DATE_UNAVAILABLE',routeCreated:false});
    if(physical.rowCount===1&&aircraft){
     const evaluated=await client.query(SCHEDULE_SQL.maintenanceGameDue,[
      userId,body.airlineId,body.aircraftInventoryId,
      firstFlightGameDate
     ]);
     gameMaintenance=evaluated.rows?.[0]?.result;
     if(evaluated.rowCount!==1||!gameMaintenance||
        gameMaintenance.readOnly!==true||
        gameMaintenance.maintenanceReady!==false||
        gameMaintenance.dispatchApproved!==false||
        gameMaintenance.flightActivated!==false||
        gameMaintenance.ledgerPosted!==false||
        typeof gameMaintenance.gameMaintenanceGrounded!=='boolean')
      return respond(503,{error:'GAME_MAINTENANCE_PREFLIGHT_UNAVAILABLE',
       routeCreated:false});
     if(gameMaintenance.gameMaintenanceGrounded)
      missing.push(gameMaintenance.status==='game_maintenance_due'?
       'GAME_AIRCRAFT_MAINTENANCE_CHECK_DUE':
       'GAME_MAINTENANCE_EVIDENCE_MISSING');
     if(gameMaintenance.hourlyGroundingEnforced!==true)
      missing.push('MAINTENANCE_HOURLY_GROUNDING_NOT_CONNECTED');
     if(gameMaintenance.maintenanceCompletionSchedulingConnected!==true)
      missing.push('MAINTENANCE_SERVICE_JOB_AND_RELEASE_NOT_CONNECTED');
    }
    // Exact UTC check for the reference flight and any reserved game service;
    // recurring departures require separate comprehensive certification.
    let maintenanceFlightWindow=null;
    if(physical.rowCount===1&&aircraft){
     if(!body.referenceDepartureUtc||!body.referenceArrivalUtc){
      missing.push('GAME_MAINTENANCE_FLIGHT_TIMES_NOT_VERIFIED');
     }else{
      const windowResponse=await client.query(SCHEDULE_SQL.maintenanceFlightWindow,[
       userId,body.airlineId,body.aircraftInventoryId,
       body.referenceDepartureUtc,body.referenceArrivalUtc
      ]);
      maintenanceFlightWindow=windowResponse.rows?.[0]?.result;
      if(windowResponse.rowCount!==1||!maintenanceFlightWindow||
         maintenanceFlightWindow.readOnly!==true||
         maintenanceFlightWindow.dispatchApproved!==false||
         maintenanceFlightWindow.flightActivated!==false||
         maintenanceFlightWindow.ledgerPosted!==false||
         !Array.isArray(maintenanceFlightWindow.blockers)||
         maintenanceFlightWindow.blockers.some(x=>typeof x!=='string'||x.length>100))
       return respond(503,{error:'GAME_MAINTENANCE_HOUR_WINDOW_UNVERIFIED',
        routeCreated:false});
      for(const code of maintenanceFlightWindow.blockers)
       if(!missing.includes(code))missing.push(code);
      if(maintenanceFlightWindow.hourlyJobOverlapChecked!==true)
       missing.push('MAINTENANCE_HOURLY_RESERVATION_CHECK_INCOMPLETE');
      if(maintenanceFlightWindow.hourlyJobOverlapChecked===true&&
         maintenanceFlightWindow.flightWindowClear!==true)
       missing.push('MAINTENANCE_FLIGHT_WINDOW_BLOCKED');
     }
    }
    // A preview for a single reference flight is not a whole recurring
    // weekly schedule. Full route booking remains fail closed.
    missing.push('RECURRING_MAINTENANCE_WINDOW_CERTIFICATION_NOT_CONNECTED');
    // Crew is intentionally out of Phase 1. These are independent, real
    // non-crew dependencies, not fictitious permits or release records.
    missing.push('ATOMIC_SCHEDULE_AND_AIRPORT_SLOT_ACTIVATION_NOT_CONNECTED',
     'TRUSTED_AIRCRAFT_EXECUTION_NOT_CONNECTED',
     'SEVEN_DAY_PASSENGER_BOOKING_NOT_CONNECTED');
    if(state.automatic_flight_and_fuel_settlement_enabled!==true)
     missing.push('FLIGHT_FINANCIAL_SETTLEMENT_NOT_CONNECTED');
    return respond(409,{error:'OPERATIONAL_ROUTE_CREATION_BLOCKED',
     reason:'GAME_ENGINE_NOT_READY',routeCreated:false,scheduleId:null,
     slotsReserved:false,activated:false,bookingEnabled:false,
     passengerBookingsCreated:false,ledgerPosted:false,
     crewRequired:false,crewCostsIncluded:false,
     aircraftPositionStatus:aircraft?.positionStatus??null,
     originalStarterPosition:aircraft?.originalStarterPosition===true,
     gameFuelEstimateReady:aircraft?.gameFuelEstimateReady===true,
     maintenanceUsageTrackingStarted:aircraft?.maintenanceUsageTrackingStarted===true,
     maintenanceStatus:maintenance?.status??'aircraft_not_verified',
     conditionEvidenceVerified:maintenance?.conditionEvidenceVerified===true,
     manufactureYearVerified:maintenance?.manufactureYearVerified===true,
     maintenanceHistoryVerifiedChecks:maintenance?.checkTypesWithVerifiedHistory??0,
     maintenanceRequiredCheckTypes:maintenance?.checkPolicies??null,
     maintenanceDueEvaluationConnected:maintenance?.checkDueEvaluationConnected===true,
     blockingRequirements:missing,verifiedGameDate:state.confirmed_game_date||null});
   }
   if(body.action==='plan-save'){
    const result=await client.query(SCHEDULE_SQL.planSave,[
     userId,body.airlineId,body.aircraftInventoryId,body.flightNumber,
     body.originAirportKey,body.destinationAirportKey,
     JSON.stringify(body.weeklySchedule),body.departureStand??null,
     body.arrivalStand,body.turnaroundMinutes,
     JSON.stringify({fares:body.fares,service:body.service,
      launchDelayDays:body.launchDelayDays??0}),
     body.referenceDepartureUtc??null,body.referenceArrivalUtc??null
    ]);
    if(result.rowCount!==1||!result.rows[0]?.planId){
     const packageId=body.service.cabinPackageId;
     if(typeof packageId==='string'&&/^pkg-[1-9][0-9]{0,5}$/.test(packageId)){
      const stored=await client.query(SCHEDULE_SQL.savedCabinPackage,[
       userId,body.airlineId,packageId
      ]);
      if(stored.rowCount!==1||typeof stored.rows?.[0]?.savedPackageExists!=='boolean')
       return respond(503,{error:'Cabin package verification unavailable'});
      if(stored.rows[0].savedPackageExists===false)
       return respond(409,{error:'ROUTE_PLANNING_REQUIREMENTS_NOT_MET',
        reason:'CABIN_PACKAGE_NOT_SAVED',
        message:'Save this custom package under Flight Services before creating the route.'});
     }
     return respond(409,{error:'ROUTE_PLANNING_REQUIREMENTS_NOT_MET',
      reason:'AIRLINE_AIRCRAFT_AIRPORT_OR_FLIGHT_NUMBER_NOT_ELIGIBLE'});
    }
    const saved=result.rows[0];
    return respond(200,{...saved,canActivateNormalFlight:false,
     slotsReserved:false,passengerBookingsCreated:false,ledgerPosted:false,
     message:'Owner-scoped planning route saved; no flight activated or slot reserved.'});
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
   if(body.action==='fee-preview'){
    const owned=await client.query(SCHEDULE_SQL.feeAircraft,[
     userId,body.airlineId,body.aircraftInventoryId
    ]);
    if(owned.rowCount!==1||!Number.isSafeInteger(Number(owned.rows?.[0]?.configurationId)))
     return respond(403,{error:'Owner-verified in-service aircraft is required'});
    const useType=owned.rows[0].useType;
    if((useType==='cargo'&&
        (body.departureStand!=='cargo'||body.arrivalStand!=='cargo'))||
       (useType==='passenger'&&
        (body.departureStand==='cargo'||body.arrivalStand==='cargo')))
     return respond(409,{error:'Stand type incompatible with aircraft'});
    const result=await client.query(SCHEDULE_SQL.feePreview,[
     body.originAirportKey,body.destinationAirportKey,
     owned.rows[0].configurationId,body.departureStand,
     body.arrivalStand,body.parkingMinutes
    ]);
    const q=result.rows?.[0]?.result;
    const expected=['departureAirportMovementUsd','arrivalLandingUsd',
     'departureGroundHandlingUsd','arrivalStandParkingUsd',
     'departureTerminalAirTrafficControlUsd','enrouteAirTrafficControlUsd',
     'departingPassengerFacilityUsd','departingPassengerSecurityUsd',
     'internationalPassengerProcessingUsd','originCargoHandlingUsd',
     'destinationCargoHandlingUsd'];
    const values=expected.map(k=>q?.fees?.[k]);
    if(result.rowCount!==1||q?.status!=='game_operating_fee_preview_only'||
      q.worldId!==1||q.currency!=='USD'||q.costBasis!=='airlinerra_game_model_only'||
      q.originAirportKey!==body.originAirportKey||
      q.destinationAirportKey!==body.destinationAirportKey||
      q.departureStand!==body.departureStand||
      q.arrivalStand!==body.arrivalStand||
      q.arrivalParkingMinutes!==body.parkingMinutes||
      q.passengers!==0||Number(q.cargoTonnes)!==0||
      q.canPostToLedger!==false||q.cashPosted!==false||
      q.operationAuthorized!==false||q.fuelIncluded!==false||
      q.isOfficialAviationTariff!==false||
      !values.every(x=>typeof x==='number'&&Number.isFinite(x)&&x>=0)||
      !Number.isFinite(q.totalGameOperatingFeesUsd)||
      Math.abs(values.reduce((n,x)=>n+x,0)-q.totalGameOperatingFeesUsd)>0.07)
      return respond(503,{error:'Verified fee preview unavailable'});
    return respond(200,{
     status:'owner_verified_fixed_fee_baseline',readOnly:true,
     airlineId:body.airlineId,aircraftInventoryId:body.aircraftInventoryId,
     airportFeeQuote:q,passengersAssumed:0,cargoTonnesAssumed:0,
     canBookFlight:false,cashPosted:false,operationAuthorized:false,
     estimatedWholeFlightCost:false
    });
   }
   if(body.action==='route-financials'){
    const response=await client.query(SCHEDULE_SQL.routeFinancials,[
     userId,body.airlineId,body.scheduleId,body.loadPercent,body.parkingMinutes
    ]);
    const data=response.rows?.[0]?.result;
    if(response.rowCount!==1||
      data?.status!=='route_financial_dashboard_read_only'||
      data?.scheduleId!==body.scheduleId||
      data?.airlineId!==body.airlineId||data?.worldId!==1||
      data?.readOnly!==true||data?.cashPosted!==false||
      data?.bookingsCreated!==false||data?.flightActivated!==false||
      data?.estimate?.status!=='draft_not_earned'||
      data?.estimate?.airportFeeQuote?.canPostToLedger!==false||
      data?.history?.source!=='verified_arrival_and_posted_airline_ledger_only'||
      !Array.isArray(data?.history?.lastSevenFlights)||
      data.history.lastSevenFlights.length>7)
     return respond(503,{error:'Unverified route financial statement'});
    return respond(200,data);
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
   if(body.action==='crew-offers'){
    const response=await client.query(SCHEDULE_SQL.crewOffers,
     [userId,body.airlineId,body.scheduleId]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Crew market unavailable'});
    const data=response.rows[0].result;
    if(data.readOnly!==true||data.canActivateNormalFlight!==false||
       !Array.isArray(data.offers))
     return respond(503,{error:'Unverified crew market'});
    return respond(200,data);
   }
   if(body.action==='crew-hire'){
    const response=await client.query(SCHEDULE_SQL.crewHire,
     [userId,body.airlineId,body.scheduleId,body.candidateSlot]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Crew contract could not be signed'});
    const data=response.rows[0].result;
    if(data.status!=='game_crew_contract_signed'||
       data.canActivateNormalFlight!==false||data.ledgerPosted!==false)
     return respond(503,{error:'Crew contract safety check failed'});
    return respond(200,data);
   }
   if(body.action==='crew-salary'){
    const response=await client.query(SCHEDULE_SQL.crewSalary,
     [userId,body.airlineId]);
    if(response.rowCount!==1||!response.rows[0]?.result)
     return respond(503,{error:'Crew salary forecast unavailable'});
    const data=response.rows[0].result;
    if(data.status!=='game_crew_salary_forecast'||
       data.readOnly!==true||data.automaticPayrollEnabled!==false)
     return respond(503,{error:'Crew payroll is not operationally released'});
    return respond(200,data);
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
    const readiness=response.rows[0].result;
    if(readiness.canActivateNormalFlight!==false)
     return respond(503,{error:'Flight activation is not operationally released'});
    return respond(200,readiness);
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
