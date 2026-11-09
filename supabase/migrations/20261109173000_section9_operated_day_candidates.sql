-- Section 9 private scheduled-operation candidates, strictly read-only.
-- Candidates are NOT departures or arrivals. Only a separate trusted
-- operations engine may certify actual operation and sign movement events.
-- No activation constraints, airline money or locations are changed.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
 p_airline uuid,p_aircraft uuid,p_game_day date
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
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
 ) THEN
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
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(uuid,uuid,date)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION
 airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(uuid,uuid,date)
 IS 'Private read-only clock-gated candidates by physical aircraft. Events are not signed or operated until separately certified by trusted operations engine and then accepted by existing guarded movement ingest.';
