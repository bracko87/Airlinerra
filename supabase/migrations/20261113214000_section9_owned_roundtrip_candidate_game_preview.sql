-- Shared, owner-scoped game-only outbound and RETURN flight preview.
-- Two legs + active aircraft rotations are evaluated as ONE time sequence.
-- Both airport-slot proposals are counted simultaneously before any writer.
-- Existing independent licence, slot and activation authorities remain locked.
-- Does not create routes, slots, flights, passengers or financial entries.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_roundtrip_candidate_preview_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_origin text, p_destination text, p_out_depart timestamp with time zone, p_out_arrive timestamp with time zone, p_back_depart timestamp with time zone, p_back_arrive timestamp with time zone, p_out_weekly jsonb, p_back_weekly jsonb, p_out_depart_stand text, p_out_arrive_stand text, p_back_depart_stand text, p_back_arrive_stand text, p_turnaround integer, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 f record;tz_out text;tz_back text;first_day date;ground_min integer;
 v_out_count integer:=0;v_back_count integer:=0;
 v_overlaps integer:=0;v_wrong integer:=0;v_short integer:=0;v_dst integer:=0;
 v_slots boolean:=false;v_windows integer:=0;
 v_out_gate jsonb;v_back_gate jsonb;v_restrictions boolean:=false;
 v_fits boolean:=false;v_active integer:=0;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
 OR p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
 OR p_out_depart IS NULL OR p_out_arrive IS NULL
 OR p_back_depart IS NULL OR p_back_arrive IS NULL
 OR p_out_arrive<=p_out_depart OR p_out_arrive>p_out_depart+interval '72 hours'
 OR p_back_arrive<=p_back_depart OR p_back_arrive>p_back_depart+interval '72 hours'
 OR p_back_depart<=p_out_arrive OR p_back_depart>p_out_depart+interval '72 hours'
 OR p_turnaround IS NULL OR p_turnaround NOT BETWEEN 15 AND 360
 OR p_days IS NULL OR p_days NOT BETWEEN 7 AND 42
 OR p_out_weekly IS NULL OR jsonb_typeof(p_out_weekly)<>'array'
 OR p_back_weekly IS NULL OR jsonb_typeof(p_back_weekly)<>'array'
 OR jsonb_array_length(p_out_weekly) NOT BETWEEN 1 AND 7
 OR jsonb_array_length(p_back_weekly) NOT BETWEEN 1 AND 7
 OR p_out_depart_stand NOT IN ('terminal','remote','cargo')
 OR p_out_arrive_stand NOT IN ('terminal','remote','cargo')
 OR p_back_depart_stand NOT IN ('terminal','remote','cargo')
 OR p_back_arrive_stand NOT IN ('terminal','remote','cargo')
 THEN RETURN jsonb_build_object('status','INVALID_ROUNDTRIP_INPUT','readOnly',true,
  'gameRoundtripModelSuitable',false,'flightsCreated',0,'slotsReserved',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS(
 SELECT 1 FROM (
  SELECT j.value FROM jsonb_array_elements(p_out_weekly) j
  UNION ALL SELECT j.value FROM jsonb_array_elements(p_back_weekly) j
 ) q WHERE jsonb_typeof(q.value)<>'object'
  OR coalesce(q.value->>'day','') !~ '^[0-6]$'
  OR coalesce(q.value->>'time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
  OR (SELECT count(*) FROM jsonb_object_keys(q.value))<>2
 ) OR (SELECT count(DISTINCT j.value->>'day') FROM jsonb_array_elements(p_out_weekly) j)
      <>jsonb_array_length(p_out_weekly)
   OR (SELECT count(DISTINCT j.value->>'day') FROM jsonb_array_elements(p_back_weekly) j)
      <>jsonb_array_length(p_back_weekly)
 THEN RETURN jsonb_build_object('status','INVALID_ROUNDTRIP_WEEKLY_SCHEDULE',
 'readOnly',true,'gameRoundtripModelSuitable',false,'flightsCreated',0,
 'slotsReserved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT fleet.id,fleet.configuration_id,fleet.fleet_status,fleet.ownership_type,
        conf.use_type,conf.typical_passenger_seats
 INTO f FROM airlinerra_game.airline_aircraft_inventory fleet
 JOIN airlinerra_game.airlines airline ON airline.id=fleet.airline_id AND airline.world_id=1
 JOIN airlinerra_game.world_memberships member ON member.world_id=airline.world_id
 AND member.player_id=airline.owner_player_id AND member.state='active'
 JOIN airlinerra.aircraft_catalog_configuration_inventory conf
 ON conf.configuration_id=fleet.configuration_id
 WHERE fleet.id=p_aircraft AND fleet.airline_id=p_airline AND airline.owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_OWNER_AIRCRAFT_NOT_VERIFIED';END IF;
 IF f.fleet_status<>'in_service' OR f.ownership_type NOT IN ('owned','leased')
 OR (f.use_type='cargo' AND
   (p_out_depart_stand<>'cargo' OR p_out_arrive_stand<>'cargo'
    OR p_back_depart_stand<>'cargo' OR p_back_arrive_stand<>'cargo'))
 OR (f.use_type='passenger' AND
    'cargo' IN (p_out_depart_stand,p_out_arrive_stand,p_back_depart_stand,p_back_arrive_stand))
 THEN RETURN jsonb_build_object('status','ROUNDTRIP_AIRCRAFT_OR_STAND_NOT_ELIGIBLE',
 'readOnly',true,'gameRoundtripModelSuitable',false,'flightsCreated',0,
 'slotsReserved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT a.timezone_iana INTO tz_out FROM airlinerra_game.airport_reference_profiles a
 JOIN pg_catalog.pg_timezone_names n ON n.name=a.timezone_iana
 WHERE a.world_id=1 AND a.airport_key=p_origin;
 SELECT a.timezone_iana INTO tz_back FROM airlinerra_game.airport_reference_profiles a
 JOIN pg_catalog.pg_timezone_names n ON n.name=a.timezone_iana
 WHERE a.world_id=1 AND a.airport_key=p_destination;
 IF tz_out IS NULL OR tz_back IS NULL THEN RETURN jsonb_build_object(
 'status','ROUNDTRIP_TIMEZONE_MISSING','readOnly',true,'gameRoundtripModelSuitable',false,
 'flightsCreated',0,'slotsReserved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 first_day:=(p_out_depart AT TIME ZONE tz_out)::date;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_out_weekly) w
 WHERE (w.value->>'day')::int=extract(isodow from p_out_depart AT TIME ZONE tz_out)::int-1
 AND w.value->>'time'=to_char(p_out_depart AT TIME ZONE tz_out,'HH24:MI'))
 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_back_weekly) w
 WHERE (w.value->>'day')::int=extract(isodow from p_back_depart AT TIME ZONE tz_back)::int-1
 AND w.value->>'time'=to_char(p_back_depart AT TIME ZONE tz_back,'HH24:MI'))
 THEN RETURN jsonb_build_object('status','ROUNDTRIP_REFERENCE_TIME_NOT_IN_CALENDAR',
 'readOnly',true,'gameRoundtripModelSuitable',false,'flightsCreated',0,
 'slotsReserved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT rule.min_ground_minutes INTO ground_min
 FROM airlinerra_game.section9_game_turnaround_policy_v1 rule
 WHERE rule.role=CASE WHEN f.use_type='cargo' THEN 'cargo' ELSE 'passenger' END
 AND rule.max_seats>=coalesce(f.typical_passenger_seats,10000)
 ORDER BY rule.max_seats LIMIT 1;
 IF ground_min IS NULL OR p_turnaround<ground_min
 OR p_back_depart-p_out_arrive<make_interval(mins=>p_turnaround)
 THEN RETURN jsonb_build_object('status','ROUNDTRIP_TURNAROUND_TOO_SHORT',
 'minimumGameTurnaroundMinutes',ground_min,
 'requestedTurnaroundMinutes',p_turnaround,'readOnly',true,
 'gameRoundtripModelSuitable',false,'flightsCreated',0,
 'slotsReserved',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT count(*)::int INTO v_active FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
 AND s.world_id=1 AND s.status='active' AND s.operationally_verified=true;
 IF v_active>250 THEN RETURN jsonb_build_object('status','ROUNDTRIP_SCHEDULE_LIMIT',
 'readOnly',true,'gameRoundtripModelSuitable',false,'flightsCreated',0,
 'slotsReserved',false,'flightActivated',false,'ledgerPosted',false);END IF;

 WITH legs AS MATERIALIZED (
  SELECT 'out'::text leg,p_origin origin_key,p_destination destination_key,
   tz_out tz,p_out_arrive-p_out_depart block,p_out_weekly weekly
  UNION ALL
  SELECT 'back',p_destination,p_origin,tz_back,p_back_arrive-p_back_depart,p_back_weekly
  UNION ALL
  SELECT 'existing',s.origin_airport_key,s.destination_airport_key,
   ap.timezone_iana,s.reference_arrival_utc-s.reference_departure_utc,s.weekly_schedule
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  JOIN airlinerra_game.airport_reference_profiles ap
    ON ap.world_id=s.world_id AND ap.airport_key=s.origin_airport_key
  JOIN pg_catalog.pg_timezone_names tz ON tz.name=ap.timezone_iana
  WHERE s.world_id=1 AND s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
   AND s.status='active' AND s.operationally_verified=true
 ), times AS MATERIALIZED (
  SELECT l.leg,l.origin_key,l.destination_key,l.tz,
   (day.d::date+(w.value->>'time')::time) local_departure,
   ((day.d::date+(w.value->>'time')::time) AT TIME ZONE l.tz) depart_utc,
   ((day.d::date+(w.value->>'time')::time) AT TIME ZONE l.tz)+l.block arrive_utc
  FROM legs l CROSS JOIN generate_series((first_day-7)::timestamp,
      (first_day+p_days+2)::timestamp,interval '1 day') day(d)
  CROSS JOIN LATERAL jsonb_array_elements(l.weekly) w(value)
  WHERE coalesce(w.value->>'day','') ~ '^[0-6]$'
   AND coalesce(w.value->>'time','') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
   AND (w.value->>'day')::int=extract(isodow from day.d)::int-1
   AND l.block>interval '0' AND l.block<=interval '72 hours'
 ), sequenced AS MATERIALIZED (
 SELECT t.*,
  lag(t.destination_key) OVER seq prev_dest,
  lag(t.arrive_utc) OVER seq prev_arrive,
  max(t.arrive_utc) OVER (ORDER BY t.depart_utc,t.leg ROWS BETWEEN
    UNBOUNDED PRECEDING AND 1 PRECEDING) latest_arrive,
  (t.depart_utc AT TIME ZONE t.tz)<>t.local_departure OR
    ((t.depart_utc+interval '1 hour') AT TIME ZONE t.tz)=t.local_departure OR
    ((t.depart_utc-interval '1 hour') AT TIME ZONE t.tz)=t.local_departure
    AS dst_ambiguous
 FROM times t WINDOW seq AS (ORDER BY t.depart_utc,t.leg)
 ), tally AS (
 SELECT count(*) FILTER(WHERE leg='out' AND depart_utc >=
    (first_day::timestamp AT TIME ZONE tz_out)
    AND depart_utc < ((first_day+p_days)::timestamp AT TIME ZONE tz_out))::int out_count,
 count(*) FILTER(WHERE leg='back' AND depart_utc >=
    (first_day::timestamp AT TIME ZONE tz_out)
    AND depart_utc < ((first_day+p_days)::timestamp AT TIME ZONE tz_out))::int back_count,
 count(*) FILTER(WHERE latest_arrive>depart_utc AND depart_utc >=
    (first_day::timestamp AT TIME ZONE tz_out)
    AND depart_utc < ((first_day+p_days)::timestamp AT TIME ZONE tz_out))::int overlaps_count,
 count(*) FILTER(WHERE prev_arrive<=depart_utc AND prev_dest<>origin_key
    AND depart_utc >= (first_day::timestamp AT TIME ZONE tz_out)
    AND depart_utc < ((first_day+p_days)::timestamp AT TIME ZONE tz_out))::int wrong_count,
 count(*) FILTER(WHERE prev_arrive<=depart_utc AND prev_dest=origin_key
    AND depart_utc-prev_arrive<make_interval(mins=>ground_min)
    AND depart_utc >= (first_day::timestamp AT TIME ZONE tz_out)
    AND depart_utc < ((first_day+p_days)::timestamp AT TIME ZONE tz_out))::int short_count,
 count(*) FILTER(WHERE dst_ambiguous AND depart_utc >=
    (first_day::timestamp AT TIME ZONE tz_out)
    AND depart_utc < ((first_day+p_days)::timestamp AT TIME ZONE tz_out))::int dst_count
 FROM sequenced)
 SELECT out_count,back_count,overlaps_count,wrong_count,short_count,dst_count
 INTO v_out_count,v_back_count,v_overlaps,v_wrong,v_short,v_dst FROM tally;

 WITH proposed AS MATERIALIZED (
  SELECT prop.* FROM airlinerra_game.section6_weekly_slot_proposals_v1(
   1::smallint,p_origin,p_destination,p_out_depart,p_out_arrive,p_out_weekly,
   p_out_depart_stand,p_out_arrive_stand) prop
  UNION ALL
  SELECT prop.* FROM airlinerra_game.section6_weekly_slot_proposals_v1(
   1::smallint,p_destination,p_origin,p_back_depart,p_back_arrive,p_back_weekly,
   p_back_depart_stand,p_back_arrive_stand) prop
 ), counted AS (
 SELECT s.*,
 count(*) OVER(PARTITION BY airport_key,stand_type,direction,weekday,minute_of_day/60) req_hour,
 count(*) OVER(PARTITION BY airport_key,stand_type,direction,weekday,minute_of_day) req_window
 FROM proposed s
 ), capacity AS (
 SELECT r.*,
 CASE r.stand_type WHEN 'terminal' THEN c.terminal_stands WHEN 'remote' THEN c.remote_stands ELSE c.cargo_stands END limit_hour,
 CASE r.stand_type WHEN 'terminal' THEN c.terminal_per_direction_10m WHEN 'remote' THEN c.remote_per_direction_10m ELSE c.cargo_per_direction_10m END limit_window,
 (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 u
  WHERE u.world_id=1 AND u.airport_key=r.airport_key
  AND u.stand_type=r.stand_type AND u.direction=r.direction AND u.weekday=r.weekday
  AND u.minute_of_day BETWEEN (r.minute_of_day/60)*60 AND (r.minute_of_day/60)*60+59) used_hour,
 (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 u
  WHERE u.world_id=1 AND u.airport_key=r.airport_key
  AND u.stand_type=r.stand_type AND u.direction=r.direction AND u.weekday=r.weekday
  AND u.minute_of_day=r.minute_of_day) used_window
 FROM counted r LEFT JOIN airlinerra_game.section6_airport_slot_capacity_v1 c
  ON c.world_id=1 AND c.airport_key=r.airport_key)
 SELECT coalesce(bool_and(coalesce(limit_hour,0)>0 AND coalesce(limit_window,0)>0
  AND used_hour+req_hour<=coalesce(limit_hour,0)
  AND used_window+req_window<=coalesce(limit_window,0)),false),
 count(*)::int INTO v_slots,v_windows FROM capacity;
 v_out_gate:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
 1::smallint,p_origin,p_destination,f.configuration_id,p_out_depart,p_out_arrive,p_out_weekly);
 v_back_gate:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
 1::smallint,p_destination,p_origin,f.configuration_id,p_back_depart,p_back_arrive,p_back_weekly);
 v_restrictions:=v_out_gate->>'weeklyTimetableChecked'='true'
  AND v_out_gate->>'gameHardBlocked'='false'
  AND v_back_gate->>'weeklyTimetableChecked'='true'
  AND v_back_gate->>'gameHardBlocked'='false';
 v_fits:=v_slots AND v_restrictions AND v_out_count>0 AND v_back_count>0
  AND v_overlaps=0 AND v_wrong=0 AND v_short=0 AND v_dst=0;
 RETURN jsonb_build_object(
 'status',CASE WHEN v_fits THEN 'ROUNDTRIP_GAME_PREVIEW_PASSED'
    ELSE 'ROUNDTRIP_GAME_PREVIEW_BLOCKED' END,
 'worldId',1,'readOnly',true,
 'modelVersion','SECTION9_ROUNDTRIP_GAME_PREVIEW_V1',
 'gameEvidenceType','GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE',
 'outboundOccurrences',v_out_count,'returnOccurrences',v_back_count,
 'existingActiveSchedules',v_active,
 'overlappingFlights',v_overlaps,'wrongAirportDepartures',v_wrong,
 'shortTurnarounds',v_short,'daylightSavingTimeIssues',v_dst,
 'minimumGameTurnaroundMinutes',ground_min,
 'requestedTurnaroundMinutes',p_turnaround,
 'returnGroundMinutes',extract(epoch FROM (p_back_depart-p_out_arrive))/60,
 'combinedSlotCapacityAvailable',v_slots,'combinedSlotWindowsChecked',v_windows,
 'outboundNoHardRestriction',v_out_gate->>'gameHardBlocked'='false',
 'returnNoHardRestriction',v_back_gate->>'gameHardBlocked'='false',
 'airportReviewsPending',coalesce((v_out_gate->>'needsReview')::boolean,true)
    OR coalesce((v_back_gate->>'needsReview')::boolean,true),
 'gameRoundtripModelSuitable',v_fits,'initialAircraftPositionVerified',false,
 'operatorLicenceApproved',false,'trafficRightsApproved',false,
 'flightsCreated',0,'slotsReserved',false,'bookingsCreated',false,
 'licenceIssued',false,'flightActivated',false,'ledgerPosted',false,
 'operationallyApproved',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_roundtrip_candidate_preview_v1(
 uuid,uuid,uuid,text,text,timestamptz,timestamptz,timestamptz,timestamptz,
 jsonb,jsonb,text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION airlinerra_game.section9_owned_roundtrip_candidate_preview_v1(
 uuid,uuid,uuid,text,text,timestamptz,timestamptz,timestamptz,timestamptz,
 jsonb,jsonb,text,text,text,text,integer,integer) TO service_role;
