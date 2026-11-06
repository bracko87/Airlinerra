
-- Airlinerra Group 3: research-planning validation for user-approved 39-model catalog.
-- Execute as database owner; research only, no releases or operational permissions.
DO $g3$
DECLARE n bigint;
BEGIN
 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3;
 IF n<>39 THEN RAISE EXCEPTION 'Group 3 must have 39 entries, found %',n; END IF;
 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3
 WHERE variant_id IS NOT NULL AND configuration_id IS NOT NULL;
 IF n<>39 THEN RAISE EXCEPTION 'Group 3 requires 39 variant/configuration links, found %',n; END IF;
 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed;
 IF n<>39 THEN RAISE EXCEPTION '39 aircraft seed planning profiles expected, found %',n; END IF;
 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1
 WHERE has_all_planning_game_sections_populated;
 IF n<>39 THEN RAISE EXCEPTION '39 complete Group 3 game-planning profiles expected, found %',n; END IF;
 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_release_gate_v1;
 IF n<>39 THEN RAISE EXCEPTION '39 release gate records expected, found %',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra.aircraft_simple_fuel_profiles f ON f.configuration_id=g.configuration_id
 JOIN airlinerra.aircraft_game_fuel_distance_rates r ON r.configuration_id=g.configuration_id
 WHERE NOT f.gameplay_enabled AND NOT r.gameplay_enabled;
 IF n<>39 THEN RAISE EXCEPTION 'Missing/duplicated/incorrectly activated fuel profiles: found %',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra.aircraft_configuration_game_rules c ON c.configuration_id=g.configuration_id
 JOIN airlinerra_game.section5_aircraft_representative_engine_v1 e ON e.configuration_id=g.configuration_id
 JOIN airlinerra_game.section5_aircraft_representative_noise_baseline_v1 no ON no.configuration_id=g.configuration_id
 JOIN airlinerra_game.section5_aircraft_noise_profiles_v1 np ON np.configuration_id=g.configuration_id
 JOIN airlinerra_game.section5_icao_aircraft_certification_v2 ic ON ic.configuration_id=g.configuration_id
 WHERE c.simultaneous_maxima_verified=false
 AND no.real_world_noise_operational_permission=false
 AND no.game_chapter_assumption IS NOT NULL
 AND (
     (no.official_icao_chapter IS NULL
      AND ic.official_icao_chapter IS NULL
      AND ic.noise_certificate_status='CERTIFICATE_NOT_VERIFIED')
     OR
     (g.entry_no=1 AND no.official_icao_chapter=14
      AND ic.official_icao_chapter=14
      AND ic.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED'
      AND no.real_world_noise_operational_permission=false
      AND ic.airframe_registration_specific=false)
 );
 IF n<>39 THEN RAISE EXCEPTION '39 research-only engine/noise/loading records including 1 type-certificate match expected, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra_game.section5_icao_aircraft_certification_v2 ic
 ON ic.configuration_id=g.configuration_id
 WHERE ic.official_icao_chapter IS NOT NULL;
 IF n<>1 THEN RAISE EXCEPTION 'Expected 1 matched A340-541 type noise certificate, found %',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3
 WHERE availability_intent='visible_not_orderable' AND entry_no IN(2,20,25);
 IF n<>3 THEN RAISE EXCEPTION 'Three future display-only models must remain locked'; END IF;

 SELECT count(*) INTO n FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 s
 JOIN airlinerra.aircraft_expansion_group3 g ON g.configuration_id=s.configuration_id;
 IF n<>122499 THEN RAISE EXCEPTION 'Group3 full-weight runway screen expected 122499 rows, found %',n; END IF;
 SELECT count(*) INTO n FROM airlinerra_game.section5_aircraft_airport_runway_screen_v1 s
 JOIN airlinerra.aircraft_expansion_group3 g ON g.configuration_id=s.configuration_id;
 IF n<>122499 THEN RAISE EXCEPTION 'Group3 simple runway screen expected 122499 rows, found %',n; END IF;

 SELECT count(*) INTO n FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 s
 JOIN airlinerra.aircraft_expansion_group3 g ON g.configuration_id=s.configuration_id
 JOIN airlinerra.aircraft_technical_specs t ON t.configuration_id=g.configuration_id AND t.spec_label='base'
 WHERE s.aircraft_mtow_kg IS DISTINCT FROM t.maximum_takeoff_weight_kg
 OR s.aircraft_mlw_kg IS DISTINCT FROM t.maximum_landing_weight_kg
 OR s.base_full_weight_takeoff_m IS DISTINCT FROM t.published_takeoff_distance_m
 OR s.base_full_weight_landing_m IS DISTINCT FROM t.published_landing_distance_m
 OR s.full_weight_takeoff_required_m IS DISTINCT FROM ceil(s.base_full_weight_takeoff_m*s.elevation_factor)
 OR s.full_weight_landing_required_m IS DISTINCT FROM ceil(s.base_full_weight_landing_m*s.elevation_factor)
 OR s.full_weight_both_length_pass IS DISTINCT FROM
 (s.full_weight_takeoff_length_pass AND s.full_weight_landing_length_pass)
 OR s.no_real_world_dispatch_certification=false;
 IF n<>0 THEN RAISE EXCEPTION 'Group3 runway weights/formula/dispatch flags are invalid on % records',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_release_gate_v1
 WHERE NOT has_all_planning_game_sections_populated
 OR game_aircraft_orderable OR game_flight_operations_enabled
 OR officially_certified_dispatch OR automatically_released;
 IF n<>0 THEN RAISE EXCEPTION 'Missing data or unauthorized aircraft game release on % records',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1
 WHERE conservative_reference_payload_game_range_km<=0
 OR nominal_model_or_estimated_range_km<=0
 OR provisional_full_weight_takeoff_m<=0
 OR provisional_full_weight_landing_m<=0
 OR nominal_model_or_estimated_range_km IS NULL
 OR provisional_icao_noise_chapter IS NULL;
 IF n<>0 THEN RAISE EXCEPTION 'Invalid Group 3 game planning numeric values: %',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE model_source_url IS NULL OR length(model_source_url)<10;
 IF n<>0 THEN RAISE EXCEPTION 'Missing model/family provenance URLs: %',n; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE entry_no=25 AND mtow_kg=15660 AND mlw_kg=15160
 AND mzfw_kg=14350 AND oew_kg=10150 AND burn_kg_h=480
 AND takeoff_m=1082 AND landing_m=965;
 IF n<>1 THEN RAISE EXCEPTION 'Deutsche Aircraft D328eco OEM performance reconciliation failed'; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE entry_no=21 AND mtow_kg=21523 AND fuel_l=5300;
 IF n<>1 THEN RAISE EXCEPTION 'CRJ100 vs CRJ100ER model differentiation failed'; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE entry_no=26 AND mtow_kg=6400 AND mlw_kg=6100
 AND mzfw_kg=5940 AND cargo_kg=1800 AND cargo_volume_m3=14.7;
 IF n<>1 THEN RAISE EXCEPTION 'DHL Dornier228 cargo model reference reconciliation failed'; END IF;

 SELECT count(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE entry_no=28 AND cargo_kg=5900 AND cargo_volume_m3=45
 AND mtow_kg=20820 AND mlw_kg=19090 AND oew_kg=11210;
 IF n<>1 THEN RAISE EXCEPTION 'DHL F27 cargo model reference reconciliation failed'; END IF;
END $g3$;
SELECT 'GROUP3_39_RESEARCH_PLANNING_VALIDATION_PASSED' AS result;
