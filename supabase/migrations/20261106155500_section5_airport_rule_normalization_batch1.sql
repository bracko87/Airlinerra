-- Applied and verified against Airlinerra World 1 on 2026-11-06.
-- Synchronizes sourced operational research to carefully scoped game rules, not general aviation dispatch clearance.
-- 21 airport time/permission records at 20 airports + Goa runway closure; 16 are REVIEW-ONLY.
-- Live scheduler activation is not implemented or authorized.

ALTER TABLE airlinerra_game.section5_airport_time_restrictions_v1
 ADD COLUMN IF NOT EXISTS applies_aircraft_use_types text[],
 ADD COLUMN IF NOT EXISTS active_from date,
 ADD COLUMN IF NOT EXISTS active_until date;
DO $constraints$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='airlinerra_game.section5_airport_time_restrictions_v1'::regclass AND conname='section5_time_rule_aircraft_use_types_valid') THEN
  ALTER TABLE airlinerra_game.section5_airport_time_restrictions_v1 ADD CONSTRAINT section5_time_rule_aircraft_use_types_valid CHECK(
    applies_aircraft_use_types IS NULL OR
    (cardinality(applies_aircraft_use_types)>0 AND applies_aircraft_use_types <@ ARRAY['passenger','cargo','combi']::text[]));
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='airlinerra_game.section5_airport_time_restrictions_v1'::regclass AND conname='section5_time_rule_active_period_valid') THEN
  ALTER TABLE airlinerra_game.section5_airport_time_restrictions_v1 ADD CONSTRAINT section5_time_rule_active_period_valid
   CHECK(active_from IS NULL OR active_until IS NULL OR active_from<=active_until);
 END IF;
 ALTER TABLE airlinerra_game.section5_airport_time_restrictions_v1
 DROP CONSTRAINT IF EXISTS section5_airport_time_restrictions_v1_rule_kind_check;
 ALTER TABLE airlinerra_game.section5_airport_time_restrictions_v1
 ADD CONSTRAINT section5_airport_time_restrictions_v1_rule_kind_check
 CHECK(rule_kind IN('CURFEW_SCHEDULED','SCHEDULED_DEPARTURES','SCHEDULED_ARRIVALS','NIGHT_QUOTA_OR_RESTRICTION','PPR_WINDOW','OPERATING_HOURS_REVIEW'));
END $constraints$;

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
 runway_block := has_runway AND
                 (coalesce(chosen.rule_blocked,false) OR
                  (NOT estimated_reference AND NOT coalesce(chosen.long_enough,false)));
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
CREATE OR REPLACE VIEW airlinerra_game.section5_airport_restriction_normalization_queue_v1
WITH (security_invoker=true) AS
 WITH timed AS (
         SELECT section5_airport_time_restrictions_v1.world_id,
            section5_airport_time_restrictions_v1.airport_key,
            count(*)::integer AS structured_time_rules,
            count(*) FILTER (WHERE section5_airport_time_restrictions_v1.game_auto_enforcement AND section5_airport_time_restrictions_v1.prohibit_normal_scheduled)::integer AS hard_time_rules,
            count(*) FILTER (WHERE NOT section5_airport_time_restrictions_v1.game_auto_enforcement OR NOT section5_airport_time_restrictions_v1.prohibit_normal_scheduled)::integer AS review_time_rules
           FROM airlinerra_game.section5_airport_time_restrictions_v1
          GROUP BY section5_airport_time_restrictions_v1.world_id, section5_airport_time_restrictions_v1.airport_key
        ), runway AS (
         SELECT section5_runway_specific_restrictions_v1.world_id,
            section5_runway_specific_restrictions_v1.airport_key,
            count(*)::integer AS structured_runway_rules,
            count(*) FILTER (WHERE section5_runway_specific_restrictions_v1.enforce_in_game)::integer AS hard_runway_rules
           FROM airlinerra_game.section5_runway_specific_restrictions_v1
          GROUP BY section5_runway_specific_restrictions_v1.world_id, section5_runway_specific_restrictions_v1.airport_key
        )
 SELECT b.world_id,
    b.airport_key,
    b.airport_code,
    b.airport_name,
    b.country_iso,
    b.batch_no,
    b.curfew_rule_summary AS research_description,
    b.curfew_source_url AS source_url,
    b.curfew_checked_on AS source_checked_on,
    array_remove(ARRAY[
        CASE
            WHEN b.curfew_rule_summary ~* '(RWY|runway|runway-specific)'::text THEN 'RUNWAY_OR_DIRECTION_SPECIFIC'::text
            ELSE NULL::text
        END,
        CASE
            WHEN b.curfew_rule_summary ~* '(chapter[[:space:]]*[234]|noisy aircraft|aircraft.weight|EPN|QC[[:space:]]|MTOW)'::text THEN 'AIRCRAFT_OR_NOISE_DEPENDENT'::text
            ELSE NULL::text
        END,
        CASE
            WHEN b.curfew_rule_summary ~* '(quota|slot|movement cap|annual limit)'::text THEN 'QUOTA_OR_SLOTS'::text
            ELSE NULL::text
        END,
        CASE
            WHEN b.curfew_rule_summary ~* '(PPR|prior permission|prior approval|on request|out.of.hours|advance notice)'::text THEN 'PERMISSION_OR_SERVICES'::text
            ELSE NULL::text
        END,
        CASE
            WHEN b.curfew_rule_summary ~* '(season|summer|winter|NOTAM|temporary|2027|valid until)'::text THEN 'SEASONAL_TEMPORARY_OR_FUTURE'::text
            ELSE NULL::text
        END,
        CASE
            WHEN b.curfew_rule_summary ~* '(opening hours|operating hours|airport hours|AD2.3|AD 2.3|airport service)'::text THEN 'AERODROME_OPERATING_HOURS'::text
            ELSE NULL::text
        END], NULL::text) AS research_tags_for_review,
    COALESCE(t.structured_time_rules, 0) AS structured_time_rules,
    COALESCE(t.hard_time_rules, 0) AS active_hard_time_rules,
    COALESCE(t.review_time_rules, 0) AS review_only_time_rules,
    COALESCE(r.structured_runway_rules, 0) AS structured_runway_rules,
    COALESCE(r.hard_runway_rules, 0) AS active_hard_runway_rules,
        CASE
            WHEN (COALESCE(t.structured_time_rules, 0) + COALESCE(r.structured_runway_rules, 0)) = 0 THEN 'RESEARCH_ONLY_RULE_NORMALIZATION_PENDING'::text
            WHEN (COALESCE(t.hard_time_rules, 0) + COALESCE(r.hard_runway_rules, 0)) > 0 THEN 'SOME_HARD_RULES_STRUCTURED_CHECK_OTHER_CONDITIONS'::text
            ELSE 'SOME_REVIEW_RULES_STRUCTURED_CHECK_OTHER_CONDITIONS'::text
        END AS normalization_status,
    'No automatic ban may be inferred from this research queue or tags alone; enforce only precise independently reviewed active rules.'::text AS rule_release_caution
   FROM airlinerra_game.section5_airport_batch50_screen_v1 b
     LEFT JOIN timed t USING (world_id, airport_key)
     LEFT JOIN runway r USING (world_id, airport_key)
  WHERE b.world_id = 1 AND b.curfew_result = 'YES'::text;
REVOKE ALL ON airlinerra_game.section5_airport_restriction_normalization_queue_v1 FROM PUBLIC,anon,authenticated;

WITH curated(airport_code,rule_code,rule_kind,affected_operations,local_start,local_end,weekday_iso,
prohibit_normal_scheduled,game_auto_enforcement,exceptions_expected,evidence_authority,evidence_note,
applies_aircraft_use_types,active_from,active_until) AS (
 VALUES
('ACE','LANZAROTE_OUTSIDE_PUBLISHED_AD_HOURS','OPERATING_HOURS_REVIEW','both','01:00:00'::time,'07:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','ENAIRE airport hours summer 06:00-00:00 UTC/winter 07:00-01:00 UTC => 07:00-01:00 local; out-of-hours permission/NOTAM and scope require review, not a hard legal aircraft ban.',NULL::text[],NULL::date,NULL::date),
('AOJ','AOMORI_OUTSIDE_GOVERNOR_OPERATING_HOURS','PPR_WINDOW','both','22:00:00'::time,'07:30:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Aomori prefecture ordinance: airfield use outside 07:30-22:00 local requires governor permission; REVIEW, not automatic prohibition for flights with approved exception.',NULL::text[],NULL::date,NULL::date),
('AUA','ARUBA_REGULAR_COMMERCIAL_OUTSIDE_HOURS','CURFEW_SCHEDULED','both','23:00:00'::time,'07:00:00'::time,NULL::smallint[],true,true,true,'AUTHORITY_OR_AIRPORT_DIRECT_SOURCE_REVIEWED_2026','Current 2026 Aruba eAIP TNCA AD2.3: outside 07:00-23:00 local only exempt authority-coordinated military/Coast Guard/SAR/medevac/humanitarian operations; blocks ordinary scheduled commercial flights, not emergency exceptions.',NULL::text[],NULL::date,NULL::date),
('BIO','BILBAO_OUTSIDE_PUBLISHED_AD_HOURS','PPR_WINDOW','both','23:30:00'::time,'06:45:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','ENAIRE 2026 AIP: airport V 04:45-21:30 UTC and I 05:45-22:30 UTC => 06:45-23:30 local; up to 70min prior permission extension. REVIEW, not hard ban.',NULL::text[],NULL::date,NULL::date),
('BZO','BOLZANO_OUTSIDE_OPERATOR_AIRPORT_HOURS','OPERATING_HOURS_REVIEW','both','23:00:00'::time,'06:30:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Airport operator publishes 06:30-23:00 local AIRPORT operating hours; confirm AIP/NOTAM and exception before any hard ban.',NULL::text[],NULL::date,NULL::date),
('CJA','CAJAMARCA_OUTSIDE_OPERATOR_HOURS','OPERATING_HOURS_REVIEW','both','18:00:00'::time,'05:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Airport operator hours 05:00-18:00 local; airfield/terminal distinction and any out-of-hours flight permission require AIP or NOTAM; REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('CRL','CHARLEROI_NORMAL_SCHEDULE_OUTSIDE_0630_2300','CURFEW_SCHEDULED','both','23:00:00'::time,'06:30:00'::time,NULL::smallint[],true,true,true,'AUTHORITY_OR_AIRPORT_DIRECT_SOURCE_REVIEWED_2026','Walloon and Charleroi authority: standard airport flight window 06:30-23:00; late based-aircraft delayed arrivals and emergencies may receive exceptions, not normal advance scheduled service.',NULL::text[],NULL::date,NULL::date),
('FSC','FIGARI_OUTSIDE_ALLOCATED_SLOTS_HOURS','OPERATING_HOURS_REVIEW','both','22:59:00'::time,'06:45:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','COHOR published 06:45-22:59 local for slot allocation; ATS/runway permission not the same as slot allocation; REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('GOI','GOA_MILITARY_CIVIL_SCHEDULE_AM','CURFEW_SCHEDULED','both','08:30:00'::time,'12:30:00'::time,ARRAY['1','2','3','4','5']::smallint[],true,true,true,'AUTHORITY_OR_AIRPORT_DIRECT_SOURCE_REVIEWED_2026','AAI Goa VOGO AD2.3: civil scheduled operations forbidden Mon-Fri 03:00-07:00 UTC, India local 08:30-12:30; military slots.',NULL::text[],NULL::date,NULL::date),
('GOI','GOA_MILITARY_CIVIL_SCHEDULE_PM','CURFEW_SCHEDULED','both','15:30:00'::time,'16:30:00'::time,ARRAY['1','2','3','4','5']::smallint[],true,true,true,'AUTHORITY_OR_AIRPORT_DIRECT_SOURCE_REVIEWED_2026','AAI Goa VOGO AD2.3: civil scheduled operations forbidden Mon-Fri 10:00-11:00 UTC, India local 15:30-16:30; military slots.',NULL::text[],NULL::date,NULL::date),
('GOU','GAROUA_OUTSIDE_AIP_SERVICE_HOURS','PPR_WINDOW','both','21:00:00'::time,'08:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','ASECNA AIP normal service 07:00-20:00 UTC = 08:00-21:00 Douala local; outside-hours operation possible by prior request, REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('GPI','GUAPI_OUTSIDE_OFFICIAL_AERODROME_HOURS','OPERATING_HOURS_REVIEW','both','18:00:00'::time,'06:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Colombian official roster says 11:00-23:00 UTC => 06:00-18:00 local; medevac/AIP/NOTAM exceptions review.',NULL::text[],NULL::date,NULL::date),
('HIJ','HIROSHIMA_OUTSIDE_MLIT_AIRPORT_HOURS','OPERATING_HOURS_REVIEW','both','22:30:00'::time,'07:30:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','MLIT airport operational use 07:30-22:30 local; overtime/NOTAM exceptions to check; not terminal hours.',NULL::text[],NULL::date,NULL::date),
('LEJ','LEIPZIG_PASSENGER_ONLY_NIGHT_CLOSURE','CURFEW_SCHEDULED','both','23:30:00'::time,'05:30:00'::time,NULL::smallint[],true,true,true,'AUTHORITY_OR_AIRPORT_DIRECT_SOURCE_REVIEWED_2026','Official Leipzig/Halle airport: scheduled passenger departure/arrival curfew 23:30-05:30 local; cargo flights are NOT prohibited by this rule. Aircraft configuration use_type passenger is current approximation for service type; combi flight needs passenger-service assessment in activation.',ARRAY['passenger']::text[],NULL::date,NULL::date),
('PNA','PAMPLONA_OUTSIDE_PUBLISHED_AIP_HOURS','PPR_WINDOW','both','23:45:00'::time,'06:30:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','ENAIRE AIP summer 04:30-21:45 UTC/winter 05:30-22:45 UTC convert to 06:30-23:45 local; limited 45-minute extension on PPR. REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('SOD','SOROCABA_OUTSIDE_ROTAER_HOURS','PPR_WINDOW','both','23:00:00'::time,'06:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Brazil DECEA ROTAER 09:00-02:00 UTC => 06:00-23:00 Sao Paulo local; overnight service is possible by prior request. REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('SVQ','SEVILLA_OUTSIDE_PUBLISHED_AIP_HOURS','PPR_WINDOW','both','01:00:00'::time,'06:30:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','ENAIRE summer 04:30-23:00 UTC/winter 05:30-00:00 UTC convert to 06:30-01:00 local; 2h PPR extension can be requested. REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('TAT','POPRAD_TATRY_OUTSIDE_AIRPORT_HOURS','PPR_WINDOW','both','19:00:00'::time,'07:15:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Airport operator hours 07:15-19:00 local; out-of-hours permission possible; REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('USH','USHUAIA_OUTSIDE_AIRPORT_HOURS','OPERATING_HOURS_REVIEW','both','00:00:00'::time,'06:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Airport operator publishes 06:00-midnight Argentina local; AIP/NOTAM and exceptions can supersede; REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('WAE','WADI_AL_DAWASIR_OUTSIDE_AIP_SERVICE_HOURS','OPERATING_HOURS_REVIEW','both','20:00:00'::time,'12:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Saudi AIP airport hours 09:00-17:00 UTC => 12:00-20:00 Riyadh local; non-scheduled PPR and ATS not published; REVIEW ONLY.',NULL::text[],NULL::date,NULL::date),
('YKA','KAMLOOPS_OUTSIDE_OPERATOR_HOURS','OPERATING_HOURS_REVIEW','both','00:30:00'::time,'03:00:00'::time,NULL::smallint[],false,false,true,'SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY','Airport operator daily 03:00-00:30 local; confirm aircraft movement requirements outside published hours; REVIEW ONLY.',NULL::text[],NULL::date,NULL::date)
)
INSERT INTO airlinerra_game.section5_airport_time_restrictions_v1
(world_id,airport_key,airport_code,rule_code,rule_kind,affected_operations,local_start,local_end,
weekday_iso,prohibit_normal_scheduled,game_auto_enforcement,exceptions_expected,source_url,
evidence_authority,evidence_note,evidence_checked_on,applies_aircraft_use_types,active_from,active_until)
SELECT b.world_id,b.airport_key,b.airport_code,x.rule_code,x.rule_kind,x.affected_operations,x.local_start,x.local_end,
x.weekday_iso,x.prohibit_normal_scheduled,x.game_auto_enforcement,x.exceptions_expected,b.curfew_source_url,
x.evidence_authority,x.evidence_note,b.curfew_checked_on,x.applies_aircraft_use_types,x.active_from,x.active_until
FROM curated x JOIN airlinerra_game.section5_airport_batch50_screen_v1 b
ON b.world_id=1 AND b.airport_code=x.airport_code
WHERE b.curfew_result='YES' AND NULLIF(trim(b.curfew_source_url),'') IS NOT NULL
ON CONFLICT(world_id,airport_key,rule_code) DO NOTHING;

INSERT INTO airlinerra_game.section5_runway_specific_restrictions_v1
(world_id,airport_key,source_runway_id,rule_code,rule_kind,affected_operation,local_start,local_end,
weekday_iso,enforce_in_game,source_url,evidence_note,checked_on)
SELECT b.world_id,b.airport_key,r.source_runway_id,'GOA_RUNWAY_08_26_SATURDAY_MAINTENANCE',
'RUNWAY_TIME_CLOSURE','both','07:30:00'::time,'11:30:00'::time,ARRAY['6']::smallint[],true,b.curfew_source_url,
'AAI VOGO AD2.3 and AD2.23: RWY 08/26 closed Saturday 02:00-06:00 UTC (07:30-11:30 Asia/Kolkata) for recurring maintenance. Applies only to documented runway, with other source NOTAMs still separately checked.',b.curfew_checked_on
FROM airlinerra_game.section5_airport_batch50_screen_v1 b JOIN airlinerra_game.airport_runway_inventory r
ON r.world_id=b.world_id AND r.airport_key=b.airport_key
WHERE b.world_id=1 AND b.airport_code='GOI' AND r.runway_designator='08/26' AND r.source_runway_id='236704'
ON CONFLICT(world_id,airport_key,source_runway_id,rule_code) DO NOTHING;

COMMENT ON VIEW airlinerra_game.section5_airport_restriction_normalization_queue_v1 IS
'All positive research condition airports with review tags and partial rule coverage. Research screening does not automatically authorize an airport-wide hard flight curfew.';
