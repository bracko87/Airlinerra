-- Owner-scoped read-only shared World 1 aircraft rotation source.
-- All schedules remain blocked until signed, independently verified release.
-- This produces no flight, slot, booking, movement or payment.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_candidate_rotation_preflight_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_origin text, p_destination text, p_reference_departure_utc timestamp with time zone, p_reference_arrival_utc timestamp with time zone, p_weekly jsonb, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 origin_tz text;
 start_day date;
 horizon_end date;
 duration interval;
 n integer;
 report jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
    OR p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
    OR p_days IS NULL OR p_days NOT BETWEEN 7 AND 42
    OR p_reference_departure_utc IS NULL OR p_reference_arrival_utc IS NULL
    OR p_reference_arrival_utc<=p_reference_departure_utc
    OR p_reference_arrival_utc>p_reference_departure_utc+interval '72 hours'
    OR p_weekly IS NULL OR jsonb_typeof(p_weekly)<>'array'
    OR jsonb_array_length(p_weekly) NOT BETWEEN 1 AND 7
 THEN RETURN jsonb_build_object('status','INVALID_ROTATION_CANDIDATE',
  'readOnly',true,'gameRotationCompatible',false,
  'flightActivated',false,'airportSlotsReserved',false,'ledgerPosted',false);
 END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_weekly) AS j(value)
   WHERE jsonb_typeof(j.value)<>'object'
      OR coalesce(j.value->>'day','') !~ '^[0-6]$'
      OR coalesce(j.value->>'time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$')
 OR (SELECT count(DISTINCT j.value->>'day') FROM jsonb_array_elements(p_weekly) AS j(value))
   <>jsonb_array_length(p_weekly)
 THEN RETURN jsonb_build_object('status','INVALID_ROTATION_WEEKLY_SCHEDULE',
  'readOnly',true,'gameRotationCompatible',false,
  'flightActivated',false,'airportSlotsReserved',false,'ledgerPosted',false);
 END IF;
 PERFORM 1
 FROM airlinerra_game.airline_aircraft_inventory fleet
 JOIN airlinerra_game.airlines a ON a.id=fleet.airline_id
 JOIN airlinerra_game.world_memberships w
   ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active'
 WHERE fleet.id=p_aircraft AND fleet.airline_id=p_airline
   AND a.owner_player_id=p_player AND a.world_id=1
   AND fleet.fleet_status='in_service';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ROTATION_CANDIDATE_NOT_OWNED_OR_IN_SERVICE';END IF;
 SELECT ar.timezone_iana INTO origin_tz
 FROM airlinerra_game.airport_reference_profiles ar
 JOIN pg_catalog.pg_timezone_names tz ON tz.name=ar.timezone_iana
 WHERE ar.world_id=1 AND ar.airport_key=p_origin;
 IF origin_tz IS NULL OR NOT EXISTS (
  SELECT 1 FROM airlinerra_game.airport_reference_profiles ar
  WHERE ar.world_id=1 AND ar.airport_key=p_destination AND ar.timezone_iana IS NOT NULL)
 THEN RETURN jsonb_build_object('status','ROTATION_AIRPORT_TIMEZONE_UNVERIFIED',
  'readOnly',true,'gameRotationCompatible',false,
  'flightActivated',false,'airportSlotsReserved',false,'ledgerPosted',false);
 END IF;
 start_day:=(p_reference_departure_utc AT TIME ZONE origin_tz)::date;
 horizon_end:=start_day+p_days-1;
 duration:=p_reference_arrival_utc-p_reference_departure_utc;
 SELECT count(*) INTO n
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=p_aircraft
   AND s.status='active' AND s.operationally_verified=true;
 IF n>250 THEN RETURN jsonb_build_object('status','ROTATION_SCHEDULE_LIMIT',
  'readOnly',true,'gameRotationCompatible',false,
  'flightActivated',false,'airportSlotsReserved',false,'ledgerPosted',false);END IF;

 WITH sources AS MATERIALIZED (
  SELECT 'candidate'::text source_kind,'NEW ROUTE'::text flight_number,
   p_origin AS origin_key,p_destination AS destination_key,
   origin_tz AS timezone_iana,duration AS flight_duration,p_weekly AS weekdays
  UNION ALL
  SELECT 'existing_active',s.flight_number,s.origin_airport_key,s.destination_airport_key,
   ap.timezone_iana,s.reference_arrival_utc-s.reference_departure_utc,s.weekly_schedule
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  JOIN airlinerra_game.airport_reference_profiles ap
    ON ap.world_id=s.world_id AND ap.airport_key=s.origin_airport_key
  JOIN pg_catalog.pg_timezone_names tz ON tz.name=ap.timezone_iana
  WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=p_aircraft
   AND s.status='active' AND s.operationally_verified=true
 ), days AS (
  SELECT start_day-7+g.i AS local_date
  FROM generate_series(0,p_days+6) AS g(i)
 ), occurrences AS MATERIALIZED (
  SELECT src.source_kind,src.flight_number,src.origin_key,src.destination_key,
   src.timezone_iana,
   (d.local_date::timestamp+(j.value->>'time')::time) AS local_departure,
   ((d.local_date::timestamp+(j.value->>'time')::time)
     AT TIME ZONE src.timezone_iana) AS departure_utc,
   (((d.local_date::timestamp+(j.value->>'time')::time)
     AT TIME ZONE src.timezone_iana)+src.flight_duration) AS arrival_utc
  FROM sources src CROSS JOIN days d
  CROSS JOIN LATERAL jsonb_array_elements(src.weekdays) AS j(value)
  WHERE src.flight_duration>interval '0 seconds'
   AND src.flight_duration<=interval '72 hours'
   AND coalesce(j.value->>'day','') ~ '^[0-6]$'
   AND coalesce(j.value->>'time','') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
   AND (j.value->>'day')::integer=EXTRACT(ISODOW FROM d.local_date)::integer-1
   AND (src.source_kind='existing_active' OR d.local_date>=start_day)
 ), ordered AS MATERIALIZED (
 SELECT o.*,
  lag(o.destination_key) OVER seq AS previous_destination,
  lag(o.flight_number) OVER seq AS previous_flight,
  lag(o.arrival_utc) OVER seq AS previous_arrival,
  max(o.arrival_utc) OVER
   (ORDER BY o.departure_utc,o.source_kind,o.flight_number
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS latest_previous_arrival,
  ((o.departure_utc AT TIME ZONE o.timezone_iana)<>o.local_departure
    OR (o.departure_utc+interval '1 hour') AT TIME ZONE o.timezone_iana=o.local_departure
    OR (o.departure_utc-interval '1 hour') AT TIME ZONE o.timezone_iana=o.local_departure)
      AS dst_ambiguous
 FROM occurrences o
 WINDOW seq AS (ORDER BY o.departure_utc,o.source_kind,o.flight_number)
 ), measured AS (
  SELECT count(*) FILTER(WHERE source_kind='candidate')::integer AS candidate_count,
   count(*) FILTER (WHERE latest_previous_arrival>departure_utc
     AND departure_utc::date BETWEEN start_day-1 AND horizon_end+1)::integer AS overlaps,
   count(*) FILTER (WHERE previous_arrival<=departure_utc
     AND previous_destination<>origin_key
     AND departure_utc::date BETWEEN start_day-1 AND horizon_end+1)::integer AS wrong_airport,
   count(*) FILTER (WHERE dst_ambiguous AND source_kind='candidate')::integer AS dst_errors
  FROM ordered
 )
 SELECT jsonb_build_object(
   'status',CASE WHEN m.candidate_count=0 THEN 'ROTATION_CANDIDATE_HAS_NO_OCCURRENCES'
     WHEN m.overlaps>0 OR m.wrong_airport>0 OR m.dst_errors>0
     THEN 'ROTATION_NEEDS_RETURN_OR_REPOSITION'
     ELSE 'ROTATION_PREVIEW_NO_SEQUENCE_CONFLICT' END,
   'worldId',1,'readOnly',true,'startDate',start_day,'previewDays',p_days,
   'candidateOccurrences',m.candidate_count,
   'existingActiveSchedules',n,
   'overlappingFlights',m.overlaps,
   'wrongAirportDepartures',m.wrong_airport,
   'invalidLocalDepartureTimes',m.dst_errors,
   'returnOrRepositionRequired',m.wrong_airport>0,
   'gameRotationCompatible',m.candidate_count>0 AND m.overlaps=0
    AND m.wrong_airport=0 AND m.dst_errors=0,
   'sampleConflicts',(SELECT coalesce(jsonb_agg(jsonb_build_object(
    'flightNumber',c.flight_number,'source',c.source_kind,
    'origin',c.origin_key,'previousDestination',c.previous_destination,
    'previousFlight',c.previous_flight,'departureUtc',c.departure_utc,
    'reason',CASE WHEN c.latest_previous_arrival>c.departure_utc THEN 'OVERLAPPING_FLIGHTS'
       WHEN c.dst_ambiguous THEN 'AMBIGUOUS_OR_NONEXISTENT_LOCAL_TIME'
       ELSE 'AIRCRAFT_AT_WRONG_AIRPORT' END)
    ORDER BY c.departure_utc),'[]'::jsonb)
    FROM (SELECT * FROM ordered WHERE
      latest_previous_arrival>departure_utc
      OR (previous_arrival<=departure_utc AND previous_destination<>origin_key)
      OR (dst_ambiguous AND source_kind='candidate')
     ORDER BY departure_utc LIMIT 5) c),
   'flightActivated',false,'airportSlotsReserved',false,'bookingEnabled',false,
   'ledgerPosted',false,'operationallyApproved',false
 ) INTO report FROM measured m;
 RETURN report;
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_candidate_rotation_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION airlinerra_game.section9_owned_candidate_rotation_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,integer) TO service_role;
