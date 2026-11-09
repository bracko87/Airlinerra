-- Owner-scoped delivery-position diagnostics for first planned aircraft
-- departure. This does NOT certify ongoing location after a flight.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_from date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE target record; proof record; first_leg record;
 schedules integer; search_from date; scan_end date;
 invalid_entries integer; unknown_timezone integer;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL OR
  p_from IS NULL OR p_from NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
  OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_DELIVERY_POSITION_PREVIEW';END IF;
 SELECT d.id,d.airline_id,d.aircraft_inventory_id,d.configuration_id,
  d.origin_airport_key,d.version,
  f.registration,f.fleet_status,f.configuration_id AS fleet_configuration,
  w.state AS world_state,clock.clock_source,
  clock.confirmed_game_date
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a
  ON a.id=d.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=d.aircraft_inventory_id AND f.airline_id=a.id
 JOIN public.airlinerra_game_worlds w ON w.id=a.world_id
 LEFT JOIN airlinerra_game.holding_world_clock_v1 clock
  ON clock.world_id=a.world_id
 WHERE d.id=p_schedule AND d.airline_id=p_airline AND d.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_DELIVERY_POSITION_SCHEDULE_NOT_OWNED';END IF;

 SELECT anchor.aircraft_inventory_id,anchor.airline_id,
  anchor.acquisition_order_id,anchor.inspection_id,
  anchor.airport_key,anchor.anchored_game_date,
  anchor.inspection_reviewed_at,
  o.order_status,i.inspection_status,
  i.reviewed_at,i.reviewer_reference
 INTO proof
 FROM airlinerra_game.section9_aircraft_delivery_position_v1 anchor
 JOIN airlinerra_game.aircraft_acquisition_orders_v1 o
  ON o.order_id=anchor.acquisition_order_id
  AND o.airline_id=anchor.airline_id
  AND o.aircraft_inventory_id=anchor.aircraft_inventory_id
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 i
  ON i.inspection_id=anchor.inspection_id AND i.order_id=o.order_id
 WHERE anchor.aircraft_inventory_id=target.aircraft_inventory_id
  AND anchor.airline_id=p_airline
  AND o.delivery_home_airport_key=anchor.airport_key
  AND o.registration=target.registration
  AND o.configuration_id=target.configuration_id
  AND i.inspection_status='approved'
  AND i.reviewed_at=anchor.inspection_reviewed_at
  AND i.reviewer_reference=anchor.reviewer_reference
  AND o.order_status='delivered_pending_inspection';

 SELECT count(*) INTO schedules
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 WHERE d.world_id=1 AND d.airline_id=p_airline
  AND d.aircraft_inventory_id=target.aircraft_inventory_id;
 IF schedules>250 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_POSITION_SCHEDULES_REQUIRE_SHARDING';END IF;

 -- To test the initial departure, scan from the immutable delivery date,
 -- not from a user-supplied arbitrary later date that could skip flights.
 search_from:=coalesce(proof.anchored_game_date,p_from);
 scan_end:=least(search_from+42,DATE '2199-12-31');

 WITH routes AS MATERIALIZED(
  SELECT s.id,s.origin_airport_key,s.weekly_schedule,
    s.reference_departure_utc,s.reference_arrival_utc,
    tz.timezone_iana,validtz.name AS safe_tz
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  LEFT JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
  LEFT JOIN pg_catalog.pg_timezone_names validtz
   ON validtz.name=tz.timezone_iana
  WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=target.aircraft_inventory_id
 ), items AS MATERIALIZED(
  SELECT r.*,e.ordinality::int AS weekly_entry,
   e.item->>'day' AS weekday_text,e.item->>'time' AS hhmm,
   (jsonb_typeof(e.item)='object'
    AND coalesce(e.item->>'day','')~'^[0-6]$'
    AND coalesce(e.item->>'time','')~
     '^([01][0-9]|2[0-3]):[0-5][0-9]$') AS entry_ok
  FROM routes r CROSS JOIN LATERAL
   jsonb_array_elements(r.weekly_schedule) WITH ORDINALITY AS e(item,ordinality)
 ), departures AS MATERIALIZED(
  SELECT q.id,q.origin_airport_key,q.weekly_entry,
   day_value::date AS local_date,
   day_value::date+q.hhmm::time AS local_timestamp,
   ((day_value::date+q.hhmm::time) AT TIME ZONE q.safe_tz) AS departure_utc,
   q.safe_tz
  FROM items q
  CROSS JOIN LATERAL generate_series(
   search_from::timestamp,scan_end::timestamp,interval '1 day') AS day_value
  WHERE q.entry_ok AND q.safe_tz IS NOT NULL
    AND (q.weekday_text)::int=
     extract(isodow from day_value)::int-1
 ), flagged AS MATERIALIZED(
  SELECT d.*, (
   (d.departure_utc AT TIME ZONE d.safe_tz)
      IS DISTINCT FROM d.local_timestamp
   OR ((d.departure_utc-interval '1 hour') AT TIME ZONE d.safe_tz)
      =d.local_timestamp
   OR ((d.departure_utc+interval '1 hour') AT TIME ZONE d.safe_tz)
      =d.local_timestamp) AS invalid_local_time
  FROM departures d
 )
 SELECT id,origin_airport_key,weekly_entry,local_date,
  departure_utc,invalid_local_time INTO first_leg
 FROM flagged ORDER BY departure_utc,id,weekly_entry LIMIT 1;

 WITH routes AS MATERIALIZED(
  SELECT s.weekly_schedule,
    tz.timezone_iana,v.name AS valid_tz
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  LEFT JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
  LEFT JOIN pg_catalog.pg_timezone_names v ON v.name=tz.timezone_iana
  WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=target.aircraft_inventory_id
 ), items AS (
  SELECT jsonb_typeof(e.item)='object'
    AND coalesce(e.item->>'day','')~'^[0-6]$'
    AND coalesce(e.item->>'time','')~
       '^([01][0-9]|2[0-3]):[0-5][0-9]$' AS ok
  FROM routes r CROSS JOIN LATERAL
    jsonb_array_elements(r.weekly_schedule) AS e(item)
 )
 SELECT count(*) FILTER(WHERE ok IS NOT TRUE)::int
 INTO invalid_entries FROM items;
 SELECT count(*)::int INTO unknown_timezone FROM
 airlinerra_game.airline_flight_schedule_drafts_v1 s
 LEFT JOIN airlinerra_game.airport_reference_profiles tz
  ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
 LEFT JOIN pg_catalog.pg_timezone_names validtz
  ON validtz.name=tz.timezone_iana
 WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=target.aircraft_inventory_id
   AND validtz.name IS NULL;

 RETURN jsonb_build_object(
  'status',CASE WHEN proof.aircraft_inventory_id IS NULL
    THEN 'delivery_anchor_missing'
   WHEN target.world_state<>'active'
    OR target.clock_source<>'authoritative_game_engine'
    OR target.confirmed_game_date IS NULL
    THEN 'world_clock_not_verified'
   WHEN target.fleet_status<>'in_service'
    OR target.fleet_configuration<>target.configuration_id
    THEN 'aircraft_not_in_service'
   WHEN invalid_entries>0 OR unknown_timezone>0
    THEN 'timetable_evidence_incomplete'
   WHEN first_leg.id IS NULL THEN 'no_initial_departure_in_42_days'
   WHEN first_leg.invalid_local_time THEN 'invalid_initial_departure_time'
   WHEN proof.airport_key<>first_leg.origin_airport_key
    THEN 'first_departure_airport_mismatch'
   ELSE 'delivery_matches_first_planned_departure'
   END,
  'scheduleId',p_schedule,'aircraftInventoryId',target.aircraft_inventory_id,
  'deliveryAnchorRecorded',proof.aircraft_inventory_id IS NOT NULL,
  'deliveryAirportKey',proof.airport_key,
  'deliveryGameDate',proof.anchored_game_date,
  'inspectionApproved',proof.inspection_status='approved',
  'firstPlannedDepartureAirport',first_leg.origin_airport_key,
  'firstPlannedDepartureUtc',first_leg.departure_utc,
  'firstPlannedDepartureLocalDate',first_leg.local_date,
  'firstPlannedScheduleId',first_leg.id,
  'initialDepartureMatchesDelivery',
    CASE WHEN proof.aircraft_inventory_id IS NULL OR
      first_leg.id IS NULL OR
      first_leg.invalid_local_time OR invalid_entries>0 OR
      unknown_timezone>0 THEN NULL
    ELSE proof.airport_key=first_leg.origin_airport_key END,
  'invalidWeeklyEntries',invalid_entries,
  'unknownOriginTimezones',unknown_timezone,
  'movementHistoryVerified',false,
  'currentAircraftLocationVerified',false,
  'flightActivationReleased',false,
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
 uuid,uuid,uuid,date,integer)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_date date,
 p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE base jsonb; staff jsonb; rest jsonb; position jsonb;
 reasons jsonb;
BEGIN
 base:=airlinerra_game.section9_owned_operational_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 staff:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 rest:=airlinerra_game.section9_owned_crew_rest_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 position:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 IF base->>'readOnly'<>'true' OR base->>'canActivateNormalFlight'<>'false'
 OR staff->>'readOnly'<>'true' OR staff->>'canActivateNormalFlight'<>'false'
 OR rest->>'readOnly'<>'true' OR rest->>'canActivateNormalFlight'<>'false'
 OR position->>'readOnly'<>'true' OR
    position->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNSAFE_OPERATING_EVIDENCE';END IF;

 reasons:=coalesce(base->'blockers','[]'::jsonb)
  || to_jsonb(ARRAY[
    CASE WHEN position->>'deliveryAnchorRecorded'<>'true' THEN
      'DELIVERY_POSITION_ANCHOR_NOT_RECORDED'
     WHEN position->>'status'='first_departure_airport_mismatch' THEN
      'FIRST_PLANNED_DEPARTURE_AT_WRONG_AIRPORT'
     WHEN position->>'status'='timetable_evidence_incomplete' OR
          position->>'status'='invalid_initial_departure_time' THEN
      'AIRCRAFT_DEPARTURE_TIME_UNVERIFIED'
     ELSE 'INITIAL_POSITION_NOT_OPERATIONALLY_CERTIFIED' END,
    'OPERATED_AIRCRAFT_MOVEMENT_HISTORY_MISSING'
   ]);
 RETURN base || jsonb_build_object(
  'crewStaffing',staff->'crew',
  'operatingPermissionEvidence',staff->'permissions',
  'crewRest',rest,
  'aircraftPosition',position,
  'blockers',reasons,
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 uuid,uuid,uuid,date,integer)
 FROM PUBLIC,anon,authenticated;
