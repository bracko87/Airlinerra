-- Provisional GAME-only crew duty/rest guidance, not real-world
-- regulatory crew duty-time certification or activation authority.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_game_crew_rest_policy_v1(
 policy_version text PRIMARY KEY CHECK(policy_version='provisional_game_rest_v1'),
 preflight_minutes smallint NOT NULL CHECK(preflight_minutes BETWEEN 0 AND 180),
 postflight_minutes smallint NOT NULL CHECK(postflight_minutes BETWEEN 0 AND 180),
 minimum_rest_minutes smallint NOT NULL CHECK(minimum_rest_minutes BETWEEN 300 AND 1440),
 max_single_duty_minutes smallint NOT NULL CHECK(max_single_duty_minutes BETWEEN 300 AND 1440)
);
ALTER TABLE airlinerra_game.section9_game_crew_rest_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_game_crew_rest_policy_v1 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section9_game_crew_rest_policy_v1(
 policy_version,preflight_minutes,postflight_minutes,
 minimum_rest_minutes,max_single_duty_minutes)
VALUES ('provisional_game_rest_v1',60,30,660,720)
ON CONFLICT(policy_version) DO NOTHING;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_rest_preview_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_start_date date,p_days int DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE policy record; total int; schedule_conf bigint;report jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL OR
 p_start_date IS NULL OR p_start_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_days NOT BETWEEN 7 AND 42 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_CREW_REST_PREVIEW';END IF;
 SELECT s.configuration_id INTO schedule_conf
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id AND a.world_id=1
 AND a.owner_player_id=p_player
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF schedule_conf IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_CREW_REST_SCHEDULE_NOT_OWNED';END IF;
 SELECT * INTO policy FROM airlinerra_game.section9_game_crew_rest_policy_v1
 WHERE policy_version='provisional_game_rest_v1';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_CREW_REST_POLICY_MISSING';END IF;
 SELECT count(*) INTO total FROM
 airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
 WHERE d.airline_id=p_airline AND d.crew_id IN (
  SELECT crew_id FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1
  WHERE airline_id=p_airline AND schedule_id=p_schedule);
 IF total>1000 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_CREW_REST_REQUIRES_SHARDING';END IF;
 WITH selected AS MATERIALIZED(
  SELECT DISTINCT d.crew_id
  FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
  WHERE d.schedule_id=p_schedule AND d.airline_id=p_airline
 ), duty_entries AS MATERIALIZED(
  SELECT d.crew_id,d.schedule_id,d.weekly_entry,d.schedule_version,
   s.version AS current_version,s.configuration_id,s.weekly_schedule,
   s.reference_arrival_utc-s.reference_departure_utc AS flight_duration,
   s.origin_airport_key,s.destination_airport_key,
   tz.timezone_iana,
   c.qualified_configuration_id,c.employment_status,
   s.weekly_schedule->(d.weekly_entry-1) AS weekly_item
  FROM selected wanted
  JOIN airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
   ON d.crew_id=wanted.crew_id AND d.airline_id=p_airline
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
   ON s.id=d.schedule_id AND s.airline_id=p_airline AND s.world_id=1
  JOIN airlinerra_game.section9_airline_crew_roster_v1 c
   ON c.crew_id=d.crew_id AND c.airline_id=p_airline
  LEFT JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
 ), good AS MATERIALIZED(
  SELECT d.*,d.weekly_item->>'day' AS weekday_text,
   d.weekly_item->>'time' AS clock_text
  FROM duty_entries d WHERE d.schedule_version=d.current_version
   AND d.qualified_configuration_id=d.configuration_id
   AND d.employment_status='verified_employed'
   AND jsonb_typeof(d.weekly_item)='object'
   AND coalesce(d.weekly_item->>'day','') ~ '^[0-6]$'
   AND coalesce(d.weekly_item->>'time','') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
   AND d.timezone_iana IS NOT NULL
   AND EXISTS(SELECT 1 FROM pg_catalog.pg_timezone_names n
    WHERE n.name=d.timezone_iana)
 ), dated AS MATERIALIZED(
  SELECT g.*,
    (day_value::date+(g.clock_text)::time) AS local_departure,
    ((day_value::date+(g.clock_text)::time) AT TIME ZONE g.timezone_iana) AS departure_utc
  FROM good g
  CROSS JOIN LATERAL generate_series(
   (p_start_date-7)::timestamp,(p_start_date+p_days+7)::timestamp,
   interval '1 day') AS day_value
  WHERE (g.weekday_text)::int = extract(isodow FROM day_value)::int-1
 ), intervals AS MATERIALIZED(
  SELECT d.*,
   d.departure_utc + d.flight_duration AS arrival_utc,
   d.departure_utc-make_interval(mins=>policy.preflight_minutes) AS duty_start,
   d.departure_utc+d.flight_duration+
     make_interval(mins=>policy.postflight_minutes) AS duty_end,
   ((d.departure_utc AT TIME ZONE d.timezone_iana)
      IS DISTINCT FROM d.local_departure
     OR ((d.departure_utc-interval '1 hour') AT TIME ZONE d.timezone_iana)
        =d.local_departure
     OR ((d.departure_utc+interval '1 hour') AT TIME ZONE d.timezone_iana)
        =d.local_departure) AS invalid_dst
  FROM dated d
 ), ordered AS MATERIALIZED(
  SELECT i.*,
   lag(i.duty_end) OVER (PARTITION BY crew_id ORDER BY duty_start,schedule_id,weekly_entry)
    AS previous_duty_end,
   lag(i.destination_airport_key) OVER
     (PARTITION BY crew_id ORDER BY duty_start,schedule_id,weekly_entry)
    AS previous_destination,
   max(i.duty_end) OVER (
    PARTITION BY crew_id ORDER BY duty_start,schedule_id,weekly_entry
    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS max_prior_duty_end
  FROM intervals i
 ), filtered AS MATERIALIZED(
  SELECT *,
    max_prior_duty_end>duty_start AS has_overlap,
    previous_duty_end IS NOT NULL AND
     duty_start>=previous_duty_end AND
     duty_start<previous_duty_end+
       make_interval(mins=>policy.minimum_rest_minutes) AS rest_short,
    previous_duty_end IS NOT NULL AND duty_start>=previous_duty_end
     AND previous_destination<>origin_airport_key AS teleport,
    extract(epoch FROM duty_end-duty_start)/60 >
     policy.max_single_duty_minutes AS excessive_duty
  FROM ordered
 )
 SELECT jsonb_build_object(
  'status','PROVISIONAL_GAME_REST_PREVIEW_ONLY',
  'scheduleId',p_schedule,'previewDays',p_days,
  'assignedCrew', (SELECT count(*) FROM selected),
  'scheduledDutyOccurrences',count(*)::int,
  'overlapConflicts',count(*) FILTER(WHERE has_overlap)::int,
  'insufficientRest',count(*) FILTER(WHERE rest_short)::int,
  'crewWrongAirport',count(*) FILTER(WHERE teleport)::int,
  'overlongDuty',count(*) FILTER(WHERE excessive_duty)::int,
  'invalidLocalDeparture',count(*) FILTER(WHERE invalid_dst)::int,
  'unverifiedOrStaleAssignments',
    (SELECT count(*) FROM duty_entries e
      WHERE NOT EXISTS(SELECT 1 FROM good g
       WHERE g.crew_id=e.crew_id AND g.schedule_id=e.schedule_id
        AND g.weekly_entry=e.weekly_entry))::int,
  'gamePolicy',jsonb_build_object(
   'preflightMinutes',policy.preflight_minutes,
   'postflightMinutes',policy.postflight_minutes,
   'minimumRestMinutes',policy.minimum_rest_minutes,
   'maxSingleDutyMinutes',policy.max_single_duty_minutes),
  'sampleConflicts',(SELECT coalesce(jsonb_agg(jsonb_build_object(
    'crewId',x.crew_id,'scheduleId',x.schedule_id,
    'departureUtc',x.departure_utc,'overlap',x.has_overlap,
    'restTooShort',x.rest_short,'wrongAirport',x.teleport,
    'overlongDuty',x.excessive_duty,'invalidLocalTime',x.invalid_dst)
    ORDER BY x.duty_start),'[]'::jsonb)
   FROM (SELECT * FROM filtered
    WHERE has_overlap OR rest_short OR teleport OR excessive_duty OR invalid_dst
    ORDER BY duty_start LIMIT 10) x),
  'actualLegalDutyAndRestCertified',false,
  'flightCrewAuthorized',false,
  'canActivateNormalFlight',false,'readOnly',true
 ) INTO report FROM filtered;
 RETURN report;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_crew_rest_preview_v1(
 uuid,uuid,uuid,date,int) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_owned_crew_rest_preview_v1(
 uuid,uuid,uuid,date,int) IS
 'Bounded 7-42d owner-scoped game-only crew duty overlap, location and rest diagnostics. NOT legal crew duty certification.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_date date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE base jsonb;staff jsonb; rest jsonb;
BEGIN
 base:=airlinerra_game.section9_owned_operational_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 staff:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 rest:=airlinerra_game.section9_owned_crew_rest_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 IF base->>'readOnly'<>'true' OR base->>'canActivateNormalFlight'<>'false'
 OR staff->>'readOnly'<>'true' OR staff->>'canActivateNormalFlight'<>'false'
 OR rest->>'readOnly'<>'true' OR rest->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNSAFE_OPERATING_EVIDENCE';END IF;
 RETURN base || jsonb_build_object(
  'crewStaffing',staff->'crew',
  'operatingPermissionEvidence',staff->'permissions',
  'crewRest',rest,
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 uuid,uuid,uuid,date,integer) FROM PUBLIC,anon,authenticated;
