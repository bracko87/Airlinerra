-- Source-neutral slot proposal timezone lookup for all 4,259 airport policies.
CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_proposals_v1(p_world_id smallint, p_origin_key text, p_destination_key text, p_reference_departure_utc timestamp with time zone, p_reference_arrival_utc timestamp with time zone, p_weekly_schedule jsonb, p_departure_stand text, p_arrival_stand text)
 RETURNS TABLE(airport_key text, stand_type text, direction text, weekday smallint, minute_of_day smallint)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE origin_tz text; destination_tz text; monday date; flight_duration interval;
BEGIN
 IF p_origin_key=p_destination_key OR
    p_departure_stand NOT IN ('terminal','remote','cargo') OR
    p_arrival_stand NOT IN ('terminal','remote','cargo') OR
    p_reference_arrival_utc<=p_reference_departure_utc OR
    p_reference_arrival_utc-p_reference_departure_utc>interval '72 hours' OR
    p_weekly_schedule IS NULL OR jsonb_typeof(p_weekly_schedule)<>'array'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION6_INVALID_SLOT_TIMETABLE'; END IF;
 SELECT p.timezone_iana INTO origin_tz FROM airlinerra_game.section5_airport_operating_policy_v1 p
 WHERE p.world_id=p_world_id AND p.airport_key=p_origin_key;
 SELECT p.timezone_iana INTO destination_tz FROM airlinerra_game.section5_airport_operating_policy_v1 p
 WHERE p.world_id=p_world_id AND p.airport_key=p_destination_key;
 IF origin_tz IS NULL OR destination_tz IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION6_AIRPORT_TIMEZONE_MISSING'; END IF;
 monday:=(p_reference_departure_utc AT TIME ZONE origin_tz)::date -
  (EXTRACT(ISODOW FROM p_reference_departure_utc AT TIME ZONE origin_tz)::int-1);
 flight_duration:=p_reference_arrival_utc-p_reference_departure_utc;
 RETURN QUERY
 WITH selected AS (
   SELECT ((monday + (w.n*7) + (j.day)::int)::timestamp + (j."time")::time) AS local_origin
   FROM jsonb_to_recordset(p_weekly_schedule) AS j(day integer,"time" text)
   CROSS JOIN generate_series(0,53) AS w(n)
 ), local_times AS (
   SELECT s.local_origin,
     (((s.local_origin AT TIME ZONE origin_tz)+flight_duration) AT TIME ZONE destination_tz) AS local_destination
   FROM selected s
 ), proposed AS (
   SELECT p_origin_key AS airport_key,p_departure_stand AS stand_type,'departure'::text AS direction,
    (EXTRACT(ISODOW FROM l.local_origin)::int-1)::smallint AS weekday,
    ((EXTRACT(HOUR FROM l.local_origin)::int*60)+
      (EXTRACT(MINUTE FROM l.local_origin)::int/10)*10)::smallint AS minute_of_day
   FROM local_times l
   UNION ALL
   SELECT p_destination_key,p_arrival_stand,'arrival'::text,
    (EXTRACT(ISODOW FROM l.local_destination)::int-1)::smallint,
    ((EXTRACT(HOUR FROM l.local_destination)::int*60)+
      (EXTRACT(MINUTE FROM l.local_destination)::int/10)*10)::smallint
   FROM local_times l
 )
 SELECT DISTINCT r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day
 FROM proposed r;
END $function$
;
