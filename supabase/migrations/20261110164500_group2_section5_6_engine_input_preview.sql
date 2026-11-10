-- Shared engine-input preview for Group 2. Information only: NEVER grants location or flight access.
-- Existing Group 1 engines and approval FKs are intentionally left unchanged.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_ENGINE_BRIDGE_PREFLIGHT_FAIL';END IF;
END $$;

CREATE VIEW airlinerra_game.airport_group2_engine_input_preview_v1
WITH (security_invoker=true) AS
SELECT c.world_id,c.airport_key,c.airport_name,c.game_lookup_code,c.game_category,
 c.timezone_iana,
 c.game_runway_length_m,
 c.game_terminal_stands,c.game_remote_stands,c.game_cargo_stands,
 c.game_terminal_slot_per_10m,c.game_remote_slot_per_10m,c.game_cargo_slot_per_10m,
 p.game_nighttime_ban,p.game_noise_restrictions,p.nighttime_ban_hours,
 p.noise_chapter_rule,p.rule_origin,p.real_world_verified,p.dispatch_authorized,
 p.source_review_status,
 (p.game_nighttime_ban AND nullif(btrim(p.nighttime_ban_hours),'') IS NULL) AS curfew_window_unresolved,
 (p.game_noise_restrictions AND nullif(btrim(p.noise_chapter_rule),'') IS NULL) AS noise_chapter_unresolved,
 (s.airport_key IS NOT NULL) AS existing_slot_engine_entry,
 (o.airport_key IS NOT NULL) AS existing_operating_rules_engine_entry,
 (a.airport_key IS NOT NULL) AS existing_approved_airport_entry,
 (g.commercial_playable AND g.commercial_access_verified AND p.dispatch_authorized) AS declared_commercial_authorization,
 false AS flight_engine_activation_via_preview,
 jsonb_build_array(
  'GROUP2_NOT_ADMITTED',
  'LIVE_SECTION5_RESTRICTION_ENGINE_NOT_INTEGRATED',
  'LIVE_SECTION6_SLOT_ENGINE_NOT_INTEGRATED',
  'LIVE_AIRCRAFT_MOVEMENT_AND_SCHEDULING_FK_NOT_INTEGRATED'
 ) ||
 CASE WHEN p.game_nighttime_ban AND nullif(btrim(p.nighttime_ban_hours),'') IS NULL
  THEN '["NIGHTTIME_HOURS_NOT_STRUCTURED"]'::jsonb ELSE '[]'::jsonb END ||
 CASE WHEN p.game_noise_restrictions AND nullif(btrim(p.noise_chapter_rule),'') IS NULL
  THEN '["NOISE_CHAPTER_RULE_NOT_STRUCTURED"]'::jsonb ELSE '[]'::jsonb END
 AS integration_blockers
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
JOIN airlinerra_game.airport_group2_section5_game_policy_v1 p USING(airport_key)
LEFT JOIN airlinerra_game.section6_airport_slot_capacity_v1 s USING(world_id,airport_key)
LEFT JOIN airlinerra_game.section5_airport_operating_policy_v1 o USING(world_id,airport_key)
LEFT JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key)
WHERE c.source_group='GROUP_2' AND c.world_id=1;
REVOKE ALL ON airlinerra_game.airport_group2_engine_input_preview_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_engine_input_summary_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS prepared_airports,
 count(*) FILTER(WHERE game_runway_length_m>0)::integer AS runway_inputs,
 count(*) FILTER(WHERE game_terminal_slot_per_10m>=0 AND game_remote_slot_per_10m>=0
  AND game_cargo_slot_per_10m>=0)::integer AS stand_capacity_inputs,
 count(*) FILTER(WHERE game_nighttime_ban IS NOT NULL AND game_noise_restrictions IS NOT NULL)::integer AS game_restriction_flags,
 count(*) FILTER(WHERE curfew_window_unresolved)::integer AS curfew_window_unresolved,
 count(*) FILTER(WHERE noise_chapter_unresolved)::integer AS noise_chapter_unresolved,
 count(*) FILTER(WHERE existing_slot_engine_entry)::integer AS existing_slot_engine_entries,
 count(*) FILTER(WHERE existing_operating_rules_engine_entry)::integer AS existing_rules_engine_entries,
 count(*) FILTER(WHERE existing_approved_airport_entry)::integer AS approved_airport_entries,
 count(*) FILTER(WHERE declared_commercial_authorization)::integer AS declared_authorized,
 false AS operational_hq_activation,
 false AS operational_hub_activation,
 false AS operational_station_activation,
 false AS commercial_flights_released
FROM airlinerra_game.airport_group2_engine_input_preview_v1;
REVOKE ALL ON airlinerra_game.airport_group2_engine_input_summary_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT prepared_airports FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>1118
 OR (SELECT runway_inputs FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>1118
 OR (SELECT stand_capacity_inputs FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>1118
 OR (SELECT game_restriction_flags FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>1118
 OR (SELECT existing_slot_engine_entries FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>0
 OR (SELECT existing_rules_engine_entries FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>0
 OR (SELECT approved_airport_entries FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>0
 OR (SELECT declared_authorized FROM airlinerra_game.airport_group2_engine_input_summary_v1)<>0
 THEN RAISE EXCEPTION 'GROUP2_ENGINE_BRIDGE_POSTCHECK_FAIL';END IF;
END $$;