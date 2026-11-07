-- Section 6: persistent weekly movement allocations by airport, stand type and direction.
-- A schedule draft can reserve slot capacity, but this NEVER activates a flight.
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN IF NOT EXISTS departure_stand_type text NOT NULL DEFAULT 'terminal'
 CHECK (departure_stand_type IN ('terminal','remote','cargo'));
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD COLUMN IF NOT EXISTS arrival_stand_type text NOT NULL DEFAULT 'terminal'
 CHECK (arrival_stand_type IN ('terminal','remote','cargo'));

CREATE TABLE IF NOT EXISTS airlinerra_game.section6_weekly_airport_slot_reservations_v1 (
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE CASCADE,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 stand_type text NOT NULL CHECK(stand_type IN ('terminal','remote','cargo')),
 direction text NOT NULL CHECK(direction IN ('arrival','departure')),
 weekday smallint NOT NULL CHECK(weekday BETWEEN 0 AND 6),
 minute_of_day smallint NOT NULL CHECK(minute_of_day BETWEEN 0 AND 1430 AND minute_of_day%10=0),
 reserved_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(schedule_id,airport_key,stand_type,direction,weekday,minute_of_day),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key)
);
CREATE INDEX IF NOT EXISTS section6_weekly_slot_usage_v1_idx
 ON airlinerra_game.section6_weekly_airport_slot_reservations_v1
 (world_id,airport_key,stand_type,direction,weekday,minute_of_day);
ALTER TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section6_weekly_airport_slot_reservations_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section6_weekly_airport_slot_reservations_v1 IS
 'Recurring weekly game slot reservations, without per-ten-minute background polling. Each protected schedule draft holds slots until changed or deleted. Arrival local-time variations over 54 weeks are reserved conservatively; operational flight activation remains blocked.';

CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_proposals_v1(
 p_world_id smallint,p_origin_key text,p_destination_key text,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_departure_stand text,p_arrival_stand text
) RETURNS TABLE(airport_key text,stand_type text,direction text,weekday smallint,minute_of_day smallint)
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE origin_tz text; destination_tz text; monday date; flight_duration interval;
BEGIN
 IF p_origin_key=p_destination_key OR
    p_departure_stand NOT IN ('terminal','remote','cargo') OR
    p_arrival_stand NOT IN ('terminal','remote','cargo') OR
    p_reference_arrival_utc<=p_reference_departure_utc OR
    p_reference_arrival_utc-p_reference_departure_utc>interval '72 hours' OR
    p_weekly_schedule IS NULL OR jsonb_typeof(p_weekly_schedule)<>'array'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION6_INVALID_SLOT_TIMETABLE'; END IF;
 SELECT p.timezone_iana INTO origin_tz FROM airlinerra_game.airport_reference_profiles p
 WHERE p.world_id=p_world_id AND p.airport_key=p_origin_key;
 SELECT p.timezone_iana INTO destination_tz FROM airlinerra_game.airport_reference_profiles p
 WHERE p.world_id=p_world_id AND p.airport_key=p_destination_key;
 IF origin_tz IS NULL OR destination_tz IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION6_AIRPORT_TIMEZONE_MISSING'; END IF;
 monday:=(p_reference_departure_utc AT TIME ZONE origin_tz)::date -
  (EXTRACT(ISODOW FROM p_reference_departure_utc AT TIME ZONE origin_tz)::int-1);
 flight_duration:=p_reference_arrival_utc-p_reference_departure_utc;
 RETURN QUERY
 WITH selected AS (
   SELECT ((monday + (w.n*7) + (j.day)::int)::timestamp + (j.departure)::time) AS local_origin
   FROM jsonb_to_recordset(p_weekly_schedule) AS j(day integer,departure text)
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
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section6_weekly_slot_proposals_v1(
 smallint,text,text,timestamptz,timestamptz,jsonb,text,text) FROM PUBLIC,anon,authenticated;

-- Compare BOTH 10-minute and hourly usage per airport, stand type and direction.
-- All proposed recurring buckets are included in the same capacity decision.
CREATE OR REPLACE FUNCTION airlinerra_game.section6_weekly_slot_preflight_v1(
 p_world_id smallint,p_origin_key text,p_destination_key text,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_departure_stand text,p_arrival_stand text,
 p_exclude_schedule_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE departure_ok boolean; arrival_ok boolean; requested_count integer;
BEGIN
 WITH proposal AS (
  SELECT DISTINCT * FROM airlinerra_game.section6_weekly_slot_proposals_v1(
   p_world_id,p_origin_key,p_destination_key,p_reference_departure_utc,
   p_reference_arrival_utc,p_weekly_schedule,p_departure_stand,p_arrival_stand)
 ), counted AS (
  SELECT r.*,
    count(*) OVER(PARTITION BY r.airport_key,r.stand_type,r.direction,r.weekday,
      (r.minute_of_day/60)) AS requested_hour,
    count(*) OVER(PARTITION BY r.airport_key,r.stand_type,r.direction,r.weekday,
      r.minute_of_day) AS requested_window
  FROM proposal r
 ), screened AS (
  SELECT c.direction,
   (CASE c.stand_type
      WHEN 'terminal' THEN a.terminal_stands
      WHEN 'remote' THEN a.remote_stands
      ELSE a.cargo_stands END) AS hour_limit,
   (CASE c.stand_type
      WHEN 'terminal' THEN a.terminal_per_direction_10m
      WHEN 'remote' THEN a.remote_per_direction_10m
      ELSE a.cargo_per_direction_10m END) AS window_limit,
    c.requested_hour,c.requested_window,
   (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 u
    WHERE u.world_id=p_world_id AND u.airport_key=c.airport_key
     AND u.stand_type=c.stand_type AND u.direction=c.direction
     AND u.weekday=c.weekday AND u.minute_of_day BETWEEN
       (c.minute_of_day/60)*60 AND (c.minute_of_day/60)*60+59
     AND (p_exclude_schedule_id IS NULL OR u.schedule_id<>p_exclude_schedule_id)
   ) AS used_hour,
   (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 u
    WHERE u.world_id=p_world_id AND u.airport_key=c.airport_key
     AND u.stand_type=c.stand_type AND u.direction=c.direction
     AND u.weekday=c.weekday AND u.minute_of_day=c.minute_of_day
     AND (p_exclude_schedule_id IS NULL OR u.schedule_id<>p_exclude_schedule_id)
   ) AS used_window
  FROM counted c LEFT JOIN airlinerra_game.section6_airport_slot_capacity_v1 a
  ON a.world_id=p_world_id AND a.airport_key=c.airport_key
 ), verdict AS (
  SELECT direction,coalesce(hour_limit,0)>0 AND coalesce(window_limit,0)>0
    AND used_hour+requested_hour<=coalesce(hour_limit,0)
    AND used_window+requested_window<=coalesce(window_limit,0) AS available
  FROM screened
 )
 SELECT coalesce(bool_and(available) FILTER(WHERE direction='departure'),false),
  coalesce(bool_and(available) FILTER(WHERE direction='arrival'),false),
  count(*)
 INTO departure_ok,arrival_ok,requested_count FROM verdict;
 RETURN jsonb_build_object('available',departure_ok AND arrival_ok,
  'departureAvailable',departure_ok,'arrivalAvailable',arrival_ok,
  'windowsChecked',requested_count,'slotModel','weekly_stand_capacity_v1');
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section6_weekly_slot_preflight_v1(
 smallint,text,text,timestamptz,timestamptz,jsonb,text,text,uuid) FROM PUBLIC,anon,authenticated;

-- Secure server-only save wraps the existing Section 5 mandatory gate.
-- The capacity row lock serializes all competing reservations at each airport.
-- Rejected bookings roll back the draft change and all reservations together.
CREATE OR REPLACE FUNCTION airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
 p_player_id uuid,p_airline_id uuid,p_aircraft_inventory_id uuid,
 p_flight_number text,p_origin_key text,p_destination_key text,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_existing_draft_id uuid DEFAULT NULL,
 p_departure_stand text DEFAULT 'terminal',p_arrival_stand text DEFAULT 'terminal'
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE previous_origin text; previous_destination text; model_use_type text;
 existing_count integer; result jsonb; slot_preview jsonb; saved_schedule_id uuid;
BEGIN
 IF p_departure_stand IS NULL OR p_arrival_stand IS NULL OR
  p_departure_stand NOT IN ('terminal','remote','cargo') OR
  p_arrival_stand NOT IN ('terminal','remote','cargo')
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION6_INVALID_STAND_CHOICE'; END IF;
 SELECT c.use_type INTO model_use_type FROM airlinerra_game.airline_aircraft_inventory i
 JOIN airlinerra.aircraft_configurations c ON c.id=i.configuration_id
 WHERE i.id=p_aircraft_inventory_id AND i.airline_id=p_airline_id;
 IF model_use_type='cargo' AND (p_departure_stand<>'cargo' OR p_arrival_stand<>'cargo') OR
    model_use_type='passenger' AND (p_departure_stand='cargo' OR p_arrival_stand='cargo')
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION6_INCOMPATIBLE_AIRCRAFT_STAND'; END IF;
 IF p_existing_draft_id IS NOT NULL THEN
  SELECT origin_airport_key,destination_airport_key INTO previous_origin,previous_destination
  FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE id=p_existing_draft_id AND airline_id=p_airline_id;
 END IF;
 -- Lock ALL old and new airports in deterministic order before any slot mutation.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN
  (p_origin_key,p_destination_key,previous_origin,previous_destination)
 ORDER BY c.airport_key FOR UPDATE;
 SELECT count(*) INTO existing_count FROM airlinerra_game.section6_airport_slot_capacity_v1
 WHERE world_id=1 AND airport_key IN (p_origin_key,p_destination_key);
 IF existing_count<>2 THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION6_AIRPORT_CAPACITY_NOT_CONFIGURED'; END IF;
 result:=airlinerra_game.section5_save_owned_aircraft_schedule_draft_v1(
  p_player_id,p_airline_id,p_aircraft_inventory_id,p_flight_number,
  p_origin_key,p_destination_key,p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_existing_draft_id);
 saved_schedule_id:=(result->>'scheduleId')::uuid;
 -- Replacing the old reservation and the new one is atomic.
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=saved_schedule_id;
 slot_preview:=airlinerra_game.section6_weekly_slot_preflight_v1(
  1,p_origin_key,p_destination_key,p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_departure_stand,p_arrival_stand,NULL);
 IF (slot_preview->>'available')::boolean IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION6_SLOT_UNAVAILABLE'; END IF;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1(
  schedule_id,world_id,airport_key,stand_type,direction,weekday,minute_of_day)
 SELECT saved_schedule_id,1,p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
 FROM airlinerra_game.section6_weekly_slot_proposals_v1(
  1,p_origin_key,p_destination_key,p_reference_departure_utc,p_reference_arrival_utc,
  p_weekly_schedule,p_departure_stand,p_arrival_stand) p;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1 SET
  departure_stand_type=p_departure_stand,arrival_stand_type=p_arrival_stand
 WHERE id=saved_schedule_id;
 RETURN result||jsonb_build_object('slotsReserved',true,'slotModel','weekly_stand_capacity_v1',
  'message','Weekly airport slots reserved for this draft; operational flight activation remains blocked.');
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
 uuid,uuid,uuid,text,text,text,timestamptz,timestamptz,jsonb,uuid,text,text)
 FROM PUBLIC,anon,authenticated;
