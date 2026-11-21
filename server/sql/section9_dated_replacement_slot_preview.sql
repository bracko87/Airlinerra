-- Private, read-only dated replacement-slot planning. No dispatch or reservations are changed.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_dated_replacement_slot_check_v1(
 p_world smallint,p_airport text,p_stand text,p_direction text,p_time timestamptz
) RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO pg_catalog,airlinerra_game AS $$
WITH c AS (
 SELECT a.*,p.timezone_iana,p_time AT TIME ZONE p.timezone_iana AS local_dt,
 CASE p_stand WHEN 'terminal' THEN a.terminal_stands WHEN 'remote' THEN a.remote_stands WHEN 'cargo' THEN a.cargo_stands END AS hour_limit,
 CASE p_stand WHEN 'terminal' THEN a.terminal_per_direction_10m WHEN 'remote' THEN a.remote_per_direction_10m WHEN 'cargo' THEN a.cargo_per_direction_10m END AS window_limit
 FROM airlinerra_game.section6_airport_slot_capacity_v1 a
 JOIN airlinerra_game.section5_airport_operating_policy_v1 p USING(world_id,airport_key)
 WHERE a.world_id=p_world AND a.airport_key=p_airport AND p_direction IN('departure','arrival')
), b AS (
 SELECT c.*,extract(isodow FROM local_dt)::int-1 AS dow,
 extract(hour FROM local_dt)::int*60+(extract(minute FROM local_dt)::int/10)*10 AS minute_bucket FROM c
 WHERE local_dt IS NOT NULL
), usage AS (
 SELECT b.*,w.h+r.h AS used_hour,w.m+r.m AS used_window
 FROM b
 CROSS JOIN LATERAL (
 SELECT count(*) FILTER(WHERE s.minute_of_day/60=b.minute_bucket/60) h,
 count(*) FILTER(WHERE s.minute_of_day=b.minute_bucket) m
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 s
 WHERE s.world_id=p_world AND s.airport_key=p_airport AND s.stand_type=p_stand AND s.direction=p_direction AND s.weekday=b.dow
 ) w
 CROSS JOIN LATERAL (
 SELECT count(*) FILTER(WHERE s.minute_of_day/60=b.minute_bucket/60) h,
 count(*) FILTER(WHERE s.minute_of_day=b.minute_bucket) m
 FROM airlinerra_game.section6_dated_relocation_slots_v1 s
 WHERE s.world_id=p_world AND s.airport_key=p_airport AND s.stand_type=p_stand AND s.direction=p_direction AND s.local_date=b.local_dt::date
 ) r
)
SELECT coalesce((SELECT hour_limit>used_hour AND window_limit>used_window FROM usage),false);
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_dated_replacement_slot_check_v1(smallint,text,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_preview_replacement_slot_pair_v1(
 p_world smallint,p_origin text,p_destination text,p_configuration bigint,
 p_departure_stand text,p_arrival_stand text,p_scheduled_departure timestamptz,
 p_scheduled_arrival timestamptz,p_earliest_departure timestamptz,
 p_turnaround_minutes integer,p_max_delay_minutes integer DEFAULT 240
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE d timestamptz;a timestamptz; latest timestamptz;checked integer:=0;duration interval;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_REPLACEMENT_SLOT_PLANNER';END IF;
 IF p_world IS DISTINCT FROM 1 OR p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
 OR p_configuration IS NULL OR p_departure_stand IS NULL OR p_departure_stand NOT IN('terminal','remote','cargo')
 OR p_arrival_stand IS NULL OR p_arrival_stand NOT IN('terminal','remote','cargo')
 OR p_scheduled_departure IS NULL OR p_scheduled_arrival IS NULL OR p_earliest_departure IS NULL
 OR NOT isfinite(p_scheduled_departure) OR NOT isfinite(p_scheduled_arrival) OR NOT isfinite(p_earliest_departure)
 OR p_scheduled_arrival<=p_scheduled_departure OR p_scheduled_arrival-p_scheduled_departure>interval '48 hours'
 OR p_turnaround_minutes IS NULL OR p_turnaround_minutes NOT BETWEEN 0 AND 360
 OR p_max_delay_minutes IS NULL OR p_max_delay_minutes NOT BETWEEN 0 AND 720
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_REPLACEMENT_SLOT_INPUT'; END IF;
 duration:=p_scheduled_arrival-p_scheduled_departure;
 latest:=p_scheduled_departure+make_interval(mins=>p_max_delay_minutes);
 d:=greatest(p_scheduled_departure,p_earliest_departure);
 WHILE d<=latest LOOP
  checked:=checked+1;a:=d+duration;
  IF EXISTS(SELECT 1 FROM airlinerra_game.section5_normal_flight_schedule_check_v1(p_world,p_origin,p_configuration,'departure',d) x WHERE x.permitted_for_normal_schedule AND NOT x.requires_special_rule_review)
  AND EXISTS(SELECT 1 FROM airlinerra_game.section5_normal_flight_schedule_check_v1(p_world,p_destination,p_configuration,'arrival',a) x WHERE x.permitted_for_normal_schedule AND NOT x.requires_special_rule_review)
  AND airlinerra_game.section9_dated_replacement_slot_check_v1(p_world,p_origin,p_departure_stand,'departure',d)
  AND airlinerra_game.section9_dated_replacement_slot_check_v1(p_world,p_destination,p_arrival_stand,'arrival',a)
  THEN
   RETURN jsonb_build_object('status','replacement_slot_pair_preview','departureUtc',d,'arrivalUtc',a,
   'availableUtc',a+make_interval(mins=>p_turnaround_minutes),'delayMinutes',ceil(extract(epoch FROM d-p_scheduled_departure)/60)::int,
   'candidatesChecked',checked,'readOnly',true,'slotsReserved',false,'dispatchChanged',false);
  END IF;
  d:=d+interval '10 minutes';
 END LOOP;
 RETURN jsonb_build_object('status','no_replacement_pair_within_limit','candidatesChecked',checked,'readOnly',true,'slotsReserved',false,'dispatchChanged',false);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_preview_replacement_slot_pair_v1(smallint,text,text,bigint,text,text,timestamptz,timestamptz,timestamptz,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
