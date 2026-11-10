-- Cross-group game-data inventory. GROUP 2 is a data cohort, NOT "World 2".
-- The 1,118 Group 2 records are intentionally not inserted into the
-- authoritative Group 1 (3,141 World 1) route-admission roster.
CREATE VIEW airlinerra_game.airport_game_cohort_inventory_v1
 WITH (security_invoker=true) AS
SELECT 'GROUP_1'::text AS group_code,
 a.airport_key,a.world_id AS approved_roster_world_id,
 coalesce(nullif(p.game_official_name,''),a.airport_name) AS display_name,
 coalesce(nullif(p.game_display_code,''),a.airport_code) AS game_lookup_code,
 p.country_iso,p.latitude_deg,p.longitude_deg,
 p.provisional_category AS game_category,
 true AS approved_game_roster_member,
 false AS live_flight_authority_verified,
 false AS commercial_playable_now,
 'GROUP1_GAME_DATA_COMPLETE_WORLD1_PLANNED'::text AS catalog_status
FROM airlinerra_game.approved_game_airports a
JOIN airlinerra_game.airport_reference_profiles p
 ON p.world_id=a.world_id AND p.airport_key=a.airport_key
WHERE a.world_id=1
UNION ALL
SELECT 'GROUP_2'::text,g.airport_key,
 NULL::smallint AS approved_roster_world_id,
 g.game_airport_name,g.game_lookup_code,
 g.country_iso,g.latitude_deg,g.longitude_deg,
 g.owner_category,
 false AS approved_game_roster_member,
 false AS live_flight_authority_verified,
 false AS commercial_playable_now,
 'PREAPPROVED_GAME_DATA_ONLY_RESTRICTIONS_PENDING'::text AS catalog_status
FROM airlinerra_game.airport_group2_game_profiles_v1 g;
REVOKE ALL ON airlinerra_game.airport_game_cohort_inventory_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.airport_game_cohort_inventory_v1 IS
 'Private unified Group1 3141 + Group2 1118 = 4259 game-data inventory. Group2 is NOT World2 and has not entered World1 operating roster.';

CREATE VIEW airlinerra_game.airport_group2_progress_v1
 WITH (security_invoker=true) AS
SELECT count(*)::integer AS game_data_airports,
 count(*) FILTER(WHERE owner_category='Local')::integer local_airports,
 count(*) FILTER(WHERE owner_category='Regional')::integer regional_airports,
 count(*) FILTER(WHERE owner_category='Medium')::integer medium_airports,
 count(*) FILTER(WHERE game_traffic_type='Passenger')::integer passenger_intent,
 count(*) FILTER(WHERE game_traffic_type='Cargo')::integer cargo_intent,
 count(*) FILTER(WHERE game_traffic_type='Both')::integer both_intent,
 count(*) FILTER(WHERE source_municipality IS NULL OR btrim(source_municipality)='')::integer missing_source_municipalities,
 count(*) FILTER(WHERE runway_width_game_basis='CATEGORY_MEDIAN_GAME_WIDTH_ESTIMATE')::integer game_width_estimates,
 count(*) FILTER(WHERE detailed_runway_observation_count=0)::integer no_detailed_runways,
 count(*) FILTER(WHERE timezone_game_basis='UA_COUNTRY_GAME_ESTIMATE')::integer ukraine_game_timezone_fallbacks,
 count(*) FILTER(WHERE game_nighttime_ban IS NULL OR game_noise_restrictions IS NULL)::integer unknown_operating_restrictions,
 count(*) FILTER(WHERE commercial_playable)::integer playable_airports
FROM airlinerra_game.airport_group2_game_profiles_v1;
REVOKE ALL ON airlinerra_game.airport_group2_progress_v1
 FROM PUBLIC,anon,authenticated;

DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_game_cohort_inventory_v1)<>4259
 OR (SELECT count(*) FROM airlinerra_game.airport_game_cohort_inventory_v1
  WHERE group_code='GROUP_1' AND approved_game_roster_member)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_game_cohort_inventory_v1
  WHERE group_code='GROUP_2' AND NOT approved_game_roster_member)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_game_cohort_inventory_v1
   WHERE commercial_playable_now OR live_flight_authority_verified)<>0
 THEN RAISE EXCEPTION 'GROUP2_COHORT_INVENTORY_LOST_SEPARATION';END IF;
END $verify$;
