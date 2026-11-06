-- All approved World 1 airports receive source-labelled research and game rule summaries.
-- A positive research screen is NOT an enforceable blanket ban.
CREATE OR REPLACE VIEW airlinerra_game.section5_airport_game_restriction_catalog_v1
WITH (security_invoker=true) AS
SELECT a.world_id,
    a.airport_key,
    a.airport_code,
    p.timezone_iana,
    b.curfew_result AS operating_condition_screen,
    b.curfew_rule_summary AS operating_research_note,
    b.curfew_source_url AS operating_research_source,
    b.curfew_checked_on AS operating_research_checked,
    b.chapter_result AS noise_condition_screen,
    b.chapter_rule_summary AS noise_research_note,
    b.chapter_source_url AS noise_research_source,
    b.chapter_checked_on AS noise_research_checked,
    c.research_status AS certified_airport_chapter_rule_status,
    c.documented_prohibited_chapters,
    COALESCE(t.total_rules, 0) AS total_time_rules,
    COALESCE(t.enforced_rules, 0) AS enforced_time_rules,
    COALESCE(t.review_rules, 0) AS review_only_time_rules,
    COALESCE(t.time_rule_details, '[]'::jsonb) AS time_rule_details,
    COALESCE(r.total_rules, 0) AS total_runway_rules,
    COALESCE(r.enforced_rules, 0) AS enforced_runway_rules,
    COALESCE(r.runway_rule_details, '[]'::jsonb) AS runway_rule_details,
        CASE
            WHEN (COALESCE(t.enforced_rules, 0) + COALESCE(r.enforced_rules, 0)) > 0 THEN 'MANDATORY_GAME_RULES_PRESENT'::text
            WHEN b.curfew_result = 'YES'::text OR b.chapter_result = 'YES'::text THEN 'RESEARCH_CONDITIONS_REQUIRE_SPECIFIC_RULE_REVIEW'::text
            WHEN b.curfew_source_url IS NOT NULL OR b.chapter_source_url IS NOT NULL THEN 'SOURCE_SCREENED_GAME_DEFAULT_NO_EXTRA_BAN'::text
            ELSE 'PROVISIONAL_GAME_DEFAULT_NO_EXTRA_BAN'::text
        END AS game_restriction_status,
    b.curfew_result = 'YES'::text AND (COALESCE(t.total_rules, 0) + COALESCE(r.total_rules, 0)) = 0 AS time_research_still_unstructured,
    false AS real_world_dispatch_approval
   FROM airlinerra_game.approved_game_airports a
     JOIN airlinerra_game.section5_airport_batch50_screen_v1 b USING (world_id, airport_key)
     JOIN airlinerra_game.section5_airport_operating_policy_v1 p USING (world_id, airport_key)
     JOIN airlinerra_game.section5_airport_icao_chapter_policy_v2 c USING (world_id, airport_key)
     LEFT JOIN LATERAL ( SELECT count(*)::integer AS total_rules,
            count(*) FILTER (WHERE z.game_auto_enforcement AND z.prohibit_normal_scheduled)::integer AS enforced_rules,
            count(*) FILTER (WHERE NOT (z.game_auto_enforcement AND z.prohibit_normal_scheduled))::integer AS review_rules,
            COALESCE(jsonb_agg(jsonb_build_object('code', z.rule_code, 'kind', z.rule_kind, 'operation', z.affected_operations, 'startLocal', to_char(z.local_start::interval, 'HH24:MI'::text), 'endLocal', to_char(z.local_end::interval, 'HH24:MI'::text), 'weekdays', z.weekday_iso, 'aircraftUseTypes', z.applies_aircraft_use_types, 'activeFrom', z.active_from, 'activeUntil', z.active_until, 'hardBlock', z.game_auto_enforcement AND z.prohibit_normal_scheduled, 'exceptionsExpected', z.exceptions_expected, 'notes', z.evidence_note, 'source', z.source_url) ORDER BY z.local_start, z.rule_code), '[]'::jsonb) AS time_rule_details
           FROM airlinerra_game.section5_airport_time_restrictions_v1 z
          WHERE z.world_id = a.world_id AND z.airport_key = a.airport_key) t ON true
     LEFT JOIN LATERAL ( SELECT count(*)::integer AS total_rules,
            count(*) FILTER (WHERE rr.enforce_in_game)::integer AS enforced_rules,
            COALESCE(jsonb_agg(jsonb_build_object('code', rr.rule_code, 'kind', rr.rule_kind, 'operation', rr.affected_operation, 'runwaySourceId', rr.source_runway_id, 'runwayDesignator', i.runway_designator, 'startLocal', to_char(rr.local_start::interval, 'HH24:MI'::text), 'endLocal', to_char(rr.local_end::interval, 'HH24:MI'::text), 'weekdays', rr.weekday_iso, 'activeFrom', rr.active_from, 'activeUntil', rr.active_until, 'prohibitedChapters', rr.prohibited_icao_chapters, 'hardBlock', rr.enforce_in_game, 'notes', rr.evidence_note, 'source', rr.source_url) ORDER BY rr.source_runway_id, rr.rule_code), '[]'::jsonb) AS runway_rule_details
           FROM airlinerra_game.section5_runway_specific_restrictions_v1 rr
             LEFT JOIN airlinerra_game.airport_runway_inventory i ON i.world_id = rr.world_id AND i.airport_key = rr.airport_key AND i.source_runway_id = rr.source_runway_id
          WHERE rr.world_id = a.world_id AND rr.airport_key = a.airport_key) r ON true
  WHERE a.world_id = 1;
REVOKE ALL ON airlinerra_game.section5_airport_game_restriction_catalog_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section5_airport_game_restriction_catalog_v1 IS 'All 3141 approved airports: game rules and research-only conditions separately classified. No real-world dispatch permission.';
