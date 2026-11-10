-- Unify Group 1 and Group 2 airports for Sections 1-8 GAME-DATA consumption only.
-- Do not modify approved_game_airports, activation, releases, flight slots or world state.
-- Group2 source provenance and operational holds remain in their original tables.

DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1) <> 3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1) <> 1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
   JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key) WHERE a.world_id=1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
   JOIN airlinerra_game.airport_group2_game_profiles_v1 g
      ON upper(a.airport_code)=upper(g.source_ident)
   WHERE a.world_id=1 AND a.airport_code IS NOT NULL)
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section1_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section2_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section3_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section4_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section5_game_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section6_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section7_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT game_data_result FROM airlinerra_game.airport_group2_section8_overall_status_v1)<>'game_complete_estimated'
 OR (SELECT count(*) FROM airlinerra_game.airport_reference_profiles r JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_facilities f JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.section5_airport_operating_policy_v1 p JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.section6_airport_slot_capacity_v1 s JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_daily_traffic_pool_baselines t JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_seasonal_demand_profiles s JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_game_fees f JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.section8_airport_operating_tariffs_v1 f JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key) WHERE a.world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'COMBINED_SECTION1_8_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE TABLE airlinerra_game.airport_sections1_8_combined_members_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 source_group text NOT NULL CHECK(source_group IN ('GROUP_1','GROUP_2')),
 game_data_status text NOT NULL CHECK(game_data_status IN ('game_complete_estimated')),
 commercial_access_scope text NOT NULL CHECK(commercial_access_scope IN
    ('EXISTING_GROUP1_APPROVAL','GROUP2_PREPARED_NOT_ADMITTED')),
 created_on date NOT NULL DEFAULT DATE '2026-11-10',
 PRIMARY KEY(world_id,airport_key),
 CHECK((source_group='GROUP_1' AND commercial_access_scope='EXISTING_GROUP1_APPROVAL')
    OR(source_group='GROUP_2' AND commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'))
);
INSERT INTO airlinerra_game.airport_sections1_8_combined_members_v1
(world_id,airport_key,source_group,game_data_status,commercial_access_scope)
SELECT 1,airport_key,'GROUP_1','game_complete_estimated','EXISTING_GROUP1_APPROVAL'
FROM airlinerra_game.approved_game_airports WHERE world_id=1
UNION ALL
SELECT 1,airport_key,'GROUP_2','game_complete_estimated','GROUP2_PREPARED_NOT_ADMITTED'
FROM airlinerra_game.airport_group2_game_profiles_v1;

ALTER TABLE airlinerra_game.airport_sections1_8_combined_members_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_sections1_8_combined_members_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_sections1_8_combined_catalog_v1
WITH (security_invoker=true) AS
SELECT m.world_id,m.airport_key,m.source_group,
 a.airport_name AS airport_name,
 coalesce(r.game_display_code,a.airport_code) AS game_lookup_code,
 r.country_iso,
 f.category AS game_category,
 r.latitude_deg,r.longitude_deg,r.timezone_iana,r.game_elevation_ft,
 ar.longest_qualifying_runway_m AS game_runway_length_m,
 ri.longest_runway_observed_m AS sourced_runway_length_m,
 (ar.airport_key LIKE 'FICTIONAL:%') AS runway_is_fictional,
 af.terminal_count AS game_terminal_count,
 s.terminal_stands AS game_terminal_stands,
 s.remote_stands AS game_remote_stands,
 s.cargo_stands AS game_cargo_stands,
 s.terminal_per_direction_10m AS game_terminal_slot_per_10m,
 s.remote_per_direction_10m AS game_remote_slot_per_10m,
 s.cargo_per_direction_10m AS game_cargo_slot_per_10m,
 p.curfew_identified AS game_nighttime_ban,
 (p.max_day_game_noise_class IS NOT NULL AND p.max_day_game_noise_class < 4) AS game_noise_restrictions,
 p.operating_hours_basis AS restriction_basis,
 t.avg_daily_outbound_passengers AS game_daily_outbound_passengers,
 t.avg_daily_outbound_cargo_tonnes AS game_daily_outbound_cargo_tonnes,
 sd.profile AS game_season_profile,
 f.landing_fee_usd AS game_landing_fee_usd,
 f.parking_per_day_usd AS game_parking_per_day_usd,
 f.departing_passenger_fee_usd AS game_departing_pax_fee_usd,
 m.game_data_status,m.commercial_access_scope,
 (m.source_group='GROUP_1') AS existing_group1_approval,
 false AS group2_activated_by_merge,
 jsonb_build_object('section1',to_jsonb(r),
  'section2',jsonb_build_object('category',f.category,'category_basis',f.pricing_basis),
  'section3',jsonb_build_object('registry',to_jsonb(ar),'fictional_runway',to_jsonb(fr)),
  'section4',to_jsonb(af),
  'section5',to_jsonb(p),
  'section6',to_jsonb(s),
  'section7',jsonb_build_object('traffic',to_jsonb(t),'seasonality',to_jsonb(sd)),
  'section8',jsonb_build_object('fees',to_jsonb(f),'tariffs',to_jsonb(et))) AS section_1_8_source_data
FROM airlinerra_game.airport_sections1_8_combined_members_v1 m
JOIN airlinerra_game.approved_game_airports a USING(world_id,airport_key)
JOIN airlinerra_game.airport_reference_profiles r USING(world_id,airport_key)
JOIN airlinerra.airport_registry ar USING(airport_key)
LEFT JOIN airlinerra_game.airport_fictional_runway_design fr USING(world_id,airport_key)
JOIN airlinerra_game.airport_facilities af USING(world_id,airport_key)
JOIN airlinerra_game.section5_airport_operating_policy_v1 p USING(world_id,airport_key)
JOIN airlinerra_game.section6_airport_slot_capacity_v1 s USING(world_id,airport_key)
JOIN airlinerra_game.airport_daily_traffic_pool_baselines t USING(world_id,airport_key)
JOIN airlinerra_game.airport_seasonal_demand_profiles sd USING(world_id,airport_key)
JOIN airlinerra_game.airport_game_fees f USING(world_id,airport_key)
JOIN airlinerra_game.section8_airport_operating_tariffs_v1 et USING(world_id,airport_key)
LEFT JOIN airlinerra_game.airport_reference_profiles ri USING(world_id,airport_key)
WHERE m.source_group='GROUP_1'
UNION ALL
SELECT m.world_id,m.airport_key,m.source_group,
 g.game_airport_name,g.game_lookup_code,g.country_iso,g.owner_category,
 g.latitude_deg,g.longitude_deg,g.timezone_iana,g.game_elevation_ft,
 g.runway_registry_qualified_length_m,g.longest_detail_length_m,
 false,
 g.game_terminal_count,g.game_terminal_stands,g.game_remote_stands,g.game_cargo_stands,
 g.game_terminal_slot_per_10m,g.game_remote_slot_per_10m,g.game_cargo_slot_per_10m,
 gp.game_nighttime_ban,gp.game_noise_restrictions,gp.rule_origin,
 g.game_daily_outbound_passengers,g.game_daily_outbound_cargo_tonnes,g.game_season_profile,
 g.game_landing_fee_usd,g.game_parking_per_day_usd,g.game_departing_pax_fee_usd,
 m.game_data_status,m.commercial_access_scope,
 false,false,
 jsonb_build_object('section1',to_jsonb(i),
  'section2',to_jsonb(c),
  'section3',to_jsonb(rw),
  'section4',to_jsonb(fac),
  'section5',to_jsonb(gp),
  'section6',to_jsonb(cap),
  'section7',to_jsonb(dem),
  'section8',to_jsonb(eco)) AS section_1_8_source_data
FROM airlinerra_game.airport_sections1_8_combined_members_v1 m
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
JOIN airlinerra_game.airport_group2_section5_game_policy_v1 gp USING(airport_key)
JOIN airlinerra_game.airport_group2_section1_identity_v1 i USING(airport_key)
JOIN airlinerra_game.airport_group2_section2_classification_v1 c USING(airport_key)
JOIN airlinerra_game.airport_group2_section3_runways_v1 rw USING(airport_key)
JOIN airlinerra_game.airport_group2_section4_facilities_v1 fac USING(airport_key)
JOIN airlinerra_game.airport_group2_section6_capacity_v1 cap USING(airport_key)
JOIN airlinerra_game.airport_group2_section7_demand_v1 dem USING(airport_key)
JOIN airlinerra_game.airport_group2_section8_economics_v1 eco USING(airport_key)
WHERE m.source_group='GROUP_2';
REVOKE ALL ON airlinerra_game.airport_sections1_8_combined_catalog_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_sections1_8_combined_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS total_airports,
 count(*) FILTER(WHERE source_group='GROUP_1')::integer AS group1_airports,
 count(*) FILTER(WHERE source_group='GROUP_2')::integer AS group2_airports,
 count(*) FILTER(WHERE game_data_status='game_complete_estimated')::integer AS complete_section1_8_airports,
 count(*) FILTER(WHERE game_lookup_code IS NULL OR country_iso IS NULL
 OR game_category IS NULL OR latitude_deg IS NULL OR longitude_deg IS NULL
 OR timezone_iana IS NULL OR game_elevation_ft IS NULL
 OR game_runway_length_m IS NULL OR game_runway_length_m<=0
 OR game_terminal_stands IS NULL OR game_remote_stands IS NULL OR game_cargo_stands IS NULL
 OR game_terminal_slot_per_10m IS NULL OR game_remote_slot_per_10m IS NULL
 OR game_cargo_slot_per_10m IS NULL
 OR game_nighttime_ban IS NULL OR game_noise_restrictions IS NULL
 OR game_daily_outbound_passengers IS NULL OR game_daily_outbound_cargo_tonnes IS NULL
 OR game_season_profile IS NULL OR game_landing_fee_usd IS NULL
 OR game_parking_per_day_usd IS NULL OR game_departing_pax_fee_usd IS NULL)::integer AS incomplete_shared_game_fields,
 count(*) FILTER(WHERE source_group='GROUP_2' AND group2_activated_by_merge)::integer AS group2_activated,
 false AS automatic_flight_activation
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1;
REVOKE ALL ON airlinerra_game.airport_sections1_8_combined_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT total_airports FROM airlinerra_game.airport_sections1_8_combined_status_v1)<>4259
 OR (SELECT group1_airports FROM airlinerra_game.airport_sections1_8_combined_status_v1)<>3141
 OR (SELECT group2_airports FROM airlinerra_game.airport_sections1_8_combined_status_v1)<>1118
 OR (SELECT incomplete_shared_game_fields FROM airlinerra_game.airport_sections1_8_combined_status_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'COMBINED_SECTION1_8_POSTCHECK_FAILED';END IF;
END $$;