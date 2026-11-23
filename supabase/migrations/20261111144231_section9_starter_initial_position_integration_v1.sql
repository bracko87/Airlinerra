-- Section 9: honor documented original starter-aircraft origins and
-- reject future-dated operated movements. Acquired-aircraft inspection,
-- source signatures, operational certification and finance gates are unchanged.

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(p_player uuid, p_airline uuid, p_schedule uuid, p_from date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE target record; proof record; first_leg record; starter jsonb;
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
 JOIN airlinerra_game.aircraft_acquisition_offers_v1 approved_offer
  ON approved_offer.offer_id=o.offer_id
   AND approved_offer.world_id=o.world_id
   AND approved_offer.configuration_id=o.configuration_id
   AND approved_offer.transaction_type=o.transaction_type
   AND approved_offer.offer_status IN ('published','retired')
   AND approved_offer.pricing_basis LIKE 'AIRLINERRA_GAME_BALANCE_V1:%'
 WHERE anchor.aircraft_inventory_id=target.aircraft_inventory_id
  AND anchor.airline_id=p_airline
  AND o.delivery_home_airport_key=anchor.airport_key
  AND o.registration=target.registration
  AND o.configuration_id=target.configuration_id
  AND i.inspection_status='approved'
  AND i.reviewed_at=anchor.inspection_reviewed_at
  AND i.reviewer_reference=anchor.reviewer_reference
  AND o.order_status='delivered_pending_inspection';
 -- A one-time original starter allocation is not a purchase or inspection.
 IF NOT FOUND THEN
  starter:=airlinerra_game.section9_starter_origin_evidence_v1(
   p_airline,target.aircraft_inventory_id,p_from);
  IF starter->>'verified'='true' THEN
   SELECT target.aircraft_inventory_id AS aircraft_inventory_id,
    starter->>'airportKey' AS airport_key,
    (starter->>'assignedGameDate')::date AS anchored_game_date,
    NULL::text AS inspection_status
   INTO proof;
  END IF;
 END IF;
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
  'starterAllocationVerified',coalesce(starter->>'verified','false')='true',
  'initialPositionSource',CASE
   WHEN starter->>'verified'='true' THEN 'original_starter_allocation'
   WHEN proof.aircraft_inventory_id IS NOT NULL THEN 'approved_acquisition_delivery'
   ELSE NULL END,
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
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_movement_preview_v1(p_player uuid, p_airline uuid, p_schedule uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE target record;actual_position record;source_anchor record;starter jsonb;
 events int;world_state record;
BEGIN
 SELECT s.aircraft_inventory_id,s.configuration_id,
  f.fleet_status,f.registration
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a
  ON a.id=s.airline_id AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_MOVEMENT_PREVIEW_NOT_OWNED';END IF;
 SELECT p.airport_key,p.anchored_game_date,
  i.inspection_status,o.delivery_home_airport_key,
  i.reviewer_reference,i.reviewed_at
 INTO source_anchor
 FROM airlinerra_game.section9_aircraft_delivery_position_v1 p
 JOIN airlinerra_game.aircraft_acquisition_orders_v1 o
  ON o.order_id=p.acquisition_order_id
  AND o.airline_id=p.airline_id
  AND o.aircraft_inventory_id=p.aircraft_inventory_id
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 i
  ON i.inspection_id=p.inspection_id AND i.order_id=o.order_id
 WHERE p.aircraft_inventory_id=target.aircraft_inventory_id
  AND p.airline_id=p_airline
  AND o.delivery_home_airport_key=p.airport_key
  AND o.registration=target.registration
  AND o.configuration_id=target.configuration_id
  AND o.order_status='delivered_pending_inspection'
  AND i.inspection_status='approved'
  AND i.reviewed_at=p.inspection_reviewed_at
  AND i.reviewer_reference=p.reviewer_reference;
 IF NOT FOUND THEN
  starter:=airlinerra_game.section9_starter_origin_evidence_v1(
   p_airline,target.aircraft_inventory_id,
   (clock_timestamp() AT TIME ZONE 'Europe/Berlin')::date);
  IF starter->>'verified'='true' THEN
   SELECT starter->>'airportKey' AS airport_key,
    (starter->>'assignedGameDate')::date AS anchored_game_date
   INTO source_anchor;
  END IF;
 END IF;
 SELECT * INTO actual_position
 FROM airlinerra_game.section9_aircraft_current_position_v1 pos
 WHERE pos.aircraft_inventory_id=target.aircraft_inventory_id
  AND pos.airline_id=p_airline;
 SELECT count(*) INTO events
 FROM airlinerra_game.section9_operated_flight_movements_v1 e
 WHERE e.aircraft_inventory_id=target.aircraft_inventory_id
  AND e.airline_id=p_airline;
 SELECT w.state,c.clock_source,c.confirmed_game_date
 INTO world_state
 FROM public.airlinerra_game_worlds w
 LEFT JOIN airlinerra_game.holding_world_clock_v1 c ON c.world_id=w.id
 WHERE w.id=1;
 RETURN jsonb_build_object(
  'status',CASE
    WHEN source_anchor.airport_key IS NULL THEN 'delivery_anchor_missing'
    WHEN actual_position.aircraft_inventory_id IS NULL THEN
       'delivery_anchor_only_no_operated_flights'
    WHEN actual_position.location_status='in_flight' THEN
       'last_verified_operated_departure_in_flight'
    WHEN actual_position.location_status='grounded' THEN
       'last_verified_operated_arrival'
    ELSE 'movement_state_unavailable' END,
  'aircraftInventoryId',target.aircraft_inventory_id,
  'initialDeliveryAirport',source_anchor.airport_key,
  'deliveryAnchorValid',source_anchor.airport_key IS NOT NULL,
  'initialPositionSource',CASE
   WHEN starter->>'verified'='true' THEN 'original_starter_allocation'
   WHEN source_anchor.airport_key IS NOT NULL THEN 'approved_acquisition_delivery'
   ELSE NULL END,
  'lastVerifiedGroundAirport',
   CASE WHEN actual_position.location_status='grounded'
       THEN actual_position.airport_key
     WHEN actual_position.aircraft_inventory_id IS NULL THEN
       source_anchor.airport_key ELSE NULL END,
  'locationStatus',CASE WHEN actual_position.aircraft_inventory_id IS NOT NULL
       THEN actual_position.location_status
     WHEN source_anchor.airport_key IS NOT NULL
       THEN 'delivery_only' ELSE 'unknown' END,
  'inFlightOccurrenceId',actual_position.current_flight_occurrence_id,
  'lastMovementEventUtc',actual_position.last_event_utc,
  'lastVerifiedArrivalUtc',actual_position.last_arrival_utc,
  'verifiedOperatedMovementEvents',events,
  'operatedFlightEvidencePresent',events>0,
  'worldClockCurrentlyVerified',
   world_state.state='active'
   AND world_state.clock_source='authoritative_game_engine'
   AND world_state.confirmed_game_date IS NOT NULL,
  'currentRealTimeLocationCertified',false,
  'operationalFlightActivationReleased',false,
  'canActivateNormalFlight',false,
  'readOnly',true);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(p_airline uuid, p_aircraft uuid, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 world_record record;clock_record record;fleet_record record;
 active_count integer;unverified_count integer;
 invalid_timezone_count integer;invalid_timetable_count integer;
 dst_issue_count integer;event_count integer;candidate_rows jsonb;
BEGIN
 IF p_airline IS NULL OR p_aircraft IS NULL OR p_game_day IS NULL
 OR p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATIONS_CANDIDATE_REQUEST';END IF;
 SELECT state,opens_at INTO world_record
 FROM public.airlinerra_game_worlds WHERE id=1;
 IF world_record.state IS DISTINCT FROM 'active'
   OR world_record.opens_at IS NULL
   OR world_record.opens_at>clock_timestamp() THEN
  RETURN jsonb_build_object(
   'status','blocked_world_not_open','worldId',1,
   'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 SELECT confirmed_game_date,clock_source,last_verified_at,engine_proof_ref
 INTO clock_record FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 IF clock_record.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR clock_record.last_verified_at IS NULL
 OR length(coalesce(clock_record.engine_proof_ref,''))<12
 OR clock_record.confirmed_game_date IS NULL
 OR clock_record.confirmed_game_date<p_game_day
 OR NOT EXISTS (
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 t
   WHERE t.world_id=1 AND t.game_date=p_game_day
 ) THEN
  RETURN jsonb_build_object(
   'status','blocked_unverified_game_day','worldId',1,
   'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 SELECT id,airline_id,fleet_status INTO fleet_record
 FROM airlinerra_game.airline_aircraft_inventory
 WHERE id=p_aircraft AND airline_id=p_airline;
 IF NOT FOUND OR fleet_record.fleet_status IS DISTINCT FROM 'in_service' THEN
  RETURN jsonb_build_object(
   'status','blocked_aircraft_not_in_service','worldId',1,
   'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 -- Never promote an aircraft merely because it was assigned to a draft.
 SELECT count(*) INTO active_count
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=p_aircraft
   AND s.status='active' AND s.operationally_verified=true;
 IF active_count=0 THEN
  RETURN jsonb_build_object(
   'status','no_verified_activated_schedules','worldId',1,
   'gameDate',p_game_day,'aircraftInventoryId',p_aircraft,
   'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 IF active_count>250 THEN
  RETURN jsonb_build_object(
   'status','blocked_aircraft_schedule_sharding_required',
   'worldId',1,'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 SELECT count(*) INTO unverified_count
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 LEFT JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
  ON cap.schedule_id=s.id AND cap.airline_id=s.airline_id
  AND cap.schedule_version=s.version
 WHERE s.world_id=1 AND s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
 AND s.status='active' AND s.operationally_verified=true
 AND (cap.schedule_id IS NULL OR s.configuration_id<>f.configuration_id);
 IF unverified_count>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_unverified_activated_capacity',
   'worldId',1,'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.section9_aircraft_delivery_position_v1 a
  JOIN airlinerra_game.aircraft_acquisition_orders_v1 o
   ON o.order_id=a.acquisition_order_id AND o.airline_id=a.airline_id
   AND o.aircraft_inventory_id=a.aircraft_inventory_id
  JOIN airlinerra_game.aircraft_delivery_inspections_v1 i
   ON i.inspection_id=a.inspection_id AND i.order_id=o.order_id
  WHERE a.airline_id=p_airline AND a.aircraft_inventory_id=p_aircraft
    AND a.anchored_game_date<=p_game_day
    AND o.delivery_home_airport_key=a.airport_key
    AND o.order_status='delivered_pending_inspection'
    AND i.inspection_status='approved'
    AND i.reviewed_at=a.inspection_reviewed_at
    AND i.reviewer_reference=a.reviewer_reference
 ) AND coalesce(
    airlinerra_game.section9_starter_origin_evidence_v1(
      p_airline,p_aircraft,p_game_day)->>'verified','false')<>'true'
 THEN
  RETURN jsonb_build_object(
   'status','blocked_unverified_aircraft_delivery',
   'worldId',1,'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 SELECT count(*) INTO invalid_timezone_count
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 LEFT JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=s.world_id AND tz.airport_key=s.origin_airport_key
 LEFT JOIN pg_catalog.pg_timezone_names tz_name ON tz_name.name=tz.timezone_iana
 WHERE s.world_id=1 AND s.airline_id=p_airline
 AND s.aircraft_inventory_id=p_aircraft
 AND s.status='active' AND s.operationally_verified=true
 AND tz_name.name IS NULL;
 IF invalid_timezone_count>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_unverified_origin_timezone','worldId',1,
   'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 SELECT count(*) INTO invalid_timetable_count FROM
 airlinerra_game.airline_flight_schedule_drafts_v1 s
 CROSS JOIN LATERAL jsonb_array_elements(s.weekly_schedule) AS w(item)
 WHERE s.world_id=1 AND s.airline_id=p_airline
 AND s.aircraft_inventory_id=p_aircraft
 AND s.status='active' AND s.operationally_verified=true
 AND (jsonb_typeof(w.item) IS DISTINCT FROM 'object'
    OR coalesce(w.item->>'day','') !~ '^[0-6]$'
    OR coalesce(w.item->>'time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$');
 IF invalid_timetable_count>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_invalid_weekly_timetable','worldId',1,
   'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;

 -- Flights may last 72 hours. The preceding four and following one
 -- origin-local calendar days cover any event on the requested UTC day,
 -- including timezone offsets and international date-line crossings.
 WITH routes AS MATERIALIZED (
  SELECT s.id,s.airline_id,s.aircraft_inventory_id,s.version,
   s.weekly_schedule,s.reference_arrival_utc-s.reference_departure_utc AS duration,
   s.origin_airport_key,s.destination_airport_key,tz.timezone_iana
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
  WHERE s.world_id=1 AND s.airline_id=p_airline
    AND s.aircraft_inventory_id=p_aircraft
    AND s.status='active' AND s.operationally_verified=true
 ),
 items AS MATERIALIZED (
  SELECT r.*,w.ordinality::int AS weekly_entry,
   w.item->>'day' AS weekday_text,w.item->>'time' AS clock_text
  FROM routes r CROSS JOIN LATERAL
   jsonb_array_elements(r.weekly_schedule) WITH ORDINALITY AS w(item,ordinality)
 ),
 dated AS MATERIALIZED (
  SELECT i.id,i.airline_id,i.aircraft_inventory_id,i.version,
   i.weekly_entry,i.origin_airport_key,i.destination_airport_key,
   i.duration,i.timezone_iana,day_value::date AS local_date,
   day_value::date+i.clock_text::time AS local_departure
  FROM items i
  CROSS JOIN LATERAL generate_series(
   (p_game_day-4)::timestamp,(p_game_day+1)::timestamp,
   interval '1 day') AS day_value
  WHERE i.weekday_text::integer=extract(isodow FROM day_value)::integer-1
 ),
 calculated AS MATERIALIZED (
  SELECT d.*,
   (d.local_departure AT TIME ZONE d.timezone_iana) AS departure_utc,
   ((d.local_departure AT TIME ZONE d.timezone_iana)+d.duration) AS arrival_utc
  FROM dated d
 ),
 verified AS MATERIALIZED (
  SELECT c.*,
   (c.departure_utc AT TIME ZONE c.timezone_iana)
     IS DISTINCT FROM c.local_departure
    OR EXISTS (
      SELECT 1 FROM generate_series(-12,12) AS alt(step_15m)
      WHERE alt.step_15m<>0 AND
      ((c.departure_utc+make_interval(mins=>alt.step_15m*15))
       AT TIME ZONE c.timezone_iana)=c.local_departure
    ) AS invalid_local_time
  FROM calculated c
 ),
 events AS MATERIALIZED (
  SELECT id AS schedule_id,airline_id,aircraft_inventory_id,version,
   weekly_entry,local_date,origin_airport_key,destination_airport_key,
   'departed'::text AS phase,departure_utc AS event_utc
  FROM verified WHERE invalid_local_time=false
   AND (departure_utc AT TIME ZONE 'UTC')::date=p_game_day
  UNION ALL
  SELECT id,airline_id,aircraft_inventory_id,version,
   weekly_entry,local_date,origin_airport_key,destination_airport_key,
   'arrived'::text,arrival_utc
  FROM verified WHERE invalid_local_time=false
   AND (arrival_utc AT TIME ZONE 'UTC')::date=p_game_day
 ),
 limited AS (
  SELECT * FROM events ORDER BY event_utc,schedule_id,local_date,weekly_entry,phase
  LIMIT 501
 )
 SELECT
  (SELECT count(*)::int FROM verified WHERE invalid_local_time),
  count(*)::int,
  coalesce(jsonb_agg(jsonb_build_object(
   'worldId',1,'airlineId',e.airline_id,
   'aircraftInventoryId',e.aircraft_inventory_id,
   'scheduleId',e.schedule_id,'scheduleVersion',e.version,
   'flightLocalDate',e.local_date,'weeklyEntry',e.weekly_entry,
   'flightOccurrenceId',e.schedule_id::text||':'||e.local_date::text||':'||e.weekly_entry::text,
   'phase',e.phase,
   'scheduledEventUtc',to_char(
      date_trunc('second',e.event_utc) AT TIME ZONE 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   'originAirportKey',e.origin_airport_key,
   'destinationAirportKey',e.destination_airport_key,
   'eventId','operate-v1.'||replace(e.schedule_id::text,'-','')||'.'
     ||to_char(e.local_date,'YYYYMMDD')||'.'||e.weekly_entry::text||'.'||e.phase,
   'activatedAndCapacityVerified',true)
   ORDER BY e.event_utc,e.schedule_id,e.local_date,e.weekly_entry,e.phase),
  '[]'::jsonb)
 INTO dst_issue_count,event_count,candidate_rows FROM limited e;
 IF dst_issue_count>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_ambiguous_or_missing_local_time',
   'worldId',1,'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 IF event_count>500 THEN
  RETURN jsonb_build_object(
   'status','blocked_day_event_limit_requires_sharding',
   'worldId',1,'readOnly',true,'requiresTrustedOperationDecision',true,
   'flightActivated',false,'movementRecorded',false,
   'candidates','[]'::jsonb);
 END IF;
 RETURN jsonb_build_object(
  'status','verified_operational_candidates_only',
  'worldId',1,'airlineId',p_airline,'aircraftInventoryId',p_aircraft,
  'gameDate',p_game_day,'eventCount',event_count,
  'readOnly',true,'requiresTrustedOperationDecision',true,
  'flightActivated',false,'movementRecorded',false,
  'candidates',candidate_rows);
END $function$;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_record_signed_operated_flight_movement_v1(p_airline uuid, p_schedule uuid, p_schedule_version integer, p_local_date date, p_weekly_entry integer, p_phase text, p_event_utc timestamp with time zone, p_event_id text, p_verified_hmac text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE world_state record;clock_row record;s record;
 capacity record;origin_tz text; weekly_item jsonb;
 local_departure timestamp; scheduled_dep timestamptz;
 scheduled_arr timestamptz; occurrence text;
 fleet record; anchor record;pos record; existing record;
 position_exists boolean:=false; resolution jsonb;starter jsonb;
 change_count int;
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL
  OR p_schedule_version IS NULL OR p_schedule_version<1
  OR p_local_date IS NULL OR p_local_date NOT BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-31'
  OR p_weekly_entry IS NULL OR p_weekly_entry NOT BETWEEN 1 AND 7
  OR p_phase IS NULL OR p_phase NOT IN ('departed','arrived')
  OR p_event_utc IS NULL
  OR (p_event_utc AT TIME ZONE 'UTC')::date NOT BETWEEN
      DATE '2000-01-01' AND DATE '2199-12-31'
  OR length(coalesce(p_event_id,'')) NOT BETWEEN 12 AND 128
  OR coalesce(p_event_id,'') !~ '^[A-Za-z0-9._:-]+$'
  OR coalesce(p_verified_hmac,'') !~ '^[a-f0-9]{64}$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATED_FLIGHT_ENGINE_EVENT';END IF;
 -- Signed proof cannot turn a future scheduled event into an early movement.
 IF p_event_utc>clock_timestamp()+interval '2 seconds' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FUTURE_OPERATED_MOVEMENT_FORBIDDEN';
 END IF;
 SELECT state,opens_at INTO world_state
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 IF world_state.state IS DISTINCT FROM 'active'
  OR world_state.opens_at IS NULL
  OR world_state.opens_at>clock_timestamp() THEN
  RETURN jsonb_build_object('status','blocked_world_not_open',
   'movementRecorded',false,'bookingsCreated',false,
   'ledgerPosted',false,'flightActivated',false);
 END IF;
 SELECT * INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock_row.confirmed_game_date IS NULL
  OR clock_row.last_verified_at IS NULL
  OR length(coalesce(clock_row.engine_proof_ref,''))<12
  OR clock_row.confirmed_game_date<
      (p_event_utc AT TIME ZONE 'UTC')::date
  OR clock_row.confirmed_game_date<p_local_date
  OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 t
   WHERE t.world_id=1
    AND t.game_date=(p_event_utc AT TIME ZONE 'UTC')::date)
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_clock',
   'movementRecorded',false,'bookingsCreated',false,
   'ledgerPosted',false,'flightActivated',false);
 END IF;

 SELECT d.id,d.airline_id,d.aircraft_inventory_id,d.configuration_id,
  d.version,d.status,d.operationally_verified,d.weekly_schedule,
  d.origin_airport_key,d.destination_airport_key,
  d.reference_departure_utc,d.reference_arrival_utc,
  f.fleet_status,f.configuration_id AS fleet_configuration
 INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=d.aircraft_inventory_id AND f.airline_id=d.airline_id
 WHERE d.world_id=1 AND d.airline_id=p_airline AND d.id=p_schedule
 FOR SHARE OF d;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_FLIGHT_SCHEDULE_NOT_REGISTERED';END IF;
 IF s.version IS DISTINCT FROM p_schedule_version
  OR s.status<>'active' OR s.operationally_verified IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_schedule_not_operational',
   'movementRecorded',false,'bookingsCreated',false,
   'ledgerPosted',false,'flightActivated',false);
 END IF;
 IF s.fleet_status<>'in_service'
  OR s.fleet_configuration IS DISTINCT FROM s.configuration_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_NOT_IN_SERVICE';END IF;
 SELECT cap.schedule_id,cap.verification_source INTO capacity
 FROM airlinerra_game.section9_verified_schedule_capacity_v1 cap
 WHERE cap.schedule_id=p_schedule AND cap.airline_id=p_airline
  AND cap.schedule_version=p_schedule_version FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_FLIGHT_CAPACITY_NOT_VERIFIED';END IF;
 IF p_weekly_entry>jsonb_array_length(s.weekly_schedule) THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_OPERATED_WEEKLY_ENTRY_MISSING';END IF;
 weekly_item:=s.weekly_schedule->(p_weekly_entry-1);
 IF jsonb_typeof(weekly_item)<>'object'
  OR coalesce(weekly_item->>'day','')!~'^[0-6]$'
  OR coalesce(weekly_item->>'time','')!~
      '^([01][0-9]|2[0-3]):[0-5][0-9]$'
  OR (weekly_item->>'day')::int<>extract(isodow FROM p_local_date)::int-1
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_OPERATED_WEEKLY_TIMETABLE_INVALID';END IF;
 SELECT tz.timezone_iana INTO origin_tz
 FROM airlinerra_game.airport_reference_profiles tz
 JOIN pg_catalog.pg_timezone_names names
  ON names.name=tz.timezone_iana
 WHERE tz.world_id=1 AND tz.airport_key=s.origin_airport_key;
 IF origin_tz IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_ORIGIN_TIMEZONE_UNVERIFIED';END IF;
 local_departure:=p_local_date+
  (weekly_item->>'time')::time;
 scheduled_dep:=local_departure AT TIME ZONE origin_tz;
 scheduled_arr:=scheduled_dep+
  (s.reference_arrival_utc-s.reference_departure_utc);
 IF (scheduled_dep AT TIME ZONE origin_tz) IS DISTINCT FROM local_departure
  OR EXISTS(
    SELECT 1 FROM generate_series(-12,12) AS alternative(offset_15m)
    WHERE alternative.offset_15m<>0
      AND ((scheduled_dep+
        make_interval(mins=>alternative.offset_15m*15))
        AT TIME ZONE origin_tz)=local_departure)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_LOCAL_TIME_AMBIGUOUS_OR_NONEXISTENT';END IF;
 -- Provisional GAME event-time envelope, not an airline delay certificate.
 IF (p_phase='departed' AND (
    p_event_utc<scheduled_dep-interval '2 hours'
    OR p_event_utc>scheduled_dep+interval '24 hours'))
  OR (p_phase='arrived' AND (
    p_event_utc<scheduled_dep
    OR p_event_utc>scheduled_arr+interval '48 hours'))
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_OPERATED_EVENT_OUTSIDE_SCHEDULE_WINDOW';END IF;
 occurrence:=p_schedule::text||':'||p_local_date::text||':'||
  p_weekly_entry::text;

 -- Serialize all physical movement updates by aircraft, even if two
 -- independent schedules or concurrent workers try to depart together.
 SELECT id INTO fleet FROM airlinerra_game.airline_aircraft_inventory
 WHERE id=s.aircraft_inventory_id AND airline_id=p_airline
 AND fleet_status='in_service' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_NO_LONGER_AVAILABLE';END IF;

 -- Exact event retries are stable even after another event (e.g. arrival).
 SELECT * INTO existing
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.engine_event_id=p_event_id OR
  (m.flight_occurrence_id=occurrence AND m.phase=p_phase)
 ORDER BY (m.engine_event_id=p_event_id) DESC LIMIT 1;
 IF FOUND THEN
  IF existing.engine_event_id IS DISTINCT FROM p_event_id OR
   existing.event_hmac_sha256 IS DISTINCT FROM p_verified_hmac OR
   existing.airline_id IS DISTINCT FROM p_airline OR
   existing.schedule_id IS DISTINCT FROM p_schedule OR
   existing.schedule_version IS DISTINCT FROM p_schedule_version OR
   existing.weekly_entry IS DISTINCT FROM p_weekly_entry OR
   existing.flight_local_date IS DISTINCT FROM p_local_date OR
   existing.phase IS DISTINCT FROM p_phase OR
   existing.actual_event_utc IS DISTINCT FROM p_event_utc
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_OPERATED_EVENT_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object('status','operated_movement_replayed',
   'flightOccurrenceId',occurrence,'phase',p_phase,
   'movementRecorded',false,'replayed',true,
   'bookingsCreated',false,'ledgerPosted',false,
   'flightActivated',false);
 END IF;

 SELECT anchor.airport_key,anchor.anchored_game_date,
  source.order_status,inspection.inspection_status,
  source.registration AS order_registration,
  source.configuration_id AS order_configuration,
  i.registration AS fleet_registration
 INTO anchor
 FROM airlinerra_game.section9_aircraft_delivery_position_v1 anchor
 JOIN airlinerra_game.aircraft_acquisition_orders_v1 source
  ON source.order_id=anchor.acquisition_order_id
   AND source.airline_id=anchor.airline_id
   AND source.aircraft_inventory_id=anchor.aircraft_inventory_id
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 inspection
  ON inspection.inspection_id=anchor.inspection_id
   AND inspection.order_id=source.order_id
   AND inspection.inspection_status='approved'
   AND inspection.reviewed_at=anchor.inspection_reviewed_at
   AND inspection.reviewer_reference=anchor.reviewer_reference
 JOIN airlinerra_game.airline_aircraft_inventory i
  ON i.id=anchor.aircraft_inventory_id AND i.airline_id=anchor.airline_id
 WHERE anchor.aircraft_inventory_id=s.aircraft_inventory_id
  AND anchor.airline_id=p_airline
  AND anchor.anchored_game_date<=
   (p_event_utc AT TIME ZONE 'UTC')::date
  AND source.delivery_home_airport_key=anchor.airport_key
  AND source.order_status='delivered_pending_inspection';
 IF NOT FOUND THEN
  starter:=airlinerra_game.section9_starter_origin_evidence_v1(
   p_airline,s.aircraft_inventory_id,
   (p_event_utc AT TIME ZONE 'Europe/Berlin')::date);
  IF starter->>'verified' IS DISTINCT FROM 'true' THEN
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_OPERATED_AIRCRAFT_INITIAL_POSITION_UNVERIFIED';
  END IF;
  anchor.airport_key:=starter->>'airportKey';
 ELSIF anchor.order_registration IS DISTINCT FROM anchor.fleet_registration
  OR anchor.order_configuration IS DISTINCT FROM s.configuration_id
 THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_AIRCRAFT_DELIVERY_ANCHOR_UNVERIFIED';
 END IF;
 SELECT * INTO pos
 FROM airlinerra_game.section9_aircraft_current_position_v1
 WHERE aircraft_inventory_id=s.aircraft_inventory_id FOR UPDATE;
 position_exists:=FOUND;
 IF position_exists AND pos.airline_id IS DISTINCT FROM p_airline THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_AIRCRAFT_POSITION_AIRLINE_CHANGED';END IF;
 IF p_phase='arrived' AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
  WHERE m.flight_occurrence_id=occurrence AND m.phase='departed'
   AND m.aircraft_inventory_id=s.aircraft_inventory_id)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_ARRIVAL_WITHOUT_DEPARTURE_EVENT';END IF;
 resolution:=airlinerra_game.section9_aircraft_movement_decision_v1(
  p_phase,
  CASE WHEN position_exists THEN pos.location_status ELSE 'grounded' END,
  CASE WHEN position_exists THEN pos.airport_key ELSE anchor.airport_key END,
  CASE WHEN position_exists THEN pos.current_flight_occurrence_id ELSE NULL END,
  CASE WHEN position_exists THEN pos.last_event_utc ELSE NULL END,
  CASE WHEN position_exists THEN pos.last_departure_utc ELSE NULL END,
  s.origin_airport_key,s.destination_airport_key,occurrence,p_event_utc
 );
 IF resolution->>'allowed'<>'true' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATED_'||resolution->>'reason';END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(
  world_id,engine_event_id,event_hmac_sha256,
  airline_id,aircraft_inventory_id,schedule_id,schedule_version,
  weekly_entry,flight_local_date,flight_occurrence_id,phase,
  origin_airport_key,destination_airport_key,
  scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,p_event_id,p_verified_hmac,p_airline,s.aircraft_inventory_id,
  p_schedule,p_schedule_version,p_weekly_entry,p_local_date,
  occurrence,p_phase,s.origin_airport_key,s.destination_airport_key,
  scheduled_dep,scheduled_arr,p_event_utc);
 INSERT INTO airlinerra_game.section9_aircraft_current_position_v1(
  aircraft_inventory_id,world_id,airline_id,
  location_status,airport_key,current_flight_occurrence_id,
  last_event_utc,last_departure_utc,last_arrival_utc,
  last_engine_event_id)
 VALUES(s.aircraft_inventory_id,1,p_airline,
  resolution->>'newState',resolution->>'newAirport',
  CASE WHEN p_phase='departed' THEN occurrence ELSE NULL END,
  p_event_utc,
  CASE WHEN p_phase='departed' THEN p_event_utc ELSE pos.last_departure_utc END,
  CASE WHEN p_phase='arrived' THEN p_event_utc
       ELSE pos.last_arrival_utc END,
  p_event_id)
 ON CONFLICT(aircraft_inventory_id) DO UPDATE SET
  location_status=excluded.location_status,
  airport_key=excluded.airport_key,
  current_flight_occurrence_id=excluded.current_flight_occurrence_id,
  last_event_utc=excluded.last_event_utc,
  last_departure_utc=excluded.last_departure_utc,
  last_arrival_utc=excluded.last_arrival_utc,
  last_engine_event_id=excluded.last_engine_event_id,
  updated_at=clock_timestamp()
 WHERE airlinerra_game.section9_aircraft_current_position_v1.airline_id=
  excluded.airline_id;
 GET DIAGNOSTICS change_count=ROW_COUNT;
 IF change_count<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_AIRCRAFT_POSITION_WRITE_CONFLICT';END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN p_phase='departed' THEN
    'operated_flight_departure_recorded' ELSE
    'operated_flight_arrival_recorded' END,
  'flightOccurrenceId',occurrence,'phase',p_phase,
  'aircraftInventoryId',s.aircraft_inventory_id,
  'locationStatus',resolution->>'newState',
  'lastVerifiedAirport',resolution->>'newAirport',
  'movementRecorded',true,'replayed',false,
  'bookingsCreated',false,'ledgerPosted',false,
  'flightActivated',false,'canActivateNormalFlight',false);
END $function$;
