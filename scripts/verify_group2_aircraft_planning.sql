-- Airlinerra Group 2: repeatable research/game-planning acceptance checks.
-- Run as the database owner in the Airlinerra Supabase SQL Editor.
-- No images are assessed here: artwork is an independent workstream.
-- No assertion authorizes flight operations, purchases, or real-world dispatch.
DO $group2_audit$
DECLARE n bigint;
BEGIN
  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2;
  IF n<>47 THEN RAISE EXCEPTION 'Group 2 expected 47 configurations, found %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2_conservative_flight_envelope_v1;
  IF n<>47 THEN RAISE EXCEPTION 'Fuel/mass planning envelope coverage is % instead of 47',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  JOIN airlinerra.aircraft_simple_fuel_profiles f ON f.configuration_id=g.configuration_id;
  IF n<>47 THEN RAISE EXCEPTION 'Fuel profiles missing or duplicated: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  JOIN airlinerra.aircraft_game_fuel_distance_rates f ON f.configuration_id=g.configuration_id;
  IF n<>47 THEN RAISE EXCEPTION 'Fuel distance rates missing or duplicated: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra_game.section5_aircraft_airport_runway_screen_v1 s
  JOIN airlinerra.aircraft_expansion_group2 g ON g.configuration_id=s.configuration_id;
  IF n<>147627 THEN RAISE EXCEPTION 'Runway v1 expected 147627 rows, found %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 s
  JOIN airlinerra.aircraft_expansion_group2 g ON g.configuration_id=s.configuration_id;
  IF n<>147627 THEN RAISE EXCEPTION 'Full weight runway v2 expected 147627 rows, found %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 s
  JOIN airlinerra.aircraft_technical_specs t ON t.configuration_id=s.configuration_id AND t.spec_label='base'
  WHERE s.configuration_id IN (SELECT configuration_id FROM airlinerra.aircraft_expansion_group2)
    AND (
      s.full_weight_takeoff_required_m<>CEIL(s.base_full_weight_takeoff_m*s.elevation_factor)
      OR s.full_weight_landing_required_m<>CEIL(s.base_full_weight_landing_m*s.elevation_factor)
      OR s.aircraft_mtow_kg<>t.maximum_takeoff_weight_kg
      OR s.aircraft_mlw_kg<>t.maximum_landing_weight_kg
      OR s.full_weight_both_length_pass IS DISTINCT FROM
        (s.full_weight_takeoff_length_pass AND s.full_weight_landing_length_pass)
    );
  IF n<>0 THEN RAISE EXCEPTION 'Runway/mass/formula inconsistency rows: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra_game.section5_group2_airport_aircraft_readiness_v1;
  IF n<>147627 THEN RAISE EXCEPTION 'Combined Group 2 runway/noise/weight readiness rows: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra_game.section5_group2_airport_aircraft_readiness_v1
  WHERE can_order_and_dispatch_on_certified_basis OR advance_order_enabled OR game_release_automatically_authorized;
  IF n<>0 THEN RAISE EXCEPTION 'UNAUTHORIZED GROUP 2 RELEASE FLAGS: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  JOIN airlinerra_game.section5_aircraft_representative_noise_baseline_v1 n ON n.configuration_id=g.configuration_id
  WHERE n.game_chapter_assumption IS NOT NULL;
  IF n<>47 THEN RAISE EXCEPTION 'Missing provisional game noise classifications: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  JOIN airlinerra.aircraft_expansion_group2_noise_audit a ON a.entry_no=g.entry_no
  JOIN airlinerra_game.section5_icao_aircraft_certification_v2 c ON c.configuration_id=g.configuration_id
  WHERE a.source_confirmed_icao_chapter IS NOT NULL AND
        c.official_icao_chapter IS DISTINCT FROM a.source_confirmed_icao_chapter;
  IF n<>0 THEN RAISE EXCEPTION 'Verified noise chapters inconsistent with central table: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2_conservative_flight_envelope_v1
  WHERE conservative_reference_payload_range_km<=0 OR approved_for_flight_operations;
  IF n<>0 THEN RAISE EXCEPTION 'Invalid mass/fuel game range or illegal operation approval: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  CROSS JOIN LATERAL airlinerra.aircraft_expansion_group2_plan_mission_v1(g.configuration_id,1000000,0) x
  WHERE x.planning_screen_pass;
  IF n<>0 THEN RAISE EXCEPTION 'Impossible 1,000,000 km missions incorrectly accepted: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  CROSS JOIN LATERAL airlinerra.aircraft_expansion_group2_plan_mission_v1(
     g.configuration_id,100,
     (SELECT planning_structural_payload_ceiling_kg+1
      FROM airlinerra.aircraft_expansion_group2_conservative_flight_envelope_v1 e
      WHERE e.configuration_id=g.configuration_id)) x
  WHERE x.planning_screen_pass;
  IF n<>0 THEN RAISE EXCEPTION 'Over-structural payload flights incorrectly accepted: %',n; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2 g
  CROSS JOIN LATERAL airlinerra.aircraft_expansion_group2_plan_mission_v1(g.configuration_id,500,3000) x
  WHERE g.entry_no=37 AND x.planning_screen_pass;
  IF n<>0 THEN RAISE EXCEPTION 'Unverified Y-12F 3t cargo flight was accepted'; END IF;


  SELECT count(*) INTO n
  FROM airlinerra.aircraft_expansion_group2_unified_game_data_v1
  WHERE has_full_modelled_game_section_data IS TRUE;
  IF n<>47 THEN RAISE EXCEPTION 'All-sections Group 2 data must cover 47 aircraft; found %',n; END IF;

  SELECT count(*) INTO n
  FROM airlinerra.aircraft_expansion_group2_unified_game_data_v1
  WHERE effective_game_icao_noise_chapter IS NULL
     OR claimed_or_published_max_range_km IS NULL
     OR game_reference_payload_range_km IS NULL
     OR selected_engine IS NULL
     OR game_usable_fuel_kg IS NULL
     OR game_cruise_burn_kg_per_hour IS NULL
     OR game_full_weight_takeoff_distance_m IS NULL
     OR game_full_weight_landing_distance_m IS NULL;
  IF n<>0 THEN RAISE EXCEPTION 'Missing effective provisional per-aircraft game data on % models',n; END IF;

  SELECT count(*) INTO n
  FROM airlinerra.aircraft_expansion_group2_unified_game_data_v1
  WHERE claimed_max_range_is_game_fallback
    AND (range_source_class IS DISTINCT FROM 'estimate' OR
       claimed_or_published_max_range_km IS DISTINCT FROM original_catalog_planning_range_km);
  IF n<>0 THEN RAISE EXCEPTION 'Unlabeled/mismatched published-range fallback on % models',n; END IF;

  SELECT count(*) INTO n
  FROM airlinerra.aircraft_expansion_group2_unified_game_data_v1
  WHERE entry_no=35 AND game_usable_fuel_kg=1230 AND game_reference_payload_range_km=382;
  IF n<>1 THEN RAISE EXCEPTION 'Y-12E manufacturer fuel-mass/full-load range correction missing'; END IF;

  SELECT count(*) INTO n
  FROM airlinerra.aircraft_expansion_group2_unified_game_data_v1
  WHERE entry_no=9 AND game_usable_fuel_liters=63216 AND game_usable_fuel_kg=50573;
  IF n<>1 THEN RAISE EXCEPTION '767-200 ABX operator fuel-capacity correction missing'; END IF;

  SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group2_unified_game_data_v1
  WHERE entry_no=18 AND max_landing_mass_kg=6600 AND max_zero_fuel_mass_kg=6000;
  IF n<>1 THEN RAISE EXCEPTION 'Jetstream 31 UK CAA Series 3100 basic weight correction missing'; END IF;

  IF has_function_privilege('anon','airlinerra.aircraft_expansion_group2_plan_mission_v1(bigint,numeric,numeric)','EXECUTE')
   OR has_function_privilege('authenticated','airlinerra.aircraft_expansion_group2_plan_mission_v1(bigint,numeric,numeric)','EXECUTE')
  THEN RAISE EXCEPTION 'Research mission planner is exposed to client roles'; END IF;
END $group2_audit$;

SELECT 'GROUP2_RESEARCH_PLANNING_TESTS_PASSED' AS result;
