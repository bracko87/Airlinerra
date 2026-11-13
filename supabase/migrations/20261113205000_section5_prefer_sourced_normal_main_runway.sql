-- Preserve the universal flight restriction gate and all existing hard blocks.
-- Prefer source-backed routine runway use over a longer, conditional alternate.
-- No runway is declared currently operational by this selection preference.
-- Explicit alternate selection continues to require review/closure evidence.
-- Required source rows: 20261113204000_section5_belgrade_normal_runway_procedural_evidence.sql

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
 SELECT configuration_id,model_name,engine_option,takeoff_runway_m,landing_runway_m,use_type
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
   AND (t.applies_aircraft_use_types IS NULL OR aircraft_row.use_type=ANY(t.applies_aircraft_use_types))
   AND airlinerra_game.section5_local_restriction_window_match_v1(
      local_dt,t.local_start,t.local_end,t.weekday_iso,t.active_from,t.active_until)
 ) INTO time_block;

 SELECT EXISTS (
  SELECT 1 FROM airlinerra_game.section5_airport_time_restrictions_v1 t
  WHERE t.world_id=p_world_id AND t.airport_key=p_airport_key
   AND (t.rule_kind='NIGHT_QUOTA_OR_RESTRICTION' OR NOT t.game_auto_enforcement OR NOT t.prohibit_normal_scheduled)
   AND t.affected_operations IN('both',CASE WHEN p_operation='arrival' THEN 'arrivals' ELSE 'departures' END)
   AND (t.applies_aircraft_use_types IS NULL OR aircraft_row.use_type=ANY(t.applies_aircraft_use_types))
   AND airlinerra_game.section5_local_restriction_window_match_v1(
      local_dt,t.local_start,t.local_end,t.weekday_iso,t.active_from,t.active_until)
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
        normal_use.reported_status AS normal_use_reported_status,
        normal_use.evidence_url AS normal_use_evidence_url,
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
 LEFT JOIN airlinerra_game.airport_runway_source_status_evidence normal_use
   ON normal_use.world_id=i.world_id
  AND normal_use.airport_key=i.airport_key
  AND normal_use.source_runway_id=i.source_runway_id
  AND normal_use.evidence_provenance LIKE 'OFFICIAL_AIP_NORMAL_RUNWAY_USE:%'
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
           -- Where the official AIP differentiates routine and alternate
           -- runway use, prefer the routine runway for a default proposal.
           -- A longer alternate runway is NOT automatically available.
           CASE normal_use.reported_status
             WHEN 'open_reported_unverified' THEN 1
             WHEN 'restricted_reported_unverified' THEN -1
             ELSE 0 END DESC,
           i.length_m DESC
 LIMIT 1;

 has_runway := chosen.source_runway_id IS NOT NULL;
 runway_block := has_runway AND
                 (coalesce(chosen.rule_blocked,false) OR
                  (NOT estimated_reference AND NOT coalesce(chosen.long_enough,false)));
 runway_review := NOT has_runway OR estimated_reference OR required_m IS NULL
   OR chosen.operational_status IS DISTINCT FROM 'operational'
   OR coalesce(chosen.runway_rule_review,false)
   OR chosen.normal_use_reported_status='restricted_reported_unverified';
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
   'selectedRunwayNormalUseEvidence',chosen.normal_use_reported_status,
   'selectedRunwayNormalUseSource',chosen.normal_use_evidence_url,
   'alternateRunwayNeedsMainClosureEvidence',
       coalesce(chosen.normal_use_reported_status='restricted_reported_unverified',false),
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
;
