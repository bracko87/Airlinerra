-- Section 9 / commercial flight readiness: read-only aircraft rotation audit.
-- One aircraft cannot operate overlapping departures or teleport between
-- airports. This does not assume a valid initial aircraft position, crew,
-- minimum aircraft turnaround, traffic rights or released operations.
-- A 28-day preview is NOT a yearly/production activation certificate.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
 p_player_id uuid,p_airline_id uuid,p_schedule_id uuid,
 p_start_date date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE target record; report jsonb; n integer;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL OR p_schedule_id IS NULL
 OR p_start_date IS NULL
 OR p_start_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ROTATION_PREVIEW_REQUEST';END IF;

 SELECT s.id,s.airline_id,s.aircraft_inventory_id,
  s.flight_number,s.world_id,s.version,s.configuration_id,
  i.fleet_status,i.configuration_id AS fleet_configuration,
  a.owner_player_id
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
 JOIN airlinerra_game.airline_aircraft_inventory i
   ON i.id=s.aircraft_inventory_id AND i.airline_id=s.airline_id
 WHERE s.id=p_schedule_id AND s.airline_id=p_airline_id AND
   a.owner_player_id=p_player_id AND a.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ROTATION_SCHEDULE_NOT_OWNED'; END IF;

 SELECT count(*) INTO n FROM
 airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.world_id=1 AND s.airline_id=p_airline_id
 AND s.aircraft_inventory_id=target.aircraft_inventory_id;
 IF n>250 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_ROTATION_SCHEDULE_COUNT_REQUIRES_SHARDING'; END IF;

 WITH owned AS MATERIALIZED (
  SELECT s.id,s.airline_id,s.aircraft_inventory_id,s.flight_number,
   s.origin_airport_key,s.destination_airport_key,
   s.reference_departure_utc,s.reference_arrival_utc,s.weekly_schedule,
   tz.timezone_iana,
   tzcheck.name AS safe_timezone
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  LEFT JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=s.world_id AND tz.airport_key=s.origin_airport_key
  LEFT JOIN pg_catalog.pg_timezone_names tzcheck
   ON tzcheck.name=tz.timezone_iana
  WHERE s.world_id=1 AND s.airline_id=p_airline_id
   AND s.aircraft_inventory_id=target.aircraft_inventory_id
 ),
 items AS MATERIALIZED (
  SELECT o.*,
    w.ordinality::integer AS weekly_entry,
    w.item->>'day' AS weekday_text,w.item->>'time' AS time_text,
    coalesce(jsonb_typeof(w.item),'null')='object' AND
    coalesce(w.item->>'day','') ~ '^[0-6]$' AND
    coalesce(w.item->>'time','') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
      AS good_weekly_entry
  FROM owned o CROSS JOIN LATERAL
   jsonb_array_elements(o.weekly_schedule) WITH ORDINALITY w(item,ordinality)
 ),
 days AS MATERIALIZED (
  SELECT i.*,
   day_value::date AS flight_local_date,
   CASE WHEN i.good_weekly_entry THEN
     (day_value::date + (i.time_text)::time) END AS local_timestamp
  FROM items i
  CROSS JOIN LATERAL generate_series(
    (p_start_date-4)::timestamp,
    (p_start_date+p_days+2)::timestamp,
    interval '1 day'
  ) AS day_value
  WHERE i.good_weekly_entry AND i.safe_timezone IS NOT NULL
   AND (i.weekday_text)::integer=
     extract(isodow from day_value)::integer-1
 ),
 flights AS MATERIALIZED (
  SELECT d.*,
   (d.local_timestamp AT TIME ZONE d.safe_timezone) AS departure_utc,
   ((d.local_timestamp AT TIME ZONE d.safe_timezone)+
    (d.reference_arrival_utc-d.reference_departure_utc)) AS arrival_utc
  FROM days d
 ),
 flagged AS MATERIALIZED (
  SELECT f.*,
   CASE WHEN (f.departure_utc AT TIME ZONE f.safe_timezone)
        IS DISTINCT FROM f.local_timestamp
     THEN 'NONEXISTENT_LOCAL_DEPARTURE'
    WHEN ((f.departure_utc+interval '1 hour') AT TIME ZONE f.safe_timezone)
         =f.local_timestamp OR
         ((f.departure_utc-interval '1 hour') AT TIME ZONE f.safe_timezone)
         =f.local_timestamp
     THEN 'AMBIGUOUS_LOCAL_DEPARTURE'
    ELSE NULL END AS dst_problem
  FROM flights f
 ),
 ordered AS MATERIALIZED (
  SELECT f.*,
   lag(f.arrival_utc) OVER sequence AS prev_arrival_utc,
   lag(f.destination_airport_key) OVER sequence AS prev_destination,
   lag(f.flight_number) OVER sequence AS prev_flight_number,
   max(f.arrival_utc) OVER (ORDER BY f.departure_utc,f.id,f.weekly_entry
     ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
       AS max_previous_arrival
  FROM flagged f
  WINDOW sequence AS (ORDER BY f.departure_utc,f.id,f.weekly_entry)
 ),
 totals AS (
  SELECT
   count(*)::integer AS occurrence_count,
   count(*) FILTER (WHERE id=p_schedule_id)::integer AS target_count,
   count(*) FILTER (WHERE max_previous_arrival>departure_utc)::integer AS overlap_count,
   count(*) FILTER (WHERE prev_arrival_utc<=departure_utc
       AND prev_destination<>origin_airport_key)::integer AS wrong_airport_count,
   count(*) FILTER (WHERE dst_problem IS NOT NULL)::integer AS dst_count,
   min(extract(epoch from (departure_utc-prev_arrival_utc))/60)
      FILTER (WHERE prev_arrival_utc IS NOT NULL AND
       prev_arrival_utc<=departure_utc)::numeric AS minimum_ground_gap_minutes
  FROM ordered
 )
 SELECT jsonb_build_object(
  'status',CASE WHEN totals.overlap_count>0 OR
     totals.wrong_airport_count>0 OR totals.dst_count>0 OR
     (SELECT count(*) FROM items WHERE good_weekly_entry IS NOT TRUE)>0 OR
     (SELECT count(*) FROM owned WHERE safe_timezone IS NULL)>0 OR
     totals.target_count=0 OR target.fleet_status<>'in_service' OR
     target.fleet_configuration<>target.configuration_id
   THEN 'ROTATION_CONFLICT_OR_UNVERIFIED'
   ELSE 'ROTATION_PREVIEW_NO_CONFLICTS' END,
  'scheduleId',target.id,
  'aircraftInventoryId',target.aircraft_inventory_id,
  'fromDate',p_start_date,'previewDays',p_days,
  'aircraftSchedules',n,
  'flightOccurrences',totals.occurrence_count,
  'targetOccurrences',totals.target_count,
  'overlappingFlights',totals.overlap_count,
  'wrongAirportDepartures',totals.wrong_airport_count,
  'daylightSavingTimeIssues',totals.dst_count,
  'invalidWeeklyEntries',
    (SELECT count(*) FROM items WHERE good_weekly_entry IS NOT TRUE),
  'unknownOriginTimezones',
    (SELECT count(*) FROM owned WHERE safe_timezone IS NULL),
  'minimumObservedGroundMinutes',round(totals.minimum_ground_gap_minutes,1),
  'slotsRecorded',jsonb_build_object(
   'departure',EXISTS(SELECT 1 FROM
     airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
      WHERE r.schedule_id=p_schedule_id AND r.direction='departure'),
   'arrival',EXISTS(SELECT 1 FROM
     airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
      WHERE r.schedule_id=p_schedule_id AND r.direction='arrival')
  ),
  'sampleConflicts',(SELECT coalesce(jsonb_agg(jsonb_build_object(
    'flightNumber',c.flight_number,'origin',c.origin_airport_key,
    'destination',c.destination_airport_key,
    'localDeparture',c.local_timestamp,
    'previousFlightNumber',c.prev_flight_number,
    'previousDestination',c.prev_destination,
    'reason',CASE WHEN c.dst_problem IS NOT NULL THEN c.dst_problem
      WHEN c.max_previous_arrival>c.departure_utc THEN 'AIRCRAFT_OVERLAP'
      ELSE 'AIRCRAFT_AT_WRONG_AIRPORT' END
   ) ORDER BY c.departure_utc),'[]'::jsonb)
   FROM (SELECT * FROM ordered
     WHERE dst_problem IS NOT NULL OR
      max_previous_arrival>departure_utc OR
      (prev_arrival_utc<=departure_utc AND
       prev_destination<>origin_airport_key)
     ORDER BY departure_utc,id,weekly_entry LIMIT 12) c),
  'initialAircraftPositionVerified',false,
  'aircraftTurnaroundPolicyVerified',false,
  'crewAssignmentsVerified',false,
  'trafficRightsVerified',false,
  'operationalFlightActivationReleased',false,
  'canActivateNormalFlight',false,
  'readOnly',true
 ) INTO report FROM totals;
 RETURN report;
END $function$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_owned_aircraft_rotation_preview_v1(uuid,uuid,uuid,date,integer)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION
 airlinerra_game.section9_owned_aircraft_rotation_preview_v1(uuid,uuid,uuid,date,integer)
 IS 'Read-only player-owned aircraft schedule continuity diagnostic. Cannot certify first aircraft position, crew, aircraft turnaround or commercial flight activation.';
