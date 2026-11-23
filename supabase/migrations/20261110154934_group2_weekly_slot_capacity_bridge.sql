-- Section 6 Group 2 capacity in the same shape as the Group 1 stand-capacity engine.
-- This is a read-only planning bridge, NOT permission to reserve a slot.
CREATE VIEW airlinerra_game.section6_group2_slot_capacity_bridge_v1
WITH (security_invoker=true) AS
SELECT c.world_id,c.airport_key,
 c.game_terminal_stands AS terminal_stands,
 c.game_remote_stands AS remote_stands,
 c.game_cargo_stands AS cargo_stands,
 c.game_terminal_slot_per_10m AS terminal_per_direction_10m,
 c.game_remote_slot_per_10m AS remote_per_direction_10m,
 c.game_cargo_slot_per_10m AS cargo_per_direction_10m,
 'group2_prepared_stand_game_v1'::text AS model_version,
 c.timezone_iana,
 false AS admitted_for_bookings,
 false AS capacity_reservation_activated
FROM airlinerra_game.airport_group2_engine_input_preview_v1 c
WHERE c.world_id=1;
REVOKE ALL ON airlinerra_game.section6_group2_slot_capacity_bridge_v1
 FROM PUBLIC,anon,authenticated;

-- A proposed weekly route can be modelled against existing reservations for
-- each end.  No writes, no issuance of slot tokens, no flight activation.
CREATE OR REPLACE FUNCTION airlinerra_game.group2_weekly_slot_route_preview_v1(
 p_origin_key text,p_destination_key text,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_departure_stand text,p_arrival_stand text
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $$
DECLARE ori record; dest record; flight_duration interval; monday date;
 selected_count integer; check_count integer; eligible boolean;
 depart_ok boolean; arrive_ok boolean; largest_used integer;
BEGIN
 IF p_origin_key IS NULL OR p_destination_key IS NULL OR
  p_origin_key=p_destination_key OR
  p_reference_departure_utc IS NULL OR p_reference_arrival_utc IS NULL OR
  p_reference_arrival_utc<=p_reference_departure_utc OR
  p_reference_arrival_utc-p_reference_departure_utc>interval '72 hours' OR
  p_departure_stand NOT IN('terminal','remote','cargo') OR
  p_arrival_stand NOT IN('terminal','remote','cargo') OR
  p_weekly_schedule IS NULL OR jsonb_typeof(p_weekly_schedule)<>'array'
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_REQUEST',
  'canReserve',false,'canActivateFlights',false,'previewOnly',true);END IF;
 selected_count:=jsonb_array_length(p_weekly_schedule);
 IF selected_count<1 OR selected_count>7 OR EXISTS(
  SELECT 1 FROM jsonb_array_elements(p_weekly_schedule) AS elem
  WHERE jsonb_typeof(elem)<>'object' OR
   (SELECT count(*) FROM jsonb_object_keys(elem))<>2 OR
   NOT(elem ? 'day' AND elem ? 'time') OR
   (elem->>'day') !~ '^[0-6]$' OR
   (elem->>'time') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 ) THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_WEEKLY_TIMETABLE',
  'canReserve',false,'canActivateFlights',false,'previewOnly',true);END IF;
 SELECT * INTO ori FROM airlinerra_game.section6_group2_slot_capacity_bridge_v1
 WHERE world_id=1 AND airport_key=p_origin_key;
 SELECT * INTO dest FROM airlinerra_game.section6_group2_slot_capacity_bridge_v1
 WHERE world_id=1 AND airport_key=p_destination_key;
 IF ori.airport_key IS NULL OR dest.airport_key IS NULL OR
    ori.timezone_iana IS NULL OR dest.timezone_iana IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_NOT_TWO_GROUP2_PREPARED_AIRPORTS',
  'canReserve',false,'canActivateFlights',false,'previewOnly',true);END IF;
 monday:=(p_reference_departure_utc AT TIME ZONE ori.timezone_iana)::date -
   (extract(isodow FROM (p_reference_departure_utc AT TIME ZONE ori.timezone_iana))::int-1);
 flight_duration:=p_reference_arrival_utc-p_reference_departure_utc;

 -- Same 54-week, two-direction weekly reservation buckets as Section 6
 -- existing preflight.  The staging capacity is separate from active capacity.
 WITH slots AS (
  SELECT ((monday + (j.day::int + week_index.n*7))::timestamp+
     j."time"::time) AS origin_local
  FROM jsonb_to_recordset(p_weekly_schedule) AS j(day integer,"time" text)
  CROSS JOIN generate_series(0,53) week_index(n)
 ), times AS(
  SELECT origin_local,
    (((origin_local AT TIME ZONE ori.timezone_iana)+flight_duration)
    AT TIME ZONE dest.timezone_iana) AS destination_local
  FROM slots
 ), proposal AS (
  SELECT p_origin_key airport_key,p_departure_stand stand_type,
   'departure'::text direction,
   (extract(isodow FROM origin_local)::int-1)::smallint weekday,
   ((extract(hour FROM origin_local)::int*60)+
    (extract(minute FROM origin_local)::int/10)*10)::smallint minute_of_day
  FROM times
  UNION ALL
  SELECT p_destination_key,p_arrival_stand,'arrival'::text,
   (extract(isodow FROM destination_local)::int-1)::smallint,
   ((extract(hour FROM destination_local)::int*60)+
    (extract(minute FROM destination_local)::int/10)*10)::smallint
  FROM times
 ), unique_proposals AS(
  SELECT DISTINCT * FROM proposal
 ), counted AS (
  SELECT r.*,
   count(*) OVER(PARTITION BY r.airport_key,r.stand_type,r.direction,
   r.weekday,(r.minute_of_day/60))::int AS requested_hour,
   count(*) OVER(PARTITION BY r.airport_key,r.stand_type,r.direction,
   r.weekday,r.minute_of_day)::int AS requested_window
  FROM unique_proposals r
 ), capacity_check AS(
  SELECT c.*,
   CASE c.stand_type WHEN 'terminal' THEN a.terminal_stands
    WHEN 'remote' THEN a.remote_stands ELSE a.cargo_stands END AS hour_limit,
   CASE c.stand_type WHEN 'terminal' THEN a.terminal_per_direction_10m
    WHEN 'remote' THEN a.remote_per_direction_10m
    ELSE a.cargo_per_direction_10m END AS window_limit,
   (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
    WHERE r.world_id=1 AND r.airport_key=c.airport_key
      AND r.stand_type=c.stand_type AND r.direction=c.direction
      AND r.weekday=c.weekday
      AND r.minute_of_day BETWEEN ((c.minute_of_day/60)*60)
        AND ((c.minute_of_day/60)*60)+59) AS hour_used,
   (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
    WHERE r.world_id=1 AND r.airport_key=c.airport_key
      AND r.stand_type=c.stand_type AND r.direction=c.direction
      AND r.weekday=c.weekday AND r.minute_of_day=c.minute_of_day) AS window_used
  FROM counted c LEFT JOIN airlinerra_game.section6_group2_slot_capacity_bridge_v1 a
   ON a.world_id=1 AND a.airport_key=c.airport_key
 ), final AS (
  SELECT direction,coalesce(hour_limit,0)>0 AND coalesce(window_limit,0)>0
   AND hour_used+requested_hour<=coalesce(hour_limit,0)
   AND window_used+requested_window<=coalesce(window_limit,0) okay,
   greatest(hour_used,window_used)::int used
  FROM capacity_check
 )
 SELECT count(*)::int,
  coalesce(bool_and(okay) FILTER(WHERE direction='departure'),false),
  coalesce(bool_and(okay) FILTER(WHERE direction='arrival'),false),
  coalesce(max(used),0)::int
 INTO check_count,depart_ok,arrive_ok,largest_used FROM final;
 eligible:=depart_ok AND arrive_ok AND check_count>0;
 RETURN jsonb_build_object(
  'modelVersion','GROUP2_WEEKLY_SLOT_ROUTE_PREVIEW_V1',
  'originAirportKey',p_origin_key,'destinationAirportKey',p_destination_key,
  'weeklyTimetableCount',selected_count,'weeklyDistinctBucketsChecked',check_count,
  'originTimezone',ori.timezone_iana,'destinationTimezone',dest.timezone_iana,
  'originStand',p_departure_stand,'destinationStand',p_arrival_stand,
  'originSlotModelCapacitySufficient',depart_ok,
  'destinationSlotModelCapacitySufficient',arrive_ok,
  'existingReservationMaxInBucket',largest_used,
  'hypotheticalSlotCapacityCompatible',eligible,
  'decision',CASE WHEN eligible THEN 'PRELIMINARY_WEEKLY_GAME_CAPACITY_PASS_NOT_ADMITTED'
   ELSE 'BLOCKED_WEEKLY_GAME_SLOT_CAPACITY' END,
  'actualSlotsReserved',false,'fullWeightRouteChecked',false,
  'timeRestrictionsAndNoiseChecked',false,'commercialAdmission',false,
  'canReserve',false,'canActivateFlights',false,'canDispatch',false,'previewOnly',true
 );
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.group2_weekly_slot_route_preview_v1(
 text,text,timestamptz,timestamptz,jsonb,text,text) FROM PUBLIC,anon,authenticated;

DO $$
DECLARE s jsonb; b jsonb; i jsonb;
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.section6_group2_slot_capacity_bridge_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.section6_group2_slot_capacity_bridge_v1
  WHERE admitted_for_bookings OR capacity_reservation_activated)<>0
 THEN RAISE EXCEPTION 'GROUP2_SLOT_BRIDGE_COVERAGE_FAILED';END IF;
 s:=airlinerra_game.group2_weekly_slot_route_preview_v1(
  'OURAIRPORTS:20581','OURAIRPORTS:46583',
  '2026-11-10T14:00:00Z','2026-11-10T19:00:00Z',
  '[{"day":1,"time":"06:00"}]'::jsonb,'terminal','terminal');
 b:=airlinerra_game.group2_weekly_slot_route_preview_v1(
  'OURAIRPORTS:4183','OURAIRPORTS:46583',
  '2026-11-10T14:00:00Z','2026-11-10T19:00:00Z',
  '[{"day":1,"time":"06:00"}]'::jsonb,'terminal','terminal');
 i:=airlinerra_game.group2_weekly_slot_route_preview_v1(
  'OURAIRPORTS:20581','OURAIRPORTS:46583',
  '2026-11-10T14:00:00Z','2026-11-10T19:00:00Z',
  '[{"day":7,"time":"06:00"}]'::jsonb,'terminal','terminal');
 IF s->>'decision'<>'PRELIMINARY_WEEKLY_GAME_CAPACITY_PASS_NOT_ADMITTED'
 OR s->>'canReserve'<>'false'
 OR b->>'decision'<>'BLOCKED_WEEKLY_GAME_SLOT_CAPACITY'
 OR i->>'decision'<>'BLOCKED_INVALID_WEEKLY_TIMETABLE'
 THEN RAISE EXCEPTION 'GROUP2_WEEKLY_SLOT_PREVIEW_TESTS_FAILED';END IF;
END $$;