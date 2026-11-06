CREATE OR REPLACE FUNCTION airlinerra_game.section5_weekly_route_restriction_gate_v1(
 p_world_id smallint,p_origin_airport_key text,p_destination_airport_key text,
 p_configuration_id bigint,p_reference_departure_utc timestamptz,
 p_reference_arrival_utc timestamptz,p_weekly_departures jsonb
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE
 tz text; monday date; duration interval;
 occurrences jsonb; bad_local_time boolean;
 n integer; gate jsonb;
BEGIN
 IF p_reference_departure_utc IS NULL OR p_reference_arrival_utc IS NULL
  OR p_reference_arrival_utc<=p_reference_departure_utc
  OR p_reference_arrival_utc-p_reference_departure_utc>interval '72 hours'
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_REFERENCE_FLIGHT_TIMES',
  'gameHardBlocked',true,'canActivateNormalFlight',false); END IF;
 IF p_weekly_departures IS NULL OR jsonb_typeof(p_weekly_departures)<>'array'
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_WEEKLY_SCHEDULE',
  'gameHardBlocked',true,'canActivateNormalFlight',false); END IF;
 n:=jsonb_array_length(p_weekly_departures);
 IF n<1 OR n>7
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_WEEKLY_DAY_COUNT',
  'gameHardBlocked',true,'canActivateNormalFlight',false); END IF;
 IF EXISTS (
  SELECT 1 FROM jsonb_array_elements(p_weekly_departures) AS j
  WHERE jsonb_typeof(j)<>'object'
     OR jsonb_typeof(j->'day')<>'number'
     OR coalesce(j->>'day','') !~ '^[0-6]$'
     OR jsonb_typeof(j->'time')<>'string'
     OR coalesce(j->>'time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 )
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_WEEKLY_DAY_OR_TIME',
  'gameHardBlocked',true,'canActivateNormalFlight',false); END IF;
 IF (SELECT count(DISTINCT j->>'day') FROM jsonb_array_elements(p_weekly_departures) AS j)<>n
 THEN RETURN jsonb_build_object('decision','BLOCKED_DUPLICATE_WEEKDAY',
  'gameHardBlocked',true,'canActivateNormalFlight',false); END IF;
 SELECT timezone_iana INTO tz
 FROM airlinerra_game.section5_airport_operating_policy_v1
 WHERE world_id=p_world_id AND airport_key=p_origin_airport_key;
 IF tz IS NULL
 THEN RETURN jsonb_build_object('decision','REVIEW_AIRPORT_TIMEZONE_UNAVAILABLE',
  'gameHardBlocked',false,'needsReview',true,'canActivateNormalFlight',false); END IF;
 monday:=(p_reference_departure_utc AT TIME ZONE tz)::date-
  (EXTRACT(ISODOW FROM (p_reference_departure_utc AT TIME ZONE tz))::integer-1);
 duration:=p_reference_arrival_utc-p_reference_departure_utc;
 WITH proposed AS (
  SELECT j->>'day' AS day_text,(j->>'time')::time AS local_departure_time,
    (monday+(w.week_index*7)+(j->>'day')::integer) AS local_day
  FROM generate_series(0,3) AS w(week_index)
  CROSS JOIN jsonb_array_elements(p_weekly_departures) AS j
 ), resolved AS (
  SELECT local_departure_time,
    ((local_day::timestamp+local_departure_time::interval) AT TIME ZONE tz) AS departure_utc
  FROM proposed
 )
 SELECT bool_or((departure_utc AT TIME ZONE tz)::time<>local_departure_time),
  jsonb_agg(jsonb_build_object(
   'departureUtc',to_char(departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   'arrivalUtc',to_char((departure_utc+duration) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'))
   ORDER BY departure_utc)
 INTO bad_local_time,occurrences FROM resolved;
 IF bad_local_time
 THEN RETURN jsonb_build_object('decision','BLOCKED_NONEXISTENT_LOCAL_TIME_DST_TRANSITION',
  'gameHardBlocked',true,'needsReview',true,'canActivateNormalFlight',false); END IF;
 gate:=airlinerra_game.section5_batch_route_restriction_screen_v1(
  p_world_id,p_origin_airport_key,p_destination_airport_key,
  p_configuration_id,occurrences);
 RETURN gate||jsonb_build_object(
  'weeklyTimetableChecked',true,'weeklyDepartureCount',n,'weeksChecked',4,
  'originTimezone',tz,'referenceDurationSeconds',EXTRACT(EPOCH FROM duration)::integer,
  'warning','Arrival times are based on the entered example flight duration. A real flight scheduler must recompute every occurrence before activation.',
  'canActivateNormalFlight',false);
END;
$function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_weekly_route_restriction_gate_v1(
smallint,text,text,bigint,timestamptz,timestamptz,jsonb) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_weekly_route_restriction_gate_v1(smallint,text,text,bigint,timestamptz,timestamptz,jsonb)
IS 'Screens four weeks of locally scheduled weekday departures (max 28) for known game airport/aircraft bans, preserving origin timezone and DST. Reference flight duration remains a planning estimate. No activation.';
