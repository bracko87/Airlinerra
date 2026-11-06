-- Applied and checked against Airlinerra Supabase World 1 on 2026-11-06.
-- This migration installs a game-rule screening engine, NOT commercial flight activation.
-- Future aircraft are dynamically read by configuration_id from the aircraft catalog.
-- Never infer hard noise bans from estimated ICAO chapters or unsourced 24/7 defaults.
CREATE TABLE IF NOT EXISTS airlinerra_game.section5_runway_specific_restrictions_v1 (
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 source_runway_id text NOT NULL,
 rule_code text NOT NULL,
 rule_kind text NOT NULL CHECK (rule_kind IN ('RUNWAY_TIME_CLOSURE','RUNWAY_NOISE_CHAPTER_BAN')),
 affected_operation text NOT NULL CHECK (affected_operation IN ('departure','arrival','both')),
 local_start time NOT NULL,
 local_end time NOT NULL,
 weekday_iso smallint[],
 active_from date,
 active_until date,
 prohibited_icao_chapters smallint[] NOT NULL DEFAULT '{}'::smallint[],
 enforce_in_game boolean NOT NULL DEFAULT false,
 source_url text NOT NULL,
 evidence_note text NOT NULL,
 checked_on date NOT NULL,
 PRIMARY KEY(world_id,airport_key,source_runway_id,rule_code),
 CHECK(active_until IS NULL OR active_from IS NULL OR active_until>=active_from),
 CHECK(rule_kind='RUNWAY_TIME_CLOSURE' OR cardinality(prohibited_icao_chapters)>0),
 CHECK(cardinality(weekday_iso) IS NULL OR weekday_iso <@ ARRAY[1,2,3,4,5,6,7]::smallint[])
);
ALTER TABLE airlinerra_game.section5_runway_specific_restrictions_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section5_runway_specific_restrictions_v1 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section5_local_restriction_window_match_v1(p_local timestamp without time zone, p_start time without time zone, p_end time without time zone, p_weekdays smallint[] DEFAULT NULL::smallint[], p_active_from date DEFAULT NULL::date, p_active_until date DEFAULT NULL::date)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
WITH matched AS (
 SELECT
  CASE
    WHEN p_local IS NULL OR p_start IS NULL OR p_end IS NULL THEN false
    WHEN p_start=p_end THEN true
    WHEN p_start<p_end THEN p_local::time>=p_start AND p_local::time<p_end
    ELSE p_local::time>=p_start OR p_local::time<p_end END in_window,
  CASE WHEN p_start>p_end AND p_local::time<p_end
    THEN p_local::date-1 ELSE p_local::date END as start_day
)
SELECT coalesce(in_window
 AND (p_weekdays IS NULL OR extract(isodow from start_day)::smallint=ANY(p_weekdays))
 AND (p_active_from IS NULL OR start_day>=p_active_from)
 AND (p_active_until IS NULL OR start_day<=p_active_until),false)
FROM matched;
$function$

REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_local_restriction_window_match_v1(timestamp,time,time,smallint[],date,date) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section5_universal_airport_leg_restriction_v1(p_world_id smallint, p_airport_key text, p_configuration_id bigint, p_operation text, p_time_utc timestamp with time zone, p_source_runway_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 airport_row record;
 aircraft_row record;
 perf_row record;
 cert_row record;
 noise_row record;
 chosen record;
 local_dt timestamp;
 required_m numeric;
 estimated_reference boolean;
 official_chapter smallint;
 official_match boolean;
 time_block boolean;
 runway_block boolean;
 noise_block boolean;
 quota_review boolean;
 noise_review boolean;
 research_review boolean;
 runway_review boolean;
 has_runway boolean;
 verdict text;
BEGIN
 IF p_world_id IS NULL OR p_airport_key IS NULL OR p_configuration_id IS NULL
    OR p_time_utc IS NULL OR p_operation NOT IN ('departure','arrival')
    OR (p_source_runway_id IS NOT NULL AND btrim(p_source_runway_id)='')
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_INPUT','gameHardBlocked',true,
  'needsReview',false,'canActivateNormalFlight',false); END IF;

 SELECT pol.airport_code,pol.timezone_iana,pol.airport_key,pol.world_id
 INTO airport_row
 FROM airlinerra_game.section5_airport_operating_policy_v1 pol
 JOIN airlinerra_game.approved_game_airports aa USING(world_id,airport_key)
 WHERE pol.world_id=p_world_id AND pol.airport_key=p_airport_key;
 SELECT configuration_id,model_name,engine_option,takeoff_runway_m,landing_runway_m
 INTO aircraft_row
 FROM airlinerra.aircraft_catalog_configuration_inventory
 WHERE configuration_id=p_configuration_id;
 IF NOT FOUND OR airport_row.airport_key IS NULL THEN
  RETURN jsonb_build_object('decision','BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT',
   'gameHardBlocked',true,'needsReview',false,'canActivateNormalFlight',false);
 END IF;
 local_dt := p_time_utc AT TIME ZONE airport_row.timezone_iana;
 SELECT s.full_weight_takeoff_required_m,s.full_weight_landing_required_m,
        s.runway_source_verification
 INTO perf_row
 FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 s
 WHERE s.world_id=p_world_id AND s.airport_key=p_airport_key
   AND s.configuration_id=p_configuration_id;

 required_m:=CASE WHEN p_operation='departure'
     THEN coalesce(perf_row.full_weight_takeoff_required_m,aircraft_row.takeoff_runway_m)
     ELSE coalesce(perf_row.full_weight_landing_required_m,aircraft_row.landing_runway_m)
 END;
 estimated_reference := CASE WHEN p_operation='departure'
     THEN perf_row.full_weight_takeoff_required_m IS NULL
     ELSE perf_row.full_weight_landing_required_m IS NULL END;

 SELECT c.official_icao_chapter,c.noise_certificate_status
 INTO cert_row
 FROM airlinerra_game.section5_icao_aircraft_certification_v2 c
 WHERE c.configuration_id=p_configuration_id;
 official_match:=coalesce(cert_row.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED',false);
 official_chapter:=CASE WHEN official_match THEN cert_row.official_icao_chapter ELSE NULL END;

 SELECT c.research_status,c.documented_prohibited_chapters,
        b.chapter_result,b.curfew_result
 INTO noise_row
 FROM airlinerra_game.section5_airport_icao_chapter_policy_v2 c
 JOIN airlinerra_game.section5_airport_batch50_screen_v1 b USING(world_id,airport_key)
 WHERE c.world_id=p_world_id AND c.airport_key=p_airport_key;

 SELECT EXISTS (
  SELECT 1 FROM airlinerra_game.section5_airport_time_restrictions_v1 t
  WHERE t.world_id=p_world_id AND t.airport_key=p_airport_key
   AND t.game_auto_enforcement AND t.prohibit_normal_scheduled
   AND t.rule_kind<>'NIGHT_QUOTA_OR_RESTRICTION'
   AND t.affected_operations IN('both',CASE WHEN p_operation='arrival' THEN 'arrivals' ELSE 'departures' END)
   AND airlinerra_game.section5_local_restriction_window_match_v1(
      local_dt,t.local_start,t.local_end,t.weekday_iso)
 ) INTO time_block;

 SELECT EXISTS (
  SELECT 1 FROM airlinerra_game.section5_airport_time_restrictions_v1 t
  WHERE t.world_id=p_world_id AND t.airport_key=p_airport_key
   AND (t.rule_kind='NIGHT_QUOTA_OR_RESTRICTION' OR NOT t.game_auto_enforcement OR NOT t.prohibit_normal_scheduled)
   AND t.affected_operations IN('both',CASE WHEN p_operation='arrival' THEN 'arrivals' ELSE 'departures' END)
   AND airlinerra_game.section5_local_restriction_window_match_v1(
      local_dt,t.local_start,t.local_end,t.weekday_iso)
 ) INTO quota_review;

 noise_block:=official_chapter IS NOT NULL AND (
    (noise_row.research_status='OFFICIAL_RULE_FOUND'
      AND official_chapter=ANY(noise_row.documented_prohibited_chapters))
    OR EXISTS (
      SELECT 1 FROM airlinerra_game.section5_airport_official_noise_rules_v2 r
      WHERE r.world_id=p_world_id AND r.airport_key=p_airport_key
       AND r.game_enforcement_status='AUTO_ENFORCE_OFFICIAL_VERIFIED'
       AND r.rule_kind='ICAO_CHAPTER_BAN'
       AND r.documented_icao_chapter=official_chapter
       AND r.affected_operations IN('both',CASE WHEN p_operation='arrival' THEN 'arrivals' ELSE 'departures' END)
       AND (r.window_start_local IS NULL OR
           airlinerra_game.section5_local_restriction_window_match_v1(local_dt,r.window_start_local,r.window_end_local))
    )
 );

 SELECT i.source_runway_id,i.runway_designator,i.length_m,
        i.verification,i.operational_status,
        coalesce(i.length_m>=required_m,false) AS long_enough,
        EXISTS (
         SELECT 1 FROM airlinerra_game.section5_runway_specific_restrictions_v1 rr
         WHERE rr.world_id=i.world_id AND rr.airport_key=i.airport_key
          AND rr.source_runway_id=i.source_runway_id AND rr.enforce_in_game
          AND rr.affected_operation IN('both',p_operation)
          AND airlinerra_game.section5_local_restriction_window_match_v1(
           local_dt,rr.local_start,rr.local_end,rr.weekday_iso,rr.active_from,rr.active_until)
          AND (rr.rule_kind='RUNWAY_TIME_CLOSURE'
            OR (rr.rule_kind='RUNWAY_NOISE_CHAPTER_BAN'
                AND official_chapter IS NOT NULL AND official_chapter=ANY(rr.prohibited_icao_chapters)))
        ) AS rule_blocked,
        EXISTS (
         SELECT 1 FROM airlinerra_game.section5_runway_specific_restrictions_v1 rr
         WHERE rr.world_id=i.world_id AND rr.airport_key=i.airport_key
          AND rr.source_runway_id=i.source_runway_id
          AND rr.affected_operation IN('both',p_operation)
          AND airlinerra_game.section5_local_restriction_window_match_v1(
            local_dt,rr.local_start,rr.local_end,rr.weekday_iso,rr.active_from,rr.active_until)
          AND (NOT rr.enforce_in_game
            OR (rr.rule_kind='RUNWAY_NOISE_CHAPTER_BAN' AND official_chapter IS NULL))
        ) AS runway_rule_review
 INTO chosen
 FROM airlinerra_game.airport_runway_inventory i
 WHERE i.world_id=p_world_id AND i.airport_key=p_airport_key
  AND (p_source_runway_id IS NULL OR i.source_runway_id=p_source_runway_id)
  AND i.length_m IS NOT NULL
  AND upper(coalesce(i.surface_reported,'')) NOT IN ('GRVL','GRASS','TURF','DIRT','SOIL','SAND','WATER')
 ORDER BY (i.length_m>=required_m
           AND NOT EXISTS (
              SELECT 1 FROM airlinerra_game.section5_runway_specific_restrictions_v1 rr
              WHERE rr.world_id=i.world_id AND rr.airport_key=i.airport_key
               AND rr.source_runway_id=i.source_runway_id AND rr.enforce_in_game
               AND rr.affected_operation IN('both',p_operation)
               AND airlinerra_game.section5_local_restriction_window_match_v1(
                   local_dt,rr.local_start,rr.local_end,rr.weekday_iso,rr.active_from,rr.active_until)
               AND (rr.rule_kind='RUNWAY_TIME_CLOSURE'
                 OR (rr.rule_kind='RUNWAY_NOISE_CHAPTER_BAN'
                    AND official_chapter IS NOT NULL AND official_chapter=ANY(rr.prohibited_icao_chapters)))
            )) DESC,
           i.length_m DESC
 LIMIT 1;

 has_runway := chosen.source_runway_id IS NOT NULL;
 runway_block := has_runway AND NOT estimated_reference AND
                 (NOT coalesce(chosen.long_enough,false) OR coalesce(chosen.rule_blocked,false));
 runway_review := NOT has_runway OR estimated_reference OR required_m IS NULL
   OR chosen.operational_status IS DISTINCT FROM 'operational'
   OR coalesce(chosen.runway_rule_review,false);
 noise_review := (coalesce(noise_row.chapter_result,'NO')='YES' AND NOT official_match)
   OR EXISTS (
     SELECT 1 FROM airlinerra_game.section5_airport_official_noise_rules_v2 r
     WHERE r.world_id=p_world_id AND r.airport_key=p_airport_key
       AND r.game_enforcement_status NOT IN ('NONBINDING_DO_NOT_ENFORCE_AS_MANDATORY','AUTO_ENFORCE_OFFICIAL_VERIFIED','NO_ICAO_CHAPTER_BAN_DETERMINED')
   );
 research_review := coalesce(noise_row.curfew_result,'NO')='YES' AND NOT EXISTS (
    SELECT 1 FROM airlinerra_game.section5_airport_time_restrictions_v1 t
    WHERE t.world_id=p_world_id AND t.airport_key=p_airport_key
   );
 verdict := CASE
    WHEN p_source_runway_id IS NOT NULL AND NOT has_runway THEN 'BLOCKED_INVALID_RUNWAY_SELECTION'
    WHEN time_block THEN 'BLOCKED_AIRPORT_TIME_CURFEW'
    WHEN noise_block THEN 'BLOCKED_VERIFIED_NOISE_CHAPTER'
    WHEN runway_block THEN CASE WHEN chosen.rule_blocked THEN 'BLOCKED_SPECIFIC_RUNWAY_RULE'
                               ELSE 'BLOCKED_GAME_RUNWAY_LENGTH' END
    WHEN quota_review OR noise_review OR research_review OR runway_review THEN 'REVIEW_REQUIRED_NOT_FULLY_VERIFIED'
    ELSE 'PRELIMINARY_ALLOW_NO_RECORDED_CONFLICT' END;
 RETURN jsonb_build_object(
   'modelVersion','SECTION5_UNIVERSAL_AIRPORT_LEG_V1',
   'decision',verdict,
   'airportCode',airport_row.airport_code,
   'airportKey',p_airport_key,
   'localAirportTime',local_dt,
   'operation',p_operation,
   'aircraftConfigurationId',p_configuration_id,
   'aircraftModel',aircraft_row.model_name,
   'selectedRunwaySourceId',chosen.source_runway_id,
   'selectedRunwayDesignator',chosen.runway_designator,
   'runwayLengthM',chosen.length_m,
   'requiredGameRunwayLengthM',required_m,
   'runwayLengthEvidence',CASE WHEN estimated_reference THEN 'CATALOG_REFERENCE_NEEDS_FULL_WEIGHT_VALIDATION'
                             ELSE 'FULL_WEIGHT_GAME_REFERENCE' END,
   'runwayOperationalStatusVerified',chosen.operational_status='operational',
   'sourceMatchedIcaoChapter',official_chapter,
   'aircraftChapterNotConfigurationMatched',NOT official_match,
   'blockedByAirportTimeRule',time_block,
   'blockedByRunwayRule',coalesce(chosen.rule_blocked,false),
   'blockedByRunwayLength',has_runway AND NOT estimated_reference AND NOT coalesce(chosen.long_enough,false),
   'blockedByVerifiedNoiseRule',noise_block,
   'quotaOrSlotReview',quota_review,
   'runwayReview',runway_review,'noiseReview',noise_review,'researchReview',research_review,
   'gameHardBlocked',verdict LIKE 'BLOCKED_%',
   'needsReview',verdict LIKE 'REVIEW_REQUIRED_%',
   'gamePreliminaryAllow',verdict NOT LIKE 'BLOCKED_%',
   'canActivateNormalFlight',false,'realWorldDispatchApproved',false
 );
END;
$function$

REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_universal_airport_leg_restriction_v1(smallint,text,bigint,text,timestamptz,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section5_universal_route_restriction_gate_v1(p_world_id smallint, p_origin_airport_key text, p_destination_airport_key text, p_configuration_id bigint, p_departure_utc timestamp with time zone, p_arrival_utc timestamp with time zone, p_origin_source_runway_id text DEFAULT NULL::text, p_destination_source_runway_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 dep jsonb; arr jsonb; blocked boolean; review boolean; code text;
BEGIN
 IF p_world_id IS NULL OR p_origin_airport_key IS NULL OR p_destination_airport_key IS NULL
    OR p_origin_airport_key=p_destination_airport_key OR p_configuration_id IS NULL
    OR p_departure_utc IS NULL OR p_arrival_utc IS NULL
    OR p_arrival_utc<=p_departure_utc
    OR p_arrival_utc>p_departure_utc+interval '72 hours'
 THEN RETURN jsonb_build_object('modelVersion','SECTION5_UNIVERSAL_ROUTE_GATE_V1',
   'decision','BLOCKED_INVALID_ROUTE_OR_TIME','gameHardBlocked',true,
   'canActivateNormalFlight',false,'realWorldDispatchApproved',false);
 END IF;
 dep:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    p_world_id,p_origin_airport_key,p_configuration_id,'departure',p_departure_utc,p_origin_source_runway_id);
 arr:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    p_world_id,p_destination_airport_key,p_configuration_id,'arrival',p_arrival_utc,p_destination_source_runway_id);
 blocked:=coalesce((dep->>'gameHardBlocked')::boolean,true)
       OR coalesce((arr->>'gameHardBlocked')::boolean,true);
 review:=coalesce((dep->>'needsReview')::boolean,true)
       OR coalesce((arr->>'needsReview')::boolean,true);
 code:=CASE WHEN blocked THEN 'BLOCKED_BY_GAME_AIRPORT_RUNWAY_OR_NOISE_RESTRICTION'
       WHEN review THEN 'REVIEW_REQUIRED_GAME_RESTRICTION_SCREEN'
       ELSE 'PRELIMINARY_ALLOW_GAME_RESTRICTION_SCREEN' END;
 RETURN jsonb_build_object(
    'modelVersion','SECTION5_UNIVERSAL_ROUTE_GATE_V1','decision',code,
    'origin',dep,'destination',arr,
    'aircraftConfigurationId',p_configuration_id,
    'gameHardBlocked',blocked,'needsReview',review,
    'gamePreliminaryAllow',NOT blocked,
    'canActivateNormalFlight',false,
    'realWorldDispatchApproved',false,
    'activationBlockedUntilOtherFlightSystemsExist',true
 );
END;
$function$

REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_universal_route_restriction_gate_v1(smallint,text,text,bigint,timestamptz,timestamptz,text,text) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_universal_route_restriction_gate_v1(smallint,text,text,bigint,timestamptz,timestamptz,text,text)
 IS 'Server-side dynamic airport time, selected/auto-selected runway length and source-supported aircraft noise game screening. No live flight activation/real-world dispatch approval.';
